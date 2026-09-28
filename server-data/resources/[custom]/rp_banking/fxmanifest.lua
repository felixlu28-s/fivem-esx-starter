fx_version 'cerulean'
game 'gta5'
version '0.1.0'
description 'GTA ATM terminals on ESX accounts with character-scoped banking receipts'
shared_scripts { '@ox_lib/init.lua', 'shared/config.lua', 'shared/locations.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/service.lua', 'server/transactions.lua', 'server/main.lua' }
client_scripts { 'client/main.lua' }
dependencies { 'es_extended', 'ox_lib', 'oxmysql', 'rp_core', 'rp_ui' }
