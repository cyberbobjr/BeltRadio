-- Belt Walkie-Talkie (batman_BeltRadio) : bruit (qui attire les zombies) d'un
-- talkie allumé accroché à la ceinture quand il reçoit une ligne (option
-- sandbox BeltRadio.BeltNoise ; fausse : comportement vanilla).
-- Le vanilla émet ce bruit dans DeviceData.doReceiveSignal seulement si
-- soundCounter <= 0, puis le met à 120 (DeviceData.java:887-915) ; le compteur
-- ne baisse que dans updateSimple, appelé à chaque image pour la radio équipée
-- et jamais pour une radio accrochée : un bruit à la première ligne, puis rien.
-- Même bruit que le vanilla : volume 100 × volume de l'appareil, portée
-- getDeviceSoundVolumeRange, aucun avec écouteurs ; addSound est envoyé au
-- serveur depuis un client MP (WorldSoundManager.java:81-150).
-- Réception : solo, BatmanRadio_Core.deliver ; client MP, OnAddMessage du chat
-- radio (WaveSignalDevice.AddDeviceText → ChatManager.showRadioMessage →
-- RadioChat.showMessage, lignes de station et messages des autres joueurs).

local Support = require "BatmanRadio/BatmanRadio_Support"
local BeltAudio = require "BatmanRadio/BatmanRadio_BeltAudio"

BatmanBeltRadioNoise = BatmanBeltRadioNoise or {}
local Noise = BatmanBeltRadioNoise
-- Au plus un bruit par radio pendant ce délai (le vanilla en main : ~1,6 s).
Noise.COOLDOWN_MS = 2000
local lastNoise = Noise.lastNoise or {}
Noise.lastNoise = lastNoise

if Noise.onAddMessage then Events.OnAddMessage.Remove(Noise.onAddMessage) end
if Noise.reset then
    Events.OnDisconnect.Remove(Noise.reset)
    Events.OnMainMenuEnter.Remove(Noise.reset)
end

--- Bruit d'une ligne reçue par la radio (accrochée) du joueur. Renvoie true si émis.
function Noise.emit(player, radio)
    if player == nil or radio == nil or not Support.enabled("BeltNoise") then
        return false
    end
    local data = radio:getDeviceData()
    if not data or not data:getIsTurnedOn() or data:getHeadphoneType() >= 0 then
        return false
    end
    local volume = data:getDeviceVolume()
    if volume <= 0 then
        return false
    end
    local id, now = radio:getID(), getTimestampMs()
    local last = lastNoise[id]
    if last and now >= last and now - last < Noise.COOLDOWN_MS then
        return false
    end
    lastNoise[id] = now
    addSound(player, math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()),
        data:getDeviceSoundVolumeRange(), math.floor(100 * volume))
    return true
end

--- Client MP : une ligne radio affichée au chat (canal > 0 ; grésillements à 0)
--- fait du bruit pour le talkie accroché qui la reçoit, sauf si la radio
--- équipée reçoit déjà ce canal (le vanilla fait alors son propre bruit), et
--- lance son son d'émission (BatmanRadio_BeltAudio, option BeltAudio).
function Noise.onAddMessage(message, tabId)
    if not isClient() or message == nil or type(message) == "string" or not message.getRadioChannel then
        return
    end
    local channel = message:getRadioChannel()
    local Core = BatmanRadioSupport
    if not channel or channel <= 0 or not Core or not Core.receives or not Core.isAttachedOnly then
        return
    end
    for playerNum = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerNum)
        if player and not player:isDead() then
            local equipped = player:getEquipedRadio()
            if not (equipped and Core.receives(equipped, channel)) then
                local attached, inventory = player:getAttachedItems(), player:getInventory()
                for i = 0, attached:size() - 1 do
                    local item = attached:getItemByIndex(i)
                    if item and item:getContainer() == inventory and Core.isAttachedOnly(player, item)
                        and Core.receives(item, channel) then
                        Noise.emit(player, item)
                        BeltAudio.onReceive(player, item)
                        break
                    end
                end
            end
        end
    end
end

function Noise.reset()
    lastNoise = {}
    Noise.lastNoise = lastNoise
end

Events.OnAddMessage.Add(Noise.onAddMessage)
Events.OnDisconnect.Add(Noise.reset)
Events.OnMainMenuEnter.Add(Noise.reset)

return Noise
