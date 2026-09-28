local B, C, X = Commerce.Clothing, Commerce.Config, Commerce.Weapons.client
local ESX = exports.es_extended:getSharedObject()
local camera, active, blips = RpPortraitCamera(), nil, {}
local function currentClothing(current)
    local skin, rows = current.base, {}
    for _, id in ipairs(Clothing.order) do
        local cat = Clothing.categories[id]
        local drawable = skin[cat.prefix .. '_1']
        local worn = type(drawable) == 'number' and drawable >= 0 and drawable ~= cat.empty[skin.sex]
        local original = worn and Clothing.describe(id, skin.sex, skin)
        rows[#rows + 1] = {
            category = id, image = id, color = '#8b9c91',
            label = not worn and 'Nicht angezogen' or original and original.label or cat.label,
            artwork = original and original.artwork or nil, gxt = original and original.gxt or nil,
        }
    end
    return rows
end
function B.close(immediate)
    local old = active
    if not old then if immediate then camera.close(false) end return end
    active = nil
    camera.close(not immediate and DoesEntityExist(old.ped) and not IsPedDeadOrDying(old.ped, true))
    exports.rp_inventory:rpClothingPreview(false)
    TriggerServerEvent('rp_commerce:close', old.session)
    if exports.rp_ui:rpGetView() == 'clothing' then exports.rp_ui:rpClose() end
end
function B.open(id, data)
    if active or exports.rp_inventory:rpClothingBusy() or IsNuiFocused() or not ESX.IsPlayerLoaded() then return false end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped) then return false end
    local model = GetEntityModel(ped)
    if model ~= joaat('mp_m_freemode_01') and model ~= joaat('mp_f_freemode_01') then return false end
    local skin
    TriggerEvent('skinchanger:getSkin', function(value)
        skin = {}
        for k,v in pairs(value) do skin[k] = v end
    end)
    if not skin or not data then return false end
    skin.sex = model == joaat('mp_f_freemode_01') and 1 or 0
    local current = { id = id, session = data.session, ped = ped, base = skin, offers = {}, selected = {} }
    for _, offer in ipairs(data.offers) do current.offers[offer.id] = true end
    active = current
    exports.rp_inventory:rpClothingPreview(true)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    camera.update({ view = 'body' })
    -- Display the actual opening outfit, including creator clothes and bundled
    -- components without a separate worn inventory row. Never inspect the trial outfit.
    data.currentClothing = currentClothing(current)
    if not exports.rp_ui:rpOpen('clothing', exports.rp_inventory:rpLocalizeCatalog(data), false, { toggleAction = 'rp_commerce:interact' }) then B.close() return false end
    return true
end
local components = {top=11,undershirt=8,pants=4,shoes=6,chain=7,mask=1,bag=5}
local props = {hat=0,glasses=1,ears=2,watch=6,bracelet=7}
local function preview(current, products)
    if type(products) ~= 'table' or #products > #Clothing.order then return false end
    local selected = {}
    for index, id in pairs(products) do
        local product = type(id) == 'string' and Clothing.products[id]
        if type(index) ~= 'number' or index % 1 ~= 0 or index < 1 or index > #products
            or not product or not current.offers[id] or selected[product.category] then return false end
        local cat = Clothing.categories[product.category]
        local draw = product.skin[cat.prefix .. '_1']
        local count = components[product.category] and GetNumberOfPedDrawableVariations(current.ped, components[product.category])
            or GetNumberOfPedPropDrawableVariations(current.ped, props[product.category])
        if draw >= count then return false end
        selected[product.category] = product
    end
    -- Rebuild the entire outfit from the owned baseline, then apply one selection
    -- per category. An omitted category is "Aktuell", never a free purchase.
    local patch = {}
    for _, id in ipairs(Clothing.order) do
        local cat = Clothing.categories[id]
        patch[cat.prefix .. '_1'] = current.base[cat.prefix .. '_1'] or cat.empty[current.base.sex == 1 and 1 or 0]
        patch[cat.prefix .. '_2'] = current.base[cat.prefix .. '_2'] or 0
    end
    patch.arms, patch.arms_2 = current.base.arms, current.base.arms_2 or 0
    for _, id in ipairs(Clothing.order) do
        if selected[id] then
            for k, v in pairs(selected[id].skin) do patch[k] = v end
        elseif id == 'undershirt' then
            patch.tshirt_1, patch.tshirt_2 = current.base.tshirt_1 or 15, current.base.tshirt_2 or 0
        end
    end
    current.selected = products
    TriggerEvent('skinchanger:loadClothes', current.base, patch)
    return true
end
local function register()
    exports.rp_ui:rpRegisterAction('rp_clothing:camera', function(data)
        return { ok = active ~= nil and exports.rp_ui:rpGetView() == 'clothing' and camera.update(data) }
    end)
    exports.rp_ui:rpRegisterAction('rp_clothing:preview', function(data)
        if not active or exports.rp_ui:rpGetView() ~= 'clothing' or type(data) ~= 'table' then return { ok = false } end
        local ok = preview(active, data.products)
        return { ok = ok, error = not ok and 'clothing_unavailable' or nil }
    end)
    exports.rp_ui:rpRegisterAction('rp_clothing:buy', function(data)
        if not active or exports.rp_ui:rpGetView() ~= 'clothing' or type(data) ~= 'table' or data.session ~= active.session then return { ok = false, error = 'invalid_state' } end
        local current = active
        local ok, result = pcall(lib.callback.await, 'rp_commerce:action', false, data)
        if ok and type(result) == 'table' and active == current and result.commerce and type(result.commerce.clothingSkin) == 'table' then
            -- Response contains only the provider's committed outfit, not the preview.
            for key, value in pairs(result.commerce.clothingSkin) do current.base[key] = value end
            result.commerce.currentClothing = currentClothing(current)
            preview(current, current.selected)
        end
        return ok and exports.rp_inventory:rpLocalizeCatalog(result) or { ok = false, error = 'unavailable' }
    end)
end
CreateThread(function()
    register()
    for id, shop in pairs(B.shops) do
        shop.id, shop.normalshop, shop.displays = id, true, {}
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 73) SetBlipColour(blip, 2) SetBlipScale(blip, 0.7) SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING') AddTextComponentString(shop.label) EndTextCommandSetBlipName(blip)
        blips[#blips+1] = blip
    end
    while true do
        local ped, loaded = PlayerPedId(), ESX.IsPlayerLoaded()
        local pos = GetEntityCoords(ped)
        if active then
            local shop = B.shops[active.id]
            if not loaded or ped ~= active.ped or IsPedDeadOrDying(ped, true) or IsPedRagdoll(ped)
                or exports.rp_ui:rpGetView() ~= 'clothing' or Commerce.Weapons.distance(pos, shop.coords) > C.radius then B.close() end
        end
        for id, shop in pairs(B.shops) do
            local distance = Commerce.Weapons.distance(pos, shop.coords)
            if loaded and distance < Commerce.Weapons.streamIn then X.updateInstance('clothing:' .. id, shop)
            elseif not loaded or distance > Commerce.Weapons.streamOut then X.destroyInstance('clothing:' .. id) end
        end
        Wait(active and 250 or 750)
    end
end)
AddEventHandler('esx:onPlayerLogout', function() B.close(true) end)
AddEventHandler('onClientResourceStart', function(resource) if resource == 'rp_ui' then register() end end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource == 'rp_ui' or resource == 'rp_inventory' or resource == 'rp_core' then
        pcall(B.close, true)
        for id in pairs(B.shops) do X.destroyInstance('clothing:' .. id) end
        for _, blip in ipairs(blips) do RemoveBlip(blip) end
        blips = {}
    end
end)
