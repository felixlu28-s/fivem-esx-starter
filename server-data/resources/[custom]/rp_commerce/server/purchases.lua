local C = Commerce
local function state(actor, request, status)
    MySQL.update.await('UPDATE rp_commerce_orders SET status = ? WHERE actor = ? AND request_id = ?', { status, actor, request })
end
local function deliver(source, view, request, order, charge)
    local ok, err = exports.rp_inventory:rpExchange(source, request, {}, order.items,
        function() return C.live(source, view) == true end, charge,
        order.equipClothing and { equipClothing = true } or nil)
    if ok then state(view.actor, request, 'completed') end
    return ok, err
end
local function purchaseOrder(source, view, request, order, fingerprint)
    local account = order.account
    if order.equipClothing then fingerprint = fingerprint .. '|wear' end
    local receipt = MySQL.single.await('SELECT fingerprint, status FROM rp_commerce_orders WHERE actor = ? AND request_id = ?', { view.actor, request })
    if receipt and receipt.fingerprint ~= fingerprint then return false, 'request_reused' end
    if receipt and receipt.status == 'completed' then return true end
    return deliver(source, view, request, order, function()
        local existing = MySQL.single.await('SELECT fingerprint, status FROM rp_commerce_orders WHERE actor = ? AND request_id = ?', { view.actor, request })
        if existing then
            if existing.fingerprint ~= fingerprint then return false, 'request_reused' end
            if existing.status == 'paid' then return true end
            return false, existing.status == 'intent' and 'payment_review' or 'invalid_state'
        end
        if C.pending(view.actor) then return false, 'pending_purchase' end
        if not C.live(source, view) then return false, 'session_expired' end
        local player = C.player(source)
        if player.getAccount(account).money < order.total then return false, 'not_enough_money' end
        order.balanceBefore = player.getAccount(account).money
        order.balanceAfter = order.balanceBefore - order.total
        MySQL.insert.await("INSERT INTO rp_commerce_orders (actor, request_id, fingerprint, payload, status) VALUES (?, ?, ?, ?, 'intent')",
            { view.actor, request, fingerprint, json.encode(order) })
        if not C.live(source, view) then state(view.actor, request, 'cancelled') return false, 'session_expired' end
        player = C.player(source)
        local before = player.getAccount(account).money
        if before < order.total then state(view.actor, request, 'cancelled') return false, 'not_enough_money' end
        if before ~= order.balanceBefore then state(view.actor, request, 'cancelled') return false, 'balance_changed' end
        -- No await between balance validation and the official ESX account debit.
        player.removeAccountMoney(account, order.total, 'rp_commerce:' .. view.venue)
        local expected = before - order.total
        if player.getAccount(account).money ~= expected then return false, 'payment_review' end
        C.saved[view.actor] = 0
        local saved = 0
        ExecuteCommand(('save %d'):format(source))
        local deadline = GetGameTimer() + 4000
        while (C.saved[view.actor] or 0) == saved and GetGameTimer() < deadline do Wait(50) end
        if (C.saved[view.actor] or 0) == saved then return false, 'payment_review' end
        local accounts = MySQL.scalar.await('SELECT accounts FROM users WHERE BINARY identifier = BINARY ?', { view.actor })
        local balances = accounts and json.decode(accounts)
        if not balances or balances[account] ~= expected then return false, 'payment_review' end
        -- Only confirmed persisted ESX payments may grant items. A crash between
        -- debit and confirmation leaves an audit hold, never an automatic refund.
        state(view.actor, request, 'paid')
        return true
    end)
end

function C.purchase(source, view, request, offer, quantity, account, equip)
    local order = { venue = view.venue, account = account, total = offer.price * quantity,
        items = { { name = offer.item, count = quantity * (offer.count or 1), metadata = offer.metadata } }, equipClothing = equip or nil }
    local fingerprint = ('%s|%s|%s|%d|%d'):format(view.venue, offer.id, account, quantity, order.total)
    if (offer.count or 1) ~= 1 then fingerprint = fingerprint .. '|pack:' .. offer.count end
    return purchaseOrder(source, view, request, order, fingerprint)
end

function C.purchaseOutfit(source, view, request, offers, account, equip)
    table.sort(offers, function(a, b) return a.id < b.id end)
    local order = { venue = view.venue, account = account, total = 0, items = {}, equipClothing = equip or nil }
    local parts = { view.venue, 'outfit', account }
    for _, offer in ipairs(offers) do
        order.total = order.total + offer.price
        order.items[#order.items + 1] = { name = offer.item, count = 1, metadata = offer.metadata }
        parts[#parts + 1] = ('%s:%d'):format(offer.id, offer.price)
    end
    return purchaseOrder(source, view, request, order, table.concat(parts, '|'))
end

-- Console-only audit/reconciliation, with an explicit operator note. Never
-- automatically infer whether an interrupted debit actually reached ESX's DB.
RegisterCommand('rp_commerce_orders', function(source, args)
    if source ~= 0 then return end
    local player = C.player(tonumber(args[1]))
    if not player then return print('rp_commerce_orders <online-player-id>') end
    local rows = MySQL.query.await("SELECT request_id, status, payload FROM rp_commerce_orders WHERE actor = ? AND status IN ('intent', 'paid')", { player.identifier })
    for _, row in ipairs(rows) do print(('[rp_commerce] %s %s %s'):format(row.request_id, row.status, row.payload)) end
    if #rows == 0 then print('[rp_commerce] No open orders.') end
end, false)
RegisterCommand('rp_commerce_resolve', function(source, args)
    if source ~= 0 then return end
    local player = C.player(tonumber(args[1]))
    local request, status, note = args[2], args[3], table.concat(args, ' ', 4)
    if not player or type(request) ~= 'string' or (status ~= 'paid' and status ~= 'cancelled') or #note < 8 or #note > 450 then
        return print('rp_commerce_resolve <online-player-id> <request> paid|cancelled <audit-note (8+ characters)>')
    end
    if C.busy[player.identifier] then return print('[rp_commerce] Transaction in progress; retry later.') end
    C.busy[player.identifier] = true
    local ok, changed = pcall(MySQL.update.await,
        "UPDATE rp_commerce_orders SET status = ?, review_note = ? WHERE actor = ? AND request_id = ? AND status = 'intent'",
        { status, 'Console: ' .. note, player.identifier, request })
    C.busy[player.identifier] = nil
    print(('[rp_commerce] Review %s: %s. No account balance changed.'):format(request, ok and tostring(changed) or 'database_error'))
end, false)
function C.recover(source, view)
    local pending = C.pending(view.actor)
    if not pending then return false, 'nothing_pending' end
    if pending.status ~= 'paid' then return false, 'payment_review' end
    local order = json.decode(pending.payload)
    if order.venue ~= view.venue then return false, 'original_shop_required' end
    return deliver(source, view, pending.request_id, order, function() return true end)
end
