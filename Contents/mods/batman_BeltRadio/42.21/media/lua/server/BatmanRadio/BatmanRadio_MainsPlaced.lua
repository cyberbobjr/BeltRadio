-- Belt Walkie-Talkie (batman_BeltRadio) : pile d'un appareil bricolé pour le
-- secteur et posé au sol. Deux sortes d'IsoRadio posés :
-- - objet 3D au sol : IsoRadio sans sprite qui reçoit le DeviceData de l'objet
--   et ModData.RadioItemID = ID de l'objet (ISDropWorldItemAction,
--   ISTransferAction, ISDropVehicleItemAction, qui déclenchent tous OnObjectAdded) ;
-- - tuile (radios HAM, « Placer » d'un talkie) : ISMoveableSpriteProps crée un
--   IsoRadio avec sprite, l'objet d'inventaire disparaît. Le DeviceData suit, et
--   la ModData de l'objet est recopiée dans l'IsoRadio (toute, ou movableData
--   seule si elle existe, :2423-2429). Le ramassage ne rend que movableData
--   (:1403-1404) : l'état y est donc aussi noté (Mains.keepOnPickup).
-- Le DeviceData est mis à jour par le solo ou le serveur (IsoWaveSignal.java:260-265),
-- et la pose comme le ramassage d'une tuile s'y exécutent (ISMoveablesAction:complete) :
-- ce fichier ne tourne pas sur un client MP (media/lua/server y est aussi chargé).

local Mains = require "BatmanRadio/BatmanRadio_Mains"

BatmanRadioMainsPlaced = BatmanRadioMainsPlaced or {}
local Placed = BatmanRadioMainsPlaced
-- IsoRadio suivi -> { state = état secteur de l'objet, stamp = minute du dernier passage }.
local tracked = Placed.tracked or {}
Placed.tracked = tracked

if Placed.onLoadGridsquare then Events.LoadGridsquare.Remove(Placed.onLoadGridsquare) end
if Placed.onObjectAdded then Events.OnObjectAdded.Remove(Placed.onObjectAdded) end
if Placed.everyMinute then Events.EveryOneMinute.Remove(Placed.everyMinute) end

--- Objet d'inventaire posé sur la case dont l'ID est RadioItemID, ou nil.
function Placed.linkedItem(object)
    local square = object:getSquare()
    local id = object:getModData().RadioItemID
    if square == nil or id == nil then
        return nil
    end
    local worldObjects = square:getWorldObjects()
    for i = 0, worldObjects:size() - 1 do
        local item = worldObjects:get(i):getItem()
        if item and item:getID() == id then
            return item
        end
    end
    return nil
end

--- État secteur d'un IsoRadio posé : celui de l'objet 3D lié, sinon le sien
--- (tuile), alors aussi noté pour le ramassage.
function Placed.stateOf(object)
    if object:getModData().RadioItemID ~= nil then
        local state = Mains.state(Placed.linkedItem(object))
        if state then
            return state
        end
    end
    local state = Mains.state(object)
    if state then
        Mains.keepOnPickup(object, state)
    end
    return state
end

--- Suit l'objet s'il est un IsoRadio d'un appareil modifié.
function Placed.consider(object)
    if object == nil or tracked[object] or not instanceof(object, "IsoWaveSignal")
        or not object:hasModData() then
        return
    end
    local state = Placed.stateOf(object)
    if state then
        tracked[object] = { state = state }
        Placed.update(object, tracked[object], getGameTime():getMinutesStamp())
    end
end

function Placed.update(object, entry, stamp)
    local minutes = entry.stamp and (stamp - entry.stamp) or 0
    entry.stamp = stamp
    Mains.apply(entry.state, object:getDeviceData(), Mains.isPoweredSquare(object:getSquare()), minutes)
end

function Placed.onLoadGridsquare(square)
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        Placed.consider(objects:get(i))
    end
end

function Placed.onObjectAdded(object)
    Placed.consider(object)
end

--- Chaque minute de jeu : appareils encore dans le monde seulement (ramassé,
--- détruit ou chunk déchargé : getSquare nil ou index -1).
function Placed.everyMinute()
    local stamp = getGameTime():getMinutesStamp()
    -- Pas de retrait pendant pairs (table Kahlua) : retraits après le parcours.
    local gone = {}
    for object, entry in pairs(tracked) do
        if object:getSquare() == nil or object:getObjectIndex() == -1 then
            gone[#gone + 1] = object
        else
            Placed.update(object, entry, stamp)
        end
    end
    for _, object in ipairs(gone) do
        tracked[object] = nil
    end
end

if not isClient() then
    Events.LoadGridsquare.Add(Placed.onLoadGridsquare)
    Events.OnObjectAdded.Add(Placed.onObjectAdded)
    Events.EveryOneMinute.Add(Placed.everyMinute)
end

return Placed
