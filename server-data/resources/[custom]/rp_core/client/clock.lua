local sample, receivedAt, preview, owner
local originalMinute = GetMillisecondsPerGameMinute()

local function receive(value)
    if not RP.Clock.valid(value) then return end
    sample, receivedAt = value, GetGameTimer()
end

local function apply()
    if not preview and not sample then return end
    local seconds = preview and preview * 3600
        or (sample.seconds + math.floor(math.max(0, GetGameTimer() - receivedAt) / 1000)) % 86400
    SetMillisecondsPerGameMinute(60000)
    NetworkOverrideClockTime(math.floor(seconds / 3600), math.floor(seconds / 60) % 60, seconds % 60)
end

AddStateBagChangeHandler('rp_core:worldClock', 'global', function(_, _, value) receive(value) end)
receive(GlobalState['rp_core:worldClock'])

-- Local presentation override, owned by its caller; never changes server world time.
exports('rpSetClockPreview', function(hour)
    local caller = GetInvokingResource()
    if not caller or (owner and owner ~= caller) then return false end
    if hour ~= nil and (type(hour) ~= 'number' or hour < 0 or hour > 23 or hour % 1 ~= 0) then return false end
    preview, owner = hour, hour ~= nil and caller or nil
    apply()
    return true
end)

CreateThread(function()
    while true do
        apply()
        Wait(250)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        NetworkClearClockTimeOverride()
        SetMillisecondsPerGameMinute(originalMinute)
    elseif resource == owner then
        preview, owner = nil, nil
        apply()
    end
end)
