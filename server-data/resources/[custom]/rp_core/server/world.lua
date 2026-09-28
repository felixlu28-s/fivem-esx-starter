SetRoutingBucketPopulationEnabled(0, false)
AddEventHandler('entityCreating', function(entity)
    local kind = GetEntityType(entity)
    if kind ~= 1 and kind ~= 2 then return end
    local population = GetEntityPopulationType(entity)
    -- Player peds and explicitly spawned vehicles are not ambient population.
    if population >= 1 and population <= 5 then CancelEvent() end
end)
