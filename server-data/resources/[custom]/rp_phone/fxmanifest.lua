fx_version 'cerulean'
game 'gta5'
version '0.2.0'
description 'Character-scoped iFruit apps, messaging, voice/video conferences and GTA phone presentation'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/service.lua', 'server/media.lua', 'server/apps.lua', 'server/social.lua', 'server/social_admin.lua', 'server/calls.lua', 'server/main.lua' }
client_scripts { 'client/animation.lua', 'client/camera.lua', 'client/apps.lua', 'client/main.lua' }
dependencies { 'es_extended', 'ox_lib', 'oxmysql', 'rp_core', 'rp_ui', 'rp_inventory' }
