local B, C = Banking, Banking.Config
local ESX = exports.es_extended:getSharedObject()
local active, pending, nearby, generation = nil, false, nil, 0
local blips, models = {}, {}
for model, brand in pairs(C.models) do models[#models+1]={name=model,hash=joaat(model),brand=brand} end
local function uiReady()
    return GetResourceState('rp_ui')=='started' and GetResourceState('rp_core')=='started'
end
local function close()
    generation=generation+1
    pending=false
    local old=active
    active=nil
    if GetResourceState('rp_ui')=='started' then exports.rp_ui:rpHideInteraction() end
    if not old then return end
    if DoesEntityExist(old.ped) and IsPedUsingScenario(old.ped,'PROP_HUMAN_ATM') then ClearPedTasks(old.ped) end
    TriggerServerEvent('rp_banking:close',old.token)
    if GetResourceState('rp_ui')=='started' then
        if exports.rp_ui:rpGetView()=='banking' then exports.rp_ui:rpClose() end
    end
end
local function findNearby()
    local ped=PlayerPedId()
    if not ESX.IsPlayerLoaded() or IsPedInAnyVehicle(ped,false) or IsPedDeadOrDying(ped,true) then return nil end
    local pos=GetEntityCoords(ped)
    local locations={}
    for id,location in ipairs(B.locations) do if B.distance(pos,location)<10.0 then locations[#locations+1]=id end end
    if #locations==0 then return nil end
    local nearest
    for _,model in ipairs(models) do
        local entity=GetClosestObjectOfType(pos.x,pos.y,pos.z,2.5,model.hash,false,false,false)
        if entity~=0 and DoesEntityExist(entity) then
            local at=GetEntityCoords(entity)
            local distance=B.distance(pos,at)
            if distance<=C.interactionRadius and (not nearest or distance<nearest.distance) then
                local locationId,closest
                for _,id in ipairs(locations) do
                    local gap=B.distance(at,B.locations[id])
                    if gap<=C.modelMatchRadius and B.distance(pos,B.locations[id])<=C.serverRadius and (not closest or gap<closest) then
                        locationId,closest=id,gap
                    end
                end
                if locationId then nearest={id=locationId,entity=entity,model=model.name,brand=C.overrides[locationId] or model.brand,distance=distance} end
            end
        end
    end
    return nearest
end
local function open()
    if not uiReady() or pending or active or IsNuiFocused() or not ESX.IsPlayerLoaded() then return end
    local point=findNearby()
    if not point then return end
    pending=true
    local mine=generation
    local ok,result=pcall(lib.callback.await,'rp_banking:open',false,point.id,point.model)
    if mine~=generation then
        if ok and result and result.banking then TriggerServerEvent('rp_banking:close',result.banking.session) end
        return
    end
    pending=false
    if not ok or not result or not result.ok or not result.banking then
        return lib.notify({title='Geldautomat',description='Dieser Automat ist gerade nicht verfügbar.',type='error'})
    end
    local ped=PlayerPedId()
    active={token=result.banking.session,ped=ped,point=point}
    if not findNearby() or IsNuiFocused() then close() return end
    TaskTurnPedToFaceEntity(ped,point.entity,500)
    Wait(450)
    if not active or mine~=generation then return end
    if IsPedDeadOrDying(ped,true) or IsPedInAnyVehicle(ped,false) then close() return end
    TaskStartScenarioInPlace(ped,'PROP_HUMAN_ATM',0,true)
    if not exports.rp_ui:rpOpen('banking',result.banking,false,{toggleAction='rp_banking:interact'}) then close() return end
    active.opened=true
    PlaySoundFrontend(-1,'PIN_BUTTON','ATM_SOUNDS',true)
end
local function register()
    exports.rp_core:rpRegisterInputAction({id='rp_banking:interact',label='Geldautomat benutzen',category='Interaktionen',
        defaultKey='E',description='Den angezeigten Geldautomaten öffnen / schließen.'})
    exports.rp_ui:rpRegisterAction('rp_banking:action',function(data)
        if not active or exports.rp_ui:rpGetView()~='banking' or type(data)~='table' or data.session~=active.token then return {ok=false,error='session_expired'} end
        local ok,result=pcall(lib.callback.await,'rp_banking:action',false,data)
        PlaySoundFrontend(-1,ok and result and result.ok and 'PIN_BUTTON' or 'ERROR','ATM_SOUNDS',true)
        return ok and result or {ok=false,error='unavailable'}
    end)
end
CreateThread(function()
    while not uiReady() do Wait(1000) end
    register()
    if C.blips then
        for _,location in ipairs(B.locations) do
            local blip=AddBlipForCoord(location.x,location.y,location.z)
            SetBlipSprite(blip,277) SetBlipScale(blip,0.55) SetBlipColour(blip,2) SetBlipAsShortRange(blip,true)
            BeginTextCommandSetBlipName('STRING') AddTextComponentString('Geldautomat') EndTextCommandSetBlipName(blip)
            blips[#blips+1]=blip
        end
    end
    while true do
        if not uiReady() then
            if active or pending then close() end
            nearby=nil
        elseif active then
            local ped=PlayerPedId()
            if not ESX.IsPlayerLoaded() or ped~=active.ped or IsPedDeadOrDying(ped,true) or IsPedInAnyVehicle(ped,false)
                or not DoesEntityExist(active.point.entity) or B.distance(GetEntityCoords(ped),GetEntityCoords(active.point.entity))>2.2
                or (active.opened and exports.rp_ui:rpGetView()~='banking') then close() end
            exports.rp_ui:rpHideInteraction()
        else
            nearby=findNearby()
            if nearby and not pending then
                exports.rp_ui:rpShowInteraction({action='rp_banking:interact',label=C.brands[nearby.brand],verb='Geldautomat benutzen',icon='bank',distance=nearby.distance})
            else exports.rp_ui:rpHideInteraction() end
        end
        Wait((nearby or active) and 250 or 1000)
    end
end)
AddEventHandler('rp_core:inputPressed',function(action)
    if action=='rp_banking:interact' and exports.rp_ui:rpIsInteractionActive(action) then CreateThread(open) end
end)
RegisterCommand('rp_atm',function() CreateThread(open) end,false)
RegisterNetEvent('rp_banking:hide',function() if source==65535 then close() end end)
RegisterNetEvent('rp_banking:received',function(amount,name)
    if source~=65535 or type(amount)~='number' or type(name)~='string' then return end
    lib.notify({title='Überweisung eingegangen',description=('$%s von %s'):format(amount,name),type='success'})
end)
AddEventHandler('esx:onPlayerLogout',close)
AddEventHandler('onClientResourceStart',function(resource) if (resource=='rp_ui' or resource=='rp_core') and uiReady() then register() end end)
AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() and resource~='rp_ui' and resource~='rp_core' then return end
    pcall(close)
    if resource==GetCurrentResourceName() then
        for _,blip in ipairs(blips) do RemoveBlip(blip) end
        blips={}
    end
end)
