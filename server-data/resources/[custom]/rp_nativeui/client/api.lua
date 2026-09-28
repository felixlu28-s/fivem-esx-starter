local N = NativeMenu
local menus, stack, active, busy = {}, {}, nil, false
local serial = 0
local function nextId() serial = serial + 1 return serial end
local function caller() return GetInvokingResource() or GetCurrentResourceName() end
local function owned(handle, owner) return type(handle) == 'string' and menus[handle] and menus[handle].owner == owner end
local function snapshot()
    if not active then return nil end
    local payload = N.copy(active.definition)
    payload.session, payload.revision, payload.selected, payload.depth = active.session, active.revision, active.selected, #stack
    return payload
end
local function show()
    if not active then return true end
    return exports.rp_ui:rpOpen('nativeui', snapshot(), true, { keyboardOnly = true, toggleAction = stack[1] and stack[1].toggleAction })
end
local function invoke(menu, name, ...)
    local handler = menu.handlers[name]
    if not handler then return true end
    local ok, result = pcall(handler, ...)
    if not ok then print(('[rp_nativeui] %s callback failed in %s: %s'):format(name, menu.owner, tostring(result))) return false end
    return result ~= false
end
local function close(reason, silent)
    local previous = stack
    stack, active = {}, nil
    if exports.rp_ui:rpGetView() == 'nativeui' then exports.rp_ui:rpClose() end
    if not silent then for i = #previous, 1, -1 do invoke(previous[i], 'onClose', reason or 'closed', previous[i].handle) end end
    return true
end
local function open(handle, push, owner)
    if not owned(handle, owner) then return false, 'foreign_menu' end
    local view = exports.rp_ui:rpGetView()
    if view and view ~= 'nativeui' then return false, 'ui_busy' end
    if active and active.owner ~= owner then return false, 'ui_busy' end
    if push and (not active or #stack >= 12) then return false, 'invalid_parent' end
    for _, menu in ipairs(stack) do if push and menu.handle == handle then return false, 'menu_cycle' end end
    local menu = menus[handle]
    local previous, oldActive = stack, active
    stack = {}
    if push then for i, entry in ipairs(previous) do stack[i] = entry end end
    local oldSession, oldRevision = menu.session, menu.revision
    menu.session, menu.revision = tostring(nextId()), nextId()
    stack[#stack + 1], active = menu, menu
    if not show() then
        stack, active = previous, oldActive
        menu.session, menu.revision = oldSession, oldRevision
        return false, 'ui_busy'
    end
    if not push then for i = #previous, 1, -1 do if previous[i] ~= menu then invoke(previous[i], 'onClose', 'replaced', previous[i].handle) end end end
    return true
end
function N.create(owner, id, definition, handlers)
    if type(id) ~= 'string' or #id > 80 or not id:match('^[%w_-]+$') then return nil, 'invalid_id' end
    local handle = owner .. '/' .. id
    if menus[handle] then return nil, 'already_exists' end
    local data, err = N.definition(definition, owner)
    if not data then return nil, err end
    handlers = handlers or {}
    if type(handlers) ~= 'table' then return nil, 'invalid_callbacks' end
    local callbacks = {}
    for name, fn in pairs(handlers) do
        if not ({ onSelect = true, onChange = true, onClose = true, onHighlight = true })[name] or not N.callable(fn) then return nil, 'invalid_callbacks' end
        callbacks[name] = fn
    end
    menus[handle] = { handle = handle, owner = owner, definition = data, handlers = callbacks, selected = #data.items > 0 and 1 or 0 }
    return handle
end
function N.update(owner, handle, patch)
    if not owned(handle, owner) or type(patch) ~= 'table' then return false, 'foreign_menu' end
    local menu = menus[handle]
    local definition = N.copy(menu.definition)
    for _, field in ipairs({ 'title', 'subtitle', 'description', 'theme', 'visibleRows', 'items' }) do if patch[field] ~= nil then definition[field] = patch[field] end end
    local data, err = N.definition(definition, owner)
    if not data then return false, err end
    local selectedId = menu.definition.items[menu.selected] and menu.definition.items[menu.selected].id
    menu.definition, menu.revision = data, nextId()
    menu.selected = #data.items > 0 and math.max(1, math.min(menu.selected, #data.items)) or 0
    for index, item in ipairs(data.items) do if item.id == selectedId then menu.selected = index break end end
    if active == menu then show() end
    return true
end
exports('rpCreateMenu', function(id, definition, handlers) return N.create(caller(), id, definition, handlers) end)
exports('rpUpdateMenu', function(handle, patch) return N.update(caller(), handle, patch) end)
exports('rpSetItems', function(handle, items) return N.update(caller(), handle, { items = items }) end)
exports('rpOpenMenu', function(handle, options)
    local owner = caller()
    if not owned(handle, owner) then return false, 'foreign_menu' end
    local action = type(options) == 'table' and options.toggleAction or nil
    if action ~= nil and (type(action) ~= 'string' or action:sub(1,#owner+1) ~= owner..':'
        or not action:match('^rp_[%w_]+:[%w_]+$')) then return false, 'invalid_toggle' end
    menus[handle].toggleAction = action
    return open(handle, false, owner)
end)
exports('rpPushMenu', function(handle) return open(handle, true, caller()) end)
exports('rpCloseMenu', function()
    if not active or active.owner ~= caller() then return false end
    return close('api')
end)
exports('rpGetMenuState', function(handle)
    if not owned(handle, caller()) then return nil end
    return { definition = N.copy(menus[handle].definition), selected = menus[handle].selected, open = active == menus[handle] }
end)
exports('rpDestroyMenu', function(handle)
    if not owned(handle, caller()) then return false end
    for _, menu in ipairs(stack) do if menu.handle == handle then close('destroyed') break end end
    menus[handle] = nil return true
end)
local function input(p)
    if type(p) ~= 'table' or not active or exports.rp_ui:rpGetView() ~= 'nativeui' then return { ok = false, error = 'closed' } end
    if p.session ~= active.session or p.revision ~= active.revision then return { ok = false, error = 'stale_menu', nativeui = snapshot() } end
    if busy then return { ok = false, error = 'busy', nativeui = snapshot() } end
    if not ({ up = true, down = true, left = true, right = true, enter = true, back = true })[p.key]
        and not (p.key == 'close' and stack[1] and stack[1].toggleAction) then return { ok = false, error = 'invalid_key' } end
    busy = true
    local menu, accepted = active, true
    if p.key == 'close' then close('toggle')
    elseif p.key == 'back' then
        if #stack == 1 then close('back') else
            table.remove(stack)
            active = stack[#stack]
            active.session, active.revision = tostring(nextId()), nextId()
            show()
            invoke(menu, 'onClose', 'back', menu.handle)
        end
    elseif p.key == 'up' or p.key == 'down' then
        local count = #menu.definition.items
        if count > 0 then
            menu.selected = (menu.selected - 1 + (p.key == 'up' and -1 or 1)) % count + 1
            local item = menu.definition.items[menu.selected]
            invoke(menu, 'onHighlight', item.id, N.copy(item), menu.handle)
        end
    else
        local item = menu.definition.items[menu.selected]
        if not item or item.disabled then accepted = false
        elseif item.type == 'list' and (p.key == 'left' or p.key == 'right') then
            local previous, revision = item.index, menu.revision
            item.index = (item.index - 1 + (p.key == 'left' and -1 or 1)) % #item.options + 1
            accepted = invoke(menu, 'onChange', item.id, item.options[item.index].value, item.index, menu.handle)
            if not accepted and menu.revision == revision then item.index = previous end
        elseif item.type == 'checkbox' and p.key == 'enter' then
            local previous, revision = item.checked, menu.revision
            item.checked = not item.checked
            accepted = invoke(menu, 'onChange', item.id, item.checked, nil, menu.handle)
            if not accepted and menu.revision == revision then item.checked = previous end
        elseif p.key == 'enter' then
            local session = menu.session
            accepted = invoke(menu, 'onSelect', item.id, N.copy(item), menu.handle)
            if accepted and active == menu and menu.session == session and item.type == 'submenu' then accepted = open(item.menu, true, menu.owner) == true end
        end
    end
    if active then active.revision = nextId() show() end
    busy = false
    PlaySoundFrontend(-1, not accepted and 'ERROR' or p.key == 'back' and 'BACK' or p.key == 'enter' and 'SELECT' or 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    return { ok = accepted, error = not accepted and 'action_rejected' or nil, nativeui = snapshot(), closed = active == nil }
end
local function register()
    exports.rp_ui:rpRegisterAction('rp_nativeui:input', function(p)
        local ok, result = pcall(input, p)
        if not ok then busy = false return { ok = false, error = 'menu_error', nativeui = snapshot() } end
        return result
    end)
end
CreateThread(register)
AddEventHandler('onClientResourceStart', function(resource) if resource == 'rp_ui' then register() end end)
AddEventHandler('esx:onPlayerLogout', function() close('logout') end)
AddEventHandler('onResourceStop', function(resource)
    if resource == 'rp_ui' then stack, active = {}, nil return end
    if resource == GetCurrentResourceName() or (active and active.owner == resource) then close('resource_stop', true) end
    for handle, menu in pairs(menus) do if menu.owner == resource then menus[handle] = nil end end
end)
N.open = function(handle) return open(handle, false, GetCurrentResourceName()) end
