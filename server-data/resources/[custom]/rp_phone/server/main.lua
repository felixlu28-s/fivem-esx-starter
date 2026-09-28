local S=PhoneService
lib.callback.register('rp_phone:open',function(source)
    if not S.rate(source,'open',700) then return {ok=false,error='rate_limited'} end
    local ref=S.ref(source)
    if not ref then return {ok=false,error='phone_missing'} end
    local token=S.token()
    S.sessions[source]={owner=ref.owner,epoch=ref.epoch,token=token}
    return {ok=true,session=token}
end)
lib.callback.register('rp_phone:action',function(source,token,action,data)
    if type(action)~='string' then return {ok=false,error='invalid_fields'} end
    return S.transaction(source,token,action,data)
end)
lib.callback.register('rp_phone:sync',function(source)
    if not S.ready or not S.rate(source,'sync',5000) then return {ok=false,error='unavailable'} end
    local ref=S.ref(source)
    if not ref then S.leaveCall(source) return {ok=false,error='phone_missing'} end
    local row=S.presence[source]
    if not row or not S.current(row) then row=S.profile(ref) end
    if not row then return {ok=false,error='unavailable'} end
    S.syncCall(source)
    return {ok=true}
end)
AddEventHandler('playerDropped',function() S.clear(source) end)
AddEventHandler('esx:playerLogout',function(id) S.clear(tonumber(id) or source) end)
