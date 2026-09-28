local ESX = exports.es_extended:getSharedObject()
local C=Inventory.ammoSync
local owned,amounts,batches,pending,baseline={},{},{},nil,{}
local epoch,serial,revision,generation=0,0,-1,nil
local nextRequest,nextReport,dirty,excess=0,0,false,0
local auditPending={}
local choices,entriesById={},{}
local presentation
local function remaining(name)
    local def=Inventory.items[name]
    local batch=def and batches[def.ammo]
    return def and def.consumable and batch and batch.count>batch.spent
end
local ammoHash,weaponHash,observedAmmo={},{},{}
for name,def in pairs(Inventory.items) do if def.weapon and (not IsWeaponValid or IsWeaponValid(joaat(name))) then weaponHash[name]=joaat(name) end end
for group,name in pairs(Inventory.ammoTypes) do ammoHash[group]=joaat(name) end
local function hasGroup(group)
    for name in pairs(owned) do if Inventory.items[name].ammo==group then return true end end
    return false
end
local function target(group)
    local batch=batches[group]
    return hasGroup(group) and ((amounts[group] or 0)+(batch and batch.count-batch.spent or 0)) or 0
end
local function applyAmmo()
    local ped=PlayerPedId()
    for group,hash in pairs(ammoHash) do
        SetPedAmmoByType(ped,hash,target(group))
        -- GTA can cap pools; compare against the actual value we wrote, not an assumed native limit.
        baseline[group]=GetPedAmmoByType(ped,hash)
    end
end
local function observe()
    local ped=PlayerPedId()
    -- Poll only held families each frame. The staggered audit still samples
    -- every configured native pool to detect ammunition injected into others.
    for group,hash in pairs(observedAmmo) do
        local actual,before=GetPedAmmoByType(ped,hash),baseline[group]
        if before then
            if actual>before then excess=math.min(100000,excess+1)
            elseif actual<before then
                local batch=batches[group]
                if batch then
                    batch.spent=math.min(batch.count,batch.spent+before-actual)
                    dirty=true
                end
            end
            if actual~=before then
                SetPedAmmoByType(ped,hash,target(group))
                actual=GetPedAmmoByType(ped,hash)
            end
        end
        baseline[group]=actual
    end
end
local function reports()
    local result={}
    for group,batch in pairs(batches) do result[group]={ammo=group,token=batch.token,spent=batch.spent} end
    return result
end
local function report(nonce)
    if not generation then return end
    observe()
    local observations={}
    for group,hash in pairs(ammoHash) do observations[group]=GetPedAmmoByType(PlayerPedId(),hash) end
    TriggerServerEvent('rp_inventory:ammoReport',generation,reports(),observations,nonce,revision,excess)
    dirty=false nextReport=GetGameTimer()+C.reportMs
end
local function reconcile(previous)
    local ped=PlayerPedId()
    observedAmmo={}
    for name in pairs(owned) do
        local group=Inventory.items[name].ammo
        if group and ammoHash[group] then observedAmmo[group]=ammoHash[group] end
    end
    SetWeaponsNoAutoswap(true)
    for name,def in pairs(Inventory.items) do if def.weapon and weaponHash[name] then
        local hash=weaponHash[name]
        if owned[name] then
            local fresh=not HasPedGotWeapon(ped,hash,false)
            if fresh then GiveWeaponToPed(ped,hash,def.rechargeable and 1 or def.consumable and target(def.ammo) or 0,false,false) end
            local metadata=owned[name]
            local desired={}
            for _,value in ipairs(type(metadata.components)=='table' and metadata.components or {}) do
                local component=type(value)=='string' and joaat(value) or type(value)=='number' and value or type(value)=='table' and value.hash
                if type(component)=='number' then desired[component]=true end
            end
            if presentation and presentation.name==name and presentation.weaponId==metadata.weaponId then
                desired[joaat(presentation.component)]=not presentation.install or nil
            end
            for _,attachment in pairs(Inventory.items) do if attachment.weaponName==name then
                local hashComponent=joaat(attachment.component)
                if not desired[hashComponent] then RemoveWeaponComponentFromPed(ped,hash,hashComponent) end
            end end
            for component in pairs(desired) do
                if DoesWeaponTakeWeaponComponent(hash,component) then GiveWeaponComponentToPed(ped,hash,component) end
            end
            SetPedWeaponTintIndex(ped,hash,type(metadata.tintIndex)=='number' and metadata.tintIndex or 0)
            -- New weapons / newly received ammunition are ready without using either item.
            if def.ammo and (fresh or ((previous[def.ammo] or 0)==0 and (amounts[def.ammo] or 0)>0)) then
                SetPedAmmoByType(ped,ammoHash[def.ammo],target(def.ammo))
                SetAmmoInClip(ped,hash,math.min(def.magazine,target(def.ammo)))
            end
        elseif HasPedGotWeapon(ped,hash,false) then RemoveWeaponFromPed(ped,hash) end
    end end
    applyAmmo()
    SetPedDropsWeaponsWhenDead(ped,false)
end
function Inventory.selectWeapon(effect)
    local entry=entriesById[effect.weaponId]
    if effect.generation~=generation or not entry or entry.name~=effect.name or not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId()) then return false end
    if not weaponHash[entry.name] then
        lib.notify({title="Waffe",description="Dieses Modell ist in deinem GTA-Spielbuild nicht verf?gbar.",type="error"})
        return false
    end
    choices[entry.name]=effect.weaponId
    owned[entry.name]=entry.metadata
    observe()
    reconcile(amounts)
    SetCurrentPedWeapon(PlayerPedId(),weaponHash[entry.name],true)
    return true
end
function Inventory.weaponInstanceAvailable(effect)
    local entry=entriesById[effect.weaponId]
    return effect.generation==generation and entry and entry.name==effect.name and choices[entry.name]==effect.weaponId
end
function Inventory.presentAttachment(effect)
    presentation=effect
    reconcile(amounts)
end
RegisterNetEvent('rp_inventory:state',function(entries,state)
    if source~=65535 or type(entries)~='table' or type(state)~='table' or type(state.revision)~='number'
        or type(state.generation)~='string' then return end
    if state.generation==generation and state.revision<revision then return end
    if generation~=state.generation then
        epoch=epoch+1 pending=nil batches={} baseline={} excess=0 auditPending={} choices={} presentation=nil
    else observe() end -- account for shots before any snapshot can overwrite the native pool
    generation,revision=state.generation,state.revision
    local previous=amounts
    local nextOwned,slots,nextAmounts={},{},{}
    entriesById={}
    for _,entry in pairs(entries) do
        local def=Inventory.items[entry.name]
        if def and def.weapon and weaponHash[entry.name] and entry.count>0 and type(entry.metadata)=='table' and type(entry.metadata.weaponId)=='string' then
            entriesById[entry.metadata.weaponId]=entry
        end
        if def and def.weapon and weaponHash[entry.name] and entry.count>0 and (not slots[entry.name] or (entry.slot or 999)<slots[entry.name]) then
            nextOwned[entry.name],slots[entry.name]=entry.metadata or {},entry.slot or 999
        end
        if ammoHash[entry.name] then nextAmounts[entry.name]=(nextAmounts[entry.name] or 0)+entry.count*(def.ammoUnits or 1) end
    end
    for name,id in pairs(choices) do
        local entry=entriesById[id]
        if entry and entry.name==name then nextOwned[name]=entry.metadata else choices[name]=nil end
    end
    for name in pairs(owned) do
        if not nextOwned[name] then
            if remaining(name) or (Inventory.items[name].consumable and pending and pending.name==name) then
                nextOwned[name]=owned[name]
            else epoch=epoch+1 pending=nil end
        end
    end
    owned,amounts=nextOwned,nextAmounts
    for group in pairs(batches) do if not hasGroup(group) then batches[group]=nil end end
    ESX.SetPlayerData('inventory',entries)
    reconcile(previous)
end)
RegisterNetEvent('rp_inventory:ammoAudit',function(gen,nonce)
    if source~=65535 or gen~=generation or type(nonce)~='string' then return end
    auditPending={token=nonce,count=excess}
    report(nonce)
end)
RegisterNetEvent('rp_inventory:ammoAuditResult',function(gen,nonce)
    if source~=65535 or gen~=generation or nonce~=auditPending.token then return end
    excess=math.max(0,excess-(auditPending.count or 0)) auditPending={}
end)
local function clear()
    epoch=epoch+1 owned,amounts,batches,pending,baseline={},{},{},nil,{}
    revision,generation=-1,nil dirty=false excess=0 auditPending={} nextRequest=0 nextReport=0
    choices,entriesById,presentation={},{},nil
    observedAmmo={}
    RemoveAllPedWeapons(PlayerPedId(),true)
end
AddEventHandler('esx:onPlayerLogout',clear)
AddEventHandler('onResourceStop',function(resource)
    if resource==GetCurrentResourceName() then clear() SetWeaponsNoAutoswap(false) end
end)
AddEventHandler('esx:onPlayerSpawn',function()
    epoch=epoch+1 pending=nil batches={} baseline={} reconcile({})
end)
local function authorize(name,clip)
    if pending or GetGameTimer()<nextRequest then return end
    serial=serial+1
    local group=Inventory.items[name].ammo
    local request=('batch_%x_%x'):format(GetGameTimer(),serial)
    local ticket={epoch=epoch,ped=PlayerPedId(),generation=generation,name=name}
    local previous=reports()[group]
    pending=ticket nextRequest=GetGameTimer()+C.requestMs
    CreateThread(function()
        local ok,result=pcall(lib.callback.await,'rp_inventory:ammoBatch',false,name,request,previous)
        if pending~=ticket then return end
        pending=nil
        if ok and result and result.ok and ticket.epoch==epoch and ticket.ped==PlayerPedId()
            and ticket.generation==generation and result.generation==generation
            and result.ammo==group and owned[name] and ESX.IsPlayerLoaded() and not IsEntityDead(ticket.ped) then
            if result.revision>=revision then revision=result.revision amounts[group]=result.remaining*(Inventory.items[name].ammoUnits or 1) end
            batches[group]={token=result.token,count=result.count,spent=result.spent}
            -- GTA may remove a last grenade when the durable debit snapshot
            -- temporarily projects zero loose objects before this paid reply.
            if Inventory.items[name].consumable then reconcile(amounts) end
            applyAmmo()
            local _,currentClip=GetAmmoInClip(ticket.ped,weaponHash[name])
            if currentClip==0 and clip>0 then SetAmmoInClip(ticket.ped,weaponHash[name],math.min(clip,target(group))) end
        end
    end)
end
CreateThread(function()
    local lastDead=false
    while true do
        local ped=PlayerPedId()
        if ESX.IsPlayerLoaded() and next(owned) then
            local dead=IsEntityDead(ped)
            if dead and not lastDead then epoch=epoch+1 pending=nil batches={} baseline={} end
            lastDead=dead
            observe()
            local selected=GetSelectedPedWeapon(ped)
            local name
            for weapon in pairs(owned) do if weaponHash[weapon]==selected then name=weapon break end end
            if name then
                local def=Inventory.items[name]
                local group=def.ammo
                local batch=batches[group]
                local allowed=not dead and not Inventory.attachmentBusy and not IsNuiFocused() and not IsPauseMenuActive() and (def.ammoFree or (batch and batch.spent<batch.count))
                -- Read both input paths before our frame-scoped firing guard.
                -- Disabled firing can hide INPUT_ATTACK from IsControlPressed.
                local wantsFire=IsControlPressed(0,24) or IsDisabledControlPressed(0,24)
                -- This native blocks the current frame even with toggle=false.
                -- Allow firing by omitting it; never clear another resource's guard.
                if not allowed then DisablePlayerFiring(PlayerId(),true) end
                if group and not dead and not Inventory.attachmentBusy and not allowed and not pending and not IsNuiFocused() and not IsPauseMenuActive()
                    and wantsFire and not IsPedReloading(ped) and (amounts[group] or 0)>0 then
                    local valid,clip=GetAmmoInClip(ped,selected)
                    if valid or def.consumable then authorize(name,valid and clip>0 and clip or def.magazine) end
                end
            end
            if dirty and GetGameTimer()>=nextReport then report() end
            for weapon in pairs(owned) do
                local def=Inventory.items[weapon]
                if def.consumable and (amounts[def.ammo] or 0)==0 and not remaining(weapon) and not (pending and pending.name==weapon) then
                    if dirty then report() end
                    owned[weapon]=nil
                    observedAmmo[def.ammo]=nil
                    RemoveWeaponFromPed(ped,weaponHash[weapon])
                end
            end
            -- DisablePlayerFiring is frame-scoped. Poll while a managed weapon is owned so a
            -- quick wheel switch cannot fire loose inventory ammo before the first paid batch.
            -- This is client-local native work; it generates no per-frame network traffic.
            Wait(0)
        else Wait(500) end
    end
end)
