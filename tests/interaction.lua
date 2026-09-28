local api, events, threads, sent = {}, {}, {}, {}
local owner, time, focus, paused, view = 'rp_commerce', 0, false, false, nil
local key = 'E'
local count = 0
local function check(value, label) assert(value, label) count = count + 1 end
exports = setmetatable({
    es_extended = {getSharedObject = function() return {IsPlayerLoaded = function() return true end} end},
    rp_ui = {rpGetView = function() return view end},
    rp_core = {rpGetBindings = function() return {
        actions = {{id='rp_commerce:interact',key=key}, {id='rp_inventory:open',key='I'}},
        keys = {{id='E',label='E'},{id='I',label='I'},{id='F12',label='F12'}},
    } end},
}, {__call=function(_, name, fn) api[name] = fn end})
function GetInvokingResource() return owner end
function GetCurrentResourceName() return 'rp_ui' end
function GetGameTimer() return time end
function IsNuiFocused() return focus end
function IsPauseMenuActive() return paused end
function IsScreenFadedOut() return false end
function IsEntityDead() return false end
function PlayerPedId() return 1 end
function SetNuiFocus() error('hint must never take focus') end
function SendNUIMessage(data) sent[#sent+1] = data end
function CreateThread(fn) threads[#threads+1] = fn end
function AddEventHandler(name, fn) events[name] = fn end
function Wait() coroutine.yield() end
json = {encode=function(v) return v == false and 'false' or v.label .. v.verb .. v.key .. v.icon end}
dofile('server-data/resources/[custom]/rp_ui/client/interaction.lua')
local loop = coroutine.create(threads[1])
local function tick() assert(coroutine.resume(loop)) return sent[#sent].data end
local function shop(distance)
    return api.rpShowInteraction({action='rp_commerce:interact',label='24/7',verb='Einkaufen',icon='shop',distance=distance})
end
check(tick() == false, 'no point hides overlay')
check(shop(2), 'owner can publish hint')
check(tick().key == 'E', 'key resolved from real bindings')
check(api.rpIsInteractionActive('rp_commerce:interact'),'visible owner may consume contextual key')
local messages = #sent
shop(2) tick()
check(#sent == messages, 'stationary point does not flood NUI messages')
key = 'F12'
check(tick().key == 'F12', 'rebinding updates displayed key')
key = ''
check(tick().key == '', 'unbound action never claims default E')
focus = true
check(tick() == false, 'NUI focus hides hint')
check(not api.rpIsInteractionActive('rp_commerce:interact'),'hidden hint cannot consume key')
focus, paused = false, true
check(tick() == false, 'pause hides hint')
paused, view = false, 'nativeui'
check(tick() == false, 'open view hides hint even without native focus')
view = nil
owner = 'rp_inventory'
check(not shop(0), 'foreign action ownership rejected')
check(api.rpShowInteraction({action='rp_inventory:open',label='Boden',verb='Öffnen',icon='bag',distance=1}), 'second domain publishes own action')
check(tick().label == 'Boden', 'nearest point wins across domains')
check(api.rpIsInteractionActive('rp_inventory:open'),'nearer item owns contextual input')
owner='rp_commerce'
check(not api.rpIsInteractionActive('rp_commerce:interact'),'farther shop cannot also consume E')
check(not api.rpIsInteractionActive('rp_inventory:open'),'caller cannot impersonate selected domain')
owner='rp_inventory'
api.rpHideInteraction()
check(tick().label == '24/7', 'hide affects only caller')
time = 701
check(tick() == false, 'stale point expires if consumer stops renewing')
owner = 'rp_commerce'
check(not shop(0/0) and not shop(math.huge) and not shop(-1), 'invalid distances rejected')
shop(1) tick()
events.onResourceStop('rp_commerce')
check(sent[#sent].data == false, 'owner stop clears visible hint immediately')
shop(1) tick()
messages = #sent
events['rp_ui:ready']() tick()
check(#sent == messages + 1, 'browser reload receives current hint again')
print(('PASS: %d interaction ownership, focus, rebinding and lifecycle assertions'):format(count))
