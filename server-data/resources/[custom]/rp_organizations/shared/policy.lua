local P = {}
Organizations.Policy = P
function P.integer(value, min, max)
    return type(value) == 'number' and value % 1 == 0 and value >= min and value <= max
end
function P.code(value)
    return type(value) == 'string' and #value >= 2 and #value <= 32 and value:match('^[a-z][a-z0-9_]+$') ~= nil
end
function P.label(value)
    if type(value) ~= 'string' or #value > 160 or value:find('[%c<>]') then return nil end
    value = value:match('^%s*(.-)%s*$')
    local size = utf8.len(value)
    return size and size >= 2 and size <= 40 and value or nil
end
function P.character(identifier)
    return type(identifier) == 'string' and #identifier <= 60 and identifier:match('^char%d+:[%w%-]+$') ~= nil
end
function P.manage(admin, ownJob, kind, name, membership)
    if admin then return true end
    if kind == 'job' then return ownJob.name == name and ownJob.grade_name == 'boss' end
    return membership ~= nil and membership.grade == 2
end
function P.memberChange(admin, actorGrade, targetGrade, nextGrade, selfTarget)
    if admin then return true end
    return not selfTarget and targetGrade < actorGrade and (nextGrade == nil or nextGrade < actorGrade)
end
