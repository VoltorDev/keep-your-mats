local _, ns = ...
local L = ns.L
local module = ns:NewModule("AuctionHouse")

-- Al poner en la ranura de venta de la subasta un material que te sirve, avisa encima del objeto,
-- en el chat y con un sonido. No impide publicar: publicar sigue siendo un clic tuyo.
-- Blizzard_AuctionHouseUI es LoadOnDemand: los marcos solo existen tras su ADDON_LOADED.

local SELL_FRAMES = { "ItemSellFrame", "CommoditiesSellFrame" }
local warnedThisVisit = {}

local function Warning(frame)
    local text = frame.guardaMaterialesWarning
    if not text then
        text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetTextColor(1, 0.25, 0.25)
        local anchor = frame.ItemDisplay or frame
        text:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 4, 2)
        text:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -4, 2)
        text:SetJustifyH("LEFT")
        frame.guardaMaterialesWarning = text
    end
    return text
end

function module.Check(frame, itemLocation)
    local db = ns.db
    local itemID
    if db.enabled and db.ahWarning and itemLocation and C_Item.DoesItemExist(itemLocation) then
        itemID = C_Item.GetItemID(itemLocation)
    end
    local status, skill
    if itemID then
        status, skill = ns.Materials.Status(itemID)
    end
    if status ~= "keep" then
        if frame.guardaMaterialesWarning then
            frame.guardaMaterialesWarning:Hide()
        end
        return
    end
    local name = ns.PROFESSION_NAMES[skill] or tostring(skill)
    local text = Warning(frame)
    text:SetText(L.AH_WARNING:format(name))
    text:Show()
    if not warnedThisVisit[itemID] then
        warnedThisVisit[itemID] = true
        local link = C_Item.GetItemLink(itemLocation)
        ns:Print(L.AH_WARNING_CHAT:format(link or ("item:" .. itemID), name))
        PlaySound(SOUNDKIT.RAID_WARNING)
    end
end

local function Hook()
    local ah = AuctionHouseFrame
    if not ah then
        return
    end
    for _, key in ipairs(SELL_FRAMES) do
        local frame = ah[key]
        if frame and frame.SetItem then
            hooksecurefunc(frame, "SetItem", module.Check)
        end
    end
end

function module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded("Blizzard_AuctionHouseUI", Hook)
    ns:RegisterEvent("AUCTION_HOUSE_CLOSED", function()
        wipe(warnedThisVisit)
    end)
end
