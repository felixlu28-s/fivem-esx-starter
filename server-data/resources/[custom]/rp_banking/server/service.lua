local B, C = Banking, Banking.Config
B.ESX = exports.es_extended:getSharedObject()
B.views, B.epochs, B.rates, B.locks, B.saved = {}, {}, {}, {}, {}
B.ready = false
local sequence, boot = 0, ('%x_%x'):format(os.time(), math.random(0, 0x7fffffff))
function B.token()
    sequence = sequence + 1
    return ('atm_%s_%x'):format(boot, sequence)
end
function B.rate(source, action, delay)
    local now = GetGameTimer()
    B.rates[source] = B.rates[source] or {}
    if (B.rates[source][action] or 0) > now then return false end
    B.rates[source][action] = now + delay
    return true
end
function B.player(source)
    local player = B.ESX.GetPlayerFromId(source)
    if not player or not player.spawned then return nil end
    return player
end
function B.capture(source)
    local player = B.player(source)
    if not player then return nil end
    B.epochs[source] = B.epochs[source] or {}
    return { source = source, identifier = player.getIdentifier(), epoch = B.epochs[source] }
end
function B.same(ctx)
    local player = ctx and B.player(ctx.source)
    return player and player.getIdentifier() == ctx.identifier and B.epochs[ctx.source] == ctx.epoch
end
function B.near(source, location)
    local ped = GetPlayerPed(source)
    return location and B.player(source) and ped ~= 0 and GetEntityHealth(ped) > 0 and GetVehiclePedIsIn(ped, false) == 0
        and GetPlayerRoutingBucket(source) == (location.bucket or 0)
        and Banking.distance(GetEntityCoords(ped), location) <= C.serverRadius
end
function B.live(source, view)
    return B.ready and view and B.views[source] == view and view.expires > os.time()
        and B.same(view.character) and B.near(source, B.locations[view.location])
end
function B.hold(identifier)
    return MySQL.scalar.await("SELECT id FROM rp_banking_transactions WHERE status IN ('intent','review') AND (actor = ? OR target = ?) LIMIT 1", {identifier, identifier}) ~= nil
end
function B.history(identifier, before)
    local rows = MySQL.query.await('SELECT id, kind, amount, balance, counterparty, note, UNIX_TIMESTAMP(created_at) AS time FROM rp_banking_history WHERE character_id = ? AND (? = 0 OR id < ?) ORDER BY id DESC LIMIT ?',
        { identifier, before or 0, before or 0, C.historyLimit })
    for _, row in ipairs(rows) do
        row.id, row.amount, row.balance, row.time = tonumber(row.id), tonumber(row.amount), tonumber(row.balance), tonumber(row.time)
    end
    return rows
end
function B.snapshot(source, view, before)
    if not B.live(source, view) then return nil end
    local rows = B.history(view.character.identifier, before)
    local held = B.hold(view.character.identifier)
    if not B.live(source, view) then return nil end
    local player = B.player(source)
    return { session = view.token, brand = view.brand, name = player.getName(),
        cash = player.getAccount('money').money, bank = player.getAccount('bank').money,
        maxAmount = C.maxAmount, history = rows, more = #rows == C.historyLimit, held = held }
end
local function cleanup(source)
    B.views[source], B.epochs[source], B.rates[source] = nil, nil, nil
    -- In-flight transaction locks live until their owning operation finishes.
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('esx:playerLogout', cleanup)
AddEventHandler('esx:playerLoaded', function(source) cleanup(source) end)
AddEventHandler('esx:playerSaved', function(_, player)
    if GetInvokingResource() == 'es_extended' and type(player) == 'table' and B.saved[player.identifier] ~= nil then
        B.saved[player.identifier] = B.saved[player.identifier] + 1
    end
end)

-- Observe official ESX bank mutations from salaries, shops and other scripts.
-- Our own operations write their two-sided, durable receipt instead.
local function observe(source, account, amount, reason, sign)
    if not B.ready or GetInvokingResource() ~= 'es_extended' or account ~= 'bank'
        or not B.integer(amount, sign == 0 and 0 or 1, C.maxBalance) then return end
    if type(reason) == 'string' and reason:sub(1,11) == 'rp_banking:' then return end
    local player = B.player(source)
    if not player then return end
    local identifier, balance = player.getIdentifier(), player.getAccount('bank').money
    CreateThread(function()
        local ok, err = pcall(MySQL.insert.await,
            'INSERT INTO rp_banking_history (character_id, kind, amount, balance, note) VALUES (?, ?, ?, ?, ?)',
            { identifier, sign == 0 and 'adjustment' or (sign == 1 and 'credit' or 'debit'), sign * amount, balance, 'Kontobewegung' })
        if not ok then print('[rp_banking] ESX history write failed: ' .. tostring(err)) end
    end)
end
AddEventHandler('esx:addAccountMoney', function(source, account, amount, reason) observe(source, account, amount, reason, 1) end)
AddEventHandler('esx:removeAccountMoney', function(source, account, amount, reason) observe(source, account, amount, reason, -1) end)
-- ESX's absolute setter reports the new balance, not a delta. Record it as such;
-- never infer a change from a shadow copy of the account.
AddEventHandler('esx:setAccountMoney', function(source, account, amount, reason) observe(source, account, amount, reason, 0) end)
MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await('SELECT id FROM rp_banking_transactions LIMIT 1')
        MySQL.query.await('SELECT id FROM rp_banking_history LIMIT 1')
        assert(GetResourceState('esx_banking') ~= 'started', 'Do not run a second banking UI/service alongside rp_banking')
        B.ready = true
        print(('[rp_banking] ESX ATM banking ready: %d configured locations.'):format(#B.locations))
    end)
    if not ok then print('[rp_banking] NOT READY: apply migrations/001_banking.sql. ' .. tostring(err)) end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    B.ready = false
    for source in pairs(B.views) do TriggerClientEvent('rp_banking:hide', source) end
end)
