local S, M, ESX = Inventory.store, Inventory.model, exports.es_extended:getSharedObject()
local groups = { admin = true, superadmin = true, owner = true }
local menus, limits = {}, {}
local function allowed(source)
    local session, player = S.player(source)
    return session and player and groups[player.getGroup()] == true and S.playable(source)
end
local function throttle(source, action, delay)
    local now = GetGameTimer()
    limits[source] = limits[source] or {}
    if limits[source][action] and now < limits[source][action] then return false end
    limits[source][action] = now + delay
    return true
end
local function current(source, token)
    local menu = menus[source]
    if not allowed(source) or not menu or menu.token ~= token or menu.expires < os.time()
        or not S.live(source, menu.actor) then return nil end
    return menu
end
local function response(menu)
    return { ok = true, token = menu.token, ticket = menu.ticket, target = menu.targetId }
end
local function category(item)
    if item.clothing then return 'Kleidung' end
    if item.weapon then return 'Waffen' end
    if item.use == 'component' then return 'Waffenzubehör' end
    if Inventory.ammoTypes[item.name] then return 'Munition' end
    if item.use == 'eat' or item.use == 'drink' then return 'Essen & Trinken' end
    if item.use == 'backpack' then return 'Rucksäcke' end
    if item.use == 'heal' then return 'Medizin' end
    if item.name == 'rp_fabric' or item.name == 'rp_thread' or item.name == 'rp_plastic' then return 'Materialien' end
    return 'Sonstiges'
end
ESX.RegisterCommand('rp_items', { 'admin', 'superadmin', 'owner' }, function(player)
    if player and allowed(player.source) then TriggerClientEvent('rp_inventory:adminOpen', player.source) end
end, false, { help = 'Itemverwaltung öffnen', validate = true, arguments = {} })

lib.callback.register('rp_inventory:adminCatalog', function(source)
    if not allowed(source) then return { ok = false, error = 'forbidden' } end
    if not throttle(source, 'catalog', 1000) then return { ok = false, error = 'rate_limited' } end
    if not S.ready then return { ok = false, error = 'server_starting' } end
    if menus[source] and menus[source].busy then return { ok = false, error = 'busy' } end
    local session = S.player(source)
    local menu = { token = S.token('admin'), ticket = S.token('grant'), actor = session,
        target = session, targetId = source, expires = os.time() + 600 }
    menus[source] = menu
    local result = response(menu)
    result.items = {}
    for name, item in pairs(Inventory.items) do
        result.items[#result.items + 1] = { name = name, label = item.label,
            category = category(item), weight = item.weight, maxStack = item.maxStack }
    end
    table.sort(result.items, function(a, b) return a.label == b.label and a.name < b.name or a.label < b.label end)
    return result
end)

lib.callback.register('rp_inventory:adminTarget', function(source, token, target)
    local menu = current(source, token)
    if not menu then return { ok = false, error = 'forbidden' } end
    if menu.busy then return { ok = false, error = 'busy' } end
    if not throttle(source, 'target', 300) then return { ok = false, error = 'rate_limited' } end
    if not M.integer(target, 1, 2147483647) then return { ok = false, error = 'invalid_target' } end
    local session = S.player(target)
    if not session or not S.playable(target) then return { ok = false, error = 'invalid_target' } end
    menu.target, menu.targetId, menu.ticket, menu.last = session, target, S.token('grant'), nil
    return response(menu)
end)

lib.callback.register('rp_inventory:adminGive', function(source, token, ticket, name, count)
    local menu = current(source, token)
    if not menu then return { ok = false, error = 'forbidden' } end
    if type(name) ~= 'string' or #name > 100 or not Inventory.items[name] or not M.integer(count, 1, 99)
        or type(ticket) ~= 'string' or #ticket > 80 then return { ok = false, error = 'invalid_item' } end
    if menu.busy then return { ok = false, error = 'busy' } end
    local fingerprint = M.canonical({ name = name, count = count, target = menu.target.identifier })
    if menu.last and menu.last.ticket == ticket then
        if menu.last.fingerprint ~= fingerprint then return { ok = false, error = 'request_reused' } end
        return menu.last.result
    end
    if ticket ~= menu.ticket then return { ok = false, error = 'session_expired' } end
    if not throttle(source, 'give', 400) then return { ok = false, error = 'rate_limited' } end
    local recipient, target = menu.target, menu.targetId
    local function guard()
        return current(source, token) == menu and S.live(target, recipient) and S.playable(target)
    end
    if not guard() then return { ok = false, error = 'invalid_target' } end
    menu.busy = true
    -- Provider-owned grant: same mutation/model/sync path as xPlayer.addInventoryItem,
    -- plus a persistent replay receipt and actor/recipient checks across SQL awaits.
    local ran, ok, err, replay = pcall(S.mutate, { recipient.id }, menu.actor.identifier, ticket, fingerprint, nil,
        guard, function(copies) return M.add(copies[recipient.id], name, count) end)
    menu.busy = false
    if not ran then return { ok = false, error = 'database_error' } end
    if not ok then return { ok = false, error = err } end
    menu.ticket = S.token('grant')
    local result = response(menu)
    menu.last = { ticket = ticket, fingerprint = fingerprint, result = result }
    if not replay then
        print(('[rp_inventory] admin grant actor=%s target=%s item=%s count=%d receipt=%s'):format(source, target, name, count, ticket))
    end
    return result
end)
AddEventHandler('playerDropped', function() menus[source], limits[source] = nil, nil end)
AddEventHandler('esx:playerLogout', function(playerId) menus[playerId], limits[playerId] = nil, nil end)
CreateThread(function()
    while true do
        for source, menu in pairs(menus) do
            if not menu.busy and (menu.expires < os.time() or not S.live(source, menu.actor)) then menus[source] = nil end
        end
        Wait(30000)
    end
end)
