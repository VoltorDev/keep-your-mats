local _, ns = ...
local L = ns.L
local module = ns:NewModule("Plan")

-- Plan para subir cada profesión (las tuyas y las que piensas aprender): ventana `/guardamat plan`
-- y entrada en el menú del icono de la bolsa. La lógica está en Planner.lua; aquí se juntan los
-- datos del personaje (rango, recetas conocidas, inventario, precios) y se pinta.

local Planner = ns.Planner
local Prices = ns.Prices

local COLOR_CODES = {
    orange = "ffff8040",
    yellow = "ffffff00",
    green = "ff40bf40",
    gray = "ff808080",
}

local function Colored(color, text)
    return "|c" .. (COLOR_CODES[color] or "ffffffff") .. text .. "|r"
end

-- Recetas conocidas: lo que se vio con la ventana de la profesión abierta (C_TradeSkillUI) y, de
-- respaldo, el libro de hechizos.
local function IsKnown(spellID)
    local known = ns.charDB.known
    if known and known[spellID] then
        return true
    end
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, value = pcall(C_SpellBook.IsSpellKnown, spellID)
        return ok and ns.Readable(value, false) == true
    end
    return false
end

local function KnownSet(recipes)
    local set = {}
    for _, recipe in ipairs(recipes) do
        if IsKnown(recipe.s) then
            set[recipe.s] = true
        end
    end
    return set
end

local function HaveSet(recipes)
    local have = {}
    for _, recipe in ipairs(recipes) do
        for item in Planner.Reagents(recipe) do
            if have[item] == nil then
                have[item] = Prices.Have(item)
            end
        end
    end
    return have
end

local pendingNames = false
local function ItemName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if name then
        return name
    end
    C_Item.RequestLoadItemDataByID(itemID)
    pendingNames = true
    return L.PLAN_ITEM:format(itemID)
end

local function RecipeName(recipe)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(recipe.s)
    if name then
        return name
    end
    if recipe.o and recipe.o > 0 then
        return ItemName(recipe.o)
    end
    return L.PLAN_RECIPE:format(recipe.s)
end

-- Profesiones para las que se puede hacer un plan: las del perfil que tienen recetas.
function module.Skills()
    local list = {}
    for skill in pairs(ns.Materials.MyProfile()) do
        if ns.RECIPES[skill] and #ns.RECIPES[skill] > 0 then
            list[#list + 1] = skill
        end
    end
    table.sort(list, function(a, b)
        return (ns.PROFESSION_NAMES[a] or "") < (ns.PROFESSION_NAMES[b] or "")
    end)
    return list
end

-- Rango de partida, tope actual (0 si no se sabe) y final de los datos.
function module.Range(skill)
    local own = ns.professions and ns.professions[skill]
    local recipes = ns.RECIPES[skill] or {}
    local final = Planner.MaxRank(recipes)
    if own then
        return own.rank, own.maxRank, final
    end
    return 0, 0, final
end

-- Objetivo: "cap" (tope actual si lo hay) o "max" (hasta que ninguna receta suba), o un número.
function module.Target(skill, target)
    local rank, cap, final = module.Range(skill)
    if type(target) == "number" then
        return math.max(rank, math.min(target, final))
    end
    if target ~= "max" and cap > rank then
        return math.min(cap, final)
    end
    return final
end

function module.Build(skill, target)
    local recipes = ns.RECIPES[skill] or {}
    local rank = module.Range(skill)
    return Planner.Plan({
        recipes = recipes,
        from = rank,
        to = module.Target(skill, target),
        known = KnownSet(recipes),
        price = Prices.Get,
        have = HaveSet(recipes),
    })
end

local function SortedKeys(map)
    local keys = {}
    for key in pairs(map) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

-- Texto del plan, una línea por elemento (ventana y chat).
function module.Lines(skill, target)
    local lines = {}
    local function Add(text)
        lines[#lines + 1] = text
    end
    local rank, cap = module.Range(skill)
    local to = module.Target(skill, target)
    local name = ns.PROFESSION_NAMES[skill] or tostring(skill)
    Add(L.PLAN_HEADER:format(name, math.max(rank, 1), to))
    if rank >= to then
        Add(L.PLAN_NOTHING)
        return lines
    end
    local plan = module.Build(skill, target)
    if cap > 0 and to > cap then
        Add(L.PLAN_CAP_NOTE:format(cap))
    end
    Add(Prices.HasAuctionator() and L.PLAN_PRICES_AUCTIONATOR or L.PLAN_PRICES_REFERENCE)
    Add("")
    for _, segment in ipairs(plan.segments) do
        local text = L.PLAN_STEP:format(segment.from, segment.to, RecipeName(segment.recipe), segment.crafts)
        if segment.early then
            text = text .. " " .. L.PLAN_EARLY
        elseif segment.source == "learn" then
            text = text .. " " .. L.PLAN_LEARN
        end
        if segment.unknownCost then
            text = text .. " " .. L.PLAN_NO_PRICE_STEP
        end
        if segment.grind then
            text = text .. " " .. L.PLAN_GRIND
        end
        Add(Colored(segment.color, text))
    end
    if plan.gap then
        Add(L.PLAN_GAP:format(plan.gap))
    end
    Add("")
    Add(L.PLAN_MATERIALS)
    for _, item in ipairs(SortedKeys(plan.use)) do
        Add(L.PLAN_USE:format(ItemName(item), plan.use[item]))
    end
    for _, item in ipairs(SortedKeys(plan.craft)) do
        Add(L.PLAN_CRAFT:format(ItemName(item), plan.craft[item]))
    end
    for _, item in ipairs(SortedKeys(plan.buy)) do
        local unit = Prices.Get(item)
        if unit then
            Add(L.PLAN_BUY:format(ItemName(item), plan.buy[item], Planner.Money(unit)))
        else
            Add(L.PLAN_BUY_NO_PRICE:format(ItemName(item), plan.buy[item]))
        end
    end
    Add("")
    local missing = #SortedKeys(plan.noPrice)
    Add(L.PLAN_TOTAL:format(Planner.Money(plan.cost)) .. (missing > 0 and " " .. L.PLAN_MISSING:format(missing) or ""))
    Add(L.PLAN_ESTIMATE)
    return lines
end

-- Busca una profesión por su nombre (sin mayúsculas ni tildes de más) entre las del plan.
local function Normalize(text)
    text = text:lower()
    for from, to in pairs({ ["á"] = "a", ["é"] = "e", ["í"] = "i", ["ó"] = "o", ["ú"] = "u", ["ñ"] = "n" }) do
        text = text:gsub(from, to)
    end
    return text
end

function module.FindSkill(text)
    if not text or text == "" then
        return nil
    end
    local wanted = Normalize(text)
    for _, skill in ipairs(module.Skills()) do
        local name = Normalize(ns.PROFESSION_NAMES[skill] or "")
        if name:sub(1, #wanted) == wanted then
            return skill
        end
    end
end

-- Ventana ---------------------------------------------------------------------------------------

local frame
local state = { skill = nil, target = "cap" }

local function Refresh()
    if not (frame and frame:IsShown()) then
        return
    end
    local skills = module.Skills()
    if not state.skill or not ns.RECIPES[state.skill] then
        state.skill = skills[1]
    end
    for i, button in ipairs(frame.skillButtons) do
        button:Hide()
        frame.skillButtons[i] = button
    end
    for i, skill in ipairs(skills) do
        local button = frame.skillButtons[i]
        if not button then
            button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            button:SetSize(104, 22)
            local row, col = math.floor((i - 1) / 5), (i - 1) % 5
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", 12 + col * 108, -30 - row * 24)
            frame.skillButtons[i] = button
        end
        button:SetText(ns.PROFESSION_NAMES[skill] or tostring(skill))
        button:SetScript("OnClick", function()
            state.skill = skill
            Refresh()
        end)
        button:Show()
    end
    pendingNames = false
    local text
    if state.skill then
        text = table.concat(module.Lines(state.skill, state.target), "\n")
    else
        text = L.PLAN_NO_SKILLS
    end
    frame.text:SetText(text)
    frame.content:SetHeight((frame.text:GetStringHeight() or 0) + 20)
end
module.Refresh = Refresh

local function CreateWindow()
    frame = CreateFrame("Frame", "GuardaMaterialesPlanFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(560, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnShow", Refresh)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText(L.PLAN_TITLE)
    frame.skillButtons = {}

    local cap = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    cap:SetSize(130, 22)
    cap:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -82)
    cap:SetText(L.PLAN_TARGET_CAP)
    cap:SetScript("OnClick", function()
        state.target = "cap"
        Refresh()
    end)
    local max = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    max:SetSize(130, 22)
    max:SetPoint("LEFT", cap, "RIGHT", 6, 0)
    max:SetText(L.PLAN_TARGET_MAX)
    max:SetScript("OnClick", function()
        state.target = "max"
        Refresh()
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -110)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 12)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(510, 400)
    scroll:SetScrollChild(content)
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    text:SetWidth(505)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    frame.content, frame.text = content, text

    if UISpecialFrames then
        table.insert(UISpecialFrames, frame:GetName()) -- se cierra con Escape
    end
    frame:Hide()
end

function ns:OpenPlan(skill, target)
    if not frame then
        CreateWindow()
    end
    if skill then
        state.skill = skill
    end
    if target then
        state.target = target
    end
    frame:Show()
    Refresh()
end

-- Recetas conocidas: con la ventana de la profesión abierta, C_TradeSkillUI.GetRecipeInfo dice si
-- la conoces (learned). Se guarda por personaje para planificar con la ventana cerrada.
local function ScanKnown()
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeInfo) then
        return
    end
    local known = ns.charDB.known
    for skill in pairs(ns.professions or {}) do
        for _, recipe in ipairs(ns.RECIPES[skill] or {}) do
            local ok, info = pcall(C_TradeSkillUI.GetRecipeInfo, recipe.s)
            if ok and type(info) == "table" and ns.Readable(info.learned, false) == true then
                known[recipe.s] = true
            end
        end
    end
    Refresh()
end
module.ScanKnown = ScanKnown

local scanPending = false
local function ScheduleScan()
    if scanPending then
        return
    end
    scanPending = true
    C_Timer.After(0.5, function()
        scanPending = false
        ScanKnown()
    end)
end

local namesPending = false
local function OnItemData()
    if not pendingNames or namesPending or not (frame and frame:IsShown()) then
        return
    end
    namesPending = true
    C_Timer.After(0.3, function()
        namesPending = false
        Refresh()
    end)
end

function module:OnInitialize()
    if type(ns.charDB.known) ~= "table" then
        ns.charDB.known = {}
    end
end

function module:ApplySettings()
    Refresh()
end

function module:OnEnable()
    ns:RegisterEvent("TRADE_SKILL_LIST_UPDATE", ScheduleScan)
    ns:RegisterEvent("ITEM_DATA_LOAD_RESULT", OnItemData)
end
