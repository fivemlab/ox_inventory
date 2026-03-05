--[[
  ox_inventory API — devix-inventory backend.
  Scripts calling exports['ox_inventory']:... use devix-inventory.
]]

local inv = exports['devix-inventory']

local function toDevixItem(item)
    if item == 'money' then return 'cash' end
    return item and tostring(item):lower() or item
end

local function toOxItem(item)
    if item == 'cash' then return 'money' end
    return item
end

-- Kullanıcının items.lua'sı: client.event / server.export / client.export ile otomatik usable (devix-core fallback)
local BridgeItems = {}
local function loadBridgeItems()
    local res = GetCurrentResourceName()
    local raw = LoadResourceFile(res, 'items.lua')
    if not raw or raw == '' then return end
    local fn, err = load(raw, '@items.lua', 't')
    if not fn then return end
    local ok, tab = pcall(fn)
    if ok and type(tab) == 'table' then
        for k, v in pairs(tab) do
            if type(v) == 'table' then
                BridgeItems[tostring(k):lower()] = v
            end
        end
    end
end
loadBridgeItems()

-- Tekil item tanımı (devix-core "no usable" fallback için): client.event, server.export, client.export
local function getItemDefinition(itemName)
    local key = tostring(itemName or ''):lower()
    if key == '' then return nil end
    local fromBridge = BridgeItems[key]
    local list = inv:GetItemList()
    local fromList = list and (list[key] or list[tostring(itemName)])
    local client = {}
    local server = {}
    local label = key
    if fromList and type(fromList) == 'table' then
        label = fromList.label or label
        if fromList.client and type(fromList.client) == 'table' then
            for k, v in pairs(fromList.client) do client[k] = v end
        end
        if fromList.server and type(fromList.server) == 'table' then
            for k, v in pairs(fromList.server) do server[k] = v end
        end
    end
    if fromBridge and type(fromBridge) == 'table' then
        label = fromBridge.label or label
        if fromBridge.client and type(fromBridge.client) == 'table' then
            for k, v in pairs(fromBridge.client) do client[k] = v end
        end
        if fromBridge.server and type(fromBridge.server) == 'table' then
            for k, v in pairs(fromBridge.server) do server[k] = v end
        end
    end
    if not (client.event or client.export or server.export) then return nil end
    return { label = label, client = client, server = server }
end

-- devix slot item -> ox format { name, count, slot, metadata }; info for scripts that expect v.info (e.g. mm_radio)
local function toOxSlot(slotNum, it)
    if not it or not it.name then return nil end
    local meta = it.info or {}
    return {
        name = toOxItem(it.name),
        count = tonumber(it.amount) or 1,
        slot = slotNum,
        metadata = meta,
        info = meta
    }
end

-- AddItem: ox (source, item, amount, metadata, slot) | devix (source, item, amount, slot, info, reason)
local function oxAddItem(source, item, amount, a4, a5, a6)
    item = toDevixItem(item)
    local slot, info, reason
    if type(a4) == 'table' and (a5 == nil or type(a5) == 'number') then
        info, slot, reason = a4, a5, a6
    else
        slot, info, reason = a4, a5, a6
    end
    local ok = inv:AddItem(source, item, amount, slot, info, reason)
    if ok and source and source > 0 then
        local count = inv:GetItemCount(source, item)
        TriggerClientEvent('ox_inventory:itemCount', source, toOxItem(item), count)
        local infoDef = inv:GetSharedItemInfo(item)
        local label = (infoDef and infoDef.label) or item
        local image = (infoDef and infoDef.image) or "placeholder.png"
        TriggerClientEvent("devix-inventory:client:itemNotify", source, "added", item, label, image, amount or 1)
        TriggerClientEvent("devix-inventory:client:inventoryRefresh", source)
    end
    return ok
end

local function oxRemoveItem(source, item, amount, a4, a5)
    item = toDevixItem(item)
    local slot, reason
    if type(a4) == 'table' and (a5 == nil or type(a5) == 'number') then
        slot, reason = a5, nil
    else
        slot, reason = a4, a5
    end
    local ok = inv:RemoveItem(source, item, amount, slot, reason)
    if ok and source and source > 0 then
        local count = inv:GetItemCount(source, item)
        TriggerClientEvent('ox_inventory:itemCount', source, toOxItem(item), count)
        local infoDef = inv:GetSharedItemInfo(item)
        local label = (infoDef and infoDef.label) or item
        local image = (infoDef and infoDef.image) or "placeholder.png"
        TriggerClientEvent("devix-inventory:client:itemNotify", source, "removed", item, label, image, amount or 1)
        TriggerClientEvent("devix-inventory:client:inventoryRefresh", source)
    end
    return ok
end

local function oxGetSlot(source, slot)
    local it = inv:GetItemBySlot(source, slot)
    if not it then return nil end
    return toOxSlot(slot, it)
end

local function oxGetSlotWithItem(source, item)
    item = toDevixItem(item)
    local slotNum, it = inv:GetSlotWithItem(source, item)
    if not it then return nil end
    return toOxSlot(slotNum, it)
end

local function oxGetSlotsWithItem(source, item)
    item = toDevixItem(item)
    local list = inv:GetSlotsWithItem(source, item)
    local out = {}
    for _, row in ipairs(list or {}) do
        if row.slot and row.item then
            out[#out + 1] = toOxSlot(row.slot, row.item)
        end
    end
    return out
end

-- Search(source, 'count', { 'item1','item2' }) veya Search(source, 'count', 'item1') veya Search('count', items) client tarzi
local function oxSearch(a1, a2, a3)
    local source, searchType, items
    if type(a1) == 'number' then
        source, searchType, items = a1, a2, a3
    else
        source, searchType, items = nil, a1, a2
    end
    if searchType ~= 'count' then return nil end
    if type(items) ~= 'table' then items = { items } end
    if not source or source == 0 then return nil end
    local out = {}
    for _, name in ipairs(items) do
        if name and name ~= '' then
            out[name] = inv:GetItemCount(source, toDevixItem(name))
        end
    end
    if #items == 1 then return out[items[1]] end
    return out
end

local function oxSetItem(source, item, amount)
    item = toDevixItem(item)
    local cur = inv:GetItemCount(source, item)
    amount = tonumber(amount) or 0
    if amount > cur then
        return inv:AddItem(source, item, amount - cur, nil, {}, 'ox_set')
    elseif amount < cur then
        return inv:RemoveItem(source, item, cur - amount, nil, 'ox_set')
    end
    return true
end

-- cm_armor / mm_radio vb.: slot'taki eşyanın metadata'sını güncelle (devix-inventory LoadInventory + merge info + SetInventory)
local function oxSetMetadata(source, slot, metadata)
    if not source or not slot or type(metadata) ~= 'table' then return false end
    local slotNum = tonumber(slot)
    if not slotNum or slotNum < 1 then return false end
    local slotBased = inv:LoadInventory(source, nil)
    if not slotBased or not slotBased[slotNum] or not slotBased[slotNum].name then return false end
    local it = slotBased[slotNum]
    it.info = it.info and type(it.info) == 'table' and it.info or {}
    for k, v in pairs(metadata) do it.info[k] = v end
    inv:SetInventory(source, slotBased)
    if source and source > 0 then
        TriggerClientEvent('devix-inventory:client:inventoryRefresh', source)
    end
    return true
end

function oxGetCurrentWeapon(source)
    return nil
end

-- Items() -> ox format { [name] = { label, weight, ... } }
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

local function oxRegisterStash(id, label, slots, weight, owner, groups, coords)
    if not id then return true end
    inv:RegisterStash(id, label, slots, weight, owner, groups, coords)
    return true
end

local function oxRegisterShop(shopType, data)
    if not shopType then return true end
    inv:RegisterShop(shopType, data)
    return true
end

local function oxOpenInventory(invType, data)
    if invType == 'stash' and data then
        local id = type(data) == 'table' and (data.id or data.name) or data
        if id then
            inv:OpenInventory(GetPlayerServerId(PlayerId()), tostring(id), data)
        end
    end
end

exports('AddItem', oxAddItem)
exports('RemoveItem', oxRemoveItem)
exports('GetItemCount', function(source, item, metadata, target)
    local src = (source and source ~= 0) and source or target
    return inv:GetItemCount(src, toDevixItem(item))
end)
exports('GetSlot', oxGetSlot)
exports('GetSlotWithItem', oxGetSlotWithItem)
exports('GetSlotsWithItem', oxGetSlotsWithItem)
exports('ClearInventory', function(source, filterItems)
    if not inv or type(inv.ClearInventory) ~= "function" then return false end
    return inv:ClearInventory(source, filterItems)
end)
exports('Search', oxSearch)
exports('SetItem', oxSetItem)
exports('SetMetadata', oxSetMetadata)
exports('GetCurrentWeapon', oxGetCurrentWeapon)
exports('CanCarryItem', function(source, item, amount) return inv:CanCarryItem(source, toDevixItem(item), amount) end)
exports('CanCarryWeight', function(source, weight)
    if not inv or type(inv.CanCarryWeight) ~= "function" then return true end
    return inv:CanCarryWeight(source, weight)
end)
exports('Items', oxItems)
exports('GetItemDefinition', getItemDefinition)
exports('RegisterStash', oxRegisterStash)
exports('RegisterShop', oxRegisterShop)
exports('CustomDrop', function() return true end)
exports('GetPlayerItems', function()
    if GetResourceState('ox_lib') ~= 'started' or not lib or not lib.callback then return {} end
    return lib.callback.await('devix-inventory:oxGetPlayerItems', false) or {}
end)
exports('GetItem', function(source, item, metadata, strict)
    local slotNum, it = inv:GetSlotWithItem(source, toDevixItem(item))
    if not it then return nil end
    return toOxSlot(slotNum or 0, it)
end)
exports('displayMetadata', function() end)
exports('forceOpenInventory', function(playerId, invType, data)
    if invType == 'stash' and data and (data.id or data.name) then
        local id = tostring(data.id or data.name)
        TriggerClientEvent('devix-inventory:client:openInventory', playerId, 'player', id, data.label or id, 'stash')
    end
end)

-- s2k / ox_inventory compat: extra exports
exports('ItemList', oxItems)
exports('setPlayerInventory', function(source, items)
    if not source or type(items) ~= 'table' then return end
    inv:SetInventory(source, items)
end)
exports('UpdateVehicle', function() return true end)
exports('GetSlotIdWithItem', function(source, item, metadata, strict)
    local slotNum, _ = inv:GetSlotWithItem(source, toDevixItem(item))
    return slotNum
end)
exports('GetSlotIdsWithItem', function(source, item)
    item = toDevixItem(item)
    local list = inv:GetSlotsWithItem(source, item)
    local out = {}
    for _, row in ipairs(list or {}) do
        if row.slot then out[#out + 1] = row.slot end
    end
    return out
end)
exports('GetInventory', function(source) return inv:LoadInventory(source, nil) end)
exports('GetEmptySlot', function(source)
    local raw = inv:LoadInventory(source, nil)
    if not raw or type(raw) ~= 'table' then return 1 end
    for slot = 1, 200 do
        if not raw[slot] or not raw[slot].name then return slot end
    end
    return 1
end)
exports('GetInventoryItems', function(identifier, owner)
    if type(identifier) == 'number' then
        return inv:LoadInventory(identifier, nil) or {}
    end
    -- Stash: identifier = stash name, owner = player identifier (owned stash)
    local stashId = tostring(identifier or '')
    if owner and type(owner) == 'string' and owner ~= '' then
        stashId = stashId .. '_' .. owner
    end
    if stashId == '' or stashId == '_' then return {} end
    return inv:GetStashItems(stashId) or {}
end)

-- rcore_doorlock / ox_inventory compat: register usable item (devix-core DEVIX.UsableItem + ox_inventory:usedItem)
local RegisterUsableItemCallbacks = {}
exports('registerUsableItem', function(itemName, cb)
    if not itemName or type(cb) ~= 'function' then return end
    local key = tostring(itemName):lower()
    RegisterUsableItemCallbacks[key] = cb
    if GetResourceState('devix-core') ~= 'started' then return end
    local ok, DEVIX = pcall(function() return exports['devix-core']:getObjects() end)
    if not ok or not DEVIX or type(DEVIX.UsableItem) ~= 'function' then return end
    DEVIX.UsableItem(key, function(source, itemData)
        local slot = (itemData and type(itemData) == 'table') and (itemData.slot or itemData.slotId) or nil
        local meta = (itemData and type(itemData) == 'table') and (itemData.info or itemData.metadata or {}) or {}
        TriggerEvent('ox_inventory:usedItem', source, key, slot, meta)
        if RegisterUsableItemCallbacks[key] then
            RegisterUsableItemCallbacks[key](source, key, slot, meta)
        end
    end)
end)

-- s2k / ox_inventory compat: hook system (stub — devix-inventory has no equivalent; scripts won't error)
local hookIdCounter = 0
exports('registerHook', function(event, cb, options)
    if not event or type(cb) ~= 'function' then return 0 end
    hookIdCounter = hookIdCounter + 1
    return hookIdCounter
end)
exports('removeHooks', function(id)
    -- no-op: stub
end)

-- Client GetItemCount / getCurrentWeapon icin callback
if GetResourceState('ox_lib') == 'started' and lib and lib.callback then
    lib.callback.register('devix-inventory:oxCompatGetItemCount', function(source, item)
        return inv:GetItemCount(source, toDevixItem(item))
    end)
    lib.callback.register('devix-inventory:oxCompatGetCurrentWeapon', function(source)
        return oxGetCurrentWeapon(source)
    end)
    lib.callback.register('devix-inventory:oxGetPlayerItems', function(source)
        local raw = inv:LoadInventory(source, nil)
        if not raw then return {} end
        local out = {}
        for slot, it in pairs(raw) do
            if it and it.name then
                out[slot] = { name = toOxItem(it.name), amount = it.amount or 1, info = it.info or {}, slot = slot }
            end
        end
        return out
    end)
    lib.callback.register('devix-inventory:oxCompatSearchSlots', function(source, items)
        if not source or source == 0 then return {} end
        if type(items) ~= 'table' then items = { items } end
        local out = {}
        local seen = {}
        for _, name in ipairs(items) do
            if name and name ~= '' then
                local list = inv:GetSlotsWithItem(source, toDevixItem(name))
                for _, row in ipairs(list or {}) do
                    if row.slot and row.item then
                        local ox = toOxSlot(row.slot, row.item)
                        if ox and not seen[row.slot] then
                            seen[row.slot] = true
                            out[#out + 1] = ox
                        end
                    end
                end
            end
        end
        return out
    end)
end

print("^2[ox_inventory]^7 Loaded — devix-inventory backend.")
