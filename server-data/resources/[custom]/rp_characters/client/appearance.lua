local A = Characters.Appearance
local skin = A.defaults(0)
local busy = false
local function limit(item, unrestricted)
    local ped = PlayerPedId()
    local max = item.max
    if item.component then
        max = item.drawable and GetNumberOfPedTextureVariations(ped, item.component, skin[item.drawable]) - 1
            or GetNumberOfPedDrawableVariations(ped, item.component) - 1
    elseif item.prop then
        max = item.drawable and (skin[item.drawable] < 0 and 0 or GetNumberOfPedPropTextureVariations(ped, item.prop, skin[item.drawable]) - 1)
            or GetNumberOfPedPropDrawableVariations(ped, item.prop) - 1
    elseif item.overlay then
        max = GetPedHeadOverlayNum(item.overlay) - 1
    end
    if not unrestricted and item.drawable and item.group ~= 'hair' then max = math.min(max, 11) end
    return math.max(item.min, math.min(item.max, max))
end
function A.catalog()
    local catalog = {}
    for _, item in ipairs(A.fields) do
        if A.visible(item, skin.sex) then
            local options = A.options(item, skin.sex)
            local available = nil
            if options then
                available = {}
                for _, option in ipairs(options) do
                    if option.value <= limit(item) then
                        available[#available + 1] = { value = option.value, label = option.label }
                    end
                end
            end
            catalog[#catalog + 1] = { key = item.key, label = item.label, group = item.group, min = item.min,
                max = limit(item), color = item.color == true, section = item.section, options = available }
        end
    end
    return catalog
end
function A.current() return skin end
function A.apply(input)
    if busy then return false end
    local nextSkin = A.validate(input)
    if not nextSkin then return false end
    busy = true
    local ok = pcall(function()
        local model = nextSkin.sex == 1 and joaat('mp_f_freemode_01') or joaat('mp_m_freemode_01')
        RequestModel(model)
        local deadline = GetGameTimer() + 10000
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(20) end
        if not HasModelLoaded(model) then error('model_timeout') end
        -- Preload bounds for the selected freemode model before applying clothes.
        if GetEntityModel(PlayerPedId()) ~= model then SetPlayerModel(PlayerId(), model) end
        skin = nextSkin
        for _, item in ipairs(A.fields) do
            if not item.drawable then skin[item.key] = math.min(skin[item.key], limit(item, true)) end
        end
        for _, item in ipairs(A.fields) do
            if item.drawable then skin[item.key] = math.min(skin[item.key], limit(item, true)) end
        end
        local complete = false
        TriggerEvent('skinchanger:loadSkin', skin, function() complete = true end)
        while not complete and GetGameTimer() < deadline do Wait(20) end
        if not complete then error('skin_timeout') end
        SetModelAsNoLongerNeeded(model)
        SetEntityVisible(PlayerPedId(), true, false)
        SetEntityInvincible(PlayerPedId(), true)
        FreezeEntityPosition(PlayerPedId(), true)
        Characters.Scene.place()
        A.camera()
    end)
    busy = false
    return ok
end
function A.change(key, value)
    if type(key) ~= 'string' then return false end
    local item = A.byKey[key]
    if not item or not A.visible(item, skin.sex) or not Characters.Validation.integer(value, item.min, limit(item)) then return false end
    if key == 'sex' then return A.apply(A.defaults(value)) end
    local option = A.option(item, skin.sex, value)
    if A.options(item, skin.sex) and not option then return false end
    local nextSkin = {}
    for k, v in pairs(skin) do nextSkin[k] = v end
    nextSkin[key] = value
    if item.texture then nextSkin[item.texture] = 0 end
    if option and option.skin then
        for k, v in pairs(option.skin) do nextSkin[k] = v end
    end
    return A.apply(nextSkin)
end
