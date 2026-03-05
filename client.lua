--[[
  ox_inventory API — devix-inventory backend (client).
]]

local inv = exports['devix-inventory']

local function toOxItem(item)
    if item == 'cash' then return 'money' end
    return item
end

local function oxGetItemCount(item)
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return 0 end
    return lib.callback.await('devix-inventory:oxCompatGetItemCount', false, item) or 0
end

local function oxGetCurrentWeapon()
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return nil end
    return lib.callback.await('devix-inventory:oxCompatGetCurrentWeapon', false) or nil
end

-- GetItemList is server-only; client gets list via callback to avoid "No such export" from cross-context call
local function oxItems()
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return {} end
    local ok, list = pcall(function()
        return lib.callback.await('ox_inventory:getItemList', false) or {}
    end)
    if not ok or not list or type(list) ~= 'table' then return {} end
    return list
end

local function oxSearch(searchType, items)
    if type(items) ~= 'table' then items = { items } end
    if searchType == 'slots' then
        if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return {} end
        return lib.callback.await('devix-inventory:oxCompatSearchSlots', false, items) or {}
    end
    if searchType ~= 'count' then return nil end
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then
        if #items == 1 then return 0 end
        return {}
    end
    local out = {}
    for _, name in ipairs(items) do
        if name and name ~= '' then
            out[name] = lib.callback.await('devix-inventory:oxCompatGetItemCount', false, name) or 0
        end
    end
    if #items == 1 then return out[items[1]] end
    return out
end

RegisterNetEvent('test', function()
    print('test')
end)

-- devix-core fallback: items.lua client.export (resource.funcName) client'ta çağrılır
RegisterNetEvent('ox_inventory:client:useItemExport', function(exportStr, itemData)
    if not exportStr or type(exportStr) ~= 'string' or exportStr == '' then return end
    local res, fn = exportStr:match('^([^%.]+)%.(.+)$')
    if not res or not fn or GetResourceState(res) ~= 'started' then return end
    if not exports[res] or type(exports[res][fn]) ~= 'function' then return end
    local data = (itemData and type(itemData) == 'table') and itemData or {}
    pcall(function() exports[res][fn](data) end)
end)

local function oxOpenInventory(invType, data)
    if invType == 'stash' then
        local id = type(data) == 'table' and (data.id or data.name) or data
        local label = type(data) == 'table' and data.label or tostring(id)
        -- Owner'lı stash: her oyuncunun kendi deposu (id_ownerIdentifier)
        if id and type(data) == 'table' and data.owner and tostring(data.owner) ~= '' then
            id = tostring(id) .. '_' .. tostring(data.owner)
        elseif id then
            id = tostring(id)
        end
        if id and id ~= '' then inv:OpenStashInventory(id, label or id) end
        return
    end
    if invType == 'shop' then
        local shopType = type(data) == 'table' and (data.type or data.id or data.name) or data
        local label = type(data) == 'table' and data.label or tostring(shopType)
        if shopType then
            TriggerEvent('devix-inventory:client:openInventory', 'player', tostring(shopType), label or tostring(shopType), 'shop')
        end
    end
end

exports('GetItemCount', oxGetItemCount)
exports('getCurrentWeapon', oxGetCurrentWeapon)
exports('Items', oxItems)
exports('ItemList', oxItems)
exports('Search', oxSearch)
exports('openInventory', oxOpenInventory)
exports('displayMetadata', function() end)
exports('GetPlayerItems', function()
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return {} end
    return lib.callback.await('devix-inventory:oxGetPlayerItems', false) or {}
end)
-- cm_armor vb. client'tan GetInventory çağrısı: mevcut oyuncu envanteri (ox format items)
exports('GetInventory', function()
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return { id = 0, items = {} } end
    local items = lib.callback.await('devix-inventory:oxGetPlayerItems', false) or {}
    local out = {}
    for slot, it in pairs(items) do
        if it and it.name then
            out[tonumber(slot) or slot] = {
                name = it.name,
                count = it.amount or 1,
                slot = tonumber(slot) or slot,
                metadata = it.info or {},
                info = it.info or {}
            }
        end
    end
    return { id = GetPlayerServerId(PlayerId()), items = out }
end)

-- s2k / ox_inventory compat: close, stash target, nearby, weight, use, weapon wheel
exports('closeInventory', function()
    if GetResourceState('devix-inventory') ~= 'started' or not exports['devix-inventory'] then return end
    if exports['devix-inventory'].CloseInventory then
        exports['devix-inventory']:CloseInventory()
    end
end)
exports('setStashTarget', function(id, owner)
    -- stub: devix-inventory opens stash by id when openInventory('stash', id) is called; no persistent "target"
end)
exports('openNearbyInventory', function()
    local inv = exports['devix-inventory']
    if not inv or not inv.OpenTrunk then return end
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then
        local seat = GetPedInVehicleSeat(vehicle, -1)
        if seat == ped then inv:OpenTrunk(vehicle)
        else inv:OpenGlovebox(vehicle) end
    else
        vehicle = GetClosestVehicle(GetEntityCoords(ped), 5.0, 0, 70)
        if vehicle and vehicle ~= 0 then inv:OpenTrunk(vehicle) end
    end
end)
exports('giveItemToTarget', function(slot, amount, target)
    -- stub: devix-inventory item transfer is via UI or server event; no direct "give to target" export
end)
exports('GetPlayerWeight', function()
    return 0
end)
exports('GetPlayerMaxWeight', function()
    return 120000
end)
exports('useItem', function(name, slot, data)
    if not name then return end
    TriggerServerEvent('devix-inventory:server:useItem', { name = name, slot = slot, info = data or {} })
end)
exports('useSlot', function(slot)
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return end
    local items = lib.callback.await('devix-inventory:oxGetPlayerItems', false) or {}
    for _, it in pairs(items) do
        if it and (it.slot == slot or it.slot == tonumber(slot)) then
            TriggerServerEvent('devix-inventory:server:useItem', { name = it.name, slot = it.slot, info = it.info or it.metadata or {} })
            return
        end
    end
end)
exports('weaponWheel', function()
    -- stub: devix-inventory may have own weapon wheel
end)
