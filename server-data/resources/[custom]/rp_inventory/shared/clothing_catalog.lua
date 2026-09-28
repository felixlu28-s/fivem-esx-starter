-- Base-game freemode garments. The server owns products, prices and skin patches.
-- Also loaded by rp_commerce; no inventory internals are exported to the browser.
Clothing = { categories = {}, products = {}, order = {
    'top', 'undershirt', 'pants', 'shoes', 'hat', 'glasses', 'ears', 'chain', 'watch', 'bracelet', 'mask', 'bag'
} }
local C = Clothing
function C.describe(categoryId, sex, skin)
    local cat = C.categories[categoryId]
    if not cat or type(skin) ~= 'table' then return nil end
    local drawable, texture = skin[cat.prefix .. '_1'], skin[cat.prefix .. '_2'] or 0
    if type(drawable) ~= 'number' or type(texture) ~= 'number' or drawable % 1 ~= 0 or texture % 1 ~= 0 then return nil end
    local key = ('clothing/%d/%s/%d_%d'):format(sex, categoryId, drawable, texture)
    return ClothingArtwork and ClothingArtwork[key]
end
C.animations = {
    default = { dict = 'clothingtie', clip = 'try_tie_positive_a', duration = 2100 },
    glasses = { dict = 'clothingspecs', clip = 'take_off', duration = 1400 },
    hat = { dict = 'mp_masks@standard_car@ds@', clip = 'put_on_mask', duration = 800 },
    ears = { dict = 'mp_masks@standard_car@ds@', clip = 'put_on_mask', duration = 800 },
    mask = { dict = 'mp_masks@standard_car@ds@', clip = 'put_on_mask', duration = 800 },
    watch = { dict = 'missmic4', clip = 'michael_tux_fidget', duration = 1500 },
    bracelet = { dict = 'missmic4', clip = 'michael_tux_fidget', duration = 1500 },
    pants = { dict = 're@construction', clip = 'out_of_breath', duration = 1800 },
    shoes = { dict = 're@construction', clip = 'out_of_breath', duration = 1800 },
}
local function category(id, label, prefix, weight, emptyMale, emptyFemale, view)
    C.categories[id] = { id = id, label = label, prefix = prefix, weight = weight,
        empty = { [0] = emptyMale, [1] = emptyFemale }, view = view }
end
category('top', 'Oberteile', 'torso', 500, 15, 15, 'upper')
category('undershirt', 'Unterziehshirts', 'tshirt', 180, 15, 15, 'upper')
category('pants', 'Hosen', 'pants', 450, 61, 15, 'lower')
category('shoes', 'Schuhe', 'shoes', 600, 34, 35, 'shoes')
category('hat', 'Kopfbedeckungen', 'helmet', 120, -1, -1, 'face')
category('glasses', 'Brillen', 'glasses', 40, -1, -1, 'face')
category('ears', 'Ohrringe', 'ears', 10, -1, -1, 'face')
category('chain', 'Ketten', 'chain', 60, 0, 0, 'upper')
category('watch', 'Uhren', 'watches', 80, -1, -1, 'upper')
category('bracelet', 'Armbänder', 'bracelets', 30, -1, -1, 'upper')
category('mask', 'Masken', 'mask', 90, 0, 0, 'face')
category('bag', 'Taschen · Accessoires', 'bags', 200, 0, 0, 'upper')
local function product(sex, categoryId, drawable, label, price, arms, tshirt)
    local cat = C.categories[categoryId]
    local id = ('%s_%d_%d'):format(categoryId, sex, drawable)
    local skin = { [cat.prefix .. '_1'] = drawable, [cat.prefix .. '_2'] = 0 }
    if categoryId == 'top' then skin.arms, skin.arms_2, skin.tshirt_1, skin.tshirt_2 = arms or 0, 0, tshirt or 15, 0 end
    local picture = categoryId
    if categoryId == 'top' then
        if label:find('jacke') or label:find('Jacke') then picture = 'jacket'
        elseif label:find('Blazer') then picture = 'blazer'
        elseif label:find('hemd') or label:find('Hemd') or label:find('Bluse') then picture = 'shirt'
        elseif label:find('Strick') then picture = 'sweater' end
    end
    local original = C.describe(categoryId, sex, skin)
    C.products[id] = { id = id, category = categoryId, sex = sex, label = original and original.label or label, price = price, skin = skin,
        artwork = original and original.artwork, gxt = original and original.gxt,
        hidden = ClothingArtwork ~= nil and original ~= nil and original.artwork == nil,
        image = picture, color = ({ '#b5b9b4', '#333e49', '#b6a78c', '#748b7c' })[drawable % 4 + 1] }
end
local tops = {
    [0] = { {0,'Klassisches T-Shirt',0}, {1,'Lockeres Shirt',0}, {3,'Leichte Jacke',1}, {4,'Smart Casual',1},
        {7,'City-Blazer',1}, {8,'Sportoberteil',8}, {9,'Freizeitjacke',0}, {11,'Freizeithemd',11},
        {12,'Leichtes Hemd',12}, {13,'Strickoberteil',11}, {14,'Urlaubsshirt',4}, {16,'Reisejacke',0} },
    [1] = { {0,'Klassisches T-Shirt',0}, {1,'Leichte Jacke',5}, {2,'Ärmelloses Top',2}, {3,'Freizeitoberteil',3},
        {4,'City-Bluse',4}, {5,'Casual-Oberteil',4}, {6,'Reisejacke',5}, {7,'Freizeithemd',6},
        {8,'Leichtes Top',4}, {9,'Smart Casual',0}, {11,'Sommeroberteil',4}, {14,'Sportoberteil',14} }
}
for sex = 0, 1 do
    for _, top in ipairs(tops[sex]) do product(sex, 'top', top[1], top[2], 90 + top[1] * 12, top[3]) end
    local pants = sex == 0 and {0,1,2,3,4,5,7,8,9,10,12,14} or {0,1,2,3,4,5,6,7,8,9,10,11}
    local shoes = sex == 0 and {1,2,3,4,5,6,7,8,9,10,12,13} or {0,1,2,3,4,5,6,7,8,9,10,11}
    for i, drawable in ipairs(pants) do product(sex, 'pants', drawable, ('City-Hose %02d'):format(i), 85 + i * 9) end
    for i, drawable in ipairs(shoes) do product(sex, 'shoes', drawable, ('Schuhe %02d'):format(i), 70 + i * 12) end
    for _, id in ipairs({'hat', 'glasses', 'ears', 'chain', 'watch', 'bracelet', 'mask', 'bag', 'undershirt'}) do
        local maximum = ({hat=7,glasses=11,ears=5,chain=8,watch=2,bracelet=2,mask=4,bag=4,undershirt=5})[id]
        for i = 1, maximum do
            local drawable = (id == 'hat' or id == 'glasses' or id == 'ears' or id == 'watch' or id == 'bracelet') and i - 1 or i
            product(sex, id, drawable, ('%s %02d'):format(C.categories[id].label, i), 45 + i * 15)
        end
    end
end
function C.base(sex)
    local result = { arms = 15, arms_2 = 0 }
    for _, cat in pairs(C.categories) do result[cat.prefix .. '_1'], result[cat.prefix .. '_2'] = cat.empty[sex], 0 end
    return result
end
function C.patch(categoryId, skin)
    local cat = C.categories[categoryId]
    if not cat or type(skin) ~= 'table' then return nil end
    local keys = {cat.prefix .. '_1', cat.prefix .. '_2'}
    if categoryId == 'top' then keys = {'torso_1','torso_2','arms','arms_2','tshirt_1','tshirt_2'} end
    local result = {}
    for _, key in ipairs(keys) do
        local value = skin[key] or 0
        if type(value) ~= 'number' or value % 1 ~= 0 or value < -1 or value > 1000 then return nil end
        result[key] = math.tointeger(value)
    end
    return result
end
