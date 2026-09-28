Commerce = {}
Commerce.Config = {
    maxBuy = 20, maxCraft = 5, radius = 1.25,
    -- Official esx_shops 2.0 Config.Zones shape, extended by Label/Subtitle/Jobs/Bucket.
    -- Existing zones can be copied here; item names must exist in the ESX catalog.
    esxZones = {
        strawberry = {
            Label = '24/7 · Strawberry', Subtitle = 'Alles für deinen nächsten Schritt.',
            Pos = { { x = 25.7, y = -1347.3, z = 29.5 } },
            Type = 52, Color = 2, ShowBlip = true, ShowMarker = true, BlipLabel = '24/7 · Testshop',
            -- Optional: Jobs = { police = 0 }, Bucket = 0.
            Categories = { { id = 'food', label = 'Verpflegung' }, { id = 'gear', label = 'Ausrüstung' }, { id = 'materials', label = 'Material' } },
            Items = {
                { id = 'water', name = 'rp_water', price = 12, category = 'food' },
                { id = 'sandwich', name = 'rp_sandwich', price = 25, category = 'food' },
                { id = 'bandage', name = 'rp_bandage', price = 45, category = 'gear' },
                { id = 'backpack', name = 'rp_backpack_small', price = 350, category = 'gear' },
                { id = 'fabric', name = 'rp_fabric', price = 8, category = 'materials' },
                { id = 'thread', name = 'rp_thread', price = 5, category = 'materials' },
                { id = 'plastic', name = 'rp_plastic', price = 6, category = 'materials' },
            },
        },
    },
    venues = {
        strawberry_workbench = {
            kind = 'crafting', label = 'Werkbank · Strawberry', subtitle = 'Aus Materialien wird etwas Eigenes.',
            coords = { x = 28.4, y = -1339.0, z = 29.5, bucket = 0 },
            blip = { sprite = 566, color = 2, label = 'Werkbank · Testrezepte' },
            offers = {
                { id = 'bandage', item = 'rp_bandage', count = 1, seconds = 3, category = 'Versorgung',
                    ingredients = { { name = 'rp_fabric', count = 2 }, { name = 'rp_water', count = 1 } } },
                { id = 'daypack', item = 'rp_backpack_small', count = 1, seconds = 6, category = 'Taschen',
                    ingredients = { { name = 'rp_fabric', count = 6 }, { name = 'rp_thread', count = 2 }, { name = 'rp_plastic', count = 2 } } },
                { id = 'travelpack', item = 'rp_backpack_large', count = 1, seconds = 10, category = 'Taschen',
                    ingredients = { { name = 'rp_backpack_small', count = 1 }, { name = 'rp_fabric', count = 8 }, { name = 'rp_thread', count = 4 } } },
            },
        },
    },
}
