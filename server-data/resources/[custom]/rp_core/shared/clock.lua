RP = RP or {}
RP.Clock = {}

-- Current MEZ/MESZ rules: last Sunday of March/October, transition at 01:00 UTC.
-- Input must be a UTC os.date('*t') record, independent of the host timezone.
function RP.Clock.fromUtc(utc)
    local summer = utc.month > 3 and utc.month < 10
    if utc.month == 3 or utc.month == 10 then
        local sunday = 31 - ((utc.wday - 1 + 31 - utc.day) % 7)
        local after = utc.day > sunday or (utc.day == sunday and utc.hour >= 1)
        summer = (utc.month == 3 and after) or (utc.month == 10 and not after)
    end
    local offset = summer and 7200 or 3600
    return { seconds = (utc.hour * 3600 + utc.min * 60 + utc.sec + offset) % 86400, offset = offset }
end

function RP.Clock.valid(sample)
    return type(sample) == 'table' and type(sample.seconds) == 'number'
        and sample.seconds >= 0 and sample.seconds < 86400 and sample.seconds % 1 == 0
        and (sample.offset == 3600 or sample.offset == 7200)
end
