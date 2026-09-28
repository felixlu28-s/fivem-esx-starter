local R,C=Garage.Rules,Garage.Config
function R.copy(value)
    if type(value)~='table' then return value end
    local result={} for k,v in pairs(value) do result[k]=R.copy(v) end return result
end
function R.finite(value,low,high) return type(value)=='number' and value==value and value>=low and value<=high end
local function contains(values,value) for _,v in ipairs(values) do if v==value then return true end end end
local function point(value,heading)
    if type(value)~='table' or not R.finite(value.x,-10000,10000) or not R.finite(value.y,-10000,10000)
        or not R.finite(value.z,-500,2500) or (heading and not R.finite(value.h,0,360)) then return end
    return {x=value.x+0.0,y=value.y+0.0,z=value.z+0.0,h=heading and value.h+0.0 or nil}
end
function R.definition(raw)
    if type(raw)~='table' or type(raw.label)~='string' or #raw.label<1 or #raw.label>80 or raw.label:find('%c')
        or not R.integer(raw.bucket,0,65535) then return nil,'invalid_label_or_bucket' end
    local g={label=raw.label,bucket=raw.bucket,blip=false}
    for _,key in ipairs({'clerk','interaction','gate','hidden','parking','staffDoor'}) do
        g[key]=point(raw[key],key=='clerk' or key=='hidden' or key=='parking' or key=='staffDoor')
        if not g[key] then return nil,'invalid_'..key end
    end
    if not contains(C.editor.models,raw.clerk.model) or not contains(C.editor.models,raw.valetModel)
        or not contains(C.editor.scenarios,raw.clerk.scenario) then return nil,'invalid_npc' end
    g.clerk.model,g.clerk.scenario,g.valetModel=raw.clerk.model,raw.clerk.scenario,raw.valetModel
    local model=raw.gate.model
    if not ((type(model)=='string' and #model>0 and #model<=64 and model:match('^[%w_]+$')) or R.integer(model,-2147483648,4294967295)) then return nil,'invalid_gate_model' end
    g.gate.model=model
    if R.distance(g.hidden,g.parking)<5 then return nil,'hidden_parking_too_close' end
    for _,key in ipairs({'outward','inward','staffPath'}) do
        if type(raw[key])~='table' or #raw[key]>C.editor.maxPoints then return nil,'invalid_route' end
        g[key]={}
        for index,value in pairs(raw[key]) do
            if not R.integer(index,1,#raw[key]) or not point(value,false) then return nil,'invalid_route' end
            g[key][index]=point(value,false)
        end
    end
    local function nearby(p) return R.distance(p,g.interaction)<=C.editor.radius end
    for _,key in ipairs({'clerk','gate','hidden','parking','staffDoor'}) do if not nearby(g[key]) then return nil,'points_too_far' end end
    for _,key in ipairs({'outward','inward','staffPath'}) do for _,p in ipairs(g[key]) do if not nearby(p) then return nil,'points_too_far' end end end
    if raw.blip~=false then
        local b=raw.blip
        if type(b)~='table' or not R.integer(b.sprite,1,1000) or not R.integer(b.color,0,85) then return nil,'invalid_blip' end
        g.blip={sprite=b.sprite,color=b.color}
    end
    return g
end
