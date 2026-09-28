local M = {}
Inventory.model = M
function M.integer(v, low, high)
    return type(v) == 'number' and v == v and v % 1 == 0 and v >= low and v <= high
end
function M.copy(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = M.copy(v) end
    return result
end
-- Stable comparison and request fingerprints; metadata never comes from a UI request.
function M.canonical(value)
    if type(value) ~= 'table' then return tostring(value) .. ':' .. type(value) end
    local keys, parts = {}, {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do parts[#parts + 1] = #tostring(k) .. ':' .. tostring(k) .. '=' .. M.canonical(value[k]) end
    return '{' .. table.concat(parts, ';') .. '}'
end
function M.empty(slots, weight)
    return { slots = slots or Inventory.baseSlots, capacity = weight or Inventory.baseWeight, items = {} }
end
function M.limits(data)
    local bag = data.backpack and Inventory.items[data.backpack.name]
    return data.slots + (bag and bag.slots or 0), data.capacity + (bag and bag.capacity or 0)
end
function M.weight(data)
    local total = data.backpack and Inventory.items[data.backpack.name].weight or 0
    for _, entry in pairs(data.items) do
        local def = Inventory.items[entry.name]
        if not def then return math.huge end
        total = total + def.weight * entry.count
        if def.weapon then
            local components = entry.metadata and entry.metadata.components
            for _, component in ipairs(type(components) == 'table' and components or {}) do
                for _, attachment in pairs(Inventory.items) do
                    if attachment.weaponName == entry.name and attachment.component == component then
                        total = total + attachment.weight * entry.count
                        break
                    end
                end
            end
        end
    end
    return total
end
function M.valid(data)
    if type(data) ~= 'table' or type(data.items) ~= 'table' or not M.integer(data.slots, 1, 200)
        or not M.integer(data.capacity, 0, 10000000) then return false end
    if data.backpack then
        local bag = Inventory.items[data.backpack.name]
        if not bag or not bag.slots or data.backpack.count ~= 1 then return false end
    end
    local slots, capacity = M.limits(data)
    for slot, entry in pairs(data.items) do
        if type(slot) ~= 'string' or not M.integer(tonumber(slot), 1, slots) or tostring(tonumber(slot)) ~= slot
            or type(entry) ~= 'table' then return false end
        local def = Inventory.items[entry.name]
        if not def or not M.integer(entry.count, 1, def.legacyMaxStack or def.maxStack) or type(entry.metadata) ~= 'table' then return false end
    end
    return M.weight(data) <= capacity
end
function M.matches(a, b)
    return a.name == b.name and M.canonical(a.metadata) == M.canonical(b.metadata)
end
-- Forward-compatible stack conversion. Preserve occupied slots, metadata, weight and quantity.
-- A completely full legacy inventory remains usable; excess is split as slots become free.
-- New additions/merges still use maxStack exclusively and cannot grow legacy stacks.
function M.repackAmmo(data)
    if type(data)~='table' or type(data.items)~='table' then return end
    local needed=false
    for _,entry in pairs(data.items) do
        local def=type(entry)=='table' and Inventory.items[entry.name]
        if def and def.legacyMaxStack and type(entry.count)=='number' and entry.count>def.maxStack then needed=true break end
    end
    if not needed then return end
    if not M.valid(data) then return end
    local slots=M.limits(data)
    local free={}
    for i=1,slots do if not data.items[tostring(i)] then free[#free+1]=tostring(i) end end
    local cursor=1
    for i=1,slots do
        local entry=data.items[tostring(i)]
        local def=entry and Inventory.items[entry.name]
        if def and def.legacyMaxStack then
            while entry.count>def.maxStack and free[cursor] do
                local moved=math.min(def.maxStack,entry.count-def.maxStack)
                local split=M.copy(entry) split.count=moved
                data.items[free[cursor]]=split entry.count=entry.count-moved cursor=cursor+1
            end
        end
    end
end
function M.componentList(entry)
    local result = {}
    if not Inventory.items[entry.name] or not Inventory.items[entry.name].weapon then return result end
    for _, component in ipairs(type(entry.metadata.components) == 'table' and entry.metadata.components or {}) do
        for name, def in pairs(Inventory.items) do
            if def.weaponName == entry.name and def.component == component then
                result[#result+1] = { name = name, label = def.label, component = component }
                break
            end
        end
    end
    return result
end
function M.installComponent(data, slot, preferredId)
    if not M.integer(slot,1,M.limits(data)) then return false,'invalid_slot' end
    slot=math.tointeger(slot)
    local item = data.items[tostring(slot)]
    local def = item and Inventory.items[item.name]
    if not def or def.use ~= 'component' then return false, 'invalid_item' end
    local slots = M.limits(data)
    local order = {}
    for i = 1, slots do
        local entry = data.items[tostring(i)]
        if preferredId and entry and entry.name == def.weaponName and entry.metadata.weaponId == preferredId then order[1] = i break end
    end
    -- An explicitly held instance must not silently redirect to another copy.
    if #order == 0 then for i = 1, slots do order[#order+1] = i end end
    for _, i in ipairs(order) do
        local weapon = data.items[tostring(i)]
        if weapon and weapon.name == def.weaponName then
            local components, installed = weapon.metadata.components or {}, false
            if type(components) ~= 'table' then return false, 'invalid_item' end
            for _, value in ipairs(components) do if value == def.component then installed = true end end
            if not installed then
                if weapon.metadata.componentItems~=nil and type(weapon.metadata.componentItems)~='table' then return false,'invalid_item' end
                local ok, reason = M.remove(data, item.name, 1, item.metadata, slot)
                if not ok then return false, reason end
                weapon.metadata.components = components
                components[#components+1] = def.component
                weapon.metadata.componentItems = weapon.metadata.componentItems or {}
                weapon.metadata.componentItems[def.component] = { name = item.name, metadata = M.copy(item.metadata) }
                return true, nil, i
            end
        end
    end
    return false, 'no_compatible_weapon'
end
function M.removeComponent(data, slot, name)
    if not M.integer(slot, 1, M.limits(data)) then return false, 'invalid_slot' end
    local weapon = data.items[tostring(math.tointeger(slot))]
    local def = Inventory.items[name]
    if not weapon or not def or def.use ~= 'component' or def.weaponName ~= weapon.name then return false, 'invalid_item' end
    local components = weapon.metadata.components
    if type(components) ~= 'table' then return false, 'component_missing' end
    local index
    for i, value in ipairs(components) do if value == def.component then index = i break end end
    if not index then return false, 'component_missing' end
    local stored = weapon.metadata.componentItems and weapon.metadata.componentItems[def.component]
    if stored and (stored.name ~= name or type(stored.metadata) ~= 'table') then return false, 'invalid_item' end
    table.remove(components, index)
    if weapon.metadata.componentItems then weapon.metadata.componentItems[def.component] = nil end
    -- Removal and item return commit together; on capacity failure discard the copy.
    return M.add(data, name, 1, stored and stored.metadata or {})
end
function M.count(data, name, metadata)
    local count = 0
    for _, e in pairs(data.items) do
        if e.name == name and (metadata == nil or M.canonical(e.metadata) == M.canonical(metadata)) then count = count + e.count end
    end
    -- Equipped backpack remains an owned ESX item; removal must unequip safely first.
    if data.backpack and data.backpack.name == name and (metadata == nil or M.canonical(data.backpack.metadata) == M.canonical(metadata)) then count = count + 1 end
    return count
end
-- All mutators operate on transaction-local copies. Discard the entire copy on false.
function M.add(data, name, count, metadata, preferred)
    local def = Inventory.items[name]
    if not def or not M.integer(count, 1, 100000) then return false, 'invalid_item' end
    local slots = M.limits(data)
    if preferred and not M.integer(preferred, 1, slots) then return false, 'invalid_slot' end
    if preferred then preferred=math.tointeger(preferred) end
    local prototype = { name = name, count = count, metadata = M.copy(metadata or {}) }
    local order = {}
    if preferred then order[1] = preferred else
        for i = 1, slots do if data.items[tostring(i)] then order[#order + 1] = i end end
        for i = 1, slots do if not data.items[tostring(i)] then order[#order + 1] = i end end
    end
    for _, i in ipairs(order) do
        local key, existing = tostring(i), data.items[tostring(i)]
        if not existing or M.matches(existing, prototype) then
            local moved = math.min(count, def.maxStack - (existing and existing.count or 0))
            if moved > 0 then
                if not existing then existing = M.copy(prototype) existing.count = 0 data.items[key] = existing end
                existing.count, count = existing.count + moved, count - moved
            end
        end
        if count == 0 then break end
    end
    if count > 0 then return false, 'no_slots' end
    if not M.valid(data) then return false, 'too_heavy' end
    return true
end
function M.remove(data, name, count, metadata, preferred)
    if not Inventory.items[name] or not M.integer(count, 1, 100000) then return false, 'invalid_item' end
    local slots = M.limits(data)
    if preferred and not M.integer(preferred, 1, slots) then return false, 'invalid_slot' end
    if preferred then preferred=math.tointeger(preferred) end
    for i = preferred or 1, preferred or slots do
        local key, e = tostring(i), data.items[tostring(i)]
        if e and e.name == name and (metadata == nil or M.canonical(e.metadata) == M.canonical(metadata)) then
            local moved = math.min(count, e.count)
            e.count, count = e.count - moved, count - moved
            if e.count == 0 then data.items[key] = nil end
        end
        if count == 0 then return true end
    end
    if not preferred and count == 1 and data.backpack and data.backpack.name == name
        and (metadata == nil or M.canonical(data.backpack.metadata) == M.canonical(metadata)) then
        data.backpack = nil
        if M.valid(data) then return true end
        return false, 'backpack_full'
    end
    return false, 'not_enough'
end
function M.move(from, to, fromSlot, toSlot, count)
    if not M.integer(fromSlot, 1, M.limits(from)) or not M.integer(toSlot, 1, M.limits(to))
        or not M.integer(count, 1, 100000) then return false, 'invalid_slot' end
    fromSlot,toSlot=math.tointeger(fromSlot),math.tointeger(toSlot)
    if from == to and fromSlot == toSlot then return false, 'invalid_slot' end
    local a, b = from.items[tostring(fromSlot)], to.items[tostring(toSlot)]
    if not a or count > a.count then return false, 'not_enough' end
    if b and not M.matches(a, b) then
        if count ~= a.count then return false, 'slot_occupied' end
        from.items[tostring(fromSlot)], to.items[tostring(toSlot)] = b, a
    else
        local copy = M.copy(a)
        local ok, err = M.remove(from, a.name, count, a.metadata, fromSlot)
        if not ok then return false, err end
        ok, err = M.add(to, copy.name, count, copy.metadata, toSlot)
        if not ok then return false, err end
    end
    if not M.valid(from) or not M.valid(to) then return false, 'too_heavy' end
    return true
end
function M.equip(data, slot)
    if not M.integer(slot,1,M.limits(data)) then return false,'invalid_slot' end
    slot=math.tointeger(slot)
    local e = data.items[tostring(slot)]
    if not e or not Inventory.items[e.name].slots then return false, 'invalid_item' end
    local previous = data.backpack
    data.items[tostring(slot)], data.backpack = previous, e
    if not M.valid(data) then return false, 'backpack_full' end
    return true
end
function M.unequip(data)
    local bag = data.backpack
    if not bag then return false, 'invalid_item' end
    data.backpack = nil
    local ok = M.add(data, bag.name, 1, bag.metadata)
    if not ok or not M.valid(data) then return false, 'backpack_full' end
    return true
end
