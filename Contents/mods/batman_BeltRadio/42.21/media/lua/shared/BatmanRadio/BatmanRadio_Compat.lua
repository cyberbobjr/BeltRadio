-- Belt Walkie-Talkie (batman_BeltRadio), source unique du récepteur commun BatmanRadio.
-- Adaptation de nos scénarios à BWT, sans modifier ses fichiers ni sa VOIP.
local Compat = {}

-- Résultat de hasBWT mémorisé : features() est appelé à chaque image.
-- getActivatedMods() rend toujours la même liste Java
-- (ZomboidFileSystem.getModIDs, LuaManager.java:6064-6066), fixe pendant une
-- partie et remplie à nouveau par loadMods, suivi d'un rechargement du Lua qui
-- vide ce cache. La clé est l'identité de la liste et sa taille ; resetCache
-- force une nouvelle lecture.
local cachedMods, cachedSize, cachedResult

function Compat.resetCache()
    cachedMods, cachedSize, cachedResult = nil, nil, nil
end

function Compat.hasBWT()
    local mods = getActivatedMods and getActivatedMods()
    if not mods then return false end
    local size = mods:size()
    if cachedMods ~= nil and mods == cachedMods and size == cachedSize then return cachedResult end
    local found = false
    for i = 0, size - 1 do
        local id = mods:get(i):gsub("^\\", "")
        if id == "BetterWalkieTalkies" or id == "BetterWalkieTalkiesDev" then
            found = true
            break
        end
    end
    cachedMods, cachedSize, cachedResult = mods, size, found
    return found
end

-- Politique commune, réévaluée à l'appel (liste des mods actifs mémorisée,
-- voir hasBWT) : l'installation ou une globale laissée par un rechargement ne
-- prouvent pas l'activation du mod.
function Compat.features()
    local active = Compat.hasBWT()
    local client, server = isClient(), isServer()
    local bwt = active and client and not server and BetterWalkieTalkies
    local bridge = bwt and bwt.RadioTextBridgeHandler
    return {
        bwtActive = active,
        -- Respecter BatteryDrain même désactivé : BWT reste propriétaire.
        beltBattery = not server and not active,
        -- BWT ne remplace pas la réception des stations à la ceinture en solo.
        scenarioReception = not client and not server,
        -- Bulle MP d'une radio non tenue (BatmanRadio_Core.onDeviceTextMP).
        -- BWT n'affiche aucune ligne de chaîne (ni AddDeviceText ni bulle dans
        -- ses Lua 42.20) mais garde ses radios en MP : rien d'ajouté avec lui.
        mpBubble = client and not server and not active,
        -- La fonction peut apparaître après le chargement de notre module.
        radioTextBridge = type(bridge) == "function" and bridge or nil,
    }
end

function Compat.microphoneAvailable(data)
    if not data:getMicIsMuted() then return true end
    local bridge = Compat.features().radioTextBridge
    if type(bridge) ~= "function" then return false end
    -- Le bridge BWT sait distinguer son silence PTT d'un micro volontairement
    -- coupé. Une requête sans parole suffit ; il protège la VOIP et restaure
    -- les micros. Ne pas ignorer globalement getMicIsMuted avec BWT installé.
    return bridge(function() return not data:getMicIsMuted() end, nil)
end

function Compat.say(player, text)
    local function speak(message) return player:Say(message) end
    local bridge = Compat.features().radioTextBridge
    if type(bridge) == "function" then return bridge(speak, text) end
    return speak(text)
end

return Compat
