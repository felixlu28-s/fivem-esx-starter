-- Real NativeUI API/model + actual inventory admin client, deterministic host.
local base = 'server-data/resources/[custom]/'
local api, events, threads, routes, view, payload = {}, {}, {}, {}, nil, nil
local passed, grants, keyboards, catalogs, currentResource = 0, {}, 0, 0, 'rp_nativeui'
local function check(value,label) assert(value,label) passed=passed+1 end
function GetInvokingResource() return 'rp_inventory' end
function GetCurrentResourceName() return currentResource end
function GetResourceState() return 'started' end
function PlayerId() return 0 end
function GetPlayerServerId() return 1 end
function CreateThread(fn) threads[#threads+1]=fn end
function Wait() end
function AddEventHandler(name,fn) events[name]=events[name] or {} table.insert(events[name],fn) end
function RegisterNetEvent(name,fn) AddEventHandler(name,fn) end
function PlaySoundFrontend() end
function AddTextEntry() end
function DisplayOnscreenKeyboard() keyboards=keyboards+1 end
local keyboardState=1
function UpdateOnscreenKeyboard() return keyboardState end
function GetOnscreenKeyboardResult() return '22' end
function CancelOnscreenKeyboard() end
function DisableAllControlActions() end
local function flush() while #threads>0 do table.remove(threads,1)() end end
local function emit(name,...) for _, fn in ipairs(events[name] or {}) do fn(...) end end
exports=setmetatable({rp_ui={
    rpOpen=function(_,name,data) view,payload=name,data return true end,
    rpClose=function() view,payload=nil,nil return true end,
    rpGetView=function() return view end,
    rpRegisterAction=function(_,name,fn) routes[name]=fn end,
}}, {__call=function(_,name,fn) api[name]=fn end})
dofile(base .. 'rp_nativeui/client/model.lua')
dofile(base .. 'rp_nativeui/client/api.lua')
flush()
exports.rp_nativeui=setmetatable({}, {__index=function(_,name) return function(_,...) return api[name](...) end end})
local items={}
for i=1,183 do items[#items+1]={name='esx_food_'..i,label='Essen '..i,category='Essen',weight=100,maxStack=20} end
items[#items+1]={name='WEAPON_PISTOL',label='Pistole',category='Waffen',weight=1000,maxStack=1}
local selected, ticket = 1, 1
lib={notify=function() end,callback={await=function(name,_,...)
    local args={...}
    if name=='rp_inventory:adminCatalog' then
        catalogs=catalogs+1
        return {ok=true,token='menu',ticket='ticket1',target=1,items=items}
    elseif name=='rp_inventory:adminTarget' then
        selected=args[2] ticket=ticket+1
        return {ok=true,target=selected,ticket='ticket'..ticket}
    elseif name=='rp_inventory:adminGive' then
        grants[#grants+1]={target=selected,name=args[3],count=args[4]}
        ticket=ticket+1
        return {ok=true,target=selected,ticket='ticket'..ticket}
    end
    error('unexpected RPC '..name)
end}}
currentResource='rp_inventory'
dofile(base .. 'rp_inventory/client/admin.lua')
source=0 emit('rp_inventory:adminOpen') flush()
check(catalogs==0,'forged local open ignored')
source=65535 emit('rp_inventory:adminOpen') flush()
check(view=='nativeui' and #payload.items==3 and payload.items[1].type=='list','target slider precedes item categories')
local function press(key)
    return routes['rp_nativeui:input']({session=payload.session,revision=payload.revision,key=key})
end
press('right')
check(payload.items[1].index==2,'slider selects give mode')
press('enter')
check(view==nil,'NativeUI releases focus before ID input')
flush()
check(keyboards==1 and view=='nativeui' and payload.items[1].options[2].label:find('22'),'entered target ID appears in selector')
press('down') press('enter')
check(#payload.items==2,'large item category is paginated')
press('enter')
check(#payload.items==180 and #payload.items[1].options==99,'page has all 99 quantity choices')
press('left')
check(payload.items[1].index==99,'quantity wraps within 1 to 99')
press('right') press('right') press('enter')
check(not press('enter').ok,'busy client rejects duplicate Enter before reply')
flush()
check(#grants==1 and grants[1].target==22 and grants[1].name=='esx_food_1' and grants[1].count==2,'selected target, DB-only catalog item and selected quantity reach RPC')
press('back') press('back') press('up') press('left') flush()
check(payload.items[1].index==1 and selected==1,'self slider restores own recipient')
press('right') keyboardState=2 press('enter') flush()
check(view=='nativeui','cancelled ID input returns to root')
press('down') press('enter') press('enter') press('enter') flush()
check(#grants==1,'no grant without confirmed recipient after changing mode')
press('back') press('back') press('back')
check(view==nil,'root back closes menu and owned definitions')
source=65535 emit('rp_inventory:adminOpen')
emit('esx:onPlayerLogout') flush()
check(view==nil,'late catalog cannot reopen after logout')
print(('PASS: %d admin client/NativeUI integration assertions'):format(passed))
