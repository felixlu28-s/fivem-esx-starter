-- Magazine-sized, durable prepayments. Reports/audits/damage checks never write SQL.
-- Client observations are signals, not proof of all shots (misses are not server-visible).
local S, M, C = Inventory.store, Inventory.model, Inventory.ammoSync
local states, busy, rates, hashes, spawnRates = {}, {}, {}, {}, {}
for name, def in pairs(Inventory.items) do if def.weapon then hashes[joaat(name) % 4294967296] = name end end
local function owned(source, name)
    local session = S.player(source)
    local row = session and S.cache[session.id]
    return row and M.count(row.data, name) > 0
end
local function stateFor(source)
    local session = S.player(source)
    if not session then return end
    local state = states[source]
    if not state or state.generation ~= session.generation then
        state = { generation=session.generation, owned={}, groups={}, batches={}, retired={}, auditAt=GetGameTimer()+math.random(C.auditMinMs,C.auditMaxMs),
            nextReport=0, anomalies=0, nextLog=0 }
        states[source] = state
    end
    return state
end
local function signal(source, state, reason)
    state.anomalies = math.min(100000, state.anomalies+1)
    if GetGameTimer() >= state.nextLog then
        state.nextLog = GetGameTimer()+C.logMs
        print(('[rp_inventory] Ammo audit: player=%s reason=%s signals=%d (review; no automatic ban)')
            :format(source,reason,state.anomalies))
        -- Local server fact, not a network event; no client-supplied identifiers in the log.
        TriggerEvent('rp_inventory:ammoAnomaly',source,reason,state.anomalies)
    end
end
local function retire(state, batch)
    if not batch then return end
    batch.untilAt = GetGameTimer()+(batch.graceMs or C.graceMs)
    state.retired[#state.retired+1] = batch
    -- Bounded across all configured ammo groups; never grow with client requests.
    if #state.retired>64 then table.remove(state.retired,1) end
end
local function response(source, state, batch)
    local session = S.player(source)
    local row = session and S.cache[session.id]
    if not row then return {ok=false} end
    return { ok=true, token=batch.token, count=batch.count, spent=batch.spent, ammo=batch.ammo,
        remaining=M.count(row.data,batch.ammo), revision=row.revision, generation=state.generation }
end
-- Cumulative consumption is monotonic and can only burn paid ammunition, never refund it.
local function consume(source, state, report)
    if type(report)~='table' or type(report.ammo)~='string' then return false end
    local batch = state.batches[report.ammo]
    if not batch or batch.token~=report.token or not M.integer(report.spent,0,batch.count) then return false end
    if report.spent<batch.spent then return true end -- delayed report
    if report.spent>batch.spent then
        batch.spent=report.spent
        if batch.spent==batch.count and not batch.finishedAt then batch.finishedAt=GetGameTimer() end
    end
    return true
end
S.clearWeapons = function(source)
    states[source],busy[source],rates[source],spawnRates[source]=nil,nil,nil,nil
end
RegisterNetEvent('esx:onPlayerSpawn',function()
    local source=source
    if type(source)~='number' or source<=0 or not S.player(source) or (spawnRates[source] or 0)>GetGameTimer() then return end
    spawnRates[source]=GetGameTimer()+1500
    states[source],busy[source]=nil,nil
    -- Keep request cooldown. A respawn cannot refund a prepayment.
end)
function S.weaponState(source)
    local state=stateFor(source)
    if not state then return end
    local row=S.cache[S.players[source].id]
    state.owned,state.groups={},{}
    for _,entry in pairs(row and row.data.items or {}) do
        local def=Inventory.items[entry.name]
        if def and def.weapon and entry.count>0 then
            state.owned[entry.name]=true
            if def.ammo then state.groups[def.ammo]=true end
        end
    end
    -- Paid consumables survive removal of the last loose item until consumed.
    for group,batch in pairs(state.batches) do
        if batch.consumable and batch.spent<batch.count then state.groups[group]=true state.owned[batch.weapon]=true end
    end
    local operation=busy[source]
    if operation and operation.consumable then state.groups[operation.name]=true state.owned[operation.name]=true end
    for group in pairs(state.batches) do
        if not state.groups[group] then
            if state.batches[group].projectile then retire(state,state.batches[group]) end
            state.batches[group]=nil
        end
    end
    for i=#state.retired,1,-1 do
        if not state.groups[state.retired[i].ammo] and not state.retired[i].projectile then table.remove(state.retired,i) end
    end
end
lib.callback.register('rp_inventory:ammoBatch',function(source,name,request,report)
    local session = S.player(source)
    local def = type(name)=='string' and Inventory.items[name]
    if not session or not S.playable(source) or not def or not def.weapon or not def.ammo or not owned(source,name)
        or type(request)~='string' or #request<8 or #request>55 or not request:match('^[%w_-]+$') then return {ok=false} end
    local state,now=stateFor(source),GetGameTimer()
    if busy[source] then return {ok=false,error='busy'} end
    local previous=state.batches[def.ammo]
    if previous and previous.request==request then return response(source,state,previous) end
    if (rates[source] or 0)>now then return {ok=false,error='rate_limited'} end
    rates[source]=now+C.requestMs
    if report then consume(source,state,report) end
    if previous and previous.spent<previous.count then return {ok=false,error='batch_pending'} end
    -- No claims of accelerated consumption can accelerate purchasing whole magazines.
    if previous and now<previous.issuedAt+math.max(0,previous.count-2)*previous.shotDelay then
        return {ok=false,error='rate_limited'}
    end
    local row=S.cache[session.id]
    if not row or M.count(row.data,def.ammo)<1 then return {ok=false,error='not_enough_items'} end
    local operation,count={name=name,consumable=def.consumable},0
    busy[source]=operation
    local ok,err,replay=S.mutate({session.id},session.identifier,'ammo-'..request,'ammo:'..name,nil,
        function() return S.live(source,session) and states[source]==state and busy[source]==operation
            and S.playable(source) and owned(source,name) end,
        function(copies)
            count=math.min(def.magazine,M.count(copies[session.id],def.ammo)*(def.ammoUnits or 1))
            if count<1 then return false,'not_enough_items' end
            return M.remove(copies[session.id],def.ammo,def.consumable and 1 or count)
        end)
    local active=busy[source]==operation
    if active then busy[source]=nil end
    -- A lost acknowledgement never grants ammunition a second time. Durable receipts are authoritative.
    if not ok or replay or not active or not S.live(source,session) or states[source]~=state
        or not S.playable(source) or (not def.consumable and not owned(source,name)) then return {ok=false,error=err or 'spent'} end
    retire(state,previous)
    local batch={token=S.token('ammo'),request=request,ammo=def.ammo,count=count,spent=0,damage=0,
        issuedAt=GetGameTimer(),shotDelay=def.shotDelay or 150, weapon=name,consumable=def.consumable,damageFactor=def.damageFactor or 1,
        projectile=def.projectile,graceMs=def.projectile and 600000 or C.graceMs}
    state.batches[def.ammo]=batch
    S.weaponState(source)
    return response(source,state,batch)
end)
RegisterNetEvent('rp_inventory:ammoReport',function(generation,reports,observations,nonce,revision,excess)
    local source=source
    local state=states[source]
    local session=S.player(source)
    if not state or not session or state.generation~=generation or session.generation~=generation then return end
    local now=GetGameTimer()
    local audit=type(nonce)=='string' and state.challenge and state.challenge.token==nonce and state.challenge.expires>=now
    if not audit and now<state.nextReport then return end
    state.nextReport=now+500
    if type(reports)~='table' then return end
    -- Fixed catalog loop, never iterate an unbounded client array.
    for group in pairs(Inventory.ammoTypes) do
        local report=reports[group]
        if report and (type(report)~='table' or report.ammo~=group or not consume(source,state,report)) then
            signal(source,state,'invalid_report')
        end
    end
    if not audit then return end
    state.challenge=nil
    local row=S.cache[session.id]
    -- Compare like revisions only; purchases/transfers in flight must not create false flags.
    if row and revision==row.revision and type(observations)=='table' then
        for group in pairs(Inventory.ammoTypes) do
            local batch=state.batches[group]
            local def=Inventory.items[group]
            local expected=state.groups[group] and (M.count(row.data,group)*(def and def.ammoUnits or 1)+(batch and batch.count-batch.spent or 0)) or 0
            local actual=observations[group]
            if not M.integer(actual,0,1000000) or actual>expected+2 then signal(source,state,'native_excess') end
        end
    end
    if M.integer(excess,1,100000) then signal(source,state,'client_corrected_excess') end
    TriggerClientEvent('rp_inventory:ammoAuditResult',source,state.generation,nonce)
end)
AddEventHandler('weaponDamageEvent',function(source,data)
    if type(data)~='table' or type(data.weaponType)~='number' then return end
    local name=hashes[data.weaponType%4294967296]
    if not name then return end -- Other gameplay damage is outside this provider's weapon contract.
    local state=states[source]
    local session=S.players[source]
    if state and session and state.generation==session.generation then
        local def=Inventory.items[name]
        if def.ammoFree and state.owned[name] then return end
        if not def.ammo or (not state.owned[name] and not def.projectile) then CancelEvent() signal(source,state,"damage_without_owned_weapon") return end
        local now,group=GetGameTimer(),Inventory.items[name].ammo
        -- Existing Cfx damage traffic; O(1) bounded RAM work, no RPC and no SQL.
        -- A packet may contain multiple hitGlobalIds (penetration); count the event, not its victims.
        local function credit(batch)
            if not batch or batch.ammo~=group or batch.damage>=batch.count*(batch.damageFactor or 1)
                or (batch.untilAt and batch.untilAt<now)
                or (batch.finishedAt and batch.finishedAt+(batch.graceMs or C.graceMs)<now) then return false end
            batch.damage=batch.damage+1
            return true
        end
        for _,batch in ipairs(state.retired) do if credit(batch) then return end end
        if credit(state.batches[group]) then return end
    end
    CancelEvent()
    if state then signal(source,state,'damage_without_paid_ammo') end
end)
CreateThread(function()
    while true do
        Wait(1000)
        local now=GetGameTimer()
        for source,state in pairs(states) do
            local session=S.players[source]
            if not session or session.generation~=state.generation then states[source]=nil
            else
                for i=#state.retired,1,-1 do
                    if state.retired[i].untilAt<now then table.remove(state.retired,i) end
                end
                if state.challenge and state.challenge.expires<now then
                    signal(source,state,'audit_timeout')
                    state.challenge=nil -- network delays alone are not a ban reason
                end
                if now>=state.auditAt then
                    state.auditAt=now+math.random(C.auditMinMs,C.auditMaxMs)
                    if next(state.owned) and S.playable(source) then
                        state.challenge={token=S.token('audit'),expires=now+C.auditTimeoutMs}
                        TriggerClientEvent('rp_inventory:ammoAudit',source,state.generation,state.challenge.token)
                    end
                end
            end
        end
    end
end)
