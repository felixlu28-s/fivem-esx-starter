-- Real lifecycle adapter with a deterministic scheduler. A missing browser must
-- never prevent exit; restarting UI must not steal another menu's input focus.
local count = 0
local function check(value, label) assert(value, label) count = count + 1 end
local function setup(active)
    local api, timers, handlers, messages = {}, {}, {}, {}
    local native, nui = 0, 0
    function exports(name, fn) api[name] = fn end
    function SetTimeout(delay, fn) timers[#timers + 1] = { delay = delay, fn = fn } end
    function AddEventHandler(name, fn) handlers[name] = fn end
    function GetCurrentResourceName() return 'rp_ui' end
    function GetIsLoadingScreenActive() return active end
    function ShutdownLoadingScreen() native = native + 1 end
    function ShutdownLoadingScreenNui() nui = nui + 1 end
    function SetNuiFocus() error('loading must not alter gameplay focus') end
    function SendLoadingScreenMessage(message) messages[#messages + 1] = message return false end
    json = { encode = function(value) return value end }
    dofile('server-data/resources/[custom]/rp_ui/client/loading.lua')
    return api, timers, handlers, messages, function() return native, nui end
end

local api, timers, handlers, messages, counts = setup(true)
check(#timers == 1 and timers[1].delay == 120000, 'one bounded watchdog, no polling loop')
check(not api.rpLoadingPhase('arbitrary'), 'unknown stage rejected')
check(api.rpLoadingPhase('session') and api.rpLoadingPhase('scene'), 'supported handoff stages')
check(messages[1].action == 'ui:loading' and messages[2].data.phase == 'scene', 'typed envelope')
api.rpFinishLoading()
local native, nui = counts()
check(native == 1 and nui == 0, 'game loading ends while NUI can finish its fade')
check(#timers == 2 and timers[2].delay == 650, 'exit does not await browser acknowledgement')
check(messages[3].data.phase == 'exiting', 'fade starts before NUI shutdown')
api.rpFinishLoading()
check(#timers == 2 and #messages == 3, 'duplicate spawn/scene completion is idempotent')
check(not api.rpLoadingPhase('session'), 'late stages cannot undo fade')
timers[2].fn()
native, nui = counts()
check(nui == 1, 'failed browser message still ends loading frame')
timers[1].fn()
handlers.onResourceStop('rp_ui')
check(select(2, counts()) == 1, 'watchdog and stop do not repeat successful teardown')

api, timers, handlers, messages, counts = setup(false)
timers[1].fn()
check(select(2, counts()) == 1, 'watchdog releases NUI even if game loading was already shut down')
api, timers, handlers, messages, counts = setup(true)
handlers.onResourceStop('unrelated')
check(select(2, counts()) == 0, 'unrelated resource stop leaves loading untouched')
api.rpFinishLoading()
handlers.onResourceStop('rp_ui')
check(select(2, counts()) == 1, 'own resource stop immediately closes during fade')
timers[2].fn()
check(select(2, counts()) == 1, 'delayed fade cannot repeat teardown after stop')
print(('PASS: %d loading lifecycle checks'):format(count))
