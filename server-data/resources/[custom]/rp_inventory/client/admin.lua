local ui = exports.rp_nativeui
local context, handles, loading, generation = nil, {}, false, 0
local messages = {
    forbidden = 'Keine Berechtigung oder Sitzung abgelaufen. /rp_items erneut öffnen.',
    invalid_target = 'Diese Spieler-ID ist nicht mit einem spielbaren Charakter verbunden.',
    too_heavy = 'Die komplette Menge passt vom Gewicht her nicht ins Zielinventar.',
    no_slots = 'Im Zielinventar sind nicht genügend freie Plätze.',
    busy = 'Eine Aktion läuft bereits. Bitte kurz warten.',
    rate_limited = 'Bitte einen Moment warten.',
    session_expired = 'Sitzung oder Zielcharakter nicht mehr gültig. Menü erneut öffnen.',
    database_error = 'Speichern nicht bestätigt. Erneut mit derselben Auswahl versuchen.',
}
local function notify(text, kind) lib.notify({ title = 'Itemverwaltung', description = text, type = kind or 'error' }) end
local function request(name, ...)
    local ok, result = pcall(lib.callback.await, 'rp_inventory:' .. name, false, ...)
    if ok and type(result) == 'table' then return result end
    return { ok = false, error = 'database_error' }
end
local function clip(value, limit)
    value = tostring(value)
    while #value > limit do value = value:sub(1, (utf8.offset(value, -1) or #value) - 1) end
    return value
end
local function clear()
    generation = generation + 1
    context = nil
    if GetResourceState('rp_nativeui') == 'started' then
        for _, handle in ipairs(handles) do ui:rpDestroyMenu(handle) end
    end
    handles = {}
end
local function create(id, definition, callbacks)
    local handle, err = ui:rpCreateMenu(id, definition, callbacks)
    if not handle then error('Admin menu: ' .. tostring(err)) end
    handles[#handles + 1] = handle
    return handle
end
local function rootItems(ctx)
    local rows = {{ id = 'target', label = 'Empfänger', type = 'list', index = ctx.mode == 'self' and 1 or 2,
        options = {{label='Mich · ID ' .. GetPlayerServerId(PlayerId()),value='self'},
            {label=ctx.otherId and ('Geben · ID ' .. ctx.otherId) or 'Geben …',value='other'}},
        description = '← / → Empfänger wählen. Bei „Geben“ Enter drücken und eine Spieler-ID eingeben.' }}
    for _, row in ipairs(ctx.categories) do rows[#rows+1] = row end
    return rows
end
local function refresh(ctx)
    if context == ctx then ui:rpSetItems(ctx.root, rootItems(ctx)) end
end
local function selectTarget(ctx, target)
    local result = request('adminTarget', ctx.token, target)
    if context ~= ctx then return end
    ctx.busy = false
    if result.ok then
        ctx.ticket, ctx.target, ctx.ready = result.ticket, result.target, true
        if ctx.mode == 'other' then ctx.otherId = result.target end
    else notify(messages[result.error] or 'Empfänger konnte nicht gewählt werden.') end
    refresh(ctx)
end
local function targetInput(ctx)
    if ctx.busy then return false end
    ctx.busy, ctx.suspended = true, true
    ui:rpCloseMenu()
    CreateThread(function()
        Wait(0) -- Finish NativeUI's Enter callback before opening the game keyboard.
        if context ~= ctx then return end
        AddTextEntry('RP_INVENTORY_TARGET_ID', 'Itemverwaltung: Spieler-ID eingeben')
        DisplayOnscreenKeyboard(1, 'RP_INVENTORY_TARGET_ID', '', ctx.otherId and tostring(ctx.otherId) or '', '', '', '', 10)
        local status = UpdateOnscreenKeyboard()
        while status == 0 and context == ctx do
            DisableAllControlActions(0)
            Wait(0)
            status = UpdateOnscreenKeyboard()
        end
        if context ~= ctx then CancelOnscreenKeyboard() return end
        if status == 1 then
            local value = GetOnscreenKeyboardResult()
            local target = type(value) == 'string' and value:match('^%d+$') and tonumber(value)
            if target and target > 0 and target <= 2147483647 then selectTarget(ctx, target)
            else ctx.busy = false notify(messages.invalid_target) end
        else ctx.busy = false end
        if context ~= ctx then return end
        ctx.suspended = false
        if not ui:rpOpenMenu(ctx.root) then clear() end
    end)
    return false
end
local function give(ctx, entry, amount)
    if ctx.busy then notify(messages.busy) return false end
    if not ctx.ready then notify('Zuerst oben einen Empfänger mit Enter festlegen.') return false end
    ctx.busy = true
    CreateThread(function()
        local result = request('adminGive', ctx.token, ctx.ticket, entry.name, amount)
        if context ~= ctx then return end
        ctx.busy = false
        if result.ok then
            ctx.ticket = result.ticket
            notify(('%d × %s an ID %d vergeben.'):format(amount, entry.label, result.target), 'success')
        else notify(messages[result.error] or 'Die Vergabe wurde abgelehnt.') end
    end)
    return true
end
local function build(result)
    clear()
    local ctx = { token=result.token,ticket=result.ticket,target=result.target,ready=true,mode='self',categories={},busy=false }
    context = ctx
    local groups, names, serial = {}, {}, 0
    for _, entry in ipairs(result.items) do
        if not groups[entry.category] then groups[entry.category] = {} names[#names+1] = entry.category end
        groups[entry.category][#groups[entry.category]+1] = entry
    end
    table.sort(names)
    local amounts = {}
    for count=1,99 do amounts[count] = {label=tostring(count),value=count} end
    local function menu(title, entries)
        serial = serial + 1
        local id, rows, lookup = 'admin_items_' .. serial, {}, {}
        for index, entry in ipairs(entries) do
            local rowId = 'item_' .. index
            rows[#rows+1] = {id=rowId,label=clip(entry.label,160),type='list',options=amounts,index=1,
                description=clip(('%s · %.2f kg · Stapel %d. Enter: gewählte Menge vergeben.'):format(entry.name,entry.weight/1000,entry.maxStack),580)}
            lookup[rowId] = entry
        end
        return create(id,{title='Itemverwaltung',subtitle=clip(title,110),visibleRows=8,items=rows}, {
            onSelect=function(id, item)
                if context ~= ctx then return false end
                return give(ctx, lookup[id], item.options[item.index].value)
            end,
            onChange=function() return context == ctx and not ctx.busy end,
        })
    end
    -- Paginated branches keep every provider/ESX item reachable within NativeUI limits.
    local function branch(title, children)
        if #children > 180 then
            local parents = {}
            for first=1,#children,180 do
                local subset = {}
                for i=first,math.min(first+179,#children) do subset[#subset+1]=children[i] end
                parents[#parents+1] = {id='page_' .. first,label=('Einträge %d–%d'):format(first,math.min(first+179,#children)),
                    type='submenu',menu=branch(title,subset)}
            end
            return branch(title,parents)
        end
        serial=serial+1
        return create('admin_pages_' .. serial,{title='Itemverwaltung',subtitle=clip(title,110),items=children})
    end
    for _, name in ipairs(names) do
        local entries, pages = groups[name], {}
        for first=1,#entries,180 do
            local subset = {}
            for i=first,math.min(first+179,#entries) do subset[#subset+1]=entries[i] end
            pages[#pages+1] = {id='page_' .. first,label=('Items %d–%d'):format(first,math.min(first+179,#entries)),
                type='submenu',menu=menu(name,subset)}
        end
        ctx.categories[#ctx.categories+1] = {id='category_' .. #ctx.categories+1,label=name,type='submenu',
            rightLabel=tostring(#entries),menu=#pages==1 and pages[1].menu or branch(name,pages)}
    end
    ctx.root = create('admin_items_root',{title='Itemverwaltung',subtitle='ADMINISTRATION',items=rootItems(ctx)}, {
        onChange=function(id, value)
            if context ~= ctx or ctx.busy then return false end
            if id == 'target' then
                ctx.mode, ctx.ready, ctx.otherId = value, false, nil
                if value == 'self' then ctx.busy=true CreateThread(function() selectTarget(ctx, GetPlayerServerId(PlayerId())) end) end
                refresh(ctx)
            end
        end,
        onSelect=function(id)
            if context ~= ctx or ctx.busy then return false end
            if id == 'target' and ctx.mode == 'other' then return targetInput(ctx) end
        end,
        onClose=function() if context==ctx and not ctx.suspended then clear() end end,
    })
    if not ui:rpOpenMenu(ctx.root) then clear() notify('Bitte zuerst das andere Menü schließen.') end
end
RegisterNetEvent('rp_inventory:adminOpen', function()
    if source ~= 65535 or loading or (context and context.busy) then return end
    if exports.rp_ui:rpGetView() then return notify('Bitte zuerst das offene Menü schließen.') end
    loading = true
    local epoch = generation
    CreateThread(function()
        local result = request('adminCatalog')
        loading = false
        if epoch ~= generation then return end
        if not result.ok then return notify(messages[result.error] or 'Itemkatalog nicht verfügbar.') end
        local ok, err = pcall(build, result)
        if not ok then clear() print('[rp_inventory] Admin menu error: ' .. tostring(err)) notify('Itemmenü konnte nicht aufgebaut werden.') end
    end)
end)
AddEventHandler('esx:onPlayerLogout', clear)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() or resource == 'rp_nativeui' or resource == 'rp_ui' then clear() end
end)
