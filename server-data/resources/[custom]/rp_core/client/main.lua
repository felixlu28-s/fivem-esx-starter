local ESX = exports.es_extended:getSharedObject()

CreateThread(function()
    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:addSpawnPoint({
        x = -1037.74,
        y = -2737.82,
        z = 20.17,
        heading = 330.0,
        model = joaat('mp_m_freemode_01'),
        skipFade = false,
    })
end)

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
