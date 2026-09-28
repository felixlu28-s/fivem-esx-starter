local C = Characters.Config
local ground
Characters.Scene = {}
local S = Characters.Scene
function S.place()
    if not ground then return end
    local ped, scene = PlayerPedId(), C.studio
    -- Ground elevation is not the ped's centre. This native adds its Z radius.
    SetEntityCoords(ped, scene.x, scene.y, ground, false, false, false, false)
    SetEntityHeading(ped, scene.heading)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
end
function S.clear() ground = nil ClearFocus() end
function S.prepare()
    ground = nil
    local scene = C.studio
    RequestCollisionAtCoord(scene.x, scene.y, scene.z)
    SetFocusPosAndVel(scene.x, scene.y, scene.z, 0.0, 0.0, 0.0)
    NetworkResurrectLocalPlayer(scene.x, scene.y, scene.z + 1.0, scene.heading, true, false)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, scene.x, scene.y, scene.z + 1.0, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    local deadline = GetGameTimer() + 5000
    repeat
        RequestCollisionAtCoord(scene.x, scene.y, scene.z)
        local found, z = GetGroundZFor_3dCoord(scene.x, scene.y, scene.z + 5.0, false)
        if found and type(z) == 'number' and math.abs(z - scene.z) <= 5.0 and HasCollisionLoadedAroundEntity(ped) then
            ground = z
            S.place()
            ClearFocus()
            SetEntityVisible(ped, true, false)
            return true
        end
        Wait(50)
    until GetGameTimer() >= deadline
    ClearFocus()
    print('[rp_characters] Preview ground/collision unavailable; retry from the arrival screen.')
    return false
end
