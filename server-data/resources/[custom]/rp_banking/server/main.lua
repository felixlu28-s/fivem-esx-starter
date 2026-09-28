local B, C = Banking, Banking.Config
local function fail(error) return {ok=false,error=error} end
lib.callback.register('rp_banking:open', function(source, location, model)
    if not B.rate(source,'open',1000) then return fail('rate_limited') end
    if not B.ready then return fail('server_starting') end
    if not B.integer(location,1,#B.locations) or type(model) ~= 'string' or not C.models[model]
        or not B.near(source,B.locations[location]) then return fail('out_of_range') end
    local character=B.capture(source)
    if B.locks[character.identifier] then return fail('busy') end
    local view={token=B.token(),character=character,location=location,
        brand=C.overrides[location] or C.models[model],expires=os.time()+C.sessionSeconds}
    B.views[source]=view
    local ok, data=pcall(B.snapshot,source,view)
    return {ok=ok and data~=nil,banking=ok and data or nil,error=not ok and 'database_error' or nil}
end)
lib.callback.register('rp_banking:action', function(source,p)
    if not B.rate(source,type(p)=='table' and p.action=='transact' and 'transact' or 'action',type(p)=='table' and p.action=='transact' and C.cooldown or 300) then return fail('rate_limited') end
    local view=B.views[source]
    if type(p)~='table' or not view or p.session~=view.token or not B.live(source,view) then return fail('session_expired') end
    local ran,result=pcall(function()
        if p.action=='recipient' then
            if not B.integer(p.id,1,65535) or p.id==source then return fail('invalid_recipient') end
            local target=B.capture(p.id)
            if not target or target.identifier==view.character.identifier then return fail('recipient_offline') end
            local token=B.token()
            view.recipient={token=token,character=target,expires=os.time()+90}
            return {ok=true,bankRecipient={token=token,id=p.id,name=B.player(p.id).getName()}}
        end
        if p.action=='transact' then
            local ok,err=B.transact(source,view,p)
            return {ok=ok,error=err,banking=B.snapshot(source,view)}
        end
        if p.action=='history' or p.action=='refresh' then
            if p.before~=nil and not B.integer(p.before,0,9007199254740991) then return fail('invalid_request') end
            return {ok=true,banking=B.snapshot(source,view,p.action=='history' and p.before or nil)}
        end
        return fail('invalid_request')
    end)
    if not ran then print('[rp_banking] Callback failed: '..tostring(result)) return fail('database_error') end
    return result
end)
RegisterNetEvent('rp_banking:close', function(token)
    local view=B.views[source]
    if view and view.token==token then B.views[source]=nil end
end)
