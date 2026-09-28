PlayerProgress = {}
function PlayerProgress.level(meters)
    return math.min(PlayerConfig.maxLevel, math.floor(meters / PlayerConfig.metersPerLevel) + 1)
end
function PlayerProgress.sample(previous, current, elapsed, eligible, previouslyEligible)
    if not previous or not eligible or not previouslyEligible or elapsed <= 0 or elapsed > PlayerConfig.sampleSeconds * 2 then return 0, 0 end
    local dx, dy, dz = current.x - previous.x, current.y - previous.y, current.z - previous.z
    local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
    local speed = distance / elapsed
    if speed ~= speed or speed < PlayerConfig.minRunningSpeed or speed > PlayerConfig.maxRunningSpeed or math.abs(dz) >= 4 then return 0, 0 end
    return distance, elapsed
end
