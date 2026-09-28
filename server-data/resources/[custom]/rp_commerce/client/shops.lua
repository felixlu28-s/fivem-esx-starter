local C,S,W=Commerce.Config,Commerce.Shops,Commerce.Weapons
local X,ESX=W.client,exports.es_extended:getSharedObject()
local shops,blips,generation,busy,received={},{},0,false,false
local B={} S.client=B
local function remove(id)
    if blips[id] then RemoveBlip(blips[id].handle) blips[id]=nil end
    X.destroyInstance('store:'..id)
end
local function clear()
    generation=generation+1 received=false
    for id in pairs(shops) do remove(id) C.venues[id]=nil end
    shops={}
end
function B.refresh()
    if busy or not ESX.IsPlayerLoaded() then return end
    busy=true local epoch=generation
    local ok,result=pcall(lib.callback.await,'rp_commerce:shops',false)
    busy=false
    if epoch~=generation or not ESX.IsPlayerLoaded() or not ok or not result or not result.ok
        or type(result.shops)~='table' or #result.shops>S.maxShops then return end
    if not received then
        -- Replace shipped ESX locations, including deleted/bucket-excluded rows.
        for id,venue in pairs(C.venues) do if venue.kind=='shop' and not venue.weaponshop and not venue.clothing then C.venues[id]=nil end end
    end
    received=true
    local nextShops={}
    for _,shop in ipairs(result.shops) do
        nextShops[shop.id]=shop
        C.venues[shop.id]={kind='shop',normalshop=true,label=shop.label,coords=shop.coords}
        local old=shops[shop.id]
        if not old or old.revision~=shop.revision then
            remove(shop.id)
            if shop.blip then
                local b,c=shop.blip,shop.coords
                local handle=AddBlipForCoord(c.x,c.y,c.z)
                SetBlipSprite(handle,b.sprite) SetBlipColour(handle,b.color) SetBlipScale(handle,b.scale)
                SetBlipAsShortRange(handle,true)
                BeginTextCommandSetBlipName('STRING') AddTextComponentString(b.label) EndTextCommandSetBlipName(handle)
                blips[shop.id]={handle=handle}
            end
        end
    end
    for id in pairs(shops) do if not nextShops[id] then remove(id) C.venues[id]=nil end end
    shops=nextShops
end
RegisterNetEvent('rp_commerce:shopsChanged',function()
    if source==65535 then CreateThread(function() Wait(math.random(2600,4200)) B.refresh() end) end
end)
CreateThread(function()
    while true do B.refresh() Wait(received and 15000 or 5000) end
end)
CreateThread(function()
    while true do
        local p=GetEntityCoords(PlayerPedId())
        for id,shop in pairs(shops) do
            local distance=W.distance(p,shop.coords)
            if ESX.IsPlayerLoaded() and distance<W.streamIn and not (X.draft and X.draft.normalshop and X.draft.id==id) then X.updateInstance('store:'..id,shop)
            elseif distance>W.streamOut or not ESX.IsPlayerLoaded() then X.destroyInstance('store:'..id) end
        end
        Wait(750)
    end
end)
AddEventHandler('esx:onPlayerLogout',clear)
AddEventHandler('onResourceStop',function(resource)
    if resource==GetCurrentResourceName() or resource=='rp_ui' or resource=='rp_nativeui' or resource=='rp_core' then clear() end
end)
