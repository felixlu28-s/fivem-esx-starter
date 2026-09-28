local base = 'server-data/resources/[custom]/'
local passed = 0
local function check(value, message) assert(value, message) passed = passed + 1 end
local api, events, commands, route = {}, {}, {}, nil
local owner, view, payload, options = 'rp_test', nil, nil, nil
local refuse = false
exports = setmetatable({ rp_ui = {
    rpOpen = function(_, name, data, locked, opts)
        if refuse then return false end
        check(locked == true, 'native view is locked')
        view, payload, options = name, data, opts return true
    end,
    rpClose = function() view, payload = nil, nil return true end,
    rpGetView = function() return view end,
    rpRegisterAction = function(_, name, fn) check(name == 'rp_nativeui:input', 'namespaced route') route = fn end,
}, rp_nativeui = setmetatable({}, { __index = function(_, name) return function(_, ...) return api[name](...) end end }) }, {
    __call = function(_, name, fn) api[name] = fn end,
})
function GetInvokingResource() return owner end
function GetCurrentResourceName() return 'rp_nativeui' end
function AddEventHandler(name, fn) events[name] = fn end
function CreateThread(fn) fn() end
function RegisterCommand(name, fn) commands[name] = fn end
function PlaySoundFrontend() end
function GetClockHours() return 12 end
function GetClockMinutes() return 30 end
dofile(base .. 'rp_nativeui/client/model.lua')
dofile(base .. 'rp_nativeui/client/api.lua')
local N = NativeMenu
local function def(items) return {title='Test',items=items or {}} end
local function action(id) return {id=id,label=id} end
local hinted=action('hinted') hinted.hint={keys={'W','A','S','D'},label='Inspect',detail='Release to return'}
check(N.definition(def({hinted}),owner).items[1].hint.keys[4]=='D','contextual key hint preserved')
hinted.hint.keys[4]=false
check(not N.definition(def({hinted}),owner),'invalid hint key rejected')
hinted.hint.keys={} check(not N.definition(def({hinted}),owner),'empty hint key list rejected')
local function press(key)
    return route({key=key,session=payload and payload.session,revision=payload and payload.revision})
end
check(not api.rpCreateMenu('../bad', def()), 'invalid IDs rejected')
check(not api.rpCreateMenu('bad', def({action('a'),action('a')})), 'duplicate rows rejected')
check(not api.rpCreateMenu('bad', def({{id='a',label='A',type='list',options={}}})), 'empty list rejected')
check(not api.rpCreateMenu('bad', def({{id='a',label='A',type='submenu',menu='foreign/menu'}})), 'foreign submenu rejected')
check(not api.rpCreateMenu('bad', {title='Test',items={},visibleRows=false}), 'false cannot become default')
check(not api.rpCreateMenu('bad', def({{id='a',label='A',description=false}})), 'wrong optional field types rejected')
check(not api.rpCreateMenu('bad', def({{id='a',label='A',type='list',index=false,options={{label='A',value=1}}}})), 'invalid index rejected')
check(not api.rpCreateMenu('bad', def(), {unknown=function()end}), 'unknown callback rejected')
check(not api.rpCreateMenu('bad', def(), {onSelect='code'}), 'non-callable callback rejected')
local highlights={}
local highlighted=assert(api.rpCreateMenu('highlight',def({action('first'),action('second')}),{
    onHighlight=function(id,item) highlights[#highlights+1]=id item.label='mutated callback copy' end,
}))
api.rpOpenMenu(highlighted)
press('down') press('up')
check(highlights[1]=='second' and highlights[2]=='first','highlight follows keyboard selection for shop camera')
check(payload.items[1].label=='first','highlight callback cannot mutate menu data')
api.rpCloseMenu()
local invoked, changed, closed, reject, explode = {}, {}, {}, false, false
local child = assert(api.rpCreateMenu('child', def({action('child_action')}), {
    onClose=function(reason) closed[#closed+1]=reason end,
}))
local root = assert(api.rpCreateMenu('root', def({
    action('action'),
    {id='list',label='List',type='list',options={{label='A',value='a'},{label='B',value=20},{label='C',value=false}}},
    {id='checkbox',label='Check',type='checkbox'},
    {id='child',label='Child',type='submenu',menu=child},
    {id='disabled',label='Locked',disabled=true},
}), {
    onSelect=function(id, item, handle)
        if explode then error('expected callback failure') end
        invoked[#invoked+1]={id,item,handle}
        return not reject
    end,
    onChange=function(id,value,index,handle)
        changed[#changed+1]={id,value,index,handle}
        return not reject
    end,
    onClose=function(reason) closed[#closed+1]=reason end,
}))
check(root == 'rp_test/root', 'handle scoped to owner')
check(not api.rpOpenMenu(root,{toggleAction='rp_other:open'}),'foreign toggle binding rejected')
check(api.rpOpenMenu(root,{toggleAction='rp_test:open'}) and options.toggleAction=='rp_test:open','root toggle passed to NUI')
check(api.rpPushMenu(child) and options.toggleAction=='rp_test:open','submenu inherits root toggle')
check(press('close').ok and view==nil,'toggle closes entire menu stack')
check(api.rpOpenMenu(root) and not press('close').ok,'close key rejected without opted-in binding')
api.rpCloseMenu()
check(not api.rpCreateMenu('root', def()), 'duplicate menu rejected')
owner = 'rp_other'
check(not api.rpOpenMenu(root) and not api.rpSetItems(root, {}) and api.rpGetMenuState(root)==nil, 'foreign resource blocked')
owner = 'rp_test'
view = 'characters'
check(not api.rpOpenMenu(root), 'other UI cannot be replaced')
view = nil
check(api.rpOpenMenu(root) and options.keyboardOnly, 'keyboard focus requested without cursor')
local stale = N.copy(payload)
check(not route({key='mouse',session=payload.session,revision=payload.revision}).ok, 'unknown key blocked')
check(press('enter').ok and #invoked==1 and invoked[1][1]=='action' and invoked[1][3]==root, 'action callback contract')
check(not route({key='enter',session=stale.session,revision=stale.revision}).ok and #invoked==1, 'replay cannot repeat action')
press('up')
check(payload.selected==5 and not press('enter').ok and #invoked==1, 'wrap and disabled activation')
press('down') press('down')
check(payload.selected==2, 'navigation wraps to first')
press('left')
check(payload.items[2].index==3 and changed[#changed][2]==false and changed[#changed][3]==3, 'list wraps with boolean value')
press('right')
check(payload.items[2].index==1 and changed[#changed][2]=='a', 'list right wraps')
press('enter')
check(invoked[#invoked][1]=='list', 'enter confirms list')
press('down') press('enter')
check(payload.items[3].checked and changed[#changed][1]=='checkbox' and changed[#changed][3]==nil, 'checkbox callback')
reject=true
check(not press('enter').ok and payload.items[3].checked, 'rejected checkbox restores prior value')
press('up')
check(not press('right').ok and payload.items[2].index==1, 'rejected list restores prior value')
press('down') press('down')
check(not press('enter').ok and payload.depth==1, 'onSelect can veto submenu')
reject=false
check(press('enter').ok and payload.depth==2, 'submenu opened')
check(not api.rpPushMenu(root), 'menu cycle blocked')
check(press('back').ok and payload.depth==1 and payload.selected==4 and closed[#closed]=='back', 'back restores parent selection')
refuse=true
check(not api.rpPushMenu(child), 'failed UI open reported')
refuse=false
check(press('back').closed and view==nil, 'failed push did not leave ghost stack entry')
api.rpOpenMenu(root)
local items = api.rpGetMenuState(root).definition.items
items[4],items[1] = items[1],items[4]
check(api.rpSetItems(root,items) and payload.selected==1 and payload.items[1].id=='child', 'dynamic reorder retains selection by ID')
items[1].label='External mutation'
check(payload.items[1].label=='Child', 'API stores independent copy')
check(api.rpSetItems(root,{}) and payload.selected==0, 'empty items valid')
check(press('down').ok and payload.selected==0 and not press('enter').ok, 'empty menu navigation safe')
check(press('back').closed, 'empty menu can close')
api.rpSetItems(root,{action('one')})
api.rpOpenMenu(root)
explode=true
check(not press('enter').ok, 'callback exception responded')
explode=false
check(press('enter').ok, 'callback exception releases busy lock')
api.rpOpenMenu(child)
check(payload.depth==1 and closed[#closed]=='replaced', 'new root replaces stack')
events.onResourceStop('rp_test')
check(view==nil and api.rpGetMenuState(root)==nil, 'owner stop closes and destroys menus')
local recreated = assert(api.rpCreateMenu('root',def({action('one')})))
api.rpOpenMenu(recreated)
events['esx:onPlayerLogout']()
check(view==nil, 'logout releases focus')
api.rpOpenMenu(recreated)
events.onResourceStop('rp_ui')
view=nil
events.onClientResourceStart('rp_ui')
check(api.rpOpenMenu(recreated), 'UI restart registers route and allows reopen')
check(api.rpDestroyMenu(recreated) and view==nil and not api.rpOpenMenu(recreated), 'destroy active closes and invalidates')

-- Callback can replace root or update checked value intentionally.
local replace = assert(api.rpCreateMenu('replace', def({action('go')}), {onSelect=function() api.rpOpenMenu(child) end}))
child = assert(api.rpCreateMenu('new_child',def()))
api.rpOpenMenu(replace) press('enter')
check(payload.depth==1 and payload.selected==0, 'callback-driven root replacement retained')
local change = assert(api.rpCreateMenu('change', def({{id='check',label='Check',type='checkbox'}}), {
    onChange=function(_, _, _, handle)
        api.rpSetItems(handle,{{id='check',label='Updated',type='checkbox',checked=true}})
        return false
    end,
}))
api.rpOpenMenu(change) press('enter')
check(payload.items[1].checked and payload.items[1].label=='Updated', 'explicit callback updates survive veto rollback')
api.rpCloseMenu()
owner='rp_nativeui'
dofile(base .. 'rp_nativeui/client/demo.lua')
commands.rp_nativeui_test()
check(view=='nativeui' and #payload.items==10, 'actual test command shows all examples')
press('enter')
check(payload.items[1].rightLabel=='1', 'actual demo action updates dynamically')
for _=1,4 do press('down') end
press('enter')
check(payload.depth==2 and #payload.items==4 and payload.items[1].rightLabel=='12:30', 'actual demo builds submenu data')
api.rpCloseMenu()

-- Real rp_ui host: legacy callers retain cursor, NativeUI opts out, locked ownership remains.
local uiApi, focus = {}, nil
local keepInput, inputThreads, blocked, enterHeld = false, {}, {}, false
function SetNuiFocusKeepInput(value) keepInput = value end
function CreateThread(fn) inputThreads[#inputThreads + 1] = coroutine.create(fn) end
function Wait() coroutine.yield() end
function DisableControlAction(_, control, value) blocked[control] = value end
function IsDisabledRawKeyDown(key) return key == 13 and enterHeld end
exports=setmetatable({}, {__call=function(_,name,fn) uiApi[name]=fn end})
function SendNUIMessage() end
function SetNuiFocus(keyboard,cursor) focus={keyboard,cursor} end
function RegisterNUICallback() end
function SetTimeout() end
dofile(base .. 'rp_ui/client/main.lua')
check(uiApi.rpOpen('nativeui',{},true,{keyboardOnly=true}) and focus[1] and not focus[2], 'real UI host disables cursor')
check(keepInput and #inputThreads == 1 and coroutine.resume(inputThreads[1]), 'keyboard menu passes input to game and starts control guard')
check(blocked[27] and blocked[200] and blocked[172] and blocked[176], 'menu navigation cannot also open phone or pause')
for _, control in ipairs({1, 2, 21, 22, 30, 31, 32, 33, 34, 35, 59, 60, 71, 72}) do
    check(not blocked[control], 'look, walking, sprint, jump and driving remain available: ' .. control)
end
check(not blocked[23] and not blocked[75], 'vehicle entry/exit remains available without menu Enter')
enterHeld = true
check(coroutine.resume(inputThreads[1]) and blocked[23] and blocked[75], 'menu Enter cannot also enter or exit a vehicle')
check(uiApi.rpOpen('nativeui',{},true,{keyboardOnly=true}) and #inputThreads == 1, 'submenu renders reuse active input guard')
owner='rp_other'
check(not uiApi.rpOpen('me',{},false) and not uiApi.rpClose(), 'locked native menu cannot be replaced externally')
owner='rp_nativeui'
check(uiApi.rpClose() and not focus[1] and not focus[2], 'focus released on close')
check(not keepInput and coroutine.resume(inputThreads[1]) and coroutine.status(inputThreads[1]) == 'dead', 'closing resets input passthrough and stops control guard')
check(uiApi.rpOpen('inventory',{},false) and focus[1] and focus[2] and not keepInput, 'legacy mouse UI still has exclusive focus and cursor')
check(uiApi.rpOpen('nativeui',{},true,{keyboardOnly=true}) and keepInput, 'native menu can reopen')
check(uiApi.rpOpen('inventory',{},false) and not keepInput and focus[2], 'same owner switching to mouse UI restores exclusive focus')
uiApi.rpOpen('nativeui',{},true,{keyboardOnly=true})
events.onResourceStop('rp_nativeui')
check(not keepInput and not focus[1] and not focus[2], 'stopped menu owner releases passthrough and focus')
print(('PASS: %d NativeUI checks (validation, ownership, stale input, navigation, callbacks, cleanup, demo, NUI focus)'):format(passed))
