-- Actual client retry route, with FiveM/NUI/SQL responses mocked.
local root = 'server-data/resources/[custom]/rp_characters/'
dofile(root .. 'shared/config.lua')
dofile(root .. 'shared/wardrobe.lua')
dofile(root .. 'shared/appearance.lua')
dofile(root .. 'shared/validation.lua')
local routes, threads, responses, waits, displays, events = {}, {}, {}, {}, {}, {}
local calls, expected = {}, 'rp_characters:bootstrap'
local A = Characters.Appearance
local appliedSkin
A.current = function() return appliedSkin or A.defaults(0) end
A.catalog = function() return {} end
A.apply = function(skin) appliedSkin = skin return true end
Characters.Scene = { prepare = function() return true end, clear = function() end }
local esx = { IsPlayerLoaded = function() return true end }
exports = {
    es_extended = { getSharedObject = function() return esx end },
    rp_ui = {
        rpFinishLoading = function() end,
        rpLoadingPhase = function() end,
        rpRegisterAction = function(_, name, fn) routes[name] = fn end,
        rpOpen = function(_, _, payload) displays[#displays + 1] = payload end,
    },
}
lib = { callback = { await = function(name, _, input)
    if expected then assert(name == expected, 'retry targets same request') end
    calls[#calls + 1] = { name = name, input = input }
    local result = table.remove(responses, 1)
    assert(result, 'unexpected extra request')
    return result
end } }
function AddEventHandler(name, fn) events[name] = fn end
local networkEvents = {}
function RegisterNetEvent(name, fn) networkEvents[name] = true AddEventHandler(name, fn) end
function CreateThread(fn) threads[#threads + 1] = fn end
function PlayerId() return 1 end
function NetworkIsPlayerActive() return true end
function GetGameTimer() return 0 end
function Wait(delay) waits[#waits + 1] = delay end
dofile(root .. 'client/main.lua')
threads[1]() -- Registers routes; an already loaded player skips scene natives.

-- A fresh client environment is needed because bootstrap above marks phase active.
esx.IsPlayerLoaded = function() return false end
-- Capture registered retry route before the scene starts, stopping at its first yield.
routes, threads = {}, {}
function NetworkIsPlayerActive() return false end
function Wait(delay) waits[#waits + 1] = delay coroutine.yield() end
dofile(root .. 'client/main.lua')
local initial = coroutine.create(threads[1])
assert(coroutine.resume(initial))
function Wait(delay) waits[#waits + 1] = delay end
local count = 0
local function check(value, message) assert(value, message) count = count + 1 end
local success = { ok = true, characters = {}, slots = 1 }
responses, waits, displays = {{ok=false,error='rate_limited',retryAfterMs=650}, success}, {}, {}
check(routes['rp_characters:refresh']().ok, 'retry recovers transient rate limit')
check(#waits == 1 and waits[1] == 700, 'waits for server cooldown plus margin')
check(#displays == 1 and displays[1].mode == 'creator', 'transient cooldown never displays interrupted arrival')
responses, waits, displays = {{ok=false,error='database_error'}}, {}, {}
check(routes['rp_characters:refresh']().error == 'database_error' and #waits == 0, 'real database failure is not retried or masked')
check(displays[1].error == 'database_error', 'real failure remains visible')
responses, waits = {{ok=false,error='rate_limited',retryAfterMs=math.huge}, {ok=false,error='rate_limited',retryAfterMs=-1}, {ok=false,error='rate_limited'}}, {}
check(routes['rp_characters:refresh']().error == 'rate_limited', 'repeated throttling stops after three requests')
check(#waits == 2 and waits[1] == 2050 and waits[2] == 150, 'server-provided retry delay is bounded')
-- A stale/full roster or a lost commit response must recover the saved slot.
expected = nil
local savedSkin = A.defaults(1)
savedSkin.hair_1, savedSkin.hair_color_1 = 12, 5
responses, displays, calls = {
    { ok = false, error = 'character_limit' },
    { ok = true, slots = 1, characters = { { slot = 1, skin = savedSkin } } },
    { ok = false, error = 'server_starting' },
}, {}, {}
check(not routes['rp_characters:create']({}).ok, 'stale creator reconciles quota error')
check(appliedSkin == savedSkin and appliedSkin.sex == 1 and appliedSkin.hair_1 == 12, 'automatic selection previews saved model and appearance before ESX login')
check(#calls == 3 and calls[2].name == 'rp_characters:bootstrap' and calls[3].name == 'rp_characters:select', 'full quota refreshes and selects saved character')
check(displays[#displays].mode == 'error' and displays[#displays].error == 'server_starting', 'login failure leaves creator for recovery screen')
responses = { success }
check(routes['rp_characters:refresh']().ok, 'reset fixture to empty account')
responses, calls = {
    { ok = false, error = 'unavailable' },
    { ok = true, slots = 1, characters = { { slot = 1 } } },
    { ok = false, error = 'server_starting' },
}, {}
check(not routes['rp_characters:create']({}).ok and calls[3].name == 'rp_characters:select', 'lost creation reply recovers committed character without another create')
responses = { success }
check(routes['rp_characters:refresh']().ok, 'reset fixture before acknowledged commit')
responses, displays, calls = {
    { ok = true, slot = 1 },
    { ok = false, error = 'server_starting' },
}, {}, {}
check(not routes['rp_characters:create']({}).ok, 'commit success with login failure reported')
check(#calls == 2 and calls[2].name == 'rp_characters:select' and calls[2].input.slot == 1, 'client selects returned committed slot')
check(displays[#displays].mode == 'error', 'committed character cannot return to creation form')
check(routes['rp_characters:create']({}).error == 'invalid_state', 'second creation is blocked after commit')
responses, calls = {{ ok = true }}, {}
check(routes['rp_characters:refresh']().ok, 'retry resumes pending character')
check(#calls == 1 and calls[1].name == 'rp_characters:select' and calls[1].input.slot == 1, 'retry only selects and never creates')
check(displays[#displays].mode == 'loading', 'successful resume displays arrival loading')
-- The official ESX server spawn event is essential for saves and other scripts.
local serverSpawns, localSpawns, closed, previewReleased = 0, 0, false, false
exports.rp_core = {rpSetClockPreview = function(_, hour) previewReleased = hour == nil return true end}
function TriggerServerEvent(name) if name == 'esx:onPlayerSpawn' then serverSpawns = serverSpawns + 1 end end
function TriggerEvent(name) if name == 'esx:onPlayerSpawn' then localSpawns = localSpawns + 1 end end
function DoScreenFadeOut() end
function DoScreenFadeIn() end
function ShutdownLoadingScreen() end
function ShutdownLoadingScreenNui() end
function PlayerPedId() return 1 end
function FreezeEntityPosition() end
function SetEntityCollision() end
function SetEntityInvincible() end
function SetEntityVisible() end
function SetPlayerControl() end
function DisplayRadar() end
function NetworkClearClockTimeOverride() end
local weatherCleared = false
function ClearOverrideWeather() weatherCleared = true end
A.destroyCamera = function() end
esx.SpawnPlayer = function(skin, _, callback)
    check(skin == A.current() and skin.hair_1 == 12 and skin.sex == 1, 'ESX spawns with applied saved appearance')
    callback()
end
exports.rp_ui.rpClose = function() closed = true end
check(networkEvents['esx:playerLoaded'], 'ESX login handler must be registered as network-safe in this resource')
source = 0
local threadCount = #threads
events['esx:playerLoaded']()
check(#threads == threadCount, 'local forged login event ignored')
source = 65535
responses, calls = { { ok = true, skin = savedSkin, position = {} }, { ok = true } }, {}
events['esx:playerLoaded']()
events['esx:playerLoaded']()
check(#threads == threadCount + 1, 'duplicate server delivery cannot start concurrent spawns')
threads[#threads]()
check(serverSpawns == 1 and localSpawns == 1, 'successful spawn notifies both ESX server and client')
check(calls[1].name == 'rp_characters:spawnData' and calls[2].name == 'rp_characters:spawned', 'server-owned spawn data and final acknowledgement used')
check(closed, 'UI closes after official ESX spawn handshake and acknowledgement')
check(weatherCleared, 'preview weather override is cleared on entry')
check(previewReleased, 'entry releases studio clock back to server German time')
print(('PASS: %d character client retry checks'):format(count))
