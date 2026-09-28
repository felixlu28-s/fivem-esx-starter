local S,C=PhoneService,PhoneConfig
local calls,bySource,signalRates={}, {}, {}
local function ice()
    local ok,list=pcall(json.decode,GetConvar('rp_phone_ice_servers','[{"urls":"stun:stun.l.google.com:19302"}]'))
    return ok and type(list)=='table' and list or {}
end
local function voice(call,id,joined,muted)
    if call.backend~='native' then return end
    if joined then
        if not call.voice[id] then AddPlayerToVoiceChannel(call.channel,id) call.voice[id]=true end
        SetPlayerMutedInVoiceChannel(call.channel,id,muted==true)
    elseif call.voice[id] then RemovePlayerFromVoiceChannel(call.channel,id) call.voice[id]=nil end
end
local function count(call,field)
    local n=0 for _,m in pairs(call.members) do if not field or m[field] then n=n+1 end end return n
end
local function publish(call)
    local members={}
    for id,m in pairs(call.members) do members[#members+1]={id=id,number=S.number(m.profile),name=m.name,joined=m.joined,video=m.video,muted=m.muted} end
    table.sort(members,function(a,b) return a.id<b.id end)
    for id,m in pairs(call.members) do
        if S.current(m) then TriggerClientEvent('rp_phone:update',id,{kind='call',call={id=call.id,self=id,host=call.host,
            members=members,video=call.video,backend=call.backend,ice=ice()}}) end
        voice(call,id,m.joined,m.muted)
    end
end
local function history(m,call,outcome)
    CreateThread(function()
        local ok,err=pcall(MySQL.insert.await,[[INSERT INTO rp_phone_call_history (profile,peer,direction,video,outcome,created) VALUES (?,?,?,?,?,?)]],
            {m.profile,m.peer,m.outgoing and 'out' or 'in',call.video and 1 or 0,outcome,os.time()})
        if not ok then print('[rp_phone] Call history unavailable: '..tostring(err)) end
    end)
end
local function remove(call,id,reason)
    local m=call.members[id]
    if not m then return end
    history(m,call,m.joined and 'finished' or reason or 'missed')
    voice(call,id,false)
    call.members[id],bySource[id]=nil,nil
    if (S.epochs[id] or 0)==m.epoch then TriggerClientEvent('rp_phone:update',id,{kind='call',call=false}) end
end
local function destroy(call,reason)
    local ids={} for id in pairs(call.members) do ids[#ids+1]=id end
    for _,id in ipairs(ids) do remove(call,id,reason) end
    if call.backend=='native' then DeleteVoiceChannel(call.channel) end
    calls[call.id]=nil
end
function S.leaveCall(source,reason)
    local call=bySource[source] and calls[bySource[source]]
    if not call then return end
    remove(call,source,reason)
    if count(call)==0 or (count(call,'joined')<2 and count(call)==count(call,'joined')) then destroy(call,reason) return end
    if not call.members[call.host] then
        for id,m in pairs(call.members) do if m.joined then call.host=id break end end
        if not call.members[call.host] then destroy(call,reason) return end
    end
    publish(call)
end
local function member(ref,row,peer,outgoing)
    return {source=ref.source,owner=ref.owner,epoch=ref.epoch,profile=row.id,name=row.name,
        peer=peer,outgoing=outgoing,joined=outgoing==true,video=false,muted=false,expires=os.time()+C.ringSeconds}
end
local function target(number)
    local id=S.numberId(number)
    local ref=id and S.online[id]
    return ref and S.current(ref) and not bySource[ref.source] and ref or nil
end
S.handlers.call_start=function(ref,row,d)
    if bySource[ref.source] or not S.rate(ref.source,'dial',2000) or type(d.video)~='boolean' then return end
    if GetResourceState('pma-voice')=='started' or GetResourceState('saltychat')=='started' then return {ok=false,error='voice_conflict'} end
    local other=target(d.number)
    if not other or other.source==ref.source then return {ok=false,error='number_unavailable'} end
    local call={id=S.token(),host=ref.source,video=d.video,members={},backend='mumble',voice={}}
    if type(CreateVoiceChannel)=='function' then
        local ok,channel=pcall(CreateVoiceChannel,0,0.0)
        if ok and type(channel)=='number' and channel>=0 and channel<65535 then call.backend,call.channel='native',channel end
    end
    call.members[ref.source]=member(ref,row,d.number,true)
    call.members[ref.source].video=d.video
    call.members[other.source]=member(other,{id=other.id,name=other.name},S.number(row.id),false)
    calls[call.id],bySource[ref.source],bySource[other.source]=call,call.id,call.id
    publish(call) return {ok=true}
end
S.handlers.call_accept=function(ref,_,d)
    local call=bySource[ref.source] and calls[bySource[ref.source]]
    if not call or d.call~=call.id or type(d.video)~='boolean' then return end
    local m=call.members[ref.source]
    if m.joined or m.expires<os.time() then return end
    m.joined=true m.video=call.video and d.video and count(call,'video')<C.videoParticipants or false
    publish(call) return {ok=true}
end
S.handlers.call_leave=function(ref,_,d)
    if bySource[ref.source]~=d.call then return end
    S.leaveCall(ref.source,'declined') return {ok=true}
end
S.handlers.call_invite=function(ref,row,d)
    local call=bySource[ref.source] and calls[bySource[ref.source]]
    if not call or call.id~=d.call or call.host~=ref.source or count(call)>=C.callParticipants or not S.rate(ref.source,'dial',2000) then return end
    local other=target(d.number)
    if not other then return {ok=false,error='number_unavailable'} end
    call.members[other.source]=member(other,{id=other.id,name=other.name},S.number(row.id),false)
    bySource[other.source]=call.id publish(call) return {ok=true}
end
S.handlers.call_state=function(ref,_,d)
    local call=bySource[ref.source] and calls[bySource[ref.source]]
    if not call or call.id~=d.call then return end
    local m=call.members[ref.source]
    if not m.joined or type(d.video)~='boolean' or type(d.muted)~='boolean' then return end
    if d.video and not m.video and count(call,'video')>=C.videoParticipants then return {ok=false,error='limit'} end
    m.video,m.muted=d.video,d.muted call.video=call.video or d.video
    publish(call) return {ok=true}
end
RegisterNetEvent('rp_phone:signal',function(d)
    local id=source
    local call=bySource[id] and calls[bySource[id]]
    if type(d)~='table' or not call or d.call~=call.id or not S.id(d.target) or d.target==id then return end
    local sender,recipient=call.members[id],call.members[d.target]
    if not sender or not recipient or not sender.joined or not recipient.joined or not S.current(sender) or not S.current(recipient)
        or (not sender.video and not recipient.video) then return end
    local bucket=signalRates[id]
    if not bucket or bucket.untilTime<GetGameTimer() then bucket={count=0,untilTime=GetGameTimer()+10000} signalRates[id]=bucket end
    bucket.count=bucket.count+1 if bucket.count>100 then return end
    if (d.type=='offer' or d.type=='answer') and S.text(d.sdp,32000) then
        TriggerClientEvent('rp_phone:update',d.target,{kind='signal',call=call.id,from=id,type=d.type,sdp=d.sdp})
    elseif d.type=='candidate' and S.text(d.candidate,1200,true) and (d.mid==nil or S.text(d.mid,50,true))
        and type(d.line)=='number' and d.line%1==0 and d.line>=0 and d.line<20 then
        TriggerClientEvent('rp_phone:update',d.target,{kind='signal',call=call.id,from=id,type=d.type,candidate=d.candidate,mid=d.mid,line=d.line})
    end
end)
function S.syncCall(source)
    local call=bySource[source] and calls[bySource[source]]
    if call then publish(call) else TriggerClientEvent('rp_phone:update',source,{kind='call',call=false}) end
end
RegisterNetEvent('rp_phone:cameraOff',function()
    local call=bySource[source] and calls[bySource[source]]
    local m=call and call.members[source]
    if m and m.video then m.video=false publish(call) end
end)
CreateThread(function()
    while true do
        Wait(2000)
        local stale={}
        for _,call in pairs(calls) do for id,m in pairs(call.members) do
            if not S.current(m) or (not m.joined and m.expires<os.time()) then stale[#stale+1]=id end
        end end
        for _,id in ipairs(stale) do S.leaveCall(id,'missed') end
    end
end)
AddEventHandler('playerDropped',function() signalRates[source]=nil end)
AddEventHandler('onResourceStop',function(name)
    if name~=GetCurrentResourceName() then return end
    local all={} for _,call in pairs(calls) do all[#all+1]=call end
    for _,call in ipairs(all) do destroy(call,'ended') end
end)
