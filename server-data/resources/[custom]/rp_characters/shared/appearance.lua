local fields, byKey = {}, {}
local function field(key, label, group, min, max, value, extra)
    local item = { key = key, label = label, group = group, min = min, max = max, default = value }
    for k, v in pairs(extra or {}) do item[k] = v end
    fields[#fields + 1], byKey[key] = item, item
end

field('sex', 'Körpermodell', 'heritage', 0, 1, 0)
field('mom', 'Mutter', 'heritage', 0, 45, 21)
field('dad', 'Vater', 'heritage', 0, 44, 0)
field('grandparents', 'Großeltern', 'heritage', 0, 45, 0)
field('face_md_weight', 'Gesichtsähnlichkeit', 'heritage', 0, 100, 50)
field('skin_md_weight', 'Hautton-Mischung', 'heritage', 0, 100, 50)
field('face_g_weight', 'Einfluss der Großeltern', 'heritage', 0, 100, 0)
for _, item in ipairs({
    { 'nose_1', 'Nasenbreite' }, { 'nose_2', 'Nasenhöhe' }, { 'nose_3', 'Nasenlänge' },
    { 'nose_4', 'Nasenrücken' }, { 'nose_5', 'Nasenspitze' }, { 'nose_6', 'Nasenkrümmung' },
    { 'eyebrows_5', 'Brauenhöhe' }, { 'eyebrows_6', 'Brauentiefe' },
    { 'cheeks_1', 'Wangenknochenhöhe' }, { 'cheeks_2', 'Wangenknochenbreite' },
    { 'cheeks_3', 'Wangenfülle' }, { 'eye_squint', 'Augenöffnung' },
    { 'lip_thickness', 'Lippenfülle' }, { 'jaw_1', 'Kieferbreite' }, { 'jaw_2', 'Kieferform' },
    { 'chin_1', 'Kinnhöhe' }, { 'chin_2', 'Kinntiefe' }, { 'chin_3', 'Kinnbreite' },
    { 'chin_4', 'Kinnform' }, { 'neck_thickness', 'Halsbreite' },
}) do field(item[1], item[2], 'face', -10, 10, 0) end
field('eye_color', 'Augenfarbe', 'face', 0, 31, 0)

for _, item in ipairs({
    { 'hair', 'Frisur', 2, 'hair' }, { 'tshirt', 'T-Shirt', 8, 'clothes' },
    { 'torso', 'Oberteil', 11, 'clothes' }, { 'decals', 'Aufdruck', 10, 'clothes' },
    { 'pants', 'Hose', 4, 'clothes' }, { 'shoes', 'Schuhe', 6, 'clothes' },
    { 'mask', 'Maske', 1, 'accessories' }, { 'bproof', 'Weste', 9, 'accessories' },
    { 'chain', 'Kette', 7, 'accessories' }, { 'bags', 'Tasche', 5, 'accessories' },
}) do
    field(item[1] .. '_1', item[2], item[4], 0, 1000, 0, { component = item[3], texture = item[1] .. '_2' })
    field(item[1] .. '_2', item[2] .. ' · Variante', item[4], 0, 100, 0, { component = item[3], drawable = item[1] .. '_1' })
end
field('arms', 'Arme / Handschuhe', 'clothes', 0, 1000, 0, { component = 3, texture = 'arms_2' })
field('arms_2', 'Arme · Variante', 'clothes', 0, 100, 0, { component = 3, drawable = 'arms' })
field('hair_color_1', 'Haarfarbe', 'hair', 0, 63, 0, { color = true })
field('hair_color_2', 'Strähnen', 'hair', 0, 63, 0, { color = true })
for _, item in ipairs({
    { 'helmet', 'Kopfbedeckung', 0 }, { 'glasses', 'Brille', 1 }, { 'ears', 'Ohrringe', 2 },
    { 'watches', 'Uhr', 6 }, { 'bracelets', 'Armband', 7 },
}) do
    field(item[1] .. '_1', item[2], 'accessories', -1, 500, -1, { prop = item[3], texture = item[1] .. '_2' })
    field(item[1] .. '_2', item[2] .. ' · Variante', 'accessories', 0, 100, 0, { prop = item[3], drawable = item[1] .. '_1' })
end
for _, item in ipairs({
    { 'blemishes', 'Hautunreinheiten', 0, 23, 'skin' }, { 'beard', 'Bart', 1, 28, 'hair', true },
    { 'eyebrows', 'Augenbrauen', 2, 33, 'hair', true }, { 'age', 'Alterung', 3, 14, 'skin' },
    { 'makeup', 'Make-up', 4, 74, 'skin', true }, { 'blush', 'Rouge', 5, 6, 'skin', true },
    { 'complexion', 'Teint', 6, 11, 'skin' }, { 'sun', 'Sonnenschäden', 7, 10, 'skin' },
    { 'lipstick', 'Lippenstift', 8, 9, 'skin', true }, { 'moles', 'Sommersprossen', 9, 17, 'skin' },
    { 'chest', 'Brustbehaarung', 10, 16, 'skin', true },
}) do
    field(item[1] .. '_1', item[2], item[5], 0, item[4], 0, { overlay = item[3] })
    field(item[1] .. '_2', item[2] .. ' · Stärke', item[5], 0, 10, item[1] == 'eyebrows' and 10 or 0)
    if item[6] then
        field(item[1] .. '_3', item[2] .. ' · Farbe', item[5], 0, 63, 0, { color = true })
        if item[1] ~= 'blush' and item[1] ~= 'chest' then
            field(item[1] .. '_4', item[2] .. ' · Zweitfarbe', item[5], 0, 63, 0, { color = true })
        end
    end
end
field('bodyb_1', 'Körpermerkmale', 'skin', -1, 11, -1)
field('bodyb_2', 'Körpermerkmale · Stärke', 'skin', 0, 10, 0)
field('bodyb_3', 'Weitere Körpermerkmale', 'skin', -1, 1, -1)
field('bodyb_4', 'Weitere Körpermerkmale · Stärke', 'skin', 0, 10, 0)

local W = Characters.Wardrobe
local hidden = { tshirt_1 = true, tshirt_2 = true, arms = true, arms_2 = true,
    decals_1 = true, decals_2 = true, mask_1 = true, mask_2 = true,
    bproof_1 = true, bproof_2 = true, bags_1 = true, bags_2 = true }
local sections = {
    heritage = 'Eltern & Ähnlichkeit', face = 'Gesichtsform', hair = 'Frisur & Farbe',
    skin = 'Hautbild', clothes = 'Oberteile', accessories = 'Accessoires',
}
for _, item in ipairs(fields) do
    local prefix = item.key:match('^([^_]+)')
    item.hidden = hidden[item.key] or false
    item.section = sections[item.group]
    if prefix == 'nose' then item.section = 'Nase'
    elseif prefix == 'cheeks' then item.section = 'Wangen'
    elseif prefix == 'jaw' or prefix == 'chin' or prefix == 'neck' then item.section = 'Kiefer & Kinn'
    elseif prefix == 'eye' or item.key == 'eyebrows_5' or item.key == 'eyebrows_6' then item.section = 'Augen & Brauen'
    elseif prefix == 'beard' then item.section, item.sex = 'Bart', 0
    elseif prefix == 'eyebrows' then item.section = 'Augenbrauen'
    elseif prefix == 'chest' then item.section, item.sex = 'Körperbehaarung', 0
    elseif prefix == 'makeup' or prefix == 'blush' or prefix == 'lipstick' then item.section = 'Make-up'
    elseif prefix == 'bodyb' then item.section = 'Körpermerkmale'
    elseif prefix == 'pants' then item.section = 'Hosen & Unterteile'
    elseif prefix == 'shoes' then item.section = 'Schuhe'
    elseif prefix == 'helmet' then item.section = 'Kopfbedeckungen'
    elseif prefix == 'glasses' then item.section = 'Brillen'
    elseif prefix == 'ears' or prefix == 'chain' then item.section = 'Schmuck'
    elseif prefix == 'watches' or prefix == 'bracelets' then item.section = 'Uhren & Armbänder' end
    if item.key == 'grandparents' or item.key == 'face_g_weight' then item.section = 'Weitere Vererbung' end
end
local function parentOptions(names, first, extras)
    local result = {}
    for index, name in ipairs(names) do result[#result + 1] = { value = first + index - 1, label = name } end
    for _, option in ipairs(extras or {}) do result[#result + 1] = option end
    return result
end
byKey.mom.options = parentOptions({ 'Hannah', 'Audrey', 'Jasmine', 'Giselle', 'Amelia', 'Isabella',
    'Zoe', 'Ava', 'Camila', 'Violet', 'Sophia', 'Eveline', 'Nicole', 'Ashley', 'Grace', 'Brianna',
    'Natalie', 'Olivia', 'Elizabeth', 'Charlotte', 'Emma' }, 21, { { value = 45, label = 'Misty' } })
byKey.dad.options = parentOptions({ 'Benjamin', 'Daniel', 'Joshua', 'Noah', 'Andrew', 'Joan', 'Alex',
    'Isaac', 'Evan', 'Ethan', 'Vincent', 'Angel', 'Diego', 'Adrian', 'Gabriel', 'Michael', 'Santiago',
    'Kevin', 'Louis', 'Samuel', 'Anthony' }, 0, {
    { value = 42, label = 'John' }, { value = 43, label = 'Niko' }, { value = 44, label = 'Claude' } })

Characters.Appearance = { fields = fields, byKey = byKey }
local A = Characters.Appearance
function A.options(item, sex) return W[sex][item.key] or item.options end
function A.visible(item, sex) return not item.hidden and (item.sex == nil or item.sex == sex) end
function A.option(item, sex, value)
    for _, option in ipairs(A.options(item, sex) or {}) do
        if option.value == value then return option end
    end
end
function Characters.Appearance.defaults(sex)
    local skin = {}
    for _, item in ipairs(fields) do skin[item.key] = item.default end
    skin.sex = sex == 1 and 1 or 0
    for key, options in pairs(W[skin.sex]) do skin[key] = options[1].value end
    for key, value in pairs(W[skin.sex].torso_1[1].skin) do skin[key] = value end
    skin.hair_1 = skin.sex == 1 and 4 or 0
    return skin
end

-- Only creation is limited to the arrival wardrobe. Existing saved characters
-- may own different clothes and continue loading through validate().
function A.validateCreation(input)
    local skin = A.validate(input)
    if not skin then return nil end
    for _, item in ipairs(fields) do
        local options = A.options(item, skin.sex)
        if options and not A.option(item, skin.sex, skin[item.key]) then return nil end
        if item.sex ~= nil and item.sex ~= skin.sex and skin[item.key] ~= item.default then return nil end
        if item.drawable and item.group ~= 'hair' and skin[item.key] > 11 then return nil end
    end
    local top = A.option(byKey.torso_1, skin.sex, skin.torso_1)
    for key, value in pairs(top.skin) do if skin[key] ~= value then return nil end end
    for key in pairs(hidden) do
        if top.skin[key] == nil and skin[key] ~= byKey[key].default then return nil end
    end
    return skin
end

-- Server-owned bounds: arbitrary model names and unknown skin keys are rejected.
function Characters.Appearance.validate(input)
    if type(input) ~= 'table' then return nil end
    local skin = Characters.Appearance.defaults(input.sex)
    for key, value in pairs(input) do
        local rule = byKey[key]
        if not rule or type(value) ~= 'number' or value % 1 ~= 0 or value < rule.min or value > rule.max then return nil end
        skin[key] = value
    end
    return skin
end
