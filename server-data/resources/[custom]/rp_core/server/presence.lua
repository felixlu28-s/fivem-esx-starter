-- Server-wide count, independent of client streaming range and routing buckets.
-- Publish only a count, never player identifiers or account data.
CreateThread(function()
    local previous
    while true do
        local count = #GetPlayers()
        if count ~= previous then
            GlobalState['rp_core:playerCount'] = count
            previous = count
        end
        Wait(2000)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then GlobalState['rp_core:playerCount'] = nil end
end)
