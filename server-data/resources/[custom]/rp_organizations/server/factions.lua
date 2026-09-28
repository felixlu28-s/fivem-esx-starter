local S, P, C = Organizations.Service, Organizations.Policy, Organizations.Config
local F = {}
Organizations.Factions = F
F.grades = {
    { grade = 0, name = 'member', label = 'Mitglied', salary = 0 },
    { grade = 1, name = 'officer', label = 'Stellvertretung', salary = 0 },
    { grade = 2, name = 'boss', label = 'Leitung', salary = 0 },
}
function F.list(ctx)
    local rows = MySQL.query.await([[SELECT f.name, f.label, m.grade FROM rp_factions f
        LEFT JOIN rp_faction_members m ON m.faction = f.name AND m.identifier = ?
        WHERE (? = 1 OR m.identifier IS NOT NULL) ORDER BY f.label]], { ctx.identifier, S.admin(ctx) and 1 or 0 })
    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = { kind = 'faction', name = row.name, label = row.label, grades = F.grades,
            own = row.grade ~= nil, manage = S.admin(ctx) or tonumber(row.grade) == 2,
            duty = false, finance = false }
    end
    return result
end
function F.members(ctx, name)
    local rows = MySQL.query.await([[SELECT m.identifier, m.grade, u.firstname, u.lastname
        FROM rp_faction_members m JOIN users u ON u.identifier = m.identifier COLLATE utf8mb4_bin
        WHERE m.faction = ? ORDER BY m.grade DESC, u.lastname LIMIT ?]], { name, C.memberLimit })
    local result = {}
    for _, row in ipairs(rows) do
        result[#result + 1] = S.publicMember(ctx, 'faction', name, row.identifier,
            (row.firstname or '') .. ' ' .. (row.lastname or ''), row.grade)
    end
    return result
end
function F.change(ctx, input)
    if not S.canManage(ctx, 'faction', input.name) then return S.fail('forbidden') end
    local actor = S.membership(ctx.identifier, input.name)
    local identifier, previous, recruited
    if input.action == 'hire' then
        if not P.integer(input.target, 1, 65535) then return S.fail('invalid_fields') end
        local target = S.ESX.GetPlayerFromId(input.target)
        if not target or not target.spawned or not P.character(target.identifier) or not S.near(ctx, target) then return S.fail('target_unavailable') end
        identifier = target.identifier
        recruited = target
        previous = S.membership(identifier, input.name)
        if previous then return S.fail('already_member') end
    else
        identifier = S.resolve(ctx, input)
        if not identifier then return S.fail('stale_members') end
        previous = S.membership(identifier, input.name)
        if not previous then return S.fail('stale_members') end
    end
    local nextGrade = input.grade
    if input.action == 'fire' then nextGrade = nil end
    if input.action ~= 'fire' and not P.integer(nextGrade, 0, 2) then return S.fail('invalid_fields') end
    if not S.canManage(ctx, 'faction', input.name) or not P.memberChange(S.admin(ctx), actor and actor.grade or -1,
        previous and previous.grade or -1, nextGrade, identifier == ctx.identifier) then return S.fail('forbidden') end
    local affected
    if recruited then
        local live = S.ESX.GetPlayerFromId(recruited.source)
        if not live or live.identifier ~= identifier or not live.spawned or not S.near(ctx, live) then return S.fail('target_unavailable') end
    end
    if input.action == 'hire' then
        -- Check the cap in the INSERT; this resource serializes all its mutations.
        affected = MySQL.update.await([[INSERT INTO rp_faction_members (faction, identifier, grade)
            SELECT name, ?, ? FROM rp_factions WHERE name = ? AND
            (SELECT COUNT(*) FROM rp_faction_members WHERE identifier = ?) < ?]],
            { identifier, nextGrade, input.name, identifier, C.maxFactionsPerCharacter })
    elseif input.action == 'fire' then
        affected = MySQL.update.await('DELETE FROM rp_faction_members WHERE faction = ? AND identifier = ? AND grade = ?',
            { input.name, identifier, previous.grade })
    else
        affected = MySQL.update.await('UPDATE rp_faction_members SET grade = ? WHERE faction = ? AND identifier = ? AND grade = ?',
            { nextGrade, input.name, identifier, previous.grade })
    end
    if affected == 0 then return S.fail('membership_conflict') end
    S.audit(ctx, input.action, 'faction', input.name, identifier, tostring(nextGrade or -1))
    TriggerEvent('rp_organizations:membershipChanged', identifier, input.name, nextGrade)
    return { ok = true }
end
