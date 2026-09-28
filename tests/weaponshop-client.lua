-- Real NativeUI + Ammu-Nation scene/menu/editor, deterministic native host.
math.randomseed(42)
local base='server-data/resources/[custom]/'
local count=0
local function check(v,message) assert(v,message) count=count+1 end
local threads,events,api,entities,cameras,protected={},{},{},{},{},{}
local now,seq,owner,view,payload,route=0,10,'rp_commerce',nil,nil,nil
local dead,loaded,frozen,rendered=false,true,false,false
local held={}
local componentModelsReady=true
local pedModelsReady=true
local animationsReady=true
local speeches,animations,transforms={},{},{}
local primary, animationLog = {}, {}
local lineOfSight=true
local floorRay
local floorObstacle, floorProbeCount = false, 0
local lights = {}
function DrawLightWithRange(x,y,z,r,g,b,range,intensity)
    assert(not lights[now], 'only one selection light per frame')
    lights[now] = {x=x,y=y,z=z,intensity=intensity,range=range}
end
function IsDisabledControlPressed(_,control) return held[control]==true end
local playerPos={x=0,y=0,z=0}
local requests,saved,keyboard={},nil,'12.5'
function GetCurrentResourceName() return 'rp_commerce' end
function GetInvokingResource() return owner end
function GetGameTimer() return now end
function CreateThread(fn) threads[#threads+1]={co=coroutine.create(fn),wake=now} end
function Wait(ms) return coroutine.yield(ms) end
local function advance(ms)
    local untilTime=now+ms
    repeat
        now=now+16
        for _,job in ipairs(threads) do if coroutine.status(job.co)~='dead' and job.wake<=now then
            local ok,delay=coroutine.resume(job.co) assert(ok,delay) job.wake=now+math.max(16,tonumber(delay) or 0)
        end end
    until now>=untilTime
end
local function run(fn,ms) CreateThread(fn) advance(ms or 100) end
function AddEventHandler(name,fn) events[name]=events[name] or {} table.insert(events[name],fn) end
function RegisterNetEvent(name,fn) AddEventHandler(name,fn) end
local function emit(name,...)
    local args={...}
    source=65535
    for _,fn in ipairs(events[name] or {}) do fn(table.unpack(args)) end
end
function TriggerServerEvent(name,...) requests[#requests+1]={name,...} end
function PlayerPedId() return 1 end
function PlayerId() return 1 end
function IsEntityDead() return dead end
function GetEntityCoords(e) return e==1 and playerPos or entities[e].pos end
function GetEntityHeading() return 0 end
function GetOffsetFromEntityInWorldCoords(_,x,y,z) return {x=playerPos.x+x,y=playerPos.y+y,z=playerPos.z+z} end
function DoesEntityExist(e) return e==1 or entities[e]~=nil end
function IsEntityPositionFrozen() return frozen end
function FreezeEntityPosition(e,value) if e==1 then frozen=value end end
function DeleteEntity(e) entities[e]=nil end
function joaat(s) return s end
function IsModelInCdimage() return true end
function IsModelValid() return true end
function IsModelAPed() return true end
function HasModelLoaded(hash)
    if tostring(hash):find('ammu') then return pedModelsReady end
    return not tostring(hash):find('_model') or componentModelsReady
end
function HasWeaponAssetLoaded() return true end
function CreateObjectNoOffset(_,x,y,z) seq=seq+1 entities[seq]={pos={x=x,y=y,z=z},kind='object',components={}} return seq end
function CreateWeaponObject(_,_,x,y,z) return CreateObjectNoOffset(nil,x,y,z) end
function CreatePed(_,hash,x,y,z) local e=CreateObjectNoOffset(nil,x,y,z) entities[e].kind='ped' entities[e].model=hash return e end
function GetModelDimensions(hash) return {x=-0.3,y=-0.3,z=-1.6},{x=0.3,y=0.3,z=1.0} end
function GetPedBoneCoords(ped)
    local p=GetEntityCoords(ped)
    local height=ped~=1 and entities[ped].model=='s_m_m_ammucountry' and 0.9 or 1.0
    return {x=p.x,y=p.y,z=p.z-height+0.06}
end
function SetEntityCoordsNoOffset(e,x,y,z) entities[e].pos={x=x,y=y,z=z} transforms[e]=(transforms[e] or 0)+1 end
function RequestAnimDict() end
function HasAnimDictLoaded() return animationsReady end
function RemoveAnimDict() end
function TaskPlayAnim(ped,dict,clip,_,_,_,flags)
    assert(entities[ped],'animation cannot target deleted ped')
    animations[ped]={dict=dict,clip=clip}
    animationLog[#animationLog+1]={ped=ped,clip=clip}
    if flags~=48 then primary[ped]=animations[ped] end
end
function StopAnimTask(ped,_,clip) if animations[ped] and animations[ped].clip==clip then animations[ped]=primary[ped] end end
function TaskClearLookAt() end
function GetEntityModel(ped) return entities[ped] and entities[ped].model or 'player' end
function IsPedMale() return true end
function GetInteriorFromEntity() return 1 end
function HasEntityClearLosToEntity() return lineOfSight end
function IsAnySpeechPlaying() return false end
function TaskLookAtEntity() end
function PlayPedAmbientSpeechNative(ped,speech) speeches[#speeches+1]={ped=ped,speech=speech} end
function SetEntityRotation(e,x,y,z) entities[e].rot={x=x,y=y,z=z} end
function CreateCam() seq=seq+1 cameras[seq]={} return seq end
function DestroyCam(c) cameras[c]=nil end
function DoesCamExist(c) return cameras[c]~=nil end
function SetCamCoord(c,x,y,z) cameras[c].pos={x=x,y=y,z=z} end
function SetCamFov(c,fov) cameras[c].fov=fov end
function PointCamAtCoord(c,x,y,z) cameras[c].target={x=x,y=y,z=z} end
function RenderScriptCams(value) rendered=value end
function GetGameplayCamCoord() return {x=0,y=-3,z=1.5} end
function GetGameplayCamRot() return {x=0,y=0,z=0} end
function GetGameplayCamFov() return 60 end
function DoesWeaponTakeWeaponComponent() return true end
function GetWeaponComponentTypeModel(hash) return hash..'_model' end
function GiveWeaponComponentToWeaponObject(e,hash) entities[e].components[hash]=true end
function RemoveWeaponComponentFromWeaponObject(e,hash) entities[e].components[hash]=nil end
function IsPauseMenuActive() return false end
function IsNuiFocused() return view~=nil end
function IsControlJustPressed() return false end
function IsDisabledControlJustPressed() return false end
function UpdateOnscreenKeyboard() return 1 end
function GetOnscreenKeyboardResult() return keyboard end
function StartShapeTestRay(x,y,z,tx,ty,tz)
    if x==tx and y==ty and z>tz then floorRay={x=x,y=y,z=z} floorProbeCount=floorProbeCount+1 return 12 end
    return 11
end
function GetShapeTestResult(ray)
    if ray==12 then
        local z=floorObstacle=='blocked' and floorRay.z-0.02 or (floorObstacle and floorRay.z>0 and 0 or -1)
        return 2,1,{x=floorRay.x,y=floorRay.y,z=z},{x=0,y=0,z=1},0
    end
    return 2,1,{x=1,y=1,z=0.9},{x=0,y=0,z=1},0
end
function AddBlipForCoord() seq=seq+1 return seq end
for _,name in ipairs({'SetEntityAsMissionEntity','RequestWeaponAsset','RequestModel','RemoveWeaponAsset','SetModelAsNoLongerNeeded',
    'SetEntityCollision','SetEntityInvincible','SetBlockingOfNonTemporaryEvents','SetPedCanRagdoll','SetPedCanEvasiveDive',
    'SetPedFleeAttributes','SetPedCombatAttributes','SetPedDropsWeaponsWhenDead','SetPedCanBeTargetted','SetEntityHeading',
    'ClearPedTasksImmediately','TaskStartScenarioInPlace','SetCamRot','DisablePlayerFiring','DisableControlAction',
    'SetBlipSprite','SetBlipColour','SetBlipScale','SetBlipAsShortRange','SetBlipCoords','BeginTextCommandSetBlipName',
    'AddTextComponentString','EndTextCommandSetBlipName','RemoveBlip','PlaySoundFrontend','AddTextEntry','DisplayOnscreenKeyboard',
    'CancelOnscreenKeyboard','DisableAllControlActions','DrawRect','SetNewWaypoint'}) do _G[name]=function() end end
exports=setmetatable({
    es_extended={getSharedObject=function() return {IsPlayerLoaded=function() return loaded end} end},
    rp_ui={rpOpen=function(_,name,data) view,payload=name,data return true end,rpClose=function() view,payload=nil,nil end,
        rpGetView=function() return view end,rpRegisterAction=function(_,_,fn) route=fn end,
        rpShowInteraction=function() end,rpHideInteraction=function() end},
    rp_core={rpProtectPed=function(_,ped) protected[ped]=true return RP.NpcPresentation.register(ped,owner) end,
        rpReleasePed=function(_,ped) protected[ped]=nil return RP.NpcPresentation.release(ped,owner) end,
        rpConfigureNpc=function(_,...) return api.rpConfigureNpc(...) end},
    rp_nativeui=setmetatable({},{__index=function(_,name) return function(_,...) return api[name](...) end end}),
},{__call=function(_,name,fn) api[name]=fn end})
dofile(base..'rp_nativeui/client/model.lua') dofile(base..'rp_nativeui/client/api.lua')
dofile(base..'rp_commerce/shared/config.lua') dofile(base..'rp_commerce/shared/weapons.lua')
local W=Commerce.Weapons
local loose={catalog='bandage',type='counter',pos={x=0,y=0,z=1},rot={x=90,y=15,z=30},heading=0,scale=1,height=0}
local lifted=W.pose(loose,0,1)
check(lifted.object.z>1 and lifted.rotation.x==90 and lifted.rotation.y==15,'non-firearm hand objects lift without forced upright rotation')
local shop=W.newShop({x=0,y=0,z=0,bucket=0}) shop.id,shop.revision='test_shop',1
shop.displays={
    {id='pistol',catalog='pistol',type='counter',pos={x=0,y=1,z=1},rot={x=90,y=0,z=0},heading=180,scale=1,height=0},
    {id='rifle',catalog='rifle',type='wall',pos={x=1,y=1,z=1.5},rot={x=0,y=0,z=0},heading=180,scale=1,height=0},
}
shop.npc={pos={x=0,y=2,z=-1},heading=180,model=W.clerkModels[1],scenario=W.scenarios[1]}
local purchaseCalls=0
lib={notify=function() end,callback={await=function(name,_,...)
    local args={...}
    if name=='rp_commerce:weaponshops' then return {ok=true,shops={W.copy(shop)}} end
    if name=='rp_commerce:weaponEditorOpen' then return {ok=true,token='editor',bucket=0,shops={W.copy(shop)}} end
    if name=='rp_commerce:weaponEditorSave' then
        saved=W.copy(args[4]) local clean=W.validate(saved) assert(clean,'editor submits valid server schema')
        saved.id,saved.revision='created_shop',1 return {ok=true,token='editor2',shop=W.copy(saved)}
    end
    if name=='rp_commerce:action' then purchaseCalls=purchaseCalls+1 requests[#requests+1]=args[1] return {ok=true} end
    error(name)
end}}
dofile(base..'rp_core/shared/npcs.lua')
dofile(base..'rp_core/client/npcs.lua')
dofile(base..'rp_commerce/client/weapon_clerk.lua')
dofile(base..'rp_commerce/client/weapon_scene.lua')
dofile(base..'rp_commerce/client/weapon_menu.lua')
dofile(base..'rp_commerce/client/weapon_editor.lua')
local X=W.client
advance(900)
local instance=X.instances.test_shop
check(instance and instance.npc and protected[instance.npc],'clerk streamed and protected from ambient cleanup')
check(math.abs(entities[instance.npc].pos.z)<0.001,'stored foot position converted to correct ped origin on first spawn')
advance(2000)
check(#speeches==1 and speeches[1].speech=='GENERIC_HI','nearby visitor greeted once')
advance(3000)
check(animations[instance.npc].clip=='_idle','greeting returns to crossed-arm gunstore idle')
local poseUpdates=transforms[instance.npc]
advance(1600)
check(#speeches==1 and transforms[instance.npc]==poseUpdates,'stream tick does not restart idle, teleport NPC or spam greetings')
lineOfSight=false
advance(61000)
check(#speeches==1,'no greeting through walls')
lineOfSight=true advance(2500)
check(#speeches==2,'visible returning visitor greeted after cooldown')
advance(3000)
local logStart=#animationLog
advance(66000)
local gestured=false
for i=logStart+1,#animationLog do local clip=animationLog[i].clip if clip=='_idle_a' or clip=='_idle_b' then gestured=true end end
check(gestured,'occasional original gunstore gesture while visitor remains')
advance(3300)
check(animations[instance.npc].clip=='_idle','occasional gesture returns to default idle')
check(instance.objects.pistol.entity and instance.objects.rifle.entity,'actual display props created')
check(not next(lights),'streamed shops do not draw lights while closed')
local resolved
floorObstacle=true floorProbeCount=0
W.clerkClient.playerFloor(function() return true end,function(p) resolved=p end) advance(100)
check(resolved and resolved.z==-1 and floorProbeCount==2,'floor probe skips counter above feet and finds supporting floor')
floorObstacle='blocked' floorProbeCount=0 resolved=true
W.clerkClient.playerFloor(function() return true end,function(p) resolved=p end) advance(100)
check(resolved==nil and floorProbeCount==4,'obstructed placement fails closed after bounded probes')
floorObstacle=false
local adjusted=W.copy(shop.npc) adjusted.pos.z=adjusted.pos.z+0.2
local originalNpc=shop.npc
shop.npc=adjusted instance.shop.npc=adjusted X.shops.test_shop.npc=adjusted
W.clerkClient.apply(instance,adjusted) advance(200)
check(math.abs(entities[instance.npc].pos.z-0.2)<0.001,'foot alignment preserves explicit manual anchor height')
shop.npc=originalNpc instance.shop.npc=originalNpc X.shops.test_shop.npc=originalNpc
W.clerkClient.apply(instance,shop.npc) advance(200)
local function press(key)
    check(view=='nativeui','keyboard targets active NativeUI')
    local reply=route({key=key,session=payload.session,revision=payload.revision})
    assert(reply.ok,reply.error) return reply
end
local function select(id)
    for _=1,50 do if payload.items[payload.selected].id==id then return end press('down') end
    error('row not found: '..id)
end
run(function() check(X.openShop(X.shops.test_shop,{session='buy-session'}),'shop opens existing NativeUI') end,100)
check(frozen and rendered and next(cameras),'camera owns freeze only during shop')
advance(180)
local pistol=instance.objects.pistol.entity
check(entities[pistol].pos.z==1 and entities[pistol].rot.x==90,'prop waits at rest while camera travels')
check(payload.items[payload.selected].hint.keys[1]=='W','weapon selection exposes separate WASD hint')
advance(450)
check(entities[pistol].pos.z>1 and entities[pistol].pos.z<1.25,'spring lift begins only after camera arrival')
check(entities[pistol].rot.x<90,'flat pistol progressively stands upright after camera arrival')
advance(700) check(X.state=='Browse','entry transitions to browse')
check(lights[now] and lights[now].intensity>1 and lights[now].intensity<=W.camera.lighting.browse,'selected weapon receives bounded browse light')
check(lights[now].z>entities[pistol].pos.z,'light sits above selected prop')
check(math.abs(entities[pistol].pos.z-1.24)<0.001 and math.abs(entities[pistol].rot.x)<0.001,'browse gun already lifted and upright')
held[32],held[35]=true,true advance(200)
check(entities[pistol].rot.x>0 and entities[pistol].rot.x<18 and entities[pistol].rot.z>0 and entities[pistol].rot.z<28,'diagonal inspection eases with resistance')
advance(1000) held[35]=nil advance(650)
check(math.abs(entities[pistol].rot.x-18)<0.1 and math.abs(entities[pistol].rot.z)<0.1,'releasing D returns only yaw while W holds pitch')
held[32]=nil advance(650)
check(math.abs(entities[pistol].rot.x)<0.1,'releasing W returns remaining axis')
local cameraId=next(cameras)
local browseFov=cameras[cameraId].fov
press('enter') advance(320)
local z=entities[pistol].pos.z
check(math.abs(z-1.24)<0.001 and cameras[cameraId].fov<browseFov,'Enter changes zoom only, no second lift')
advance(500) check(math.abs(entities[pistol].pos.z-1.24)<0.001 and X.state=='Preview','counter preview reaches configured height')
select('pistol_light') advance(700)
check(entities[pistol].components.COMPONENT_AT_PI_FLSH,'highlight previews compatible component on real weapon object')
check(X.state=='Preview','component highlight does not restart camera transition')
select('pistol_suppressor') advance(32)
check(not entities[pistol].components.COMPONENT_AT_PI_FLSH and entities[pistol].components.COMPONENT_AT_PI_SUPP_02,'moving to next attachment swaps preview immediately')
select('ammo')
check(not next(entities[pistol].components),'leaving attachment row removes preview')
check(payload.items[payload.selected].options[1].label:find('96') and payload.items[payload.selected].description:find('12'),'ammo menu shows price and rounds per magazine')
componentModelsReady=false select('pistol_light') advance(32) select('ammo') advance(32)
componentModelsReady=true advance(100)
check(not next(entities[pistol].components),'cancelled delayed component load never attaches after leaving row')
select('pistol_light')
press('enter') advance(32)
check(purchaseCalls==1 and requests[#requests].offer=='pistol_light','submenu uses existing authoritative purchase action')
press('back') advance(320)
check(math.abs(entities[pistol].pos.z-1.24)<0.001,'back zooms out while selected prop remains presented')
advance(500)
check(not next(entities[pistol].components) and X.state=='Browse','preview component removed on back')
local previousLight = lights[now]
select('rifle') advance(140)
check(lights[now] and math.abs(lights[now].z-previousLight.z)<0.2,'selection light interpolates instead of jumping to next weapon')
check(entities[pistol].pos.z<1.24 and entities[pistol].pos.z>1,'changing highlighted weapon smoothly lowers previous prop')
local rifle=instance.objects.rifle.entity
check(entities[rifle].pos.y==1,'next weapon waits for its own camera arrival')
select('pistol') advance(140)
check(entities[rifle].pos.y==1,'rapid scroll cancels presentation of skipped weapon')
select('rifle') advance(1150)
check(entities[rifle].pos.y<1 and entities[rifle].pos.z==1.5,'wall weapon moves forward already on highlight')
select('payment')
check(not payload.items[payload.selected].hint,'payment row hides weapon inspection hint')
select('rifle') advance(1150)
press('enter') advance(700)
press('back') advance(700) press('back') advance(600)
check(not frozen and not rendered and not next(cameras) and view==nil,'menu exit restores player and deletes camera')
check(entities[rifle].pos.y==1 and entities[pistol].pos.z==1,'all props return home on exit')
advance(300)
check(not lights[now],'closing shop leaves no selection light behind')
run(function() X.openShop(X.shops.test_shop,{session='death-session'}) end,100)
dead=true advance(350)
check(not frozen and not rendered and not next(cameras) and not view,'death abort releases menus and camera') dead=false
run(function() X.openShop(X.shops.test_shop,{session='abort-session'}) end,100)
view=nil advance(100)
check(not frozen and not rendered and not next(cameras),'unexpected UI abort releases camera and player')

playerPos.x=0.75 -- Real distances are fractional; Lua 5.4 rejects them with %d.
run(function() emit('rp_commerce:weaponEditor') end,100)
check(X.dev and payload.subtitle:find('DEV'),'authenticated dev command opens existing NativeUI')
check(payload.items[2].rightLabel=='1 m','fractional shop distance renders rounded metres without integer-format error')
playerPos.x=0
press('enter') -- create shop
check(X.draft and #X.draft.displays==0,'new shop uses local draft')
select('npc') press('enter') press('enter') advance(100)
check(X.draft.npc and X.instances.draft.npc,'NPC checkbox creates preview clerk')
check(floorRay.z==playerPos.z+0.5 and X.draft.npc.pos.z==-1,'editor stores actual supporting floor without permanent half-metre lift')
check(math.abs(entities[X.instances.draft.npc].pos.z)<0.001,'initial preview aligns actual foot bones despite oversized model bounds')
select('here') press('enter') advance(100)
check(X.draft.npc.pos.z==-1,'explicit placement resolves fresh position without accumulating correction')
local previousClerk=X.instances.draft.npc
select('model') press('right') advance(100)
check(X.draft.npc.model==W.clerkModels[2],'NPC model selected by list')
local changedClerk=X.instances.draft.npc
check(not entities[previousClerk] and not protected[previousClerk],'model change releases old NPC')
check(math.abs(entities[changedClerk].pos.z+0.1)<0.001 and X.draft.npc.pos.z==-1,'model change preserves floor anchor using the new skeleton height')
check(animations[changedClerk].clip=='_idle','model change immediately restarts crossed-arm idle without scenario toggle')
animationsReady=false
press('left') advance(100)
local loadingClerk=X.instances.draft.npc
press('right') advance(100)
animationsReady=true advance(100)
check(not entities[loadingClerk] and animations[X.instances.draft.npc].clip=='_idle','pending animation on replaced model cancels; latest model receives idle')
pedModelsReady=false
press('left') advance(100) press('right') advance(100)
pedModelsReady=true advance(100)
check(entities[X.instances.draft.npc].model==X.draft.npc.model,'rapid model selection during asset load creates only the latest model')
check(X.draft.npc.pos.z==-1,'repeated model replacements never accumulate initial height correction')
press('back') select('displays') press('enter') press('enter') select('pistol') press('enter') select('counter') press('enter')
advance(100)
check(view==nil and X.dev and #X.draft.displays==1,'placement releases menu for raycast aiming')
emit('rp_core:inputPressed','rp_commerce:interact') advance(100)
check(view=='nativeui' and X.draft.displays[1].pos.x==1,'bound interaction confirms raycast position')
select('transform') press('enter') select('pos_x') press('right')
check(math.abs(X.draft.displays[1].pos.x-1.01)<0.001,'fine position moves by selected centimetre step')
keyboard='1.125' press('enter') advance(100)
check(X.draft.displays[1].pos.x==1.125 and view=='nativeui','native numeric input restores editor navigation')
press('back') select('duplicate') press('enter')
check(#X.draft.displays==2 and X.draft.displays[1].id~=X.draft.displays[2].id,'duplicate receives separate display ID')
select('preview') press('enter') advance(800)
check(X.state=='Browse' and rendered,'dev preview runs real camera path')
press('enter') press('enter') advance(100)
check(purchaseCalls==1,'dev camera preview cannot buy items')
press('back') press('back') advance(600)
check(X.dev and not rendered and view=='nativeui','preview exit returns to suspended editor')
press('back') press('back') select('save') press('enter') advance(100)
check(saved and #saved.displays==2 and saved.npc.model==W.clerkModels[2],'editor saves complete transforms and NPC configuration')
press('back') press('back')
check(not X.dev and not view and not X.instances.draft,'closing editor cleans local draft and menus')
-- The normal shop editor reuses the same authenticated shell and NPC placement.
dofile(base..'rp_commerce/shared/shops.lua')
local regularSaved,regularShops=nil,{}
local previousCallback=lib.callback.await
local definitions={rp_water={label='Wasser'},rp_sandwich={label='Sandwich'}}
exports.rp_inventory={Items=function(_,name) return name and definitions[name] or definitions end}
lib.callback.await=function(name,delay,...)
    local args={...}
    if name=='rp_commerce:shopEditorOpen' then return {ok=true,token='normal-edit',bucket=0,shops={},catalog={{name='rp_water',label='Wasser'},{name='rp_sandwich',label='Sandwich'}}} end
    if name=='rp_commerce:shopEditorSave' then
        local clean,err=Commerce.Shops.validate(args[4]) assert(clean,err)
        regularSaved=clean regularSaved.id,regularSaved.revision='normal_test',1 regularShops={W.copy(regularSaved)}
        return {ok=true,token='normal-next',shop=W.copy(regularSaved)}
    end
    if name=='rp_commerce:shops' then return {ok=true,shops=W.copy(regularShops)} end
    return previousCallback(name,delay,...)
end
dofile(base..'rp_commerce/client/shop_editor.lua')
dofile(base..'rp_commerce/client/shops.lua')
run(function() emit('rp_commerce:shopEditor') end,100)
check(X.dev and payload.title=='LADENVERWALTUNG','normal editor opens same mint NativeUI shell')
press('enter')
check(X.draft.normalshop and #X.draft.offers==0,'new normal draft uses ordinary shop schema')
select('npc') press('enter') press('enter') advance(100)
check(X.draft.npc.model=='mp_m_shopkeep_01' and X.instances.draft.npc,'normal clerk preview uses shopkeeper and floor-placement code')
check(X.draft.npc.pos.z==-1,'normal shop also stores supporting floor without hover offset')
press('back') select('offers') press('enter') press('enter') select('item_1') press('enter')
check(#X.draft.offers==1 and X.draft.offers[1].item=='rp_water','catalogue selection adds server-supplied item')
select('price') keyboard='19' press('enter') advance(100)
select('count') keyboard='3' press('enter') advance(100)
check(X.draft.offers[1].price==19 and X.draft.offers[1].count==3,'normal offer price and pack editor')
press('back') press('enter') select('item_1') press('enter')
check(#X.draft.offers==2,'already stocked items excluded from picker')
select('remove') press('enter')
check(#X.draft.offers==1 and payload.subtitle=='SORTIMENT','remove rewinds to valid assortment callbacks')
press('back') select('blip') press('enter') select('color') keyboard='4' press('enter') advance(100)
check(X.draft.blip.color==4,'blip editor changes colour')
press('back') select('save') press('enter') advance(100)
check(regularSaved and regularSaved.offers[1].price==19 and regularSaved.npc.model=='mp_m_shopkeep_01','normal draft persisted through separate server callback')
press('back') press('back') advance(4500)
check(not X.dev and not X.instances.draft,'normal editor closes and clears draft')
check(Commerce.Config.venues.normal_test and X.instances['store:normal_test'],'published ordinary shop streams its NPC and interaction')
advance(8000) -- Covers the shared cross-NPC speech gap after closing the editor.
local normalPed=X.instances['store:normal_test'].npc
local normalGreeting=false
for _,s in ipairs(speeches) do if s.ped==normalPed and s.speech=='GENERIC_HI' then normalGreeting=true end end
check(normalGreeting,'saved ordinary shopkeeper greets through the shared core outside dev mode')
local normalGesture=false
for _,a in ipairs(animationLog) do if a.ped==normalPed and a.clip=='gesture_hello' then normalGesture=true end end
check(normalGesture,'ordinary shop scenario receives generic gesture instead of gunstore-only exclusion')
emit('onResourceStop','rp_commerce')
check(not next(entities) and not next(cameras) and not next(protected) and not frozen,'resource stop leaves no props, NPCs, camera or freeze')
print(('PASS: %d Ammu-Nation client / camera / editor assertions'):format(count))
