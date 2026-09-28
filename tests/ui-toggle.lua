local api, callbacks, events, sent = {}, {}, {}, {}
local owner, key = 'rp_inventory', 'I'
exports = setmetatable({rp_core={rpGetBindings=function()
    return {actions={{id='rp_inventory:open',key=key}}}
end}}, {__call=function(_, name, fn) api[name]=fn end})
function GetInvokingResource() return owner end
function RegisterNUICallback(name, fn) callbacks[name]=fn end
function AddEventHandler(name, fn) events[name]=fn end
function RegisterCommand() end
function SendNUIMessage(value) sent[#sent+1]=value end
function SetNuiFocus() end
function SetNuiFocusKeepInput() end
function TriggerEvent() end
function GetCurrentResourceName() return 'rp_ui' end
local passed = 0
local function check(value, label) assert(value,label) passed=passed+1 end
dofile('server-data/resources/[custom]/rp_ui/client/main.lua')
api.rpOpen('inventory',{},false,{toggleAction='rp_inventory:open'})
check(sent[#sent].data.toggleKey=='I', 'opening key comes from current registry')
key = 'J'
events['rp_core:bindingsChanged']()
check(sent[#sent].data.toggleKey=='J', 'open UI follows updated key')
key = ''
events['rp_core:bindingsChanged']()
check(sent[#sent].data.toggleKey=='', 'unbound does not use default')
local result
callbacks['ui:close']({},function(value) result=value end)
check(result.ok and api.rpGetView()==nil, 'normal close route closes toggled view')
owner = 'rp_characters'
api.rpOpen('characters',{},true)
check(sent[#sent].data.toggleKey==nil, 'new view does not inherit previous toggle')
callbacks['ui:close']({},function(value) result=value end)
check(not result.ok and result.error=='locked' and api.rpGetView()=='characters', 'toggle cannot bypass locked creation')
print(('PASS: %d UI toggle routing, rebinding and lock assertions'):format(passed))
