fx_version 'cerulean'
game 'gta5'
version '0.1.0'
description 'Personal character overview and server-observed endurance progression'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/progress.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/main.lua' }
dependencies { 'rp_core', 'rp_ui', 'es_extended', 'oxmysql', 'ox_lib' }
