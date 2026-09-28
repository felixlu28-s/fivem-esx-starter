local ui, ESX = exports.rp_nativeui, exports.es_extended:getSharedObject()
local ctx, opening, generation = nil, false, 0
local god, godPed, previousInvincible, lease, nextHeartbeat = false, nil, false, 0, 0
local heartbeatBusy, modeEpoch = false, 0
local messages={forbidden='Keine Berechtigung oder Sitzung abgelaufen.',invalid_target='Spieler nicht mehr verfügbar. Empfänger neu wählen.',
    invalid_amount='Bitte einen ganzen Betrag von 1 bis 1.000.000 eingeben.',invalid_account='Dieses Konto kann nicht geändert werden.',
    rate_limited='Bitte einen Moment warten.',stale_request='Auswahl nicht mehr aktuell. Menü erneut öffnen.',
    unavailable='Keine Antwort. Bei Geldvergabe dieselbe Auswahl erneut bestätigen.'}
local function notify(text,kind) lib.notify({title='Administration',description=text,type=kind or 'error'}) end
local function request(name,...)
    local ok,result=pcall(lib.callback.await,'rp_admin:'..name,false,...)
    return ok and type(result)=='table' and result or {ok=false,error='unavailable'}
end
local function setGod(enabled)
    modeEpoch=modeEpoch+1
    if enabled and not god then
        previousInvincible=GetPlayerInvincible(PlayerId())
        godPed=PlayerPedId()
        SetPlayerInvincible(PlayerId(),true)
    elseif not enabled and god then
        SetPlayerInvincible(PlayerId(),previousInvincible)
        godPed=nil
    end
    god=enabled
    lease=enabled and GetGameTimer()+30000 or 0
    if enabled then nextHeartbeat=GetGameTimer()+10000 end
end
local function clear()
    generation=generation+1
    local old=ctx ctx=nil
    if old and GetResourceState('rp_nativeui')=='started' then
        for _,h in ipairs(old.handles or {}) do ui:rpDestroyMenu(h) end
    end
end
local rootRows, moneyRows, refresh, input
local function act(c,action,enabled)
    if ctx~=c or c.busy then return false end
    c.busy=true
    CreateThread(function()
        Wait(0)
        if ctx~=c then return end
        -- Cross-resource menus cannot be nested. Release our NativeUI first;
        -- the inventory resource then opens its existing authenticated menu.
        if action~='godmode' then c.suspended=true ui:rpCloseMenu() end
        local result=request('action',c.token,action,enabled)
        if ctx~=c then return end
        c.busy=false
        if not result.ok then
            notify(messages[result.error] or 'Aktion abgelehnt.')
            c.suspended=false ui:rpOpenMenu(c.root,{toggleAction='rp_admin:open'})
        elseif action~='godmode' then clear()
        else refresh(c) end
    end)
    return false
end
rootRows=function(c)
    return {
        {id='money',label='Geld vergeben',type='submenu',menu=c.money},
        {id='items',label='Items vergeben',description='Öffnet die vorhandene Itemverwaltung mit Kategorien, Empfänger und Mengen.'},
        {id='noclip',label='Noclip umschalten',rightLabel='An / Aus',description='Verwendet den vorhandenen ESX-Noclip. Erneut wählen zum Ausschalten.'},
        {id='waypoint',label='Zum Wegpunkt teleportieren',description='Zuerst auf der Karte einen Wegpunkt setzen. Verwendet ESX /tpm.'},
        {id='godmode',label='Godmode',type='checkbox',checked=god,description='Temporäre Unverwundbarkeit. Endet bei Logout, Tod oder Ressourcenstopp.'},
    }
end
moneyRows=function(c)
    return {
        {id='target',label='Empfänger',rightLabel=c.target==GetPlayerServerId(PlayerId()) and ('Mich · ID '..c.target) or ('ID '..c.target),
            description='Enter: Spieler-ID eingeben. Standard ist dein eigener Charakter.'},
        {id='account',label='Konto',type='list',index=c.account=='money' and 1 or 2,
            options={{label='Bargeld',value='money'},{label='Bankkonto',value='bank'}}},
        {id='amount',label='Betrag',rightLabel=('$ %d'):format(c.amount),description='Enter: Betrag von 1 bis 1.000.000 eingeben.'},
        {id='give',label='Geld vergeben',description='Schreibt den ausgewählten Betrag über ESX auf den aktiven Charakter des Empfängers.'},
    }
end
refresh=function(c)
    if ctx~=c then return end
    ui:rpSetItems(c.root,rootRows(c)) ui:rpSetItems(c.money,moneyRows(c))
end
input=function(c,field)
    if ctx~=c or c.busy then return false end
    c.busy,c.suspended=true,true
    ui:rpCloseMenu()
    CreateThread(function()
        Wait(0)
        if ctx~=c then return end
        AddTextEntry('RP_ADMIN_INPUT',field=='amount' and 'Betrag (1 bis 1.000.000)' or 'Spieler-ID')
        DisplayOnscreenKeyboard(1,'RP_ADMIN_INPUT','',tostring(c[field]),'','','',10)
        local status=UpdateOnscreenKeyboard()
        while status==0 and ctx==c do DisableAllControlActions(0) Wait(0) status=UpdateOnscreenKeyboard() end
        if ctx~=c then CancelOnscreenKeyboard() return end
        if status==1 then
            local raw=GetOnscreenKeyboardResult()
            local n=type(raw)=='string' and raw:match('^%d+$') and tonumber(raw)
            if not n or n<1 or n>(field=='amount' and 1000000 or 2147483647) then notify('Ungültige Zahl.')
            elseif field=='amount' then c.amount=math.tointeger(n)
            else
                local result=request('target',c.token,n)
                if ctx~=c then return end
                if result.ok then c.target,c.nonce=result.target,result.nonce
                else notify(messages[result.error] or 'Empfänger nicht verfügbar.') end
            end
        end
        c.suspended,c.busy=false,false refresh(c)
        if ui:rpOpenMenu(c.root,{toggleAction='rp_admin:open'}) then ui:rpPushMenu(c.money) else clear() end
    end)
    return false
end
local function build(result)
    clear()
    local c={token=result.token,nonce=result.nonce,target=result.target,amount=1000,account='money',handles={},busy=false}
    ctx=c
    c.money=assert(ui:rpCreateMenu('money',{title='Administration',subtitle='GELDVERGABE',items={}}, {
        onChange=function(id,value)
            if ctx~=c or c.busy then return false end
            if id=='account' then c.account=value end
        end,
        onSelect=function(id)
            if ctx~=c or c.busy then return false end
            if id=='target' or id=='amount' then return input(c,id) end
            if id~='give' then return end
            c.busy=true
            CreateThread(function()
                local result=request('money',c.token,c.nonce,c.account,c.amount)
                if ctx~=c then return end
                c.busy=false
                if result.ok then c.nonce=result.nonce notify(('$%d an ID %d vergeben.'):format(c.amount,c.target),'success')
                else notify(messages[result.error] or 'Geldvergabe abgelehnt.') end
                refresh(c)
            end)
        end,
    }))
    c.handles[#c.handles+1]=c.money
    c.root=assert(ui:rpCreateMenu('main',{title='Administration',subtitle='LOS SANTOS · ADMIN',items={}}, {
        onSelect=function(id) if id~='money' then return act(c,id) end end,
        onChange=function(id,value) if id=='godmode' then return act(c,id,value) end end,
        onClose=function() if ctx==c and not c.suspended then clear() end end,
    }))
    c.handles[#c.handles+1]=c.root
    refresh(c)
    if not ui:rpOpenMenu(c.root,{toggleAction='rp_admin:open'}) then clear() end
end
local function open()
    if ctx then if not ctx.busy then clear() end return end
    if opening or not ESX.IsPlayerLoaded() or IsNuiFocused() or IsEntityDead(PlayerPedId()) then return end
    opening=true local epoch=generation
    CreateThread(function()
        local result=request('open')
        opening=false
        if epoch~=generation then return end
        if not result.ok then return notify(messages[result.error] or 'Menü nicht verfügbar.') end
        if IsNuiFocused() or not ESX.IsPlayerLoaded() then return end
        local ok,err=pcall(build,result)
        if not ok then clear() print('[rp_admin] '..tostring(err)) notify('Menü konnte nicht geöffnet werden.') end
    end)
end
RegisterNetEvent('rp_admin:open',function() if source==65535 then open() end end)
RegisterNetEvent('rp_admin:godmode',function(enabled,token)
    if source~=65535 or type(enabled)~='boolean' then return end
    if enabled and (not ctx or ctx.token~=token or not ESX.IsPlayerLoaded()) then return end
    setGod(enabled)
    if ctx then refresh(ctx) end
end)
local function register()
    exports.rp_core:rpRegisterInputAction({id='rp_admin:open',label='Administration',category='Menüs',defaultKey='F10',description='Adminmenü öffnen / schließen.'})
end
CreateThread(register)
AddEventHandler('rp_core:inputPressed',function(action) if action=='rp_admin:open' then open() end end)
AddEventHandler('onClientResourceStart',function(name) if name=='rp_core' then register() end end)
local function reset() clear() setGod(false) end
AddEventHandler('esx:onPlayerLogout',reset)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() or name=='rp_ui' or name=='rp_nativeui' or name=='rp_core' then reset() end
end)
CreateThread(function()
    while true do
        if god then
            if not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId()) or PlayerPedId()~=godPed or GetGameTimer()>lease then setGod(false)
            elseif not heartbeatBusy and GetGameTimer()>=nextHeartbeat then
                nextHeartbeat=GetGameTimer()+10000
                heartbeatBusy=true local epoch=modeEpoch
                CreateThread(function()
                    local result=request('heartbeat')
                    heartbeatBusy=false
                    if god and epoch==modeEpoch then
                        if result.ok and result.godmode then lease=GetGameTimer()+30000 else setGod(false) end
                    end
                end)
            end
        end
        if ctx and (not ESX.IsPlayerLoaded() or IsEntityDead(PlayerPedId())) then clear() end
        Wait(500)
    end
end)
