fx_version 'cerulean'
game 'gta5'

author 'TJ Scripts'
description 'ESX OX Community Service Script'
version '1.0.0'
lua54 'yes'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}
files {
	'locales/*.json',
}

client_scripts {
    'client/*.lua'
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_target'
}

ox_libs {
    'locale',
    'table',
}
