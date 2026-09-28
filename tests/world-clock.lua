local base = 'server-data/resources/[custom]/rp_core/'
local count = 0
local function check(value, message) assert(value, message) count = count + 1 end
dofile(base .. 'shared/clock.lua')
local C = RP.Clock
local function at(epoch, expected, offset)
    local value = C.fromUtc(os.date('!*t', epoch))
    check(value.seconds == expected and value.offset == offset, 'Berlin time at UTC epoch ' .. epoch)
end
at(1767225600, 3600, 3600) -- 2026-01-01 00:00 UTC
at(1774745999, 7199, 3600) -- 2026-03-29 00:59:59 UTC
at(1774746000, 10800, 7200) -- Spring skips 02:00
at(1792889999, 10799, 7200) -- 2026-10-25 00:59:59 UTC
at(1792890000, 7200, 3600) -- Autumn repeats 02:00
at(1806195599, 7199, 3600) -- 2027-03-28 00:59:59 UTC
at(1806195600, 10800, 7200)
at(1824944399, 10799, 7200) -- 2027-10-31 00:59:59 UTC
at(1824944400, 7200, 3600)
at(1782860400, 3600, 7200) -- 2026-06-30 23:00 UTC, local next day
check(not C.valid({seconds = 86400, offset = 3600}), 'out-of-range native clock rejected')
check(not C.valid({seconds = 0/0, offset = 3600}), 'NaN rejected')
check(not C.valid({seconds = 1.5, offset = 3600}), 'fractional seconds rejected')
check(not C.valid({seconds = 1, offset = 999}), 'unsupported offset rejected')

local threads, events, api = {}, {}, {}
local timer, invoking, current, minute, cleared = 0, 'rp_characters', nil, 2000, false
local changed
GlobalState = {['rp_core:worldClock'] = {seconds = 86399, offset = 7200}}
function GetGameTimer() return timer end
function GetMillisecondsPerGameMinute() return minute end
function SetMillisecondsPerGameMinute(value) minute = value end
function NetworkOverrideClockTime(h, m, s)
    assert(h >= 0 and h < 24 and m >= 0 and m < 60 and s >= 0 and s < 60)
    current = h * 3600 + m * 60 + s
end
function NetworkClearClockTimeOverride() cleared = true end
function GetInvokingResource() return invoking end
function GetCurrentResourceName() return 'rp_core' end
function AddStateBagChangeHandler(key, bag, fn)
    check(key == 'rp_core:worldClock' and bag == 'global', 'only server global clock is subscribed')
    changed = fn
end
function CreateThread(fn) threads[#threads + 1] = fn end
function Wait(ms) coroutine.yield(ms) end
function AddEventHandler(name, fn) events[name] = fn end
exports = function(name, fn) api[name] = fn end
dofile(base .. 'client/clock.lua')
local loop = coroutine.create(threads[1])
check(coroutine.resume(loop) and current == 86399 and minute == 60000, 'initial state applied with real minute length')
timer = 2000
check(coroutine.resume(loop) and current == 1, 'interpolation crosses midnight safely')
changed(nil, nil, {seconds = -10, offset = 3600})
check(coroutine.resume(loop) and current == 1, 'invalid replicated value does not replace good sample')
changed(nil, nil, {seconds = 45000, offset = 3600})
check(coroutine.resume(loop) and current == 45000, 'fresh server time corrects drift and offset')
check(not api.rpSetClockPreview(24) and not api.rpSetClockPreview(0/0), 'invalid preview rejected')
check(api.rpSetClockPreview(12) and current == 43200, 'creator has bright noon preview')
timer = 5000
changed(nil, nil, {seconds = 50000, offset = 3600})
check(coroutine.resume(loop) and current == 43200, 'server resync does not disturb studio')
invoking = 'rp_other'
check(not api.rpSetClockPreview(nil) and not api.rpSetClockPreview(7), 'another resource cannot replace or release owned preview')
invoking = 'rp_characters'
check(api.rpSetClockPreview(nil) and current == 50000, 'leaving creator immediately restores latest world time')
check(api.rpSetClockPreview(0) and current == 0, 'midnight preview is valid')
events.onResourceStop('rp_characters')
check(current == 50000, 'stopped preview owner releases override')
events.onResourceStop('rp_core')
check(cleared and minute == 2000, 'core stop clears override and restores original pace')

-- Real server publisher: UTC calendar conversion, no player-settable event.
local originalDate = os.date
os.date = function(format)
    check(format == '!*t', 'host timezone cannot affect source calendar')
    return originalDate('!*t', 1774746000)
end
threads, GlobalState = {}, {}
dofile(base .. 'server/clock.lua')
local publisher = coroutine.create(threads[1])
local ok, delay = coroutine.resume(publisher)
check(ok and delay == 1000 and GlobalState['rp_core:worldClock'].seconds == 10800, 'server publishes once per second from UTC')
os.date = originalDate
print(('PASS: %d German world clock assertions'):format(count))
