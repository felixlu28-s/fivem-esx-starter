local ESX = exports.es_extended:getSharedObject()
local resourceName = GetCurrentResourceName()
local requestTimes = {}
local selectedCharacters = {}

local function getIdentifier(playerId)
    local player = ESX.GetPlayerFromId(playerId)
    return player and player.getIdentifier() or nil
end

local function validText(value, limits)
    return type(value) == 'string'
        and #value >= limits.min
        and #value <= limits.max
        and value:match('^[%a%s%-]+$') ~= nil
end

local function validDate(value)
    if type(value) ~= 'string' or not value:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return false
    end

    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    return year >= 1900 and year <= 2020 and month >= 1 and month <= 12 and day >= 1 and day <= 31
end

local function allowedRequest(playerId)
    local now = os.time()
    if requestTimes[playerId] and now - requestTimes[playerId] < Config.cooldownSeconds then
        return false
    end

    requestTimes[playerId] = now
    return true
end

local function publicCharacter(row)
    return {
        id = tonumber(row.id),
        firstname = row.firstname,
        lastname = row.lastname,
        dateofbirth = row.dateofbirth,
        gender = row.gender,
        height = tonumber(row.height),
    }
end

local function loadCharacters(playerId)
    local identifier = getIdentifier(playerId)
    if not identifier then return {} end

    local rows = MySQL.query.await([[
        SELECT id, firstname, lastname, dateofbirth, gender, height
        FROM rp_characters
        WHERE identifier = ?
        ORDER BY id ASC
        LIMIT ?
    ]], { identifier, Config.maxCharacters })

    local characters = {}
    for _, row in ipairs(rows or {}) do
        characters[#characters + 1] = publicCharacter(row)
    end
    return characters
end

lib.callback.register('rp_characters:list', function(source)
    if not allowedRequest(source) then return { ok = false, error = 'rate_limited' } end
    return { ok = true, characters = loadCharacters(source) }
end)

lib.callback.register('rp_characters:create', function(source, input)
    if not allowedRequest(source) or type(input) ~= 'table' then
        return { ok = false, error = 'invalid_request' }
    end

    local firstname, lastname = input.firstname, input.lastname
    local dateofbirth, gender, height = input.dateofbirth, input.gender, input.height
    if not validText(firstname, Config.fields.firstname)
        or not validText(lastname, Config.fields.lastname)
        or not validDate(dateofbirth)
        or type(gender) ~= 'string' or not Config.genders[gender]
        or type(height) ~= 'number' or height % 1 ~= 0
        or height < Config.fields.height.min or height > Config.fields.height.max then
        return { ok = false, error = 'invalid_fields' }
    end

    local identifier = getIdentifier(source)
    if not identifier then return { ok = false, error = 'player_unavailable' } end

    local count = MySQL.scalar.await('SELECT COUNT(*) FROM rp_characters WHERE identifier = ?', { identifier })
    if tonumber(count) >= Config.maxCharacters then
        return { ok = false, error = 'character_limit' }
    end

    local id = MySQL.insert.await([[
        INSERT INTO rp_characters (identifier, firstname, lastname, dateofbirth, gender, height)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], { identifier, firstname, lastname, dateofbirth, gender, height })
    if not id then return { ok = false, error = 'database_error' } end

    return { ok = true, characters = loadCharacters(source) }
end)

lib.callback.register('rp_characters:select', function(source, characterId)
    if not allowedRequest(source) or type(characterId) ~= 'number' or characterId % 1 ~= 0 or characterId < 1 then
        return { ok = false, error = 'invalid_request' }
    end

    local identifier = getIdentifier(source)
    if not identifier then return { ok = false, error = 'player_unavailable' } end

    local row = MySQL.single.await([[
        SELECT id, firstname, lastname, dateofbirth, gender, height
        FROM rp_characters WHERE id = ? AND identifier = ? LIMIT 1
    ]], { characterId, identifier })
    if not row then return { ok = false, error = 'not_found' } end

    selectedCharacters[source] = row.id
    return { ok = true, character = publicCharacter(row) }
end)

AddEventHandler('playerDropped', function()
    requestTimes[source] = nil
    selectedCharacters[source] = nil
end)

AddEventHandler('onResourceStop', function(stoppedResource)
    if stoppedResource ~= resourceName then return end
    requestTimes = {}
    selectedCharacters = {}
end)