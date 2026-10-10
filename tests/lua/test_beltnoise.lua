-- Bruit d'un talkie accroché qui reçoit une ligne (BatmanRadio_BeltNoise) :
-- formule vanilla de DeviceData.doReceiveSignal (volume 100 × volume, portée
-- getDeviceSoundVolumeRange, rien avec écouteurs), délai par radio, option
-- BeltNoise, et réception MP par OnAddMessage du chat radio. Simulé : pas un test en jeu.
local T = {}

local function eq(a, b)
    assert(a == b, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function list(items)
    return { size = function() return #items end, getItemByIndex = function(_, i) return items[i + 1] end }
end

local nextId = 0
local function radio(opts)
    opts = opts or {}
    nextId = nextId + 1
    local data = { on = opts.on ~= false, volume = opts.volume or 0.6, headphones = opts.headphones or -1,
        channel = opts.channel or 151400 }
    data.getIsTurnedOn = function() return data.on end
    data.getDeviceVolume = function() return data.volume end
    data.getHeadphoneType = function() return data.headphones end
    data.getDeviceSoundVolumeRange = function() return 17 end
    data.getChannel = function() return data.channel end
    local item = { id = nextId, data = data }
    item.getID = function(self) return self.id end
    item.getDeviceData = function(self) return self.data end
    item.getContainer = function() return INVENTORY end
    return item
end

local function player()
    local p = { attached = {} }
    p.getX = function() return 10.7 end
    p.getY = function() return 20.2 end
    p.getZ = function() return 1 end
    p.isDead = function() return false end
    p.getInventory = function() return INVENTORY end
    p.getAttachedItems = function(self) return list(self.attached) end
    p.getEquipedRadio = function(self) return self.equipped end
    return p
end

local function message(channel)
    return { getRadioChannel = function() return channel end }
end

function T.setup()
    INVENTORY = {}
    CLIENT = false
    isClient = function() return CLIENT end
    isServer = function() return false end
    SANDBOX = useJavaSandboxOptions({})
    PLAYERS = { player() }
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    -- Récepteur (BatmanRadio_Core) réduit aux deux prédicats utilisés.
    BatmanRadioSupport = {
        isAttachedOnly = function(p, item)
            for _, v in ipairs(p.attached) do if v == item then return true end end
            return false
        end,
        receives = function(item, frequency)
            local data = item:getDeviceData()
            return data:getIsTurnedOn() and data:getChannel() == frequency and data:getDeviceVolume() > 0
        end,
    }
    NOISE = loadMod("client/BatmanRadio/BatmanRadio_BeltNoise.lua")
end

function T.noise_uses_vanilla_volume_and_range_at_the_player()
    eq(NOISE.emit(PLAYERS[1], radio({ volume = 0.6 })), true)
    eq(#SOUNDS, 1)
    local s = SOUNDS[1]
    eq(s.source, PLAYERS[1])
    eq(s.x, 10)
    eq(s.y, 20)
    eq(s.z, 1)
    eq(s.radius, 17)
    eq(s.volume, 60)
end

function T.no_noise_switched_off_muted_or_with_headphones()
    eq(NOISE.emit(PLAYERS[1], radio({ on = false })), false)
    eq(NOISE.emit(PLAYERS[1], radio({ volume = 0 })), false)
    eq(NOISE.emit(PLAYERS[1], radio({ headphones = 0 })), false)
    eq(#SOUNDS, 0)
end

function T.one_noise_per_radio_every_two_seconds()
    local a, b = radio(), radio()
    eq(NOISE.emit(PLAYERS[1], a), true)
    eq(NOISE.emit(PLAYERS[1], a), false)
    eq(NOISE.emit(PLAYERS[1], b), true)
    CLOCK_MS = CLOCK_MS + 1999
    eq(NOISE.emit(PLAYERS[1], a), false)
    CLOCK_MS = CLOCK_MS + 1
    eq(NOISE.emit(PLAYERS[1], a), true)
    eq(#SOUNDS, 3)
end

function T.option_off_is_vanilla_and_read_at_each_use()
    SANDBOX["BeltRadio.BeltNoise"] = false
    eq(NOISE.emit(PLAYERS[1], radio()), false)
    SANDBOX["BeltRadio.BeltNoise"] = true
    eq(NOISE.emit(PLAYERS[1], radio()), true)
end

function T.mp_radio_chat_line_makes_the_belt_radio_noisy()
    CLIENT = true
    local belt = radio({ channel = 98000 })
    PLAYERS[1].attached = { belt }
    triggerEvent("OnAddMessage", message(98000), 1)
    eq(#SOUNDS, 1)
    -- Autre canal, grésillement (canal 0) ou solo : rien.
    CLOCK_MS = CLOCK_MS + 5000
    triggerEvent("OnAddMessage", message(100000), 1)
    triggerEvent("OnAddMessage", message(0), 1)
    CLIENT = false
    triggerEvent("OnAddMessage", message(98000), 1)
    eq(#SOUNDS, 1)
end

function T.mp_no_extra_noise_when_the_equipped_radio_hears_the_channel()
    CLIENT = true
    PLAYERS[1].attached = { radio({ channel = 98000 }) }
    PLAYERS[1].equipped = radio({ channel = 98000 })
    triggerEvent("OnAddMessage", message(98000), 1)
    eq(#SOUNDS, 0)
end

function T.handlers_are_replaced_on_reload()
    loadMod("client/BatmanRadio/BatmanRadio_BeltNoise.lua")
    eq(listenerCount("OnAddMessage"), 1)
end

return T
