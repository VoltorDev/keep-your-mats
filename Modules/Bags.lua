local _, ns = ...
local module = ns:NewModule("Bags")

-- Icono de la profesión en la esquina superior derecha de cada hueco que guarda un material que
-- te sirve (en gris, si se pide, los que ya no te suben). Se engancha a las bolsas de Blizzard
-- (ContainerFrame1..N y la bolsa combinada) y al panel del banco, con hooksecurefunc: no se
-- reasigna nada de Blizzard. Los marcos de bolsa no son seguros: se puede pintar en combate.

local SIZE = 14

local function Mark(button)
    local mark = button.guardaMaterialesMark
    if not mark then
        local back = button:CreateTexture(nil, "OVERLAY", nil, 6)
        back:SetSize(SIZE + 2, SIZE + 2)
        back:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
        back:SetColorTexture(0, 0, 0, 0.85)
        mark = button:CreateTexture(nil, "OVERLAY", nil, 7)
        mark:SetSize(SIZE, SIZE)
        mark:SetPoint("CENTER", back, "CENTER")
        mark:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        mark.back = back
        button.guardaMaterialesMark = mark
    end
    return mark
end

local function Hide(button)
    local mark = button.guardaMaterialesMark
    if mark then
        mark:Hide()
        mark.back:Hide()
    end
end

function module.Decorate(button, bag, slot)
    local db = ns.db
    if not (db.enabled and db.markBags) or bag == nil or slot == nil then
        Hide(button)
        return
    end
    local itemID = C_Container.GetContainerItemID(bag, slot)
    local status, skill
    if itemID then
        status, skill = ns.Materials.Status(itemID)
    end
    if status == "done" and not db.showDone then
        status = nil
    end
    if not status then
        Hide(button)
        return
    end
    local mark = Mark(button)
    mark:SetTexture(ns.Materials.Icon(skill))
    mark:SetDesaturated(status == "done")
    mark:SetAlpha(status == "done" and 0.6 or 1)
    mark:Show()
    mark.back:Show()
end

local function DecorateContainer(frame)
    for _, button in frame:EnumerateValidItems() do
        module.Decorate(button, button:GetBagID(), button:GetID())
    end
end

local function DecorateBank()
    local panel = BankPanel
    if not (panel and panel.EnumerateValidItems and panel:IsShown()) then
        return
    end
    for button in panel:EnumerateValidItems() do
        module.Decorate(button, button:GetBankTabID(), button:GetContainerSlotID())
    end
end

local function ContainerFrames()
    local frames = {}
    for i = 1, NUM_CONTAINER_FRAMES or 0 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            frames[#frames + 1] = frame
        end
    end
    if ContainerFrameCombinedBags then
        frames[#frames + 1] = ContainerFrameCombinedBags
    end
    return frames
end

function module:Refresh()
    for _, frame in ipairs(ContainerFrames()) do
        if frame:IsShown() then
            DecorateContainer(frame)
        end
    end
    DecorateBank()
end

function module:OnEnable()
    for _, frame in ipairs(ContainerFrames()) do
        if frame.UpdateItems then
            hooksecurefunc(frame, "UpdateItems", DecorateContainer)
        end
    end
    -- El banco refresca huecos sueltos con button:Refresh() en BAG_UPDATE; el ciclo completo de
    -- la pestaña pasa por estos dos métodos, y BAG_UPDATE_DELAYED recoge lo demás.
    if BankPanel then
        for _, method in ipairs({ "GenerateItemSlotsForSelectedTab", "RefreshAllItemsForSelectedTab" }) do
            if BankPanel[method] then
                hooksecurefunc(BankPanel, method, DecorateBank)
            end
        end
    end
    ns:RegisterEvent("BAG_UPDATE_DELAYED", DecorateBank)
end

function module:ApplySettings()
    self:Refresh()
end
