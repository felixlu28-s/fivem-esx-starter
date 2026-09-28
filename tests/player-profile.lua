-- Regression: ESX exports return serialized tables; identity is character-scoped.
local root = 'server-data/resources/[custom]/rp_player/'
local events, callbacks, reads, writes = {}, {}, {}, {}
local identifier, queryHook, clock = 'char1:account', nil, 0
local count = 0
local function check(value, label) assert(value, label) count = count + 1 end
local esx = { GetPlayerFromId = function()
    if not identifier then return nil end
    return { identifier = identifier, spawned = true,
        getName = function() return 'Test Character' end,
        getJob = function() return { label = 'Police', grade_label = 'Officer' } end,
        getMoney = function() return 100 end, getAccount = function() return { money = 500 } end,
        get = function() return nil end }
end }
exports = { es_extended = { getSharedObject = function() return esx end } }
lib = { callback = { register = function(name, fn) callbacks[name] = fn end } }
function AddEventHandler(name, fn) events[name] = fn end
function CreateThread() end
function TriggerClientEvent() end
function GetGameTimer() clock = clock + 2000 return clock end
function GetCurrentResourceName() return 'rp_player' end
MySQL = {
    ready = function(fn) fn() end,
    query = { await = function() return {} end },
    single = { await = function(_, params)
        reads[#reads + 1] = params[1]
        if queryHook then local hook = queryHook queryHook = nil hook() end
        return { running_meters = params[1] == 'char1:account' and 10000 or 25, training_seconds = 100 }
    end },
    update = function(_, params) writes[#writes + 1] = params end,
}
dofile(root .. 'shared/config.lua')
dofile(root .. 'shared/progress.lua')
dofile(root .. 'server/main.lua')
local function profile() return callbacks['rp_player:profile'](1) end
check(esx.GetPlayerFromId(1) ~= esx.GetPlayerFromId(1), 'fixture models cross-resource table copies')
local first = profile()
check(first.ok and first.profile.runningMeters == 10000, 'serialized ESX player tables can open M profile')
check(reads[1] == 'char1:account', 'fitness reads full first-character identifier')
events['esx:playerLogout'](1)
check(writes[1][1] == 'char1:account', 'logout saves fitness against first character')
identifier = 'char2:account'
local second = profile()
check(second.ok and second.profile.runningMeters == 25, 'second character does not inherit first fitness')
events['esx:playerLogout'](1)
queryHook = function() identifier = 'char1:account' end
check(profile().error == 'player_unavailable', 'character change while SQL waits invalidates result')
check(profile().ok, 'new character can subsequently load normally')
source = 1 events.playerDropped()
queryHook = function() events.playerDropped() end
check(profile().error == 'player_unavailable', 'same-character reconnect invalidates pending fitness request')
check(profile().ok, 'subsequent request recovers after disconnect')
check(writes[#writes][1] == 'char1:account', 'no account-scoped fitness save')
print(('PASS: %d ESX export/profile and multicharacter fitness checks'):format(count))
