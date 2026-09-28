local W, X = Commerce.Weapons, Commerce.Weapons.client
local current, serial = nil, 0
local inspectHint={keys={'W','A','S','D'},label='Waffe begutachten',detail='Halten zum Drehen · Loslassen zum Zurückfedern'}
local errors = {
    not_enough_money = 'Du hast auf diesem Konto nicht genug Geld.', too_heavy = 'Dein Inventar ist zu schwer.',
    no_slots = 'Kein Platz im Inventar.', weapon_license_required = 'Du benötigst eine Waffenlizenz.',
    license_unavailable = 'Die Lizenzprüfung ist zurzeit nicht verfügbar.', session_expired = 'Bitte öffne den Laden erneut.',
    payment_review = 'Die Zahlung muss geprüft werden. Es wird nicht erneut abgebucht.',
    pending_purchase = 'Eine frühere Bestellung ist noch offen. Nutze „Bestellung fortsetzen“.',
    nothing_pending = 'Es ist keine Bestellung offen.', rate_limited = 'Bitte einen Moment warten.',
    database_error = 'Bestätigung fehlt. Wiederhole dieselbe Bestellung oder nutze „Bestellung fortsetzen“.',
    out_of_range = 'Du bist zu weit vom Laden entfernt.', revision_conflict = 'Der Laden wurde geändert. Bitte erneut öffnen.',
    purchase_in_progress = 'Ein Kunde kauft gerade ein. Versuche es gleich erneut.',
    pending_orders = 'Dieser Laden hat offene Bestellungen. Vor dem Löschen zustellen oder über die Bestellprüfung klären.',
    forbidden = 'Die Editorberechtigung ist abgelaufen oder wurde entzogen. Bitte erneut öffnen.',
    forbidden_or_not_ready = 'Keine Berechtigung oder der Waffenladen ist noch nicht bereit. Serverkonsole prüfen.',
}
function X.notify(message, failed)
    lib.notify({ title = 'Ammu-Nation', description = errors[message] or message or 'Aktion nicht möglich.', type = failed and 'error' or 'inform' })
end
function X.menu(id, title, subtitle, rows, callbacks)
    local handle, reason = exports.rp_nativeui:rpCreateMenu(id, { title = title, subtitle = subtitle, items = rows, visibleRows = 8 }, callbacks)
    if not handle then X.notify('Menü nicht verfügbar: '..tostring(reason),true) end
    return handle
end
function X.closeShop(immediate)
    local ctx = current
    if not ctx then X.endScene(immediate) return end
    current = nil
    if ctx.data then TriggerServerEvent('rp_commerce:close',ctx.data.session) end
    pcall(function() exports.rp_nativeui:rpCloseMenu() end)
    for _,handle in ipairs(ctx.handles) do pcall(function() exports.rp_nativeui:rpDestroyMenu(handle) end) end
    X.endScene(immediate)
end
local function buy(ctx, key, quantity, recover)
    if current ~= ctx or ctx.busy then return end
    if ctx.test then return X.notify('Vorschau: Es werden keine Käufe ausgeführt.') end
    if ctx.pending and not recover and (ctx.pending.key ~= key or ctx.pending.quantity ~= quantity or ctx.pending.account ~= ctx.account) then
        return X.notify('Bitte zuerst die unbestätigte Bestellung erneut bestätigen oder fortsetzen.',true)
    end
    serial = serial+1
    ctx.pending = ctx.pending or { key = key, quantity = quantity, account = ctx.account, request = ('ammu_%x_%x'):format(GetGameTimer(),serial) }
    local op = ctx.pending
    ctx.busy = true
    CreateThread(function()
        local ok, response = pcall(lib.callback.await,'rp_commerce:action',false, { session = ctx.data.session,
            action = recover and 'recover' or 'buy', offer = op.key, quantity = op.quantity, account = op.account, request = op.request })
        ctx.busy = false
        if current ~= ctx then return end
        if ok and response and response.ok then
            ctx.pending = nil
            X.notify(recover and 'Bestellung zugestellt.' or 'Gekauft und im Inventar verstaut.')
        else
            local err = ok and response and response.error or 'database_error'
            if err ~= 'database_error' and err ~= 'payment_review' and err ~= 'pending_purchase' then ctx.pending = nil end
            X.notify(err,true)
        end
    end)
end
local function submenu(ctx, display)
    local def, rows = W.catalog[display.catalog], {}
    rows[#rows+1] = { id = 'buy',label = def.weapon and 'Waffe kaufen' or def.packSize and 'Magazin kaufen' or 'Gegenstand kaufen',
        rightLabel = ('$%d'):format(ctx.shop.prices[display.catalog]),description='W / A / S / D: begutachten · Loslassen: zurückfedern.' }
    if def.ammo then
        local options = {}
        local ammo=W.catalog[def.ammo]
        for i=1,Commerce.Config.maxBuy do options[i] = { label = ('%d Mag. · $%d'):format(i,i*ctx.shop.prices[def.ammo]), value = i } end
        rows[#rows+1] = { id = 'ammo',label = ammo.label,type = 'list',options = options,index = 1,
            description = ('%d Patronen pro Magazin / Stapel · $%d pro Magazin. Enter kauft die gewählte Anzahl Magazine.'):format(ammo.packSize,ctx.shop.prices[def.ammo]) }
    end
    for _, key in ipairs(def.components or {}) do
        rows[#rows+1] = { id = key,label = W.catalog[key].label,rightLabel = ('$%d'):format(ctx.shop.prices[key]),
            description = 'An der Waffe ansehen. Enter kauft das Zubehör als Item; im Inventar benutzen zum Montieren.' }
    end
    local handle = ctx.subs[display.id]
    if def.weapon then for _,row in ipairs(rows) do row.hint=inspectHint end end
    if not handle then
        handle = X.menu('ammu_detail_'..display.id,'AMMU-NATION',def.label,rows,{
            onHighlight = function(id)
                if current == ctx then X.focus(display,true,W.catalog[id] and W.catalog[id].component) end
            end,
            onSelect = function(id,item)
                if id == 'buy' then buy(ctx,display.catalog,1)
                elseif id == 'ammo' then buy(ctx,def.ammo,item.options[item.index].value)
                elseif W.catalog[id] then buy(ctx,id,1) end
            end,
            onClose = function(reason)
                if current == ctx and reason == 'back' then X.focus(display,false) end
            end,
        })
        if not handle then return end
        ctx.subs[display.id] = handle ctx.handles[#ctx.handles+1] = handle
    end
    if exports.rp_nativeui:rpPushMenu(handle) then
        local state = exports.rp_nativeui:rpGetMenuState(handle)
        local selected = state and state.definition.items[state.selected]
        X.focus(display,true,selected and W.catalog[selected.id] and W.catalog[selected.id].component)
    end
end
function X.openShop(shop, data, test, onEnd)
    if current or not shop or not shop.displays or #shop.displays == 0 then X.notify('Der Laden hat noch keine Auslage.',true) return false end
    local ctx = { shop = shop,data = data,test = test,account = 'money',handles = {},subs = {} }
    current = ctx
    local rows, displays = {}, {}
    for _, d in ipairs(shop.displays) do
        displays[d.id] = d
        rows[#rows+1] = { id = d.id,label = W.catalog[d.catalog].label,rightLabel = ('$%d'):format(shop.prices[d.catalog]),
            hint = W.catalog[d.catalog].weapon and inspectHint or nil,
            description = 'W / A / S / D: begutachten · Enter: näher ansehen, Munition und Zubehör.' }
    end
    rows[#rows+1] = { id = 'payment',label = 'Bezahlen mit',type = 'list',index = 1,
        options = { { label = 'Bargeld',value = 'money' },{ label = 'Bank',value = 'bank' } } }
    if not test then rows[#rows+1] = { id = 'recover',label = 'Offene Bestellung fortsetzen',description = 'Bestätigt bezahlte Ware ohne zweite Abbuchung zustellen.' } end
    local handle = X.menu('ammu_browse','AMMU-NATION',shop.label,rows,{
        onHighlight = function(id) if current == ctx then X.focus(displays[id],false) end end,
        onChange = function(id,value) if id == 'payment' then ctx.account = value end end,
        onSelect = function(id) if displays[id] then submenu(ctx,displays[id]) elseif id == 'recover' then buy(ctx,nil,nil,true) end end,
        onClose = function() if current == ctx then X.closeShop(false) end end,
    })
    if handle then ctx.handles[#ctx.handles+1] = handle end
    if not handle or not X.beginScene(shop,function()
        if current == ctx then X.closeShop(true) end
        if onEnd then onEnd() end
    end) or current ~= ctx or not exports.rp_nativeui:rpOpenMenu(handle) then
        X.closeShop(true) return false
    end
    return true
end
AddEventHandler('esx:onPlayerLogout',function() X.closeShop(true) end)
AddEventHandler('onResourceStop',function(resource)
    if resource == GetCurrentResourceName() or resource == 'rp_ui' or resource == 'rp_nativeui' then X.closeShop(true) end
end)
