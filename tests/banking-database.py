"""Production Lua banking callbacks against disposable MariaDB tables; no user balances touched."""
import json
import subprocess
import uuid
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import pymysql
from lupa.lua54 import LuaRuntime, lua_type

config=json.loads(subprocess.check_output(['docker','compose','config','--format','json'],text=True))['services']['db']['environment']
port=int(subprocess.check_output(['docker','compose','port','db','3306'],text=True).strip().rsplit(':',1)[1])
def connect():
    return pymysql.connect(host='127.0.0.1',port=port,user=config['MARIADB_USER'],password=config['MARIADB_PASSWORD'],database=config['MARIADB_DATABASE'],autocommit=True,charset='utf8mb4',cursorclass=pymysql.cursors.DictCursor)
db=connect()
prefix='rp_bt_'+uuid.uuid4().hex[:12]
tables={name:prefix+'_'+name.removeprefix('rp_banking_') for name in ['rp_banking_transactions','rp_banking_history','users']}
base=Path('server-data/resources/[custom]/rp_banking')
lua=LuaRuntime(unpack_returned_tuples=True)
lost=[False]
def convert(value):
    if lua_type(value)!='table':return value
    keys=list(value.keys())
    if not keys or all(isinstance(k,(int,float)) and k==i+1 for i,k in enumerate(sorted(keys))):return [convert(value[i]) for i in range(1,len(keys)+1)]
    return {k:convert(v) for k,v in value.items()}
def sql(text):
    for old,new in tables.items():text=text.replace(old,new)
    return text.replace('?','%s')
def query(kind,statement,params=None):
    with db.cursor() as cur:
        changed=cur.execute(sql(statement),tuple(convert(params)) if params else ())
        if kind=='query':return lua.table_from(cur.fetchall(),recursive=True)
        if kind=='single':
            row=cur.fetchone();return lua.table_from(row,recursive=True) if row else None
        if kind=='scalar':
            row=cur.fetchone();return next(iter(row.values())) if row else None
        return cur.lastrowid if kind=='insert' else changed
def transaction(queries):
    db.begin()
    try:
        with db.cursor() as cur:
            for q in convert(queries):cur.execute(sql(q['query']),tuple(q['values']))
        db.commit()
    except Exception:
        db.rollback();raise
    if lost[0]:
        lost[0]=False
        raise RuntimeError('Injected lost journal commit acknowledgement')
    return True
lua.globals().query=query
lua.globals().transaction=transaction
lua.globals().encode=lambda value:json.dumps(convert(value),ensure_ascii=False)
lua.globals().decode=lambda value:lua.table_from(json.loads(value),recursive=True)
lua.globals().lose_reply=lambda:lost.__setitem__(0,True)
try:
    with db.cursor() as cur:
        migration=(base/'migrations/001_banking.sql').read_text(encoding='utf-8')
        for statement in migration.split(';'):
            if statement.strip():cur.execute(sql(statement))
        cur.execute(f'CREATE TABLE {tables["users"]} (identifier VARCHAR(96) COLLATE utf8mb4_bin PRIMARY KEY, accounts LONGTEXT NOT NULL CHECK (JSON_VALID(accounts))) CHARACTER SET utf8mb4')
    lua.execute(r'''
checks=0 local now=10000 local caller='rp_banking'
local events,callbacks,commands,players,saves={},{},{},{},{}
local function check(v,m) assert(v,m) checks=checks+1 end
function GetInvokingResource() return caller end
function GetResourceState() return 'missing' end
function GetCurrentResourceName() return 'rp_banking' end
function GetGameTimer() return now end
function GetPlayerPed(id) return id end
function GetEntityHealth() return 200 end
function GetVehiclePedIsIn() return 0 end
function GetPlayerRoutingBucket() return 0 end
function GetEntityCoords() return Banking.locations[1] end
function AddEventHandler(n,fn) events[n]=fn end
RegisterNetEvent=AddEventHandler
function RegisterCommand(n,fn) commands[n]=fn end
function TriggerClientEvent() end
function CreateThread(fn) fn() end
function ExecuteCommand(value) saves[#saves+1]=tonumber(value:match('^save (%d+)$')) end
function Wait(ms)
    now=now+ms
    for _,id in ipairs(saves) do local p=players[id]
        query('update','UPDATE users SET accounts=? WHERE identifier=?',{json.encode(p.balances),p.identifier})
        caller='es_extended' events['esx:playerSaved'](id,{identifier=p.identifier}) caller='rp_banking'
    end
    saves={}
end
json={encode=encode,decode=decode}
lib={callback={register=function(n,fn) callbacks[n]=fn end}}
local esx={GetPlayerFromId=function(id)
    local p=players[id] if not p then return end
    return {spawned=true,identifier=p.identifier,getIdentifier=function() return p.identifier end,getName=function() return 'Person '..id end,
        getAccount=function(account) return {money=p.balances[account]} end,
        removeAccountMoney=function(account,n) p.balances[account]=p.balances[account]-n end,
        addAccountMoney=function(account,n) p.balances[account]=p.balances[account]+n end}
end}
exports={es_extended={getSharedObject=function() return esx end}}
MySQL={ready=function(fn) fn() end,transaction={await=transaction}}
for _,kind in ipairs({'query','single','scalar','update','insert'}) do MySQL[kind]={await=function(statement,p) return query(kind,statement,p) end} end
local base='server-data/resources/[custom]/rp_banking/'
dofile(base..'shared/config.lua') dofile(base..'shared/locations.lua') dofile(base..'server/service.lua')
dofile(base..'server/transactions.lua') dofile(base..'server/main.lua')
local B=Banking check(B.ready,'real migration accepted by service')
for id=1,2 do
    players[id]={identifier='char'..id..':license:banking-test',balances={money=1000,bank=5000}}
    query('insert','INSERT INTO users (identifier, accounts) VALUES (?,?)',{players[id].identifier,json.encode(players[id].balances)})
end
local function open(id) now=now+2000 return callbacks['rp_banking:open'](id,1,'prop_fleeca_atm') end
local function action(id,p) now=now+2000 p.session=B.views[id].token return callbacks['rp_banking:action'](id,p) end
local function payment(id,kind,amount,request,recipient)
    return action(id,{action='transact',kind=kind,amount=amount,note='Test',request=request,recipient=recipient})
end
check(open(1).ok and open(2).ok,'real empty history opens')
check(payment(1,'deposit',200,'deposit_001').ok,'deposit writes real journal/history')
check(payment(1,'deposit',200,'deposit_001').ok and players[1].balances.bank==5200,'database replay is idempotent')
check(query('scalar','SELECT COUNT(*) FROM rp_banking_history',{})==1,'no duplicate history')
local recipient=action(1,{action='recipient',id=2}).bankRecipient
check(payment(1,'transfer',100,'transfer_001',recipient.token).ok,'transfer journal commits both history rows')
check(open(2).banking.history[1].kind=='received' and players[2].balances.bank==5100,'receiver ESX and history updated')
check(#open(1).banking.history==2 and #open(2).banking.history==1,'same-license characters have isolated history')
lose_reply()
check(not payment(1,'withdraw',10,'lost_reply_001').ok,'lost commit response surfaces as error')
local cash=players[1].balances.money
check(payment(1,'withdraw',10,'lost_reply_001').ok and players[1].balances.money==cash,'real committed receipt recovers without re-debit')
local id=query('insert','INSERT INTO rp_banking_transactions (actor,target,request_id,fingerprint,payload) VALUES (?,?,?,?,?)',
    {players[1].identifier,players[2].identifier,'crash_intent_001','unused',json.encode({kind='transfer',amount=1,entries={}})})
check(B.hold(players[1].identifier) and B.hold(players[2].identifier),'pending receipt blocks both parties')
check(payment(1,'withdraw',1,'held_001').error=='review_required','new request cannot escape durable hold')
-- A resource restart drops memory, but keeps unresolved intents blocking.
dofile(base..'server/service.lua')
check(B.hold(players[1].identifier) and B.hold(players[2].identifier),'holds survive resource restart')
commands.rp_bank_review(0,{tostring(id),'cancelled','Verified isolated test never mutated money'})
check(not B.hold(players[1].identifier) and not B.hold(players[2].identifier),'console audit releases both holds')
open(1)
for n=1,23 do query('insert','INSERT INTO rp_banking_history (character_id,kind,amount,balance,note) VALUES (?,?,?,?,?)',
    {players[1].identifier,'credit',1,5100+n,'Salary'}) end
local first=action(1,{action='history'})
local second=action(1,{action='history',before=first.banking.history[20].id})
check(#first.banking.history==20 and first.banking.more and #second.banking.history==6 and not second.banking.more,'real indexed cursor pagination')
check(first.banking.history[20].id>second.banking.history[1].id,'pages do not overlap')
print(('PASS: %d real Lua / MariaDB bank checks'):format(checks))
''')
    # Unique actor/request is enforced even across separate SQL connections.
    def race(_):
        conn=connect()
        try:
            with conn.cursor() as cur:
                cur.execute(f"INSERT INTO {tables['rp_banking_transactions']} (actor,request_id,fingerprint,payload) VALUES (%s,%s,%s,%s)",('char1:race','same_request','race','{}'))
            return True
        except pymysql.err.IntegrityError:return False
        finally:conn.close()
    with ThreadPoolExecutor(max_workers=2) as pool:assert sum(pool.map(race,range(2)))==1
    with db.cursor() as cur:
        try:
            cur.execute(f"INSERT INTO {tables['rp_banking_transactions']} (actor,request_id,fingerprint,payload) VALUES ('bad','bad_json','bad','not json')")
            raise AssertionError('JSON constraint missing')
        except pymysql.err.OperationalError as err:assert err.args[0]==4025
    print('PASS: concurrent receipt uniqueness and JSON integrity constraints')
finally:
    with db.cursor() as cur:
        for table in tables.values():
            assert table.startswith(prefix+'_')
            cur.execute(f'DROP TABLE IF EXISTS {table}')
    db.close()
