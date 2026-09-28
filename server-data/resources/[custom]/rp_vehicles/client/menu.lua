local ESX=exports.es_extended:getSharedObject()
local ui=exports.rp_nativeui
local pending,menu,location=false,nil,nil
local rows={}
local function register()
    exports.rp_core:rpRegisterInputAction({id='rp_vehicles:garage',label='Garage öffnen',category='Interaktionen',
        defaultKey='E',description='Beim Mitarbeiter ein Fahrzeug ein- oder ausparken.'})
end
local errors={ busy='Der Mitarbeiter ist gerade unterwegs.', park_at_handover='Stelle dein Fahrzeug auf den Übergabeplatz und steige aus.',
    recovery_vehicle='Bitte zuerst das unterbrochene Fahrzeug aus der Einfahrt holen.',
    already_outside='Dieses Fahrzeug ist bereits ausgeparkt.', parking_blocked='Bitte den Übergabeplatz freihalten.',
    not_stored_here='Dieses Fahrzeug ist hier nicht eingelagert.' }
local function close()
    if menu then ui:rpDestroyMenu(menu) menu=nil end
    location=nil
end
local function select(id)
    if pending or Garage.Scene.active then return end
    local row=rows[id]
    if not row then return end
    pending=true
    local garageId=location
    CreateThread(function()
        local condition
        if not row.stored and row.netId and NetworkDoesEntityExistWithNetworkId(row.netId) then
            local vehicle=NetworkGetEntityFromNetworkId(row.netId)
            condition={fuelLevel=GetVehicleFuelLevel(vehicle),engineHealth=GetVehicleEngineHealth(vehicle),
                bodyHealth=GetVehicleBodyHealth(vehicle),tankHealth=GetVehiclePetrolTankHealth(vehicle)}
        end
        local ok,result=pcall(lib.callback.await,'rp_vehicles:start',false,garageId,row.stored and 'out' or 'in',row.plate,condition)
        pending=false
        if ok and result and result.ok then
            Garage.Scene.active=result.token
            Garage.World.react(garageId,'acknowledge')
            close()
            lib.notify({title='Parkservice',description='Der Mitarbeiter kümmert sich um dein Fahrzeug. Bitte halte den Fahrweg frei.'})
        else
            lib.notify({title='Parkservice',description=errors[result and result.error] or 'Das Fahrzeug ist gerade nicht verfügbar. Menü erneut öffnen.',type='error'})
        end
    end)
end
local function open()
    if menu then close() return end
    if pending or Garage.Scene.active or not ESX.IsPlayerLoaded() or IsNuiFocused() or IsEntityDead(PlayerPedId()) then return end
    local id=Garage.World.nearest()
    if not id then return end
    pending=true
    local ok,result=pcall(lib.callback.await,'rp_vehicles:list',false,id)
    pending=false
    if not ok or not result or not result.ok or Garage.World.nearest()~=id then return end
    location,rows=id,{}
    local items={}
    for index,row in ipairs(result.vehicles) do
        local itemId='vehicle_'..index
        rows[itemId]=row
        local model=type(row.model)=='string' and joaat(row.model) or row.model
        local label=model and GetLabelText(GetDisplayNameFromVehicleModel(model)) or 'Fahrzeug'
        if label=='NULL' or label=='' then label='Fahrzeug' end
        items[#items+1]={id=itemId,label=label..' · '..row.plate,
            rightLabel=row.stored and (row.available and 'Ausparken' or 'Andere Garage') or 'Einparken',
            disabled=result.busy or (row.stored and not row.available) or (not row.stored and not row.canStore),
            description=row.stored and 'Der Mitarbeiter fährt dein Fahrzeug zum Übergabeplatz.'
                or 'Fahrzeug auf dem Übergabeplatz abstellen, aussteigen und hier einparken.'}
    end
    if #items==0 then items={{id='empty',label='Keine eigenen Fahrzeuge',disabled=true,description='Hier erscheinen die Fahrzeuge deines aktiven ESX-Charakters.'}} end
    menu=ui:rpCreateMenu('garage',{title='Los Santos',subtitle=Garage.Config.garages[id].label,theme='mint',visibleRows=7,
        description='Parkservice · Ein- und Ausparken',items=items},{onSelect=select,onClose=function() location=nil end})
    if not menu or not ui:rpOpenMenu(menu,{toggleAction='rp_vehicles:garage'}) then close() end
end
CreateThread(function()
    register()
    while true do
        local id,distance
        if ESX.IsPlayerLoaded() and not IsEntityDead(PlayerPedId()) then id,distance=Garage.World.nearest() end
        if menu and (not id or not location or location~=id) then close() end
        if id and not Garage.Scene.active then
            exports.rp_ui:rpShowInteraction({action='rp_vehicles:garage',label=Garage.Config.garages[id].label,
                verb='Parkservice',icon='shop',distance=distance})
        elseif not Garage.Editor or not Garage.Editor.placing then exports.rp_ui:rpHideInteraction() end
        Wait(200)
    end
end)
AddEventHandler('rp_core:inputPressed',function(action)
    if action=='rp_vehicles:garage' and exports.rp_ui:rpIsInteractionActive(action) then CreateThread(open) end
end)
RegisterCommand('rp_garage',function() CreateThread(open) end,false)
AddEventHandler('onClientResourceStart',function(name) if name=='rp_core' then register() end end)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then close() exports.rp_ui:rpHideInteraction() end end)
