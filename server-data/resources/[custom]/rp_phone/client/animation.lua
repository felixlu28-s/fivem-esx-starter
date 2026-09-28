PhoneMotion = {}
local A = PhoneMotion
local state
local model = joaat('prop_npc_phone_02')
local unarmed = joaat('WEAPON_UNARMED')
local gestures = { up='cellphone_up', down='cellphone_down', left='cellphone_left', right='cellphone_right',
    enter='cellphone_select', back='cellphone_swipe_screen' }
local gestureMask = 'BONEMASK_HEAD_NECK_AND_R_ARM'
local function current(s) return state == s and DoesEntityExist(s.ped) and PlayerPedId() == s.ped and not IsEntityDead(s.ped) end
local function stopGesture(s)
    if not s.gesture then return end
    if DoesEntityExist(s.ped) then TaskStopPhoneGestureAnimation(s.ped, 0.15) end
    s.gesture = false
end
local function play(s, dict, clip, duration, flags)
    if s.clip then StopAnimTask(s.ped, s.dict, s.clip, 2.0) end
    s.dict, s.clip = dict, clip
    TaskPlayAnim(s.ped, dict, clip, 3.0, -3.0, duration, flags or 48, 0.0, false, false, false)
end
function A.clear()
    local s = state state = nil
    if not s then return end
    stopGesture(s)
    if DoesEntityExist(s.ped) and s.clip then StopAnimTask(s.ped, s.dict, s.clip, 2.0) end
    if s.object and DoesEntityExist(s.object) then DeleteEntity(s.object) end
    if DoesEntityExist(s.ped) and PlayerPedId()==s.ped and not IsEntityDead(s.ped)
        and s.weapon and s.weapon~=unarmed and GetSelectedPedWeapon(s.ped)==unarmed and HasPedGotWeapon(s.ped,s.weapon,false) then
        SetCurrentPedWeapon(s.ped,s.weapon,true)
    end
    RemoveAnimDict('cellphone@')
    RemoveAnimDict(s.base)
    SetModelAsNoLongerNeeded(model)
end
function A.open()
    A.clear()
    local ped = PlayerPedId()
    local base = IsPedInAnyVehicle(ped, false) and 'anim@cellphone@in_car@ps'
        or (IsPedMale(ped) and 'cellphone@' or 'cellphone@female')
    local s = { ped=ped, base=base, vehicle=IsPedInAnyVehicle(ped,false), stage='opening', gestureAt=0 }
    state = s
    RequestModel(model) RequestAnimDict(base) RequestAnimDict('cellphone@')
    local deadline = GetGameTimer() + 3000
    while current(s) and GetGameTimer() < deadline and (not HasModelLoaded(model)
        or not HasAnimDictLoaded(base) or not HasAnimDictLoaded('cellphone@')) do Wait(25) end
    if not current(s) then return false end
    if not HasModelLoaded(model) or not HasAnimDictLoaded(base) or not HasAnimDictLoaded('cellphone@') then A.clear() return false end
    s.weapon=GetSelectedPedWeapon(ped)
    SetCurrentPedWeapon(ped,unarmed,true)
    play(s, base, 'cellphone_text_in', 750)
    Wait(300)
    if not current(s) or s.stage~='opening' then return false end
    local p = GetEntityCoords(ped)
    local bone = GetPedBoneIndex(ped, 28422)
    if bone <= 0 then A.clear() return false end
    local object = CreateObjectNoOffset(model, p.x, p.y, p.z, true, true, false)
    if object == 0 then A.clear() return false end
    s.object = object
    SetEntityCollision(object, false, false)
    AttachEntityToEntity(object, ped, bone, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)
    SetModelAsNoLongerNeeded(model)
    Wait(450)
    if not current(s) or s.stage~='opening' then return false end
    s.stage = 'open'
    play(s, base, 'cellphone_text_read_base', -1, 49)
    return true
end
function A.gesture(key)
    local s, now = state, GetGameTimer()
    if not s or not current(s) or s.stage~='open' or s.camera or not gestures[key] or now < s.gestureAt then return end
    s.gestureAt = now + 220
    -- Navigation clips contain finger movements. They belong on GTA's phone
    -- gesture layer; replacing the secondary holding task lowers the whole arm.
    -- Keep the gender/vehicle-specific holding loop and attached prop untouched.
    TaskPlayPhoneGestureAnimation(s.ped, 'cellphone@', gestures[key], gestureMask, 0.15, 0.15, false, false)
    s.gesture = true
end
function A.cameraAnchor()
    local s=state
    if s and current(s) and s.stage=='open' and s.object and DoesEntityExist(s.object) then return s.object,s.ped end
end
function A.cameraPose(active)
    local s=state
    if not s or not current(s) or s.stage~='open' or s.camera==active then return end
    stopGesture(s) s.camera=active
    if active and not s.vehicle then play(s,'cellphone@','cellphone_photo_idle',-1,49)
    else play(s,s.base,'cellphone_text_read_base',-1,49) end
end
function A.close()
    local s = state
    if not s or not current(s) then A.clear() return end
    s.stage = 'closing'
    stopGesture(s)
    play(s, s.base, 'cellphone_text_out', 650)
    Wait(500)
    if state == s then A.clear() end
end
function A.valid()
    return state and current(state) and not IsPedRagdoll(state.ped) and IsPedInAnyVehicle(state.ped,false)==state.vehicle
        and (state.stage=='opening' or (state.object and DoesEntityExist(state.object)))
end
