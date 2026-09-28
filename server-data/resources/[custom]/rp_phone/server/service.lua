PhoneService={handlers={},online={},presence={},sessions={},epochs={},locks={},ready=false}
local S,ESX=PhoneService,exports.es_extended:getSharedObject()
local rates,sequence={},0
local boot=('%x-%x'):format(os.time(),math.random(0,0x7fffffff))
-- Only a stable namespace is stored on the server, never gallery media/keys.
local galleryNamespace=GetResourceKvpString('rp_phone:gallery_namespace')
if not galleryNamespace then
    galleryNamespace=boot..('%x'):format(math.random(0,0x7fffffff))
    SetResourceKvp('rp_phone:gallery_namespace',galleryNamespace)
end
function S.token() sequence=sequence+1 return boot..':'..sequence end
function S.text(v,max,empty)
    return type(v)=='string' and #v<=max and (empty or #v>0) and not v:find('[%z\1-\8\11\12\14-\31]') and v
end
function S.id(v) return type(v)=='number' and v%1==0 and v>0 and v<9007199254740991 and v end
function S.number(id) return ('555%07d'):format(id) end
function S.numberId(value)
    if type(value)~='string' or not value:match('^555%d%d%d%d%d%d%d$') then return end
    return tonumber(value:sub(4))
end
function S.rate(source,key,delay)
    rates[source]=rates[source] or {}
    local now=GetGameTimer()
    if (rates[source][key] or 0)>now then return false end
    rates[source][key]=now+delay return true
end
function S.player(source)
    local p,ped=ESX.GetPlayerFromId(source),GetPlayerPed(source)
    if not p or not p.identifier or ped==0 or GetEntityHealth(ped)<=0 then return end
    local item=p.getInventoryItem('phone')
    return item and item.count>0 and p or nil
end
function S.ref(source)
    local p=S.player(source)
    return p and {source=source,owner=p.identifier,epoch=S.epochs[source] or 0}
end
function S.current(ref)
    local p=ref and S.player(ref.source)
    return p and p.identifier==ref.owner and (S.epochs[ref.source] or 0)==ref.epoch and p
end
function S.profile(ref)
    local p=S.current(ref)
    if not p then return end
    local row=MySQL.single.await('SELECT * FROM rp_phone_profiles WHERE owner=?',{ref.owner})
    if not row then
        MySQL.insert.await('INSERT IGNORE INTO rp_phone_profiles (owner,name) VALUES (?,?)',{ref.owner,(p.getName() or 'Los Santos'):sub(1,60)})
        row=MySQL.single.await('SELECT * FROM rp_phone_profiles WHERE owner=?',{ref.owner})
    end
    if not row or not S.current(ref) then return end
    row.id=tonumber(row.id)
    S.online[row.id]={source=ref.source,owner=ref.owner,epoch=ref.epoch,id=row.id,name=row.name}
    S.presence[ref.source]=S.online[row.id]
    return row
end
function S.public(row)
    return {id=row.id,number=S.number(row.id),name=row.name,handle=row.handle or ('citizen'..row.id),bio=row.bio,galleryScope=galleryNamespace..':'..row.id,
        contacts=json.decode(row.contacts or '[]'),tasks=json.decode(row.tasks or '[]'),bookmarks=json.decode(row.bookmarks or '[]')}
end
function S.notify(id,kind)
    local ref=S.online[id]
    if ref and S.current(ref) then TriggerClientEvent('rp_phone:update',ref.source,{kind=kind}) end
end
function S.transaction(source,token,action,data)
    local ref=S.ref(source)
    local session=S.sessions[source]
    if not S.ready or not ref or not session or session.owner~=ref.owner or session.epoch~=ref.epoch or session.token~=token
        or not S.handlers[action] or type(data)~='table' then return {ok=false,error='invalid_state'} end
    if not S.rate(source,'action',180) or S.locks[ref.owner] then return {ok=false,error='busy'} end
    local lock={} S.locks[ref.owner]=lock
    local ok,result=xpcall(function()
        local row=S.profile(ref)
        if not row then return {ok=false,error='invalid_state'} end
        local result=S.handlers[action](ref,row,data)
        if not S.current(ref) then return {ok=false,error='invalid_state'} end
        return result
    end,debug.traceback)
    if S.locks[ref.owner]==lock then S.locks[ref.owner]=nil end
    if not ok then print('[rp_phone] App request failed: '..tostring(result)) return {ok=false,error='unavailable'} end
    return result or {ok=false,error='invalid_fields'}
end
function S.clear(source)
    S.epochs[source]=(S.epochs[source] or 0)+1
    S.sessions[source],rates[source]=nil,nil
    S.presence[source]=nil
    if S.leaveCall then S.leaveCall(source) end
    for id,ref in pairs(S.online) do if ref.source==source then S.online[id]=nil end end
end
MySQL.ready(function()
    local ok=pcall(function() MySQL.query.await('SELECT owner,active FROM rp_phone_social_accounts LIMIT 1') end)
    S.ready=ok
    if not ok then print('[rp_phone] Run migrations/001_phone_apps.sql and 002_social_profiles.sql before using phone apps.') end
end)
