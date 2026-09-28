-- Display-only GTA localization. Item identity/prices/metadata remain server-owned.
local labels = {}
local function item(row)
    if type(row) ~= 'table' then return end
    local key = row.gxt or (row.clothing and row.clothing.gxt)
    if type(key) == 'string' and #key <= 80 and GetCurrentLanguage() == 2 then
        if labels[key] == nil then
            local value = GetLabelText(key)
            labels[key] = value and value ~= 'NULL' and value ~= '' and value or false
        end
        if labels[key] then
            row.label = labels[key]
            if row.clothing then row.clothing.label = row.label end
        end
    end
end
function Inventory.localizeCatalog(payload)
    if type(payload) ~= 'table' then return payload end
    local inventory = payload.inventory or payload
    for _, side in ipairs({'own', 'external'}) do
        local store = inventory[side]
        if type(store) == 'table' then
            for _, row in ipairs(store.items or {}) do item(row) end
            item(store.backpack)
        end
    end
    local commerce = payload.commerce or payload
    for _, row in ipairs(commerce.offers or {}) do item(row) end
    for _, row in ipairs(commerce.currentClothing or {}) do item(row) end
    return payload
end
exports('rpLocalizeCatalog', Inventory.localizeCatalog)
