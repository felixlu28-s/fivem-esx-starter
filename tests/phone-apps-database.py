"""Actual Lua phone service against isolated MariaDB tables (requires lupa, pymysql)."""
import json
import base64
import re
import subprocess
import uuid
from pathlib import Path
import pymysql
from lupa.lua54 import LuaRuntime, lua_type

config=json.loads(subprocess.check_output(['docker','compose','config','--format','json'],text=True))
env=config['services']['db']['environment']
port=int(subprocess.check_output(['docker','compose','port','db','3306'],text=True).strip().rsplit(':',1)[1])
db=pymysql.connect(host='127.0.0.1',port=port,user=env['MARIADB_USER'],password=env['MARIADB_PASSWORD'],database=env['MARIADB_DATABASE'],charset='utf8mb4',autocommit=True,cursorclass=pymysql.cursors.DictCursor)
prefix='rp_pt_'+uuid.uuid4().hex[:10]+'_'
base=Path('server-data/resources/[custom]/rp_phone')
migration=(base/'migrations/001_phone_apps.sql').read_text(encoding='utf-8').replace('rp_phone_',prefix)
social_migration=(base/'migrations/002_social_profiles.sql').read_text(encoding='utf-8').replace('rp_phone_',prefix)
tables=re.findall(r'CREATE TABLE IF NOT EXISTS (\w+)',migration+social_migration)
lua=LuaRuntime(unpack_returned_tuples=True)

def from_lua(v):
    if lua_type(v)!='table': return v
    keys=list(v.keys())
    if not keys or all(isinstance(k,(int,float)) and k==i+1 for i,k in enumerate(sorted(keys))):
        return [from_lua(v[i]) for i in range(1,len(keys)+1)]
    return {k:from_lua(value) for k,value in v.items()}

def query(kind,sql,params=None):
    statement=sql.replace('rp_phone_',prefix).replace('?','%s')
    values=tuple(from_lua(params)) if params else ()
    with db.cursor() as cur:
        affected=cur.execute(statement,values)
        if kind=='query': return lua.table_from(cur.fetchall(),recursive=True)
        if kind=='single':
            row=cur.fetchone();return lua.table_from(row,recursive=True) if row else None
        if kind=='scalar':
            row=cur.fetchone();return next(iter(row.values())) if row else None
        if kind=='insert': return cur.lastrowid
        return affected

def transaction(statements):
    try:
        db.begin()
        with db.cursor() as cur:
            for statement in from_lua(statements):
                cur.execute(statement['query'].replace('rp_phone_',prefix).replace('?','%s'),tuple(statement['values']))
        db.commit()
        return True
    except Exception:
        db.rollback()
        raise

lua.globals().db_transaction=transaction
lua.globals().db_query=query
lua.globals().json_encode=lambda v:json.dumps(from_lua(v),ensure_ascii=False,separators=(',',':'))
lua.globals().json_decode=lambda v:lua.table_from(json.loads(v),recursive=True)
def jpeg_header(width=640, height=360):
    # Synthetic marker fixture: tests header bounds, not JPEG entropy decoding.
    image = (b'\xff\xd8\xff\xe0\x00\x42' + b'A'*64 + b'\xff\xc0\x00\x0b\x08'
        + height.to_bytes(2,'big') + width.to_bytes(2,'big') + b'\x01\x01\x11\x00\xff\xd9')
    return 'data:image/jpeg;base64,' + base64.b64encode(image).decode()
lua.globals().jpeg=jpeg_header()
lua.globals().jpegHuge=jpeg_header(60000,60000)
lua.globals().jpegOther=jpeg_header(320,180)
try:
    with db.cursor() as cur:
        for statement in migration.split(';'):
            if statement.strip():cur.execute(statement)
        # Existing phone identity migrates with its ID, name and handle intact.
        cur.execute(f"INSERT INTO {prefix}profiles (owner,name,handle,bio) VALUES ('char1:license:8','Legacy Eight','legacy_eight','Old bio')")
        cur.execute(f"INSERT INTO {prefix}photos (owner,nonce,image,created) VALUES (1,'legacy-photo','legacy-image',1)")
        cur.execute(f"INSERT INTO {prefix}posts (author,photo,nonce,caption,created) VALUES (1,1,'legacy-post','Legacy caption',1)")
        cur.execute(f'INSERT INTO {prefix}likes (post,profile) VALUES (1,1)')
        cur.execute(f"INSERT INTO {prefix}comments (post,author,nonce,body,created) VALUES (1,1,'legacy-comment','Legacy comment',1)")
        cur.execute(f'INSERT INTO {prefix}follows (follower,target) VALUES (1,1)')
        for statement in social_migration.split(';'):
            if statement.strip():cur.execute(statement)
        cur.execute(f'SELECT id,owner,handle,bio FROM {prefix}social_profiles')
        assert cur.fetchone()=={'id':1,'owner':1,'handle':'legacy_eight','bio':'Old bio'}
        cur.execute(f'SELECT p.id,p.caption,u.handle FROM {prefix}posts p JOIN {prefix}social_profiles u ON u.id=p.author')
        assert cur.fetchone()=={'id':1,'caption':'Legacy caption','handle':'legacy_eight'}
        for suffix in ['likes','comments','follows']:
            cur.execute(f'SELECT COUNT(*) AS count FROM {prefix}{suffix}')
            assert cur.fetchone()['count']==1
        # Delete only the temporary fixture before the independent action tests.
        cur.execute(f'DELETE FROM {prefix}posts WHERE id=1')
        cur.execute(f'DELETE FROM {prefix}photos WHERE id=1')
        cur.execute(f'DELETE FROM {prefix}follows WHERE follower=1')

    lua.execute(r'''
now=1000 checks=0 callbacks={} events={} players={} notifications={} nativeChannels={} threads={}
function check(v,label) assert(v,label) checks=checks+1 end
function GetGameTimer() return now end
os.time=function() return 1800000000+math.floor(now/1000) end
function GetPlayerPed(id) return players[id] and id or 0 end
function GetEntityHealth() return 200 end
function GetResourceState() return 'missing' end
function GetCurrentResourceName() return 'rp_phone' end
local kvp={} function GetResourceKvpString(k) return kvp[k] end function SetResourceKvp(k,v) kvp[k]=v end
function GetConvar(_,fallback) return fallback end
function AddEventHandler(name,fn) events[name]=events[name] or {} table.insert(events[name],fn) end
RegisterNetEvent=AddEventHandler
function emit(name,id,data) source=id for _,f in ipairs(events[name] or {}) do f(data) end end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) return coroutine.yield(ms) end
function TriggerClientEvent(name,id,data) notifications[#notifications+1]={name=name,id=id,data=data} end
function CreateVoiceChannel() local id=#nativeChannels+1 nativeChannels[id]={} return id end
function AddPlayerToVoiceChannel(channel,id) nativeChannels[channel][id]=true end
function SetPlayerMutedInVoiceChannel(channel,id,muted) nativeChannels[channel][id]=not muted end
function RemovePlayerFromVoiceChannel(channel,id) nativeChannels[channel][id]=nil end
function DeleteVoiceChannel(channel) nativeChannels[channel]={} end
function tick(ms) now=now+ms for _,co in ipairs(threads) do if coroutine.status(co)~='dead' then local ok,err=coroutine.resume(co) assert(ok,err) end end end
json={encode=json_encode,decode=json_decode}
MySQL={ready=function(fn) fn() end,transaction={await=db_transaction}}
for _,kind in ipairs({'query','single','scalar','insert','update'}) do MySQL[kind]={await=function(sql,p) return db_query(kind,sql,p) end} end
lib={callback={register=function(name,fn) callbacks[name]=fn end}}
for id=1,8 do
 players[id]={identifier=id<=2 and ('char'..id..':license:a') or 'char1:license:'..id,phone=1}
 local p=players[id]
 p.getInventoryItem=function() return {count=p.phone} end
 p.source=id p.group=id==1 and 'owner' or 'user'
 p.getGroup=function() return p.group end
 p.showNotification=function() end
 p.getName=function() return 'Player '..id end
end
exports={es_extended={getSharedObject=function() return {GetPlayerFromId=function(id) return players[id] end,RegisterCommand=function(name,groups,fn) callbacks[name]=fn end} end}}
''')
    for name in ['shared/config.lua','server/service.lua','server/media.lua','server/apps.lua','server/social.lua','server/social_admin.lua','server/calls.lua','server/main.lua']:
        lua.execute(f'dofile({json.dumps(str(base/name).replace(chr(92),"/"))})')
    lua.execute(r'''
tokens={} profiles={}
for id=1,8 do
 tokens[id]=callbacks['rp_phone:open'](id).session
 check(callbacks['rp_phone:sync'](id).ok,'phone presence registration')
 local result=callbacks['rp_phone:action'](id,tokens[id],'home',{})
 check(result.ok,'profile creation') profiles[id]=result.phone.profile
end
function act(id,action,data) tick(4000) return callbacks['rp_phone:action'](id,tokens[id],action,data or {}) end
for id=1,7 do
 check(act(id,'social_home',{}).phone.active==0,'new character must create social identity explicitly')
 check(act(id,'social_create',{name='Player '..id,handle='player_'..id,bio='',nonce='register-'..id}).ok,'register first social identity')
end
check(profiles[1].number~=profiles[2].number,'characters have independent phone numbers')
check(not callbacks['rp_phone:action'](2,tokens[1],'home',{}).ok,'foreign session rejected')
check(act(1,'contact',{id='friend',name='Alice',number=profiles[2].number}).ok,'create contact')
check(#act(2,'home',{}).phone.profile.contacts==0,'contacts isolated across characters')
check(act(1,'task',{id='work',title='Werkstatt besuchen',done=false}).ok,'create task')
check(act(1,'task',{id='work',title='Werkstatt besuchen',done=true}).phone.profile.tasks[1].done,'complete task')
check(act(1,'bookmark',{id='city'}).ok,'valid city bookmark')
check(not act(1,'bookmark',{id='https://evil.invalid'}).ok,'arbitrary external URL rejected')
check(act(1,'send',{number=profiles[2].number,body='Hallo!',nonce='message-1'}).ok,'message stored')
check(act(1,'send',{number=profiles[2].number,body='Hallo!',nonce='message-1'}).ok,'message retry idempotent')
check(not act(1,'send',{number=profiles[2].number,body='Changed',nonce='message-1'}).ok,'changed replay rejected')
local inbox=act(2,'messages',{}).phone.rows
check(#inbox==1 and inbox[1].body=='Hallo!' and not inbox[1].mine,'recipient receives one message')
check(#act(3,'messages',{number=profiles[1].number}).phone.rows==0,'third party cannot read conversation')
check(act(2,'read',{number=profiles[1].number,last=inbox[1].id}).ok,'mark received messages read')
check(act(1,'messages',{}).phone.rows[1].seen,'read state shared correctly')
check(#act(3,'conversations',{profile=profiles[1].id}).phone.rows==0,'conversation summaries cannot impersonate another profile')
check(act(3,'send',{number=profiles[1].number,body='Older separate conversation',nonce='older-peer'}).ok,'second conversation')
for i=1,35 do check(act(2,'send',{number=profiles[1].number,body='Busy chat '..i,nonce='bulk-'..i}).ok,'busy conversation messages') end
local summaries=act(1,'conversations',{}).phone.rows
check(#summaries==2 and summaries[1].number==profiles[2].number and summaries[2].number==profiles[3].number,'one summary per peer even with more than 30 recent messages')
check(summaries[1].unread==35 and not summaries[1].mine and summaries[1].sender==nil,'accurate unread count without internal identifiers')
local older=act(1,'conversations',{before=summaries[1].id}).phone.rows
check(#older==1 and older[1].number==profiles[3].number,'summary cursor does not repeat busy peer using its older messages')
check(act(1,'read',{number=profiles[2].number,last=summaries[1].id}).ok,'mark busy conversation read')
check(act(1,'conversations',{}).phone.rows[1].unread==0,'read state updates conversation summary')
players[2].phone=0
check(act(1,'send',{number=profiles[2].number,body='Offline',nonce='message-2'}).ok,'offline messages persist')
check(not act(2,'home',{}).ok,'no item means no app access') players[2].phone=1
check(profiles[1].galleryScope~=profiles[2].galleryScope,'local gallery scopes are character specific')
check(act(1,'home',{}).phone.profile.galleryScope==profiles[1].galleryScope,'local gallery scope stays stable across requests')
check(not act(1,'photo',{image=jpeg,nonce='private'}).ok,'private capture cannot upload to old gallery endpoint')
check(not act(1,'photos',{}).ok,'server does not expose a private gallery')
check(not act(1,'publish_local',{image='data:image/svg+xml,<script/>',caption='',nonce='bad'}).ok,'non JPEG publication denied')
check(not act(1,'publish_local',{image=jpegHuge,caption='',nonce='bomb'}).ok,'oversized JPEG publication denied')
check(act(1,'publish_local',{image=jpeg,caption='Los Santos',nonce='post-1'}).ok,'explicit public photo saved atomically with post')
PhoneConfig.photos=1
check(act(1,'publish_local',{image=jpeg,caption='Los Santos',nonce='post-1'}).ok,'public retry succeeds at limit')
check(not act(1,'publish_local',{image=jpegOther,caption='Los Santos',nonce='post-1'}).ok,'changed photo replay refused')
check(not act(1,'publish_local',{image=jpeg,caption='Changed',nonce='post-1'}).ok,'changed caption replay refused')
check(not act(1,'publish_local',{image=jpeg,caption='',nonce='post-2'}).ok,'public storage limit enforced')
PhoneConfig.photos=40
local photo=act(2,'feed',{}).phone.rows[1].photo
check(act(2,'image',{id=photo}).ok,'published image visible to social readers')
check(not act(2,'post',{photo=photo,caption='Stolen',nonce='post-1'}).ok,'cannot republish another owner image')
local post=act(2,'feed',{}).phone.rows[1]
check(act(2,'like',{id=post.id,enabled=true}).ok,'like post')
check(act(2,'like',{id=post.id,enabled=true}).ok,'repeat like idempotent')
check(act(2,'feed',{}).phone.rows[1].likes==1,'one like per reader')
check(act(2,'comment',{id=post.id,body='Cool!',nonce='comment-1'}).ok,'comment stored')
check(#act(1,'comments',{id=post.id}).phone.rows==1,'comment visible')
check(act(2,'follow',{id=profiles[1].id,enabled=true}).ok,'follow creator')
check(#act(2,'feed',{following=true}).phone.rows==1,'following feed filters correctly')
check(act(2,'post_delete',{id=post.id}).ok and #act(1,'feed',{}).phone.rows==1,'foreign delete cannot remove post')
check(not act(1,'photo_delete',{id=photo}).ok,'published photo cannot be orphaned')
check(act(1,'post_delete',{id=post.id}).ok,'author can delete post')
check(not act(2,'image',{id=photo}).ok and not act(1,'image',{id=photo}).ok,'deleted publication removes server copy entirely')
check(act(1,'photo_delete',{id=photo}).ok,'unpublished photo can be removed')
check(act(1,'profile',{handle='joost',name='Joost',bio='Hallo'}).ok,'social profile changed')
check(not act(2,'profile',{handle='joost',name='Copy',bio=''}).ok,'unique handle protected')
dofile('tests/phone-social-database.lua')
check(act(1,'call_start',{number=profiles[2].number,video=true}).ok,'outgoing video call')
local call
for _,n in ipairs(notifications) do if n.id==2 and n.data.kind=='call' then call=n.data.call end end
check(call and not call.members[2].joined,'receiver must explicitly accept')
local before=#notifications
emit('rp_phone:signal',3,{call=call.id,target=2,type='offer',sdp='v=0\r\n'})
check(#notifications==before,'nonparticipant cannot relay RTC offers')
emit('rp_phone:signal',1,{call=call.id,target=2,type='offer',sdp='v=0\r\n'})
check(#notifications==before,'video cannot be relayed before receiver accepts')
check(act(2,'call_accept',{call=call.id,video=false}).ok,'callee may accept audio only')
emit('rp_phone:signal',1,{call=call.id,target=2,type='offer',sdp='v=0\r\n'})
check(#notifications>before,'accepted participants can signal peer video')
check(not act(2,'call_invite',{call=call.id,number=profiles[3].number}).ok,'only host invites conference participants')
for id=3,6 do
 check(act(1,'call_invite',{call=call.id,number=profiles[id].number}).ok,'host conference invitation')
 check(act(id,'call_accept',{call=call.id,video=true}).ok,'conference participant accepts')
end
check(not act(1,'call_invite',{call=call.id,number=profiles[7].number}).ok,'conference bounded to six')
check(not act(2,'call_state',{call=call.id,video=true,muted=false}).ok,'four video senders maximum')
check(act(2,'call_state',{call=call.id,video=false,muted=true}).ok,'mute persists server side')
check(act(1,'call_leave',{call=call.id}).ok,'host can leave without destroying conference')
check(act(2,'call_invite',{call=call.id,number=profiles[7].number}).ok,'new host elected')
emit('playerDropped',2)
check(not callbacks['rp_phone:action'](2,tokens[2],'home',{}).ok,'disconnect invalidates sessions')
local old=tokens[3] PhoneService.clear(3) players[3].identifier='char2:license:3'
check(not callbacks['rp_phone:action'](3,old,'home',{}).ok,'source reuse cannot access previous character')
tick(40000)
check(act(1,'history',{}).phone.rows[1].peer==profiles[2].number,'call history persisted')
print(('phone-apps-database: %d Lua + real MariaDB checks passed'):format(checks))
''')
finally:
    with db.cursor() as cur:
        order=['call_history','follows','comments','likes','posts','photos','messages','social_accounts','social_profiles','profiles']
        for table in [prefix+name for name in order]:
            assert table.startswith(prefix) and re.fullmatch(r'\w+',table)
            cur.execute(f'DROP TABLE IF EXISTS `{table}`')
    db.close()
