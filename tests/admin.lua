local callbacks,events,commands,sent={},{},{},{}
local now,passed=10000,0
local function check(v,m) assert(v,m) passed=passed+1 end
local function person(id,group,identifier)
    local p={source=id,identifier=identifier or 'char1:license:'..id,group=group,accounts={money=20,bank=40},grants=0}
    p.getGroup=function() return p.group end
    p.getAccount=function(name) return p.accounts[name] and {money=p.accounts[name]} end
    p.addAccountMoney=function(name,n) p.accounts[name]=p.accounts[name]+n p.grants=p.grants+1 end
    p.showNotification=function() end
    return p
end
local players={[1]=person(1,'owner'),[2]=person(2,'user')}
exports={es_extended={getSharedObject=function() return {
    GetPlayerFromId=function(id) return players[id] end,
    RegisterCommand=function(name,groups,fn) commands[name]=fn end,
} end}}
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
function GetGameTimer() return now end
function TriggerClientEvent(name,id,...) sent[#sent+1]={name=name,id=id,args={...}} end
function AddEventHandler(name,fn) events[name]=fn end
function GetCurrentResourceName() return 'rp_admin' end
dofile('server-data/resources/[custom]/rp_admin/server/main.lua')
local function call(name,id,...) return callbacks['rp_admin:'..name](id,...) end
local function tick() now=now+1100 end
check(not call('open',2).ok,'ordinary players cannot open admin')
local m=call('open',1)
check(m.ok and m.target==1,'owner opens self target')
check(not call('money',2,m.token,m.nonce,'money',10).ok,'capability cannot be used by another player')
check(not call('money',1,m.token,m.nonce,'black_money',10).ok,'account allowlist') tick()
check(not call('money',1,m.token,m.nonce,'money',0/0).ok,'NaN rejected') tick()
check(not call('money',1,m.token,m.nonce,'money',-1).ok,'negative rejected') tick()
check(not call('money',1,m.token,m.nonce,'money',1.5).ok,'fraction rejected') tick()
check(not call('money',1,m.token,m.nonce,'money',1000001).ok,'limit enforced') tick()
local r=call('money',1,m.token,m.nonce,'money',100)
check(r.ok and players[1].accounts.money==120 and players[1].grants==1,'ESX account API adds cash')
check(call('money',1,m.token,m.nonce,'money',100).ok and players[1].grants==1,'lost response retry credits only once')
check(not call('money',1,m.token,m.nonce,'bank',100).ok,'changed replay rejected')
check(not call('money',1,m.token,r.nonce,'money',100).ok,'rapid second payment limited') tick()
local target=call('target',1,m.token,2)
check(target.ok and target.target==2,'target resolved server-side')
check(call('money',1,m.token,target.nonce,'bank',200).ok and players[2].accounts.bank==240,'bank targets selected ESX player') tick()
local latest=call('target',1,m.token,2)
source=2 events.playerDropped()
players[2]=person(2,'user')
check(not call('money',1,m.token,latest.nonce,'bank',100).ok,'reused ID and identical character cannot inherit old target session') tick()
check(call('action',1,m.token,'items').ok and sent[#sent].name=='rp_inventory:adminOpen','existing item menu reused') tick()
check(call('action',1,m.token,'noclip').ok and sent[#sent].name=='esx:noclip','official noclip event reused') tick()
check(call('action',1,m.token,'waypoint').ok and sent[#sent].name=='esx:tpm','official waypoint event reused') tick()
check(not call('action',1,m.token,'arbitrary_event').ok,'event allowlist') tick()
check(call('action',1,m.token,'godmode',true).ok and sent[#sent].args[1]==true,'authorized godmode')
check(call('heartbeat',1).godmode,'mode lease granted')
players[1].group='user' now=now+6000
check(not call('heartbeat',1).godmode,'permission revocation terminates lease')
check(not call('action',1,m.token,'items').ok,'rights rechecked for every action')
players[1].group='owner' tick()
events['esx:playerLogout'](1)
check(not call('target',1,m.token,1).ok,'logout invalidates menu')
m=call('open',1) now=now+600001
check(not call('money',1,m.token,m.nonce,'money',1).ok,'menu expires')
commands.rp_money(players[1],{account='bank',amount=1000},function(e) error(e) end)
check(players[1].accounts.bank==1040,'self money command uses same ESX grant')
commands.rp_admin(players[1])
check(sent[#sent].name=='rp_admin:open','server command opens authenticated menu')
print(('PASS: %d admin permission/account/replay/session/ESX adapter assertions'):format(passed))
