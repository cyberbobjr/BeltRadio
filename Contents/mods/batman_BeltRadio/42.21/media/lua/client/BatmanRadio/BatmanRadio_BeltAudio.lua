-- Belt Walkie-Talkie (batman_BeltRadio) : son d'un talkie allumé accroché à la
-- ceinture, comme en main (option sandbox BeltRadio.BeltAudio ; fausse :
-- comportement vanilla, aucun son à la ceinture).
-- Le vanilla joue ce son dans DeviceData.updateEmitter (DeviceData.java:700-757),
-- appelé seulement pour la radio équipée : Radio.update (Radio.java:187-205)
-- coupe à chaque image le son de toute autre radio (cleanSoundsAndEmitter).
-- On reproduit updateEmitter sur un émetteur à nous, gardé hors de la réserve
-- du monde (takeOwnershipOfEmitter) et avancé à chaque image :
--   - grésillement RadioStatic en boucle tant que la radio est allumée ;
--   - à la réception d'une ligne, boucle d'émission BroadcastEmergency (canal
--     de la catégorie Emergency, isEmergencyBroadcast) ou RadioTalk pendant le
--     compteur vanilla (300, moins 1,25 x getMultiplier par image : ~5 s) ;
--   - « zap » RadioZap au retour au grésillement.
-- Volume : paramètre FMOD DeviceVolume si l'événement l'utilise, sinon
-- setVolume (DeviceData.setSoundVolume). Lecture locale seulement
-- (playSoundImpl), comme le vanilla : les autres joueurs n'entendent pas la
-- radio d'un joueur, en main ou à la ceinture.
-- Réception : solo, BatmanRadio_Core.deliver ; client MP, OnAddMessage du chat
-- radio (BatmanRadio_BeltNoise.onAddMessage).

local Support = require "BatmanRadio/BatmanRadio_Support"

BatmanBeltRadioAudio = BatmanBeltRadioAudio or {}
local Audio = BatmanBeltRadioAudio
-- Compteur de signal de DeviceData.doReceiveSignal et sa baisse par image.
Audio.SIGNAL = 300
Audio.SIGNAL_DECAY = 1.25
Audio.STATIC_SOUND = "RadioStatic"
Audio.TALK_SOUND = "RadioTalk"
Audio.EMERGENCY_SOUND = "BroadcastEmergency"
Audio.ZAP_SOUND = "RadioZap"
-- Par radio (getID) : { emitter, loop, signal }. Gardé au rechargement Lua.
local states = Audio.states or {}
Audio.states = states

if Audio.onTick then Events.OnTick.Remove(Audio.onTick) end
if Audio.reset then
    Events.OnDisconnect.Remove(Audio.reset)
    Events.OnMainMenuEnter.Remove(Audio.reset)
end

local function applyVolume(emitter, id, volume)
    if id == nil or id == 0 then return end
    if emitter:isUsingParameter(id, "DeviceVolume") then
        emitter:setParameterValueByName(id, "DeviceVolume", volume)
    else
        emitter:setVolume(id, volume)
    end
end

-- Surcharge à trois arguments, sans ambiguïté : playSoundImpl(nom, nil) sur un
-- émetteur libre choisit la surcharge IsoGridSquare et lève une NPE.
local function play(emitter, name, volume)
    local id = emitter:playSoundImpl(name, false, nil)
    applyVolume(emitter, id, volume)
    return id or 0
end

-- Identifiants suivis, relevés avant d'en retirer : ne pas modifier une table
-- Kahlua pendant pairs.
local function trackedIds()
    local ids = {}
    for id in pairs(states) do ids[#ids + 1] = id end
    return ids
end

local function stop(id)
    local state = states[id]
    if not state then return end
    states[id] = nil
    if state.emitter then
        state.emitter:stopAll()
        getWorld():returnOwnershipOfEmitter(state.emitter)
    end
end

--- Talkie accroché, allumé et alimenté qui doit sonner, ou nil.
local function beltDevice(player, item)
    local Core = BatmanRadioSupport
    if not item or not instanceof(item, "Radio") or item:getContainer() ~= player:getInventory()
        or not Core or not Core.isAttachedOnly or not Core.isAttachedOnly(player, item)
        or player:getEquipedRadio() == item then
        return nil
    end
    local data = item:getDeviceData()
    if not data or not data:getIsTurnedOn() or data:getIsTelevision() then
        return nil
    end
    if data:getIsBatteryPowered() and not (data:getHasBattery() and data:getPower() > 0) then
        return nil
    end
    return data
end

--- Une ligne reçue par le talkie accroché : boucle d'émission pendant le
--- compteur vanilla. Renvoie true si la radio sonnera.
function Audio.onReceive(player, radio)
    if player == nil or radio == nil or not Support.enabled("BeltAudio") or not beltDevice(player, radio) then
        return false
    end
    local id = radio:getID()
    local state = states[id] or { loop = 0, signal = 0 }
    states[id] = state
    state.signal = Audio.SIGNAL
    return true
end

--- Une image de DeviceData.updateEmitter pour un talkie accroché.
function Audio.update(player, radio, data)
    local id = radio:getID()
    local state = states[id] or { loop = 0, signal = 0 }
    states[id] = state
    local x, y, z = player:getX(), player:getY(), math.floor(player:getZ())
    local emitter = state.emitter
    if emitter == nil then
        emitter = getWorld():getFreeEmitter(x, y, z)
        getWorld():takeOwnershipOfEmitter(emitter)
        state.emitter = emitter
    else
        emitter:setPos(x, y, z)
    end
    local volume = data:getDeviceVolume()
    applyVolume(emitter, state.loop, volume)
    local talk = data:isEmergencyBroadcast() and Audio.EMERGENCY_SOUND or Audio.TALK_SOUND
    if state.signal > 0 and not emitter:isPlaying(talk) then
        if state.loop > 0 then emitter:stopSound(state.loop) end
        state.loop = play(emitter, talk, volume)
    end
    if state.loop == 0 or (state.signal <= 0 and not emitter:isPlaying(Audio.STATIC_SOUND)) then
        if state.loop > 0 then
            emitter:stopOrTriggerSound(state.loop)
            play(emitter, Audio.ZAP_SOUND, volume)
        end
        state.loop = play(emitter, Audio.STATIC_SOUND, volume)
    end
    emitter:tick()
    if state.signal > 0 then
        state.signal = state.signal - Audio.SIGNAL_DECAY * getGameTime():getMultiplier()
    end
end

function Audio.onTick()
    local present = {}
    if Support.enabled("BeltAudio") then
        for playerNum = 0, getNumActivePlayers() - 1 do
            local player = getSpecificPlayer(playerNum)
            if player and not player:isDead() then
                local attached = player:getAttachedItems()
                for i = 0, attached:size() - 1 do
                    local item = attached:getItemByIndex(i)
                    local data = beltDevice(player, item)
                    if data and not present[item:getID()] then
                        present[item:getID()] = true
                        Audio.update(player, item, data)
                    end
                end
            end
        end
    end
    -- Décrochée, prise en main (le vanilla la fait sonner), éteinte, vide,
    -- option désactivée : arrêt.
    for _, id in ipairs(trackedIds()) do
        if not present[id] then stop(id) end
    end
end

function Audio.reset()
    for _, id in ipairs(trackedIds()) do stop(id) end
end

Events.OnTick.Add(Audio.onTick)
Events.OnDisconnect.Add(Audio.reset)
Events.OnMainMenuEnter.Add(Audio.reset)

return Audio
