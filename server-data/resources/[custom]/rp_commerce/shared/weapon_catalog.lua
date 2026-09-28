-- Read-only definitions from the sole inventory provider. Adding a catalogue
-- entry makes it available to the editor; it does not add a shop/display.
local W = Commerce.Weapons
local existing = {}
for key, def in pairs(W.catalog) do existing[def.item] = key end
for name, def in pairs(Inventory.items) do
    if not existing[name] and Inventory.ammoTypes[name] and not def.weapon then
        W.catalog[name] = { label=def.label, item=name, packSize=def.maxStack,
            price=math.max(10,def.weight*def.maxStack), model=def.dropModel }
        existing[name] = name
    end
end
for name, def in pairs(Inventory.items) do
    if def.weapon then
        local key = existing[name] or name:lower()
        W.catalog[key] = W.catalog[key] or { label=def.label, item=name, weapon=true,
            price=math.max(100,def.weight*4), components={},
            presentation=(def.ammoFree or def.consumable) and 'object' or 'firearm',
            ammo=not def.consumable and existing[def.ammo] or nil }
        W.catalog[key].label = def.label
        -- Never stand a knife/grenade up like a firearm.
        if def.ammoFree or def.consumable then W.catalog[key].presentation='object' end
    end
end
