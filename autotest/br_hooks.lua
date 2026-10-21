--[[
Belt Walkie-Talkie (batman_BeltRadio) in-game nominal test for pz-autotest (.claude/tools/pz-autotest).
Configuration: BeltRadio/autotest.json. Loaded by batman_PZAutoTestDriver with loadstring (global environment, mod
already loaded). One check per main feature of docs/specifications-fonctionnelles.md (F01-F13); edge cases later.

Client side (solo, or client 1 in mp with --client-run): two walkie-talkies are added to the player, one hooked on the
belt (radio A) and one kept in the inventory (radio B), then removed at the end.
  F01 context menu option, F02 window kept open, F03 solo listening (sp) / F04 MP bubble (mp client),
  F05 belt battery drain (waits up to waitSec real seconds for two game minutes), F06 noise, F07 sound,
  F08 transmit predicate, F10 recipe OnTest/OnCreate, F11 carried mains charge, F12 placed device (sp), F13 tooltip.
Server side (mp server after "go", or server mode): shared API, features off on the server, recipe, OnCreate,
placed device (F12) near the first connected player.
Parameter (ctx.params, "-P name=value"): waitSec (default 90).
]]

local H = { client = {}, server = {} }

local lines, okAll, errorsAtStart = {}, true, 0

local function rec(ok, name, detail)
    if not ok then okAll = false end
    lines[#lines + 1] = (ok and "PASS " or "FAIL ") .. name .. (detail ~= nil and (" - " .. tostring(detail)) or "")
end

local function info(text)
    lines[#lines + 1] = "INFO " .. tostring(text)
end

local function check(name, fn)
    local ok, res, detail = pcall(fn)
    if not ok then
        rec(false, name, "error: " .. tostring(res))
        return false
    end
    rec(res == true, name, detail)
    return res == true
end

local function luaErrors()
    return getLuaDebuggerErrorCount and getLuaDebuggerErrorCount() or 0
end

local function reset()
    lines, okAll, errorsAtStart = {}, true, luaErrors()
end

local function result()
    check("no new Lua error during the test", function()
        local n = luaErrors() - errorsAtStart
        return n == 0, "new errors=" .. tostring(n)
    end)
    local pass, total = 0, 0
    for i = 1, #lines do
        local head = lines[i]:sub(1, 4)
        if head == "PASS" then pass = pass + 1 end
        if head == "PASS" or head == "FAIL" then total = total + 1 end
    end
    return { ok = okAll and total > 0, summary = tostring(pass) .. "/" .. tostring(total) .. " PASS", lines = lines }
end

-- ----------------------------------------------------------------------------
-- Shared checks (solo client and server)
-- ----------------------------------------------------------------------------

local RECIPE = "BatmanRadio_AdaptRadioMains"
local TEST_FREQUENCY = 99900

local function recipeRegistered()
    local manager = getScriptManager()
    local recipe = manager:getCraftRecipe(RECIPE) or manager:getCraftRecipe("Base." .. RECIPE)
    return recipe ~= nil, recipe and tostring(recipe:getName()) or "not found"
end

--- Craft data stand-in for OnCreate: only getAllKeepInputItems is read (BatmanRadio_Mains.lua).
local function keepData(item)
    local list = ArrayList.new()
    list:add(item)
    return { getAllKeepInputItems = function() return list end }
end

--- F10: OnTest accepts an unmodified radio, OnCreate marks it, OnTest then refuses it.
local function recipeFunctions(item)
    local Mains = BatmanRadioMains
    check("F10 OnTest accepts an unmodified walkie-talkie", function()
        return Mains.isEligible(item) and Mains.onTestAdapt(item, nil) == true
    end)
    -- character nil: no item sync sent from the test.
    Mains.onCreateAdapt(keepData(item), nil)
    check("F10 OnCreate marks the device for mains power", function()
        local state = Mains.state(item)
        return state ~= nil and tonumber(state.useDelta) ~= nil and state.useDelta > 0,
            state and ("useDelta/h=" .. tostring(state.useDelta)) or "no state"
    end)
    check("F10 OnTest refuses an already adapted device", function()
        return Mains.onTestAdapt(item, nil) == false
    end)
end

--- F12: an IsoRadio with the mains state (tile placed) is tracked and gets the mains rule of its square.
--- The object is built on a loaded square but never added to it (no world change).
local function placedDevice(square)
    local Placed, Mains = BatmanRadioMainsPlaced, BatmanRadioMains
    if not square then
        rec(false, "F12 placed device tracked", "no loaded square")
        return
    end
    local radio = IsoRadio.new(getCell(), square, nil)
    local data = radio:getDeviceData()
    data:setIsBatteryPowered(true)
    data:setHasBattery(true)
    data:setPower(0.5)
    radio:getModData()[Mains.MODDATA_KEY] = { useDelta = 0.02 }
    Placed.consider(radio)
    check("F12 placed adapted device tracked", function()
        return Placed.tracked[radio] ~= nil
    end)
    check("F12 placed device follows the mains rule of its square", function()
        local onMains = Mains.isPoweredSquare(square)
        local perMinute = data:getUseDelta()
        local good = onMains and perMinute == 0 or (not onMains and math.abs(perMinute * 60 - 0.02) < 0.0001)
        return good, "powered=" .. tostring(onMains) .. " useDelta/min=" .. tostring(perMinute)
    end)
    check("F12 mains state kept for pickup (movableData)", function()
        local movable = radio:getModData().movableData
        return type(movable) == "table" and type(movable[Mains.MODDATA_KEY]) == "table"
    end)
    Placed.tracked[radio] = nil
end

-- ----------------------------------------------------------------------------
-- Client side
-- ----------------------------------------------------------------------------

local C = {}

local function newRadio(p, fullType)
    local item = p:getInventory():AddItem(fullType)
    local data = item:getDeviceData()
    data:setHasBattery(true)
    data:setPower(0.8)
    data:setDeviceVolume(0.5)
    data:setChannel(TEST_FREQUENCY)
    data:setMicIsMuted(false)
    data:setIsTurnedOn(true)
    return item, data
end

--- Hooks the radio on the walkie-talkie belt slot, as ISAttachItemHotbar:perform does (without the animation).
local function attach(p, item)
    p:setAttachedItem(C.slot, item)
    item:setAttachedSlot(1)
    item:setAttachedSlotType("Belt")
    item:setAttachedToModel(C.slot)
end

local function detach(p, item)
    if p:isAttachedItem(item) then p:removeAttachedItem(item) end
    item:setAttachedSlot(-1)
    item:setAttachedSlotType(nil)
    item:setAttachedToModel(nil)
end

local function contextOption(p, item)
    local Core = BatmanRadioSupport
    local context = ISContextMenu.get(p:getPlayerNum(), 0, 0)
    Core.onFillInventoryContextMenu(p:getPlayerNum(), context, { item })
    local option = context:getOptionFromName(getText(Core.OPTIONS_KEY))
    context:hideAndChildren()
    return option
end

local function runClient(p)
    local Core, Support, Mains = BatmanRadioSupport, BatmanRadioSupport, BatmanRadioMains
    local mpClient = isClient()
    info("side=" .. (mpClient and "mp client" or "solo") .. " player=" .. tostring(p:getUsername()))

    check("API loaded (BatmanRadioSupport VERSION >= 2)", function()
        return type(Support) == "table" and (Support.VERSION or 0) >= 2 and type(Core.isAttachedOnly) == "function"
            and type(Mains) == "table", "VERSION=" .. tostring(Support and Support.VERSION)
    end)

    local radioA, dataA = newRadio(p, "Base.WalkieTalkie2")
    local radioB = newRadio(p, "Base.WalkieTalkie2")
    C.radioA, C.radioB, C.dataA = radioA, radioB, dataA
    attach(p, radioA)

    check("radio A hooked on the belt (isAttachedOnly)", function()
        return Core.isAttachedOnly(p, radioA) == true, C.slot
    end)

    -- F01
    check("F01 Device Options offered for the belt walkie-talkie", function()
        return contextOption(p, radioA) ~= nil
    end)

    -- F02
    check("F02 window wrapper installed", function()
        return ISRadioWindow.update == Core.windowWrapper
    end)
    check("F02 window kept open and radio on after update", function()
        ISRadioWindow.activate(p, radioA)
        local window = ISRadioWindow.instances[p:getPlayerNum()]
        window:update()
        local ok = window:getIsVisible() and Core.keepsWindow(window) and dataA:getIsTurnedOn()
        window:close()
        return ok == true, "on=" .. tostring(dataA:getIsTurnedOn())
    end)

    -- F03 / F04
    if not mpClient then
        check("F03 solo receiver started", function()
            return Core.listening == true
        end)
        check("F03 belt radio selected to hear its frequency", function()
            return Core.listeningRadio(p, TEST_FREQUENCY) == radioA
        end)
        BatmanBeltRadioNoise.lastNoise[radioA:getID()] = nil
        Core.deliver(RadioLine.new("PZAT belt line", 1, 1, 1), TEST_FREQUENCY)
        check("F06 reception noise emitted by the belt radio", function()
            return BatmanBeltRadioNoise.lastNoise[radioA:getID()] ~= nil
        end)
        check("F07 reception sound armed for the belt radio", function()
            local state = BatmanBeltRadioAudio and BatmanBeltRadioAudio.states[radioA:getID()]
            return state ~= nil and state.signal > 0
        end)
    else
        local line = "PZAT bubble " .. tostring(getTimestampMs())
        Core.onDeviceTextMP(nil, "", 0, 0, 0, line, radioA)
        check("F04 MP bubble added for the belt walkie-talkie", function()
            local last = Core.lastBubble[p:getPlayerNum()]
            return last ~= nil and last.text == line
        end)
        BatmanBeltRadioNoise.lastNoise[radioA:getID()] = nil
        check("F06 reception noise emitted by the belt radio", function()
            return BatmanBeltRadioNoise.emit(p, radioA) == true
        end)
        check("F07 reception sound armed for the belt radio", function()
            return BatmanBeltRadioAudio.onReceive(p, radioA) == true
        end)
    end

    -- F08
    check("F08 no transmission from the belt (reason belt)", function()
        local ok, reason = Support.canTransmitWith(p, radioA)
        return ok == false and reason == "belt", tostring(reason)
    end)
    check("F08 no transmission from a stowed radio (reason stowed)", function()
        local ok, reason = Support.canTransmitWith(p, radioB)
        return ok == false and reason == "stowed", tostring(reason)
    end)
    p:setPrimaryHandItem(radioB)
    check("F08 transmission allowed in hand", function()
        local ok, reason = Support.canTransmitWith(p, radioB)
        return ok == true, tostring(reason)
    end)

    -- F10, F11, F13 on radio B (in hand)
    recipeFunctions(radioB)
    check("F10 recipe script registered", recipeRegistered)
    local dataB, state = radioB:getDeviceData(), Mains.state(radioB)
    dataB:setPower(0.5)
    Mains.apply(state, dataB, true, 60)
    check("F11 on mains: no drain and battery recharges", function()
        local expected = 0.5 + 60 / (Mains.rechargeHours() * 60)
        return dataB:getUseDelta() == 0 and math.abs(dataB:getPower() - expected) < 0.001,
            "power=" .. tostring(dataB:getPower())
    end)
    Mains.apply(state, dataB, false, 1)
    check("F11 off mains: original drain restored", function()
        return math.abs(dataB:getUseDelta() * 60 - state.useDelta) < 0.0001
    end)
    info("player square powered=" .. tostring(Mains.isPoweredSquare(p:getSquare())))
    check("F13 tooltip provider registered with TooltipLib", function()
        return TooltipLib ~= nil and TooltipLib.hasProvider("batman_BeltRadio_Mains") == true
    end)

    -- F12 (solo: server Lua runs on this machine)
    if not mpClient then
        placedDevice(p:getCurrentSquare())
    end

    -- F05: waits in done() for the game minutes to pass.
    C.stamp0 = getGameTime():getMinutesStamp()
    C.power0 = dataA:getPower()
end

local function cleanupClient(p)
    for _, item in ipairs({ C.radioA, C.radioB }) do
        if item then
            if p:getPrimaryHandItem() == item then p:setPrimaryHandItem(nil) end
            detach(p, item)
            item:getContainer():Remove(item)
        end
    end
    C.radioA, C.radioB = nil, nil
end

function H.client.start(ctx)
    reset()
    local p = getPlayer()
    if not p then return false, "no local player" end
    C.slot = "Walkie Belt Left"
    C.waitMs = (tonumber(ctx.params.waitSec) or 90) * 1000
    C.started = getTimestampMs()
    C.finished = false
    local ok, err = pcall(runClient, p)
    if not ok then
        rec(false, "client checks aborted", err)
        pcall(cleanupClient, p)
        C.finished = true
    end
    return true
end

local function onBelt(p)
    return C.radioA ~= nil and BatmanRadioSupport.isAttachedOnly(p, C.radioA) == true
end

function H.client.done()
    if C.finished then return true end
    local p = getPlayer()
    local elapsed = getGameTime():getMinutesStamp() - C.stamp0
    local timedOut = getTimestampMs() - C.started > C.waitMs
    if elapsed < 2 and not timedOut then return false end
    check("F05 belt battery drains while on", function()
        local power = C.dataA:getPower()
        return elapsed >= 2 and power < C.power0 and onBelt(p),
            "game minutes=" .. tostring(elapsed) .. " power " .. tostring(C.power0) .. " -> " .. tostring(power)
    end)
    pcall(cleanupClient, p)
    C.finished = true
    return true
end

function H.client.result()
    return result()
end

-- ----------------------------------------------------------------------------
-- Server side
-- ----------------------------------------------------------------------------

local function runServer(ctx)
    local Support, Mains = BatmanRadioSupport, BatmanRadioMains
    check("shared API loaded on the server (VERSION >= 2)", function()
        return type(Support) == "table" and (Support.VERSION or 0) >= 2 and type(Support.canTransmitWith) == "function",
            "VERSION=" .. tostring(Support and Support.VERSION)
    end)
    check("client-only features off on the server", function()
        local f = require("BatmanRadio/BatmanRadio_Compat").features()
        return not f.beltBattery and not f.mpBubble and not f.scenarioReception
    end)
    check("sandbox option MainsRechargeHours readable", function()
        local hours = Mains.rechargeHours()
        return type(hours) == "number" and hours >= 1, tostring(hours)
    end)
    check("F10 recipe script registered", recipeRegistered)
    recipeFunctions(instanceItem("Base.WalkieTalkie2"))
    check("F12 placed-device updater present on the server", function()
        return type(BatmanRadioMainsPlaced) == "table" and type(BatmanRadioMainsPlaced.everyMinute) == "function"
    end)
    local player = ctx.players()[1]
    info("connected player=" .. tostring(player and player:getUsername()))
    if player then
        placedDevice(player:getCurrentSquare())
    else
        info("F12 placed device skipped: no connected player (server mode)")
    end
end

function H.server.start(ctx)
    reset()
    local ok, err = pcall(runServer, ctx)
    if not ok then rec(false, "server checks aborted", err) end
    return true
end

function H.server.result()
    return result()
end

return H
