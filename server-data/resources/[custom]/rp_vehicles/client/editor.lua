local C,R,W,ui=Garage.Config,Garage.Rules,Garage.World,exports.rp_nativeui
local E={placing=false} Garage.Editor=E
local ctx,opening,generation=nil,false,0
local root,edit,pointPage,routePage,npcPage,gatePage
local function notify(message,bad) lib.notify({title='Garagenverwaltung',description=message,type=bad and 'error' or 'inform'}) end
local function alive(e) return ctx==e and not IsEntityDead(PlayerPedId()) end
local function refresh(e) if alive(e) and e.g then W.setDraft(e.g) end end
local function stop()
    generation=generation+1
    local e=ctx ctx=nil E.placing=false
    if not e then return end e.suspended=true
    TriggerServerEvent('rp_vehicles:editorClose',e.token)
    if e.keyboard then CancelOnscreenKeyboard() end
    ui:rpCloseMenu() for _,p in pairs(e.pages) do ui:rpDestroyMenu(p.handle) end
    W.setDraft(nil) exports.rp_ui:rpHideInteraction()
end
local function page(e,key,title,rows,select,change,back)
    if not alive(e) then return end
    local p=e.pages[key]
    if not p then
        p={} e.pages[key]=p
        p.handle=ui:rpCreateMenu('garage_dev_'..key,{title='GARAGEN',subtitle=title,theme='mint',visibleRows=8,items=rows},{
            onSelect=function(id,item) if alive(e) and not e.busy and p.select then p.select(id,item) end end,
            onChange=function(id,value,index) if alive(e) and not e.busy and p.change then return p.change(id,value,index) end return false end,
            onClose=function(reason)
                if not alive(e) or e.suspended then return end
                if reason=='back' then table.remove(e.path) if p.back then p.back() end if #e.path==0 then stop() end else stop() end
            end,
        })
        if not p.handle then stop() return end
    else ui:rpUpdateMenu(p.handle,{subtitle=title,items=rows}) end
    p.select,p.change,p.back=select,change,back
    if e.path[#e.path]~=key then
        local ok=#e.path==0 and ui:rpOpenMenu(p.handle) or ui:rpPushMenu(p.handle)
        if ok then e.path[#e.path+1]=key else stop() end
    end
end
local function suspend(e) e.suspended=true ui:rpCloseMenu() end
local function resume(e)
    if not alive(e) then return end e.suspended=false
    for i,key in ipairs(e.path) do if i==1 then ui:rpOpenMenu(e.pages[key].handle) else ui:rpPushMenu(e.pages[key].handle) end end
end
local function input(e,label,value,limit,accept)
    e.busy=true
    CreateThread(function()
        suspend(e) e.keyboard=true AddTextEntry('RP_GARAGE_INPUT',label)
        DisplayOnscreenKeyboard(1,'RP_GARAGE_INPUT','',tostring(value),'','','',limit)
        while alive(e) and UpdateOnscreenKeyboard()==0 do DisableAllControlActions(0) Wait(0) end
        local result=alive(e) and UpdateOnscreenKeyboard()==1 and GetOnscreenKeyboardResult()
        e.busy,e.keyboard=false,false if not alive(e) then return end resume(e)
        if result and result~='' then accept(result) refresh(e) end
    end)
end
local function number(e,label,value,low,high,accept,integer)
    input(e,label,value,18,function(raw)
        local n=tonumber((raw:gsub(',','.')))
        if not R.finite(n,low,high) or (integer and n%1~=0) then notify('Ungültiger Zahlenwert.',true) return end
        accept(integer and math.tointeger(n) or n)
    end)
end
local function position()
    local ped=PlayerPedId() local vehicle=GetVehiclePedIsIn(ped,false)
    local target=vehicle~=0 and vehicle or ped local p=GetEntityCoords(target)
    return {x=p.x,y=p.y,z=p.z,h=GetEntityHeading(target)}
end
local function here(e,target,floor,done)
    e.busy=true
    CreateThread(function()
        local p=floor and W.playerFloor(function() return alive(e) end) or not floor and position()
        e.busy=false if not alive(e) then return end
        if not p then notify('Kein sicherer Boden gefunden. Auf ebenen Boden stellen.',true) return end
        for k,v in pairs(p) do target[k]=v end refresh(e) if done then done() end
    end)
end
local function aim(e,target,door,done)
    e.busy=true E.placing=true e.accept=false
    CreateThread(function()
        suspend(e)
        local deadline,ray,last,hitPoint,hitEntity=GetGameTimer()+30000,nil,0,nil,nil
        while alive(e) and GetGameTimer()<deadline do
            DisablePlayerFiring(PlayerId(),true) DisableControlAction(0,24,true)
            DrawRect(0.5,0.5,0.008,0.0015,195,225,199,230)
            if not ray then
                local p,r=GetGameplayCamCoord(),GetGameplayCamRot(2) local yaw,pitch=math.rad(r.z),math.rad(r.x)
                ray=StartShapeTestRay(p.x,p.y,p.z,p.x-math.sin(yaw)*math.cos(pitch)*25,p.y+math.cos(yaw)*math.cos(pitch)*25,p.z+math.sin(pitch)*25,17,PlayerPedId(),7)
            end
            local state,hit,p,normal,entity=GetShapeTestResult(ray)
            if state==2 then
                hitPoint,hitEntity=nil,nil
                if (hit==1 or hit==true) and R.distance(p,e.g.interaction)<C.editor.radius
                    and (not door and normal.z>0.5 or door and entity~=0 and GetEntityType(entity)==3) then hitPoint,hitEntity=p,entity end
                ray=nil
            elseif state==0 then ray=nil end
            if GetGameTimer()-last>200 then
                exports.rp_ui:rpShowInteraction({action='rp_vehicles:garage',label=hitPoint and 'Position übernehmen' or (door and 'Torobjekt anvisieren' or 'Boden anvisieren'),verb='Backspace: Abbrechen',icon='shop',distance=0}) last=GetGameTimer()
            end
            if e.accept and hitPoint then
                local p=door and GetEntityCoords(hitEntity) or hitPoint
                target.x,target.y,target.z=p.x,p.y,p.z
                if door then target.model=GetEntityModel(hitEntity) else target.h=GetEntityHeading(PlayerPedId()) end
                refresh(e) break
            end
            e.accept=false
            if IsControlJustPressed(0,177) or IsDisabledControlJustPressed(0,177) or IsPauseMenuActive() then break end
            Wait(0)
        end
        e.busy=false E.placing=false exports.rp_ui:rpHideInteraction()
        if alive(e) then resume(e) if done then done() end end
    end)
end
pointPage=function(e,key,p,title,floor)
    local step=e.step or 0.05 local rows={{id='here',label='An meine Position setzen'},
        {id='surface',label='Boden anvisieren'},
        {id='step',label='Schrittweite',type='list',index=e.stepIndex or 2,options={{label='0,01',value=0.01},{label='0,05',value=0.05},{label='0,1',value=0.1},{label='0,5',value=0.5},{label='1',value=1},{label='5',value=5}}}}
    for _,axis in ipairs({'x','y','z','h'}) do
        if p[axis]~=nil then rows[#rows+1]={id=axis,label=axis=='h' and 'Blickrichtung' or axis:upper(),type='list',index=2,
            options={{label='−',value=-1},{label=('%.3f'):format(p[axis]),value=0},{label='+',value=1}},description='Links/rechts: fein justieren. Enter: exakten Wert eingeben.'} end
    end
    local function redraw() pointPage(e,key,p,title,floor) end
    page(e,'point_'..key,title,rows,function(id)
        if id=='here' then here(e,p,floor,redraw)
        elseif id=='surface' then aim(e,p,false,redraw)
        elseif p[id] then number(e,id,p[id],id=='h' and 0 or -10000,id=='h' and 360 or 10000,function(v) p[id]=v redraw() end) end
    end,function(id,value,index)
        if id=='step' then e.step,e.stepIndex=value,index
        elseif p[id] and value~=0 then p[id]=p[id]+value*(id=='h' and math.max(step,1) or step) if id=='h' then p[id]=p[id]%360 end refresh(e) end
        redraw()
    end)
end
routePage=function(e,key,title)
    local route=e.g[key] local rows={{id='add',label='Wegpunkt hier hinzufügen',disabled=#route>=C.editor.maxPoints,
        description='Punkte in Fahr-/Laufrichtung setzen. Der endgültige Zielplatz folgt automatisch.'}}
    for i,p in ipairs(route) do rows[#rows+1]={id='p_'..i,label=('Punkt %d'):format(i),rightLabel=('%.1f / %.1f'):format(p.x,p.y)} end
    page(e,'route_'..key,title,rows,function(id)
        if id=='add' then route[#route+1]=position() refresh(e) routePage(e,key,title) return end
        local index=tonumber(id:match('p_(%d+)')) local p=route[index] if not p then return end
        page(e,'route_item_'..key,'WEGPUNKT '..index,{{id='edit',label='Position fein justieren'},{id='duplicate',label='Duplizieren',disabled=#route>=C.editor.maxPoints},
            {id='up',label='In Reihenfolge nach vorne'},{id='down',label='In Reihenfolge nach hinten'},{id='delete',label='Wegpunkt löschen'}},function(action)
            if action=='edit' then pointPage(e,'waypoint',p,title,false) return end
            if action=='duplicate' then table.insert(route,index+1,R.copy(p))
            elseif action=='delete' then table.remove(route,index)
            else local target=index+(action=='up' and -1 or 1) if route[target] then route[index],route[target]=route[target],p end end
            refresh(e)
            -- Rebuild from the route level so stale waypoint references cannot be edited.
            e.suspended=true ui:rpCloseMenu() table.remove(e.path) resume(e) routePage(e,key,title)
        end,nil,function() routePage(e,key,title) end)
    end)
end
local function choices(values,current)
    local list,index={},1 for i,v in ipairs(values) do list[i]={label=v,value=v} if v==current then index=i end end return list,index
end
npcPage=function(e)
    local g=e.g local models,model=choices(C.editor.models,g.clerk.model) local _,driver=choices(C.editor.models,g.valetModel)
    local scenarios,scenario=choices(C.editor.scenarios,g.clerk.scenario)
    page(e,'npc','MITARBEITER',{{id='model',label='Empfangsmodell',type='list',options=models,index=model},
        {id='idle',label='Grundhaltung',type='list',options=scenarios,index=scenario},
        {id='clerk',label='Empfang: Position / Blickrichtung'},
        {id='driver',label='Fahrermodell',type='list',options=models,index=driver},
        {id='staffDoor',label='Verdeckter Personaleingang'}, {id='path',label='Laufweg bearbeiten'},
        {id='greet',label='Begrüßung / Reaktion testen'}},function(id)
            if id=='clerk' or id=='staffDoor' then pointPage(e,id,g[id],id=='clerk' and 'EMPFANG' or 'PERSONALEINGANG',true)
            elseif id=='path' then routePage(e,'staffPath','LAUFWEG: INNEN → AUSSEN')
            elseif id=='greet' then
                local i=W.instances[g.id or 'draft'] if i and i.ped then
                    exports.rp_core:rpConfigureNpc(i.ped,{paused=false}) W.react(g.id or 'draft','acknowledge')
                end
            end
        end,function(id,value)
            if id=='model' then g.clerk.model=value elseif id=='driver' then g.valetModel=value elseif id=='idle' then g.clerk.scenario=value end
            refresh(e) npcPage(e)
        end)
end
gatePage=function(e)
    local g=e.g local _,status=W.gateStatus(g.id or 'draft',W.testOpen==true)
    page(e,'gate','TOR & VORSCHAU',{{id='pick',label='Vorhandenes Tor anvisieren',description='Objekt und exakte Modellposition aus der Welt übernehmen.'},
        {id='model',label='Modell / Hash',rightLabel=tostring(g.gate.model)},
        {id='position',label='Torposition fein justieren'},
        {id='open',label='Tor öffnen / schließen',type='checkbox',checked=W.testOpen==true},
        {id='test',label='Torstatus prüfen',rightLabel=status or 'Bereit'}},function(id)
            if id=='pick' then aim(e,g.gate,true,function() gatePage(e) end)
            elseif id=='model' then input(e,'Tormodell oder GTA-Hash',g.gate.model,64,function(v) g.gate.model=tonumber(v) or v gatePage(e) end)
            elseif id=='position' then pointPage(e,'gate',g.gate,'TORPOSITION',false)
            elseif id=='test' then local ok,reason=W.gateStatus(g.id or 'draft',W.testOpen==true) notify(ok and 'Tor ist geladen und in der gewünschten Stellung.' or 'Torprüfung: '..tostring(reason),not ok) gatePage(e) end
        end,function(_,value) W.testOpen=value gatePage(e) end)
end
local errors={garage_has_vehicles='Dieser Garage sind noch Fahrzeuge zugeordnet. Erst umziehen lassen; die Garage wird nicht gelöscht.',
    garage_busy='Hier läuft ein Parkvorgang oder ein anderer Editor.',out_of_range='Bleibe in der Nähe dieser Garage.',
    revision_conflict='Die Garage wurde inzwischen geändert. Editor neu öffnen.',gate_in_use='Dieses Tor wird bereits von einer anderen Garage verwendet.'}
local function save(e,remove)
    e.busy=true local draft=R.copy(e.g)
    CreateThread(function()
        local ok,result=pcall(lib.callback.await,'rp_vehicles:editorSave',false,e.token,draft.id or false,draft.revision or 0,draft,remove)
        e.busy=false if not alive(e) then return end
        if not ok or not result or not result.ok then notify(errors[result and result.error] or ('Speichern fehlgeschlagen: '..tostring(ok and result and result.error or 'Verbindung')),true) return end
        e.token=result.token
        if remove then notify('Garage archiviert. Fahrzeugdaten bleiben erhalten.') stop()
        else
            e.g=result.garage local found=false
            for i,g in ipairs(e.garages) do if g.id==e.g.id then e.garages[i]=R.copy(e.g) found=true end end
            if not found then e.garages[#e.garages+1]=R.copy(e.g) end
            refresh(e) edit(e) notify('Garage gespeichert und veröffentlicht.')
        end
        W.refresh()
    end)
end
edit=function(e)
    local g=e.g
    page(e,'edit','DEV · '..g.label,{{id='name',label='Name',rightLabel=g.label},{id='npc',label='NPCs & Personaleingang'},
        {id='interaction',label='Interaktionspunkt'},{id='gate',label='Tor auswählen / testen'},
        {id='hidden',label='Verdeckter Fahrzeugplatz'},{id='parking',label='Übergabe-Parkplatz'},
        {id='outward',label='Fahrweg: Ausparken'},{id='inward',label='Fahrweg: Einparken'},
        {id='blip',label='Kartenmarkierung'},{id='save',label='Garage speichern'},
        {id='delete',label='Garage löschen',disabled=not g.id}},function(id)
            if id=='name' then input(e,'Garagenname',g.label,80,function(v) g.label=v edit(e) end)
            elseif id=='npc' then npcPage(e) elseif id=='gate' then gatePage(e)
            elseif id=='interaction' or id=='hidden' or id=='parking' then pointPage(e,id,g[id],id:upper(),false)
            elseif id=='outward' or id=='inward' then routePage(e,id,id=='outward' and 'AUSFAHRT' or 'EINFAHRT')
            elseif id=='save' then save(e,false)
            elseif id=='delete' then page(e,'delete','GARAGE WIRKLICH ENTFERNEN?',{{id='yes',label='Ja, Garage archivieren',description='Mit zugeordneten Fahrzeugen wird das Löschen abgewiesen.'}},function() save(e,true) end)
            elseif id=='blip' then
                local function blip()
                    local b=g.blip
                    local rows={{id='enabled',label='Kartenblip anzeigen',type='checkbox',checked=b~=false}}
                    if b then rows[#rows+1]={id='sprite',label='Symbol',rightLabel=tostring(b.sprite)} rows[#rows+1]={id='color',label='Farbe',rightLabel=tostring(b.color)} end
                    page(e,'blip','KARTENBLIP',rows,function(k) if b then number(e,k,b[k],k=='sprite' and 1 or 0,k=='sprite' and 1000 or 85,function(v) b[k]=v blip() end,true) end end,
                        function(_,value) g.blip=value and {sprite=357,color=2} or false refresh(e) blip() end)
                end blip()
            end
        end,nil,function()
            e.g=nil W.setDraft(nil) e.busy=true
            CreateThread(function() pcall(lib.callback.await,'rp_vehicles:editorSelect',false,e.token,false) e.busy=false if alive(e) then root(e) end end)
        end)
end
root=function(e)
    local rows={{id='new',label='Garage hier erstellen',description='Danach Tor, versteckten Spawn, Parkplatz und Wege einrichten.'}}
    for i,g in ipairs(e.garages) do rows[#rows+1]={id='g_'..i,label=g.label,rightLabel=('%d m'):format(math.floor(R.distance(position(),g.interaction)))} end
    page(e,'root','DEV · GARAGENVERWALTUNG',rows,function(id)
        local existing=e.garages[tonumber(id:match('g_(%d+)'))]
        e.busy=true
        CreateThread(function()
            local ok,result=pcall(lib.callback.await,'rp_vehicles:editorSelect',false,e.token,existing and existing.id or false)
            if not alive(e) then return end
            e.busy=false
            if not ok or not result or not result.ok then notify(errors[result and result.error] or 'Garage derzeit nicht bearbeitbar.',true) return end
            if existing then e.g=result.garage
            else
                local p=position() local floor=W.playerFloor(function() return alive(e) end)
                if not floor then notify('Bitte auf einen ebenen Boden stellen.',true) return end
                e.g={label='Neue Garage',bucket=e.bucket,clerk=R.copy(floor),interaction=R.copy(p),gate={model='prop_id2_11_gdoor',x=p.x,y=p.y,z=p.z},
                    hidden={x=p.x+10,y=p.y,z=p.z,h=p.h},parking=R.copy(p),staffDoor=R.copy(floor),staffPath={},outward={},inward={},valetModel=C.editor.models[1],blip={sprite=357,color=2}}
                e.g.clerk.model=C.editor.models[1] e.g.clerk.scenario=C.editor.scenarios[1]
            end
            refresh(e) edit(e)
        end)
    end)
end
RegisterNetEvent('rp_vehicles:editor',function()
    if source~=65535 or opening or Garage.Scene.active then return end
    if ctx then stop() return end opening=true
    local ticket=generation
    CreateThread(function()
        local ok,result=pcall(lib.callback.await,'rp_vehicles:editorOpen',false) opening=false
        if generation~=ticket then return end
        if not ok or not result or not result.ok then notify('Editor nicht verfügbar. Rechte und Migration prüfen.',true) return end
        ctx={token=result.token,garages=result.garages,bucket=result.bucket,pages={},path={}}
        root(ctx)
    end)
end)
RegisterNetEvent('rp_vehicles:editorClosed',function() if source==65535 then stop() end end)
AddEventHandler('rp_core:inputPressed',function(action) if action=='rp_vehicles:garage' and ctx and E.placing then ctx.accept=true end end)
AddEventHandler('esx:onPlayerLogout',stop)
AddEventHandler('onResourceStop',function(name) if name==GetCurrentResourceName() or name=='rp_nativeui' or name=='rp_ui' then stop() end end)
CreateThread(function()
    while true do
        if ctx and not alive(ctx) then stop() end
        local e=ctx
        if e and e.g then
            local g=e.g
            local function marker(p,r,b) DrawMarker(28,p.x,p.y,p.z,0.0,0.0,0.0,0.0,0.0,0.0,0.16,0.16,0.16,r,210,b,180,false,false,2,false,nil,nil,false) end
            marker(g.interaction,180,200) marker(g.hidden,245,90) marker(g.parking,100,180) marker(g.staffDoor,180,245)
            for _,key in ipairs({'outward','inward','staffPath'}) do
                local previous=key=='outward' and g.hidden or key=='inward' and g.parking or g.staffDoor
                for _,p in ipairs(g[key]) do marker(p,160,220) DrawLine(previous.x,previous.y,previous.z,p.x,p.y,p.z,180,230,205,170) previous=p end
                local last=key=='outward' and g.parking or key=='inward' and g.hidden
                if last then DrawLine(previous.x,previous.y,previous.z,last.x,last.y,last.z,180,230,205,170) end
            end
            Wait(0) -- temporary editor gizmos only
        else Wait(500) end
    end
end)
