fx_version 'cerulean'
game 'gta5'

author 'Project team'
description 'Shared foundation for project-owned resources'
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
    'skinchanger',
    'ox_lib',
    'oxmysql',
}
