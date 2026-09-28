Characters.Validation = {}
local V = Characters.Validation
function V.integer(value, min, max)
    return type(value) == 'number' and value % 1 == 0 and value >= min and value <= max
end
function V.name(value)
    if type(value) ~= 'string' or #value > 64 then return nil end
    value = value:gsub('^%s+', ''):gsub('%s+$', ''):gsub(' +', ' ')
    local length = utf8.len(value)
    if not length or length < 2 or length > 16 then return nil end
    local letters = 0
    for _, point in utf8.codes(value) do
        local letter = (point >= 65 and point <= 90) or (point >= 97 and point <= 122)
            or (point >= 192 and point <= 214) or (point >= 216 and point <= 246)
            or (point >= 248 and point <= 591)
        if not letter and point ~= 32 and point ~= 39 and point ~= 45 then return nil end
        if letter then letters = letters + 1 end
    end
    return letters >= 2 and value or nil
end
function V.birthdate(value, today)
    if type(value) ~= 'string' then return false end
    local y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or not m or not d or m < 1 or m > 12 then return false end
    local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
    local days = { 31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if d < 1 or d > days[m] then return false end
    local age = today.year - y
    if today.month < m or (today.month == m and today.day < d) then age = age - 1 end
    return age >= Characters.Config.minAge and age <= Characters.Config.maxAge
end
function V.position(value)
    if type(value) ~= 'table' then return nil end
    for _, key in ipairs({ 'x', 'y', 'z' }) do
        local n = value[key]
        if type(n) ~= 'number' or n ~= n or math.abs(n) > 20000 then return nil end
    end
    if value.z < -200 or value.z > 2000 then return nil end
    local heading = value.heading or value.w or 0
    if type(heading) ~= 'number' or heading ~= heading or math.abs(heading) == math.huge then return nil end
    return { x = value.x, y = value.y, z = value.z, heading = heading % 360 }
end
