-- World items are volatile. Only the player's inventory mutation/receipt is durable.
local S,M,G=Inventory.store,Inventory.model,Inventory.ground
local drops,pending,claims,rates,poseRates={},{},{},{},{}
local function position(source)
    local p=GetEntityCoords(GetPlayerPed(source))
    local heading=math.rad(GetEntityHeading(GetPlayerPed(source)))
    return {x=p.x-math.sin(heading)*0.65,y=p.y+math.cos(heading)*0.65,z=p.z-0.8,bucket=GetPlayerRoutingBucket(source)}
end
local function near(source,p,radius)
    if not S.playable(source) or GetPlayerRoutingBucket(source)~=p.bucket then return false end
    local c=GetEntityCoords(GetPlayerPed(source))
    return (c.x-p.x)^2+(c.y-p.y)^2+(c.z-p.z)^2<=(radius or G.radius)^2
end
local function rate(source)
    local now=GetGameTimer()
    if (rates[source] or 0)>now then return false end
    rates[source]=now+300 return true
end
local function packet(drop)
    local def=Inventory.items[drop.item.name]
    local components={}
    for _, value in ipairs(def.weapon and type(drop.item.metadata.components)=='table' and drop.item.metadata.components or {}) do
        local component=type(value)=='table' and value.hash or value
        if (type(component)=='string' and #component<=100) or type(component)=='number' then components[#components+1]=component end
        if #components>=32 then break end
    end
    local garment = M.garment and M.garment(drop.item)
    return {id=drop.id,name=drop.item.name,label=garment and garment.label or def.label,count=drop.item.count,model=def.dropModel or G.model,
        fallbackModel=def.dropFallback,
        weapon=def.weapon==true,pos=drop.pos,age=os.time()-drop.created,owner=drop.owner,visual=drop.visual,
        components=def.weapon and components or nil,
        tintIndex=def.weapon and drop.item.metadata.tintIndex or nil}
end
function S.publishGround()
    for source in pairs(S.players) do
        local result={}
        if S.playable(source) then
            for _,drop in pairs(drops) do if not drop.expired and near(source,drop.pos,G.stream) then result[#result+1]=packet(drop) end end
        end
        TriggerClientEvent('rp_inventory:ground',source,result)
    end
end
local function receipt(op)
    local ok,value=pcall(MySQL.scalar.await,'SELECT fingerprint FROM rp_inventory_operations WHERE actor = ? AND request_id = ?', {op.actor,op.request})
    if not ok then return nil end
    return value==op.fingerprint
end
local function resolve(op,committed)
    if committed==nil then return end -- Freeze ambiguous outcomes; never make two owners.
    if committed and op.uncertain then
        if not S.cache[op.session.id] then
            if S.locks[op.session.id] then return end
            S.locks[op.session.id]=true
            local ok,row=pcall(S.load,op.session.id)
            S.locks[op.session.id]=nil
            if not ok or not row then return end
        end
        S.changed({op.session.id})
    end
    pending[op.key]=nil
    if op.kind=='drop' then
        if committed and op.item and os.time()-op.created<G.lifetime then
            drops[op.id]={id=op.id,item=op.item,pos=op.pos,created=op.created,owner=S.live(op.source,op.session) and op.source or 0,session=op.session}
        end
    else
        local drop=drops[op.id]
        if drop and drop.claim==op then
            if committed then drops[op.id]=nil else drop.claim=nil end
        end
    end
    S.publishGround()
end
-- One bounded landing report per drop from its original live character session.
-- The server adopts the validated physical resting location for both presentation and pickup.
RegisterNetEvent('rp_inventory:groundSettled',function(id,pos,rot)
    local source=source
    local now=GetGameTimer()
    if (poseRates[source] or 0)>now then return end
    poseRates[source]=now+250
    local drop=type(id)=='string' and #id<=80 and drops[id]
    if not drop or drop.visual or drop.owner~=source or not S.live(source,drop.session)
        or os.time()-drop.created>20 or not near(source,drop.pos,10) or type(pos)~='table' or type(rot)~='table' then return end
    for _,axis in ipairs({'x','y','z'}) do
        if type(pos[axis])~='number' or pos[axis]~=pos[axis] or math.abs(pos[axis])>20000
            or type(rot[axis])~='number' or rot[axis]~=rot[axis] or math.abs(rot[axis])>360 then return end
    end
    if (pos.x-drop.pos.x)^2+(pos.y-drop.pos.y)^2+(pos.z-drop.pos.z)^2>Inventory.dropMotion.maxDrift^2 then return end
    drop.visual={pos={x=pos.x,y=pos.y,z=pos.z},rot={x=rot.x,y=rot.y,z=rot.z}}
    drop.pos={x=pos.x,y=pos.y,z=pos.z,bucket=drop.pos.bucket}
    -- Existing periodic nearby publication carries this once; no extra broadcast/SQL per frame.
end)
function S.dropItem(source,p,guard)
    local session=S.player(source)
    if not session then return false,'player_unavailable' end
    local key=session.identifier..':'..p.request
    if pending[key] then return false,'busy' end
    local count=0 for _ in pairs(drops) do count=count+1 end for _ in pairs(pending) do count=count+1 end
    if count>=G.limit then return false,'ground_full' end
    local op={kind='drop',key=key,actor=session.identifier,request=p.request,fingerprint=M.canonical(p),
        id=S.token('ground'),pos=position(source),source=source,session=session,created=os.time(),inflight=true}
    pending[key]=op
    local ok,err,replay=S.mutate({session.id},session.identifier,p.request,op.fingerprint,{[session.id]=p.ownRevision},
        function() return S.live(source,session) and guard() and near(source,op.pos,3) end,
        function(copies)
            local data=copies[session.id]
            local entry=data.items[tostring(p.slot)]
            if not entry or entry.count<p.count then return false,'not_enough' end
            op.item=M.copy(entry) op.item.count=p.count
            return M.remove(data,entry.name,p.count,entry.metadata,p.slot)
        end)
    op.inflight=false
    if replay then pending[key]=nil return ok,err end
    -- Wearing removal may animate before commit. The world item is born now,
    -- not when the request began, so its hand-release animation is still fresh.
    op.created=os.time()
    local committed=ok
    if not ok and err=='database_error' then op.uncertain=true committed=receipt(op) end
    resolve(op,committed)
    return ok,err
end
lib.callback.register('rp_inventory:pickupStart',function(source,id)
    if not rate(source) or type(id)~='string' or #id>80 then return {ok=false,error='invalid_request'} end
    local drop,session=drops[id],S.player(source)
    if not drop or not session or not near(source,drop.pos) or os.time()-drop.created>=G.lifetime then return {ok=false,error='item_unavailable'} end
    if drop.claim or claims[source] then return {ok=false,error='busy'} end
    local token=S.token('pickup')
    local op={kind='pickup',id=id,actor=session.identifier,session=session,source=source,request=token,
        fingerprint='pickup:'..id,key=session.identifier..':'..token,ready=GetGameTimer()+800,expires=GetGameTimer()+6000}
    claims[source],drop.claim=op,op
    return {ok=true,token=token,duration=850}
end)
lib.callback.register('rp_inventory:pickupFinish',function(source,token)
    if not rate(source) then return {ok=false,error='rate_limited'} end
    local op=claims[source]
    if type(token)~='string' or not op or op.request~=token then return {ok=false,error='item_unavailable'} end
    if pending[op.key] then return {ok=false,error='busy'} end
    if GetGameTimer()<op.ready then return {ok=false,error='not_ready'} end
    local drop=drops[op.id]
    local function guard()
        return drop and drops[op.id]==drop and drop.claim==op and S.live(source,op.session)
            and GetGameTimer()<=op.expires and os.time()-drop.created<G.lifetime and near(source,drop.pos)
    end
    if not guard() then claims[source]=nil if drop and drop.claim==op then drop.claim=nil end return {ok=false,error='item_unavailable'} end
    pending[op.key]=op op.inflight=true
    local ok,err=S.mutate({op.session.id},op.actor,op.request,op.fingerprint,nil,guard,function(copies)
        return M.add(copies[op.session.id],drop.item.name,drop.item.count,drop.item.metadata)
    end)
    op.inflight=false
    claims[source]=nil
    local committed=ok
    if not ok and err=='database_error' then op.uncertain=true committed=receipt(op) end
    resolve(op,committed)
    return {ok=ok,error=err}
end)
local function cleanup(source)
    local op=claims[source]
    if op and not pending[op.key] then local drop=drops[op.id] if drop and drop.claim==op then drop.claim=nil end end
    claims[source],rates[source],poseRates[source]=nil,nil,nil
end
AddEventHandler('playerDropped',function() cleanup(source) end)
AddEventHandler('esx:playerLogout',cleanup)
CreateThread(function()
    while true do
        Wait(2000)
        for source,op in pairs(claims) do if GetGameTimer()>op.expires and not pending[op.key] then cleanup(source) end end
        for _,op in pairs(pending) do if not op.inflight and not S.locks[op.session.id] then resolve(op,receipt(op)) end end
        S.publishGround()
    end
end)
CreateThread(function()
    while true do
        Wait(G.sweep)
        for id,drop in pairs(drops) do
            if os.time()-drop.created>=G.lifetime then
                drop.expired=true -- Hide even while an ambiguous pickup receipt is being recovered.
                if not (drop.claim and pending[drop.claim.key]) then drops[id]=nil end
            end
        end
        S.publishGround()
    end
end)
