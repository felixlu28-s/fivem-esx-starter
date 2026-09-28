local C, W = Commerce, Commerce.Weapons
local function install(id, shop, revision)
    shop.id, shop.revision = id, revision
    local offers, seen = {}, {}
    local function add(key)
        if not key or seen[key] then return end
        seen[key] = true
        local def=W.catalog[key]
        if def.packSize then
            assert(exports.rp_inventory:Items(def.item).maxStack==def.packSize,'Ammo magazine/stack mismatch: '..key)
        end
        offers[#offers+1] = { id = key, item = def.item, count = def.packSize or 1, price = shop.prices[key], category = 'Ammu-Nation' }
    end
    for _, d in ipairs(shop.displays) do
        local def = W.catalog[d.catalog]
        if def.weapon and def.ammo then
            assert(exports.rp_inventory:Items(def.item).ammo==W.catalog[def.ammo].item,'Weapon/ammo family mismatch: '..d.catalog)
        end
        add(d.catalog) add(def.ammo)
        for _, key in ipairs(def.components or {}) do add(key) end
    end
    C.Config.venues['weapon_' .. id] = { kind = 'shop', weaponshop = true, revision = revision,
        label = shop.label, subtitle = 'AMMU-NATION', coords = shop.coords, offers = offers, license = shop.license, shopId = id }
end
function C.authorizeWeapon(source, view)
    local venue = C.Config.venues[view.venue]
    if not venue or not venue.weaponshop or not venue.license then return true end
    if GetResourceState('esx_license') ~= 'started' then return false, 'license_unavailable' end
    local answered, licensed = false, false
    TriggerEvent('esx_license:checkLicense', source, 'weapon', function(value)
        answered, licensed = true, value == true
    end)
    local deadline = GetGameTimer() + 2500
    while not answered and GetGameTimer() < deadline do Wait(25) end
    if not answered or not licensed then return false, 'weapon_license_required' end
    -- A short, action-scoped permit covers the existing ESX persisted-payment handshake.
    if not C.live(source, view) then return false, 'session_expired' end
    view.licenseUntil = GetGameTimer() + 15000
    return true
end

function C.weaponViewValid(view, venue)
    return not venue.weaponshop or not view.licenseUntil or view.licenseUntil >= GetGameTimer()
end
local repository=C.registerShopEditor({
    schema=W, tableName='rp_commerce_weaponshops', command='rp_weaponshop',
    channel='rp_commerce:weaponEditor', changedEvent='rp_commerce:weaponshopsChanged',
    help='Ammu-Nation erstellen / bearbeiten', venue=function(id) return 'weapon_'..id end,
    install=install, uninstall=function(id) C.Config.venues['weapon_'..id]=nil end,
    checkCatalog=function()
        for _,def in pairs(W.catalog) do if not exports.rp_inventory:Items(def.item) then return false end end
        return true
    end,
})
lib.callback.register('rp_commerce:weaponshops', function(source)
    if not repository.ready() or not C.player(source) or not C.rate(source, 'weaponshops', 1500) then return { ok = false } end
    local p, bucket, result = GetEntityCoords(GetPlayerPed(source)), GetPlayerRoutingBucket(source), {}
    for _, shop in pairs(repository.shops) do
        if shop.coords.bucket == bucket then
            -- Small global location list keeps distant map blips; full displays only near the player.
            result[#result+1] = W.distance(p, shop.coords) < 160 and W.copy(shop)
                or { id = shop.id, revision = shop.revision, label = shop.label, coords = shop.coords }
        end
    end
    return { ok = true, shops = result }
end)
