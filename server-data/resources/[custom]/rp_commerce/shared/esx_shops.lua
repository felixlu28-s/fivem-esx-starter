-- Reuse the official esx_shops Items / Categories / Pos / blip configuration
-- contract. Runtime transactions/UI are ours, so no second shop handler starts.
local C = Commerce.Config
for zoneId, zone in pairs(C.esxZones or {}) do
    assert(type(zoneId) == 'string' and zoneId:match('^[%w_-]+$') and type(zone.Items) == 'table'
        and type(zone.Pos) == 'table' and #zone.Pos > 0, 'Invalid ESX shop zone')
    local categories, offers = {}, {}
    for _, category in ipairs(zone.Categories or {}) do categories[category.id] = category.label end
    for _, item in ipairs(zone.Items) do
        offers[#offers+1] = { id = item.id or item.name, item = item.name, price = item.price,
            category = categories[item.category] or item.category or 'Sortiment' }
    end
    for index, position in ipairs(zone.Pos) do
        local id = #zone.Pos == 1 and zoneId or ('%s_%d'):format(zoneId, index)
        assert(not C.venues[id], 'Duplicate shop/workbench ID: ' .. id)
        C.venues[id] = { kind = 'shop', label = zone.Label or zoneId,
            subtitle = zone.Subtitle or 'Alles für deinen Alltag.', jobs = zone.Jobs,
            coords = { x = position.x, y = position.y, z = position.z, bucket = zone.Bucket or 0 },
            offers = offers, marker = zone.ShowMarker ~= false,
            blip = zone.ShowBlip ~= false and { sprite = zone.Type or 52, color = zone.Color or 2,
                label = zone.BlipLabel or zone.Label or zoneId } or nil }
    end
end
