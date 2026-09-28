"""Actual garage editor Lua handlers against isolated MariaDB tables."""
import json
import subprocess
import uuid
from pathlib import Path
import pymysql
from lupa.lua54 import LuaRuntime, lua_type

config=json.loads(subprocess.check_output(['docker','compose','config','--format','json'],text=True))['services']['db']['environment']
port=int(subprocess.check_output(['docker','compose','port','db','3306'],text=True).strip().rsplit(':',1)[1])
db=pymysql.connect(host='127.0.0.1',port=port,user=config['MARIADB_USER'],password=config['MARIADB_PASSWORD'],database=config['MARIADB_DATABASE'],autocommit=True,charset='utf8mb4',cursorclass=pymysql.cursors.DictCursor)
prefix='rp_gt_'+uuid.uuid4().hex[:10]
locations,vehicles=prefix+'_locations',prefix+'_vehicles'
lua=LuaRuntime(unpack_returned_tuples=True)
def convert(value):
    if lua_type(value)!='table':return value
    keys=list(value.keys())
    if not keys or all(isinstance(k,(int,float)) and k==i+1 for i,k in enumerate(sorted(keys))):return [convert(value[i]) for i in range(1,len(keys)+1)]
    return {k:convert(v) for k,v in value.items()}
lost=[False]
def query(kind,statement,params=None):
    statement=statement.replace('rp_vehicle_garages',locations).replace('owned_vehicles',vehicles).replace('?','%s')
    with db.cursor() as cursor:
        changed=cursor.execute(statement,tuple(convert(params)) if params else ())
        if lost[0] and statement.startswith('UPDATE '+locations):
            lost[0]=False
            raise RuntimeError('Simulated SQL acknowledgement loss AFTER commit')
        if kind=='query':return lua.table_from(cursor.fetchall(),recursive=True)
        if kind=='single':
            row=cursor.fetchone();return lua.table_from(row,recursive=True) if row else None
        if kind=='scalar':return next(iter(cursor.fetchone().values()))
        return changed
lua.globals().query=query
lua.globals().encode=lambda value:json.dumps(convert(value),ensure_ascii=False)
lua.globals().decode=lambda value:lua.table_from(json.loads(value),recursive=True)
lua.globals().lose_reply=lambda:lost.__setitem__(0,True)
base=Path('server-data/resources/[custom]/rp_vehicles')
try:
    with db.cursor() as cur:
        cur.execute((base/'migrations/002_garage_locations.sql').read_text(encoding='utf-8').replace('rp_vehicle_garages',locations))
        cur.execute(f'CREATE TABLE {vehicles} (plate VARCHAR(12) PRIMARY KEY,parking VARCHAR(48))')
    lua.execute(r'''
now=0 count=0 events={} callbacks={} commands={} busy=false
local threads,notices={},{}
function check(v,label) assert(v,label) count=count+1 end
function GetGameTimer() return now end
function Wait(ms) coroutine.yield(ms) end
function CreateThread(fn)
    local co=coroutine.create(fn) threads[#threads+1]=co
    local ok,err=coroutine.resume(co) assert(ok,err)
end
function TriggerClientEvent(name,id) notices[#notices+1]={name=name,id=id} end
local function tick()
    now=now+2000
    for _,co in ipairs(threads) do local ok,err=coroutine.resume(co) assert(ok,err) end
end
function GetPlayerPed(id) return id end
function GetEntityHealth() return 200 end
function GetPlayerRoutingBucket(id) return players[id].bucket or 0 end
function GetEntityCoords(id) return players[id].pos end
function RegisterNetEvent(n,f) events[n]=f end AddEventHandler=RegisterNetEvent
function GetCurrentResourceName() return 'rp_vehicles' end
json={encode=encode,decode=decode}
lib={callback={register=function(n,f) callbacks[n]=f end}}
local esx={GetPlayerFromId=function(id) return players[id] end,RegisterCommand=function(n,_,fn) commands[n]=fn end}
exports={es_extended={getSharedObject=function() return esx end}}
MySQL={ready=function(fn) fn() end}
for _,kind in ipairs({'query','single','scalar','update'}) do MySQL[kind]={await=function(sql,p) return query(kind,sql,p) end} end
dofile('server-data/resources/[custom]/rp_vehicles/shared/config.lua')
dofile('server-data/resources/[custom]/rp_vehicles/shared/rules.lua')
dofile('server-data/resources/[custom]/rp_vehicles/shared/schema.lua')
local R=Garage.Rules
local default=R.copy(Garage.Config.garages.la_mesa)
players={}
for id=1,3 do players[id]={identifier='char'..id..':license:test',source=id,pos=R.copy(default.interaction),getGroup=function() return id==3 and 'user' or 'owner' end} end
GlobalState={} Garage.Service={busy=function() return busy end}
dofile('server-data/resources/[custom]/rp_vehicles/server/locations.lua')
check(Garage.Locations.ready,'catalogue loads and seeds migration')
local function call(name,id,...) now=now+1000 return callbacks['rp_vehicles:'..name](id,...) end
players[1].bucket=10001
local private=call('locations',1)
check(private.ok and #private.garages==0,'private login receives no public garages but subscribes to changes')
notices={} tick() check(#notices==0,'stable instance creates no catalogue traffic')
players[1].bucket=0 tick()
check(#notices==1 and notices[1].id==1 and notices[1].name=='rp_vehicles:locationsChanged','entering world notifies only affected subscriber')
check(#call('locations',1).garages==1,'world catalogue includes La Mesa')
notices={} for _=1,15 do tick() end check(#notices==0,'stable world never broadcasts recurring catalogues')
local probe=call('editorOpen',1)
source=1 events['rp_vehicles:editorClose'](probe.token)
players[1].bucket=10001 tick()
check(#notices==1 and notices[1].id==1,'closing editor preserves world-change subscription')
notices={} events['esx:playerLogout'](1) players[1].bucket=0 tick()
check(#notices==0,'logout removes catalogue subscription')
call('locations',1) source=1 events.playerDropped() players[1].bucket=10001 tick()
check(#notices==0,'disconnect removes subscription before server ID reuse')
players[1].bucket=0
check(not call('editorOpen',3).ok,'non-admin rejected')
local a=call('editorOpen',1) local b=call('editorOpen',2)
check(a.ok and #a.garages==1,'owner catalogue')
local pick=call('editorSelect',1,a.token,'la_mesa')
check(pick.ok,'owner reserves garage while editing')
check(not call('editorSelect',2,b.token,'la_mesa').ok,'another admin cannot edit same live gate')
local g=pick.garage
local function save(value,remove,key,revision) return call('editorSave',1,key or a.token,'la_mesa',revision or g.revision,value,remove or false) end
local forged=R.copy(g) forged.clerk.model='rhino'
check(not save(forged).ok,'NPC allowlist')
forged=R.copy(g) forged.gate.z=0/0 check(not save(forged).ok,'NaN coordinates')
forged=R.copy(g) forged.parking.x=forged.parking.x+1000 check(not save(forged).ok,'bounded geometry')
forged=R.copy(g) forged.outward[25]=R.copy(g.parking) check(not save(forged).ok,'sparse oversized path')
players[1].pos.x=0 check(not save(g).ok,'remote save denied') players[1].pos=R.copy(g.interaction)
busy=true check(not save(g).ok,'active valet prevents edits') busy=false
g.label='Neue Garage mit Umlauten ä'
local saved=save(g) check(saved.ok and saved.garage.revision==2,'revision CAS updates persisted garage')
check(not save(g).ok,'stale version refused') g=saved.garage
lose_reply() g.label='Acknowledged after re-read'
saved=save(g) check(saved.ok and saved.garage.revision==3,'SQL commit/reply loss reconciles from durable row') g=saved.garage
query('update','INSERT INTO owned_vehicles (plate,parking) VALUES (?,?)',{'TEST','la_mesa'})
check(not save(g,true).ok,'delete cannot orphan owned vehicles')
query('update','DELETE FROM owned_vehicles WHERE plate=?',{'TEST'})
check(save(g,true).ok and not Garage.Config.garages.la_mesa,'soft delete removes runtime garage')
check(query('scalar','SELECT deleted FROM rp_vehicle_garages WHERE id=?',{'la_mesa'})==1,'archived payload retained')
-- New locations use generated IDs and server-checked ESX actor, never client row IDs.
local c=call('editorOpen',1) check(call('editorSelect',1,c.token,false).ok,'new draft')
local fresh=R.copy(default) fresh.label='New garage'
local created=call('editorSave',1,c.token,false,0,fresh,false)
check(created.ok and created.garage.id~='la_mesa','new stable garage ID')
check(not call('editorSave',1,c.token,false,0,fresh,false).ok,'creation token consumed; no duplicate on replay')
check(call('editorSave',1,created.token,created.garage.id,1,created.garage,false).ok,'created garage remains reserved for subsequent edits')
players[1].identifier='char9:license:test'
check(not call('editorSave',1,created.token,created.garage.id,2,created.garage,false).ok,'character switch invalidates capability')
players[1].identifier='char1:license:test'
source=1 events['esx:playerLogout'](1)
check(not Garage.Locations.reserved[created.garage.id],'logout releases garage lock')
-- Resource reload reads durable rows and never resurrects soft-deleted defaults.
dofile('server-data/resources/[custom]/rp_vehicles/server/locations.lua')
check(Garage.Locations.ready and not Garage.Config.garages.la_mesa and Garage.Config.garages[created.garage.id].revision==2,'durable reload and archive')
print(('garage-locations-database: %d actual Lua/MariaDB checks passed'):format(count))
''')
finally:
    with db.cursor() as cur:
        for table in (locations,vehicles):
            assert table.startswith(prefix+'_')
            cur.execute(f'DROP TABLE IF EXISTS {table}')
    db.close()
