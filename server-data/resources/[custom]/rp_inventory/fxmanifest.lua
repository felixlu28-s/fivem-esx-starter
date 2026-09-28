fx_version 'cerulean'
game 'gta5'
version '0.1.0'
description 'Character inventory and ESX custom-inventory provider'

-- ESX Legacy 1.15 uses this provider name to select its official inventory bridge.
provide 'ox_inventory'
shared_scripts { '@ox_lib/init.lua', 'shared/items.lua', 'shared/weapon_catalog.lua', 'shared/weapons.lua', 'shared/model.lua', 'shared/clothing_artwork.lua', 'shared/clothing_catalog.lua', 'shared/clothing.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/store.lua', 'server/clothing.lua', 'server/bridge.lua', 'server/ground.lua', 'server/actions.lua', 'server/stashes.lua', 'server/exchange.lua', 'server/weapons.lua', 'server/admin.lua' }
client_scripts { 'client/item_labels.lua', 'client/main.lua', 'client/weapons.lua', 'client/attachments.lua', 'client/ground.lua', 'client/admin.lua', 'client/clothing.lua' }
dependencies { 'es_extended', 'oxmysql', 'ox_lib', 'rp_core', 'rp_ui', 'rp_nativeui' }
