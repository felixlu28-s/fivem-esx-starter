local R = {}
Garage.Rules = R
function R.plate(value)
    if type(value) ~= 'string' or #value > 12 then return end
    value = value:match('^%s*(.-)%s*$')
    if value == '' or value:find('[^%w %-]') then return end
    return value
end
function R.integer(value, low, high)
    return type(value) == 'number' and value == value and value % 1 == 0 and value >= low and value <= high
end
function R.distance(a, b)
    return math.sqrt((a.x-b.x)^2 + (a.y-b.y)^2 + (a.z-b.z)^2)
end
function R.outsideGate(garage,position,clearance)
    local dx,dy=garage.parking.x-garage.hidden.x,garage.parking.y-garage.hidden.y
    local length=math.sqrt(dx*dx+dy*dy)
    if length<0.1 then return false end
    return ((position.x-garage.gate.x)*dx+(position.y-garage.gate.y)*dy)/length >= clearance
end
function R.available(row, owner, garage)
    return row and row.owner == owner and tonumber(row.stored) == 1 and row.type == 'car'
        and (not row.job or row.job == '') and (not row.pound or row.pound == '')
        and (not row.parking or row.parking == '' or row.parking == garage)
end
-- Only runtime condition fields may come from the driver, never model/tuning/identity.
-- A garage cannot repair a vehicle by reporting a higher health/fuel value.
function R.condition(properties, observed)
    local copy = {}
    for key, value in pairs(properties) do copy[key] = value end
    if type(observed) ~= 'table' then return copy end
    for key, range in pairs({ fuelLevel={0,100}, engineHealth={-4000,1000}, bodyHealth={0,1000}, tankHealth={-4000,1000} }) do
        local value = observed[key]
        if type(value) == 'number' and value == value and value >= range[1] and value <= range[2] then
            copy[key] = math.min(tonumber(copy[key]) or range[2], value)
        end
    end
    return copy
end
