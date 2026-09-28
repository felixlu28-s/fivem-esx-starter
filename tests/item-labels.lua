local checks=0
local function check(value,message) assert(value,message) checks=checks+1 end
Inventory={}
local api={}
exports=setmetatable({}, {__call=function(_,name,fn) api[name]=fn end})
local language,calls=2,0
function GetCurrentLanguage() return language end
function GetLabelText(key) calls=calls+1 return key=='KNOWN' and 'Originaler deutscher Name' or 'NULL' end
dofile('server-data/resources/[custom]/rp_inventory/client/item_labels.lua')
local function payload()
    return {own={items={{label='Fallback',gxt='KNOWN',clothing={label='Fallback'}}}},
        external={items={{label='Fallback',gxt='KNOWN'}}},
        offers={{label='Fallback',gxt='KNOWN'}},currentClothing={{label='Fallback',gxt='KNOWN'}}}
end
local p=api.rpLocalizeCatalog(payload())
check(p.own.items[1].label==p.offers[1].label,'shop and inventory name identical')
check(p.own.items[1].clothing.label==p.external.items[1].label,'metadata display / external store match')
check(p.currentClothing[1].label=='Originaler deutscher Name' and calls==1,'cached original name for current outfit')
local unknown={inventory={own={items={{label='Deutscher Ersatzname',gxt='UNKNOWN'}}}}}
api.rpLocalizeCatalog(unknown)
check(unknown.inventory.own.items[1].label=='Deutscher Ersatzname','missing GTA label keeps readable German fallback')
language=0 p=api.rpLocalizeCatalog(payload())
check(p.own.items[1].label=='Fallback','English GTA installation cannot turn server labels English')
print(('PASS: %d shared shop/inventory/localization checks'):format(checks))
