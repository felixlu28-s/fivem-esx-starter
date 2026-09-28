local S, P, C = Organizations.Service, Organizations.Policy, Organizations.Config
local J = {}
Organizations.Jobs = J
function J.summary(ctx, name, job)
    local own = ctx.player.getJob()
    local manage = P.manage(S.admin(ctx), own, 'job', name)
    local grades = {}
    for _, grade in pairs(job.grades) do
        grades[#grades + 1] = { grade = tonumber(grade.grade), name = grade.name, label = grade.label, salary = tonumber(grade.salary) }
    end
    table.sort(grades, function(a, b) return a.grade < b.grade end)
    local account = manage and S.account(name) or nil
    return { kind = 'job', name = name, label = job.label, grades = grades, manage = manage,
        own = own.name == name, duty = own.name == name and own.onDuty == true,
        balance = account and account.money or nil,
        finance = account ~= nil and own.name == name and own.grade_name == 'boss' }
end
function J.members(ctx, name)
    local rows = MySQL.query.await([[SELECT identifier, firstname, lastname, job_grade FROM users
        WHERE job = ? ORDER BY job_grade DESC, lastname, firstname LIMIT ?]], { name, C.memberLimit })
    local result, seen = {}, {}
    -- Online ESX state wins over SQL, including unsaved changes from other scripts.
    for _, player in pairs(S.ESX.GetExtendedPlayers()) do
        local job = player.getJob()
        seen[player.identifier] = true
        if job.name == name and P.character(player.identifier) then
            result[#result + 1] = S.publicMember(ctx, 'job', name, player.identifier, player.getName(), job.grade)
        end
    end
    for _, row in ipairs(rows) do
        if not seen[row.identifier] and P.character(row.identifier) then
            result[#result + 1] = S.publicMember(ctx, 'job', name, row.identifier,
                (row.firstname or '') .. ' ' .. (row.lastname or ''), row.job_grade)
        end
    end
    return result
end
function J.change(ctx, input)
    local job = S.jobs()[input.name]
    if not job or input.name == 'unemployed' then return S.fail('invalid_fields') end
    if not S.canManage(ctx, 'job', input.name) then return S.fail('forbidden') end
    local target
    if input.action == 'hire' then
        if not P.integer(input.target, 1, 65535) then return S.fail('invalid_fields') end
        target = S.ESX.GetPlayerFromId(input.target)
        if not target or not target.spawned or not P.character(target.identifier) or not S.near(ctx, target) then return S.fail('target_unavailable') end
        if not S.admin(ctx) and target.getJob().name ~= 'unemployed' then return S.fail('target_employed') end
    else
        local identifier = S.resolve(ctx, input)
        if not identifier then return S.fail('stale_members') end
        target = S.ESX.GetPlayerFromIdentifier(identifier)
        if not target or not target.spawned then return S.fail('member_offline') end
        if target.getJob().name ~= input.name then return S.fail('stale_members') end
    end
    local nextGrade = input.grade
    if input.action == 'fire' then nextGrade = nil end
    if input.action ~= 'fire' and (not P.integer(nextGrade, 0, 99) or not job.grades[tostring(nextGrade)]) then return S.fail('invalid_fields') end
    local actorGrade = tonumber(ctx.player.getJob().grade)
    local targetGrade = input.action == 'hire' and -1 or tonumber(target.getJob().grade)
    if not P.memberChange(S.admin(ctx), actorGrade, targetGrade, nextGrade, ctx.identifier == target.identifier) then return S.fail('forbidden') end
    if not S.alive(ctx) then return S.fail('player_unavailable') end
    local duty = input.action == 'promote' and target.getJob().onDuty == true
    target.setJob(input.action == 'fire' and 'unemployed' or input.name, nextGrade or 0, duty)
    S.savePlayer(target)
    S.audit(ctx, input.action, 'job', input.name, target.identifier, tostring(nextGrade or 0))
    return { ok = true }
end
function J.duty(ctx, input)
    local job = ctx.player.getJob()
    if job.name == 'unemployed' or job.name ~= input.name or type(input.duty) ~= 'boolean' then return S.fail('forbidden') end
    ctx.player.setJob(job.name, job.grade, input.duty)
    S.savePlayer(ctx.player)
    S.audit(ctx, 'duty', 'job', job.name, nil, tostring(input.duty))
    return { ok = true }
end
function J.money(ctx, input)
    local job = ctx.player.getJob()
    if job.name ~= input.name or job.grade_name ~= 'boss' then return S.fail('forbidden') end
    if not P.integer(input.amount, 1, C.maxTransfer) then return S.fail('invalid_fields') end
    local account = S.account(input.name)
    if not account then return S.fail('society_pending') end
    -- No yields between balance checks and standard ESX account mutations.
    if input.action == 'deposit' then
        if ctx.player.getMoney() < input.amount then return S.fail('insufficient_money') end
        ctx.player.removeMoney(input.amount, 'Society deposit')
        account.addMoney(input.amount)
    else
        if account.money < input.amount then return S.fail('insufficient_money') end
        account.removeMoney(input.amount)
        ctx.player.addMoney(input.amount, 'Society withdrawal')
    end
    S.savePlayer(ctx.player)
    S.audit(ctx, input.action, 'job', input.name, nil, tostring(input.amount))
    return { ok = true }
end
function J.grade(ctx, input)
    if not S.canManage(ctx, 'job', input.name) then return S.fail('forbidden') end
    local job, label = S.jobs()[input.name], P.label(input.label)
    if not job or not P.integer(input.grade, 0, 99) or not job.grades[tostring(input.grade)]
        or not label or not P.integer(input.salary, 0, C.maxSalary) then return S.fail('invalid_fields') end
    if not S.admin(ctx) and input.grade >= ctx.player.getJob().grade then return S.fail('forbidden') end
    MySQL.update.await('UPDATE job_grades SET label = ?, salary = ? WHERE job_name = ? AND grade = ?',
        { label, input.salary, input.name, input.grade })
    S.ESX.RefreshJob(input.name) -- refreshes every online member using standard ESX events
    S.audit(ctx, 'grade', 'job', input.name, nil, tostring(input.grade))
    return { ok = true }
end
