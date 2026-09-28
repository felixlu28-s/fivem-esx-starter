PhoneApps={call=false}
local A,ESX=PhoneApps,exports.es_extended:getSharedObject()
local volumes,voiceOwned={},false
local function owned()
    if not ESX.IsPlayerLoaded() then return false end
    for _,v in pairs(ESX.GetPlayerData().inventory or {}) do if v.name=='phone' and v.count>0 then return true end end
    return false
end
local function resetVoice()
    for id in pairs(volumes) do MumbleSetVolumeOverrideByServerId(id,-1.0) end volumes={}
    if voiceOwned then MumbleClearVoiceTarget(30) MumbleSetVoiceTarget(0) voiceOwned=false end
end
function A.stopCamera() PhoneCamera.stop() end
function A.close()
    A.stopCamera()
    pcall(function() exports.rp_ui:rpSetTextInput(false) end)
    if A.call then TriggerServerEvent('rp_phone:cameraOff') end
end
function A.register(valid)
    exports.rp_ui:rpRegisterAction('rp_phone:action',function(d)
        if not valid(d) or type(d.action)~='string' or type(d.data)~='table' then return {ok=false,error='invalid_state'} end
        local ok,result=pcall(lib.callback.await,'rp_phone:action',false,d.session,d.action,d.data)
        return ok and result or {ok=false,error='unavailable'}
    end)
    exports.rp_ui:rpRegisterAction('rp_phone:typing',function(d)
        if not valid(d) or type(d.active)~='boolean' then return {ok=false} end
        return {ok=exports.rp_ui:rpSetTextInput(d.active)}
    end)
    exports.rp_ui:rpRegisterAction('rp_phone:camera',function(d)
        if not valid(d) then return {ok=false,error='invalid_state'} end
        if d.mode~='off' and d.mode~='rear' and d.mode~='selfie' then return {ok=false,error='invalid_fields'} end
        return {ok=PhoneCamera.configure(d.mode,d.zoom or 1.0,owned)}
    end)
    exports.rp_ui:rpRegisterAction('rp_phone:signal',function(d)
        if not owned() or not A.call or d.call~=A.call.id then return {ok=false} end
        TriggerServerEvent('rp_phone:signal',d) return {ok=true}
    end)
end
RegisterNetEvent('rp_phone:update',function(d)
    if source~=65535 or type(d)~='table' then return end
    if d.kind=='call' then
        local hadCall=A.call
        A.call=d.call
        if not d.call then resetVoice() if hadCall then A.stopCamera() end end
    end
    exports.rp_ui:rpPhoneEvent(d)
end)
CreateThread(function()
    local nextSync,wasOwned,nextRing=0,false,0
    while true do
        local has=owned() and not IsEntityDead(PlayerPedId())
        if has and (not wasOwned or GetGameTimer()>nextSync) then
            nextSync=GetGameTimer()+30000
            pcall(lib.callback.await,'rp_phone:sync',false)
        end
        wasOwned=has
        local call=A.call
        local selfId=GetPlayerServerId(PlayerId())
        local me
        if has and call then for _,m in ipairs(call.members) do if m.id==selfId then me=m break end end end
        if me and not me.joined and GetGameTimer()>nextRing then
            PlaySoundFrontend(-1,'Remote_Ring','Phone_SoundSet_Default',true) nextRing=GetGameTimer()+4000
        end
        if me and me.joined and call.backend=='mumble' then
            MumbleClearVoiceTarget(30)
            local desired={}
            for _,m in ipairs(call.members) do
                if m.id~=selfId and m.joined then
                    desired[m.id]=true MumbleSetVolumeOverrideByServerId(m.id,1.0)
                    if not me.muted then MumbleAddVoiceTargetPlayerByServerId(30,m.id) end
                end
            end
            for id in pairs(volumes) do if not desired[id] then MumbleSetVolumeOverrideByServerId(id,-1.0) end end
            volumes=desired
            local position=GetEntityCoords(PlayerPedId())
            local range=MumbleGetTalkerProximity()
            for _,player in ipairs(GetActivePlayers()) do
                if player~=PlayerId() and #(GetEntityCoords(GetPlayerPed(player))-position)<range then MumbleAddVoiceTargetPlayer(30,player) end
            end
            MumbleSetVoiceTarget(30) voiceOwned=true
        else resetVoice() end
        if not has then A.stopCamera() end
        Wait(500)
    end
end)
AddEventHandler('esx:onPlayerLogout',function() A.close() A.call=false resetVoice() exports.rp_ui:rpPhoneEvent({kind='reset'}) end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() or name=='rp_ui' then A.close() A.call=false resetVoice() end
end)
