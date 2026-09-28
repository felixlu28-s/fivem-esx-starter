local ESX = exports.es_extended:getSharedObject()
local menus, epochs, rates, gods = {}, {}, {}, {}
local groups = { owner=true, admin=true }
local serial = 0
local function ticket()
    serial=serial+1
    return ('admin_%x_%x_%x'):format(GetGameTimer(),math.random(0,0x7fffffff),serial)
end
local function integer(n,low,high) return type(n)=='number' and n==n and n%1==0 and n>=low and n<=high end
local function player(id)
    if not integer(id,1,2147483647) then return end
    local p=ESX.GetPlayerFromId(id)
    return p and p.identifier and p
end
local function admin(id)
    local p=player(id)
    return p and groups[p.getGroup()] and p
end
local function rate(id,key,ms)
    rates[id]=rates[id] or {}
    local now=GetGameTimer()
    if (rates[id][key] or 0)>now then return false end
    rates[id][key]=now+ms return true
end
local function identity(id,p) return {id=id,identifier=p.identifier,epoch=epochs[id] or 0} end
local function current(ref)
    local p=ref and player(ref.id)
    return p and p.identifier==ref.identifier and (epochs[ref.id] or 0)==ref.epoch and p
end
local function menu(id,token)
    local m=menus[id]
    return type(token)=='string' and admin(id) and m and m.token==token and current(m.actor)
        and m.expires>GetGameTimer() and m
end
local function reply(m)
    return {ok=true,token=m.token,nonce=m.nonce,target=m.target.id,godmode=gods[m.actor.id]~=nil}
end
lib.callback.register('rp_admin:open',function(source)
    local p=admin(source)
    if not p or not rate(source,'open',700) then return {ok=false,error='forbidden'} end
    local ref=identity(source,p)
    local m={token=ticket(),nonce=ticket(),actor=ref,target=ref,expires=GetGameTimer()+600000}
    menus[source]=m
    return reply(m)
end)
lib.callback.register('rp_admin:target',function(source,token,id)
    local m=menu(source,token)
    if not m or not rate(source,'target',350) then return {ok=false,error='forbidden'} end
    local p=player(id)
    if not p then return {ok=false,error='invalid_target'} end
    m.target,m.nonce,m.last=identity(id,p),ticket(),nil
    return reply(m)
end)
local function grant(actor,target,account,amount)
    if (account~='money' and account~='bank') or not integer(amount,1,1000000) then return false,'invalid_amount' end
    local balance=target.getAccount(account)
    if not balance or type(balance.money)~='number' or balance.money+amount>2147483647 then return false,'invalid_account' end
    target.addAccountMoney(account,amount,'RP administration')
    print(('[rp_admin] money actor=%d target=%d account=%s amount=%d'):format(actor,target.source,account,amount))
    return true
end
lib.callback.register('rp_admin:money',function(source,token,nonce,account,amount)
    local m=menu(source,token)
    if not m or type(nonce)~='string' or #nonce>80 then return {ok=false,error='forbidden'} end
    if m.last and m.last.nonce==nonce then
        if m.last.account~=account or m.last.amount~=amount then return {ok=false,error='stale_request'} end
        return m.last.result
    end
    if m.nonce~=nonce then return {ok=false,error='stale_request'} end
    if not rate(source,'money',1000) then return {ok=false,error='rate_limited'} end
    local target=current(m.target)
    if not target then return {ok=false,error='invalid_target'} end
    local ok,err=grant(source,target,account,amount)
    if not ok then return {ok=false,error=err} end
    m.nonce=ticket()
    local result=reply(m)
    m.last={nonce=nonce,account=account,amount=amount,result=result}
    return result
end)
lib.callback.register('rp_admin:action',function(source,token,action,enabled)
    local m=menu(source,token)
    if not m or not rate(source,'action',700) then return {ok=false,error='forbidden'} end
    if action=='godmode' and type(enabled)=='boolean' then
        gods[source]=enabled and identity(source,admin(source)) or nil
        TriggerClientEvent('rp_admin:godmode',source,enabled,m.token)
    elseif action=='items' then TriggerClientEvent('rp_inventory:adminOpen',source)
    elseif action=='noclip' then TriggerClientEvent('esx:noclip',source)
    elseif action=='waypoint' then TriggerClientEvent('esx:tpm',source)
    else return {ok=false,error='invalid_action'} end
    return {ok=true,godmode=gods[source]~=nil}
end)
-- Only admins with an active temporary mode send a heartbeat; never per player/frame.
lib.callback.register('rp_admin:heartbeat',function(source)
    if not rate(source,'heartbeat',5000) then return {ok=false} end
    local ref=gods[source]
    local enabled=ref and current(ref) and admin(source)~=nil or false
    if not enabled then gods[source]=nil end
    return {ok=true,godmode=enabled}
end)
ESX.RegisterCommand('rp_admin',{'admin','owner'},function(p)
    if p and admin(p.source) then TriggerClientEvent('rp_admin:open',p.source) end
end,false,{help='Adminmenü öffnen (F10)',validate=true,arguments={}})
ESX.RegisterCommand('rp_money',{'admin','owner'},function(p,args,showError)
    if not p or not admin(p.source) or not rate(p.source,'money',1000) then return end
    local ok,err=grant(p.source,p,args.account,args.amount)
    if not ok then showError('money oder bank, Betrag 1–1000000. '..tostring(err))
    else p.showNotification(('Du hast $%d erhalten (%s).'):format(args.amount,args.account)) end
end,false,{help='Geld an eigenen aktiven Charakter geben',validate=true,arguments={
    {name='account',help='money oder bank',type='string'}, {name='amount',help='Betrag',type='number'},
}})
local function clear(id)
    epochs[id]=(epochs[id] or 0)+1 menus[id],rates[id],gods[id]=nil,nil,nil
    TriggerClientEvent('rp_admin:godmode',id,false)
end
AddEventHandler('esx:playerLogout',clear)
AddEventHandler('playerDropped',function() clear(source) end)
AddEventHandler('onResourceStop',function(name)
    if name==GetCurrentResourceName() then for id in pairs(gods) do TriggerClientEvent('rp_admin:godmode',id,false) end end
end)
