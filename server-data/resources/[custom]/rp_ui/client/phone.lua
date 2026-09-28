local payload=false
exports('rpPhoneEvent',function(data)
    if GetInvokingResource()~='rp_phone' or type(data)~='table' then return false end
    SendNUIMessage({action='ui:phoneApp',data=data}) return true
end)
local function send() SendNUIMessage({action='ui:phone',data=payload}) end
exports('rpSetPhone',function(data)
    if GetInvokingResource()~='rp_phone' then return false end
    if data~=false and (type(data)~='table' or type(data.available)~='boolean' or type(data.open)~='boolean'
        or type(data.session)~='string' or #data.session>100 or type(data.toggleKey)~='string' or #data.toggleKey>32) then return false end
    payload=data send() return true
end)
AddEventHandler('rp_ui:ready',send)
AddEventHandler('onResourceStop',function(resource)
    if resource=='rp_phone' or resource==GetCurrentResourceName() then payload=false send() end
end)
