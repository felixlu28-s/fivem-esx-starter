fx_version 'cerulean'
game 'gta5'
lua54 'yes'
version '0.1.0'
description 'ESX job/society management and character-owned secondary factions'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/policy.lua' }
client_scripts { 'client/main.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/service.lua', 'server/jobs.lua', 'server/factions.lua', 'server/main.lua' }
dependencies { 'es_extended', 'esx_society', 'esx_addonaccount', 'esx_addoninventory', 'esx_datastore', 'rp_core', 'rp_ui', 'ox_lib', 'oxmysql' }
