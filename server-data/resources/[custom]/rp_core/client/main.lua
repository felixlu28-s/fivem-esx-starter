local ESX = exports.es_extended:getSharedObject()

exports('GetESX', function()
    return ESX
end)

RegisterCommand('rp_time', function()
    local serverTime = lib.callback.await('rp_core:getServerTime', false)

    if not serverTime then
        return
    end

    print(('Server time: %d'):format(serverTime))
end, false)
