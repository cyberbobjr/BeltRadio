-- Belt Walkie-Talkie (batman_BeltRadio) : talkie, radio HAM ou radio dorsale
-- bricolé pour le secteur (recette BatmanRadio_AdaptRadioMains, docs/decisions.md).
-- Partagé : la recette (OnTest, OnCreate) tourne en solo ou sur le serveur, la
-- pile d'une radio portée est gérée par le client (BatmanRadio_MainsCarried) et
-- celle d'un appareil posé par le serveur (BatmanRadio_MainsPlaced).
--
-- Sur une case électrifiée, l'usure est coupée à la source (setUseDelta(0) :
-- DeviceData.update retire useDelta × minutes, DeviceData.java:777-779) et la
-- pile se recharge ; hors zone, la valeur d'origine notée au bricolage est
-- remise. Les deux sens sont réimposés à chaque passage : un useDelta à 0 resté
-- dans une sauvegarde ou recopié au ramassage se corrige seul. Une pile reste
-- nécessaire : le vanilla éteint un appareil à pile vide (:789).

local Support = require "BatmanRadio/BatmanRadio_Support"

BatmanRadioMains = BatmanRadioMains or {}
local Mains = BatmanRadioMains

--- Clé de ModData de l'objet : { useDelta = usure d'origine par heure }.
Mains.MODDATA_KEY = "BatmanMains"
--- Usure par heure de repli (talkie vanilla, radio.txt) si l'appareil n'en a pas.
Mains.DEFAULT_USE_DELTA = 0.014
Mains.ITEM_TYPES = {
    ["Base.WalkieTalkie1"] = true, ["Base.WalkieTalkie2"] = true, ["Base.WalkieTalkie3"] = true,
    ["Base.WalkieTalkie4"] = true, ["Base.WalkieTalkie5"] = true, ["Base.WalkieTalkieMakeShift"] = true,
    ["Base.HamRadio1"] = true, ["Base.HamRadio2"] = true, ["Base.HamRadioMakeShift"] = true,
    ["Base.ManPackRadio"] = true,
}

--- Appareil que la recette peut modifier (type listé, radio à pile).
function Mains.isEligible(item)
    if item == nil or not instanceof(item, "Radio") or not Mains.ITEM_TYPES[item:getFullType()] then
        return false
    end
    local data = item:getDeviceData()
    return data ~= nil and data:getIsBatteryPowered()
end

--- État de l'appareil modifié, ou nil. item : objet d'inventaire ou IsoRadio
--- posé comme tuile. La clé est cherchée à la racine de la ModData, puis dans
--- movableData : le ramassage d'un meuble (ISMoveableSpriteProps.lua:1403-1404)
--- ne recopie que cette table dans l'objet créé, la pose la recopie aussi (:2423).
function Mains.state(item)
    if item == nil or not item:hasModData() then
        return nil
    end
    local modData = item:getModData()
    local state = modData[Mains.MODDATA_KEY]
    if type(state) == "table" then
        return state
    end
    local movable = modData.movableData
    state = type(movable) == "table" and movable[Mains.MODDATA_KEY] or nil
    if type(state) == "table" then
        return state
    end
    return nil
end

--- Note l'état dans movableData d'un IsoRadio posé comme tuile, pour que
--- l'objet rendu par le ramassage reste modifié. Renvoie true si ajouté.
function Mains.keepOnPickup(object, state)
    local modData = object:getModData()
    if type(modData.movableData) ~= "table" then
        modData.movableData = {}
    end
    if type(modData.movableData[Mains.MODDATA_KEY]) == "table" then
        return false
    end
    modData.movableData[Mains.MODDATA_KEY] = { useDelta = state.useDelta }
    return true
end

function Mains.isModified(item)
    return Mains.state(item) ~= nil
end

--- Courant présent sur la case : même règle que DeviceData.canBePoweredHere pour
--- un appareil sans pile (DeviceData.java:518-529) : générateur (haveElectricity),
--- ou réseau public (hasGridPower) dans une pièce.
function Mains.isPoweredSquare(square)
    if square == nil then
        return false
    end
    if square:haveElectricity() then
        return true
    end
    return square:hasGridPower() and square:getRoom() ~= nil
end

--- Heures de jeu pour recharger une pile vide (option MainsRechargeHours, au moins 1).
function Mains.rechargeHours()
    local hours = tonumber(Support.option("MainsRechargeHours")) or Support.OPTION_DEFAULTS.MainsRechargeHours
    if hours < 1 then
        return 1
    end
    return hours
end

--- Usure d'origine par heure notée au bricolage (repli si absente ou nulle).
function Mains.originalUseDelta(state)
    local value = state and tonumber(state.useDelta)
    if value == nil or value <= 0 then
        return Mains.DEFAULT_USE_DELTA
    end
    return value
end

--- Applique l'état secteur à un DeviceData. onMains : case électrifiée ;
--- minutes : minutes de jeu écoulées depuis le passage précédent (recharge).
--- getUseDelta rend l'usure par minute, setUseDelta attend l'usure par heure
--- (DeviceData.java:575-581). Renvoie true si la charge a changé.
function Mains.apply(state, data, onMains, minutes)
    if data == nil or not data:getIsBatteryPowered() then
        return false
    end
    if not onMains then
        local perHour = Mains.originalUseDelta(state)
        if math.abs(data:getUseDelta() * 60 - perHour) > 0.000001 then
            data:setUseDelta(perHour)
        end
        return false
    end
    if data:getUseDelta() ~= 0 then
        data:setUseDelta(0)
    end
    if not data:getHasBattery() or minutes == nil or minutes <= 0 then
        return false
    end
    local power = data:getPower()
    if power >= 1 then
        return false
    end
    data:setPower(math.min(1, power + minutes / (Mains.rechargeHours() * 60)))
    return true
end

--- Charge en cours : modifié, sur le secteur, pile présente et non pleine.
function Mains.isCharging(data, onMains)
    return onMains and data ~= nil and data:getIsBatteryPowered() and data:getHasBattery() and data:getPower() < 1
end

-- ----------------------------------------------------------------------------
-- Recette (scripts/BatmanRadio_recipes.txt)
-- ----------------------------------------------------------------------------

--- OnTest, appelé pour chaque objet candidat (item, character) : refuse un
--- appareil déjà modifié, accepte tout le reste (outil, pièces, fil).
function Mains.onTestAdapt(item, character)
    if Mains.isEligible(item) then
        return not Mains.isModified(item)
    end
    return true
end

--- OnCreate (solo ou serveur, jamais sur un client MP) : note l'usure d'origine
--- dans la ModData de l'appareil gardé, puis la renvoie au client.
function Mains.onCreateAdapt(craftRecipeData, character)
    local items = craftRecipeData:getAllKeepInputItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if Mains.isEligible(item) and not Mains.isModified(item) then
            local perHour = item:getDeviceData():getUseDelta() * 60
            if perHour <= 0 then perHour = Mains.DEFAULT_USE_DELTA end
            item:getModData()[Mains.MODDATA_KEY] = { useDelta = perHour }
            if character and syncItemFields then
                syncItemFields(character, item)
            end
        end
    end
end

return Mains
