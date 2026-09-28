local ESX = exports.es_extended:getSharedObject()
local sessions, requests = {}, {}
local C = PlayerConfig
local ready = false
local function level(s) return PlayerProgress.level(s.meters) end
local function save(s)
    if not s.loaded then return end
    MySQL.update([[INSERT INTO rp_player_progress (identifier, running_meters, training_seconds) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE running_meters = GREATEST(running_meters, VALUES(running_meters)),
        training_seconds = GREATEST(training_seconds, VALUES(training_seconds))]],
        { s.identifier, math.floor(s.meters), math.floor(s.seconds) })
end
local function getSession(source, player)
    local s = sessions[source]
    if s and s.identifier == player.identifier then return s.loaded and s or nil end
    s = { identifier = player.identifier, meters = 0, seconds = 0, loaded = false, savedAt = os.time() }
    sessions[source] = s
    local ok, row = pcall(MySQL.single.await, 'SELECT running_meters, training_seconds FROM rp_player_progress WHERE identifier = ?', { s.identifier })
    -- Cross-resource ESX calls may deserialize a new table for the same player.
    -- Compare the character identity and our session, never table identity.
    local current = ESX.GetPlayerFromId(source)
    if sessions[source] ~= s or not current or current.identifier ~= s.identifier or not current.spawned then return nil end
    if not ok then sessions[source] = nil return nil end
    s.meters, s.seconds, s.loaded = row and tonumber(row.running_meters) or 0, row and tonumber(row.training_seconds) or 0, true
    TriggerClientEvent('rp_player:fitnessChanged', source, level(s))
    return s
end

lib.callback.register('rp_player:profile', function(source)
    local now = GetGameTimer()
    if requests[source] and now - requests[source] < 1000 then return { ok = false, error = 'rate_limited' } end
    requests[source] = now
    local player = ESX.GetPlayerFromId(source)
    if not ready or not player or not player.spawned then return { ok = false, error = 'player_unavailable' } end
    local s = getSession(source, player)
    if not s then return { ok = false, error = 'player_unavailable' } end
    local job = player.getJob()
    local bank = player.getAccount('bank')
    return { ok = true, profile = {
        name = player.getName(), firstname = player.get('firstName') or '', lastname = player.get('lastName') or '',
        birthdate = player.get('dateofbirth') or '', height = tonumber(player.get('height')) or 180,
        job = job.label, grade = job.grade_label or '', cash = player.getMoney(), bank = bank and bank.money or 0,
        level = level(s), runningMeters = math.floor(s.meters), trainingSeconds = math.floor(s.seconds),
        metersPerLevel = C.metersPerLevel, maxLevel = C.maxLevel,
    } }
end)

MySQL.ready(function()
    ready = pcall(MySQL.query.await, 'SELECT identifier FROM rp_player_progress LIMIT 0')
    if not ready then print('[rp_player] Import migrations/001_player_progress.sql.') end
end)
CreateThread(function()
    while true do
        Wait(C.sampleSeconds * 1000)
        if ready then
            for _, id in ipairs(GetPlayers()) do
                local source = tonumber(id)
                local player = ESX.GetPlayerFromId(source)
                if player and player.spawned then
                    local s = getSession(source, player)
                    local ped = GetPlayerPed(source)
                    if s and ped ~= 0 and DoesEntityExist(ped) then
                        local coords, now = GetEntityCoords(ped), GetGameTimer()
                        local eligible = GetEntityHealth(ped) > 0 and GetVehiclePedIsIn(ped, false) == 0 and GetPlayerRoutingBucket(source) == 0
                        if eligible and s.last and s.eligible then
                            local elapsed = (now - s.time) / 1000
                            local distance, seconds = PlayerProgress.sample(s.last, coords, elapsed, eligible, s.eligible)
                            if distance > 0 then
                                local oldLevel = level(s)
                                s.meters = math.min(100000000, s.meters + distance)
                                s.seconds = math.min(1000000000, s.seconds + seconds)
                                if level(s) ~= oldLevel then TriggerClientEvent('rp_player:fitnessChanged', source, level(s)) end
                            end
                        end
                        s.last, s.time, s.eligible = coords, now, eligible
                        if os.time() - s.savedAt >= C.saveSeconds then save(s) s.savedAt = os.time() end
                    end
                end
            end
        end
    end
end)
local function clearSession(id)
    local s = sessions[id]
    sessions[id], requests[id] = nil, nil
    if s then save(s) end
end
AddEventHandler('playerDropped', function() clearSession(source) end)
AddEventHandler('esx:playerLogout', clearSession)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, s in pairs(sessions) do save(s) end
end)
