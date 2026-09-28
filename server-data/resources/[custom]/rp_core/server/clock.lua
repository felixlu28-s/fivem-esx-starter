-- Only the server publishes world time. No client event can set it.
CreateThread(function()
    while true do
        GlobalState['rp_core:worldClock'] = RP.Clock.fromUtc(os.date('!*t'))
        Wait(1000)
    end
end)
