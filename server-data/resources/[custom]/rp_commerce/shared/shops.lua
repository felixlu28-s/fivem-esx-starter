local W = Commerce.Weapons
local S = {
    maxShops=128, maxOffers=96, copy=W.copy, distance=W.distance,
    clerkModels={'mp_m_shopkeep_01','s_f_y_shop_mid','s_f_y_shop_low','s_m_m_ammucountry'},
    scenarios={'WORLD_HUMAN_STAND_IMPATIENT','WORLD_HUMAN_CLIPBOARD','WORLD_HUMAN_GUARD_STAND'},
}
Commerce.Shops=S
local function integer(v,a,b) return W.finite(v,b) and v%1==0 and v>=a end
local function text(v,limit) return type(v)=='string' and #v>0 and #v<=limit and not v:find('[%c~]') end
local function contains(list,v) for _,x in ipairs(list) do if x==v then return true end end end
local function point(p)
    if type(p)~='table' then return end
    for _,a in ipairs({'x','y','z'}) do if not W.finite(p[a],20000) then return end end
    return {x=p.x,y=p.y,z=p.z}
end
function S.sellable(name,def)
    -- Weapon/ammo/component offers remain in Ammu-Nation's licence-aware catalogue.
    return type(name)=='string' and #name<=64 and name:match('^[%w_]+$') and type(def)=='table'
        and not def.weapon and not def.component and def.use~='component'
        and not name:upper():match('^WEAPON_') and not name:lower():match('^ammo_')
        and name~='money' and name~='bank' and name~='black_money'
end
function S.newShop(pos)
    return {normalshop=true,label='Neuer Laden',subtitle='Alles fuer deinen Alltag.',coords=W.copy(pos),
        npc=false,displays={},offers={},blip={sprite=52,color=2,scale=0.75,label='Laden'},jobs=nil}
end
function S.validate(raw)
    if type(raw)~='table' or not text(raw.label,80) or not text(raw.subtitle or 'Einkaufen',160) then return nil,'invalid_shop' end
    local pos=point(raw.coords)
    if not pos or not integer(raw.coords.bucket,0,2147483647) then return nil,'invalid_position' end
    pos.bucket=raw.coords.bucket
    local shop=S.newShop(pos) shop.label,shop.subtitle=raw.label,raw.subtitle or 'Einkaufen'
    if raw.blip~=false then
        local b=raw.blip
        if type(b)~='table' or not integer(b.sprite,1,1000) or not integer(b.color,0,85)
            or not W.finite(b.scale,1.5) or b.scale<0.3 or not text(b.label,80) then return nil,'invalid_blip' end
        shop.blip={sprite=b.sprite,color=b.color,scale=b.scale,label=b.label}
    else shop.blip=false end
    if raw.npc~=false then
        local n=raw.npc
        if type(n)~='table' or not contains(S.clerkModels,n.model) or not contains(S.scenarios,n.scenario)
            or not W.finite(n.heading,360) then return nil,'invalid_npc' end
        local p=point(n.pos)
        if not p or S.distance(p,pos)>25 then return nil,'npc_too_far' end
        shop.npc={pos=p,model=n.model,heading=n.heading,scenario=n.scenario}
    end
    if raw.jobs~=nil then
        if type(raw.jobs)~='table' then return nil,'invalid_jobs' end
        shop.jobs={} local count=0
        for name,grade in pairs(raw.jobs) do
            count=count+1
            if count>16 or not text(name,50) or not name:match('^[%w_]+$') or not integer(grade,0,100000) then return nil,'invalid_jobs' end
            shop.jobs[name]=grade
        end
    end
    if type(raw.offers)~='table' or #raw.offers>S.maxOffers then return nil,'offer_limit' end
    local seen,items={},{}
    local catalogue=exports.rp_inventory:Items()
    local entries=0
    for i,o in pairs(raw.offers) do
        entries=entries+1
        if not integer(i,1,#raw.offers) or type(o)~='table' or not text(o.id,64) or not o.id:match('^[%w_-]+$')
            or seen[o.id] or type(o.item)~='string' or items[o.item] or not integer(o.price,1,1000000)
            or not integer(o.count or 1,1,100) or not text(o.category,60) then return nil,'invalid_offer' end
        local def=catalogue[o.item]
        if not S.sellable(o.item,def) then return nil,'item_not_allowed' end
        seen[o.id],items[o.item]=true,true
        shop.offers[i]={id=o.id,item=o.item,price=math.tointeger(o.price),count=math.tointeger(o.count or 1),category=o.category}
    end
    if entries~=#raw.offers then return nil,'invalid_offer' end
    return shop
end
