fx_version 'cerulean'
game 'gta5'
version '0.1.0'
description 'ESX shops and crafting with project UI and atomic inventory exchanges'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/esx_shops.lua', 'shared/weapons.lua', '@rp_inventory/shared/items.lua', '@rp_inventory/shared/weapon_catalog.lua', '@rp_inventory/shared/weapons.lua', 'shared/weapon_catalog.lua', 'shared/shops.lua', '@rp_inventory/shared/clothing_artwork.lua', '@rp_inventory/shared/clothing_catalog.lua', 'shared/clothing.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/service.lua', 'server/purchases.lua', 'server/shop_editor_store.lua', 'server/weaponshops.lua', 'server/shops.lua', 'server/main.lua' }
client_scripts { 'client/weapon_clerk.lua', 'client/weapon_scene.lua', 'client/weapon_menu.lua', 'client/weapon_editor.lua', 'client/shop_editor.lua', 'client/shops.lua', '@rp_core/lib/portrait_camera.lua', 'client/clothing.lua', 'client/main.lua' }
dependencies { 'es_extended', 'oxmysql', 'ox_lib', 'rp_core', 'rp_ui', 'rp_inventory', 'rp_nativeui' }
