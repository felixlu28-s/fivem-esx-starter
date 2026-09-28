local W, X = Commerce.Weapons, Commerce.Weapons.client
local editor, opening, serial, generation = nil, false, 0, 0
local root, edit, displays, displayPage, npcPage, prices, transformPage
local function alive(ctx) return editor == ctx and not IsEntityDead(PlayerPedId()) end
local function position()
    local p = GetEntityCoords(PlayerPedId())
    return { x=p.x,y=p.y,z=p.z }
end
local function options(values)
    local result = {} for i,v in ipairs(values) do result[i] = { label = tostring(v),value = tostring(v) } end return result
end
local function stop()
    generation = generation + 1
    local ctx = editor
    if not ctx then return end
    editor = nil ctx.suspended = true
    if ctx.keyboard then CancelOnscreenKeyboard() end
    X.closeShop(true)
    pcall(function() exports.rp_nativeui:rpCloseMenu() end)
    for _,page in pairs(ctx.pages) do pcall(function() exports.rp_nativeui:rpDestroyMenu(page.handle) end) end
    X.setDraft(nil) X.dev, X.state = false, 'Closed'
    pcall(function() exports.rp_ui:rpHideInteraction() end)
end
local function page(ctx, key, subtitle, rows, select, change, back)
    if not alive(ctx) then return end
    local entry = ctx.pages[key]
    if not entry then
        entry = {} ctx.pages[key] = entry
        entry.handle = X.menu((ctx.normal and 'shop_editor_' or 'ammu_editor_')..key,ctx.normal and 'LADENVERWALTUNG' or 'AMMU-NATION',subtitle,rows,{
            onSelect = function(id,item) if alive(ctx) and not ctx.busy and entry.select then entry.select(id,item) end end,
            onChange = function(id,value,index) if alive(ctx) and not ctx.busy and entry.change then return entry.change(id,value,index) end return false end,
            onClose = function(reason)
                if not alive(ctx) or ctx.suspended then return end
                if reason == 'back' then
                    table.remove(ctx.path)
                    if entry.back then entry.back() end
                    if #ctx.path == 0 then stop() end
                else stop() end
            end,
        })
        if not entry.handle then return stop() end
    else exports.rp_nativeui:rpUpdateMenu(entry.handle,{ subtitle = subtitle,items = rows }) end
    entry.select, entry.change, entry.back = select, change, back
    if ctx.path[#ctx.path] ~= key then
        local opened = #ctx.path == 0 and exports.rp_nativeui:rpOpenMenu(entry.handle) or exports.rp_nativeui:rpPushMenu(entry.handle)
        if opened then ctx.path[#ctx.path+1] = key else X.notify('Dieses Menü ist gerade nicht verfügbar.',true) end
    end
end
local function suspend(ctx)
    ctx.suspended = true
    exports.rp_nativeui:rpCloseMenu()
end
local function resume(ctx)
    if not alive(ctx) then return end
    ctx.suspended = false
    for index,key in ipairs(ctx.path) do
        local handle = ctx.pages[key].handle
        if index == 1 then exports.rp_nativeui:rpOpenMenu(handle) else exports.rp_nativeui:rpPushMenu(handle) end
    end
end
local function input(ctx, label, initial, limit, accept)
    if ctx.busy then return end
    ctx.busy = true
    CreateThread(function()
        suspend(ctx) ctx.keyboard = true
        AddTextEntry('RP_AMMU_INPUT',label)
        DisplayOnscreenKeyboard(1,'RP_AMMU_INPUT','',''..initial,'','','',limit)
        while alive(ctx) and UpdateOnscreenKeyboard() == 0 do DisableAllControlActions(0) Wait(0) end
        local result = alive(ctx) and UpdateOnscreenKeyboard() == 1 and GetOnscreenKeyboardResult() or nil
        ctx.keyboard, ctx.busy = false, false
        if not alive(ctx) then return end
        resume(ctx)
        if result and result ~= '' then accept(result) X.refreshDraft() end
    end)
end
local function numeric(ctx,label,value,low,high,accept)
    input(ctx,label,value,18,function(raw)
        local number = tonumber((raw:gsub(',','.')))
        if not W.finite(number,math.max(math.abs(low),math.abs(high))) or number < low or number > high then
            return X.notify(('Wert zwischen %s und %s eingeben.'):format(low,high),true)
        end
        accept(number)
    end)
end
local function save(ctx, remove)
    if ctx.busy then return end
    ctx.busy = true
    local draft = W.copy(ctx.shop)
    CreateThread(function()
        local ok,result = pcall(lib.callback.await,ctx.normal and 'rp_commerce:shopEditorSave' or 'rp_commerce:weaponEditorSave',false,ctx.token,
            draft.id or false,draft.revision or 0,draft,remove == true)
        ctx.busy = false
        if not alive(ctx) then return end
        if not ok or not result or not result.ok then return X.notify(ok and result and result.error or 'database_error',true) end
        ctx.token = result.token or ctx.token
        if remove then
            X.notify('Laden gelöscht. Gespeicherte Daten bleiben als Archiv erhalten.')
            stop()
        else
            ctx.shop = result.shop X.setDraft(ctx.shop)
            local replaced = false
            for i,shop in ipairs(ctx.shops) do if shop.id == result.shop.id then ctx.shops[i] = result.shop replaced = true end end
            if not replaced then ctx.shops[#ctx.shops+1] = result.shop end
            X.notify('Laden gespeichert.') edit(ctx)
        end
        CreateThread(function() Wait(1600) if ctx.normal then Commerce.Shops.client.refresh() else X.refresh() end end)
    end)
end
local function placement(ctx,target,npc,done)
    if ctx.busy then return end
    ctx.busy, ctx.acceptPlacement = true, false
    local previous = W.copy(target)
    CreateThread(function()
        suspend(ctx)
        local hitPosition, hitNormal, ray, requested, lastHint = nil,nil,nil,0,0
        while alive(ctx) do
            local now = GetGameTimer()
            DisablePlayerFiring(PlayerId(),true)
            DisableControlAction(0,24,true) DisableControlAction(0,25,true)
            DrawRect(0.5,0.5,0.008,0.0015,195,225,199,230)
            DrawRect(0.5,0.5,0.001,0.014,195,225,199,230)
            if not ray and now-requested > 40 then
                local p,r = GetGameplayCamCoord(),GetGameplayCamRot(2)
                local yaw,pitch = math.rad(r.z),math.rad(r.x)
                ray = StartShapeTestRay(p.x,p.y,p.z,p.x-math.sin(yaw)*math.cos(pitch)*15,
                    p.y+math.cos(yaw)*math.cos(pitch)*15,p.z+math.sin(pitch)*15,17,PlayerPedId(),7)
                requested = now
            end
            if ray then
                local state,hit,p,normal = GetShapeTestResult(ray)
                if state == 2 then
                    hitPosition, hitNormal = nil,nil
                    if hit == 1 and W.distance(p,ctx.shop.coords) < 25 and (not npc or normal.z > 0.5) then
                        hitPosition,hitNormal = p,normal
                        target.pos = { x=p.x+normal.x*0.025,y=p.y+normal.y*0.025,z=p.z+normal.z*0.025 }
                        if not npc and target.type == 'wall' and math.abs(normal.z) < 0.8 then
                            target.heading = math.deg(math.atan(-normal.x,normal.y))
                        elseif npc then target.heading = GetEntityHeading(PlayerPedId()) end
                        X.refreshDraft()
                    end
                    ray = nil
                elseif state == 0 then ray = nil end
            end
            if now-lastHint > 180 then
                exports.rp_ui:rpShowInteraction({ action='rp_commerce:interact',label=hitPosition and 'Position übernehmen' or 'Oberfläche anvisieren',
                    verb='Zurück: Backspace · danach im Menü fein justieren',icon='shop',distance=0 })
                lastHint = now
            end
            if ctx.acceptPlacement and hitPosition and hitNormal then break end
            ctx.acceptPlacement = false
            if IsControlJustPressed(0,177) or IsDisabledControlJustPressed(0,177) or IsPauseMenuActive() then
                for k,v in pairs(previous) do target[k] = v end
                X.refreshDraft() break
            end
            Wait(0)
        end
        ctx.busy,ctx.acceptPlacement = false,false
        exports.rp_ui:rpHideInteraction()
        if alive(ctx) then resume(ctx) if done then done() end end
    end)
end
AddEventHandler('rp_core:inputPressed',function(action)
    if action == 'rp_commerce:interact' and editor and editor.suspended and editor.busy and not editor.keyboard then editor.acceptPlacement = true end
end)
transformPage = function(ctx,target,npc)
    local step = ctx.step or 0.01
    local function axisRow(id,label,value)
        return { id=id,label=label,type='list',index=2,options={
            {label='− '..step,value=-1},{label=('%.3f'):format(value),value=0},{label='+ '..step,value=1} },
            description='Links/rechts: Schritt ändern. Enter: exakten Wert eingeben. Position in Metern, Rotation in Grad.' }
    end
    local rows = {{id='step',label='Schrittweite',type='list',index=ctx.stepIndex or 1,options=options({0.01,0.05,0.1,0.5,1,5,15})}}
    for _,axis in ipairs({'x','y','z'}) do rows[#rows+1] = axisRow('pos_'..axis,'Position '..axis:upper(),target.pos[axis]) end
    if not npc then
        for _,axis in ipairs({'x','y','z'}) do rows[#rows+1] = axisRow('rot_'..axis,'Rotation '..axis:upper(),target.rot[axis]) end
        rows[#rows+1] = axisRow('scale','Kameraabstand ×',target.scale)
        rows[#rows+1] = axisRow('height','Kamerahöhe',target.height)
    end
    if npc~='point' then rows[#rows+1] = axisRow('heading',npc and 'Blickrichtung' or 'Kamera / Präsentationsrichtung',target.heading) end
    local function field(id)
        local kind,axis = id:match('^(%w+)_(%w)$')
        if kind == 'pos' then return target.pos,axis,-20000,20000 end
        if kind == 'rot' then return target.rot,axis,-360,360 end
        if id == 'heading' then return target,id,-360,360 end
        if id == 'scale' then return target,id,0.5,2 end
        if id == 'height' then return target,id,-1,1 end
    end
    page(ctx,'transform','FEINJUSTIERUNG',rows,function(id)
        local object,key,low,high = field(id)
        if object then numeric(ctx,id,object[key],low,high,function(v) object[key]=v transformPage(ctx,target,npc) end) end
    end,function(id,value,index)
        if id == 'step' then ctx.step,ctx.stepIndex=tonumber(value),index else
            local object,key,low,high = field(id)
            if object then object[key]=math.max(low,math.min(high,object[key]+value*step)) end
        end
        X.refreshDraft() transformPage(ctx,target,npc)
    end)
end
local function placeClerkHere(ctx, npc)
    ctx.busy = true
    W.clerkClient.playerFloor(function() return alive(ctx) and (not npc or ctx.shop.npc == npc) end, function(p)
        ctx.busy = false
        if not p then X.notify('Kein sicherer Boden gefunden. Bitte eine Oberfläche anvisieren.', true) npcPage(ctx) return end
        -- Optional manual default (normally zero) is baked in once. Runtime
        -- placement aligns the soles and never adds this correction again.
        p.z = p.z + W.clerk.initialHeightOffset
        if npc then npc.pos = p npc.heading = GetEntityHeading(PlayerPedId())
        else ctx.shop.npc = {pos=p,heading=GetEntityHeading(PlayerPedId()),model=(ctx.normal and Commerce.Shops or W).clerkModels[1],scenario=(ctx.normal and Commerce.Shops or W).scenarios[1]} end
        X.refreshDraft() npcPage(ctx)
    end)
end
npcPage = function(ctx)
    local schema=ctx.normal and Commerce.Shops or W
    local npc = ctx.shop.npc
    local rows = {{id='enabled',label='Verkäufer vorhanden',type='checkbox',checked=npc ~= false}}
    if npc then
        local mi,si=1,1
        for i,v in ipairs(schema.clerkModels) do if v==npc.model then mi=i end end
        for i,v in ipairs(schema.scenarios) do if v==npc.scenario then si=i end end
        rows[#rows+1]={id='model',label='Modell',type='list',options=options(schema.clerkModels),index=mi}
        local poses=options(schema.scenarios)
        if ctx.normal then
            poses[1].label='Entspannt stehen' poses[2].label='Klemmbrett' poses[3].label='Wachsam stehen'
        else
        poses[1].label='Ammu-Nation · Arme verschränkt'
        poses[2].label='Ammu-Nation · Standard (Bestand)'
        poses[3].label='Klemmbrett'
        end
        rows[#rows+1]={id='scenario',label='Haltung',type='list',options=poses,index=si}
        rows[#rows+1]={id='here',label='An meine Position stellen'}
        rows[#rows+1]={id='ray',label='Oberfläche anvisieren'}
        rows[#rows+1]={id='transform',label='Position / Drehung fein justieren'}
    end
    page(ctx,'npc','VERKÄUFER',rows,function(id)
        if not npc then return end
        if id=='here' then placeClerkHere(ctx,npc)
        elseif id=='ray' then placement(ctx,npc,true)
        elseif id=='transform' then transformPage(ctx,npc,true) end
    end,function(id,value)
        if id=='enabled' then
            if value then
                placeClerkHere(ctx,nil) return
            else ctx.shop.npc=false end
        elseif npc then npc[id]=value end
        X.refreshDraft() npcPage(ctx)
    end)
end
local function preview(ctx)
    if ctx.busy then return end
    ctx.busy = true
    CreateThread(function()
        if not alive(ctx) then return end
        suspend(ctx)
        local opened = X.openShop(ctx.shop,nil,true,function() if alive(ctx) then resume(ctx) end end)
        ctx.busy = false
        if not opened then resume(ctx) end
    end)
end
displayPage = function(ctx,d)
    local rows={
        {id='type',label='Präsentation',type='list',options={{label='Wand',value='wall'},{label='Theke',value='counter'}},index=d.type=='wall' and 1 or 2},
        {id='ray',label='An Oberfläche platzieren',description='Mit der Kamera anvisieren; Interaktionstaste übernimmt, Backspace verwirft.'},
        {id='here',label='Vor mir platzieren'},
        {id='transform',label='Position / Rotation / Kamera'},
        {id='preview',label='Shop & Kamera testen'},
        {id='duplicate',label='Duplizieren'},
        {id='remove',label='Diese Auslage entfernen',description='Änderung wird erst mit „Laden speichern“ veröffentlicht.'},
    }
    page(ctx,'display',W.catalog[d.catalog].label,rows,function(id)
        if id=='ray' then placement(ctx,d,false)
        elseif id=='here' then local p=GetOffsetFromEntityInWorldCoords(PlayerPedId(),0,1,0) d.pos={x=p.x,y=p.y,z=p.z} X.refreshDraft()
        elseif id=='transform' then transformPage(ctx,d,false)
        elseif id=='preview' then preview(ctx)
        elseif id=='duplicate' then
            if #ctx.shop.displays>=W.maxDisplays then return X.notify('Maximal '..W.maxDisplays..' Auslagen.',true) end
            serial=serial+1 local copy=W.copy(d) copy.id=('display_%x_%d'):format(GetGameTimer(),serial) copy.pos.x=copy.pos.x+0.25
            ctx.shop.displays[#ctx.shop.displays+1]=copy X.refreshDraft() X.notify('Duplikat angelegt. Unter „Auslagen“ auswählbar.')
        elseif id=='remove' then
            for i,item in ipairs(ctx.shop.displays) do if item==d then table.remove(ctx.shop.displays,i) break end end
            X.refreshDraft()
            -- Rebuild the menu path without stale callbacks referencing the removed display.
            suspend(ctx) ctx.path={'root','edit'} resume(ctx) displays(ctx)
        end
    end,function(id,value) if id=='type' then d.type=value end X.refreshDraft() end,function() displays(ctx) end)
end
displays = function(ctx)
    local rows={{id='add',label='Neue Waffe / neues Item platzieren',rightLabel=('%d / %d'):format(#ctx.shop.displays,W.maxDisplays)}}
    for i,d in ipairs(ctx.shop.displays) do rows[#rows+1]={id='entry_'..i,label=W.catalog[d.catalog].label,rightLabel=d.type=='wall' and 'Wand' or 'Theke'} end
    page(ctx,'displays','AUSLAGEN',rows,function(id)
        if id=='add' then
            if #ctx.shop.displays>=W.maxDisplays then return X.notify('Auslagenlimit erreicht.',true) end
            local catalog={} for key,def in pairs(W.catalog) do catalog[#catalog+1]={id=key,label=def.label} end
            table.sort(catalog,function(a,b) return a.label<b.label end)
            page(ctx,'catalog','WARE AUSWÄHLEN',catalog,function(key)
                page(ctx,'type','WAND ODER THEKE',{{id='wall',label='An der Wand'},{id='counter',label='Auf der Theke'}},function(kind)
                    serial=serial+1
                    local d={id=('display_%x_%d'):format(GetGameTimer(),serial),catalog=key,type=kind,pos=position(),
                        rot={x=kind=='counter' and 90 or 0,y=0,z=GetEntityHeading(PlayerPedId())},heading=GetEntityHeading(PlayerPedId())+180,scale=1,height=0}
                    if d.heading>360 then d.heading=d.heading-360 end
                    ctx.shop.displays[#ctx.shop.displays+1]=d X.refreshDraft()
                    suspend(ctx) ctx.path={'root','edit','displays'} resume(ctx) displayPage(ctx,d)
                    placement(ctx,d,false)
                end)
            end)
        else local index=tonumber(id:match('^entry_(%d+)$')) if index and ctx.shop.displays[index] then displayPage(ctx,ctx.shop.displays[index]) end end
    end)
end
prices = function(ctx)
    local rows={}
    for key,def in pairs(W.catalog) do rows[#rows+1]={id=key,label=def.label,
        rightLabel=('$%d%s'):format(ctx.shop.prices[key],def.packSize and ' / Mag.' or ''),
        description=def.packSize and ('Ein Magazin enthält %d Patronen.'):format(def.packSize) or 'Preis pro Stück.'} end
    table.sort(rows,function(a,b) return a.label<b.label end)
    page(ctx,'prices','PREISE · STÜCK / MAGAZIN',rows,function(id)
        numeric(ctx,W.catalog[id].packSize and 'Preis pro Magazin (ganze Dollar)' or 'Preis (ganze Dollar)',ctx.shop.prices[id],1,1000000,function(v)
            if v%1~=0 then return X.notify('Bitte einen ganzen Dollarbetrag eingeben.',true) end
            ctx.shop.prices[id]=v prices(ctx)
        end)
    end)
end
edit = function(ctx)
    if ctx.normal then return Commerce.Shops.editor.edit(ctx) end
    local rows={
        {id='label',label='Name',rightLabel=ctx.shop.label},
        {id='interaction',label='Interaktionspunkt hier setzen',description='Deine aktuelle Position wird beim Speichern zum Interaktionspunkt und Blip.'},
        {id='license',label='ESX-Waffenlizenz erforderlich',type='checkbox',checked=ctx.shop.license,
            description='Prüft esx_license:checkLicense (weapon). Fehlende Lizenz-Resource sperrt den Kauf.'},
        {id='npc',label='Verkäufer'}, {id='displays',label='Waffen & Items'}, {id='prices',label='Preise'},
        {id='preview',label='Shop & Kamera testen',description='Lokaler Test ohne Käufe. Backspace kehrt in den Editor zurück.'},
        {id='save',label='Laden speichern',description='Änderungen dauerhaft speichern und für alle Spieler veröffentlichen.'},
        {id='delete',label='Laden löschen',disabled=not ctx.shop.id},
    }
    page(ctx,'edit','DEV · '..ctx.shop.label,rows,function(id)
        if id=='label' then input(ctx,'Shopname',ctx.shop.label,60,function(v) ctx.shop.label=v edit(ctx) end)
        elseif id=='interaction' then local p=position() p.bucket=ctx.bucket ctx.shop.coords=p X.notify('Interaktionspunkt gesetzt. Speichern nicht vergessen.')
        elseif id=='npc' then npcPage(ctx)
        elseif id=='displays' then displays(ctx)
        elseif id=='prices' then prices(ctx)
        elseif id=='preview' then preview(ctx)
        elseif id=='save' then save(ctx,false)
        elseif id=='delete' then page(ctx,'delete','LADEN WIRKLICH LÖSCHEN?',{{id='confirm',label='Ja, Laden entfernen',description='Entfernt NPC, Auslagen, Blip und Kaufzugriff. Backspace bricht ab.'}},function() save(ctx,true) end) end
    end,function(id,value) if id=='license' then ctx.shop.license=value end end,function()
        X.setDraft(nil) ctx.shop=nil X.notify('Editor verlassen. Nur ausdrücklich gespeicherte Änderungen bleiben erhalten.')
        root(ctx)
    end)
end
root = function(ctx)
    local rows={{id='create',label='Neuen Laden hier erstellen'}}
    for i,shop in ipairs(ctx.shops) do rows[#rows+1]={id='shop_'..i,label=shop.label,rightLabel=('%.0f m'):format(W.distance(position(),shop.coords))} end
    page(ctx,'root','DEV · LADENVERWALTUNG',rows,function(id)
        if id=='create' then
            local p=position() p.bucket=ctx.bucket ctx.shop=(ctx.normal and Commerce.Shops or W).newShop(p)
        else
            local index=tonumber(id:match('^shop_(%d+)$')) local shop=index and ctx.shops[index]
            if not shop then return end
            if shop.coords.bucket~=ctx.bucket or W.distance(position(),shop.coords)>75 then
                SetNewWaypoint(shop.coords.x,shop.coords.y)
                return X.notify('Wegpunkt gesetzt. Zum Bearbeiten bitte zum Laden gehen (gleiche Instanz, maximal 75 m).',true)
            end
            ctx.shop=W.copy(shop)
        end
        X.setDraft(ctx.shop) edit(ctx)
    end)
end
local function openEditor(normal)
    if source~=65535 then return end
    if editor then stop() return end
    if opening or IsNuiFocused() then return end
    opening=true
    local epoch = generation
    local ok,result=pcall(lib.callback.await,normal and 'rp_commerce:shopEditorOpen' or 'rp_commerce:weaponEditorOpen',false)
    opening=false
    if epoch ~= generation then return end
    if not ok or not result or not result.ok then return X.notify(ok and result and result.error or 'Editor nicht verfügbar.',true) end
    if IsNuiFocused() or IsEntityDead(PlayerPedId()) or not exports.es_extended:getSharedObject().IsPlayerLoaded() then return end
    editor={token=result.token,shops=result.shops,bucket=result.bucket,pages={},path={},normal=normal,catalog=result.catalog or {}}
    X.dev,X.state=true,'DevMode'
    root(editor)
end
RegisterNetEvent('rp_commerce:weaponEditor',function() openEditor(false) end)
RegisterNetEvent('rp_commerce:shopEditor',function() openEditor(true) end)
CreateThread(function()
    while true do
        if editor and (IsEntityDead(PlayerPedId()) or not exports.es_extended:getSharedObject().IsPlayerLoaded()) then stop() end
        Wait(300)
    end
end)
AddEventHandler('esx:onPlayerLogout',stop)
AddEventHandler('onResourceStop',function(resource)
    if resource==GetCurrentResourceName() or resource=='rp_ui' or resource=='rp_nativeui' or resource=='rp_core' then stop() end
end)

X.editorAPI={page=page,input=input,numeric=numeric,save=save,npc=npcPage,transform=transformPage,root=root,position=position,stop=stop,edit=edit,alive=alive,
    rewind=function(ctx,path) suspend(ctx) ctx.path=path resume(ctx) end}
