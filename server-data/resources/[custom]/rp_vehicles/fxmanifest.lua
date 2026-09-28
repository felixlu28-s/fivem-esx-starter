fx_version 'cerulean'
game 'gta5'
version '0.2.0'
description 'ESX owned vehicles with a networked garage valet and existing NativeUI'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/rules.lua', 'shared/schema.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua', 'server/locations.lua' }
client_scripts { 'client/world.lua', 'client/scene.lua', 'client/delivery.lua', 'client/menu.lua', 'client/editor.lua' }
dependencies { 'es_extended', 'oxmysql', 'ox_lib', 'rp_core', 'rp_ui', 'rp_nativeui' }
