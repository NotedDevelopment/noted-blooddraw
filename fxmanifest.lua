fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Noted'
description 'Allows players to draw and transfuse blood'
version '1.0'

shared_script {
    'config.lua',
    -- '@qb-core/shared/locale.lua',
    -- 'locales/en.lua',
    -- 'locales/*.lua',
    '@ox_lib/init.lua',
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
