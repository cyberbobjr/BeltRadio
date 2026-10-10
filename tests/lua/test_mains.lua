-- Radios bricolées pour le secteur : règle de courant, usure coupée, recharge,
-- usure d'origine remise, recette (OnTest, OnCreate), radio portée (client) et
-- appareil posé (serveur). DeviceData simulé d'après DeviceData.java 42.21
-- (setUseDelta divise par 60, setPower borné à [0, 1]) : pas un test en jeu.
local T = {}

local function eq(a, b)
    assert(a == b, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function close(a, b)
    assert(math.abs(a - b) < 0.00001, "attendu " .. tostring(b) .. ", obtenu " .. tostring(a))
end

local function list(items)
    return { size = function() return #items end, get = function(_, i) return items[i + 1] end,
        getItemByIndex = function(_, i) return items[i + 1] end }
end

local function deviceData(opts)
    opts = opts or {}
    local data = { power = opts.power or 0.5, useDelta = (opts.perHour or 0.014) / 60,
        battery = opts.hasBattery ~= false }
    data.getIsBatteryPowered = function() return opts.batteryPowered ~= false end
    data.getHasBattery = function() return data.battery end
    data.getPower = function() return data.power end
    data.setPower = function(_, p) data.power = math.max(0, math.min(1, p)) end
    data.getUseDelta = function() return data.useDelta end
    data.setUseDelta = function(_, f) data.useDelta = f / 60 end
    return data
end

local nextId = 0
local function radioItem(fullType, opts)
    nextId = nextId + 1
    local item = { kind = "Radio", fullType = fullType or "Base.WalkieTalkie3", id = nextId, modData = nil,
        data = deviceData(opts) }
    item.getFullType = function(self) return self.fullType end
    item.getID = function(self) return self.id end
    item.getDeviceData = function(self) return self.data end
    item.hasModData = function(self) return self.modData ~= nil end
    item.getModData = function(self)
        self.modData = self.modData or {}
        return self.modData
    end
    item.getContainer = function() return INVENTORY end
    return item
end

local function square(opts)
    opts = opts or {}
    local sq = { generator = opts.generator or false, grid = opts.grid or false, room = opts.room,
        objects = {}, worldObjects = {} }
    sq.haveElectricity = function(self) return self.generator end
    sq.hasGridPower = function(self) return self.grid end
    sq.getRoom = function(self) return self.room end
    sq.getObjects = function(self) return list(self.objects) end
    sq.getWorldObjects = function(self) return list(self.worldObjects) end
    return sq
end

local function player()
    local p = { attached = {}, square = square() }
    p.getInventory = function() return INVENTORY end
    p.getPrimaryHandItem = function(self) return self.primary end
    p.getSecondaryHandItem = function(self) return self.secondary end
    p.getClothingItem_Back = function(self) return self.back end
    p.getAttachedItems = function(self) return list(self.attached) end
    p.getSquare = function(self) return self.square end
    p.isDead = function() return false end
    return p
end

function T.setup()
    INVENTORY = {}
    MINUTE, CLIENT, SERVER = 1000, false, false
    isClient = function() return CLIENT end
    isServer = function() return SERVER end
    getGameTime = function() return { getMinutesStamp = function() return MINUTE end } end
    instanceof = function(object, class)
        if class == "IsoWaveSignal" then return object.kind == "IsoRadio" end
        return object.kind == class
    end
    SANDBOX = useJavaSandboxOptions({})
    PLAYERS = { player() }
    getNumActivePlayers = function() return #PLAYERS end
    getSpecificPlayer = function(i) return PLAYERS[i + 1] end
    SYNCED = {}
    syncItemFields = function(character, item) SYNCED[#SYNCED + 1] = item end
end

local function mains()
    return require "BatmanRadio/BatmanRadio_Mains"
end

local function adapt(item)
    item:getModData().BatmanMains = { useDelta = item.data.useDelta * 60 }
    return item
end

-- Règle de DeviceData.canBePoweredHere : générateur partout, réseau dans une pièce.
function T.powered_square_matches_vanilla_mains_rule()
    local M = mains()
    eq(M.isPoweredSquare(nil), false)
    eq(M.isPoweredSquare(square()), false)
    eq(M.isPoweredSquare(square({ generator = true })), true)
    eq(M.isPoweredSquare(square({ grid = true })), false)
    eq(M.isPoweredSquare(square({ grid = true, room = {} })), true)
    eq(M.isPoweredSquare(square({ room = {} })), false)
end

function T.on_mains_drain_is_cut_and_battery_recharges_at_the_sandbox_rate()
    local M = mains()
    SANDBOX["BeltRadio.MainsRechargeHours"] = 10
    local item = adapt(radioItem(nil, { power = 0.5 }))
    eq(M.apply(M.state(item), item.data, true, 60), true)
    eq(item.data.useDelta, 0)
    close(item.data.power, 0.6)
    M.apply(M.state(item), item.data, true, 600)
    eq(item.data.power, 1)
    -- Pleine : plus rien à faire.
    eq(M.apply(M.state(item), item.data, true, 60), false)
end

function T.recharge_rate_follows_option_changes_and_never_divides_by_zero()
    local M = mains()
    local item = adapt(radioItem(nil, { power = 0 }))
    SANDBOX["BeltRadio.MainsRechargeHours"] = 24
    M.apply(M.state(item), item.data, true, 60)
    close(item.data.power, 1 / 24)
    SANDBOX["BeltRadio.MainsRechargeHours"] = 0
    M.apply(M.state(item), item.data, true, 30)
    close(item.data.power, 1 / 24 + 0.5)
end

function T.default_recharge_is_ten_hours_without_the_option()
    local M = mains()
    local item = adapt(radioItem(nil, { power = 0 }))
    M.apply(M.state(item), item.data, true, 60)
    close(item.data.power, 0.1)
end

function T.off_mains_original_drain_is_restored()
    local M = mains()
    local item = adapt(radioItem(nil, { perHour = 0.01 }))
    M.apply(M.state(item), item.data, true, 1)
    eq(item.data.useDelta, 0)
    M.apply(M.state(item), item.data, false, 60)
    close(item.data.useDelta * 60, 0.01)
    close(item.data.power, 0.5 + 1 / 600)
end

function T.saved_zero_drain_without_noted_value_falls_back_to_vanilla_walkie_rate()
    local M = mains()
    local item = radioItem(nil, { perHour = 0 })
    item:getModData().BatmanMains = { useDelta = 0 }
    M.apply(M.state(item), item.data, false, 1)
    close(item.data.useDelta * 60, 0.014)
end

function T.no_battery_means_no_recharge_but_no_drain_either()
    local M = mains()
    local item = adapt(radioItem(nil, { power = 0, hasBattery = false }))
    eq(M.apply(M.state(item), item.data, true, 60), false)
    eq(item.data.power, 0)
    eq(item.data.useDelta, 0)
    eq(M.isCharging(item.data, true), false)
end

function T.recipe_accepts_only_unmodified_listed_radios()
    local M = mains()
    local walkie = radioItem("Base.WalkieTalkie5")
    local manpack = radioItem("Base.ManPackRadio")
    local ham = adapt(radioItem("Base.HamRadio2"))
    local tv = radioItem("Base.TvBlack")
    local scrap = { kind = "InventoryItem" }
    eq(M.onTestAdapt(walkie, nil), true)
    eq(M.onTestAdapt(manpack, nil), true)
    eq(M.onTestAdapt(ham, nil), false)
    eq(M.isEligible(tv), false)
    eq(M.onTestAdapt(scrap, nil), true)
end

function T.recipe_notes_original_drain_and_syncs_the_item()
    local M = mains()
    local walkie = radioItem("Base.WalkieTalkie2", { perHour = 0.014 })
    local screwdriver = { kind = "InventoryItem" }
    local recipeData = { getAllKeepInputItems = function() return list({ walkie, screwdriver }) end }
    local character = {}
    M.onCreateAdapt(recipeData, character)
    close(M.state(walkie).useDelta, 0.014)
    eq(SYNCED[1], walkie)
    eq(#SYNCED, 1)
    -- Une seconde exécution ne remplace pas la valeur notée.
    walkie.data.useDelta = 0
    M.onCreateAdapt(recipeData, character)
    close(M.state(walkie).useDelta, 0.014)
end

-- Radio portée (client) : une fois par minute, main, dos et ceinture.
function T.carried_radio_recharges_on_mains_and_drains_again_elsewhere()
    local p = PLAYERS[1]
    local belt = adapt(radioItem(nil, { power = 0.2 }))
    local hand = adapt(radioItem(nil, { power = 0.2 }))
    local plain = radioItem(nil, { power = 0.2 })
    p.attached = { belt, plain }
    p.primary = hand
    p.square = square({ grid = true, room = {} })
    loadMod("client/BatmanRadio/BatmanRadio_MainsCarried.lua")
    triggerEvent("OnTick")
    eq(belt.data.useDelta, 0)
    eq(hand.data.useDelta, 0)
    close(belt.data.power, 0.2) -- première minute vue : rien à rattraper
    triggerEvent("OnTick")
    close(belt.data.power, 0.2) -- même minute
    MINUTE = MINUTE + 30
    triggerEvent("OnTick")
    close(belt.data.power, 0.25)
    close(hand.data.power, 0.25)
    close(plain.data.useDelta * 60, 0.014) -- non modifiée : jamais touchée
    p.square = square()
    MINUTE = MINUTE + 1
    triggerEvent("OnTick")
    close(belt.data.useDelta * 60, 0.014)
    close(belt.data.power, 0.25)
end

function T.carried_handler_is_replaced_on_reload_and_idle_on_server()
    loadMod("client/BatmanRadio/BatmanRadio_MainsCarried.lua")
    loadMod("client/BatmanRadio/BatmanRadio_MainsCarried.lua")
    eq(listenerCount("OnTick"), 1)
    SERVER = true
    local belt = adapt(radioItem())
    PLAYERS[1].attached = { belt }
    PLAYERS[1].square = square({ generator = true })
    triggerEvent("OnTick")
    close(belt.data.useDelta * 60, 0.014)
end

-- Appareil posé (serveur ou solo) : IsoRadio lié par RadioItemID.
local function placed(item, sq)
    local object = { kind = "IsoRadio", modData = { RadioItemID = item:getID() }, square = sq, index = 0,
        data = deviceData({ power = item.data.power, perHour = item.data.useDelta * 60 }) }
    object.hasModData = function() return true end
    object.getModData = function(self) return self.modData end
    object.getSquare = function(self) return self.square end
    object.getObjectIndex = function(self) return self.index end
    object.getDeviceData = function(self) return self.data end
    sq.objects[#sq.objects + 1] = object
    sq.worldObjects[#sq.worldObjects + 1] = { getItem = function() return item end }
    return object
end

function T.placed_ham_found_on_load_recharges_each_minute_on_a_generator()
    local sq = square({ generator = true })
    local ham = adapt(radioItem("Base.HamRadio1", { power = 0.1, perHour = 0.01 }))
    local object = placed(ham, sq)
    local other = placed(radioItem("Base.HamRadio1", { power = 0.1 }), sq)
    loadMod("server/BatmanRadio/BatmanRadio_MainsPlaced.lua")
    triggerEvent("LoadGridsquare", sq)
    eq(object.data.useDelta, 0)
    MINUTE = MINUTE + 60
    triggerEvent("EveryOneMinute")
    close(object.data.power, 0.2)
    close(other.data.power, 0.1)
    close(other.data.useDelta * 60, 0.014)
    -- Générateur arrêté : usure d'origine remise.
    sq.generator = false
    MINUTE = MINUTE + 1
    triggerEvent("EveryOneMinute")
    close(object.data.useDelta * 60, 0.01)
end

function T.placed_device_added_in_play_is_tracked_then_released_when_picked_up()
    local sq = square({ grid = true, room = {} })
    local walkie = adapt(radioItem(nil, { power = 0.5 }))
    local object = placed(walkie, sq)
    loadMod("server/BatmanRadio/BatmanRadio_MainsPlaced.lua")
    triggerEvent("OnObjectAdded", object)
    triggerEvent("OnObjectAdded", object)
    MINUTE = MINUTE + 60
    triggerEvent("EveryOneMinute")
    close(object.data.power, 0.6)
    object.index = -1
    MINUTE = MINUTE + 60
    triggerEvent("EveryOneMinute")
    close(object.data.power, 0.6)
    eq(BatmanRadioMainsPlaced.tracked[object], nil)
end

function T.placed_handlers_are_not_registered_on_an_mp_client()
    CLIENT = true
    loadMod("server/BatmanRadio/BatmanRadio_MainsPlaced.lua")
    eq(listenerCount("LoadGridsquare"), 0)
    eq(listenerCount("EveryOneMinute"), 0)
end

return T
