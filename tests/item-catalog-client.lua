-- All real weapon definitions against GTA-like client ammo/weapon natives.
local base='server-data/resources/[custom]/rp_inventory/'
for _,file in ipairs({'items','weapon_catalog','weapons'}) do dofile(base..'shared/'..file..'.lua') end
local events,threads,hashes,pools,weapons,ammo,clips={},{},{},{},{},{},{}
local serial,clock,selected,revision,passed=0,10000,0,1,0
local blocked,held,nui,dead=false,false,false,false
local reply,waiting,requests=nil,false,0
local function check(v,m) assert(v,m) passed=passed+1 end
function joaat(name) if not hashes[name] then serial=serial+1 hashes[name]=serial end return hashes[name] end
for name,def in pairs(Inventory.items) do if def.weapon and def.ammo then pools[joaat(name)]=joaat(Inventory.ammoTypes[def.ammo]) end end
exports={es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return true end,SetPlayerData=function() end} end}}
lib={notify=function() end,callback={await=function()
    requests=requests+1
    if waiting then coroutine.yield('await') end
    return reply
end}}
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function GetGameTimer() return clock end
function PlayerPedId() return 1 end
function PlayerId() return 0 end
function GetSelectedPedWeapon() return selected end
function SetCurrentPedWeapon(_,hash) selected=hash end
function IsEntityDead() return dead end
function IsNuiFocused() return nui end
function IsPauseMenuActive() return false end
function IsControlPressed() return held and not blocked end
function IsDisabledControlPressed() return held end
function IsPedReloading() return false end
function DisablePlayerFiring() blocked=true end
function IsWeaponValid() return true end
function HasPedGotWeapon(_,hash) return weapons[hash]==true end
function GiveWeaponToPed(_,hash,count) weapons[hash]=true if pools[hash] then ammo[pools[hash]]=count end end
function RemoveWeaponFromPed(_,hash) weapons[hash]=nil end
function RemoveAllPedWeapons() weapons,ammo,clips={},{},{} end
function SetPedAmmoByType(_,group,count) check(group~=nil,'native ammo hash is never nil') ammo[group]=count end
function GetPedAmmoByType(_,group) return ammo[group] or 0 end
function SetAmmoInClip(_,hash,count) clips[hash]=count end
function GetAmmoInClip(_,hash) return true,clips[hash] or 0 end
function SetPedDropsWeaponsWhenDead() end
function SetWeaponsNoAutoswap() end
function DoesWeaponTakeWeaponComponent() return true end
function GiveWeaponComponentToPed() end
function RemoveWeaponComponentFromPed() end
function SetPedWeaponTintIndex() end
function GetCurrentResourceName() return 'rp_inventory' end
function TriggerServerEvent() end
local function tick(thread)
    blocked=false
    local ok,err=coroutine.resume(thread or threads[1]) assert(ok,err)
end
dofile(base..'client/weapons.lua')
local function snapshot(rows)
    revision=revision+1 source=65535
    events['rp_inventory:state'](rows,{revision=revision,generation='catalog-client'})
end
for name,def in pairs(Inventory.items) do if def.weapon then
    events['esx:onPlayerLogout']()
    clock=clock+2000 held=false waiting=false
    local rows={{name=name,count=1,metadata={weaponId=name},slot=1}}
    if def.ammo and not def.consumable then rows[2]={name=def.ammo,count=def.magazine,slot=2} end
    snapshot(rows) selected=joaat(name)
    check(weapons[selected],'all catalogue weapons reach wheel')
    tick()
    if def.ammoFree then
        check(not blocked,'owned melee or rechargeable usable without ammo RPC')
        nui=true tick() check(blocked,'UI still gates melee') nui=false
        snapshot({}) check(not weapons[selected],'removal clears ammo-free weapon')
    else
        check(blocked,'loose ammo never bypasses durable prepayment')
        held=true waiting=true tick()
        local request=threads[#threads]
        check(request~=threads[1],'paid request created') tick(request)
        if def.consumable then snapshot({}) else snapshot({rows[1]}) end
        if def.consumable then weapons[selected]=nil end -- engine removes last grenade at zero
        reply={ok=true,token='paid-'..name,count=def.magazine,spent=0,ammo=def.ammo,remaining=0,
            revision=revision,generation='catalog-client'}
        waiting=false tick(request) held=false tick()
        check(not blocked and weapons[selected],'last-item debit snapshot preserves paid usability')
        check(ammo[pools[selected]]==def.magazine,'paid native total exact')
        ammo[pools[selected]]=0 clock=clock+2000 tick()
        check(blocked,'exhausted budget cannot fire')
        if def.consumable then check(not weapons[selected],'thrown/spent object removed from wheel') end
    end
end end
-- Receiving another snapshot while a throw is pending must not resurrect a
-- transferable item or discard the only paid grenade after server debit.
events['esx:onPlayerLogout']()
check(not next(weapons),'resource lifecycle clears every managed weapon')
print(('PASS: %d all-family client projection / last-consumable / UI checks; %d batched requests'):format(passed,requests))
