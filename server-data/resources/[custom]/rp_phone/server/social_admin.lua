local S,ESX=PhoneService,exports.es_extended:getSharedObject()
local function admin(id,owner,epoch)
    if id==0 then return true end
    local p=ESX.GetPlayerFromId(id)
    return p and p.identifier==owner and (S.epochs[id] or 0)==epoch and (p.getGroup()=='admin' or p.getGroup()=='owner')
end
-- ESX applies the command ACL; recheck fresh permissions after asynchronous reads.
ESX.RegisterCommand('rp_ifruit_slots',{'admin','owner'},function(player,args,showError)
    local source=player and player.source or 0
    if not S.ready or not S.id(args.id) or not S.id(args.slots) or args.slots>5 or not S.rate(source,'social_admin',1000) then
        showError('Spieler-ID und Profilanzahl 1–5 angeben.') return
    end
    local actor,epoch=player and player.identifier or '',S.epochs[source] or 0
    if not admin(source,actor,epoch) then return end
    local target=ESX.GetPlayerFromId(args.id)
    if not target then showError('Spieler ist nicht online.') return end
    local owner,targetEpoch=target.identifier,S.epochs[args.id] or 0
    local function current()
        local p=ESX.GetPlayerFromId(args.id)
        return p and p.identifier==owner and (S.epochs[args.id] or 0)==targetEpoch and admin(source,actor,epoch)
    end
    if S.locks[owner] then showError('Handy wird gerade verwendet. Gleich erneut versuchen.') return end
    local lock={} S.locks[owner]=lock
    local ok,result=xpcall(function()
        if not current() then return false end
        MySQL.insert.await('INSERT IGNORE INTO rp_phone_profiles (owner,name) VALUES (?,?)',{owner,(target.getName() or 'Los Santos'):sub(1,60)})
        local id=MySQL.scalar.await('SELECT id FROM rp_phone_profiles WHERE owner=?',{owner})
        local count=MySQL.scalar.await('SELECT COUNT(*) FROM rp_phone_social_profiles WHERE owner=?',{id})
        if not current() then return false end
        if count>args.slots then showError('Es existieren bereits mehr Profile. Es wird nichts gelöscht.') return false end
        MySQL.update.await([[INSERT INTO rp_phone_social_accounts (owner,slots) VALUES (?,?)
            ON DUPLICATE KEY UPDATE slots=VALUES(slots)]],{id,args.slots})
        if current() then
            local text=('iFruit: %d Profil(e) für Spieler %d freigeschaltet.'):format(args.slots,args.id)
            if player then ESX.GetPlayerFromId(source).showNotification(text) else print(text) end
            ESX.GetPlayerFromId(args.id).showNotification(('iFruit: Du darfst jetzt %d Profile verwalten.'):format(args.slots))
        end
        print(('[rp_phone] admin %d set social slots for player %d to %d'):format(source,args.id,args.slots))
        return true
    end,debug.traceback)
    if S.locks[owner]==lock then S.locks[owner]=nil end
    if not ok then print('[rp_phone] Social account administration failed: '..tostring(result)) showError('iFruit-Verwaltung nicht verfügbar.') end
end,true,{help='iFruit-Profile für den aktiven ESX-Charakter freischalten',validate=true,arguments={
    {name='id',help='Online-Spieler-ID',type='number'},
    {name='slots',help='Erlaubte Profile, insgesamt 1–5',type='number'},
}})
