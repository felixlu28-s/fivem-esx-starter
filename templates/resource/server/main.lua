local ESX = exports.es_extended:getSharedObject()
local resourceName = GetCurrentResourceName()

lib.callback.register('__RESOURCE__:health', function(source)
    if not ESX.GetPlayerFromId(source) then
        return nil
    end

    return { ok = true }
end)

AddEventHandler('onResourceStart', function(startedResource)
    if startedResource ~= resourceName or not Config.debug then
        return
    end

    print(('[%s] server ready'):format(resourceName))
end)
