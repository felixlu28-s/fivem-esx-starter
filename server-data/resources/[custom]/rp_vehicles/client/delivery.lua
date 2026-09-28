local active
local function clear()
    local old=active active=nil
    if old and old.blip then RemoveBlip(old.blip) end
end
RegisterNetEvent('rp_vehicles:deliveryBlip',function(ticket,net,plate)
    if source~=65535 or type(ticket)~='string' or #ticket>80 or not Garage.Rules.integer(net,1,65535) or not Garage.Rules.plate(plate) then return end
    clear()
    local entry={ticket=ticket,net=net,plate=plate} active=entry
    CreateThread(function()
        local deadline=GetGameTimer()+15000
        while active==entry do
            if IsEntityDead(PlayerPedId()) then break end
            local entity=NetworkDoesEntityExistWithNetworkId(net) and NetworkGetEntityFromNetworkId(net)
            if entity and DoesEntityExist(entity) then
                if Garage.Rules.plate(GetVehicleNumberPlateText(entity))~=plate then
                    if entry.blip or GetGameTimer()>deadline then break end
                    entity=nil -- wait for the server's plate RPC to reach the freshly streamed entity
                end
            end
            if entity and DoesEntityExist(entity) then
                if GetVehiclePedIsIn(PlayerPedId(),false)==entity then break end
                deadline=GetGameTimer()+15000
                if not entry.blip then
                    entry.blip=AddBlipForEntity(entity)
                    SetBlipSprite(entry.blip,225) SetBlipColour(entry.blip,2) SetBlipScale(entry.blip,0.8)
                    SetBlipAsShortRange(entry.blip,false)
                    BeginTextCommandSetBlipName('STRING') AddTextComponentString('Dein Fahrzeug · '..plate) EndTextCommandSetBlipName(entry.blip)
                end
            elseif GetGameTimer()>deadline then break end
            Wait(250)
        end
        if active==entry then clear() end
    end)
end)
RegisterNetEvent('rp_vehicles:finish',function(ticket,ok,_,_,retained)
    if source==65535 and not ok and not retained and active and active.ticket==ticket then clear() end
end)
AddEventHandler('esx:onPlayerLogout',clear)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() then clear() end end)
