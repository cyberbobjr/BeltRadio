-- Belt Walkie-Talkie (batman_BeltRadio) : ligne d'infobulle d'un appareil
-- bricolé pour le secteur, par TooltipLib (prérequis du mod, require=\TooltipLib).

require "TooltipLib/Core"
local Mains = require "BatmanRadio/BatmanRadio_Mains"

if not TooltipLib or type(TooltipLib.registerProvider) ~= "function" then
    print("[BeltRadio] TooltipLib missing: no mains power line in tooltips")
    return
end

local LABEL = { 0.6, 0.85, 1, 1 }
local CHARGING = { 0.6, 1, 0.6, 1 }

--- Case qui alimente l'objet : celle du porteur, sinon celle de l'objet posé.
local function deviceSquare(item)
    local square = item:getSquare()
    if square then return square end
    local worldItem = item:getWorldItem()
    return worldItem and worldItem:getSquare() or nil
end

TooltipLib.registerProvider({
    id = "batman_BeltRadio_Mains",
    target = "item",
    description = "UI_BeltRadio_TooltipProvider",
    enabled = function(item)
        return Mains.isModified(item)
    end,
    callback = function(ctx)
        local item = ctx.item
        ctx:addLabel(getText("UI_BeltRadio_MainsAdapted"), LABEL)
        if Mains.isCharging(item:getDeviceData(), Mains.isPoweredSquare(deviceSquare(item))) then
            ctx:addLabel(getText("UI_BeltRadio_MainsCharging"), CHARGING)
        end
    end,
})
