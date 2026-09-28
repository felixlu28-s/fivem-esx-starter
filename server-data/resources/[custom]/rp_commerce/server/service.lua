local C = Commerce
C.ESX = exports.es_extended:getSharedObject()
C.views, C.epochs, C.busy, C.rates, C.saved = {}, {}, {}, {}, {}
C.ready = false
local sequence = 0
local boot = ('%x_%x'):format(os.time(), math.random(0, 0x7fffffff))
function C.token()
    sequence = sequence + 1
    return ('shop_%s_%x'):format(boot, sequence)
end
function C.integer(v, low, high)
    return type(v) == 'number' and v == v and v % 1 == 0 and v >= low and v <= high
end
function C.player(source)
    local player = C.ESX.GetPlayerFromId(source)
    if not player or not player.spawned or not exports.rp_inventory:rpIsReady(source) then return nil end
    return player
end
function C.allowed(source, venue)
    local player, ped = C.player(source), GetPlayerPed(source)
    if not player or ped == 0 or GetEntityHealth(ped) <= 0 or not venue then return false end
    local p, c = GetEntityCoords(ped), venue.coords
    if GetPlayerRoutingBucket(source) ~= c.bucket or (p.x-c.x)^2+(p.y-c.y)^2+(p.z-c.z)^2 > C.Config.radius^2 then return false end
    if venue.jobs then
        local job = player.getJob()
        local grade = job and tonumber(job.grade)
        if not job or not C.integer(grade, 0, 100000) or venue.jobs[job.name] == nil or grade < venue.jobs[job.name] then return false end
    end
    return true
end
function C.live(source, view)
    local player = C.player(source)
    return C.ready and player and C.views[source] == view and C.epochs[source] == view.epoch
        and player.identifier == view.actor and view.expires > os.time() and C.allowed(source, C.Config.venues[view.venue]) == true
        and (not C.weaponViewValid or C.weaponViewValid(view, C.Config.venues[view.venue]))
        and (not C.catalogViewValid or C.catalogViewValid(view, C.Config.venues[view.venue]))
end
function C.rate(source, name, delay)
    local now = GetGameTimer()
    C.rates[source] = C.rates[source] or {}
    if (C.rates[source][name] or 0) > now then return false end
    C.rates[source][name] = now + delay
    return true
end
function C.offer(venue, id)
    for _, offer in ipairs(venue.offers) do if offer.id == id then return offer end end
end
function C.pending(actor)
    return MySQL.single.await("SELECT request_id, payload, status FROM rp_commerce_orders WHERE actor = ? AND status IN ('intent', 'paid') ORDER BY created_at LIMIT 1", { actor })
end
function C.snapshot(source, view)
    if not C.live(source, view) then return nil end
    local player, venue = C.player(source), C.Config.venues[view.venue]
    local offers = {}
    -- Many clothing variants share one inventory definition. Snapshot each
    -- item once per request instead of crossing resource boundaries per product.
    local items = {}
    local function getItem(name)
        if not items[name] then items[name] = exports.rp_inventory:GetItem(source, name) end
        return items[name]
    end
    local clothing = venue.clothing and exports.rp_inventory:rpClothingState(source)
    for _, offer in ipairs(venue.offers) do
        if not venue.clothing or (clothing and offer.sex == clothing.sex) then
        local item = getItem(offer.item)
        local ingredients = {}
        for _, input in ipairs(offer.ingredients or {}) do
            local def = getItem(input.name)
            ingredients[#ingredients+1] = { name = input.name, label = def.label, icon = def.icon or 'item', artwork = def.artwork,
                count = input.count, owned = def.count }
        end
        local product = venue.clothing and Clothing.products[offer.id]
        offers[#offers+1] = { id = offer.id, label = product and product.label or item.label, icon = item.icon or 'item', description = item.description or item.label,
            artwork = product and product.artwork or item.artwork, gxt = product and product.gxt,
            category = offer.category, weight = item.weight, price = offer.price or 0, count = offer.count or 1,
            seconds = offer.seconds or 0, owned = item.count, ingredients = ingredients,
            garment = product and { category = product.category, image = product.image, color = product.color, view = Clothing.categories[product.category].view } }
        end
    end
    local pending = C.pending(view.actor)
    if not C.live(source, view) then return nil end
    player = C.player(source)
    return { session = view.token, kind = venue.kind, label = venue.label, subtitle = venue.subtitle, offers = offers,
        clothing = venue.clothing or nil,
        currentClothing = clothing and clothing.current and #clothing.current > 0 and clothing.current or nil,
        clothingSkin = clothing and clothing.skin or nil,
        cash = player.getAccount('money').money, bank = player.getAccount('bank').money,
        maxQuantity = venue.kind == 'shop' and C.Config.maxBuy or C.Config.maxCraft,
        pending = pending and pending.status or 'none',
        job = view.job and { token = view.job.token, offer = view.job.offer.id, quantity = view.job.quantity,
            duration = view.job.duration, remaining = math.max(0, view.job.readyAt - GetGameTimer()) } or nil }
end
function C.result(source, view, ok, err)
    return { ok = ok == true, error = err, commerce = C.snapshot(source, view) }
end
local function cleanup(source)
    C.views[source], C.epochs[source], C.rates[source] = nil, nil, nil
end
AddEventHandler('playerDropped', function() cleanup(source) end)
AddEventHandler('esx:playerLogout', cleanup)
AddEventHandler('rp_inventory:loaded', function(source) cleanup(source) end)
AddEventHandler('esx:playerSaved', function(_, player)
    if GetInvokingResource() == 'es_extended' and type(player) == 'table' and type(player.identifier) == 'string'
        and C.saved[player.identifier] ~= nil then
        C.saved[player.identifier] = (C.saved[player.identifier] or 0) + 1
    end
end)
MySQL.ready(function()
    local ok, reason = pcall(function()
        MySQL.query.await('SELECT request_id FROM rp_commerce_orders LIMIT 1')
        local catalog = exports.rp_inventory:Items()
        for id, venue in pairs(C.Config.venues) do
            assert(type(id) == 'string' and (venue.kind == 'shop' or venue.kind == 'crafting'), 'Invalid venue')
            assert(C.integer(venue.coords.bucket, 0, 2147483647), 'Invalid venue bucket')
            for _, axis in ipairs({ 'x', 'y', 'z' }) do
                local value = venue.coords[axis]
                assert(type(value) == 'number' and value == value and math.abs(value) < 20000, 'Invalid venue coordinate')
            end
            for name, grade in pairs(venue.jobs or {}) do
                assert(type(name) == 'string' and C.integer(grade, 0, 100000), 'Invalid venue job restriction')
            end
            local seen = {}
            for _, offer in ipairs(venue.offers) do
                assert(not seen[offer.id] and catalog[offer.item], 'Duplicate offer or unknown item: ' .. offer.id)
                seen[offer.id] = true
                if venue.kind == 'shop' then
                    assert(C.integer(offer.price, 1, 1000000), 'Invalid shop price')
                    assert(C.integer(offer.count or 1,1,100),'Invalid shop pack size')
                else
                    assert(C.integer(offer.count, 1, 100) and C.integer(offer.seconds, 1, 60) and #offer.ingredients > 0, 'Invalid recipe')
                    for _, input in ipairs(offer.ingredients) do
                        assert(catalog[input.name] and C.integer(input.count, 1, 100), 'Invalid ingredient')
                    end
                end
            end
        end
        C.ready = true
        print('[rp_commerce] ESX shops and crafting ready.')
    end)
    if not ok then print('[rp_commerce] NOT READY: apply migrations and check configuration: ' .. tostring(reason)) end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource == 'rp_inventory' then
        C.ready = false
        for source in pairs(C.views) do TriggerClientEvent('rp_commerce:hide', source) end
        C.views = {}
    end
end)
