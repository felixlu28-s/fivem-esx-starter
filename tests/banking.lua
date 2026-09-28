-- Run real banking service/callbacks against deterministic ESX + SQL boundaries.
local base='server-data/resources/[custom]/rp_banking/'
local checks,clock=0,10000
local function check(v,m) assert(v,m) checks=checks+1 end
local function copy(t) if type(t)~='table' then return t end local c={} for k,v in pairs(t) do c[k]=copy(v) end return c end
local encoded,serial={},0
json={encode=function(v) serial=serial+1 encoded[tostring(serial)]=copy(v) return tostring(serial) end,decode=function(v) return copy(encoded[v]) end}
local players,positions,buckets,health,persisted,vehicles={},{},{},{},{},{}
local callbacks,events,commands,notifications={},{},{},{}
local caller='rp_banking'
function GetInvokingResource() return caller end
function GetCurrentResourceName() return 'rp_banking' end
function GetResourceState() return 'missing' end
function GetGameTimer() return clock end
function GetPlayerPed(id) return players[id] and id or 0 end
function GetVehiclePedIsIn(id) return vehicles[id] or 0 end
function GetEntityHealth(id) return health[id] or 200 end
function GetEntityCoords(id) return positions[id] end
function GetPlayerRoutingBucket(id) return buckets[id] or 0 end
function CreateThread(fn) fn() end
function RegisterCommand(n,fn) commands[n]=fn end
function AddEventHandler(n,fn) events[n]=events[n] or {} events[n][#events[n]+1]=fn end
function RegisterNetEvent(n,fn) AddEventHandler(n,fn) end
function TriggerClientEvent(n,id,...) notifications[#notifications+1]={name=n,id=id} end
local function emit(n,id,...)
    source=id for _,fn in ipairs(events[n] or {}) do fn(...) end
end
local saved,failSave,failCredit,failCommit,loseReply,lostInsert={},false,false,false,false,false
function ExecuteCommand(s) saved[#saved+1]=assert(tonumber(s:match('^save (%d+)$'))) end
function Wait(ms)
    clock=clock+ms
    if not failSave then
        local batch=saved saved={}
        for _,id in ipairs(batch) do if players[id] then
            persisted[players[id].identifier]=copy(players[id].balances)
            caller='es_extended' emit('esx:playerSaved',0,id,players[id]) caller='rp_banking'
        end end
    end
end
local ESX={GetPlayerFromId=function(id)
    local p=players[id] if not p then return nil end
    -- Snapshot object identity changes on every cross-resource call.
    return {identifier=p.identifier,spawned=true,getIdentifier=function()return p.identifier end,getName=function()return p.name end,
        getAccount=function(account)return {money=p.balances[account]} end,
        removeAccountMoney=function(account,n) p.balances[account]=p.balances[account]-n return true end,
        addAccountMoney=function(account,n) if failCredit then return false end p.balances[account]=p.balances[account]+n return true end}
end}
exports={es_extended={getSharedObject=function()return ESX end}}
lib={callback={register=function(n,fn) callbacks[n]=fn end}}
local receipts,history,nextId,nextHistory={},{},0,0
local ready,insertHook
MySQL={ready=function(fn)ready=fn end,single={},scalar={},query={},insert={},update={},transaction={}}
MySQL.single.await=function(sql,p)
    if sql:find('WHERE actor',1,true) then for _,r in pairs(receipts) do if r.actor==p[1] and r.request_id==p[2] then return copy(r) end end
    elseif sql:find('WHERE id',1,true) then return copy(receipts[p[1]]) end
end
MySQL.scalar.await=function(sql,p)
    if sql:find('SELECT accounts',1,true) then return persisted[p[1]] and json.encode(persisted[p[1]]) end
    for _,r in pairs(receipts) do if (r.status=='intent' or r.status=='review') and (r.actor==p[1] or r.target==p[2]) then return r.id end end
end
MySQL.query.await=function(sql,p)
    if not p then return {} end
    local result={}
    for i=#history,1,-1 do local r=history[i] if r.character==p[1] and (p[2]==0 or r.id<p[2]) then
        result[#result+1]={id=r.id,kind=r.kind,amount=r.amount,balance=r.balance,counterparty=r.counterparty,note=r.note,time=r.time}
        if #result==p[4] then break end
    end end
    return result
end
local function addHistory(p)
    for _,row in ipairs(history) do if row.character==p[1] and row.reference==p[2] then return end end
    nextHistory=nextHistory+1
    history[#history+1]={id=nextHistory,character=p[1],reference=p[2],kind=p[3],amount=p[4],balance=p[5],counterparty=p[6],note=p[7],time=os.time()}
end
MySQL.insert.await=function(sql,p)
    if sql:find('rp_banking_transactions',1,true) then
        for _,r in pairs(receipts) do assert(not (r.actor==p[1] and r.request_id==p[3]),'unique actor/request') end
        nextId=nextId+1 receipts[nextId]={id=nextId,actor=p[1],target=p[2],request_id=p[3],fingerprint=p[4],payload=p[5],status='intent'}
        if insertHook then local hook=insertHook insertHook=nil hook() end
        if lostInsert then lostInsert=false error('injected lost insert acknowledgement') end
        return nextId
    end
    addHistory({p[1],'external:'..nextHistory,p[2],p[3],p[4],'',p[5]})
end
MySQL.update.await=function(sql,p)
    local r=receipts[p[1]] or receipts[p[2]]
    if not r or (sql:find("status = 'intent'",1,true) and r.status~='intent') then return 0 end
    r.status=sql:match("SET status = '(%w+)'") return 1
end
MySQL.transaction.await=function(queries)
    if failCommit then error('injected ledger commit failure') end
    for _,q in ipairs(queries) do
        if q.query:find('UPDATE',1,true) then receipts[q.values[2]].status='completed'
        else addHistory(q.values) end
    end
    if loseReply then loseReply=false error('injected lost ledger acknowledgement') end
    return true
end
dofile(base..'shared/config.lua') dofile(base..'shared/locations.lua')
dofile(base..'server/service.lua') dofile(base..'server/transactions.lua') dofile(base..'server/main.lua')
local B=Banking ready()
local function player(id,identifier)
    players[id]={identifier=identifier,name='Character '..id,balances={money=1000,bank=5000}}
    persisted[identifier]=copy(players[id].balances) positions[id]=copy(B.locations[1])
end
player(1,'char1:one-account') player(2,'char2:one-account') player(3,'char1:other-account')
local function open(id,model) clock=clock+1200 return callbacks['rp_banking:open'](id,1,model or 'prop_fleeca_atm') end
local function action(id,p)
    clock=clock+1200 p.session=p.session or (B.views[id] and B.views[id].token)
    return callbacks['rp_banking:action'](id,p)
end
local function txn(id,kind,amount,extra)
    local p={action='transact',kind=kind,amount=amount,request=B.token(),note=''} for k,v in pairs(extra or {}) do p[k]=v end
    return action(id,p),p
end
check(B.ready and #B.locations==70,'official configured world locations loaded')
check(not open(99).ok,'unknown player cannot bank')
positions[1].x=0 check(not open(1).ok,'remote ATM rejected') positions[1]=copy(B.locations[1])
buckets[1]=9 check(not open(1).ok,'wrong bucket rejected') buckets[1]=0
health[1]=0 check(not open(1).ok,'dead actor rejected') health[1]=200
vehicles[1]=9 check(not open(1).ok,'actor in vehicle rejected') vehicles[1]=nil
check(not open(1,'not_an_atm').ok,'unlisted model rejected')
check(open(1).banking.brand=='fleeca' and open(2,'prop_atm_03').banking.brand=='maze' and open(3,'prop_atm_02').banking.brand=='liberty','model-specific UI shares ESX accounts')
for _,amount in ipairs({0,-1,0.5,'100',{},1000001,math.huge,0/0}) do check(not txn(1,'deposit',amount).ok,'invalid amount rejected') end
check(players[1].balances.money==1000 and #history==0,'invalid requests do not change money/history')
local result,p=txn(1,'deposit',200)
check(result.ok and players[1].balances.money==800 and players[1].balances.bank==5200,'deposit via ESX cash and bank APIs')
check(result.banking.history[1].amount==200 and result.banking.history[1].balance==5200,'durable bank history records result')
check(action(1,p).ok and players[1].balances.bank==5200 and #history==1,'same request never duplicates a deposit')
p.amount=201 check(action(1,p).error=='request_reused','reused request cannot change amount')
check(txn(1,'withdraw',100).ok and players[1].balances.money==900 and players[1].balances.bank==5100,'withdrawal conserves total money')
check(txn(1,'withdraw',999999).error=='insufficient_funds','cannot overdraw')
check(players[2].balances.bank==5000 and #open(2).banking.history==0,'characters on same license isolated')
check(not action(1,{action='recipient',id=1}).ok and not action(1,{action='recipient',id=99}).ok,'self/offline recipients rejected')
local resolved=action(1,{action='recipient',id=3})
check(resolved.ok and resolved.bankRecipient.name=='Character 3' and not resolved.bankRecipient.identifier,'recipient returns name with opaque token')
result,p=txn(1,'transfer',350,{recipient=resolved.bankRecipient.token,note='Dinner'})
check(result.ok and players[1].balances.bank==4750 and players[3].balances.bank==5350,'transfer debits/credits online ESX players')
check(action(1,p).ok and players[3].balances.bank==5350,'transfer replay credits exactly once')
local inbox=open(3).banking.history
check(inbox[1].kind=='received' and inbox[1].counterparty=='Character 1','receiver gets own history with sender name')
resolved=action(1,{action='recipient',id=3})
emit('playerDropped',3) player(3,'char1:replacement-player')
check(txn(1,'transfer',20,{recipient=resolved.bankRecipient.token}).error=='recipient_changed','recycled source cannot receive another character transfer')
local token=B.views[1].token
emit('esx:playerLogout',0,1) player(1,'char1:replacement-actor')
check(not action(1,{action='transact',kind='deposit',amount=100,note='',request=B.token(),session=token}).ok,'old character token rejected')
open(1)
insertHook=function() positions[1].x=0 end
check(not txn(1,'deposit',50).ok and players[1].balances.money==1000,'distance rechecked after SQL yield')
check(receipts[nextId].status=='cancelled','cancelled pre-mutation intent does not hold account') positions[1]=copy(B.locations[1])
open(1) insertHook=function() players[1].balances.money=999 end
check(txn(1,'deposit',50).error=='balance_changed' and players[1].balances.bank==5000,'concurrent external balance change aborts before mutation')
failSave=true result,p=txn(1,'deposit',10)
check(not result.ok and result.banking.held and receipts[nextId].status=='review','unconfirmed ESX save is held for audit')
local bankBefore=players[1].balances.bank
check(not action(1,p).ok and players[1].balances.bank==bankBefore,'uncertain mutation never replayed')
check(txn(1,'withdraw',1).error=='review_required','new request cannot bypass uncertain payment')
commands.rp_bank_review(1,{tostring(nextId),'completed','forged client audit'})
check(receipts[nextId].status=='review','review command console only')
failSave=false Wait(50)
commands.rp_bank_review(0,{tostring(nextId),'completed','Verified ESX saved accounts'})
check(receipts[nextId].status=='completed' and not B.hold(players[1].identifier) and players[1].balances.bank==bankBefore,'console audit closes receipt without moving money')
loseReply=true result,p=txn(1,'withdraw',5)
local historyCount=#history
check(not result.ok and receipts[nextId].status=='completed','lost journal ack keeps completed authority')
check(action(1,p).ok and #history==historyCount,'retry after lost ack does not duplicate funds/history')
lostInsert=true result,p=txn(1,'deposit',25)
bankBefore=players[1].balances.bank
check(not result.ok and B.hold(players[1].identifier),'lost intent acknowledgement blocks new requests')
check(not action(1,p).ok and players[1].balances.bank==bankBefore,'uncertain intent never guessed/replayed')
commands.rp_bank_review(0,{tostring(nextId),'cancelled','Verified no ESX mutation occurred'})
check(not B.hold(players[1].identifier),'explicit no-mutation audit releases hold')
resolved=action(1,{action='recipient',id=3})
failCredit=true result,p=txn(1,'transfer',30,{recipient=resolved.bankRecipient.token}) failCredit=false
check(not result.ok and B.hold(players[1].identifier) and B.hold(players[3].identifier),'partial transfer failure holds both characters')
local bankTarget=players[3].balances.bank
check(not action(1,p).ok and players[3].balances.bank==bankTarget,'failed credit cannot be replayed by client')
-- Official external credits append history; no arbitrary client logging event exists.
caller='es_extended' players[2].balances.bank=5500 emit('esx:addAccountMoney',0,2,'bank',500,'salary') caller='rp_banking'
check(open(2).banking.history[1].kind=='credit','salary-style ESX account event appears in history')
local before=#history
caller='es_extended' emit('esx:addAccountMoney',0,2,'bank',100,'rp_banking:test') caller='rp_banking'
check(#history==before,'bank service movements not logged twice')
emit('esx:addAccountMoney',0,2,'bank',999999,'forged')
check(#history==before,'foreign log event ignored')
check(not action(2,{action='history',before=-1}).ok,'history cursor bounded and character-scoped')
caller='es_extended' players[2].balances.bank=6000 emit('esx:setAccountMoney',0,2,'bank',6000,'admin') caller='rp_banking'
local adjustment=open(2).banking.history[1]
check(adjustment.kind=='adjustment' and adjustment.amount==0 and adjustment.balance==6000,'absolute ESX setter logs resulting balance, never invents a delta')
player(4,'char1:concurrent-recipient') open(4)
resolved=action(2,{action='recipient',id=4})
insertHook=function()
    check(txn(2,'withdraw',1).error=='busy','parallel payer operation cannot pass character lock')
    check(txn(4,'withdraw',1).error=='busy','parallel recipient operation cannot pass character lock')
end
check(txn(2,'transfer',10,{recipient=resolved.bankRecipient.token}).ok,'locked transfer finishes without deadlock')
check(next(B.locks)==nil,'all success/error paths release transaction locks')
print(('PASS: %d banking ESX / security / replay / character / journal checks'):format(checks))
