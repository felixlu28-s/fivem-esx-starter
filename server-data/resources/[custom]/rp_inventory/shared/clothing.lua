local M, C = Inventory.model, Clothing
-- Freemode drawables are not standalone objects. Use a fitting base-game prop
-- per category; small accessories without a suitable object use a small bag.
local dropFallback = 'prop_paper_bag_small'
local dropModels = {
    top = 'prop_ld_shirt_01', undershirt = 'prop_ld_tshirt_01',
    pants = 'prop_ld_jeans_01', shoes = 'prop_ld_shoe_01',
    hat = 'prop_ld_hat_01', glasses = 'prop_aviators_01',
    ears = 'p_tmom_earrings_s', watch = 'p_watch_01',
    mask = 'prop_cs_bandana', bag = 'prop_cs_duffel_01',
}
for id, cat in pairs(C.categories) do
    local name = 'clothing_' .. id
    Inventory.items[name] = { name = name, label = cat.label, description = 'Kleidungsstück · im Inventar an- und ausziehen',
        weight = cat.weight, maxStack = 1, stack = false, icon = 'clothes', use = 'clothing', clothing = id,
        dropModel = dropModels[id] or dropFallback, dropFallback = dropFallback }
end
function M.garment(entry)
    local def = entry and Inventory.items[entry.name]
    local garment = entry and entry.metadata and entry.metadata.garment
    if not def or not def.clothing or type(garment) ~= 'table' or (garment.sex ~= 0 and garment.sex ~= 1)
        or type(garment.id) ~= 'string' or #garment.id > 80 or #garment.id < 1
        or type(garment.label) ~= 'string' or #garment.label > 120 or not C.patch(def.clothing, garment.skin) then return nil end
    return garment, def.clothing
end
function M.clothingNormalize(data)
    if not data.clothing then return true end
    local worn, present = data.clothing.worn, {}
    if type(worn) ~= 'table' or (data.clothing.sex ~= 0 and data.clothing.sex ~= 1) then return false end
    for _, entry in pairs(data.items) do
        local garment, category = M.garment(entry)
        if garment then
            if present[garment.id] then return false end
            present[garment.id] = { category = category, sex = garment.sex }
        end
    end
    for category, id in pairs(worn) do
        local found = present[id]
        if not found or found.category ~= category or found.sex ~= data.clothing.sex then worn[category] = nil end
    end
    return true
end
function M.clothingSkin(data)
    if not data.clothing then return nil end
    local result, garments = C.base(data.clothing.sex), {}
    for _, entry in pairs(data.items) do
        local garment, category = M.garment(entry)
        if garment and data.clothing.worn[category] == garment.id then garments[category] = garment end
    end
    -- Top bundle first; a separately worn undershirt overrides that bundle.
    for _, category in ipairs(C.order) do
        local garment = garments[category]
        if garment then for k, v in pairs(C.patch(category, garment.skin)) do result[k] = v end end
    end
    return result
end
function M.clothingUse(data, slot)
    local garment, category = M.garment(data.items[tostring(slot)])
    if not data.clothing then return false, 'clothing_not_ready' end
    if not garment then return false, 'invalid_garment' end
    if garment.sex ~= data.clothing.sex then return false, 'clothing_wrong_model' end
    data.clothing.worn[category] = data.clothing.worn[category] ~= garment.id and garment.id or nil
    return true
end
function M.clothingDisplay(data, entry)
    local garment, category = M.garment(entry)
    if not garment then return nil end
    local product = C.products[garment.product]
    local original = C.describe(category, garment.sex, garment.skin)
    return { category = category, label = original and original.label or garment.label, image = product and product.image or category, sex = garment.sex,
        artwork = original and original.artwork, gxt = original and original.gxt,
        color = product and product.color or '#8b9c91', worn = data.clothing ~= nil and data.clothing.worn[category] == garment.id }
end
