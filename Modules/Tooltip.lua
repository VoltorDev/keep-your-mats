local _, ns = ...
local L = ns.L
local module = ns:NewModule("Tooltip")

-- Líneas en el tooltip de cualquier objeto que sea material de tus profesiones: en cuántas
-- recetas te sube aún y hasta qué rango, o que ya no te sube. Con la opción de alts, también
-- qué otros personajes lo aprovechan.

local GREEN, GRAY, GOLD = "|cff40ff40", "|cff999999", "|cffffd200"
local MAX_ALT_LINES = 4

local function Icon(skill)
    return ("|T%d:0|t "):format(ns.Materials.Icon(skill))
end

local function Name(skill)
    return ns.PROFESSION_NAMES[skill] or tostring(skill)
end

-- Nombre localizado del intermedio; si el cliente aún no lo tiene en caché, lo pide para la
-- próxima vez y de momento enseña el ID.
local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        return name
    end
    C_Item.RequestLoadItemDataByID(itemID)
    return "item " .. itemID
end

function module.Lines(itemID)
    local db = ns.db
    local lines = {}
    local result = ns.Materials.Evaluate(itemID, ns.Materials.BuildProfile(ns.professions, db.secondaries))
    for _, e in ipairs(result and result.entries or {}) do
        local where = e.learned and ("%s %d"):format(Name(e.skill), e.rank) or L.NOT_LEARNED:format(Name(e.skill))
        local via = e.via
        if e.useful > 0 then
            lines[#lines + 1] = Icon(e.skill) .. GREEN .. L.KEEP_LINE:format(where, e.useful, e.maxGray) .. "|r"
            if via and via.reach > e.maxGray then
                lines[#lines + 1] = GREEN .. L.ALSO_LINE:format(ItemName(via.item), via.reach) .. "|r"
            end
        elseif via then
            lines[#lines + 1] = Icon(e.skill)
                .. GREEN
                .. L.LATER_LINE:format(where, ItemName(via.item), via.reach)
                .. "|r"
        elseif e.maxGray > 0 then
            lines[#lines + 1] = Icon(e.skill) .. GRAY .. L.DONE_LINE:format(where, e.maxGray) .. "|r"
        else
            lines[#lines + 1] = Icon(e.skill) .. GRAY .. L.USED_LINE:format(where, e.total) .. "|r"
        end
    end
    if db.alts then
        local alts = ns.Materials.EvaluateAlts(itemID)
        for i = 1, math.min(#alts, MAX_ALT_LINES) do
            local a = alts[i]
            local text
            if a.useful > 0 then
                text = L.ALT_LINE:format(a.key, Name(a.skill), a.rank, a.useful)
            else
                text = L.ALT_LATER_LINE:format(a.key, Name(a.skill), a.rank, ItemName(a.via.item))
            end
            lines[#lines + 1] = Icon(a.skill) .. GOLD .. text .. "|r"
        end
        if #alts > MAX_ALT_LINES then
            lines[#lines + 1] = GOLD .. L.ALT_MORE:format(#alts - MAX_ALT_LINES) .. "|r"
        end
    end
    return lines
end

local function OnItemTooltip(tooltip, data)
    local db = ns.db
    if not (db and db.enabled and db.tooltip) then
        return
    end
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
        return
    end
    local itemID = data and data.id
    if itemID == nil or ns.IsSecret(itemID) or type(itemID) ~= "number" then
        return
    end
    local lines = module.Lines(itemID)
    if #lines == 0 then
        return
    end
    tooltip:AddLine(" ")
    tooltip:AddLine(L.TOOLTIP_HEADER, 1, 0.82, 0)
    for _, line in ipairs(lines) do
        tooltip:AddLine(line, 1, 1, 1, true)
    end
end

function module:OnEnable()
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
end
