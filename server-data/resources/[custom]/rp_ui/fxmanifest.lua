fx_version 'cerulean'
game 'gta5'

author 'Project team'
description 'Central React and TypeScript NUI'
version '0.1.0'

ui_page 'web/dist/index.html'
loadscreen 'web/dist/loading.html'
loadscreen_manual_shutdown 'yes'

files {
    'web/dist/index.html',
    'web/dist/**/*',
}

client_scripts {
    'client/**/*.lua',
}

dependencies {
    'rp_core',
}
