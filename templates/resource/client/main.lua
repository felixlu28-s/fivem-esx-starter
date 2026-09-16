local resourceName = GetCurrentResourceName()

AddEventHandler('onClientResourceStart', function(startedResource)
    if startedResource ~= resourceName or not Config.debug then
        return
    end

    print(('[%s] client ready'):format(resourceName))
end)
