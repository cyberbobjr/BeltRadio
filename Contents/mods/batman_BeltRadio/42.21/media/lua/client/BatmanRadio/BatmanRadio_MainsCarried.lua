-- Belt Walkie-Talkie (batman_BeltRadio) : pile d'une radio bricolée pour le
-- secteur et portée par un joueur local (main, dos, ceinture). Le client (ou le
-- solo) décompte la pile d'une radio d'inventaire (Radio.java:187-205, et
-- BatmanRadio_BeltBattery pour la ceinture) : c'est donc lui qui coupe l'usure et
-- recharge. La case est celle du joueur (Radio.getSquare, Radio.java:143).
-- Limite MP : le serveur n'apprend la charge que par les paquets de pile vanilla
-- envoyés quand la radio est allumée (DeviceData.java:777-787).

local Mains = require "BatmanRadio/BatmanRadio_Mains"

BatmanRadioMainsCarried = BatmanRadioMainsCarried or {}
local Carried = BatmanRadioMainsCarried
local lastStamp = Carried.lastStamp or {}
Carried.lastStamp = lastStamp

-- Rechargement Lua : remplacer le gestionnaire, sans en ajouter un autre.
if Carried.onTick then Events.OnTick.Remove(Carried.onTick) end
if Carried.reset then
    Events.OnDisconnect.Remove(Carried.reset)
    Events.OnMainMenuEnter.Remove(Carried.reset)
end

--- Radios modifiées portées par le joueur (main, dos, accrochées), sans doublon.
function Carried.devices(player)
    local list, seen = {}, {}
    local inventory = player:getInventory()
    local function add(item)
        if item and not seen[item] and item:getContainer() == inventory and Mains.isModified(item) then
            seen[item] = true
            list[#list + 1] = item
        end
    end
    add(player:getPrimaryHandItem())
    add(player:getSecondaryHandItem())
    add(player:getClothingItem_Back())
    local attached = player:getAttachedItems()
    for i = 0, attached:size() - 1 do
        add(attached:getItemByIndex(i))
    end
    return list
end

--- Une fois par minute de jeu : usure coupée et recharge sur le secteur,
--- usure d'origine remise ailleurs. Aucun rattrapage après un chargement.
function Carried.onTick()
    if isServer() then return end
    local stamp = getGameTime():getMinutesStamp()
    local present = {}
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local onMains = Mains.isPoweredSquare(player:getSquare())
            for _, item in ipairs(Carried.devices(player)) do
                local id = item:getID()
                present[id] = true
                local last = lastStamp[id]
                if last ~= stamp then
                    local minutes = last and (stamp - last) or 0
                    Mains.apply(Mains.state(item), item:getDeviceData(), onMains, minutes)
                    lastStamp[id] = stamp
                end
            end
        end
    end
    -- Pas de retrait pendant pairs (table Kahlua) : retraits après le parcours.
    local gone = {}
    for id in pairs(lastStamp) do
        if not present[id] then gone[#gone + 1] = id end
    end
    for _, id in ipairs(gone) do
        lastStamp[id] = nil
    end
end

function Carried.reset()
    lastStamp = {}
    Carried.lastStamp = lastStamp
end

Events.OnTick.Add(Carried.onTick)
Events.OnDisconnect.Add(Carried.reset)
Events.OnMainMenuEnter.Add(Carried.reset)

return Carried
