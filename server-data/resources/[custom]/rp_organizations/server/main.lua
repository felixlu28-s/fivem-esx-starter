local S, J, F = Organizations.Service, Organizations.Jobs, Organizations.Factions
local P, C = Organizations.Policy, Organizations.Config
local requests, writing = {}, false
local function snapshot(ctx, input)
    local organizations = F.list(ctx)
    if not S.alive(ctx) then return S.fail('player_unavailable') end
    for name, job in pairs(S.jobs()) do
        if (S.admin(ctx) and name ~= 'unemployed') or ctx.player.getJob().name == name then
            organizations[#organizations + 1] = J.summary(ctx, name, job)
        end
    end
    table.sort(organizations, function(a, b)
        if a.kind == b.kind then return a.label < b.label end
        return a.kind == 'job'
    end)
    local selected
    for _, org in ipairs(organizations) do
        if org.kind == input.kind and org.name == input.name then selected = org break end
    end
    if not selected then
        for _, org in ipairs(organizations) do if org.own then selected = org break end end
        selected = selected or organizations[1]
    end
    local members, candidates = {}, {}
    S.tokens[ctx.source] = { identifier = ctx.identifier, entries = {} }
    if selected and selected.manage then
        members = selected.kind == 'job' and J.members(ctx, selected.name) or F.members(ctx, selected.name)
        if not S.canManage(ctx, selected.kind, selected.name) then return S.fail('forbidden') end
        for _, target in pairs(S.ESX.GetExtendedPlayers()) do
            if target.spawned and P.character(target.identifier) and (S.admin(ctx) or target.identifier ~= ctx.identifier)
                and S.near(ctx, target) then
                candidates[#candidates + 1] = { id = target.source, name = target.getName() }
            end
        end
        table.sort(candidates, function(a, b) return a.name < b.name end)
    end
    if not S.alive(ctx) then return S.fail('player_unavailable') end
    return { ok = true, organizations = { admin = S.admin(ctx), character = ctx.player.getName(),
        list = organizations, selected = selected and selected.kind .. ':' .. selected.name or '',
        members = members, candidates = candidates, memberLimit = C.memberLimit } }
end
local function create(ctx, input)
    if not S.admin(ctx) then return S.fail('forbidden') end
    local label = P.label(input.label)
    if not P.code(input.name) or not label or input.name == 'unemployed' then return S.fail('invalid_fields') end
    if input.kind == 'faction' then
        if MySQL.scalar.await('SELECT name FROM rp_factions WHERE name = ?', { input.name }) then return S.fail('already_exists') end
        if not S.admin(ctx) then return S.fail('forbidden') end
        MySQL.insert.await('INSERT INTO rp_factions (name, label) VALUES (?, ?)', { input.name, label })
    else
        if S.jobs()[input.name] or MySQL.scalar.await('SELECT name FROM jobs WHERE name = ?', { input.name }) then return S.fail('already_exists') end
        if not S.admin(ctx) then return S.fail('forbidden') end
        local key = 'society_' .. input.name
        local queries = {
            { query = "INSERT INTO jobs (name, label, type, whitelisted) VALUES (?, ?, 'civ', 1)", values = { input.name, label } },
            { query = 'INSERT IGNORE INTO addon_account (name, label, shared) VALUES (?, ?, 1)', values = { key, label } },
            { query = 'INSERT INTO addon_account_data (account_name, money) SELECT ?, 0 WHERE NOT EXISTS (SELECT 1 FROM addon_account_data WHERE account_name = ? AND owner IS NULL)', values = { key, key } },
            { query = 'INSERT IGNORE INTO addon_inventory (name, label, shared) VALUES (?, ?, 1)', values = { key, label } },
            { query = 'INSERT IGNORE INTO datastore (name, label, shared) VALUES (?, ?, 1)', values = { key, label } },
        }
        for _, grade in ipairs(F.grades) do
            queries[#queries + 1] = { query = "INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female) VALUES (?, ?, ?, ?, 0, '{}', '{}')",
                values = { input.name, grade.grade, grade.name, grade.label } }
        end
        if not MySQL.transaction.await(queries) then return S.fail('database_error') end
        S.ESX.RefreshJob(input.name)
        S.registerSociety(input.name, S.jobs()[input.name])
        -- ESX addon caches load their new account/stash at the next restart.
        -- Never flush all live addon accounts to initialize just one new job.
    end
    S.audit(ctx, 'create', input.kind, input.name)
    return { ok = true }
end
local function rename(ctx, input)
    if not S.admin(ctx) then return S.fail('forbidden') end
    local label = P.label(input.label)
    if not label then return S.fail('invalid_fields') end
    if input.kind == 'job' then
        if not S.jobs()[input.name] or input.name == 'unemployed' then return S.fail('invalid_fields') end
        MySQL.update.await('UPDATE jobs SET label = ? WHERE name = ?', { label, input.name })
        S.ESX.RefreshJob(input.name)
    else
        MySQL.update.await('UPDATE rp_factions SET label = ? WHERE name = ?', { label, input.name })
    end
    S.audit(ctx, 'rename', input.kind, input.name)
    return { ok = true }
end
local function addGrade(ctx, input)
    if not S.admin(ctx) or input.kind ~= 'job' then return S.fail('forbidden') end
    local job, label = S.jobs()[input.name], P.label(input.label)
    if not job or input.name == 'unemployed' or not P.integer(input.grade, 0, 99) or job.grades[tostring(input.grade)]
        or not label or not P.code(input.rankName) or not P.integer(input.salary, 0, C.maxSalary) then return S.fail('invalid_fields') end
    MySQL.insert.await([[INSERT INTO job_grades (job_name, grade, name, label, salary, skin_male, skin_female)
        SELECT ?, ?, ?, ?, ?, '{}', '{}' WHERE NOT EXISTS (SELECT 1 FROM job_grades WHERE job_name = ? AND grade = ?)]],
        { input.name, input.grade, input.rankName, label, input.salary, input.name, input.grade })
    S.ESX.RefreshJob(input.name)
    S.audit(ctx, 'addGrade', 'job', input.name, nil, tostring(input.grade))
    return { ok = true }
end
local mutations = { hire = true, promote = true, fire = true, duty = true, deposit = true, withdraw = true,
    grade = true, create = true, rename = true, addGrade = true }
lib.callback.register('rp_organizations:request', function(source, input)
    if not S.ready then return S.fail('server_starting') end
    if type(input) ~= 'table' or (input.action ~= 'view' and not mutations[input.action]) then return S.fail('invalid_fields') end
    if input.action ~= 'view' and (not P.code(input.name) or (input.kind ~= 'job' and input.kind ~= 'faction')) then return S.fail('invalid_fields') end
    local ctx = S.context(source)
    if not ctx then return S.fail('player_unavailable') end
    local now, old = GetGameTimer(), requests[source]
    if old and old.identifier == ctx.identifier and (old.busy or now - old.time < (input.action == 'view' and 200 or C.cooldownMs)) then return S.fail('rate_limited') end
    local record = { identifier = ctx.identifier, time = now, busy = true }
    requests[source] = record
    if input.action ~= 'view' and writing then record.busy = false return S.fail('busy') end
    local ownsWrite = input.action ~= 'view'
    if ownsWrite then writing = true end
    local ok, result = pcall(function()
        if input.action == 'view' then return snapshot(ctx, input) end
        local changed
        if input.action == 'create' then changed = create(ctx, input)
        elseif input.action == 'rename' then changed = rename(ctx, input)
        elseif input.action == 'addGrade' then changed = addGrade(ctx, input)
        elseif input.action == 'hire' or input.action == 'promote' or input.action == 'fire' then
            changed = input.kind == 'job' and J.change(ctx, input) or F.change(ctx, input)
        elseif input.kind ~= 'job' then return S.fail('invalid_fields')
        elseif input.action == 'duty' then changed = J.duty(ctx, input)
        elseif input.action == 'grade' then changed = J.grade(ctx, input)
        else changed = J.money(ctx, input) end
        if not changed.ok then return changed end
        -- A committed action is successful even if the subsequent UI reload fails.
        local loaded, fresh = pcall(snapshot, ctx, input)
        return loaded and fresh.ok and fresh or { ok = true }
    end)
    record.busy = false
    if ownsWrite then writing = false end
    if not ok then
        print('[rp_organizations] Request failed; check database/dependency diagnostics.')
        return S.fail('database_error')
    end
    return result
end)
-- Server-only integration for secondary-faction scripts; no account identifiers accepted.
exports('rpGetMemberships', function(identifier)
    if not S.ready or not P.character(identifier) then return {} end
    return MySQL.query.await('SELECT faction, grade FROM rp_faction_members WHERE identifier = ?', { identifier })
end)
exports('rpHasFaction', function(identifier, name, minimumGrade)
    if not S.ready or not P.character(identifier) or not P.code(name) or not P.integer(minimumGrade or 0, 0, 2) then return false end
    local membership = S.membership(identifier, name)
    return membership ~= nil and membership.grade >= (minimumGrade or 0)
end)
local function clearSession(id)
    requests[id], S.tokens[id] = nil, nil
    S.generations[id] = (S.generations[id] or 0) + 1
end
AddEventHandler('playerDropped', function() clearSession(source) end)
AddEventHandler('esx:playerLogout', clearSession)
AddEventHandler('esx:jobRefreshed', function(name, job) if job then S.registerSociety(name, job) end end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then S.ready = false S.tokens = {} requests = {} end
end)
MySQL.ready(function()
    local ok = pcall(function()
        MySQL.query.await('SELECT identifier FROM rp_faction_members LIMIT 0')
        MySQL.query.await('SELECT actor FROM rp_organization_audit LIMIT 0')
        local deadline = GetGameTimer() + 30000
        while not S.jobs().unemployed and GetGameTimer() < deadline do Wait(100) end
        assert(S.jobs().unemployed, 'ESX jobs unavailable')
        for name, job in pairs(S.jobs()) do S.registerSociety(name, job) end
    end)
    S.ready = ok
    print(ok and '[rp_organizations] ESX societies and character factions ready.' or '[rp_organizations] Startup failed. Check migrations and dependencies.')
end)
