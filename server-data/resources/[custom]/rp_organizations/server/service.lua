local S = { ready = false, tokens = {}, generations = {}, sequence = 0 }
Organizations.Service = S
S.ESX = exports.es_extended:getSharedObject()
local C, P = Organizations.Config, Organizations.Policy
function S.fail(code) return { ok = false, error = code } end
function S.jobs() return exports.es_extended:getSharedObject().Jobs or {} end
function S.context(source)
    local player = S.ESX.GetPlayerFromId(source)
    if not player or not player.spawned or not P.character(player.identifier) then return nil end
    return { source = source, player = player, identifier = player.identifier, generation = S.generations[source] or 0,
        admin = IsPlayerAceAllowed(source, C.adminAce) }
end
function S.alive(ctx)
    local player = S.ESX.GetPlayerFromId(ctx.source)
    return player ~= nil and player.identifier == ctx.identifier and player.spawned == true
        and ctx.generation == (S.generations[ctx.source] or 0)
end
function S.admin(ctx) return S.alive(ctx) and IsPlayerAceAllowed(ctx.source, C.adminAce) end
function S.membership(identifier, name)
    return MySQL.single.await('SELECT grade FROM rp_faction_members WHERE identifier = ? AND faction = ?', { identifier, name })
end
function S.canManage(ctx, kind, name)
    local member = kind == 'faction' and S.membership(ctx.identifier, name) or nil
    if not S.alive(ctx) then return false end
    return P.manage(S.admin(ctx), ctx.player.getJob(), kind, name, member)
end
function S.near(ctx, player)
    if S.admin(ctx) then return true end
    if GetPlayerRoutingBucket(ctx.source) ~= GetPlayerRoutingBucket(player.source) then return false end
    local a, b = GetPlayerPed(ctx.source), GetPlayerPed(player.source)
    return a ~= 0 and b ~= 0 and #(GetEntityCoords(a) - GetEntityCoords(b)) <= C.recruitDistance
end
function S.token(ctx, kind, name, identifier)
    local session = S.tokens[ctx.source]
    if not session or session.identifier ~= ctx.identifier then
        session = { identifier = ctx.identifier, entries = {} }
        S.tokens[ctx.source] = session
    end
    S.sequence = S.sequence + 1
    local token = tostring(S.sequence)
    session.entries[token] = { kind = kind, name = name, identifier = identifier, expires = GetGameTimer() + 120000 }
    return token
end
function S.resolve(ctx, input)
    local session = S.tokens[ctx.source]
    local member = session and session.identifier == ctx.identifier and session.entries[input.member]
    if not member or member.expires < GetGameTimer() or member.kind ~= input.kind or member.name ~= input.name then return nil end
    return member.identifier
end
function S.publicMember(ctx, kind, name, identifier, fullName, grade)
    local player = S.ESX.GetPlayerFromIdentifier(identifier)
    return { token = S.token(ctx, kind, name, identifier), name = fullName,
        grade = tonumber(grade), online = player ~= nil and player.spawned == true,
        self = identifier == ctx.identifier }
end
function S.audit(ctx, action, kind, name, target, detail)
    MySQL.insert('INSERT INTO rp_organization_audit (actor, action, kind, organization, target, detail) VALUES (?, ?, ?, ?, ?, ?)',
        { ctx.identifier, action, kind, name, target or '', detail or '' })
end
function S.account(name)
    local society = exports.esx_society:GetSociety(name)
    return society and exports.esx_addonaccount:GetSharedAccount(society.account) or nil
end
function S.registerSociety(name, job)
    if name == 'unemployed' or exports.esx_society:GetSociety(name) then return end
    local key = 'society_' .. name
    TriggerEvent('esx_society:registerSociety', name, job.label, key, key, key, { type = 'private' })
end
function S.savePlayer(player)
    -- 1.15.2 exposes saving through the console command; Core.SavePlayer is
    -- private. The resource receives only command.save permission in server.cfg.
    if P.integer(player.source, 1, 65535) then ExecuteCommand(('save %d'):format(player.source)) end
end
