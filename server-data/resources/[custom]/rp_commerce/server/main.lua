local C = Commerce
lib.callback.register('rp_commerce:open', function(source, id)
    if not C.rate(source, 'open', 500) then return { ok = false, error = 'rate_limited' } end
    if not C.ready then return { ok = false, error = 'server_starting' } end
    local venue = type(id) == 'string' and C.Config.venues[id]
    if not C.allowed(source, venue) then return { ok = false, error = 'out_of_range' } end
    if venue.clothing and not exports.rp_inventory:rpClothingState(source) then return { ok = false, error = 'clothing_not_ready' } end
    local player = C.player(source)
    if C.busy[player.identifier] then return { ok = false, error = 'busy' } end
    C.epochs[source] = C.epochs[source] or {}
    local view = { token = C.token(), actor = player.identifier, epoch = C.epochs[source], venue = id, expires = os.time() + 600, venueRevision = venue.revision }
    C.views[source] = view
    local ok, data = pcall(C.snapshot, source, view)
    return { ok = ok and data ~= nil, commerce = ok and data or nil, error = not ok and 'database_error' or nil }
end)
lib.callback.register('rp_commerce:action', function(source, p)
    if not C.rate(source, 'action', 350) then return { ok = false, error = 'rate_limited' } end
    local view = C.views[source]
    if type(p) ~= 'table' or not view or p.session ~= view.token or not C.live(source, view) then return { ok = false, error = 'session_expired' } end
    if C.busy[view.actor] then return { ok = false, error = 'busy' } end
    C.busy[view.actor] = true
    local ran, ok, err = pcall(function()
        local venue = C.Config.venues[view.venue]
        if p.action == 'refresh' then return true end
        if p.action == 'cancel' then view.job = nil return true end
        if p.action == 'recover' and venue.kind == 'shop' then
            if venue.weaponshop then
                local allowed, reason = C.authorizeWeapon(source, view)
                if not allowed then return false, reason end
            end
            return C.recover(source, view)
        end
        if p.action == 'finish' then
            local job = view.job
            if not job or p.token ~= job.token then return false, 'invalid_state' end
            if GetGameTimer() < job.readyAt then return false, 'craft_not_ready' end
            local remove = {}
            for _, input in ipairs(job.offer.ingredients) do remove[#remove+1] = { name = input.name, count = input.count * job.quantity } end
            local success, reason = exports.rp_inventory:rpExchange(source, job.token, remove,
                { { name = job.offer.item, count = job.offer.count * job.quantity } },
                function() return C.live(source, view) == true and view.job == job end)
            if success then view.job = nil end
            return success, reason
        end
        if view.job then return false, 'busy' end
        if p.action == 'buyOutfit' and venue.clothing and venue.kind == 'shop' then
            if type(p.products) ~= 'table' or #p.products < 1 or #p.products > #Clothing.order
                or type(p.equip) ~= 'boolean' or (p.account ~= 'money' and p.account ~= 'bank')
                or type(p.request) ~= 'string' or #p.request < 8 or #p.request > 55
                or not p.request:match('^[%w_-]+$') then return false, 'invalid_request' end
            local clothing = exports.rp_inventory:rpClothingState(source)
            if not clothing then return false, 'clothing_not_ready' end
            local offers, categories = {}, {}
            for index, id in pairs(p.products) do
                local offer = type(id) == 'string' and C.offer(venue, id)
                local product = offer and Clothing.products[id]
                if not C.integer(index, 1, #p.products) or not product or categories[product.category]
                    or (offer.count or 1) ~= 1 then return false, 'invalid_request' end
                if clothing.sex ~= offer.sex then return false, 'clothing_wrong_model' end
                categories[product.category] = true
                offers[#offers + 1] = offer
            end
            return C.purchaseOutfit(source, view, p.request, offers, p.account, p.equip)
        end
        local offer = type(p.offer) == 'string' and C.offer(venue, p.offer)
        if not offer or not C.integer(p.quantity, 1, venue.kind == 'shop' and C.Config.maxBuy or C.Config.maxCraft) then return false, 'invalid_request' end
        if p.action == 'buy' and venue.kind == 'shop' then
            if venue.clothing then
                local clothing = exports.rp_inventory:rpClothingState(source)
                if not clothing or clothing.sex ~= offer.sex or p.quantity ~= 1 then return false, 'clothing_wrong_model' end
            end
            if p.equip ~= nil and (type(p.equip) ~= 'boolean' or not venue.clothing) then return false, 'invalid_request' end
            if (p.account ~= 'money' and p.account ~= 'bank') or type(p.request) ~= 'string' or #p.request < 8 or #p.request > 55
                or not p.request:match('^[%w_-]+$') then return false, 'invalid_request' end
            if venue.weaponshop then
                local allowed, reason = C.authorizeWeapon(source, view)
                if not allowed then return false, reason end
            end
            return C.purchase(source, view, p.request, offer, p.quantity, p.account, p.equip)
        end
        if p.action == 'craft' and venue.kind == 'crafting' then
            for _, input in ipairs(offer.ingredients) do
                if exports.rp_inventory:GetItem(source, input.name).count < input.count * p.quantity then return false, 'not_enough' end
            end
            local duration = offer.seconds * p.quantity * 1000
            view.job = { token = C.token(), offer = offer, quantity = p.quantity, duration = duration, readyAt = GetGameTimer() + duration }
            return true
        end
        return false, 'invalid_request'
    end)
    C.busy[view.actor] = nil
    view.licenseUntil = nil
    C.saved[view.actor] = nil
    if not ran then print('[rp_commerce] Transaction interrupted; durable order retained: ' .. tostring(ok)) ok, err = false, 'database_error' end
    local snapOk, result = pcall(C.result, source, view, ok, err)
    return snapOk and result or { ok = false, error = 'database_error' }
end)
RegisterNetEvent('rp_commerce:close', function(token)
    local view = C.views[source]
    if view and view.token == token then C.views[source] = nil end
end)
CreateThread(function()
    while true do
        Wait(750)
        for source, view in pairs(C.views) do
            if not C.live(source, view) then C.views[source] = nil TriggerClientEvent('rp_commerce:hide', source) end
        end
    end
end)
