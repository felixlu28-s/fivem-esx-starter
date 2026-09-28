-- One persistence/editor boundary for ordinary shops and Ammu-Nation.
local C = Commerce
C.shopEditors = {}
function C.catalogViewValid(view, venue)
    local editor = venue.editorKind and C.shopEditors[venue.editorKind]
    return not editor or (editor.ready() and not editor.editing[venue.shopId] and view.venueRevision == venue.revision)
end
function C.registerShopEditor(spec)
    -- Names are code constants, never network payloads.
    assert(spec.tableName:match('^rp_commerce_[a-z]+$'))
    local W = spec.schema
    local shops, editors, editing = {}, {}, {}
    local ready = false
    local groups = { admin = true, superadmin = true, owner = true }
    local function admin(source)
        local player = C.player(source)
        return player and groups[player.getGroup()] and GetEntityHealth(GetPlayerPed(source)) > 0 and player
    end
    local function current(source, token)
        local p, e = admin(source), editors[source]
        return p and e and e.token == token and e.actor == p.identifier and e.epoch == C.epochs[source]
            and e.expires > os.time() and e or nil
    end

    local function install(id, shop, revision)
        shop.id, shop.revision = id, revision
        shops[id] = shop
        spec.install(id, shop, revision)
        local venue=C.Config.venues[spec.venue(id)]
        venue.editorKind,venue.shopId,venue.revision=spec.channel,id,revision
    end
    local function changed(id)
        for source, view in pairs(C.views) do
            if view.venue == spec.venue(id) then C.views[source] = nil TriggerClientEvent('rp_commerce:hide', source) end
        end
        TriggerClientEvent(spec.changedEvent, -1)
    end
    C.ESX.RegisterCommand(spec.command, { 'admin', 'superadmin', 'owner' }, function(player)
        if player and admin(player.source) then TriggerClientEvent(spec.channel, player.source) end
    end, false, { help = spec.help, validate = true, arguments = {} })
    lib.callback.register(spec.channel..'Open', function(source)
        local p = admin(source)
        if not ready or not p or not C.rate(source, spec.channel..'Open', 1000) then return { ok = false, error = 'forbidden_or_not_ready' } end
        if editors[source] and editors[source].busy then return { ok = false, error = 'busy' } end
        C.epochs[source] = C.epochs[source] or {}
        local e = { token = C.token(), actor = p.identifier, epoch = C.epochs[source], expires = os.time() + 1800 }
        editors[source] = e
        local result = {} for _, shop in pairs(shops) do result[#result+1] = W.copy(shop) end
        table.sort(result, function(a,b) return a.label < b.label end)
        return { ok = true, token = e.token, shops = result, bucket = GetPlayerRoutingBucket(source), catalog = spec.catalog and spec.catalog() or nil }
    end)
    lib.callback.register(spec.channel..'Save', function(source, token, id, revision, raw, remove)
        local editor = current(source, token)
        if not ready or not editor then return { ok = false, error = 'forbidden' } end
        if editor.busy or not C.rate(source, spec.channel..'Save', 1000) then return { ok = false, error = 'busy' } end
        if type(remove) ~= 'boolean' or (id ~= false and (type(id) ~= 'string' or #id > 48)) then return { ok = false, error = 'invalid_request' } end
        local old = id and shops[id]
        if id and (not old or old.revision ~= revision or editing[id]) then return { ok = false, error = 'revision_conflict' } end
        if not id and remove then return { ok = false, error = 'invalid_request' } end
        local count = 0 for _ in pairs(shops) do count = count+1 end
        for key in pairs(editing) do if not shops[key] then count = count+1 end end
        if not id and count >= W.maxShops then return { ok = false, error = 'shop_limit' } end
        local p, bucket = GetEntityCoords(GetPlayerPed(source)), GetPlayerRoutingBucket(source)
        if old and (old.coords.bucket ~= bucket or W.distance(old.coords, p) > 75) then return { ok = false, error = 'out_of_range' } end
        local shop, err
        if not remove then
            shop, err = W.validate(raw)
            if not shop then return { ok = false, error = err } end
            if shop.coords.bucket ~= bucket or W.distance(shop.coords, p) > (old and 75 or 10) then return { ok = false, error = 'out_of_range' } end
            if spec.checkCatalog and not spec.checkCatalog() then return { ok = false, error = 'catalog_unavailable' } end
        end
        if id then
            for _, view in pairs(C.views) do
                if view.venue == spec.venue(id) and C.busy[view.actor] then return { ok = false, error = 'purchase_in_progress' } end
            end
        end
        -- One creation per capability: a lost network response cannot mint another shop on retry.
        id = id or editor.token
        editor.busy, editing[id] = true, true
        local ran, saved, saveError = pcall(function()
            if not current(source, token) then return false end
            if remove then
                local pending = MySQL.scalar.await("SELECT COUNT(*) FROM rp_commerce_orders WHERE status IN ('intent', 'paid') AND JSON_UNQUOTE(JSON_EXTRACT(payload, '$.venue')) = ?", { spec.venue(id) })
                if tonumber(pending) ~= 0 then return false, 'pending_orders' end
                if not current(source, token) then return false, 'forbidden' end
            end
            if old then
                return MySQL.update.await('UPDATE ' .. spec.tableName .. ' SET payload = ?, revision = revision + 1, deleted = ?, updated_by = ? WHERE id = ? AND revision = ? AND deleted = 0',
                    { json.encode(remove and old or shop), remove and 1 or 0, editor.actor, id, revision }) == 1
            end
            MySQL.insert.await('INSERT INTO ' .. spec.tableName .. ' (id, payload, updated_by) VALUES (?, ?, ?)', { id, json.encode(shop), editor.actor })
            return true
        end)
        if not ran then
            -- A SQL acknowledgement can be lost after commit. Reload authority before any retry;
            -- otherwise an already committed creation could be duplicated by a second request.
            local read, row = pcall(MySQL.single.await, 'SELECT id, revision, payload, deleted FROM ' .. spec.tableName .. ' WHERE id = ?', { id })
            if read and row then
                editor.busy, editing[id] = false, nil
                if row.deleted == 1 then shops[id] = nil spec.uninstall(id)
                else
                    local decoded, value = pcall(json.decode, row.payload)
                    local validated = decoded and W.validate(value)
                    if not validated then
                        ready=false editors[source]=nil
                        return {ok=false,error='database_error'}
                    end
                    install(id, validated, row.revision)
                end
                changed(id)
                -- Return the committed row only when its revision is this operation's next revision.
                if row.revision == (old and revision + 1 or 1) then
                    if not old then editor.token = C.token() end
                    return { ok = true, token = editor.token, shop = row.deleted ~= 1 and W.copy(shops[id]) or nil }
                end
            end
            -- Keep this editor capability blocked until it is reopened from the durable catalogue.
            editors[source] = nil
            if not read then ready=false end -- uncertain authority: fail closed until resource reload
            editing[id], editor.busy = nil, false
            return { ok = false, error = 'database_error' }
        end
        editor.busy, editing[id] = false, nil
        if not saved then return { ok = false, error = saveError or 'revision_conflict' } end
        if remove then shops[id] = nil spec.uninstall(id)
        else install(id, shop, old and revision + 1 or 1) end
        changed(id)
        if not old then editor.token = C.token() end
        print(('[rp_commerce] shop %s id=%s admin=%d revision=%d'):format(remove and 'deleted' or 'saved', id, source, old and revision+1 or 1))
        return { ok = true, token = editor.token, shop = not remove and W.copy(shops[id]) or nil }
    end)
    local function clean(source) editors[source] = nil end
    AddEventHandler('playerDropped', function() clean(source) end)
    AddEventHandler('esx:playerLogout', clean)
    AddEventHandler('rp_inventory:loaded', clean)
    MySQL.ready(function()
        local ok, err = pcall(function()
            if spec.seed then spec.seed() end
            local rows = MySQL.query.await('SELECT id, revision, payload, deleted FROM ' .. spec.tableName .. ' ORDER BY id')
            local activeCount=0
            local validated = {}
            for _, row in ipairs(rows) do
                if row.deleted == 1 then spec.uninstall(row.id) else
                activeCount=activeCount+1 assert(activeCount<=W.maxShops, 'Too many shops')
                local shop, reason = W.validate(json.decode(row.payload))
                assert(shop, ('Invalid shop %s: %s'):format(row.id, tostring(reason)))
                assert(not spec.checkCatalog or spec.checkCatalog(), 'Inventory catalogue unavailable')
                validated[#validated+1] = { id = row.id, shop = shop, revision = row.revision }
                end
            end
            for _, row in ipairs(validated) do install(row.id, row.shop, row.revision) end
            ready = true
            print(('[rp_commerce] %s: %d shops ready.'):format(spec.command,activeCount))
        end)
        if not ok then print('[rp_commerce] '..spec.command..' unavailable; apply migrations: '..tostring(err)) end
    end)

    local api={shops=shops,editing=editing,ready=function() return ready end}
    C.shopEditors[spec.channel]=api
    return api
end
