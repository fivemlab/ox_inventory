# ox_inventory — API stub for devix-inventory

## RegisterStash / RegisterShop örnekleri

Aynı projedeki job resource'larında kullanım örnekleri:

| Resource | Dosya | Ne var |
|----------|-------|--------|
| **qbx_mechanicjob** | `server/main.lua` ~14 | `RegisterStash('mechanicstash', ...)` — client'ta target ile açılış: `client/main.lua` ~592 `openInventory('stash', {id = 'mechanicstash'})` |
| **qbx_police** | `server/main.lua` ~593-596 | `RegisterStash('policetrash_1'.., 'Police Trash', ...)` ve `RegisterStash('policelocker', ...)` — client `client/job.lua` ~297, ~301 |
| **qbx_ambulancejob** | `server/main.lua` ~22, ~28 | `RegisterShop(armory.shopType, armory)` ve `RegisterStash(stash.name, ...)` — client `client/job.lua` ~199 stash, ~207 shop |
| **qbx_properties** | `server/property.lua` ~30 | `RegisterStash('qbx_properties_'..property_name, ...)` |