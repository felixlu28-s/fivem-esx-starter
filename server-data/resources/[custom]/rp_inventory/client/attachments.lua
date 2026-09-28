-- Presentation only. Inventory and attachment return have already committed atomically.
local current
local function clear()
    local context=current
    if not context then return end
    current=nil
    Inventory.attachmentBusy=false
    StopAnimTask(context.ped,context.dict,context.clip,2.0)
    RemoveAnimDict(context.dict)
    Inventory.presentAttachment(nil)
end
function Inventory.animateAttachment(effect)
    clear()
    if type(effect.component)~='string' or type(effect.install)~='boolean' or not Inventory.selectWeapon(effect) then return end
    if exports.rp_ui:rpGetView()=='inventory' then exports.rp_ui:rpClose() end
    local context={ped=PlayerPedId(),dict='anim@amb@machinery@weapon_test@',
        clip='weapon_inspect_01_amy_skater_01'}
    current=context
    Inventory.attachmentBusy=true
    local function alive()
        return current==context and context.ped==PlayerPedId() and not IsEntityDead(context.ped)
            and not IsPedRagdoll(context.ped) and Inventory.weaponInstanceAvailable(effect)
    end
    CreateThread(function()
        RequestAnimDict(context.dict)
        local deadline=GetGameTimer()+2000
        while alive() and not HasAnimDictLoaded(context.dict) and GetGameTimer()<deadline do Wait(25) end
        if not alive() or not HasAnimDictLoaded(context.dict) then if current==context then clear() end return end
        Inventory.presentAttachment(effect)
        -- Upper body only, native weapon stays in the right hand; no ammo/reload task.
        TaskPlayAnim(context.ped,context.dict,context.clip,4.0,-4.0,2400,48,0.0,false,false,false)
        local start=GetGameTimer()
        local applied=false
        while alive() and GetGameTimer()-start<2400 do
            DisablePlayerFiring(PlayerId(),true)
            for _,control in ipairs({24,25,37,45,140,141,142}) do DisableControlAction(0,control,true) end
            if GetSelectedPedWeapon(context.ped)~=joaat(effect.name) then break end
            if not applied and GetGameTimer()-start>=1400 then
                applied=true Inventory.presentAttachment(nil)
            end
            Wait(0)
        end
        if current==context then clear() end
    end)
end
AddEventHandler('esx:onPlayerLogout',clear)
AddEventHandler('onResourceStop',function(resource) if resource==GetCurrentResourceName() then clear() end end)
