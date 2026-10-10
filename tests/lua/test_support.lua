-- Partie partagée de l'API (BatmanRadio_Support) : VERSION, lecture des
-- options sandbox, prédicat d'émission canTransmitWith (décision 4 : jamais
-- depuis la ceinture). Chargée seule, comme sur un serveur dédié (sans client/).
local T = {}

--- Radio d'inventaire simulée ; opts remplace les valeurs de DeviceData.
local function makeRadio(opts)
    opts = opts or {}
    local values = {
        getIsPortable = true, getIsTelevision = false, getIsTwoWay = true, isNoTransmit = false,
        getIsTurnedOn = true, getIsBatteryPowered = true, getHasBattery = true, getPower = 0.8,
        getMicIsMuted = false,
    }
    local data = {}
    for name, value in pairs(values) do
        local v = value
        if opts[name] ~= nil then v = opts[name] end
        data[name] = function() return v end
    end
    return { kind = opts.kind or "Radio", getDeviceData = function() return data end }
end

local function makePlayer()
    local player = { attached = {}, hands = {} }
    player.getPrimaryHandItem = function(self) return self.hands[1] end
    player.getSecondaryHandItem = function(self) return self.hands[2] end
    player.getClothingItem_Back = function(self) return self.back end
    player.isAttachedItem = function(self, item)
        for _, v in ipairs(self.attached) do
            if v == item then return true end
        end
        return false
    end
    return player
end

function T.setup()
    CLIENT, SERVER = false, false
    isClient = function() return CLIENT end
    isServer = function() return SERVER end
    instanceof = function(object, class) return type(object) == "table" and object.kind == class end
    getActivatedMods = function() return { size = function() return 0 end } end
    SandboxVars = {}
    PLAYER = makePlayer()
    SUPPORT = loadMod("shared/BatmanRadio/BatmanRadio_Support.lua")
end

-- VERSION ------------------------------------------------------------------------

function T.version_is_a_positive_integer_on_the_global_table()
    assertEq(type(SUPPORT.VERSION), "number", "VERSION est un nombre")
    assertTrue(SUPPORT.VERSION >= 1 and math.floor(SUPPORT.VERSION) == SUPPORT.VERSION, "entier >= 1")
    assertEq(BatmanRadioSupport, SUPPORT, "globale BatmanRadioSupport")
    assertEq(SUPPORT.MOD_ID, "batman_BeltRadio", "identifiant du mod")
end

function T.reload_and_core_keep_one_table()
    BatmanRadioSupport.providers = { keep = true }
    local again = loadMod("shared/BatmanRadio/BatmanRadio_Support.lua")
    assertEq(again, SUPPORT, "même table après rechargement")
    assertTrue(again.providers.keep, "champs du Core conservés")
end

-- Options ------------------------------------------------------------------------

function T.options_default_to_true_without_sandbox_options()
    getSandboxOptions = nil
    for _, name in ipairs({ "MPBubble", "BeltBattery", "BeltListening" }) do
        assertEq(SUPPORT.option(name), true, name .. " par défaut")
        assertEq(SUPPORT.enabled(name), true, name .. " activée")
    end
end

function T.java_option_wins_over_stale_sandboxvars_and_is_read_each_time()
    SandboxVars = { BeltRadio = { MPBubble = true } } -- périmé en solo après l'éditeur
    local values = useJavaSandboxOptions({ ["BeltRadio.MPBubble"] = false })
    assertEq(SUPPORT.enabled("MPBubble"), false, "valeur Java")
    values["BeltRadio.MPBubble"] = true
    assertEq(SUPPORT.enabled("MPBubble"), true, "changement en cours de partie vu aussitôt")
end

function T.sandboxvars_then_default_when_the_java_option_is_unknown()
    useJavaSandboxOptions({})
    SandboxVars = { BeltRadio = { BeltListening = false } }
    assertEq(SUPPORT.enabled("BeltListening"), false, "repli SandboxVars")
    assertEq(SUPPORT.enabled("BeltBattery"), true, "option absente : défaut")
end

-- canTransmitWith --------------------------------------------------------------

local function check(radio, expectedOk, expectedReason, message)
    local ok, reason = SUPPORT.canTransmitWith(PLAYER, radio)
    assertEq(ok, expectedOk, message)
    assertEq(reason, expectedReason, message .. " (raison)")
end

function T.transmits_in_either_hand_or_on_the_back()
    local radio = makeRadio()
    PLAYER.hands = { radio }
    check(radio, true, nil, "main principale")
    PLAYER.hands = { nil, radio }
    check(radio, true, nil, "main secondaire")
    PLAYER.hands, PLAYER.back = {}, radio
    check(radio, true, nil, "sur le dos")
end

function T.belt_radio_never_transmits()
    local radio = makeRadio()
    PLAYER.attached = { radio }
    check(radio, false, "belt", "accrochée à la ceinture")
    -- Prise en main : accrochée et en main un instant, la main l'emporte.
    PLAYER.hands = { radio }
    check(radio, true, nil, "en main")
end

function T.stowed_radio_never_transmits()
    check(makeRadio(), false, "stowed", "rangée dans l'inventaire ou un sac")
end

function T.muted_microphone_off_radio_and_empty_battery_are_refused()
    local muted = makeRadio({ getMicIsMuted = true })
    PLAYER.hands = { muted }
    check(muted, false, "micMuted", "micro coupé")
    local off = makeRadio({ getIsTurnedOn = false })
    PLAYER.hands = { off }
    check(off, false, "off", "éteinte")
    local empty = makeRadio({ getPower = 0 })
    PLAYER.hands = { empty }
    check(empty, false, "battery", "pile vide")
    local none = makeRadio({ getHasBattery = false })
    PLAYER.hands = { none }
    check(none, false, "battery", "sans pile")
    local mains = makeRadio({ getIsBatteryPowered = false, getHasBattery = false, getPower = 0 })
    PLAYER.hands = { mains }
    check(mains, true, nil, "sans pile requise")
end

function T.receivers_and_non_radios_are_refused()
    local receiver = makeRadio({ getIsTwoWay = false })
    PLAYER.hands = { receiver }
    check(receiver, false, "notTransmitter", "récepteur seul")
    local cd = makeRadio({ isNoTransmit = true })
    PLAYER.hands = { cd }
    check(cd, false, "notTransmitter", "NoTransmit (lecteur CD)")
    local fixed = makeRadio({ getIsPortable = false })
    PLAYER.hands = { fixed }
    check(fixed, false, "notRadio", "radio non portative")
    local weapon = makeRadio({ kind = "HandWeapon" })
    PLAYER.hands = { weapon }
    check(weapon, false, "notRadio", "pas une radio")
    check(nil, false, "notRadio", "rien")
end

function T.server_does_not_check_the_stale_microphone()
    -- setMicIsMuted n'est jamais transmis au serveur : son état y est périmé.
    SERVER = true
    local muted = makeRadio({ getMicIsMuted = true })
    PLAYER.hands = { muted }
    check(muted, true, nil, "serveur : micro non vérifié")
    PLAYER.hands, PLAYER.attached = {}, { muted }
    check(muted, false, "belt", "serveur : ceinture toujours refusée")
end

function T.bwt_idle_mute_is_not_a_muted_microphone()
    -- Better Walkie Talkies coupe le micro au repos (PTT) : son pont dit si le
    -- micro est volontairement coupé (BatmanRadio_Compat.microphoneAvailable).
    CLIENT = true
    getActivatedMods = function()
        return { size = function() return 1 end, get = function() return "\\BetterWalkieTalkies" end }
    end
    BetterWalkieTalkies = { RadioTextBridgeHandler = function() return true end }
    local radio = makeRadio({ getMicIsMuted = true })
    PLAYER.hands = { radio }
    check(radio, true, nil, "silence PTT de BWT")
end

return T
