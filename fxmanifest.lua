-- ox_inventory API implementation using devix-inventory. Do not start the real Overextended ox_inventory.
fx_version 'cerulean'
game 'gta5'

name 'ox_inventory'
description 'ox_inventory API — devix-inventory backend. Scripts that call exports["ox_inventory"] use devix-inventory.'
author 'devix'
version '2.42.1'

dependencies {
    'ox_lib',
    -- 'devix-core',
    -- 'devix-inventory',
}

client_scripts { 'client.lua' }
server_scripts { 'server.lua' }

lua54 'yes'
