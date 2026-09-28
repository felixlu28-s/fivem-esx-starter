local root='server-data/resources/[custom]/'
dofile(root..'rp_inventory/shared/clothing_artwork.lua')
dofile(root..'rp_inventory/shared/clothing_catalog.lua')
local checks,events,api,threads,sent,applied=0,{},{},{},{},{}
local function check(v,m) assert(v,m) checks=checks+1 end
local time,dead,inVehicle,model,stops=0,false,false,'mp_m_freemode_01',0
local skin={sex=0,hair_1=22,torso_1=0,torso_2=1,pants_1=1,pants_2=2,tshirt_1=1,tshirt_2=0,glasses_1=2,glasses_2=1}
function joaat(v) return v end
function PlayerPedId() return 1 end
function GetEntityModel() return model end
function GetGameTimer() return time end
function IsPedDeadOrDying() return dead end
function IsPedInAnyVehicle() return inVehicle end
function IsPedRagdoll() return false end
function RequestAnimDict() end
function HasAnimDictLoaded() return true end
function RemoveAnimDict() end
function TaskPlayAnim(_,_,_,_,_,duration,flag) check(duration>0 and flag==48,'finite non-looping clothes animation') end
function StopAnimTask() stops=stops+1 end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) time=time+ms coroutine.yield(ms) end
function SetTimeout() end
function GetCurrentResourceName() return 'rp_inventory' end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) events[name]=fn end
function TriggerServerEvent(name,token,ok) sent[#sent+1]={name=name,token=token,ok=ok} end
function TriggerEvent(name,a,b)
    if name=='skinchanger:getSkin' then a(skin)
    elseif name=='skinchanger:loadClothes' then applied[#applied+1]=b end
end
exports=setmetatable({}, {__call=function(_,name,fn) api[name]=fn end})
dofile(root..'rp_inventory/client/clothing.lua')
events['rp_inventory:clothingState']({sex=0,skin={torso_1=4},generation='session'})
check(#applied==1 and applied[1].torso_1==4,'state uses standard skinchanger clothes event')
api.rpClothingPreview(true)
events['rp_inventory:clothingState']({sex=0,skin={torso_1=7},generation='session'})
check(#applied==1,'preview does not get overwritten by an unrelated sync')
api.rpClothingPreview(false)
check(applied[#applied].torso_1==7,'closing preview restores latest owned outfit')
events['rp_inventory:clothingAnimate']('wrong','top','stale')
check(sent[#sent].ok==false and not api.rpClothingBusy(),'old generation cannot dress new character')
events['rp_inventory:clothingAnimate']('valid','top','session')
check(api.rpClothingBusy(),'clothes animation owns busy state')
local animation=threads[#threads]
local before=#sent
check(coroutine.resume(animation),'animation begins')
check(#sent==before,'client waits before acknowledging')
while coroutine.status(animation)~='dead' do local ok,err=coroutine.resume(animation) assert(ok,err) end
check(sent[#sent].ok==true and time>=2100,'animation completes before client ACK')
events['rp_inventory:clothingFinish']('wrong')
check(api.rpClothingBusy(),'unrelated finish cannot interrupt another operation')
events['rp_inventory:clothingFinish']('valid')
check(not api.rpClothingBusy() and stops==1,'matching finish clears animation')
inVehicle=true events['rp_inventory:clothingAnimate']('car','top','session')
check(sent[#sent].ok==false,'vehicle prevents dressing') inVehicle=false
events['rp_inventory:clothingAnimate']('death','shoes','session')
animation=threads[#threads] check(coroutine.resume(animation),'second animation begins') dead=true
while coroutine.status(animation)~='dead' do local ok,err=coroutine.resume(animation) assert(ok,err) end
check(sent[#sent].ok==false,'death cancels before success acknowledgement')
events.onResourceStop('rp_inventory')
check(stops==2,'resource stop stops owned animation')

-- Shop orchestration preserves category previews without ever freezing the ped.
events,threads={},{}
local actions,view,preview,closedCamera,frozen={},nil,false,0,false
local closedSmooth
local openedPayload
local function currentPicture(payload, category)
    for _, item in ipairs(payload.currentClothing) do if item.category == category then return item end end
end
dead=false
function GetCurrentResourceName() return 'rp_commerce' end
function IsNuiFocused() return view~=nil end
function IsEntityPositionFrozen() return frozen end
function FreezeEntityPosition(_,value) frozen=value end
function DoesEntityExist() return true end
function GetEntityCoords() return {x=0,y=0,z=0} end
function SetCurrentPedWeapon() end
function GetNumberOfPedDrawableVariations() return 200 end
function GetNumberOfPedPropDrawableVariations() return 30 end
function RpPortraitCamera() return {update=function(data) return type(data)=='table' end,close=function(smooth) closedCamera=closedCamera+1 closedSmooth=smooth end} end
exports={es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return true end} end},
    rp_ui={rpRegisterAction=function(_,name,fn) actions[name]=fn end,rpGetView=function() return view end,
        rpOpen=function(_,name,payload) view=name openedPayload=payload return true end,rpClose=function() view=nil end},
    rp_inventory={rpLocalizeCatalog=function(_,data) return data end,rpClothingBusy=function() return false end,rpClothingPreview=function(_,value) preview=value end}}
Commerce={Config={radius=1.25},Clothing={shops={test={coords={x=0,y=0,z=0}}}},Weapons={streamIn=40,streamOut=60,
    distance=function() return 0 end,client={updateInstance=function() end,destroyInstance=function() end}}}
function AddBlipForCoord() return 1 end
function SetBlipSprite() end function SetBlipColour() end function SetBlipScale() end function SetBlipAsShortRange() end
function BeginTextCommandSetBlipName() end function AddTextComponentString() end function EndTextCommandSetBlipName() end
function RemoveBlip() end
dofile(root..'rp_commerce/client/clothing.lua')
local stream=threads[1]
local ok,err=coroutine.resume(stream) assert(ok,err)
local B=Commerce.Clothing
check(B.open('test',{session='test',offers={{id='top_0_1'},{id='pants_0_2'},{id='shoes_0_3'}},
    currentClothing={{category='top',artwork='clothing/1/top/0_0'}}}),'shop opens')
check(preview and not frozen and view=='clothing','fitting room leaves character unfrozen')
check(#openedPayload.currentClothing==12,'current cards cover every outfit category')
check(currentPicture(openedPayload,'top').artwork=='clothing/0/top/0_1','opening outfit beats stale inventory card and uses exact texture')
check(currentPicture(openedPayload,'pants').artwork=='clothing/0/pants/1_2','creator pants do not need a current inventory row')
check(currentPicture(openedPayload,'undershirt').artwork=='clothing/0/undershirt/1_0','bundled component receives actual image')
check(currentPicture(openedPayload,'glasses').artwork=='clothing/0/glasses/2_1','accessory prop uses its actual texture')
check(not currentPicture(openedPayload,'hat').artwork and currentPicture(openedPayload,'hat').label=='Nicht angezogen','absent accessory never shows another item')
check(not actions['rp_clothing:preview']({products={'top_1_0'}}).ok,'preview outside server-filtered offer list denied')
check(actions['rp_clothing:preview']({products={'top_0_1','pants_0_2','shoes_0_3'}}).ok,'whole outfit preview uses installed skinchanger')
check(applied[#applied].torso_1==1 and applied[#applied].pants_1==2 and applied[#applied].shoes_1==3,'categories remain previewed together')
check(currentPicture(openedPayload,'top').artwork=='clothing/0/top/0_1','trial garment cannot overwrite current image')
check(actions['rp_clothing:preview']({products={'top_0_1','shoes_0_3'}}).ok,'current restores one category')
check(applied[#applied].pants_1==skin.pants_1 and applied[#applied].torso_1==1 and applied[#applied].shoes_1==3,'current does not reset other categories')
check(not actions['rp_clothing:preview']({products={'top_0_1','top_0_1'}}).ok,'duplicate preview category rejected')
lib={callback={await=function() return {ok=true,commerce={clothingSkin={torso_1=7,torso_2=0}}} end}}
local purchased=actions['rp_clothing:buy']({session='test'})
check(purchased.ok,'purchase response refreshes owned baseline')
check(currentPicture(purchased.commerce,'top').artwork=='clothing/0/top/7_0','purchase card uses committed provider outfit, not remaining trial')
check(applied[#applied].torso_1==1,'unbought preview survives baseline update')
check(actions['rp_clothing:preview']({products={}}).ok and applied[#applied].torso_1==7,'current uses newly purchased authoritative outfit')
check(actions['rp_clothing:camera']({view='face'}).ok,'camera routed to same shared API')
view=nil -- NUI Escape / another resource closed the surface.
ok,err=coroutine.resume(stream) assert(ok,err)
check(not preview and not frozen and closedCamera==1 and closedSmooth,'normal close returns camera smoothly')
frozen=true
check(B.open('test',{session='next',offers={{id='top_0_0'}}}),'reopen')
B.close()
check(frozen,'pre-existing freeze state preserved')
check(not actions['rp_clothing:preview']({products={'top_0_0'}}).ok,'closed scene cannot mutate preview')
events.onResourceStop('rp_commerce')
check(closedSmooth==false,'resource stop also drains a pending camera return')
model='mp_f_freemode_01'
check(B.open('test',{session='female',offers={{id='top_1_0'}}}),'female fitting room opens')
check(currentPicture(openedPayload,'top').artwork=='clothing/1/top/0_1','actual female model selects female image despite stale skin sex')
B.close()
model='a_m_m_business_01'
check(not B.open('test',{session='third',offers={}}),'non-freemode model cannot open garment preview')
print(('PASS: %d clothing client animation / preview / camera / cleanup checks'):format(checks))
