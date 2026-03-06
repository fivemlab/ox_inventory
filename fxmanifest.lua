-- ox_inventory API implementation using devix-inventory. Do not start the real Overextended ox_inventory.
fx_version 'cerulean'
game 'gta5'

name 'ox_inventory'
description 'ox_inventory API — devix-inventory backend. Scripts that call exports["ox_inventory"] use devix-inventory.'
author 'devix'
version '2.42.1'

-- qbx_houserobbery, qbx_idcard vb. bu export'ları kullanır; server.cfg'de ensure ox_inventory onlardan ÖNCE olmalı
dependencies {
    'devix-core',
    'devix-inventory',
}

client_scripts { 'client.lua' }
server_scripts { 'server.lua' }

-- QBX vb. script'lerin arayacağı export'lar (client)
exports {
    'Items',
    'ItemList',
    'GetItemList',
    'displayMetadata',
}

lua54 'yes'
