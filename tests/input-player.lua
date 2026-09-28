local base = 'server-data/resources/[custom]/'
local passed = 0
local function check(value, message) assert(value, message) passed = passed + 1 end
dofile(base .. 'rp_core/shared/input.lua')
local I, seen = RP.Input, {}
local defaults = I.defaults()
check(defaults['rp_player:me'] == 'M' and defaults['rp_ui:settings'] == 'F12', 'menu defaults')
for _, a in ipairs(I.actions) do
    check(not seen[a.id] and I.byKey[a.default] and not I.byKey[a.default].reserved, 'unique action with bindable default: ' .. a.id)
    seen[a.id] = true
end
check(#I.actions == 3 and defaults['rp_inventory:open'] == 'I' and not I.byAction['rp_move:forward'], 'only project menus are registered')
check(I.validate({})['rp_player:me'] == 'M', 'missing defaults repaired')
check(I.validate({['unknown:action'] = 'J'}) == nil, 'unknown action rejected')
check(I.validate({['rp_player:me'] = 'UNKNOWN'}) == nil, 'unknown key rejected')
check(I.validate({['rp_player:me'] = 'F8'}) == nil, 'reserved key rejected')
check(I.validate({['rp_player:me'] = false}) == nil, 'non-string key rejected')
check(I.validate({['rp_player:me'] = ''})['rp_player:me'] == '', 'explicit unbound survives')
local result, err, conflicts = I.rebind(defaults, 'rp_player:me', 'F12', false)
check(not result and err == 'binding_conflict' and #conflicts == 1 and conflicts[1] == 'rp_ui:settings', 'own menu conflict requires confirmation')
check(defaults['rp_player:me'] == 'M' and defaults['rp_ui:settings'] == 'F12', 'no mutation before confirmation')
result = I.rebind(defaults, 'rp_player:me', 'F12', true)
check(result['rp_player:me'] == 'F12' and result['rp_ui:settings'] == '', 'confirmed collision clears other custom action')
check(defaults['rp_ui:settings'] == 'F12', 'rebind clones rather than mutates')
check(I.rebind(defaults, 'rp_player:me', 'W', false)['rp_player:me'] == 'W', 'GTA keys are not custom-action conflicts')
check(I.rebind(defaults, 'rp_player:me', 'M', false)['rp_ui:settings'] == 'F12', 'same-key no-op preserves other action')
check(I.rebind(defaults, 'rp_player:me', '', false)['rp_player:me'] == '', 'removing binding works')
check(not I.rebind(defaults, 'rp_player:me', 'ESCAPE', true), 'reserved key cannot be overridden')
check(not I.rebind(defaults, 'rp_move:forward', 'J', true), 'removed GTA action cannot be rebound')

-- Actual client API with a mocked FiveM host; no native game loop is executed.
local api, events, threads, store, commands, mapped = {}, {}, {}, {}, {}, {}
local owner, esx = 'rp_jobs', {}
exports = setmetatable({es_extended = {getSharedObject = function() return esx end}}, {__call = function(_, name, fn) api[name] = fn end})
function GetConvar(_, fallback) return fallback end
function GetResourceKvpString() return 'stored' end
json = {decode = function() return {['rp_player:me'] = 'K', ['rp_jobs:menu'] = 'J', ['rp_bad:key'] = 'F8', ['rp_move:forward'] = 'J'} end,
    encode = function(value) store = value return 'saved' end}
function SetResourceKvp() end
function GetInvokingResource() return owner end
function TriggerEvent() end
function CreateThread(fn) threads[#threads + 1] = fn end
function AddEventHandler(name, fn) events[name] = fn end
function RegisterCommand(name, fn) commands[name] = fn end
function ExecuteCommand() error('production console commands must never be used for key bindings') end
local registrations = {}
function RegisterKeyMapping(command, description, mapper, key)
    assert(command:match('^%+rp_core_mapped_v3_[%w_]+$') and mapper == 'keyboard' and description ~= '',
        'use the production-safe resource keymapping API with a namespaced command')
    assert(commands[command] and commands['-' .. command:sub(2)], 'press and release registered before mapping')
    assert(not registrations[command], 'register each stable key mapping only once per resource start')
    registrations[command] = true
    mapped[key] = command
end
dofile(base .. 'rp_core/client/input.lua')
local function find(id) for _, a in ipairs(api.rpGetBindings().actions) do if a.id == id then return a end end end
local snapshot = api.rpGetBindings()
check(#snapshot.actions == 3 and find('rp_move:forward') == nil, 'legacy stored GTA bindings cannot return to the catalog')
check(find('rp_player:me').key == 'K', 'core preference survives future resource keys')
check(api.rpRegisterInputAction({id='rp_jobs:menu',label='Job',defaultKey='L'}), 'resource-owned registration')
check(find('rp_jobs:menu').key == 'J', 'late registration restores saved key')
check(not api.rpRegisterInputAction({id='rp_other:menu',label='Other',defaultKey='L'}), 'foreign namespace rejected')
check(not api.rpRegisterInputAction({id='rp_jobs:bad',label='Bad',defaultKey='F8'}), 'reserved default rejected')
check(api.rpSetBinding('rp_player:me', 'L', false, snapshot.revision).error == 'stale_bindings', 'stale UI write rejected')
check(api.rpSetBinding('rp_player:me', 'L', false, api.rpGetBindings().revision).ok, 'current revision accepted')
check(store['rp_player:me'] == 'L' and store['rp_jobs:menu'] == 'J', 'all resource preferences persisted')
events.onResourceStop('rp_jobs')
check(find('rp_jobs:menu') == nil, 'stopped resource action removed')
check(api.rpRegisterInputAction({id='rp_jobs:menu',label='Job',defaultKey='L'}) and find('rp_jobs:menu').key == 'J', 'resource restart keeps preferences')
check(api.rpResetBindings(api.rpGetBindings().revision).ok and find('rp_player:me').key == 'M', 'reset restores defaults')

local signals, mouse = {}, {}
local focused, paused, faded, loaded = false, false, false, true
function esx.IsPlayerLoaded() return loaded end
function IsInputDisabled() return false end -- Controller was the last device.
function IsNuiFocused() return focused end
function IsPauseMenuActive() return paused end
function IsPauseMenuRestarting() return true end -- Must not block closed pause menu.
function IsScreenFadedOut() return faded end
function IsRawKeyDown() error('keyboard must not rely on raw native buffers') end
function IsDisabledRawKeyDown() error('keyboard must not rely on disabled raw native buffers') end
function IsDisabledControlPressed(_, control) return mouse[control] == true end
function EnableControlAction() error('must not change GTA controls') end
function DisableControlAction() error('must not change GTA controls') end
function SetControlNormal() error('must not inject GTA input') end
function TriggerEvent(name, id) signals[name .. ':' .. tostring(id)] = (signals[name .. ':' .. tostring(id)] or 0) + 1 end
function Wait() coroutine.yield() end
local inputLoop = coroutine.create(threads[1])
local function down(key) assert(mapped[key], 'missing actual FiveM registration: ' .. key) commands[mapped[key]]() end
local function up(key) commands['-' .. mapped[key]:sub(2)]() end
api.rpSetBinding('rp_player:me', 'W', false, api.rpGetBindings().revision)
down('W')
check(coroutine.resume(inputLoop) and signals['rp_core:inputPressed:rp_player:me'] == 1, 'custom action bound to W emits without modifying GTA controls')
check(coroutine.resume(inputLoop) and signals['rp_core:inputPressed:rp_player:me'] == 1, 'held key emits only one press')
up('W')
check(coroutine.resume(inputLoop) and signals['rp_core:inputReleased:rp_player:me'] == 1, 'custom action emits release')
down('F12')
check(coroutine.resume(inputLoop) and signals['rp_core:inputPressed:rp_ui:settings'] == 1, 'F12 settings action works')
focused = true
check(coroutine.resume(inputLoop) and signals['rp_core:inputReleased:rp_ui:settings'] == 1, 'NUI focus releases custom actions')
signals = {}
down('W')
check(coroutine.resume(inputLoop) and next(signals) == nil, 'NUI focus suppresses custom hotkeys')
focused, signals = false, {}
up('W') up('F12')
api.rpResetBindings(api.rpGetBindings().revision)
check(coroutine.resume(inputLoop), 'empty input frame after resetting defaults')
for _, pair in ipairs({{'M', 'rp_player:me'}, {'F12', 'rp_ui:settings'}, {'I', 'rp_inventory:open'}}) do
    down(pair[1])
    check(coroutine.resume(inputLoop) and signals['rp_core:inputPressed:' .. pair[2]] == 1,
        'default hotkey works with last device controller and disabled GTA input: ' .. pair[2])
    up(pair[1])
    check(coroutine.resume(inputLoop) and signals['rp_core:inputReleased:' .. pair[2]] == 1, 'default hotkey releases')
end
signals, paused = {}, true
down('M')
check(coroutine.resume(inputLoop) and next(signals) == nil, 'actual pause menu blocks actions')
up('M')
paused, faded = false, true
down('M')
check(coroutine.resume(inputLoop) and next(signals) == nil, 'faded screen blocks actions')
up('M')
faded, loaded = false, false
down('M')
check(coroutine.resume(inputLoop) and next(signals) == nil, 'unloaded character blocks actions')
up('M')
loaded = true
owner = 'rp_commerce'
check(api.rpRegisterInputAction({id='rp_commerce:interact', label='Shop', defaultKey='E'}) and mapped.E, 'late shop action installs E in FiveM')
down('E') up('E')
check(signals['rp_core:inputPressed:rp_commerce:interact'] == 1, 'E reaches commerce via registered command')
signals = {}
api.rpSetBinding('rp_player:me', 'J', false, api.rpGetBindings().revision)
down('M') up('M')
check(not signals['rp_core:inputPressed:rp_player:me'], 'old persistent helper cannot dispatch a rebound action')
down('J') down('J')
check(signals['rp_core:inputPressed:rp_player:me'] == 1, 'rebound key emits once per press')
api.rpSetBinding('rp_player:me', 'BACKSPACE', false, api.rpGetBindings().revision)
check(signals['rp_core:inputReleased:rp_player:me'] == 1 and mapped.BACK, 'rebind releases held action and translates Backspace mapper ID')
up('J')
api.rpSetBinding('rp_player:me', 'OEM_PLUS', false, api.rpGetBindings().revision)
check(mapped.EQUALS, 'OEM plus uses valid FiveM keyboard parameter')
down('EQUALS') up('EQUALS')
api.rpSetBinding('rp_player:me', '', false, api.rpGetBindings().revision)
signals = {}
down('EQUALS') up('EQUALS')
check(next(signals) == nil, 'unbound action cannot be triggered through retained mapper helper')
api.rpSetBinding('rp_player:me', 'M', false, api.rpGetBindings().revision)
signals = {}
focused = true
down('M')
focused = false
down('M')
check(next(signals) == nil, 'held key from NUI does not reopen menu when focus is released')
up('M') down('M') up('M')
check(signals['rp_core:inputPressed:rp_player:me'] == 1, 'fresh press after NUI focus works')
api.rpSetBinding('rp_player:me', 'MOUSE3', false, api.rpGetBindings().revision)
signals, mouse[348] = {}, true
check(coroutine.resume(inputLoop) and signals['rp_core:inputPressed:rp_player:me'] == 1, 'mouse binding still works')
mouse[348] = false
check(coroutine.resume(inputLoop) and signals['rp_core:inputReleased:rp_player:me'] == 1, 'mouse binding releases')
events.onResourceStop('rp_commerce')
signals = {}
down('E') up('E')
check(next(signals) == nil, 'stopped domain cannot receive retained E helper')

-- Simulate a reconnect: both native mappings and our KVP survive, while commands reload.
-- RegisterKeyMapping only supplies defaults, so rebinding actions must never depend
-- on it changing the default parameter of an existing command.
local persistedMappings = mapped
store['rp_player:me'] = 'J'
json.decode = function() return store end
mapped, commands, threads, registrations = {}, {}, {}, {}
function RegisterKeyMapping(command, description, mapper, key)
    assert(mapper == 'keyboard' and description ~= '', 'valid mapping after reconnect')
    for savedKey, savedCommand in pairs(persistedMappings) do
        if savedCommand == command then
            assert(savedKey == key, 'a stable mapping must keep its original native key')
            mapped[savedKey] = command
            return
        end
    end
    mapped[key] = command
end
dofile(base .. 'rp_core/shared/input.lua')
dofile(base .. 'rp_core/client/input.lua')
signals = {}
down('J') up('J')
check(signals['rp_core:inputPressed:rp_player:me'] == 1, 'saved F12 preference works after reconnect with persisted native mappings')
check(api.rpResetBindings(api.rpGetBindings().revision).ok, 'reset after reconnect')
signals = {}
down('J') up('J') down('M') up('M')
check(signals['rp_core:inputPressed:rp_player:me'] == 1, 'restored M emits once and retained J is inert after reconnect')

-- Settings routes enforce both the active view and close confirmation in Lua.
local routes, view = {}, 'settings'
exports.rp_core = setmetatable({}, {__index = function(_, key) return function(_, ...) return api[key](...) end end})
exports.rp_ui = {
    rpGetView = function() return view end,
    rpRegisterAction = function(_, name, fn) routes[name] = fn end,
    rpClose = function() view = nil end,
}
function RegisterCommand() end
dofile(base .. 'rp_ui/client/settings.lua')
threads[#threads]()
local payload = {action='rp_player:me',key='',revision=api.rpGetBindings().revision}
view = 'me'
check(routes['rp_ui:bind'](payload).error == 'invalid_state', 'binding route rejects a different active view')
view = 'settings'
check(routes['rp_ui:bind'](payload).ok, 'settings route accepts valid change')
check(routes['rp_ui:closeSettings']({revision=api.rpGetBindings().revision}).error == 'unbound_actions' and view == 'settings', 'Lua cannot bypass missing-binding warning')
check(routes['rp_ui:closeSettings']({revision=-1,confirmed=true}).error == 'stale_bindings', 'stale close confirmation rejected')
check(routes['rp_ui:closeSettings']({revision=api.rpGetBindings().revision,confirmed=true}).ok and view == nil, 'explicit current confirmation permits closing')

dofile(base .. 'rp_player/shared/config.lua')
dofile(base .. 'rp_player/shared/progress.lua')
local P = PlayerProgress
local start, current = {x=0,y=0,z=30}, {x=15,y=0,z=30}
local distance, seconds = P.sample(start, current, 5, true, true)
check(distance == 15 and seconds == 5, 'legitimate jogging earns distance and time')
check(P.sample(start, current, 5, false, true) == 0, 'vehicle/dead/private bucket does not earn progress')
check(P.sample(start, current, 5, true, false) == 0, 'vehicle exit excludes previous movement')
check(P.sample(nil, current, 5, true, true) == 0, 'initial sample not rewarded')
check(P.sample(start, current, 0, true, true) == 0, 'zero-time rejected')
check(P.sample(start, current, -5, true, true) == 0, 'timer rollover rejected')
check(P.sample(start, current, 20, true, true) == 0, 'stale checkpoint rejected')
check(P.sample(start, start, 5, true, true) == 0, 'standing still rejected')
check(P.sample(start, {x=5,y=0,z=30}, 5, true, true) == 0, 'walking is not training')
check(P.sample(start, {x=500,y=0,z=30}, 5, true, true) == 0, 'teleport/high speed rejected')
check(P.sample(start, {x=15,y=0,z=40}, 5, true, true) == 0, 'falling excluded')
check(P.level(0) == 1 and P.level(999) == 1 and P.level(1000) == 2, 'level thresholds')
check(P.level(100000000) == PlayerConfig.maxLevel, 'maximum level capped')

-- Cleanup protects player peds, occupied traffic and project-owned vehicles.
threads, events = {}, {}
local removed, population = {}, {[201]=2, [202]=7, [203]=2, [204]=2}
function Wait() coroutine.yield() end
function GetGamePool(kind) return kind == 'CPed' and {101,102,103,104,105} or {201,202,203,204} end
GlobalState={['rp_core:networkPeds']={['104']=900,['105']=901}}
function NetworkGetNetworkIdFromEntity(id) return id end
function GetEntityModel() return 900 end
function IsPedAPlayer(id) return id == 101 end
function NetworkGetEntityIsNetworked() return true end
function NetworkHasControlOfEntity(id) return id ~= 103 and id ~= 204 end
function SetEntityAsMissionEntity() end
function DeleteEntity(id) removed[id] = true end
function GetEntityPopulationType(id) return population[id] or 7 end
function GetVehicleMaxNumberOfPassengers() return 3 end
function GetPedInVehicleSeat(id, seat) return id == 203 and seat == 2 and 101 or 0 end
RP.NpcPresentation = { register=function() return true end, release=function() return true end }
dofile(base .. 'rp_core/client/world.lua')
local hidden, cashDisabled, cashRemoved = {}, false, false
function DisplayCash(value) cashDisabled = value == false end
function RemoveMultiplayerHudCash() cashRemoved = true end
function HideHudComponentThisFrame(id) hidden[id] = true end
for _, name in ipairs({'EnableDispatchService', 'SetCreateRandomCops', 'SetCreateRandomCopsNotOnScenarios',
    'SetCreateRandomCopsOnScenarios', 'SetRandomBoats', 'SetRandomTrains', 'SetGarbageTrucks', 'SetMaxWantedLevel',
    'SetPedDensityMultiplierThisFrame', 'SetScenarioPedDensityMultiplierThisFrame', 'SetVehicleDensityMultiplierThisFrame',
    'SetRandomVehicleDensityMultiplierThisFrame', 'SetParkedVehicleDensityMultiplierThisFrame'}) do _G[name] = function() end end
local world = coroutine.create(threads[1])
check(coroutine.resume(world) and cashDisabled and cashRemoved and hidden[3] and hidden[4] and hidden[13], 'cash HUD hidden before first frame yield')
check(not hidden[19] and not hidden[20], 'weapon wheel remains available')
hidden = {}
check(coroutine.resume(world) and hidden[3] and hidden[4] and hidden[13], 'cash suppression repeats every frame')
local cleanup = coroutine.create(threads[2])
check(coroutine.resume(cleanup), 'cleanup yields before scan')
check(coroutine.resume(cleanup), 'cleanup completes one pass')
check(removed[102] and not removed[101], 'NPC deleted; player protected')
check(not removed[104] and removed[105], 'server-registered network valet protected; mismatched reused net id rejected')
check(not removed[103] and not removed[204], 'uncontrolled network entities untouched')
check(removed[201] and not removed[202], 'ambient traffic deleted; project vehicle protected')
check(not removed[203], 'player passenger protects ambient vehicle')
owner='rp_commerce'
function NetworkGetEntityIsNetworked(id) return id ~= 102 end
function DoesEntityExist(id) return id==102 end
function IsEntityAPed(id) return id==102 end
removed[102]=nil
check(api.rpProtectPed(102),'project-owned local clerk can be protected')
check(not api.rpProtectPed(101),'player peds cannot be registered as clerks')
check(coroutine.resume(cleanup) and not removed[102],'registered clerk survives ambient sweep')
owner='rp_other'
check(not api.rpReleasePed(102),'another resource cannot release clerk protection')
owner='rp_commerce'
events.onResourceStop('rp_commerce')
check(removed[102],'stopping clerk owner deletes protected ped')
print(('PASS: %d input API, conflict, persistence, fitness and NPC cleanup assertions'):format(passed))
