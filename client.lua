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

local function oxItems()
    local list = inv:GetItemList()
    if not list or type(list) ~= 'table' then return {} end
    local out = {}
    for name, data in pairs(list) do
        if data and type(data) == 'table' then
            out[toOxItem(name)] = {
                label = data.label or name,
                weight = data.weight or 0,
                stack = not (data.unique),
                close = true,
                description = data.description or nil,
                client = data.client or {}
            }
        end
    end
    return out
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

local function oxOpenInventory(invType, data)
    if invType ~= 'stash' then return end
    local id = type(data) == 'table' and (data.id or data.name) or data
    local label = type(data) == 'table' and data.label or tostring(id)
    if id then
        inv:OpenStashInventory(tostring(id), label or tostring(id))
    end
end

exports('GetItemCount', oxGetItemCount)
exports('getCurrentWeapon', oxGetCurrentWeapon)
exports('Items', oxItems)
exports('Search', oxSearch)
exports('openInventory', oxOpenInventory)
exports('displayMetadata', function() end)
exports('GetPlayerItems', function()
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return {} end
    return lib.callback.await('devix-inventory:oxGetPlayerItems', false) or {}
end)
