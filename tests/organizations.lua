-- Lua 5.4: actual resource callbacks with controlled FiveM/ESX/SQL boundaries.
local root = 'server-data/resources/[custom]/rp_organizations/'
local count = 0
local function check(value, label) assert(value, label) count = count + 1 end
local callbacks, events, api, players, audit, saved = {}, {}, {}, {}, {}, {}
local timer, admin, accountMoney, sqlFailure, sqlHook = 10000, false, 1000, false, nil
local members, factions = {}, { lost = 'The Lost MC' }
local jobs = {
    unemployed = { label = 'Arbeitslos', grades = { ['0'] = { grade = 0, name = 'unemployed', label = 'Bürger', salary = 0 } } },
    police = { label = 'Police', grades = {
        ['0'] = { grade = 0, name = 'recruit', label = 'Recruit', salary = 100 },
        ['1'] = { grade = 1, name = 'officer', label = 'Officer', salary = 200 },
        ['2'] = { grade = 2, name = 'boss', label = 'Boss', salary = 300 },
    } },
}
local function player(id, identifier, jobName, grade)
    local p = { source = id, identifier = identifier, spawned = true, cash = 500, position = id, changes = 0 }
    p.setJob = function(name, rank, duty)
        local data = jobs[name].grades[tostring(rank)]
        p.job = { name = name, grade = rank, grade_name = data.name, onDuty = duty }
        p.changes = p.changes + 1
    end
    p.getJob = function() return p.job end
    p.getName = function() return 'Character ' .. id end
    p.getMoney = function() return p.cash end
    p.removeMoney = function(value) p.cash = p.cash - value end
    p.addMoney = function(value) p.cash = p.cash + value end
    p.setJob(jobName, grade, true)
    players[id] = p
    return p
end
local boss = player(1, 'char1:account', 'police', 2)
local recruit = player(2, 'char1:other', 'unemployed', 0)
local esx = {
    Jobs = jobs,
    GetPlayerFromId = function(id) return players[id] end,
    GetPlayerFromIdentifier = function(identifier)
        for _, p in pairs(players) do if p.identifier == identifier then return p end end
    end,
    GetExtendedPlayers = function() return players end,
    RefreshJob = function(name) esxRefreshed = name end,
}
local societies = { police = { account = 'society_police' } }
exports = setmetatable({
    es_extended = { getSharedObject = function() return esx end },
    esx_society = { GetSociety = function(_, name) return societies[name] end },
    esx_addonaccount = { GetSharedAccount = function(_, name)
        if name ~= 'society_police' then return nil end
        return { money = accountMoney, addMoney = function(n) accountMoney = accountMoney + n end,
            removeMoney = function(n) accountMoney = accountMoney - n end }
    end },
}, { __call = function(_, name, callback) api[name] = callback end })
lib = { callback = { register = function(name, callback) callbacks[name] = callback end } }
function GetGameTimer() return timer end
function IsPlayerAceAllowed(id) return id == 1 and admin end
function GetPlayerRoutingBucket(id) return players[id].bucket or 0 end
function GetPlayerPed(id) return players[id] and id or 0 end
function GetEntityCoords(id)
    return setmetatable({ value = players[id].position }, { __sub = function(a, b)
        return setmetatable({}, { __len = function() return math.abs(a.value - b.value) end })
    end })
end
function GetCurrentResourceName() return 'rp_organizations' end
function ExecuteCommand(command) saved[#saved + 1] = command end
function AddEventHandler(name, fn) events[name] = fn end
function TriggerEvent(name, key, label, account)
    if name == 'esx_society:registerSociety' then societies[key] = { account = account, label = label } end
end
function Wait() end
local function beforeQuery()
    if sqlFailure then error('Injected SQL failure') end
    if sqlHook then local hook = sqlHook sqlHook = nil hook() end
end
local function query(sql, params)
    beforeQuery()
    if sql:find('LIMIT 0', 1, true) then return {} end
    if sql:find('FROM rp_factions f', 1, true) then
        local rows = {}
        for name, label in pairs(factions) do
            local rank = (members[params[1]] or {})[name]
            if params[2] == 1 or rank ~= nil then rows[#rows + 1] = { name = name, label = label, grade = rank } end
        end
        return rows
    end
    if sql:find('JOIN users u', 1, true) then
        local rows = {}
        for identifier, membership in pairs(members) do
            if membership[params[1]] ~= nil then rows[#rows + 1] = { identifier = identifier, grade = membership[params[1]], firstname = 'Test', lastname = 'Member' } end
        end
        return rows
    end
    if sql:find('SELECT faction, grade', 1, true) then
        local rows = {}
        for name, grade in pairs(members[params[1]] or {}) do rows[#rows + 1] = { faction = name, grade = grade } end
        return rows
    end
    return {}
end
local function update(sql, params)
    beforeQuery()
    if sql:find('INSERT INTO rp_faction_members', 1, true) then
        local identifier, grade, name = params[1], params[2], params[3]
        local data, total = members[identifier] or {}, 0
        for _ in pairs(data) do total = total + 1 end
        if total >= params[5] or not factions[name] then return 0 end
        data[name] = grade members[identifier] = data
    elseif sql:find('UPDATE rp_faction_members', 1, true) then
        members[params[3]][params[2]] = params[1]
    elseif sql:find('DELETE FROM rp_faction_members', 1, true) then
        members[params[2]][params[1]] = nil
    elseif sql:find('UPDATE job_grades', 1, true) then
        local grade = jobs[params[3]].grades[tostring(params[4])]
        grade.label, grade.salary = params[1], params[2]
    end
    return 1
end
MySQL = {
    ready = function(fn) fn() end,
    query = { await = query },
    single = { await = function(_, params)
        beforeQuery()
        local grade = (members[params[1]] or {})[params[2]]
        return grade ~= nil and { grade = grade } or nil
    end },
    scalar = { await = function(_, params) beforeQuery() return factions[params[1]] end },
    update = { await = update },
    insert = setmetatable({ await = function(sql, params)
        beforeQuery()
        if sql:find('INSERT INTO rp_factions', 1, true) then factions[params[1]] = params[2] end
        return 1
    end }, { __call = function(_, _, params) audit[#audit + 1] = params end }),
    transaction = { await = function(queries)
        beforeQuery()
        for _, row in ipairs(queries) do
            local v = row.values
            if row.query:find('INSERT INTO jobs', 1, true) then jobs[v[1]] = { name = v[1], label = v[2], grades = {} }
            elseif row.query:find('INSERT INTO job_grades', 1, true) then
                jobs[v[1]].grades[tostring(v[2])] = { grade = v[2], name = v[3], label = v[4], salary = 0 }
            end
        end
        return true
    end },
}
for _, file in ipairs({ 'shared/config.lua', 'shared/policy.lua', 'server/service.lua', 'server/jobs.lua', 'server/factions.lua', 'server/main.lua' }) do dofile(root .. file) end
local S, P = Organizations.Service, Organizations.Policy
local function call(input, id, immediate)
    if not immediate then timer = timer + 1000 end
    return callbacks['rp_organizations:request'](id or 1, input)
end
local function action(name, fields)
    local input = fields or {} input.action = name input.kind = input.kind or 'job' input.name = input.name or 'police'
    return call(input)
end
local function memberToken(identifier, kind, name)
    return S.token(S.context(1), kind or 'job', name or 'police', identifier)
end
check(S.ready, 'resource starts with migrations and live ESX jobs')
check(not P.character('account') and P.character('char2:account'), 'full character identifiers required')
check(not P.integer(0 / 0, 0, 99) and not P.integer(math.huge, 0, 99), 'non-finite rejected')
check(not P.code("job';DROP") and P.label('  Ärzte  ') == 'Ärzte', 'codes and UTF8 labels validated')
check(call(false).error == 'invalid_fields', 'invalid envelope rejected')
check(action('delete').error == 'invalid_fields', 'no destructive endpoint')
check(action('create', { kind = 'faction', name = 'test', label = 'Test' }).error == 'forbidden', 'boss cannot create organizations')
local view = action('view').organizations
check(#view.list == 1 and view.list[1].manage and view.list[1].balance == 1000, 'boss own job and society visible')
check(view.members[1].identifier == nil and view.members[1].token ~= boss.identifier, 'public roster never leaks identifier')
check(action('hire', { target = 2, grade = 2 }).error == 'forbidden', 'boss cannot appoint equal rank')
recruit.position = 30
check(action('hire', { target = 2, grade = 0 }).error == 'target_unavailable', 'recruitment distance checked server-side')
recruit.position, recruit.bucket = 2, 1
check(action('hire', { target = 2, grade = 0 }).error == 'target_unavailable', 'cross-bucket recruit denied')
recruit.bucket = 0
check(action('hire', { target = 2, grade = 0 }).ok and recruit.job.name == 'police', 'hire uses standard xPlayer setJob')
check(saved[#saved] == 'save 2' and audit[#audit][5] == recruit.identifier, 'ESX saving and audit target exact character')
check(action('hire', { target = 2, grade = 0 }).error == 'target_employed', 'boss cannot steal employed character')
check(action('promote', { member = 'char1:other', grade = 1 }).error == 'stale_members', 'arbitrary identifier rejected')
local token = memberToken(recruit.identifier)
check(S.resolve(S.context(2), { member = token, kind = 'job', name = 'police' }) == nil, 'token not transferable to another source')
check(action('promote', { member = token, grade = 1 }).ok and recruit.job.grade == 1, 'rank change uses ESX state')
token = memberToken(boss.identifier)
check(action('fire', { member = token }).error == 'forbidden', 'boss cannot remove self')
token = memberToken('char2:offline')
check(action('fire', { member = token }).error == 'member_offline', 'offline jobs never directly overwritten')
token = memberToken(recruit.identifier)
timer = timer + 120001
check(action('fire', { member = token }).error == 'stale_members', 'member tokens expire')
token = memberToken(recruit.identifier)
check(action('fire', { member = token }).ok and recruit.job.name == 'unemployed', 'fire assigns standard unemployed rank')
check(action('duty', { duty = false }).ok and not boss.job.onDuty, 'duty uses standard setJob onDuty')
check(action('deposit', { amount = -1 }).error == 'invalid_fields', 'negative transfer rejected')
check(action('deposit', { amount = 501 }).error == 'insufficient_money', 'cash availability checked')
check(action('deposit', { amount = 100 }).ok and boss.cash == 400 and accountMoney == 1100, 'standard cash/shared-account transfer')
check(call({ action = 'deposit', kind = 'job', name = 'police', amount = 100 }, 1, true).error == 'rate_limited', 'repeat transfer cooldown')
check(action('withdraw', { amount = 2000 }).error == 'insufficient_money', 'cannot overdraw society')
check(action('withdraw', { amount = 100 }).ok and boss.cash == 500 and accountMoney == 1000, 'fresh shared-account state used')
check(call({ action = 'withdraw', kind = 'job', name = 'police', amount = 10 }, 2).error == 'forbidden', 'non-boss cannot withdraw')
check(action('grade', { grade = 0, salary = 99999, label = 'New' }).error == 'invalid_fields', 'salary cap enforced')
check(action('grade', { grade = 2, salary = 300, label = 'New' }).error == 'forbidden', 'boss cannot change own rank')
check(action('grade', { grade = 0, salary = 150, label = 'Neuling' }).ok and esxRefreshed == 'police', 'rank changes call standard RefreshJob')
members[boss.identifier] = { lost = 2 }
local beforeJob = recruit.job.name
check(action('hire', { kind = 'faction', name = 'lost', target = 2, grade = 0 }).ok, 'secondary faction recruitment')
check(recruit.job.name == beforeJob and members[recruit.identifier].lost == 0, 'faction never replaces primary job')
check(not api.rpHasFaction('char2:other', 'lost') and api.rpHasFaction('char1:other', 'lost'), 'same-account characters have independent memberships')
check(#api.rpGetMemberships('other') == 0 and #api.rpGetMemberships('char2:other') == 0, 'raw account and unrelated character rejected')
check(action('hire', { kind = 'faction', name = 'lost', target = 2, grade = 0 }).error == 'already_member', 'duplicate membership rejected')
members[recruit.identifier].lost = nil members[recruit.identifier].a = 0 members[recruit.identifier].b = 0 members[recruit.identifier].c = 0
check(action('hire', { kind = 'faction', name = 'lost', target = 2, grade = 0 }).error == 'membership_conflict', 'per-character faction limit enforced')
members[recruit.identifier] = { lost = 0 }
token = memberToken(recruit.identifier, 'faction', 'lost')
players[2] = nil
check(action('promote', { kind = 'faction', name = 'lost', member = token, grade = 1 }).ok, 'offline faction promotion supported')
token = memberToken(recruit.identifier, 'faction', 'lost')
check(action('fire', { kind = 'faction', name = 'lost', member = token }).ok and not members[recruit.identifier].lost, 'offline faction removal')
players[2] = recruit
admin = true
local createdJob = action('create', { name = 'harbor', label = 'Hafendienst' })
check(createdJob.ok and jobs.harbor.grades['2'].name == 'boss', 'administrator creates standard ESX job with three default ranks')
check(societies.harbor.account == 'society_harbor', 'created job registers standard society account contract')
local pendingSociety = createdJob.organizations.list
for _, org in ipairs(pendingSociety) do if org.name == 'harbor' then check(org.balance == nil and not org.finance, 'new society stays unavailable until upstream cache loads') end end
check(action('create', { kind = 'faction', name = 'new_team', label = 'Neues Team' }).ok and factions.new_team, 'administrator creates faction')
check(action('create', { kind = 'faction', name = 'new_team', label = 'Duplicate' }).error == 'already_exists', 'duplicate organization rejected')
sqlHook = function() admin = false end
check(action('create', { kind = 'faction', name = 'revoked', label = 'Revoked' }).error == 'forbidden' and not factions.revoked, 'permission revocation after await rechecked')
local oldCtx = S.context(1)
players[1] = player(1, 'char2:account', 'unemployed', 0)
check(not S.alive(oldCtx), 'reused server ID cannot authorize old character')
check(not api.rpHasFaction('char2:account', 'lost') and api.rpHasFaction('char1:account', 'lost'), 'switching character isolates faction leadership')
local secondView = action('view').organizations
check(#secondView.list == 1 and secondView.list[1].name == 'unemployed' and not secondView.list[1].manage, 'second character does not inherit job permissions')
players[1], admin = boss, true
sqlFailure = true
check(action('rename', { label = 'Fail' }).error == 'database_error', 'database error reported')
sqlFailure = false
check(action('view').ok, 'request lock released after exception')
sqlHook = function()
    check(call({ action = 'duty', kind = 'job', name = 'police', duty = false }, 2).error == 'busy', 'concurrent mutation rejected during SQL')
end
check(action('rename', { label = 'Police' }).ok, 'global mutation lock released after operation')
local previousSession = S.context(1)
source = 1 events.playerDropped()
check(S.tokens[1] == nil, 'drop cleans member capabilities')
check(not S.alive(previousSession), 'same-character reconnect cannot resume an old asynchronous request')
events.onResourceStop('rp_organizations')
check(action('view').error == 'server_starting', 'stopped domain rejects requests')
print(('PASS: %d organization permission, ESX integration and character-isolation checks'):format(count))
