Inventory = {
    items = {}, baseSlots = 24, baseWeight = 25000,
    -- Installed ESX's stock items table uses kg; provider/native inventory uses grams.
    legacyWeightMultiplier = 1000,
    ammoTypes = { ammo_pistol = 'AMMO_PISTOL', ammo_rifle = 'AMMO_RIFLE' },
    ammoSync = { reportMs = 2000, auditMinMs = 20000, auditMaxMs = 35000,
        auditTimeoutMs = 10000, graceMs = 2500, requestMs = 500, logMs = 30000 },
    ground = { lifetime = 1800, sweep = 60000, radius = 1.35, stream = 40, limit = 1000, model = 'prop_cs_cardbox_01' },
    dropMotion = { dict = 'mp_common', clip = 'givetake1_a', releaseMs = 1420, duration = 2450,
        settleMs = 350, physicsMs = 8000, maxDrift = 3.0,
        -- PH_R_Hand is the prop grip, SKEL_R_Hand is the wrist-side skeleton anchor.
        -- Local metres / Euler degrees, independent of the saved landing transform.
        grip = { bone = 28422, fallbackBone = 57005, fallbackOffset = { x = 0.10, y = 0.02, z = 0.0 },
            default = { pos = { x = 0.02, y = 0.0, z = -0.015 }, rot = { x = 0.0, y = 0.0, z = 0.0 } },
            weapon = { pos = { x = 0.0, y = 0.0, z = 0.0 }, rot = { x = 0.0, y = 0.0, z = 0.0 } },
            models = {
                prop_sandwich_01 = { pos = { x = 0.025, y = 0.0, z = -0.01 }, rot = { x = 0.0, y = 0.0, z = 0.0 } },
                prop_ld_flow_bottle = { pos = { x = 0.02, y = 0.0, z = -0.07 }, rot = { x = 0.0, y = 0.0, z = 0.0 } },
                p_michael_backpack_s = { pos = { x = 0.04, y = 0.02, z = -0.16 }, rot = { x = 0.0, y = 0.0, z = 0.0 } },
            },
        },
    },
}
local function item(name, label, weight, stack, icon, extra)
    local value = extra or {}
    value.name, value.label, value.weight, value.maxStack, value.icon = name, label, weight, stack, icon
    value.stack, value.close, value.description = stack > 1, false, value.description or label
    local models = { water = 'prop_ld_flow_bottle', food = 'prop_sandwich_01', medical = 'prop_ld_health_pack',
        ammo = 'prop_box_ammo03a', bag = 'p_michael_backpack_s', fabric = 'prop_cs_rag_01', thread = 'prop_cs_cardbox_01', item = 'prop_cs_cardbox_01' }
    value.dropModel = value.dropModel or (value.weapon and name) or models[icon] or Inventory.ground.model
    Inventory.items[name] = value
end
item('rp_water', 'Mineralwasser', 500, 6, 'water', { use = 'drink', description = 'Eine Flasche Wasser für unterwegs.' })
item('rp_sandwich', 'Sandwich', 250, 8, 'food', { use = 'eat' })
item('phone', 'iFruit Handy', 180, 1, 'item', { dropModel = 'prop_npc_phone_02', description = 'Dein iFruit. Mit Pfeil nach oben herausholen.' })
item('rp_bandage', 'Verband', 100, 10, 'medical', { use = 'heal' })
item('rp_fabric', 'Stoff', 150, 20, 'fabric', { description = 'Sauberer Stoff für Verbände und Taschen.' })
item('rp_thread', 'Nähgarn', 50, 20, 'thread', { description = 'Reißfestes Garn für textile Arbeiten.' })
item('rp_plastic', 'Kunststoff', 100, 20, 'item', { description = 'Leichtes Material für Verschlüsse und Verstärkungen.' })
item('rp_backpack_small', 'Tagesrucksack', 1200, 1, 'bag', { slots = 8, capacity = 10000, use = 'backpack' })
item('rp_backpack_large', 'Reiserucksack', 2500, 1, 'bag', { slots = 16, capacity = 25000, use = 'backpack' })
-- Use each weapon family's standard magazine for the held and dropped prop.
item('ammo_pistol', 'Pistolenmunition', 12, 12, 'ammo', { legacyMaxStack = 60, dropModel = 'w_pi_pistol_mag1' })
item('ammo_rifle', 'Gewehrmunition', 20, 30, 'ammo', { legacyMaxStack = 90, dropModel = 'w_ar_carbinerifle_mag1' })
item('WEAPON_PISTOL', 'Pistole', 1000, 1, 'weapon', { weapon = true, ammo = 'ammo_pistol', magazine = 12, shotDelay = 140, use = 'weapon' })
item('WEAPON_CARBINERIFLE', 'Karabiner', 3500, 1, 'rifle', { weapon = true, ammo = 'ammo_rifle', magazine = 30, shotDelay = 85, use = 'weapon' })
local attachmentDescription='Benutzen: passende Waffe automatisch hervorholen und montieren. Bei mehreren Kopien zuerst die gewünschte Waffe benutzen. Rechtsklick auf die Waffe zum Abnehmen.'
item('rp_pistol_light', 'Pistolenlampe', 100, 5, 'item', { use = 'component', weaponName = 'WEAPON_PISTOL', component = 'COMPONENT_AT_PI_FLSH', description = attachmentDescription })
item('rp_pistol_suppressor', 'Pistolen-Schalldämpfer', 200, 5, 'item', { use = 'component', weaponName = 'WEAPON_PISTOL', component = 'COMPONENT_AT_PI_SUPP_02', description = attachmentDescription })
item('rp_rifle_light', 'Gewehrlampe', 150, 5, 'item', { use = 'component', weaponName = 'WEAPON_CARBINERIFLE', component = 'COMPONENT_AT_AR_FLSH', description = attachmentDescription })
item('rp_rifle_scope', 'Karabiner-Zielfernrohr', 350, 5, 'item', { use = 'component', weaponName = 'WEAPON_CARBINERIFLE', component = 'COMPONENT_AT_SCOPE_MEDIUM', description = attachmentDescription })
