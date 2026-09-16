local ESX = exports.es_extended:getSharedObject()
local resourceName = GetCurrentResourceName()

local function log(message)
    print(('[%s] %s'):format(resourceName, message))
end

local function getPlayer(playerId)
    if type(playerId) ~= 'number' or playerId <= 0 then
        return nil
    end

    return ESX.GetPlayerFromId(playerId)
end

exports('GetPlayer', getPlayer)

lib.callback.register('rp_core:getServerTime', function(source)
    if not getPlayer(source) then
        return nil
    end

    return os.time()
end)

AddEventHandler('onResourceStart', function(startedResource)
    if startedResource ~= resourceName then
        return
    end

    log('ready')
end)
