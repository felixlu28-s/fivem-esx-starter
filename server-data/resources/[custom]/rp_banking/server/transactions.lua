local B, C = Banking, Banking.Config
local function balance(player, account) return player.getAccount(account).money end
local function finish(id, order, reviewNote)
    local queries = {{ query = "UPDATE rp_banking_transactions SET status = 'completed', review_note = ? WHERE id = ?", values = {reviewNote or '', id} }}
    for _, row in ipairs(order.entries) do
        queries[#queries+1] = { query = 'INSERT IGNORE INTO rp_banking_history (character_id, reference, kind, amount, balance, counterparty, note) VALUES (?, ?, ?, ?, ?, ?, ?)',
            values = { row.character, 'atm:' .. id, row.kind, row.amount, row.balance, row.counterparty, order.note } }
    end
    assert(MySQL.transaction.await(queries), 'journal_commit_failed')
end
function B.transact(source, view, p)
    if not ({ deposit=true, withdraw=true, transfer=true })[p.kind] or not B.integer(p.amount, 1, C.maxAmount)
        or type(p.request) ~= 'string' or #p.request < 8 or #p.request > 64 or not p.request:match('^[%w_-]+$')
        or type(p.note) ~= 'string' or #p.note > 120 or not utf8.len(p.note) or p.note:find('%c')
        or (p.kind == 'transfer' and (type(p.recipient) ~= 'string' or #p.recipient > 100)) then return false, 'invalid_request' end
    local actor = view.character.identifier
    if B.locks[actor] then return false, 'busy' end
    B.locks[actor] = true
    local target, journalId
    local fingerprint = table.concat({p.kind, tostring(p.amount), p.kind == 'transfer' and p.recipient or '-', p.note}, '|')
    local ran, ok, reason = xpcall(function()
        local receipt = MySQL.single.await('SELECT id, fingerprint, status FROM rp_banking_transactions WHERE actor = ? AND request_id = ?', {actor, p.request})
        if receipt then
            if receipt.fingerprint ~= fingerprint then return false, 'request_reused' end
            return receipt.status == 'completed', receipt.status ~= 'completed' and 'review_required' or nil
        end
        if p.kind == 'transfer' then
            local recipient = view.recipient
            if not recipient or recipient.token ~= p.recipient or recipient.expires < os.time() or not B.same(recipient.character)
                or recipient.character.identifier == actor then return false, 'recipient_changed' end
            if B.locks[recipient.character.identifier] then return false, 'busy' end
            target = recipient.character
            B.locks[target.identifier] = true
        end
        if B.hold(actor) or (target and B.hold(target.identifier)) then return false, 'review_required' end
        if not B.live(source, view) or (target and not B.same(target)) then return false, 'session_expired' end
        local player, receiver = B.player(source), target and B.player(target.source)
        local cash, bank = balance(player,'money'), balance(player,'bank')
        local toBank = receiver and balance(receiver,'bank')
        local amount, depositing = p.amount, p.kind == 'deposit'
        if (depositing and cash or bank) < amount then return false, 'insufficient_funds' end
        if (depositing and bank or receiver and toBank or cash) + amount > C.maxBalance then return false, 'balance_limit' end
        local order = { kind=p.kind, amount=amount, note=p.note, name=player.getName(), targetName=receiver and receiver.getName(),
            before={cash=cash, bank=bank, targetBank=toBank}, after={}, entries={} }
        order.after.cash = depositing and cash-amount or (receiver and cash or cash+amount)
        order.after.bank = depositing and bank+amount or bank-amount
        order.after.targetBank = toBank and toBank+amount
        order.entries[1] = { character=actor, kind=p.kind, amount=depositing and amount or -amount,
            balance=order.after.bank, counterparty=order.targetName or '' }
        if target then order.entries[2] = { character=target.identifier, kind='received', amount=amount,
            balance=order.after.targetBank, counterparty=order.name } end
        -- Persist the intent before touching ESX; no automatic replay/refund of
        -- ambiguous mutations after a crash. The journal is never a balance store.
        journalId = MySQL.insert.await('INSERT INTO rp_banking_transactions (actor, target, request_id, fingerprint, payload) VALUES (?, ?, ?, ?, ?)',
            {actor, target and target.identifier or '', p.request, fingerprint, json.encode(order)})
        assert(journalId, 'intent_write_failed')
        if not B.live(source, view) or (target and not B.same(target)) then
            MySQL.update.await("UPDATE rp_banking_transactions SET status = 'cancelled' WHERE id = ? AND status = 'intent'", {journalId})
            return false, 'session_expired'
        end
        player, receiver = B.player(source), target and B.player(target.source)
        if balance(player,'money') ~= cash or balance(player,'bank') ~= bank or (receiver and balance(receiver,'bank') ~= toBank) then
            MySQL.update.await("UPDATE rp_banking_transactions SET status = 'cancelled' WHERE id = ? AND status = 'intent'", {journalId})
            return false, 'balance_changed'
        end
        -- No yield between the debit and credit. Both character locks are held;
        -- only current xPlayer APIs mutate money. Never write online users rows.
        local why = 'rp_banking:' .. journalId
        assert(player.removeAccountMoney(depositing and 'money' or 'bank', amount, why) ~= false, 'debit_failed')
        assert(balance(player, depositing and 'money' or 'bank') == (depositing and cash or bank)-amount, 'debit_mismatch')
        assert((receiver or player).addAccountMoney(receiver and 'bank' or (depositing and 'bank' or 'money'), amount, why) ~= false, 'credit_failed')
        assert(balance(player,'money') == order.after.cash and balance(player,'bank') == order.after.bank
            and (not receiver or balance(receiver,'bank') == order.after.targetBank), 'credit_mismatch')
        B.saved[actor] = 0
        if target then B.saved[target.identifier] = 0 end
        ExecuteCommand(('save %d'):format(source))
        if target then ExecuteCommand(('save %d'):format(target.source)) end
        local deadline = GetGameTimer()+5000
        while GetGameTimer() < deadline and (B.saved[actor] == 0 or (target and B.saved[target.identifier] == 0)) do Wait(50) end
        assert(B.same(view.character) and (not target or B.same(target)) and B.saved[actor] > 0
            and (not target or B.saved[target.identifier] > 0), 'save_unconfirmed')
        local raw = MySQL.scalar.await('SELECT accounts FROM users WHERE BINARY identifier = BINARY ?', {actor})
        local persisted = raw and json.decode(raw)
        assert(persisted and persisted.money == order.after.cash and persisted.bank == order.after.bank, 'save_mismatch')
        if target then
            raw = MySQL.scalar.await('SELECT accounts FROM users WHERE BINARY identifier = BINARY ?', {target.identifier})
            persisted = raw and json.decode(raw)
            assert(persisted and persisted.bank == order.after.targetBank, 'recipient_save_mismatch')
        end
        finish(journalId, order)
        if target and B.same(target) then TriggerClientEvent('rp_banking:received', target.source, amount, order.name) end
        return true
    end, debug.traceback)
    if not ran then
        if journalId then pcall(MySQL.update.await, "UPDATE rp_banking_transactions SET status = 'review' WHERE id = ? AND status = 'intent'", {journalId}) end
        print(('[rp_banking] Receipt %s requires review (request %s): %s'):format(tostring(journalId or 'unconfirmed'),p.request,tostring(ok)))
    end
    B.locks[actor], B.saved[actor] = nil, nil
    if target then B.locks[target.identifier], B.saved[target.identifier] = nil, nil end
    if not ran then return false, 'review_required' end
    return ok == true, reason
end

-- Resolve only after checking ESX save/account evidence. This never moves money.
RegisterCommand('rp_bank_review', function(source, args)
    if source ~= 0 then return end
    local id, status, note = tonumber(args[1]), args[2], table.concat(args,' ',3)
    if not B.integer(id,1,9007199254740991) or (status ~= 'completed' and status ~= 'cancelled') or #note < 8 or #note > 440 then
        return print('rp_bank_review <receipt-id> completed|cancelled <verified audit note (8+ characters)>')
    end
    local row = MySQL.single.await('SELECT actor, target, payload, status FROM rp_banking_transactions WHERE id = ?', {id})
    if not row or (row.status ~= 'intent' and row.status ~= 'review') or B.locks[row.actor] or B.locks[row.target] then return end
    B.locks[row.actor] = true
    if row.target and row.target ~= '' then B.locks[row.target] = true end
    local ok, err = pcall(function()
        if status == 'completed' then finish(id, json.decode(row.payload), 'Console: ' .. note)
        else MySQL.update.await("UPDATE rp_banking_transactions SET status = 'cancelled', review_note = ? WHERE id = ?", {'Console: ' .. note,id}) end
    end)
    B.locks[row.actor] = nil
    if row.target then B.locks[row.target] = nil end
    print(('[rp_banking] Audit %d %s: %s; no balance changed.'):format(id,status,ok and 'saved' or tostring(err)))
end, false)

RegisterCommand('rp_bank_pending', function(source)
    if source ~= 0 then return end
    local ok, rows = pcall(MySQL.query.await, [[SELECT id, actor, target, status, created_at, payload
        FROM rp_banking_transactions WHERE status IN ('intent','review') ORDER BY id LIMIT 20]])
    if not ok then return print('[rp_banking] Unable to read pending receipts: ' .. tostring(rows)) end
    for _, row in ipairs(rows) do
        local order = json.decode(row.payload)
        print(('[rp_banking] #%s %s %s $%s | %s -> %s'):format(row.id,row.status,order.kind,order.amount,row.actor,row.target or 'self'))
    end
    print(('[rp_banking] %d pending receipts shown (maximum 20). Inspect ESX account/save evidence before rp_bank_review.'):format(#rows))
end, false)
