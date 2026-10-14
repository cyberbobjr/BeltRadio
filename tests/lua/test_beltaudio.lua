-- Son d'un talkie accroché (BatmanRadio_BeltAudio) : reprise de
-- DeviceData.updateEmitter sur un émetteur à nous (grésillement, boucle
-- d'émission pendant le compteur vanilla, zap), volume par DeviceVolume ou
-- setVolume, arrêt au décrochage, à l'extinction et option BeltAudio.
-- Simulé : pas un test en jeu (rendu FMOD non vérifié).
local T = {}

local function eq(a, b)
    assert(a == b, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function list(items)
    return { size = function() return #items end, getItemByIndex = function(_, i) return items[i + 1] end }
end

-- Émetteur FMOD simulé : sons en cours par identifiant, journal des appels.
-- playSoundImpl n'accepte que la surcharge à trois arguments (celle à deux
-- arguments avec nil lève une NPE sur un émetteur libre en jeu).
local function emitter(usesParameter)
    local e = { playing = {}, log = {}, nextId = 0, volumes = {}, params = {}, ticks = 0 }
    function e:playSoundImpl(name, doWorldSound, parent)
        assert(doWorldSound == false and parent == nil, "surcharge à trois arguments attendue")
        self.nextId = self.nextId + 1
        self.playing[self.nextId] = name
        self.log[#self.log + 1] = "play " .. name
        return self.nextId
    end
    function e:isPlaying(name)
        for _, n in pairs(self.playing) do if n == name then return true end end
        return false
    end
    function e:stopSound(id)
        self.log[#self.log + 1] = "stop " .. tostring(self.playing[id])
        self.playing[id] = nil
    end
    function e:stopOrTriggerSound(id)
        self.log[#self.log + 1] = "stopOrTrigger " .. tostring(self.playing[id])
        self.playing[id] = nil
    end
    function e:stopAll()
        self.playing = {}
        self.stoppedAll = true
    end
    function e:isUsingParameter(_, name) return usesParameter and name == "DeviceVolume" end
    function e:setParameterValueByName(id, name, value) self.params[id] = value end
    function e:setVolume(id, value) self.volumes[id] = value end
    function e:setPos(x, y, z) self.pos = { x, y, z } end
    function e:tick() self.ticks = self.ticks + 1 end
    return e
end

local nextId = 0
local function radio(opts)
    opts = opts or {}
    nextId = nextId + 1
    local data = { on = opts.on ~= false, volume = opts.volume or 0.6, emergency = opts.emergency or false,
        battery = opts.battery ~= false, power = opts.power or 1 }
    data.getIsTurnedOn = function() return data.on end
    data.getIsTelevision = function() return false end
    data.getDeviceVolume = function() return data.volume end
    data.isEmergencyBroadcast = function() return data.emergency end
    data.getIsBatteryPowered = function() return true end
    data.getHasBattery = function() return data.battery end
    data.getPower = function() return data.power end
    local item = { id = nextId, data = data, isRadio = true }
    item.getID = function(self) return self.id end
    item.getDeviceData = function(self) return self.data end
    item.getContainer = function() return INVENTORY end
    return item
end

local function player()
    local p = { attached = {} }
    p.getX = function() return 10.5 end
    p.getY = function() return 20.25 end
    p.getZ = function() return 1.4 end
    p.isDead = function() return false end
    p.getInventory = function() return INVENTORY end
    p.getAttachedItems = function(self) return list(self.attached) end
    p.getEquipedRadio = function(self) return self.equipped end
    return p
end

local function tick(n)
    for _ = 1, n or 1 do triggerEvent("OnTick") end
end

function T.setup()
    INVENTORY = {}
    MULTIPLIER = 1
    USES_PARAMETER = false
    EMITTERS = {}
    OWNED, RETURNED = {}, {}
    instanceof = function(o, class) return class == "Radio" and type(o) == "table" and o.isRadio == true end
    isServer = function() return false end
    getGameTime = function() return { getMultiplier = function() return MULTIPLIER end } end
    getWorld = function()
        return {
            getFreeEmitter = function(_, x, y, z)
                local e = emitter(USES_PARAMETER)
                e.pos = { x, y, z }
                EMITTERS[#EMITTERS + 1] = e
                return e
            end,
            takeOwnershipOfEmitter = function(_, e) OWNED[#OWNED + 1] = e end,
            returnOwnershipOfEmitter = function(_, e) RETURNED[#RETURNED + 1] = e end,
        }
    end
    SANDBOX = useJavaSandboxOptions({})
    PLAYERS = { player() }
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    -- Récepteur (BatmanRadio_Core) réduit au prédicat utilisé.
    BatmanRadioSupport = {
        isAttachedOnly = function(p, item)
            for _, v in ipairs(p.attached) do if v == item then return true end end
            return false
        end,
    }
    AUDIO = loadMod("client/BatmanRadio/BatmanRadio_BeltAudio.lua")
end

function T.switched_on_belt_radio_plays_static_on_an_owned_emitter()
    PLAYERS[1].attached = { radio() }
    tick()
    eq(#EMITTERS, 1)
    local e = EMITTERS[1]
    eq(OWNED[1], e)
    eq(e.pos[1], 10.5)
    eq(e.pos[2], 20.25)
    eq(e.pos[3], 1)
    eq(e:isPlaying("RadioStatic"), true)
    eq(e.ticks, 1)
    tick(10)
    eq(#EMITTERS, 1)
    eq(#e.log, 1)
end

function T.received_line_plays_the_program_then_zap_and_static()
    local belt = radio()
    PLAYERS[1].attached = { belt }
    tick()
    eq(AUDIO.onReceive(PLAYERS[1], belt), true)
    tick()
    local e = EMITTERS[1]
    eq(e.log[2], "stop RadioStatic")
    eq(e.log[3], "play RadioTalk")
    -- Compteur vanilla : 300, moins 1,25 x multiplicateur par image (240 images ici).
    tick(238)
    eq(e:isPlaying("RadioTalk"), true)
    tick(2)
    eq(e:isPlaying("RadioTalk"), false)
    eq(e.log[4], "stopOrTrigger RadioTalk")
    eq(e.log[5], "play RadioZap")
    eq(e.log[6], "play RadioStatic")
end

function T.emergency_channel_plays_the_emergency_broadcast()
    local belt = radio({ emergency = true })
    PLAYERS[1].attached = { belt }
    AUDIO.onReceive(PLAYERS[1], belt)
    tick()
    eq(EMITTERS[1]:isPlaying("BroadcastEmergency"), true)
    eq(EMITTERS[1]:isPlaying("RadioTalk"), false)
end

function T.volume_by_device_volume_parameter_or_set_volume()
    local belt = radio({ volume = 0.4 })
    PLAYERS[1].attached = { belt }
    tick()
    eq(EMITTERS[1].volumes[1], 0.4)
    belt.data.volume = 0.8
    tick()
    eq(EMITTERS[1].volumes[1], 0.8)
    AUDIO.reset()
    USES_PARAMETER = true
    tick()
    eq(EMITTERS[2].params[1], 0.8)
    eq(EMITTERS[2].volumes[1], nil)
end

function T.stops_when_taken_in_hand_switched_off_or_battery_empty()
    local belt = radio()
    PLAYERS[1].attached = { belt }
    tick()
    PLAYERS[1].equipped = belt
    tick()
    eq(EMITTERS[1].stoppedAll, true)
    eq(RETURNED[1], EMITTERS[1])
    PLAYERS[1].equipped = nil
    tick()
    belt.data.on = false
    tick()
    eq(EMITTERS[2].stoppedAll, true)
    belt.data.on = true
    belt.data.power = 0
    tick()
    eq(#EMITTERS, 2)
    PLAYERS[1].attached = {}
    belt.data.power = 1
    tick()
    eq(#EMITTERS, 2)
end

function T.option_off_is_vanilla_and_read_at_each_use()
    local belt = radio()
    PLAYERS[1].attached = { belt }
    tick()
    SANDBOX["BeltRadio.BeltAudio"] = false
    tick()
    eq(EMITTERS[1].stoppedAll, true)
    eq(AUDIO.onReceive(PLAYERS[1], belt), false)
    tick()
    eq(#EMITTERS, 1)
    SANDBOX["BeltRadio.BeltAudio"] = true
    tick()
    eq(#EMITTERS, 2)
end

function T.line_for_an_unheld_radio_not_on_the_belt_is_ignored()
    eq(AUDIO.onReceive(PLAYERS[1], radio()), false)
    tick()
    eq(#EMITTERS, 0)
end

function T.handlers_are_replaced_on_reload_and_sounds_kept_in_check()
    PLAYERS[1].attached = { radio() }
    tick()
    loadMod("client/BatmanRadio/BatmanRadio_BeltAudio.lua")
    eq(listenerCount("OnTick"), 1)
    tick()
    eq(#EMITTERS, 1)
    triggerEvent("OnDisconnect")
    eq(EMITTERS[1].stoppedAll, true)
end

return T
