-- Run from repository root with Lua 5.4: lua tests/characters.lua
local root = 'server-data/resources/[custom]/rp_characters/'
dofile(root .. 'shared/config.lua')
dofile(root .. 'shared/wardrobe.lua')
dofile(root .. 'shared/appearance.lua')
dofile(root .. 'shared/validation.lua')
local V, A = Characters.Validation, Characters.Appearance
local count = 0
local function check(value, message) assert(value, message) count = count + 1 end
check(V.name('  Jörg  ') == 'Jörg', 'trim UTF-8 name')
check(V.name("O'Connor") == "O'Connor", 'apostrophe')
check(V.name('---') == nil, 'name requires letters')
check(V.name('<script>') == nil, 'reject markup')
check(V.name(string.char(255)) == nil, 'reject invalid UTF-8')
check(V.name(string.rep('A', 17)) == nil, 'respect ESX 16 character columns')
local today = { year = 2026, month = 9, day = 17 }
check(V.birthdate('2000-02-29', today), 'valid leap date')
check(not V.birthdate('2001-02-29', today), 'invalid leap date')
check(not V.birthdate('2000-04-31', today), 'invalid calendar date')
check(V.birthdate('2008-09-17', today), '18th birthday accepted')
check(not V.birthdate('2008-09-18', today), 'under 18 rejected')
check(not V.birthdate('1900-01-01', today), 'maximum age enforced')
check(A.validate({ sex = 1, nose_1 = -10, mom = 45 }) ~= nil, 'appearance ranges')
check(A.validate({ model = 's_m_y_cop_01' }) == nil, 'arbitrary model rejected')
check(A.validate({ mom = 999 }) == nil, 'face model range')
check(A.validate({ sex = 0 / 0 }) == nil, 'NaN rejected')
check(A.validate({ torso_1 = 2.5 }) == nil, 'fractional drawable rejected')
check(A.validate(A.defaults(0)) ~= nil and A.validate(A.defaults(1)) ~= nil, 'defaults valid')
check(#A.fields > 90, 'complete appearance catalog')
check(V.position({ x = 0, y = 0, z = 20, heading = 370 }).heading == 10, 'heading normalized')
check(V.position({ x = math.huge, y = 0, z = 20 }) == nil, 'infinite position rejected')

-- Exercise actual server callbacks with FiveM/SQL boundary doubles.
local callbacks, events, players, joins = {}, {}, {}, {}
local accountSlots, rows, clock = 1, {}, 10000
local clockStep = 2000
local actor = { account = 'testaccount', connected = true }
local liveJobs = { unemployed = { grades = { ['0'] = {} } } }
local esx = {
    Jobs = {}, -- snapshot captured before ESX.RefreshJobs replaces the table
    GetIdentifier = function() return actor.account end,
    GetPlayerFromId = function(id) return players[id] end,
    GetPlayerFromIdentifier = function() return nil end,
    GetConfig = function(key) if key == 'Multichar' then return true else return { bank = 50000 } end end,
}
local exportedOnce = false
exports = { rp_inventory = { rpResolveClothing = function(_, _, skin) return skin end }, es_extended = { getSharedObject = function()
    if not exportedOnce then exportedOnce = true return esx end
    return { Jobs = liveJobs }
end } }
lib = { callback = { register = function(name, callback) callbacks[name] = callback end } }
function GetGameTimer() clock = clock + clockStep return clock end
function GetPlayerName() return actor.connected and 'Test' or nil end
function GetCurrentResourceName() return 'rp_characters' end
function SetRoutingBucketPopulationEnabled() end
function SetRoutingBucketEntityLockdownMode() end
function SetPlayerRoutingBucket() end
function GetPlayerPed() return 0 end
function DoesEntityExist() return false end
function CreateThread() end
function SetTimeout() end
function AddEventHandler(name, callback) events[name] = callback end
function RegisterCommand(name, callback) callbacks[name] = callback end
function IsPlayerAceAllowed() return false end
function TriggerEvent(name, source, prefix) joins[#joins + 1] = { name = name, source = source, prefix = prefix } end
function DropPlayer() actor.connected = false end
json = { encode = function() return '{}' end, decode = function() return {} end }
local interruptQuery = false
local failTransaction = true
local transactions = 0
MySQL = {
    ready = function(callback) callback() end,
    scalar = { await = function(sql)
        if sql:find('MAX', 1, true) then return #rows end
        return accountSlots
    end },
    query = { await = function(sql)
        if sql:find('LIMIT 0', 1, true) then return {} end
        return rows
    end },
    single = { await = function(_, params)
        if interruptQuery then actor.connected = false end
        for _, row in ipairs(rows) do
            if row.slot == params[2] then return { esx_identifier = 'char' .. row.slot .. ':' .. params[1], skin = A.defaults(0) } end
        end
    end },
    insert = { await = function() return 1 end },
    update = setmetatable({ await = function() return 1 end }, { __call = function() return 1 end }),
    transaction = { await = function(queries)
        transactions = transactions + 1
        check(callbacks['rp_characters:create'](1, {}).error == 'busy', 'overlapping creation blocked while SQL is pending')
        if failTransaction then failTransaction = false return false end
        local values = queries[2].values
        rows[#rows + 1] = { slot = values[1], firstname = 'Alex', lastname = 'Morgan', dateofbirth = '2000-01-01', sex = 'm', height = 180, skin = A.defaults(0), job = 'Bürger' }
        return true
    end },
}
dofile(root .. 'server/main.lua')
local function call(name, input) return callbacks['rp_characters:' .. name](1, input) end
check(call('select', { slot = 1 }).error == 'session_expired', 'no login without bootstrap')
check(call('bootstrap').ok, 'new account can bootstrap')
clockStep = 0
local throttle = call('bootstrap')
check(throttle.error == 'rate_limited' and throttle.retryAfterMs == 1500, 'bootstrap cooldown reports exact remaining delay')
clock = clock + 1499
throttle = call('bootstrap')
check(throttle.error == 'rate_limited' and throttle.retryAfterMs == 1, 'denied retries do not extend bootstrap cooldown')
clock = clock + 1
check(call('bootstrap').ok, 'bootstrap works at cooldown boundary')
clockStep = 2000
check(callbacks['rp_characters:bootstrap'](2).error == 'account_in_use', 'same account cannot open another session')
check(call('select', { slot = 999 }).error == 'invalid_state', 'invalid slot rejected')
clockStep = 0
throttle = call('select', { slot = 999 })
check(throttle.error == 'rate_limited' and throttle.retryAfterMs == Characters.Config.requestCooldownMs, 'action cooldown reports remaining delay')
clockStep = 2000
check(call('select', { slot = 2 }).error == 'not_found', 'foreign/unowned slot rejected')
check(#joins == 0, 'unowned slot never reaches ESX')
local input = { identity = { firstname = 'Alex', lastname = 'Morgan', dateofbirth = '2000-01-01', height = 180 }, skin = A.defaults(0) }
check(call('create', { identity = {}, skin = {} }).error == 'invalid_fields', 'invalid creation rejected')
local forbidden = A.defaults(0)
forbidden.torso_1 = 999
check(call('create', { identity = input.identity, skin = forbidden }).error == 'invalid_fields', 'server callback rejects clothing outside arrival catalog')
local loadedJobs = liveJobs
liveJobs = {}
check(call('create', input).error == 'server_starting', 'creation waits for live ESX jobs')
check(transactions == 0 and #rows == 0, 'not ready cannot consume a character slot')
liveJobs = loadedJobs
check(call('create', input).error == 'database_error', 'failed transaction reported without loading')
check(#rows == 0 and #joins == 0, 'failed transaction does not consume a slot')
local created = call('create', input)
check(created.ok and created.slot == 1, 'creation returns committed slot separately from login')
check(#joins == 0, 'saving never starts ESX login before acknowledgement')
local committedTransactions = transactions
liveJobs = {}
check(call('select', { slot = created.slot }).error == 'server_starting', 'login can fail independently after commit')
local resumed = call('create', input)
check(resumed.ok and resumed.slot == created.slot, 'repeat creation returns already committed slot')
check(transactions == committedTransactions and #rows == 1, 'retry never creates duplicate even when quota is full')
liveJobs = loadedJobs
check(call('select', { slot = resumed.slot }).ok, 'login resumes with current jobs despite stale cached ESX.Jobs')
check(#joins == 1 and joins[1].prefix == 'char1' and joins[1].source == 1, 'ESX receives server-owned prefix and source')
check(call('create', input).error == 'invalid_state', 'cannot create while loading')
check(call('spawnData').error == 'invalid_state', 'spawn data requires real ESX player')
players[1] = { identifier = 'char1:testaccount' }
check(call('spawnData').ok, 'spawn data belongs to loaded character')
check(call('spawned').error == 'spawn_pending', 'cannot complete spawn before standard ESX spawn event')
check(players[1].spawned == nil, 'custom resource must not write spawned on exported ESX snapshot')
players[1].spawned = true
check(call('spawned').error == 'spawn_pending', 'cannot complete spawn without a server ped')
players[1] = nil
source = 1 events.playerDropped()
check(call('bootstrap').ok, 'reconnect can resume account')
check(call('create', input).error == 'character_limit', 'account limit enforced after reconnect')
check(call('list').characters[1].skin ~= nil, 'only public character data returned')
check(call('list').characters[1].esx_identifier == nil, 'no database identifier leaked')
interruptQuery = true
check(call('select', { slot = 1 }).error == 'session_expired', 'disconnect during SQL cannot login')
check(#joins == 1, 'stale session never starts another ESX login')
-- The same account selects two distinct ESX character prefixes across reconnects.
interruptQuery, actor.connected, accountSlots = false, true, 2
source = 1 events.playerDropped()
rows[2] = { slot = 2, firstname = 'Robin', lastname = 'Hayes', dateofbirth = '2000-01-01', sex = 'f', height = 170, skin = A.defaults(1), job = 'Bürger' }
local roster = call('bootstrap')
check(roster.ok and #roster.characters == 2 and roster.slots == 2, 'same account roster contains two independent slots')
check(call('select', { slot = 2 }).ok and joins[2].prefix == 'char2', 'second character uses official char2 login prefix')
players[1] = { identifier = 'char1:testaccount' }
check(call('spawnData').error == 'invalid_state', 'first character ESX state cannot complete second-character login')
players[1] = { identifier = 'char2:testaccount' }
check(call('spawnData').ok, 'second-character login requires matching full ESX identifier')
players[1] = nil
source = 1 events.playerDropped()
check(call('bootstrap').ok and call('select', { slot = 1 }).ok and joins[3].prefix == 'char1', 'returning to first character restores its original ESX prefix')
print(('PASS: %d character validation and server-boundary checks'):format(count))
