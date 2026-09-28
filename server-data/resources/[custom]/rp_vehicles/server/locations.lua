local C,R,ESX=Garage.Config,Garage.Rules,exports.es_extended:getSharedObject()
local D={ready=false,editing={},reserved={}}
Garage.Locations=D
local sessions,epochs,rates,serial={}, {}, {}, 0
local catalogBuckets={}
local function token()
    serial=serial+1 return ('g_%x_%x_%x'):format(GetGameTimer(),math.random(0,0x7fffffff),serial)
end
local function rate(source,channel,delay)
    local now=GetGameTimer() rates[source]=rates[source] or {}
    local entries=rates[source] if (entries[channel] or 0)>now then return false end
    entries[channel]=now+(delay or 800) return true
end
local function admin(source)
    local p=ESX.GetPlayerFromId(source)
    if p and ({admin=true,superadmin=true,owner=true})[p.getGroup()] and GetEntityHealth(GetPlayerPed(source))>0 then return p end
end
local function current(source,key)
    local p,s=admin(source),sessions[source]
    return p and s and s.token==key and s.owner==p.identifier and s.epoch==(epochs[source] or 0)
        and s.expires>os.time() and s
end
local function catalog(source)
    local rows,bucket={},GetPlayerRoutingBucket(source)
    for id,g in pairs(C.garages) do if g.bucket==bucket then
        local row=R.copy(g) row.id=id rows[#rows+1]=row
    end end
    table.sort(rows,function(a,b) return a.label<b.label end)
    return rows
end
local function install(id,payload,revision,deleted)
    if deleted==1 then C.garages[id]=nil
    else local g=assert(R.definition(payload)) g.id,g.revision=id,revision C.garages[id]=g end
    GlobalState['rp_vehicles:gate:'..id]=false
end
local function changed() TriggerClientEvent('rp_vehicles:locationsChanged',-1) end
lib.callback.register('rp_vehicles:locations',function(source)
    if not D.ready or not ESX.GetPlayerFromId(source) or not rate(source,'catalog') then return {ok=false} end
    -- ESX loading precedes the character resource's return from its private
    -- routing bucket. Even an empty catalog must subscribe to that transition.
    catalogBuckets[source]=GetPlayerRoutingBucket(source)
    return {ok=true,garages=catalog(source)}
end)
ESX.RegisterCommand('rp_garage_dev',{'admin','superadmin','owner'},function(p)
    if p and admin(p.source) then TriggerClientEvent('rp_vehicles:editor',p.source) end
end,false,{help='Garagen, NPCs, Tor und Fahrwege bearbeiten',validate=true,arguments={}})
lib.callback.register('rp_vehicles:editorOpen',function(source)
    local p=admin(source)
    if not D.ready or not p or not rate(source,'open') or (sessions[source] and sessions[source].busy) then return {ok=false,error='forbidden_or_busy'} end
    local previous=sessions[source]
    if previous and previous.id then D.reserved[previous.id]=nil end
    local s={owner=p.identifier,token=token(),epoch=epochs[source] or 0,expires=os.time()+1800}
    sessions[source]=s
    return {ok=true,token=s.token,garages=catalog(source),bucket=GetPlayerRoutingBucket(source)}
end)
lib.callback.register('rp_vehicles:editorSelect',function(source,key,id)
    local s=current(source,key)
    if not D.ready or not s or s.busy or not rate(source,'select',150) then return {ok=false,error='forbidden_or_busy'} end
    local g=type(id)=='string' and C.garages[id]
    if id~=false and (not g or g.bucket~=GetPlayerRoutingBucket(source)
        or R.distance(GetEntityCoords(GetPlayerPed(source)),g.interaction)>C.editor.radius) then return {ok=false,error='out_of_range'} end
    if g and (Garage.Service.busy(id) or D.editing[id] or (D.reserved[id] and D.reserved[id]~=s)) then return {ok=false,error='garage_busy'} end
    if s.id then D.reserved[s.id]=nil end
    s.id=id or nil if s.id then D.reserved[s.id]=s end
    return {ok=true,garage=g and R.copy(g)}
end)
lib.callback.register('rp_vehicles:editorSave',function(source,key,id,revision,raw,remove)
    local s=current(source,key)
    if not D.ready or not s then return {ok=false,error='forbidden'} end
    if s.busy or not rate(source,'save') then return {ok=false,error='busy'} end
    if type(remove)~='boolean' or (id~=false and (type(id)~='string' or #id>48)) then return {ok=false,error='invalid_request'} end
    local old=id and C.garages[id]
    if id and (not old or old.revision~=revision) then return {ok=false,error='revision_conflict'} end
    if id and D.reserved[id]~=s then return {ok=false,error='garage_not_selected'} end
    if id and (D.editing[id] or Garage.Service.busy(id)) then return {ok=false,error='garage_busy'} end
    if not old and remove then return {ok=false,error='invalid_request'} end
    local pos,bucket=GetEntityCoords(GetPlayerPed(source)),GetPlayerRoutingBucket(source)
    if old and (old.bucket~=bucket or R.distance(pos,old.interaction)>C.editor.radius) then return {ok=false,error='out_of_range'} end
    local g,reason
    if not remove then
        g,reason=R.definition(raw)
        if not g then return {ok=false,error=reason} end
        if g.bucket~=bucket or R.distance(pos,g.interaction)>(old and C.editor.radius or 10) then return {ok=false,error='out_of_range'} end
        -- One physical door must have exactly one controller, including pending saves.
        for otherId,other in pairs(C.garages) do
            if otherId~=id and other.bucket==g.bucket and R.distance(other.gate,g.gate)<3 then return {ok=false,error='gate_in_use'} end
        end
        for otherId,other in pairs(D.editing) do
            if otherId~=id and other.bucket==g.bucket and R.distance(other.gate,g.gate)<3 then return {ok=false,error='gate_in_use'} end
        end
    end
    local count=0 for _ in pairs(C.garages) do count=count+1 end
    for pending in pairs(D.editing) do if not C.garages[pending] then count=count+1 end end
    if not old and count>=C.editor.maxGarages then return {ok=false,error='garage_limit'} end
    id=id or s.token -- repeat after lost SQL reply cannot create a second garage
    D.editing[id],s.busy=g or old,true
    local expected=(old and revision or 0)+1
    local ok,saved,err=pcall(function()
        if remove then
            local stock=MySQL.scalar.await('SELECT COUNT(*) FROM owned_vehicles WHERE parking=?',{id})
            if tonumber(stock)~=0 then return false,'garage_has_vehicles' end
        end
        if not current(source,key) or GetPlayerRoutingBucket(source)~=bucket
            or R.distance(GetEntityCoords(GetPlayerPed(source)),(old or g).interaction)>C.editor.radius then return false,'session_ended' end
        if old then
            return MySQL.update.await('UPDATE rp_vehicle_garages SET payload=?,deleted=?,revision=revision+1,updated_by=? WHERE id=? AND revision=? AND deleted=0',
                {json.encode(remove and old or g),remove and 1 or 0,s.owner,id,revision})==1
        end
        return MySQL.update.await('INSERT IGNORE INTO rp_vehicle_garages (id,payload,updated_by) VALUES (?,?,?)',{id,json.encode(g),s.owner})==1
    end)
    -- Re-read after uncertain SQL acknowledgement instead of blindly retrying a create.
    if not ok then
        local read,row=pcall(MySQL.single.await,'SELECT payload,revision,deleted FROM rp_vehicle_garages WHERE id=?',{id})
        if read and row then
            local decoded,value=pcall(json.decode,row.payload)
            if decoded and R.definition(value) then
                install(id,value,row.revision,row.deleted) changed()
                saved=row.revision==expected and row.deleted==(remove and 1 or 0)
                g=C.garages[id] ok=true
            end
        end
        if not ok then D.ready=false sessions[source]=nil end
    end
    D.editing[id],s.busy=nil,false
    if not ok or not saved then return {ok=false,error=err or (ok and 'revision_conflict' or 'database_error')} end
    install(id,remove and old or g,expected,remove and 1 or 0) changed()
    if not old then s.token=token() s.id=id D.reserved[id]=s end
    if remove then D.reserved[id]=nil s.id=nil end
    print(('[rp_vehicles] garage %s id=%s admin=%d revision=%d'):format(remove and 'archived' or 'saved',id,source,expected))
    if not current(source,s.token) then return {ok=false,error='session_ended'} end
    return {ok=true,token=s.token,garage=R.copy(C.garages[id])}
end)
local function leave(id)
    local s=sessions[id] if s and s.id and D.reserved[s.id]==s then D.reserved[s.id]=nil end
    epochs[id]=(epochs[id] or 0)+1 sessions[id],rates[id]=nil,nil
end
RegisterNetEvent('rp_vehicles:editorClose',function(key)
    local s=sessions[source] if s and s.token==key then leave(source) end
end)
AddEventHandler('playerDropped',function() catalogBuckets[source]=nil leave(source) end)
AddEventHandler('esx:playerLogout',function(id) catalogBuckets[id]=nil leave(id) end)
CreateThread(function()
    while true do
        Wait(2000)
        -- One native lookup per subscribed player; no database access, repeated
        -- full catalog downloads or network traffic while the bucket is stable.
        for source,previous in pairs(catalogBuckets) do
            local bucket=GetPlayerRoutingBucket(source)
            if bucket~=previous then
                catalogBuckets[source]=bucket
                TriggerClientEvent('rp_vehicles:locationsChanged',source)
            end
        end
        for source,s in pairs(sessions) do
            local g=s.id and C.garages[s.id]
            if not current(source,s.token) or (g and (g.bucket~=GetPlayerRoutingBucket(source)
                or R.distance(GetEntityCoords(GetPlayerPed(source)),g.interaction)>C.editor.radius)) then
                leave(source) TriggerClientEvent('rp_vehicles:editorClosed',source)
            end
        end
    end
end)
MySQL.ready(function()
    local ok,err=pcall(function()
        for id,g in pairs(C.garages) do
            MySQL.update.await('INSERT IGNORE INTO rp_vehicle_garages (id,payload,updated_by) VALUES (?,?,?)',{id,json.encode(g),'bootstrap'})
        end
        local rows=MySQL.query.await('SELECT id,payload,revision,deleted FROM rp_vehicle_garages')
        local count=0
        for _,row in ipairs(rows) do
            if row.deleted==0 then count=count+1 assert(count<=C.editor.maxGarages,'garage_limit') end
            install(row.id,json.decode(row.payload),row.revision,row.deleted)
        end
        D.ready=true changed()
        print(('[rp_vehicles] Garage catalogue ready: %d active locations.'):format(count))
    end)
    if not ok then print('[rp_vehicles] Garage catalogue unavailable; apply migrations/002_garage_locations.sql: '..tostring(err)) end
end)
