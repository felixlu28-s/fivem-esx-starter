fx_version 'cerulean'
game 'gta5'

author 'Project team'
description 'Secure ESX character selection and creation'
version '0.2.0'

-- Enables the ESX multicharacter path through Cfx resource aliasing.
provide 'esx_multicharacter'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/wardrobe.lua',
    'shared/appearance.lua',
    'shared/validation.lua',
}

client_scripts {
    '@rp_core/lib/portrait_camera.lua',
    'client/scene.lua',
    'client/camera.lua',
    'client/appearance.lua',
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
    'skinchanger',
    'rp_core',
    'rp_ui',
    'rp_inventory',
}
