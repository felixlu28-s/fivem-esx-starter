-- Ordinary shops extend the same editor/navigation/placement code as Ammu-Nation.
local S,W=Commerce.Shops,Commerce.Weapons
local X,A=W.client,W.client.editorAPI
local E={} S.editor=E
local offers,offerPage,blipPage,catalogue
local function number(ctx,label,value,low,high,accept)
    A.numeric(ctx,label,value,low,high,function(n)
        if n%1~=0 then return X.notify('Bitte eine ganze Zahl eingeben.',true) end
        accept(math.tointeger(n))
    end)
end
local function returnOffers(ctx)
    A.rewind(ctx,{'root','edit'})
    offers(ctx)
end
offerPage=function(ctx,offer)
    local rows={
        {id='name',label=offer.item,disabled=true},
        {id='price',label='Preis pro Angebot',rightLabel=('$ %d'):format(offer.price)},
        {id='count',label='Stück pro Kauf',rightLabel=tostring(offer.count or 1)},
        {id='category',label='Kategorie',rightLabel=offer.category},
        {id='up',label='Im Sortiment nach oben'}, {id='down',label='Im Sortiment nach unten'},
        {id='remove',label='Aus Sortiment entfernen'},
    }
    A.page(ctx,'offer','ARTIKEL BEARBEITEN',rows,function(id)
        if id=='price' then number(ctx,'Preis',offer.price,1,1000000,function(v) offer.price=v offerPage(ctx,offer) end)
        elseif id=='count' then number(ctx,'Stück pro Kauf',offer.count or 1,1,100,function(v) offer.count=v offerPage(ctx,offer) end)
        elseif id=='category' then A.input(ctx,'Kategorie',offer.category,60,function(v) offer.category=v offerPage(ctx,offer) end)
        elseif id=='up' or id=='down' or id=='remove' then
            for i,o in ipairs(ctx.shop.offers) do if o==offer then
                if id=='remove' then table.remove(ctx.shop.offers,i) returnOffers(ctx)
                else local target=i+(id=='up' and -1 or 1)
                    if ctx.shop.offers[target] then ctx.shop.offers[i],ctx.shop.offers[target]=ctx.shop.offers[target],o end
                    X.notify('Reihenfolge angepasst.')
                end
                break
            end end
        end
    end,nil,function() offers(ctx) end)
end
catalogue=function(ctx,index,query)
    index=index or 1 query=query or ''
    local entries,used={},{}
    for _,o in ipairs(ctx.shop.offers) do used[o.item]=true end
    for _,item in ipairs(ctx.catalog) do
        if not used[item.name] and (query=='' or (item.label..' '..item.name):lower():find(query:lower(),1,true)) then entries[#entries+1]=item end
    end
    local pages=math.max(1,math.ceil(#entries/20)) index=math.min(index,pages)
    local rows={{id='search',label='Artikel suchen',rightLabel=query~='' and query or 'Alle Items'}}
    if index>1 then rows[#rows+1]={id='prev',label='Vorherige Seite'} end
    for i=(index-1)*20+1,math.min(index*20,#entries) do
        rows[#rows+1]={id='item_'..i,label=entries[i].label,description=entries[i].name}
    end
    if index<pages then rows[#rows+1]={id='next',label='Nächste Seite'} end
    A.page(ctx,'catalog',('ESX-ARTIKEL · %d / %d'):format(index,pages),rows,function(id)
        if id=='search' then A.input(ctx,'Itemname oder Bezeichnung ( * = alle )',query,60,function(v) catalogue(ctx,1,v=='*' and '' or v) end)
        elseif id=='prev' then catalogue(ctx,index-1,query)
        elseif id=='next' then catalogue(ctx,index+1,query)
        else
            local item=entries[tonumber(id:match('^item_(%d+)$'))]
            if not item or #ctx.shop.offers>=S.maxOffers then return end
            local offer={id=item.name,item=item.name,price=1,count=1,category='Sortiment'}
            ctx.shop.offers[#ctx.shop.offers+1]=offer
            -- Pop the picker first, so returning from details leads to the refreshed assortment.
            A.rewind(ctx,{'root','edit'})
            offers(ctx) offerPage(ctx,offer)
        end
    end)
end
offers=function(ctx)
    local labels={} for _,i in ipairs(ctx.catalog) do labels[i.name]=i.label end
    local rows={{id='add',label='Artikel hinzufügen',disabled=#ctx.shop.offers>=S.maxOffers,rightLabel=('%d / %d'):format(#ctx.shop.offers,S.maxOffers)}}
    for i,o in ipairs(ctx.shop.offers) do rows[#rows+1]={id='offer_'..i,label=labels[o.item] or o.item,rightLabel=('$ %d · ×%d'):format(o.price,o.count or 1)} end
    A.page(ctx,'offers','SORTIMENT',rows,function(id)
        if id=='add' then catalogue(ctx) else
            local offer=ctx.shop.offers[tonumber(id:match('^offer_(%d+)$'))]
            if offer then offerPage(ctx,offer) end
        end
    end)
end
blipPage=function(ctx)
    local b=ctx.shop.blip
    local rows={{id='enabled',label='Auf der Karte anzeigen',type='checkbox',checked=b~=false}}
    if b then
        rows[#rows+1]={id='label',label='Blip-Name',rightLabel=b.label}
        rows[#rows+1]={id='sprite',label='GTA-Blip-Symbol',rightLabel=tostring(b.sprite)}
        rows[#rows+1]={id='color',label='GTA-Blip-Farbe',rightLabel=tostring(b.color)}
        rows[#rows+1]={id='scale',label='Größe',rightLabel=('%.2f'):format(b.scale)}
    end
    A.page(ctx,'blip','KARTENMARKIERUNG',rows,function(id)
        if not b then return end
        if id=='label' then A.input(ctx,'Blip-Name',b.label,80,function(v) b.label=v blipPage(ctx) end)
        elseif id=='sprite' or id=='color' then number(ctx,id,b[id],id=='sprite' and 1 or 0,id=='sprite' and 1000 or 85,function(v) b[id]=v blipPage(ctx) end)
        elseif id=='scale' then A.numeric(ctx,'Blip-Größe',b.scale,0.3,1.5,function(v) b.scale=v blipPage(ctx) end) end
    end,function(_,value)
        ctx.shop.blip=value and {sprite=52,color=2,scale=0.75,label=ctx.shop.label} or false
        blipPage(ctx)
    end)
end
function E.edit(ctx)
    local rows={
        {id='label',label='Name',rightLabel=ctx.shop.label},
        {id='subtitle',label='Beschreibung',rightLabel=ctx.shop.subtitle},
        {id='interaction',label='Interaktionspunkt hier setzen'},
        {id='position',label='Interaktionspunkt fein justieren'},
        {id='npc',label='Verkäufer platzieren / bearbeiten'},
        {id='offers',label='Sortiment & Preise',rightLabel=tostring(#ctx.shop.offers)},
        {id='blip',label='Kartenmarkierung'},
        {id='save',label='Laden speichern',description='Veröffentlicht den Entwurf mit NPC, Blip und Sortiment.'},
        {id='delete',label='Laden löschen',disabled=not ctx.shop.id},
    }
    A.page(ctx,'edit','DEV · '..ctx.shop.label,rows,function(id)
        if id=='label' or id=='subtitle' then A.input(ctx,id=='label' and 'Ladenname' or 'Beschreibung',ctx.shop[id],id=='label' and 80 or 160,function(v) ctx.shop[id]=v E.edit(ctx) end)
        elseif id=='interaction' then local p=A.position() p.bucket=ctx.bucket ctx.shop.coords=p X.refreshDraft() X.notify('Interaktionspunkt gesetzt. Speichern nicht vergessen.')
        elseif id=='position' then A.transform(ctx,{pos=ctx.shop.coords},'point')
        elseif id=='npc' then A.npc(ctx)
        elseif id=='offers' then offers(ctx)
        elseif id=='blip' then blipPage(ctx)
        elseif id=='save' then A.save(ctx,false)
        elseif id=='delete' then A.page(ctx,'delete','LADEN WIRKLICH LÖSCHEN?',{{id='confirm',label='Ja, Laden entfernen',description='Entfernt Verkäufer, Blip und Kaufzugriff. Backspace bricht ab.'}},function() A.save(ctx,true) end) end
    end,nil,function()
        X.setDraft(nil) ctx.shop=nil A.root(ctx)
    end)
end
