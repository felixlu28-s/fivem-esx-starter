fx_version 'cerulean'
game 'gta5'

author 'Project team'
description 'Central React and TypeScript NUI'
version '0.1.0'

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*',
}

client_scripts {
    'client/**/*.lua',
}

dependencies {
    'rp_core',
    'rp_characters',
}
