fx_version 'cerulean'
game 'gta5'

author 'Project team'
description '__RESOURCE__ domain resource'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/**/*.lua',
}

client_scripts {
    'client/**/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/**/*.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'oxmysql',
    'rp_core',
}
