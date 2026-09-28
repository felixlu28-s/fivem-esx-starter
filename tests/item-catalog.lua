-- Real catalog, inventory model and ammunition server handlers (no FXServer).
local base='server-data/resources/[custom]/rp_inventory/'
for _,file in ipairs({'items','weapon_catalog','weapons','model','clothing_artwork','clothing_catalog','clothing'}) do
    dofile(base..'shared/'..file..'.lua')
end
local M=Inventory.model
local passed=0
local function check(ok,message) assert(ok,message) passed=passed+1 end
local callbacks,events,hashes={},{},{}
local clock,serial,writes,cancelled=10000,0,0,false
function joaat(name) if not hashes[name] then serial=serial+1 hashes[name]=serial end return hashes[name] end
function GetGameTimer() return clock end
function CreateThread() end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function TriggerClientEvent() end
function TriggerEvent() end
function CancelEvent() cancelled=true end
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
local S={players={},cache={}}
Inventory.store=S
function S.player(id) return S.players[id] end
function S.live(id,session) return S.players[id]==session end
function S.playable(id) return S.player(id)~=nil end
function S.token(prefix) serial=serial+1 return prefix..serial end
function S.mutate(ids,_,_,_,_,guard,transform)
    if not guard() then return false end
    local row=S.cache[ids[1]]
    local copy={[ids[1]]=M.copy(row.data)}
    local ok,err=transform(copy)
    if not ok or not guard() then return false,err end
    row.data=copy[ids[1]] row.revision=row.revision+1 writes=writes+1
    S.weaponState(tonumber(ids[1])) -- mirrors S.sync before the callback returns
    return true
end
dofile(base..'server/weapons.lua')
local i=0
for name,definition in pairs(WeaponCatalog) do
    i=i+1
    local def=Inventory.items[name]
    check(def.weapon and def.label==definition.label and def.artwork=='weapons/'..name,'correct provider identity/name/artwork')
    local data=M.empty() data.capacity=100000
    check(M.add(data,name,1),'weapon fits valid player inventory')
    if not def.ammoFree and not def.consumable then check(M.add(data,def.ammo,def.magazine),'correct ammunition registered') end
    local key=tostring(i)
    S.players[i]={id=key,identifier='char1:catalog'..i,generation='catalog-session'..i}
    S.cache[key]={data=data,revision=0}
    S.weaponState(i)
    local before=writes
    local reply=callbacks['rp_inventory:ammoBatch'](i,name,'catalog-request-'..i)
    if def.ammoFree then
        check(not reply.ok and writes==before,'melee/equipment/recharge weapons cannot request free ammo')
        cancelled=false events.weaponDamageEvent(i,{weaponType=joaat(name)})
        check(not cancelled,'owned melee/recharge damage accepted')
        check(M.remove(data,name,1),'remove melee weapon') S.weaponState(i)
        cancelled=false events.weaponDamageEvent(i,{weaponType=joaat(name)})
        check(cancelled,'removed melee/recharge weapon rejected')
    else
        check(reply.ok and reply.count==def.magazine and writes==before+1,'exactly one durable prepayment')
        check(M.count(S.cache[key].data,def.ammo)==0,'paid ammo or thrown object removed from transferable inventory')
        callbacks['rp_inventory:ammoBatch'](i,name,'catalog-request-'..i)
        check(writes==before+1,'retry cannot debit or grant a second batch')
        cancelled=false events.weaponDamageEvent(i,{weaponType=joaat(name)})
        check(not cancelled,'paid last grenade/can or loaded weapon remains usable')
        source=i events['rp_inventory:ammoReport']('catalog-session'..i,{[def.ammo]={ammo=def.ammo,token=reply.token,spent=reply.count}})
        check(writes==before+1,'consumption is a RAM report, not another SQL write')
        if def.projectile then
            -- Flight/fuse finishes after the item was removed or a new inventory
            -- snapshot arrived. This is still the previously paid projectile.
            S.cache[key].data=M.empty() S.weaponState(i)
            clock=clock+5000 cancelled=false
            events.weaponDamageEvent(i,{weaponType=joaat(name)})
            check(not cancelled,'paid projectile survives flight/fuse and later inventory changes')
        end
    end
end
check(i==110,'complete imported Cfx handheld catalogue')
local clothingCount,visible=0,0
for _,def in pairs(Inventory.items) do if def.clothing then clothingCount=clothingCount+1 end end
check(clothingCount==12,'variants did not multiply ESX clothing definitions')
for _,p in pairs(Clothing.products) do
    if not p.hidden then check(p.artwork~=nil,'every sellable garment has exact artwork: '..p.id) visible=visible+1 end
end
check(visible==167,'invisible footwear is not sold as a garment')
local data=M.empty()
local a={garment={id='test-garment',sex=0,label='old persisted name',product='top_0_0',skin={torso_1=0,torso_2=1,arms=0,tshirt_1=15}}}
check(M.add(data,'clothing_top',1,a,1),'existing garment metadata accepted')
local display=M.clothingDisplay(data,data.items['1'])
check(display.artwork=='clothing/0/top/0_1','actual texture wins over stale product ID')
check(data.items['1'].metadata.garment.label=='old persisted name','display enrichment does not mutate stored metadata')
-- Real commerce catalogue: all guns available in editor, existing prices/IDs retained.
Commerce={Config={venues={}}}
dofile('server-data/resources/[custom]/rp_commerce/shared/weapons.lua')
dofile('server-data/resources/[custom]/rp_commerce/shared/weapon_catalog.lua')
local available={}
for _,p in pairs(Commerce.Weapons.catalog) do available[p.item]=true end
for name in pairs(WeaponCatalog) do check(available[name],'weapon available in existing editor') end
check(Commerce.Weapons.catalog.pistol.price==2500 and Commerce.Weapons.catalog.rifle.price==12500,'existing shop IDs/default prices preserved')
print(('PASS: %d catalog / all weapon families / exact garment variant checks'):format(passed))
