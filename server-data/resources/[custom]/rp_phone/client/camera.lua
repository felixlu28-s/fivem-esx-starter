PhoneCamera={}
local C=PhoneCamera
local state
local function clamp(value,min,max) return math.max(min,math.min(max,value)) end
function C.stop()
    local previous=state state=nil
    if previous then
        RenderScriptCams(false,true,200,true,true)
        DestroyCam(previous.cam,false)
        PhoneMotion.cameraPose(false)
    end
end
function C.configure(mode,zoom,owned)
    if mode=='off' then C.stop() return true end
    if mode~='rear' and mode~='selfie' then return false end
    if type(zoom)~='number' or zoom~=zoom or zoom<0.5 or zoom>3.0 then return false end
    local object,ped=PhoneMotion.cameraAnchor()
    if not object or not owned() or IsEntityDead(ped) then return false end
    if state and state.object==object and state.ped==ped then
        state.mode,state.zoom=mode,zoom
        return true -- lens/zoom changes reuse the camera and its frame loop.
    end
    C.stop()
    local cam=CreateCam('DEFAULT_SCRIPTED_CAMERA',true)
    if not cam or cam==0 then return false end
    state={cam=cam,object=object,ped=ped,mode=mode,zoom=zoom,fov=65.0,yaw=0.0,pitch=0.0}
    local s=state
    PhoneMotion.cameraPose(true)
    SetCamNearClip(cam,0.035)
    local lens=PhoneConfig.camera.lens[mode]
    local origin=GetOffsetFromEntityInWorldCoords(object,lens.x,lens.y,lens.z)
    SetCamCoord(cam,origin.x,origin.y,origin.z)
    SetCamRot(cam,0.0,0.0,GetEntityHeading(ped),2)
    SetCamFov(cam,s.fov)
    RenderScriptCams(true,true,200,true,true)
    CreateThread(function()
        local nextOwnership=0
        while state==s do
            local currentObject,currentPed=PhoneMotion.cameraAnchor()
            if currentObject~=s.object or currentPed~=s.ped or IsEntityDead(ped) then break end
            if GetGameTimer()>=nextOwnership then
                if not owned() then break end
                nextOwnership=GetGameTimer()+250
            end
            -- Lens is anchored to the held phone, never to a floating point in
            -- front of the character or to the gameplay camera's head position.
            local lens=PhoneConfig.camera.lens[s.mode]
            local p=GetOffsetFromEntityInWorldCoords(object,lens.x,lens.y,lens.z)
            local dt=math.min(GetFrameTime(),0.05)
            s.yaw=clamp(s.yaw-GetDisabledControlNormal(0,1)*6.0,-45.0,45.0)
            s.pitch=clamp(s.pitch-GetDisabledControlNormal(0,2)*6.0,-35.0,35.0)
            SetCamCoord(cam,p.x,p.y,p.z)
            if s.mode=='selfie' then
                local face=GetPedBoneCoords(ped,31086,0.0,0.0,0.025)
                PointCamAtCoord(cam,face.x+s.yaw*0.002,face.y,face.z+s.pitch*0.003)
            else
                StopCamPointing(cam)
                SetCamRot(cam,s.pitch,0.0,GetEntityHeading(ped)+s.yaw,2)
            end
            local target=math.deg(2*math.atan(math.tan(math.rad(PhoneConfig.camera.fov[s.mode])/2)/s.zoom))
            s.fov=s.fov+(clamp(target,20.0,105.0)-s.fov)*math.min(1,dt*12)
            SetCamFov(cam,s.fov)
            SetEntityLocallyInvisible(object) -- do not photograph the lens housing itself.
            HideHudAndRadarThisFrame()
            Wait(0) -- transform/HUD natives only while a phone camera is active.
        end
        if state==s then C.stop() end
    end)
    return true
end
function C.active() return state and state.cam or false end
