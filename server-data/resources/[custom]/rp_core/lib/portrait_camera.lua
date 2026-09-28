-- Shared creator / fitting-room camera. Each resource owns and cleans up its instance.
function RpPortraitCamera()
local A = {}
local presets = {
    body = { height = 0.0, min = 1.8, max = 4.0, distance = 2.8 },
    face = { height = 0.66, min = 0.5, max = 1.4, distance = 0.85 },
    upper = { height = 0.25, min = 0.8, max = 2.6, distance = 1.5 },
    lower = { height = -0.45, min = 0.9, max = 2.6, distance = 1.7 },
    shoes = { height = -0.85, min = 0.55, max = 1.8, distance = 1.0 },
}
local camera, generation, current = nil, 0, nil
local retiring = {}
local function clearRetiring()
    for handle in pairs(retiring) do DestroyCam(handle, false) end
    retiring = {}
end
local target = { view = 'body', rotation = 0, pitch = 0, zoom = 0.454545 }
local function finite(value, min, max)
    return type(value) == 'number' and value == value and value >= min and value <= max
end
local function draw(dt)
    local preset, ped = presets[target.view], PlayerPedId()
    local pos = GetEntityCoords(ped)
    local wanted = { height = preset.height, distance = preset.min + (preset.max - preset.min) * target.zoom,
        rotation = target.rotation, pitch = target.pitch }
    current = current or wanted
    local blend = 1.0 - math.exp(-12.0 * dt)
    for _, key in ipairs({ 'height', 'distance', 'pitch' }) do
        current[key] = current[key] + (wanted[key] - current[key]) * blend
    end
    local delta = (wanted.rotation - current.rotation + 180) % 360 - 180
    current.rotation = (current.rotation + delta * blend) % 360
    local yaw, pitch = math.rad(GetEntityHeading(ped) + current.rotation), math.rad(current.pitch)
    local horizontal = current.distance * math.cos(pitch)
    local z = pos.z + current.height
    SetCamCoord(camera, pos.x - math.sin(yaw) * horizontal, pos.y + math.cos(yaw) * horizontal,
        math.max(pos.z - 0.92, z + math.sin(pitch) * current.distance))
    PointCamAtCoord(camera, pos.x, pos.y, z)
    SetCamFov(camera, 40.0)
    -- Soft, camera-facing fill keeps skin/clothes readable against the sun.
    -- These lights exist for this frame only, not as persistent world entities.
    local frontX, frontY = -math.sin(yaw), math.cos(yaw)
    local sideX, sideY = math.cos(yaw), math.sin(yaw)
    DrawLightWithRange(pos.x + frontX * 2.0 + sideX * 1.2,
        pos.y + frontY * 2.0 + sideY * 1.2, pos.z + 1.3, 255, 247, 232, 4.0, 1.0)
    DrawLightWithRange(pos.x + frontX * 1.3 - sideX * 1.5,
        pos.y + frontY * 1.3 - sideY * 1.5, pos.z + 0.3, 228, 240, 255, 3.5, 0.55)
end
function A.camera(input)
    input = input or {}
    if type(input) ~= 'table' or (input.view ~= nil and not presets[input.view]) then return false end
    if (input.rotation ~= nil and not finite(input.rotation, -180, 180))
        or (input.pitch ~= nil and not finite(input.pitch, -25, 35))
        or (input.zoom ~= nil and not finite(input.zoom, 0, 1)) then return false end
    if input.view and input.view ~= target.view then
        local preset = presets[input.view]
        target.view, target.pitch = input.view, 0
        target.zoom = (preset.distance - preset.min) / (preset.max - preset.min)
    end
    for _, key in ipairs({ 'rotation', 'pitch', 'zoom' }) do
        if input[key] ~= nil then target[key] = input[key] end
    end
    if not camera then
        clearRetiring()
        camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        generation = generation + 1
        local owner = generation
        draw(1)
        SetCamActive(camera, true)
        RenderScriptCams(true, true, 400, true, true)
        CreateThread(function()
            while camera and owner == generation do
                draw(math.min(GetFrameTime(), 0.1))
                Wait(0)
            end
        end)
    end
    return true
end
function A.destroyCamera(smooth)
    generation = generation + 1
    if not smooth then clearRetiring() end
    if camera then
        local old = camera
        RenderScriptCams(false, smooth == true, smooth and 400 or 0, true, true)
        if smooth then
            local ticket = {}
            retiring[old] = ticket
            SetTimeout(400, function()
                -- Only retire this handle; never disable a subsequently opened camera.
                if retiring[old] ~= ticket then return end
                retiring[old] = nil
                DestroyCam(old, false)
            end)
        else DestroyCam(old, false) end
        camera = nil
    end
    current = nil
    target = { view = 'body', rotation = 0, pitch = 0, zoom = 0.454545 }
    ClearFocus()
end

return { update = A.camera, close = A.destroyCamera }
end
