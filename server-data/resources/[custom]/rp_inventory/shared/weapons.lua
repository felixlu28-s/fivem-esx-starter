-- ESX custom-inventory definitions. Names/artwork come from the generated GTA
-- catalogue; weights, stack limits and prepaid batch sizes are server policy.
local I = Inventory
local families = {
    AMMO_PISTOL = {'ammo_pistol', 'Pistolenmunition', 12, 12, 'w_pi_pistol_mag1'},
    AMMO_RIFLE = {'ammo_rifle', 'Gewehrmunition', 20, 30, 'w_ar_carbinerifle_mag1'},
    AMMO_SMG = {'ammo_smg', 'MP-Munition', 12, 30, 'w_sb_smg_mag1'},
    AMMO_MG = {'ammo_mg', 'MG-Munition', 25, 100, 'w_mg_combatmg_mag1'},
    AMMO_SHOTGUN = {'ammo_shotgun', 'Schrotpatronen', 35, 8, 'prop_box_ammo03a'},
    AMMO_SNIPER = {'ammo_sniper', 'Scharfschützenmunition', 35, 10, 'w_sr_sniperrifle_mag1'},
    AMMO_MINIGUN = {'ammo_minigun', 'Minigun-Munition', 25, 100, 'prop_box_ammo03a'},
    AMMO_GRENADELAUNCHER = {'ammo_grenade', 'Granatwerfermunition', 250, 10, 'prop_box_ammo03a'},
    AMMO_GRENADELAUNCHER_SMOKE = {'ammo_grenade_smoke', 'Rauchgranatwerfermunition', 250, 10, 'prop_box_ammo03a'},
    AMMO_RPG = {'ammo_rocket', 'RPG-Rakete', 1200, 1, 'w_lr_rpg_rocket'},
    AMMO_HOMINGLAUNCHER = {'ammo_homing', 'Lenkrakete', 1500, 1, 'w_lr_homing_rocket'},
    AMMO_FIREWORK = {'ammo_firework', 'Feuerwerksrakete', 500, 1, 'prop_box_ammo03a'},
    AMMO_RAILGUN = {'ammo_railgun', 'Railgun-Munition', 150, 1, 'prop_box_ammo03a'},
    AMMO_RAILGUNXM3 = {'ammo_railgunxm3', 'Railgun-XM3-Munition', 150, 1, 'prop_box_ammo03a'},
    AMMO_EMPLAUNCHER = {'ammo_emp', 'EMP-Granate', 250, 1, 'prop_box_ammo03a'},
    AMMO_FLAREGUN = {'ammo_flaregun', 'Leuchtpistolenmunition', 80, 1, 'prop_box_ammo03a'},
    AMMO_SNOWLAUNCHER = {'ammo_snowlauncher', 'Schneeballwerfermunition', 100, 1, 'w_ex_snowball'},
}
for native, row in pairs(families) do
    local name, label, weight, stack, model = table.unpack(row)
    I.ammoTypes[name] = native
    I.items[name] = I.items[name] or { name=name, label=label, weight=weight, maxStack=stack,
        stack=stack>1, close=false, icon='ammo', description=label, dropModel=model }
end
local clips = {
    APPISTOL=18, PISTOL50=9, SNSPISTOL=6, SNSPISTOL_MK2=6, HEAVYPISTOL=18, VINTAGEPISTOL=7,
    CERAMICPISTOL=12, PISTOLXM3=12, GADGETPISTOL=1, MARKSMANPISTOL=1, REVOLVER=6, REVOLVER_MK2=6,
    DOUBLEACTION=6, NAVYREVOLVER=6, MICROSMG=16, MINISMG=20, MACHINEPISTOL=12, SMG_MK2=20,
    TECPISTOL=33, MG=54, COMBATMG=100, COMBATMG_MK2=100, GUSENBERG=30,
    ASSAULTSHOTGUN=8, PUMPSHOTGUN=8, PUMPSHOTGUN_MK2=8, SAWNOFFSHOTGUN=8, BULLPUPSHOTGUN=14,
    HEAVYSHOTGUN=6, DBSHOTGUN=2, AUTOSHOTGUN=10, COMBATSHOTGUN=6, MUSKET=1,
    HEAVYSNIPER=6, HEAVYSNIPER_MK2=6, MARKSMANRIFLE=8, MARKSMANRIFLE_MK2=8,
    GRENADELAUNCHER=10, GRENADELAUNCHER_SMOKE=10, COMPACTLAUNCHER=1, BATTLERIFLE=20,
}
local weights = { GROUP_MELEE=700, GROUP_UNARMED=350, GROUP_PISTOL=1000, GROUP_STUNGUN=500,
    GROUP_SMG=2500, GROUP_RIFLE=3500, GROUP_MG=7000, GROUP_SHOTGUN=3500, GROUP_SNIPER=5500,
    GROUP_HEAVY=8000, GROUP_THROWN=500, GROUP_PETROLCAN=5000 }
for name, original in pairs(WeaponCatalog) do
    local existing = I.items[name]
    local def = existing or { name=name, weapon=true, use='weapon', maxStack=1, stack=false, close=false,
        weight=weights[original.category] or 500, icon=original.category=='GROUP_PISTOL' and 'weapon' or 'rifle', dropModel=name }
    def.label, def.description, def.artwork, def.weaponCategory = original.label, original.label, original.artwork, original.category
    def.projectile = original.category=='GROUP_THROWN' or name=='WEAPON_FLAREGUN'
        or (original.category=='GROUP_HEAVY' and original.nativeAmmo~='AMMO_MINIGUN')
    local family = families[original.nativeAmmo]
    if family then
        def.ammo = family[1]
        def.magazine = clips[name:sub(8)] or (original.category=='GROUP_HEAVY' and 1 or family[4])
        if original.nativeAmmo=='AMMO_MINIGUN' then def.magazine,def.shotDelay=100,10 end
        def.shotDelay = def.shotDelay or 30 -- permissive lower bound, not a rate-of-fire override
        def.damageFactor = original.category=='GROUP_SHOTGUN' and 16 or def.projectile and 64 or 1
    elseif original.category=='GROUP_THROWN' or original.category=='GROUP_PETROLCAN' or original.nativeAmmo=='AMMO_FIREEXTINGUISHER' then
        -- The thrown object / filled can IS the consumable. Never create a free
        -- reusable grenade launcher item plus separate "grenade ammunition".
        def.ammo, def.consumable, def.ammoUnits = name, true, original.category=='GROUP_THROWN' and 1 or 4500
        def.magazine, def.shotDelay, def.damageFactor = def.ammoUnits, 0, 64
        I.ammoTypes[name] = original.nativeAmmo
    elseif original.nativeAmmo=='NULL' then
        def.ammoFree = true -- melee / equipment; ownership is still checked
    else
        assert(original.nativeAmmo=='AMMO_STUNGUN' or original.nativeAmmo=='AMMO_RAYPISTOL', 'Unmapped ammunition: '..name)
        def.ammoFree, def.rechargeable = true, true
    end
    I.items[name] = def
end
