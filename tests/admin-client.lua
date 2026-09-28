local base='server-data/resources/[custom]/'
local api,events,jobs,routes,calls={},{},{},{},{}
local view,payload,options,now=nil,nil,nil,0
local invincible,loaded,dead=false,true,false
local keyboard='2500'
local count=0
local function check(v,m) assert(v,m) count=count+1 end
function GetInvokingResource() return 'rp_admin' end
function GetCurrentResourceName() return 'rp_admin' end
function GetResourceState() return 'started' end
function PlayerId() return 0 end
function PlayerPedId() return 1 end
function GetPlayerServerId() return 1 end
function GetPlayerInvincible() return invincible end
function SetPlayerInvincible(_,v) invincible=v end
function IsNuiFocused() return view~=nil end
function IsEntityDead() return dead end
function GetGameTimer() return now end
function Wait(ms) return coroutine.yield(ms) end
function CreateThread(fn) jobs[#jobs+1]={co=coroutine.create(fn),at=now} end
function AddEventHandler(n,fn) events[n]=events[n] or {} table.insert(events[n],fn) end
function RegisterNetEvent(n,fn) AddEventHandler(n,fn) end
function PlaySoundFrontend() end
function AddTextEntry() end
function DisplayOnscreenKeyboard() end
function UpdateOnscreenKeyboard() return 1 end
function GetOnscreenKeyboardResult() return keyboard end
function CancelOnscreenKeyboard() end
function DisableAllControlActions() end
local function emit(n,...)
    source=65535
    for _,fn in ipairs(events[n] or {}) do fn(...) end
end
local function advance(ms)
    local finish=now+ms
    repeat
        now=now+16
        for _,job in ipairs(jobs) do if coroutine.status(job.co)~='dead' and job.at<=now then
            local ok,delay=coroutine.resume(job.co) assert(ok,delay) job.at=now+math.max(16,delay or 0)
        end end
    until now>=finish
end
local allowHeartbeat=true
lib={notify=function() end,callback={await=function(name,_,...)
    local args={...} calls[#calls+1]={name=name,args=args}
    if name=='rp_admin:open' then return {ok=true,token='session',nonce='grant1',target=1,godmode=false} end
    if name=='rp_admin:money' then return {ok=true,nonce='grant2'} end
    if name=='rp_admin:target' then return {ok=true,target=args[2],nonce='newtarget'} end
    if name=='rp_admin:heartbeat' then return {ok=true,godmode=allowHeartbeat} end
    if name=='rp_admin:action' then
        if args[2]=='godmode' then emit('rp_admin:godmode',args[3],args[1]) end
        return {ok=true,godmode=args[3]}
    end
    error(name)
end}}
exports=setmetatable({
    es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end} end},
    rp_core={rpRegisterInputAction=function(_,v) check(v.id=='rp_admin:open' and v.defaultKey=='F10','F10 registered through own input system') end},
    rp_ui={rpOpen=function(_,v,p,_,o) view,payload,options=v,p,o return true end,
        rpClose=function() view,payload=nil,nil return true end, rpGetView=function() return view end,
        rpRegisterAction=function(_,name,fn) routes[name]=fn end},
},{__call=function(_,name,fn) api[name]=fn end})
exports.rp_nativeui=setmetatable({},{__index=function(_,name) return function(_,...) return api[name](...) end end})
dofile(base..'rp_nativeui/client/model.lua') dofile(base..'rp_nativeui/client/api.lua')
dofile(base..'rp_admin/client/main.lua') advance(100)
local function press(key) return routes['rp_nativeui:input']({key=key,session=payload.session,revision=payload.revision}) end
local function select(id) for _=1,10 do if payload.items[payload.selected].id==id then return end press('down') end error(id) end
emit('rp_core:inputPressed','rp_admin:open') advance(100)
check(view=='nativeui' and payload.title=='Administration' and options.toggleAction=='rp_admin:open','F10 opens actual NativeUI with toggle')
press('enter') select('amount') press('enter') advance(100)
check(payload.items[3].rightLabel=='$ 2500' and payload.depth==2,'native numeric input restores money submenu')
select('target') keyboard='22' press('enter') advance(100)
check(payload.items[1].rightLabel=='ID 22','target selection reflected')
select('account') press('right') select('give') press('enter') press('enter') advance(100)
local grants=0
for _,call in ipairs(calls) do if call.name=='rp_admin:money' then
    grants=grants+1 check(call.args[2]=='newtarget' and call.args[3]=='bank' and call.args[4]==2500,'money request has server nonce, account and entered amount')
end end
check(grants==1,'repeated enter cannot duplicate in-flight money request')
press('close') check(view==nil,'toggle closes money submenu and root together')
emit('rp_admin:open') advance(100) select('godmode') press('enter') advance(100)
check(invincible and payload.items[5].checked,'authorized godmode updates actual checkbox')
press('close') advance(11000)
check(invincible,'godmode lease continues with menu closed')
allowHeartbeat=false advance(11000)
check(not invincible,'revoked lease clears godmode')
emit('rp_admin:open') advance(100) select('items') press('enter') advance(100)
check(view==nil and calls[#calls].args[2]=='items','item handoff releases focus first')
for _,action in ipairs({'noclip','waypoint'}) do
    emit('rp_admin:open') advance(100) select(action) press('enter') advance(100)
    check(view==nil and calls[#calls].args[2]==action,'existing ESX action routed: '..action)
end
emit('rp_admin:open') advance(100) select('godmode') press('enter') advance(100)
emit('onResourceStop','rp_admin')
check(not invincible and view==nil,'stop restores invincibility and closes own menu')
print(('PASS: %d actual NativeUI/admin client/keyboard/godmode cleanup assertions'):format(count))
