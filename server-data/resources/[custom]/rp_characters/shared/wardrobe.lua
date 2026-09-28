-- Base-game freemode IDs stay stable across DLC updates. No job uniforms,
-- masks, armour or invisible body components in the arrival wardrobe.
local function choices(ids, label)
    local result = {}
    for index, id in ipairs(ids) do
        result[index] = { value = id, label = id == -1 and 'Ohne' or ('%s %02d'):format(label, index) }
    end
    return result
end
local function tops(rows)
    local result = {}
    for index, row in ipairs(rows) do
        result[index] = { value = row[1], label = row[2],
            skin = { arms = row[3], arms_2 = 0, tshirt_1 = row[4], tshirt_2 = 0 } }
    end
    return result
end
Characters.Wardrobe = {
    [0] = {
        torso_1 = tops({
            { 0, 'T-Shirt', 0, 15 }, { 1, 'Locker unterwegs', 0, 15 },
            { 3, 'Leichte Jacke', 1, 15 }, { 4, 'Smart Casual', 1, 15 },
            { 7, 'Blazer', 1, 15 }, { 8, 'Sportlich', 8, 15 },
            { 9, 'Freizeitjacke', 0, 15 }, { 11, 'Hemd', 11, 15 },
            { 12, 'Leichtes Hemd', 12, 15 }, { 13, 'Strick', 11, 15 },
            { 14, 'Urlaubslook', 4, 15 }, { 16, 'Reisejacke', 0, 15 },
        }),
        pants_1 = choices({ 0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 12, 14 }, 'Hose'),
        shoes_1 = choices({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13 }, 'Schuhe'),
        helmet_1 = choices({ -1, 2, 4, 5, 6, 7, 12, 13, 14, 15, 16, 17, 18 }, 'Kopfbedeckung'),
        glasses_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12 }, 'Brille'),
        ears_1 = choices({ -1, 0, 1, 2, 3, 4, 5 }, 'Ohrringe'),
        watches_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Uhr'),
        bracelets_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 6 }, 'Armband'),
        chain_1 = choices({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Halsaccessoire'),
    },
    [1] = {
        torso_1 = tops({
            { 0, 'T-Shirt', 0, 15 }, { 1, 'Leichte Jacke', 5, 15 },
            { 2, 'Ärmelloses Top', 2, 15 }, { 3, 'Freizeitlook', 3, 15 },
            { 4, 'Bluse', 4, 15 }, { 5, 'Casual', 4, 15 },
            { 6, 'Reisejacke', 5, 15 }, { 7, 'Hemd', 6, 15 },
            { 8, 'Leichtes Top', 4, 15 }, { 9, 'Smart Casual', 0, 15 },
            { 11, 'Sommerlook', 4, 15 }, { 14, 'Sportlich', 14, 15 },
        }),
        pants_1 = choices({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Unterteil'),
        shoes_1 = choices({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Schuhe'),
        helmet_1 = choices({ -1, 2, 4, 5, 6, 7, 9, 12, 13, 14, 15, 16, 17 }, 'Kopfbedeckung'),
        glasses_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Brille'),
        ears_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Ohrringe'),
        watches_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Uhr'),
        bracelets_1 = choices({ -1, 0, 1, 2, 3, 4, 5, 6 }, 'Armband'),
        chain_1 = choices({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }, 'Halsaccessoire'),
    },
}
