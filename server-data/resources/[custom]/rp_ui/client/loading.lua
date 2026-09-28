-- FiveM owns loading progress. rp_characters owns the ESX entry lifecycle.
-- This adapter only presents stages and releases the dedicated loading frame.
local closing, closed = false, false
local function message(phase)
    SendLoadingScreenMessage(json.encode({ action = 'ui:loading', data = { phase = phase } }))
end
local function shutdown()
    if closed then return end
    closed = true
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
end
local function finish(immediate)
    if closing or closed then return end
    closing = true
    if immediate then shutdown() return end
    ShutdownLoadingScreen()
    message('exiting')
    -- Never wait for a browser callback; even a failed/missing bundle is released.
    SetTimeout(650, shutdown)
end

exports('rpLoadingPhase', function(phase)
    if closed or closing or (phase ~= 'session' and phase ~= 'scene') then return false end
    message(phase)
    return true
end)
exports('rpFinishLoading', function() finish(false) end)

-- Bounded fallback from client-script startup (not the potentially long download).
-- Only releases presentation, never marks a character loaded or bypasses ESX.
SetTimeout(120000, function()
    if not closed then
        if GetIsLoadingScreenActive() then
            print('[rp_ui] Loading-screen handoff timed out; releasing the loading frame.')
        end
        finish(true)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and not closed then shutdown() end
end)
