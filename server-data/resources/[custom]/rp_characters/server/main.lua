local ESX = exports.es_extended:getSharedObject()
local C, V, A = Characters.Config, Characters.Validation, Characters.Appearance
local sessions, owners, locks = {}, {}, {}
local ready = false
local function failure(code) return { ok = false, error = code } end
local function jobsReady()
    -- Cross-resource exports copy tables. ESX.RefreshJobs replaces ESX.Jobs
    -- after startup; the Jobs table on our cached ESX object stays stale.
    -- Read a fresh snapshot without calling the indefinitely waiting GetJobs().
    local jobs = exports.es_extended:getSharedObject().Jobs
    local unemployed = type(jobs) == 'table' and jobs.unemployed
    return type(unemployed) == 'table' and type(unemployed.grades) == 'table'
        and unemployed.grades['0'] ~= nil
end
local function decode(value)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' then return nil end
    local ok, data = pcall(json.decode, value)
    return ok and data or nil
end
local function alive(s)
    return sessions[s.source] == s and GetPlayerName(s.source) ~= nil
end
local function accountOf(source)
    local ok, identifier = pcall(ESX.GetIdentifier, source)
    if not ok or type(identifier) ~= 'string' or #identifier > 50 or not identifier:match('^[%w%-]+$') then return nil end
    return identifier
end
local function accountLock(account, action)
    if locks[account] then return failure('busy') end
    locks[account] = true
    local ok, result = pcall(action)
    locks[account] = nil
    if not ok then
        print('[rp_characters] Database operation failed; see oxmysql diagnostics. Session remains recoverable.')
        return failure('database_error')
    end
    return result
end

-- ESX can inherit a newer database collation than our migrations. Explicitly
-- compare character identifiers as utf8mb4_bin in both cross-resource joins.
local function list(s)
    local slots = tonumber(MySQL.scalar.await('SELECT slots FROM rp_character_accounts WHERE identifier = ?', { s.account }))
    local rows = MySQL.query.await([[
        SELECT c.slot, c.esx_identifier, u.firstname, u.lastname, u.dateofbirth, u.sex, u.height, u.skin,
            COALESCE(j.label, 'Bürger') AS job
        FROM rp_character_slots c JOIN users u ON u.identifier = c.esx_identifier COLLATE utf8mb4_bin
        LEFT JOIN jobs j ON j.name = u.job
        WHERE c.account_identifier = ? ORDER BY c.slot
    ]], { s.account })
    local characters = {}
    for _, row in ipairs(rows) do
        characters[#characters + 1] = {
            slot = tonumber(row.slot), firstname = row.firstname, lastname = row.lastname,
            dateofbirth = row.dateofbirth, gender = row.sex, height = tonumber(row.height), job = row.job,
            skin = exports.rp_inventory:rpResolveClothing(row.esx_identifier, A.validate(decode(row.skin)) or A.defaults(row.sex == 'f' and 1 or 0)),
        }
    end
    return { ok = true, slots = slots, characters = characters }
end

local function checkpoint(s)
    if s.state ~= 'active' or not s.identifier then return end
    local ped = GetPlayerPed(s.source)
    if ped == 0 or not DoesEntityExist(ped) then return end
    local coords = GetEntityCoords(ped)
    local position = V.position({ x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) })
    if not position then return end
    s.position = position
    -- Dedicated checkpoints are immune to ESX saving an already-despawned ped on disconnect.
    MySQL.update.await('UPDATE rp_character_slots SET last_position = ?, last_seen = CURRENT_TIMESTAMP WHERE esx_identifier = ?',
        { json.encode(position), s.identifier })
end

local function login(s, slot)
    if not V.integer(slot, 1, C.maxSlots) or s.state ~= 'selecting' then return failure('invalid_state') end
    local row = MySQL.single.await([[
        SELECT c.esx_identifier, c.last_position, u.position, u.skin, u.sex
        FROM rp_character_slots c JOIN users u ON u.identifier = c.esx_identifier COLLATE utf8mb4_bin
        WHERE c.account_identifier = ? AND c.slot = ? LIMIT 1
    ]], { s.account, slot })
    if not alive(s) then return failure('session_expired') end
    if not row then return failure('not_found') end
    if ESX.GetPlayerFromId(s.source) or ESX.GetPlayerFromIdentifier(row.esx_identifier) then return failure('already_loaded') end
    if not jobsReady() then return failure('server_starting') end
    s.identifier, s.slot, s.state = row.esx_identifier, slot, 'loading'
    s.spawn = {
        position = V.position(decode(row.last_position)) or V.position(decode(row.position)) or C.arrival,
        skin = exports.rp_inventory:rpResolveClothing(row.esx_identifier, A.validate(decode(row.skin)) or A.defaults(row.sex == 'f' and 1 or 0)),
    }
    -- Only this server-local event may ask ESX to load an account-owned slot.
    TriggerEvent('esx:onPlayerJoined', s.source, 'char' .. slot)
    SetTimeout(C.loginTimeoutMs, function()
        if alive(s) and s.state ~= 'active' then
            DropPlayer(s.source, 'Der Charakter konnte nicht geladen werden. Bitte erneut verbinden. [rp_characters:login_timeout]')
        end
    end)
    return { ok = true }
end

local function register(name, action, allowLoading)
    lib.callback.register('rp_characters:' .. name, function(source, input)
        local s = sessions[source]
        if not ready then return failure('server_starting') end
        if not s or not alive(s) then return failure('session_expired') end
        if s.busy then return failure('busy') end
        if s.state ~= 'selecting' and not allowLoading then return failure('invalid_state') end
        local now = GetGameTimer()
        if s.times[name] and now - s.times[name] < C.requestCooldownMs then
            return { ok = false, error = 'rate_limited', retryAfterMs = C.requestCooldownMs - (now - s.times[name]) }
        end
        s.times[name], s.busy = now, true
        local ok, result = pcall(action, s, input)
        s.busy = false
        if not ok then
            print(('[rp_characters] %s failed; check server/database diagnostics.'):format(name))
            return failure('database_error')
        end
        if not alive(s) then return failure('session_expired') end
        return result
    end)
end

lib.callback.register('rp_characters:bootstrap', function(source)
    if not ready then return failure('server_starting') end
    local account = accountOf(source)
    if not account then return failure('identifier_missing') end
    if ESX.GetPlayerFromId(source) then return failure('already_loaded') end
    if owners[account] and owners[account] ~= sessions[source] then return failure('account_in_use') end
    local s = sessions[source]
    if not s then
        s = { source = source, account = account, state = 'selecting', times = {} }
        sessions[source], owners[account] = s, s
        s.bucket = 10000 + source
        SetRoutingBucketPopulationEnabled(s.bucket, false)
        SetRoutingBucketEntityLockdownMode(s.bucket, 'strict')
        SetPlayerRoutingBucket(source, s.bucket)
    end
    if s.busy or s.state ~= 'selecting' then return failure('busy') end
    local now = GetGameTimer()
    if s.times.bootstrap and now - s.times.bootstrap < 1500 then
        return { ok = false, error = 'rate_limited', retryAfterMs = 1500 - (now - s.times.bootstrap) }
    end
    s.times.bootstrap, s.busy = now, true
    local result = accountLock(account, function()
        MySQL.insert.await('INSERT IGNORE INTO rp_character_accounts (identifier, slots) VALUES (?, ?)', { account, C.defaultSlots })
        if not alive(s) then return failure('session_expired') end
        return list(s)
    end)
    s.busy = false
    if not alive(s) then return failure('session_expired') end
    return result
end)

register('list', list)
register('select', function(s, input)
    return login(s, type(input) == 'table' and input.slot or nil)
end)

register('create', function(s, input)
    -- A repeated request in the same session resumes the committed character.
    -- The client must select it before it can start another creation session.
    if s.createdSlot then return { ok = true, slot = s.createdSlot } end
    if type(input) ~= 'table' or type(input.identity) ~= 'table' then return failure('invalid_fields') end
    local id = input.identity
    local firstname, lastname = V.name(id.firstname), V.name(id.lastname)
    local skin = A.validateCreation(input.skin)
    if not firstname or not lastname or not V.birthdate(id.dateofbirth, os.date('!*t'))
        or not V.integer(id.height, 120, 230) or not skin then return failure('invalid_fields') end
    if not jobsReady() then return failure('server_starting') end
    return accountLock(s.account, function()
        local roster = list(s)
        if not alive(s) then return failure('session_expired') end
        if #roster.characters >= roster.slots then return failure('character_limit') end
        local used = {}
        for _, character in ipairs(roster.characters) do used[character.slot] = true end
        local slot
        for index = 1, roster.slots do if not used[index] then slot = index break end end
        if not slot then return failure('character_limit') end
        local identifier = ('char%d:%s'):format(slot, s.account)
        local accounts = ESX.GetConfig('StartingAccountMoney')
        local ssn = ('%03d-%02d-%04d'):format(math.random(100, 599), math.random(1, 99), math.random(1, 9999))
        local success = MySQL.transaction.await({
            { query = 'UPDATE rp_character_accounts SET slots = slots WHERE identifier = ?', values = { s.account } },
            { query = [[INSERT INTO rp_character_slots (account_identifier, slot, esx_identifier, last_position)
                SELECT identifier, ?, ?, ? FROM rp_character_accounts
                WHERE identifier = ? AND slots >= ? AND
                (SELECT COUNT(*) FROM rp_character_slots WHERE account_identifier = ?) < slots]],
                values = { slot, identifier, json.encode(C.arrival), s.account, slot, s.account } },
            { query = [[INSERT INTO users (identifier, ssn, accounts, firstname, lastname, dateofbirth, sex, height,
                skin, position, inventory, loadout, metadata, `group`, job, job_grade)
                SELECT esx_identifier, ?, ?, ?, ?, ?, ?, ?, ?, ?, '{}', '{}', '{}', 'user', 'unemployed', 0
                FROM rp_character_slots WHERE account_identifier = ? AND slot = ?]],
                values = { ssn, json.encode(accounts), firstname, lastname, id.dateofbirth,
                    skin.sex == 1 and 'f' or 'm', id.height, json.encode(skin), json.encode(C.arrival), s.account, slot } },
        })
        if not success then return failure('database_error') end
        s.createdSlot = slot
        if not alive(s) then return failure('session_expired') end
        -- Commit acknowledgement is independent of ESX login readiness.
        return { ok = true, slot = slot }
    end)
end)

register('spawnData', function(s)
    local player = ESX.GetPlayerFromId(s.source)
    if s.state ~= 'loading' or not player or player.identifier ~= s.identifier then return failure('invalid_state') end
    return { ok = true, position = s.spawn.position, skin = exports.rp_inventory:rpResolveClothing(s.identifier, s.spawn.skin) }
end, true)

register('spawned', function(s)
    local player = ESX.GetPlayerFromId(s.source)
    if s.state == 'active' and player and player.identifier == s.identifier then return { ok = true } end
    if s.state ~= 'loading' or not player or player.identifier ~= s.identifier then return failure('invalid_state') end
    if player.spawned ~= true then return failure('spawn_pending') end
    local ped = GetPlayerPed(s.source)
    if ped == 0 or not DoesEntityExist(ped) then return failure('spawn_pending') end
    local coords, target = GetEntityCoords(ped), s.spawn.position
    if #(coords - vector3(target.x, target.y, target.z)) > 30 then return failure('spawn_pending') end
    s.state, s.position = 'active', target
    SetPlayerRoutingBucket(s.source, 0)
    local saved = pcall(checkpoint, s)
    if not saved then print('[rp_characters] Initial checkpoint failed; periodic retry remains active.') end
    return { ok = true }
end, true)

RegisterCommand('rp_character_slots', function(source, args)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.rp_character_slots') then return end
    local slots = tonumber(args[2])
    local target = tonumber(args[1])
    local account = target and accountOf(target) or (type(args[1]) == 'string' and args[1]:gsub('^license:', '') or nil)
    if not account or not account:match('^[%w%-]+$') or #account > 50 or not V.integer(slots, 1, C.maxSlots) then
        print('[rp_characters] Usage: rp_character_slots <server-id|license:identifier> <1-8>')
        return
    end
    local result = accountLock(account, function()
        local highest = tonumber(MySQL.scalar.await('SELECT COALESCE(MAX(slot), 0) FROM rp_character_slots WHERE account_identifier = ?', { account }))
        if slots < highest then return failure('occupied_slots') end
        MySQL.update.await('INSERT INTO rp_character_accounts (identifier, slots) VALUES (?, ?) ON DUPLICATE KEY UPDATE slots = VALUES(slots)', { account, slots })
        return { ok = true }
    end)
    print(('[rp_characters] Slot update: %s. Changes appear on next login or list refresh.'):format(result.ok and 'saved' or result.error))
end, true)

RegisterCommand('rp_characters_status', function(source)
    if source ~= 0 and not IsPlayerAceAllowed(source, 'command.rp_characters_status') then return end
    local selecting, active = 0, 0
    for _, s in pairs(sessions) do
        if s.state == 'active' then active = active + 1 else selecting = selecting + 1 end
    end
    print(('[rp_characters] ESX multichar=%s; database ready=%s; jobs ready=%s; selecting/loading=%d; active=%d')
        :format(tostring(ESX.GetConfig('Multichar')), tostring(ready), tostring(jobsReady()), selecting, active))
end, true)

AddEventHandler('playerDropped', function()
    local s = sessions[source]
    if not s then return end
    -- Capture before yielding: a reused server ID must never supply another player's position.
    local position = s.position
    local ped = GetPlayerPed(s.source)
    if s.state == 'active' and ped ~= 0 and DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        position = V.position({ x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }) or position
    end
    sessions[source] = nil
    if owners[s.account] == s then owners[s.account] = nil end
    if s.state == 'active' and position then
        MySQL.update('UPDATE rp_character_slots SET last_position = ?, last_seen = CURRENT_TIMESTAMP WHERE esx_identifier = ?',
            { json.encode(position), s.identifier })
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for _, s in pairs(sessions) do
        SetPlayerRoutingBucket(s.source, 0)
        DropPlayer(s.source, 'Charakterverwaltung wird neu gestartet. Bitte erneut verbinden.')
    end
end)

MySQL.ready(function()
    if ESX.GetConfig('Multichar') ~= true then
        print('^1[rp_characters] ESX multicharacter mode is disabled. Fully restart FXServer after installing the resource alias.^0')
        return
    end
    local ok = pcall(function()
        MySQL.query.await('SELECT identifier, slots FROM rp_character_accounts LIMIT 0')
        MySQL.query.await('SELECT account_identifier, slot, last_position FROM rp_character_slots LIMIT 0')
    end)
    ready = ok
    if not ok then print('^1[rp_characters] Run migrations/002_account_characters.sql before joining.^0') end
    if ok then print('[rp_characters] Account slots and character login ready (ESX multicharacter enabled).') end
end)

CreateThread(function()
    while true do
        Wait(C.checkpointSeconds * 1000)
        for _, s in pairs(sessions) do
            if alive(s) and s.state == 'active' then
                local ok = pcall(checkpoint, s)
                if not ok then print('[rp_characters] Position checkpoint failed; retrying next interval.') end
            end
        end
    end
end)
