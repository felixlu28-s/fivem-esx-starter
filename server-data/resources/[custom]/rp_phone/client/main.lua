local ESX = exports.es_extended:getSharedObject()
local phase, session, epoch, last = 'closed', '', 0, nil
local function owned()
    if not ESX.IsPlayerLoaded() then return false end
    for _, item in pairs(ESX.GetPlayerData().inventory or {}) do
        if item.name=='phone' and type(item.count)=='number' and item.count>0 then return true end
    end
    return false
end
local function publish(force)
    local visible = owned() and not IsEntityDead(PlayerPedId()) and not IsPauseMenuActive() and not IsScreenFadedOut()
    local key = 'UP'
    for _, action in ipairs(exports.rp_core:rpGetBindings().actions) do if action.id=='rp_phone:open' then key=action.key end end
    local data = { available=visible, open=phase=='opening' or phase=='open', session=session, toggleKey=key }
    local signature = json.encode(data)
    if force or signature~=last then exports.rp_ui:rpSetPhone(data) last=signature end
end
local function close(immediate)
    if PhoneApps then PhoneApps.close() end
    epoch=epoch+1
    local ticket=epoch
    phase=immediate and 'closed' or 'closing'
    if exports.rp_ui:rpGetView()=='phone' then exports.rp_ui:rpClose() end
    publish(true)
    if immediate then PhoneMotion.clear() else CreateThread(function()
        PhoneMotion.close()
        if ticket==epoch then phase='closed' end
    end) end
end
local function open()
    if phase=='closing' then return end
    if phase~='closed' then close(false) return end
    if not owned() or IsNuiFocused() or IsPauseMenuActive() or IsScreenFadedOut() or IsEntityDead(PlayerPedId()) then return end
    phase='requesting' epoch=epoch+1 local ticket=epoch
    local ok,result=pcall(lib.callback.await,'rp_phone:open',false)
    if ticket~=epoch then return end
    if not ok or not result or not result.ok or type(result.session)~='string' or not owned()
        or IsNuiFocused() or IsPauseMenuActive() then phase='closed' return end
    if not exports.rp_ui:rpOpen('phone',{},true,{keyboardOnly=true}) then phase='closed' return end
    session,phase=result.session,'opening'
    publish(true)
    if PhoneMotion.open() and ticket==epoch then phase='open'
    elseif ticket==epoch then close(true) end
end
local function register()
    if PhoneApps then PhoneApps.register(function(data)
        return type(data)=='table' and data.session==session and phase=='open' and owned() and exports.rp_ui:rpGetView()=='phone'
    end) end
    exports.rp_core:rpRegisterInputAction({id='rp_phone:open',label='Handy herausholen',category='Menüs',defaultKey='UP',description='iFruit mit Pfeiltasten bedienen; Zurück auf dem Homebildschirm legt es weg.'})
    exports.rp_ui:rpRegisterAction('rp_phone:key',function(data)
        if type(data)~='table' or data.session~=session or phase~='open' or not owned()
            or exports.rp_ui:rpGetView()~='phone' then return {ok=false,error='invalid_state'} end
        if data.key~='up' and data.key~='down' and data.key~='left' and data.key~='right' and data.key~='enter' and data.key~='back' then return {ok=false,error='invalid_key'} end
        PhoneMotion.gesture(data.key)
        if data.sound==true then PlaySoundFrontend(-1, data.key=='enter' and 'Menu_Accept' or 'Menu_Navigate', 'Phone_SoundSet_Default', true) end
        return {ok=true}
    end)
    exports.rp_ui:rpRegisterAction('rp_phone:close',function(data)
        if type(data)~='table' or data.session~=session or exports.rp_ui:rpGetView()~='phone' then return {ok=false,error='invalid_state'} end
        close(false) return {ok=true}
    end)
end
CreateThread(register)
AddEventHandler('rp_core:inputPressed',function(action) if action=='rp_phone:open' then CreateThread(open) end end)
RegisterCommand('rp_phone',function() CreateThread(open) end,false)
AddEventHandler('rp_ui:ready',function() last=nil end)
AddEventHandler('esx:onPlayerLogout',function() close(true) end)
AddEventHandler('onClientResourceStart',function(resource) if resource=='rp_ui' or resource=='rp_core' then register() last=nil end end)
AddEventHandler('onResourceStop',function(resource)
    if resource==GetCurrentResourceName() or resource=='rp_ui' or resource=='rp_core' or resource=='rp_inventory' then
        epoch=epoch+1 phase='closed' PhoneMotion.clear()
        pcall(function() if exports.rp_ui:rpGetView()=='phone' then exports.rp_ui:rpClose() end exports.rp_ui:rpSetPhone(false) end)
    end
end)
CreateThread(function()
    while true do
        if phase~='closed' and phase~='requesting' and phase~='closing' and (not owned() or not PhoneMotion.valid()
            or IsPauseMenuActive() or IsScreenFadedOut() or exports.rp_ui:rpGetView()~='phone') then close(true) end
        publish(false)
        Wait(200)
    end
end)
CreateThread(function()
    while true do
        if phase=='opening' or phase=='open' then
            DisablePlayerFiring(PlayerId(),true)
            for _,control in ipairs({24,25,37,140,141,142}) do DisableControlAction(0,control,true) end
            Wait(0) -- GTA controls must be suppressed per frame, only with the phone open.
        else Wait(200) end
    end
end)
