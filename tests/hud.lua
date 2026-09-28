local base = 'server-data/resources/[custom]/'
local passed, threads, events, messages = 0, {}, {}, {}
local function check(value, label) assert(value, label) passed = passed + 1 end
local loaded, paused, faded, focused, view = false, false, false, false, nil
local data = {accounts={{name='bank',money=99999},{name='money',money=2450}}}
local connected, talking, range, safe, pma = true, false, 3, 0.9, false
local esx = {IsPlayerLoaded=function() return loaded end, GetPlayerData=function() return data end}
exports = {es_extended={getSharedObject=function() return esx end}, rp_ui={rpGetView=function() return view end}}
GlobalState = {['rp_core:playerCount']=24}
LocalPlayer = {state={}}
function CreateThread(fn) threads[#threads+1] = fn end
function AddEventHandler(name, fn) events[name] = fn end
function Wait() coroutine.yield() end
function IsPauseMenuActive() return paused end
function IsScreenFadedOut() return faded end
function IsNuiFocused() return focused end
function PlayerId() return 0 end
function GetPlayerServerId() return 12 end
function GetSafeZoneSize() return safe end
function GetResourceState() return pma and 'started' or 'missing' end
function MumbleIsConnected() return connected end
function MumbleGetTalkerProximity() return range end
function NetworkIsPlayerTalking() return talking end
function GetCurrentResourceName() return 'rp_ui' end
function SetNuiFocus() error('HUD must never acquire focus') end
function TriggerServerEvent() error('HUD must not send gameplay requests') end
function SendNUIMessage(value) messages[#messages+1] = value end
json = {encode=function(v)
    if v == false then return 'false' end
    local values = {}
    for _, k in ipairs({'cash','id','players','connected','talking','range','inset'}) do values[#values+1]=tostring(v[k]) end
    return table.concat(values, ':')
end}
dofile(base .. 'rp_ui/client/hud.lua')
local loop = coroutine.create(threads[1])
local function tick() local ok, err = coroutine.resume(loop) assert(ok, err) return messages[#messages].data end
check(tick() == false, 'unloaded player has no HUD')
loaded = true
local hud = tick()
check(hud.cash == 2450 and hud.players == 24 and hud.id == 12, 'ESX cash (not bank), global count and server ID')
check(hud.range == 3 and not hud.talking and hud.connected, 'native proximity and silent voice')
check(math.abs(hud.inset - 0.05) < 0.001, 'respects GTA safe zone')
local sent = #messages
tick()
check(#messages == sent, 'unchanged data not sent repeatedly')
data = {accounts={{name='money',money=0}}}
check(tick().cash == 0, 'fresh ESX snapshot and legitimate zero balance')
data = {accounts={}}
check(tick().cash == false, 'missing account does not invent zero cash')
talking = true
check(tick().talking, 'live speaking state')
pma, LocalPlayer.state.proximity = true, {distance=1.5}
check(tick().range == 1.5, 'pma voice range adapter')
pma = false
check(tick().range == 3, 'stopped voice resource cannot leave stale range')
connected = false
hud = tick()
check(not hud.connected and not hud.talking and hud.range == false, 'offline voice has no fabricated range or talking')
connected, range = true, 0
check(tick().range == false, 'unconfigured range is unknown')
range = 0/0
check(tick().range == false, 'invalid native range rejected')
GlobalState['rp_core:playerCount'] = nil
check(tick().players == false, 'unknown count is not nearby streamed players')
view = 'characters'
check(tick() == false, 'hidden during character creation')
view, focused = 'nativeui', true
check(type(tick()) == 'table', 'visible with keyboard-only native menu')
view = 'inventory'
check(tick() == false, 'large menu hides HUD')
view = nil
check(tick() == false, 'foreign NUI focus hides HUD')
focused, paused = false, true
check(tick() == false, 'pause hides HUD')
paused, faded = false, true
check(tick() == false, 'black screen hides HUD')
faded = false
tick()
sent = #messages
events['rp_ui:ready']()
tick()
check(#messages == sent + 1, 'browser reload gets current HUD')
loaded = false
check(tick() == false, 'logout removes previous character data')
events.onResourceStop('rp_ui')
check(messages[#messages].data == false, 'resource stop clears HUD')
threads, events = {}, {}
local players = {'1','7','18'}
function GetPlayers() return players end
function GetCurrentResourceName() return 'rp_core' end
dofile(base .. 'rp_core/server/presence.lua')
loop = coroutine.create(threads[1])
check(coroutine.resume(loop) and GlobalState['rp_core:playerCount'] == 3, 'server counts all connected players')
players = {'1'}
check(coroutine.resume(loop) and GlobalState['rp_core:playerCount'] == 1, 'disconnect reflected')
players = {}
check(coroutine.resume(loop) and GlobalState['rp_core:playerCount'] == 0, 'empty server reflected')
events.onResourceStop('rp_core')
check(GlobalState['rp_core:playerCount'] == nil, 'server stop clears stale count')
print(('PASS: %d HUD lifecycle, ESX, voice and server presence assertions'):format(passed))
