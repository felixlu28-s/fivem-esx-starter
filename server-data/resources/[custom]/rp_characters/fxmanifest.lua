fx_version 'cerulean'
game 'gta5'

author 'Project team'
description 'Secure ESX character selection and creation'
version '0.1.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'es_extended',
}
