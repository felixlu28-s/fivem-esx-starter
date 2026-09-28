local C,S,W=Commerce,Commerce.Shops,Commerce.Weapons
local function install(id,shop,revision)
    local venue=W.copy(shop)
    venue.kind,venue.revision,venue.shopId='shop',revision,id
    C.Config.venues[id]=venue
end
local function catalogue()
    local result={}
    for name,def in pairs(exports.rp_inventory:Items()) do
        if S.sellable(name,def) then result[#result+1]={name=name,label=def.label or name} end
    end
    table.sort(result,function(a,b) return a.label<b.label end)
    return result
end
local repository=C.registerShopEditor({
    schema=S, tableName='rp_commerce_shops', command='rp_shopdev', channel='rp_commerce:shopEditor',
    changedEvent='rp_commerce:shopsChanged', help='Normale Laeden erstellen / bearbeiten',
    venue=function(id) return id end, install=install, catalog=catalogue,
    uninstall=function(id) C.Config.venues[id]=nil end,
    seed=function()
        -- Existing ESX zones are imported once under their original venue ID, preserving order recovery.
        MySQL.query.await('SELECT id FROM rp_commerce_shops LIMIT 1')
        for id,venue in pairs(C.Config.venues) do
            if venue.kind=='shop' and not venue.weaponshop and not venue.normalshop and not venue.clothing then
                local value=S.newShop(venue.coords)
                value.label,value.subtitle=venue.label,venue.subtitle or 'Einkaufen'
                value.offers,value.jobs=W.copy(venue.offers),W.copy(venue.jobs)
                value.blip=venue.blip and {sprite=venue.blip.sprite,color=venue.blip.color,scale=0.75,label=venue.blip.label} or false
                local clean,err=S.validate(value) assert(clean,err)
                MySQL.insert.await('INSERT IGNORE INTO rp_commerce_shops (id,payload,updated_by) VALUES (?,?,?)',
                    {id,json.encode(clean),'config:esx_shops'})
            end
        end
    end,
})
lib.callback.register('rp_commerce:shops',function(source)
    if not repository.ready() or not C.player(source) or not C.rate(source,'shops',2500) then return {ok=false} end
    local bucket,result=GetPlayerRoutingBucket(source),{}
    for id,shop in pairs(repository.shops) do
        if shop.coords.bucket==bucket then
            result[#result+1]={id=id,revision=shop.revision,label=shop.label,coords=shop.coords,blip=shop.blip,
                npc=shop.npc,normalshop=true,displays={}}
        end
    end
    return {ok=true,shops=result}
end)
