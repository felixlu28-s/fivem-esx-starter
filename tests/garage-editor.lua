local base='server-data/resources/[custom]/rp_vehicles/'
local now=0 local events,threads,menus,stack={}, {}, {}, {}
local checked,saved,closed,draft=0,0,0,nil
local function check(v,label) assert(v,label) checked=checked+1 end
function GetGameTimer() return now end
function PlayerPedId() return 1 end
function IsEntityDead() return false end
function GetCurrentResourceName() return 'rp_vehicles' end
function RegisterNetEvent(n,f) events[n]=f end AddEventHandler=RegisterNetEvent
function TriggerServerEvent(n) if n=='rp_vehicles:editorClose' then closed=closed+1 end end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) coroutine.yield(ms) end
local function advance(ms)
    for _=1,math.ceil(ms/50) do now=now+50 for _,t in ipairs(threads) do if coroutine.status(t.co)~='dead' and t.wake<=now then
        local ok,delay=coroutine.resume(t.co) assert(ok,delay) t.wake=now+(delay or 0)
    end end end
end
dofile(base..'shared/config.lua') dofile(base..'shared/rules.lua') dofile(base..'shared/schema.lua')
local R=Garage.Rules local g=R.copy(Garage.Config.garages.la_mesa) g.id,g.revision='la_mesa',1
function GetEntityCoords() return R.copy(g.interaction) end
function GetVehiclePedIsIn() return 0 end
function GetEntityHeading() return 90.0 end
function DrawMarker() end function DrawLine() end
local ui={}
function ui:rpCreateMenu(id,definition,callbacks)
    check(definition.theme=='mint','all garage menus use mint banner')
    menus[id]={definition=definition,callbacks=callbacks} return id
end
function ui:rpUpdateMenu(id,patch) for k,v in pairs(patch) do menus[id].definition[k]=v end return true end
function ui:rpOpenMenu(id) stack={id} return true end
function ui:rpPushMenu(id) stack[#stack+1]=id return true end
function ui:rpCloseMenu() for i=#stack,1,-1 do menus[stack[i]].callbacks.onClose('api') end stack={} end
function ui:rpDestroyMenu(id) menus[id]=nil end
exports={rp_nativeui=ui,rp_ui={rpHideInteraction=function() end},rp_core={}}
Garage.Scene={}
Garage.World={instances={},setDraft=function(value) draft=value and R.copy(value) end,refresh=function() end,
    footHeight=function() return 1,21.17 end,playerFloor=function() return {x=715,y=-1094,z=21.17,h=90} end,
    gateStatus=function() return false,'gate_missing' end}
lib={notify=function() end,callback={await=function(name,_,token,id,revision,raw,remove)
    if name=='rp_vehicles:editorOpen' then return {ok=true,token='test',garages={R.copy(g)},bucket=0} end
    if name=='rp_vehicles:editorSelect' then return {ok=true,garage=id and R.copy(g)} end
    if name=='rp_vehicles:editorSave' then
        check(token=='test' and id=='la_mesa' and revision==1 and not remove,'save includes capability and expected revision')
        check(R.definition(raw),'editor emits valid server schema') saved=saved+1 raw.revision=2 return {ok=true,token='test',garage=raw}
    end
    error('Unexpected callback '..name)
end}}
dofile(base..'client/editor.lua')
local function select(id)
    local m=menus[stack[#stack]] assert(m,'menu open')
    m.callbacks.onSelect(id) advance(250)
end
local function change(id,value,index) menus[stack[#stack]].callbacks.onChange(id,value,index) advance(250) end
local function back() local id=table.remove(stack) menus[id].callbacks.onClose('back') advance(250) end
source=1 events['rp_vehicles:editor']() advance(250) check(#stack==0,'forged open ignored')
source=65535 events['rp_vehicles:editor']() advance(250)
select('g_1') check(draft and draft.id=='la_mesa','existing garage preview')
select('npc') change('model','s_m_m_autoshop_01',2)
check(draft.clerk.model=='s_m_m_autoshop_01','model switch updates preview')
select('clerk') select('here')
check(draft.clerk.z==21.17,'NPC anchor stored at floor, no permanent +0.5')
change('z',1,3) check(math.abs(draft.clerk.z-21.22)<0.001,'fine adjustment preserved')
back() back() select('outward')
local points=#draft.outward select('add') check(#draft.outward==points+1,'route point appended')
select('p_1') select('duplicate') check(#draft.outward==points+2,'duplicate waypoint')
select('p_1') select('delete') check(#draft.outward==points+1,'remove waypoint')
back() select('gate') change('open',true) check(Garage.World.testOpen==true,'live door preview switch')
back() select('save') check(saved==1 and draft.revision==2,'save refreshes revision without leaving editor')
source=65535 events['rp_vehicles:editorClosed']() advance(250)
check(not draft and next(menus)==nil and closed==1,'server cancel cleans every menu and draft')
print(('garage-editor: %d navigation, NPC placement, routes, preview and cleanup checks passed'):format(checked))
