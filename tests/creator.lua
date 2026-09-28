-- Model-dependent catalogs, server wardrobe restrictions and camera lifecycle.
local root = 'server-data/resources/[custom]/rp_characters/'
for _, file in ipairs({ 'config', 'wardrobe', 'appearance', 'validation' }) do
    dofile(root .. 'shared/' .. file .. '.lua')
end
local A, W, count = Characters.Appearance, Characters.Wardrobe, 0
Characters.Scene = { place = function() end }
local function check(value, message) assert(value, message) count = count + 1 end
for sex = 0, 1 do
    local skin = A.defaults(sex)
    check(A.validateCreation(skin) ~= nil, 'both freemode defaults pass creation')
    for _, key in ipairs({ 'torso_1', 'pants_1', 'shoes_1' }) do
        check(#W[sex][key] == 12, 'exactly twelve arrival choices per main category')
        local seen = {}
        for _, option in ipairs(W[sex][key]) do
            check(not seen[option.value], 'unique drawable choices')
            seen[option.value] = true
            local candidate = A.defaults(sex)
            candidate[key] = option.value
            for k, v in pairs(option.skin or {}) do candidate[k] = v end
            check(A.validateCreation(candidate) ~= nil, 'every paired outfit can be saved')
        end
    end
    skin.torso_1 = 999
    check(A.validateCreation(skin) == nil, 'arbitrary clothing rejected at creation')
    check(A.validate(skin) ~= nil, 'legacy owned clothes still load')
    skin = A.defaults(sex)
    skin.arms = 999
    check(A.validateCreation(skin) == nil, 'top matching cannot be bypassed')
    skin = A.defaults(sex)
    skin.bproof_1 = 1
    check(A.validateCreation(skin) == nil, 'armour is not arrival clothing')
    skin = A.defaults(sex)
    skin.pants_2 = 12
    check(A.validateCreation(skin) == nil, 'arrival textures are bounded')
end
local skin = A.defaults(1)
skin.beard_2 = 10
check(not A.validateCreation(skin), 'unsupported female beard rejected')

local model, applied, renders, creates, destroys = 'mp_m_freemode_01', nil, 0, 0, 0
local threads, position = {}, nil
function joaat(value) return value end
function PlayerPedId() return 1 end
function PlayerId() return 1 end
function RequestModel() end
function HasModelLoaded() return true end
function GetGameTimer() return 1 end
function GetEntityModel() return model end
function SetPlayerModel(_, value) model = value end
function GetNumberOfPedDrawableVariations(_, component)
    if component == 2 then return model == 'mp_f_freemode_01' and 83 or 79 end
    return 1000
end
function GetNumberOfPedTextureVariations() return 24 end
function GetNumberOfPedPropDrawableVariations() return 13 end
function GetNumberOfPedPropTextureVariations() return 20 end
function GetPedHeadOverlayNum() return 75 end
function TriggerEvent(name, value, cb)
    assert(name == 'skinchanger:loadSkin')
    applied = value
    cb()
end
function SetModelAsNoLongerNeeded() end
function SetEntityVisible() end
function SetEntityInvincible() end
function FreezeEntityPosition() end
function CreateCam() creates = creates + 1 return creates end
function RenderScriptCams() renders = renders + 1 end
function DestroyCam() destroys = destroys + 1 end
function ClearFocus() end
function GetEntityCoords() return { x = 0, y = 0, z = 20 } end
function GetEntityHeading() return 0 end
function SetCamCoord(_, x, y, z) position = { x = x, y = y, z = z } end
function PointCamAtCoord() end
function SetCamFov() end
function SetCamActive() end
local lights = 0
function DrawLightWithRange(_, _, _, r, g, b, range, intensity)
    assert(r >= 0 and r <= 255 and g >= 0 and g <= 255 and b >= 0 and b <= 255)
    assert(range <= 4 and intensity <= 1)
    lights = lights + 1
end
function CreateThread(fn) threads[#threads + 1] = coroutine.create(fn) end
function GetFrameTime() return 1 / 60 end
function Wait() coroutine.yield() end
dofile('server-data/resources/[custom]/rp_core/lib/portrait_camera.lua')
dofile(root .. 'client/camera.lua')
dofile(root .. 'client/appearance.lua')
check(A.apply(A.defaults(0)), 'male appearance applied')
check(model == 'mp_m_freemode_01' and applied.sex == 0, 'male freemode model')
local function field(key)
    for _, item in ipairs(A.catalog()) do if item.key == key then return item end end
end
check(field('beard_1') ~= nil and field('hair_1').max == 78, 'male native catalog')
check(A.change('sex', 1), 'female switch succeeds')
check(model == 'mp_f_freemode_01' and applied.sex == 1, 'female freemode model is loaded')
check(field('beard_1') == nil and field('chest_1') == nil, 'unsupported female overlays hidden')
check(field('hair_1').max == 82, 'hair limits refreshed from new model')
check(#field('torso_1').options == 12 and field('torso_1').options[2].value == 1, 'female wardrobe')
check(not field('arms') and not field('tshirt_1'), 'technical body components are automatic')
check(not A.change('beard_2', 10) and not A.change('torso_1', 900), 'UI restrictions also enforced client-side')
check(A.change('torso_1', 4) and A.current().arms == 4 and A.current().tshirt_1 == 15, 'top applies matched body components')
check(field('torso_2').max == 11, 'native texture limits capped for arrival')
check(#field('helmet_1').options < #W[1].helmet_1, 'unavailable native prop IDs filtered')
check(creates == 1 and renders == 1, 'appearance changes do not restart camera interpolation')
check(not A.camera({ view = 'invalid' }), 'invalid camera preset rejected')
check(not A.camera({ pitch = 36 }) and not A.camera({ zoom = -1 }), 'camera bounds enforced')
check(not A.camera({ rotation = 0/0 }) and not A.camera({ zoom = math.huge }), 'nonfinite camera values rejected')
for _, view in ipairs({ 'body', 'face', 'upper', 'lower', 'shoes' }) do
    check(A.camera({ view = view, rotation = 179, pitch = -25, zoom = 0 }), 'all presets supported')
    for _ = 1, 90 do assert(coroutine.resume(threads[#threads])) end
    check(position.z >= 19.08 and position.z < 25, 'camera remains above floor at closest zoom')
end
local before = position.x
check(lights > 0 and lights % 2 == 0, 'two bounded neutral fill lights accompany camera frames')
check(A.camera({ rotation = -179 }), 'yaw wraps across seam')
assert(coroutine.resume(threads[#threads]))
check(math.abs(position.x - before) < 0.03, 'yaw uses shortest path across 180 degrees')
A.destroyCamera()
local stoppedLights = lights
check(destroys == 1 and renders == 2, 'camera cleanup restores gameplay')
assert(coroutine.resume(threads[1]))
check(coroutine.status(threads[1]) == 'dead', 'camera thread stops after cleanup')
check(lights == stoppedLights, 'preview lighting stops with the camera')
-- Fitting-room exit retains its camera until the engine finishes interpolating.
local exits, deferred = {}, {}
function SetTimeout(ms, fn) check(ms==400,'exit duration matches entry') deferred[#deferred+1]=fn end
local previousRender=RenderScriptCams
function RenderScriptCams(render,ease,duration) previousRender() exits[#exits+1]={render,ease,duration} end
local fitting=RpPortraitCamera()
check(fitting.update({view='body'}),'fitting camera opens')
local oldDestructions=destroys
fitting.close(true)
check(destroys==oldDestructions and exits[#exits][1]==false and exits[#exits][2] and exits[#exits][3]==400,'close eases without immediately destroying camera')
deferred[1]()
check(destroys==oldDestructions+1,'camera retired after smooth return')
fitting.update({view='face'}) fitting.close(true)
fitting.update({view='body'})
local afterReopen=destroys
deferred[2]()
check(destroys==afterReopen and exits[#exits][1]==true,'old timeout cannot destroy or stop reopened camera')
fitting.close(true) fitting.close(false)
local afterStop=destroys
deferred[3]()
check(destroys==afterStop,'resource stop drains retiring camera exactly once')
-- Streamed ground is a floor elevation, not the ped centre used by NoOffset.
local clock, probes, visible, placed, focusCleared = 0, 0, false, nil, false
local foundGround, collision = true, true
function GetGameTimer() return clock end
function Wait(ms) clock = clock + ms end
function RequestCollisionAtCoord() probes = probes + 1 end
function SetFocusPosAndVel() focusCleared = false end
function ClearFocus() focusCleared = true end
function NetworkResurrectLocalPlayer(_, _, z) check(z > Characters.Config.studio.z, 'initial preview starts above nominal floor') end
function SetEntityCoordsNoOffset() end
function SetEntityCoords(_, x, y, z) placed = {x=x,y=y,z=z + 1.0} end -- native Z-radius offset
function SetEntityHeading() end
function SetEntityVisible(_, value) visible = value end
function HasCollisionLoadedAroundEntity() return collision end
function GetGroundZFor_3dCoord() return foundGround, Characters.Config.studio.z + 0.2 end
dofile(root .. 'client/scene.lua')
check(Characters.Scene.prepare() and placed.z > Characters.Config.studio.z + 1, 'preview placement includes streamed floor and ped radius')
check(visible and focusCleared, 'preview visible only after successful placement and streaming focus released')
placed = nil
Characters.Scene.place()
check(placed ~= nil, 'recreated male/female preview ped can be repositioned on cached floor')
Characters.Scene.clear()
placed = nil
Characters.Scene.place()
check(placed == nil, 'cleanup disables preview relocation during gameplay')
foundGround, clock, probes = false, 0, 0
check(not Characters.Scene.prepare() and clock == 5000 and probes > 1, 'missing ground times out with bounded streaming retries')
check(not visible and focusCleared, 'missing floor never exposes sunk ped or leaves streaming focus locked')
foundGround, collision, clock = true, false, 0
check(not Characters.Scene.prepare(), 'ground without collision is not considered ready')
collision = true
check(Characters.Scene.prepare() and visible, 'retry can recover once ground and collision are ready')
print(('PASS: %d creator, wardrobe, model and camera checks'):format(count))
