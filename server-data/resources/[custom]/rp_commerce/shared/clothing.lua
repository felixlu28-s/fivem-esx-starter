Commerce.Clothing = { shops = {
    binco_strawberry = { label = 'Binco · Strawberry', subtitle = 'DEIN STIL. DEINE STADT.',
        coords = { x = 75.43, y = -1392.93, z = 29.38, bucket = 0 },
        npc = { enabled = true, model = 's_f_y_shop_mid', pos = {x=73.92,y=-1392.05,z=28.38}, heading = 269.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT' } },
    suburban_hawick = { label = 'Suburban · Hawick', subtitle = 'DEIN STIL. DEINE STADT.',
        coords = { x = 125.43, y = -224.97, z = 54.56, bucket = 0 },
        npc = { enabled = true, model = 's_f_y_shop_mid', pos = {x=127.14,y=-223.23,z=53.56}, heading = 65.0,
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT' } },
} }
for id, shop in pairs(Commerce.Clothing.shops) do
    local offers = {}
    for _, product in pairs(Clothing.products) do
        if not product.hidden then
        offers[#offers+1] = { id = product.id, item = 'clothing_' .. product.category, category = Clothing.categories[product.category].label,
            price = product.price, count = 1, sex = product.sex, metadata = { garment = {
                product = product.id, sex = product.sex, skin = product.skin, label = product.label
            } } }
        end
    end
    table.sort(offers, function(a,b) return a.id < b.id end)
    Commerce.Config.venues[id] = { kind = 'shop', clothing = true, label = shop.label, subtitle = shop.subtitle,
        coords = shop.coords, offers = offers }
end
