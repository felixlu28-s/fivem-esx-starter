Banking = { Config = {
    interactionRadius = 1.5, serverRadius = 3.0, modelMatchRadius = 2.5,
    sessionSeconds = 300, cooldown = 1000, maxAmount = 1000000, maxBalance = 2000000000,
    historyLimit = 20, blips = true,
    -- Appearance only. These model hints never authorize access or move money.
    models = { prop_fleeca_atm = 'fleeca', prop_atm_01 = 'liberty', prop_atm_02 = 'liberty', prop_atm_03 = 'maze' },
    brands = { fleeca = 'Fleeca Bank', maze = 'Maze Bank', liberty = 'Bank of Liberty' },
    -- Optional, server-owned overrides for MLO/retextured machines; key = location ID.
    overrides = {},
} }
function Banking.distance(a, b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
function Banking.integer(n, low, high)
    return type(n) == 'number' and n == n and n % 1 == 0 and n >= low and n <= high
end
