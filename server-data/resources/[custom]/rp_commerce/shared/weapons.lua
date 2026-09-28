-- Server-owned sellable catalogue. Admins arrange these entries; clients never add item definitions.
Commerce.Weapons = {
    streamIn = 45.0, streamOut = 60.0, maxShops = 32, maxDisplays = 32,
    clerkModels = { 's_m_y_ammucity_01', 's_m_m_ammucountry' },
    scenarios = { 'AMMU_ARMS_CROSSED', 'WORLD_HUMAN_STAND_IMPATIENT', 'WORLD_HUMAN_CLIPBOARD' },
    clerk = {
        placementLift = 0.5, initialHeightOffset = 0.0, soleClearance = 0.06,
        dict = 'random@shop_gunstore', idle = '_idle',
        -- Shared greetings/gestures live in rp_core/shared/npcs.lua.
    },
    camera = {
        duration = 650, exitDuration = 500,
        presentation = { duration = 420, returnDuration = 300, overshoot = 0.9 },
        inspect = { pitch = 18.0, yaw = 28.0, spring = 14.0 },
        lighting = { enabled = true, color = { r = 255, g = 244, b = 225 },
            range = 1.6, browse = 1.4, preview = 1.8, fadeSpeed = 7.0,
            forward = 0.55, side = 0.25, height = 0.45 },
        wall = { browseDistance = 1.75, previewDistance = 0.80, browseFov = 42.0, previewFov = 33.0,
            height = 0.12, side = 0.18, forward = 0.24, lift = 0.0 },
        counter = { browseDistance = 1.55, previewDistance = 0.72, browseFov = 43.0, previewFov = 34.0,
            height = 0.38, side = 0.12, forward = 0.10, lift = 0.24 },
    },
    catalog = {
        pistol = { label = 'Pistole', item = 'WEAPON_PISTOL', weapon = true, price = 2500,
            presentation = 'firearm', ammo = 'pistol_ammo', components = { 'pistol_light', 'pistol_suppressor' } },
        rifle = { label = 'Karabiner', item = 'WEAPON_CARBINERIFLE', weapon = true, price = 12500,
            presentation = 'firearm', ammo = 'rifle_ammo', components = { 'rifle_light', 'rifle_scope' } },
        pistol_ammo = { label = 'Pistolenmunition', item = 'ammo_pistol', packSize = 12, price = 96, model = 'prop_box_ammo03a' },
        rifle_ammo = { label = 'Gewehrmunition', item = 'ammo_rifle', packSize = 30, price = 450, model = 'prop_box_ammo03a' },
        pistol_light = { label = 'Pistolenlampe', item = 'rp_pistol_light', price = 300,
            component = 'COMPONENT_AT_PI_FLSH', model = 'prop_box_ammo03a' },
        pistol_suppressor = { label = 'Pistolen-Schalldämpfer', item = 'rp_pistol_suppressor', price = 900,
            component = 'COMPONENT_AT_PI_SUPP_02', model = 'prop_box_ammo03a' },
        rifle_light = { label = 'Gewehrlampe', item = 'rp_rifle_light', price = 400,
            component = 'COMPONENT_AT_AR_FLSH', model = 'prop_box_ammo03a' },
        rifle_scope = { label = 'Karabiner-Zielfernrohr', item = 'rp_rifle_scope', price = 1200,
            component = 'COMPONENT_AT_SCOPE_MEDIUM', model = 'prop_box_ammo03a' },
        bandage = { label = 'Verband', item = 'rp_bandage', price = 45, model = 'prop_ld_health_pack' },
    },
}
local W = Commerce.Weapons
function W.copy(v)
    if type(v) ~= 'table' then return v end
    local result = {} for k, value in pairs(v) do result[k] = W.copy(value) end return result
end
function W.finite(v, limit) return type(v) == 'number' and v == v and math.abs(v) <= limit end
local function vector(v, limit)
    if type(v) ~= 'table' or not W.finite(v.x, limit) or not W.finite(v.y, limit) or not W.finite(v.z, limit) then return nil end
    return { x = v.x, y = v.y, z = v.z }
end
function W.distance(a, b) return ((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2)^0.5 end
local function integer(v, low, high) return W.finite(v, high) and v % 1 == 0 and v >= low end
local function contains(values, value) for _, v in ipairs(values) do if v == value then return true end end return false end
-- Rebuild a bounded, plain record. Never persist arbitrary nested admin payloads.
function W.validate(raw)
    if type(raw) ~= 'table' or type(raw.label) ~= 'string' or #raw.label < 1 or #raw.label > 80
        or raw.label:find('[%c~]') or type(raw.license) ~= 'boolean' then return nil, 'invalid_shop' end
    local coords = vector(raw.coords, 20000)
    if not coords or not integer(raw.coords.bucket, 0, 2147483647) then return nil, 'invalid_position' end
    coords.bucket = raw.coords.bucket
    local shop = { label = raw.label, coords = coords, license = raw.license, displays = {}, prices = {}, ammoPricing = 'magazine-v1' }
    if type(raw.prices) ~= 'table' then return nil, 'invalid_prices' end
    for key, def in pairs(W.catalog) do
        local price = raw.prices[key] or def.price
        if def.packSize and raw.ammoPricing ~= 'magazine-v1' and raw.prices[key] ~= nil then
            if not integer(price,1,1000000) then return nil,'invalid_price' end
            price=price*def.packSize -- old persisted prices were per cartridge
        end
        if not integer(price, 1, 1000000) then return nil, 'invalid_price' end
        shop.prices[key] = price
    end
    if raw.npc ~= false then
        if type(raw.npc) ~= 'table' or not contains(W.clerkModels, raw.npc.model)
            or not contains(W.scenarios, raw.npc.scenario) or not W.finite(raw.npc.heading, 360) then return nil, 'invalid_npc' end
        local p = vector(raw.npc.pos, 20000)
        if not p or W.distance(p, coords) > 25 then return nil, 'npc_too_far' end
        shop.npc = { pos = p, heading = raw.npc.heading, model = raw.npc.model, scenario = raw.npc.scenario }
    else shop.npc = false end
    if type(raw.displays) ~= 'table' or #raw.displays > W.maxDisplays then return nil, 'display_limit' end
    local seen = {}
    for i, d in pairs(raw.displays) do
        if not integer(i, 1, #raw.displays) or type(d) ~= 'table' or type(d.id) ~= 'string'
            or #d.id > 40 or not d.id:match('^[%w_-]+$') or d.id == 'payment' or d.id == 'recover' or seen[d.id] or not W.catalog[d.catalog]
            or (d.type ~= 'wall' and d.type ~= 'counter') then return nil, 'invalid_display' end
        local p, r = vector(d.pos, 20000), vector(d.rot, 360)
        if not p or not r or W.distance(p, coords) > 25 or not W.finite(d.heading, 360)
            or not W.finite(d.scale, 2) or d.scale < 0.5 or not W.finite(d.height, 1) then return nil, 'invalid_transform' end
        seen[d.id] = true
        shop.displays[i] = { id = d.id, catalog = d.catalog, type = d.type, pos = p, rot = r,
            heading = d.heading, scale = d.scale, height = d.height }
    end
    return shop
end
function W.newShop(pos)
    local prices = {} for key, def in pairs(W.catalog) do prices[key] = def.price end
    return { label = 'Ammu-Nation', coords = W.copy(pos), license = false, npc = false, displays = {}, prices = prices, ammoPricing = 'magazine-v1' }
end
function W.pose(display, preview, presentation)
    presentation = presentation or preview
    local cfg = W.camera[display.type]
    local angle = math.rad(display.heading)
    local forward = { x = -math.sin(angle), y = math.cos(angle) }
    local position = { x = display.pos.x + forward.x * cfg.forward * presentation,
        y = display.pos.y + forward.y * cfg.forward * presentation, z = display.pos.z + cfg.lift * presentation }
    local rotation=W.copy(display.rot)
    if display.type=='counter' and W.catalog[display.catalog].presentation=='firearm' then
        rotation.x=W.angle(display.rot.x,0,presentation)
        rotation.y=W.angle(display.rot.y,0,presentation)
    end
    local distance = (cfg.browseDistance + (cfg.previewDistance - cfg.browseDistance) * preview) * display.scale
    return { object = position, rotation = rotation, target = { x = position.x, y = position.y, z = position.z },
        camera = { x = position.x + forward.x * distance + math.cos(angle) * cfg.side,
            y = position.y + forward.y * distance + math.sin(angle) * cfg.side,
            z = position.z + cfg.height + display.height },
        fov = cfg.browseFov + (cfg.previewFov - cfg.browseFov) * preview }
end
function W.lerp(a, b, t) return a + (b-a) * t end
function W.presentEase(t)
    t=math.max(0,math.min(1,t))-1
    local bounce=W.camera.presentation.overshoot
    return 1+(bounce+1)*t*t*t+bounce*t*t
end
function W.angle(a,b,t) return a+((b-a+180)%360-180)*t end
-- Exact critically damped spring: independent axes, stable under variable frame rates.
function W.spring(value,velocity,target,dt)
    local speed=W.camera.inspect.spring
    local delta=value-target
    local c=velocity+speed*delta
    local decay=math.exp(-speed*dt)
    return target+(delta+c*dt)*decay,(velocity-speed*c*dt)*decay
end
function W.mix(a, b, t) return { x = W.lerp(a.x,b.x,t), y = W.lerp(a.y,b.y,t), z = W.lerp(a.z,b.z,t) } end
function W.ease(t) t = math.max(0, math.min(1, t)) return t*t*(3-2*t) end
