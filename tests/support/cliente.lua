-- Cliente simulado de Forever con lo que usa GuardaMateriales encima del de la plantilla
-- (wow_env): profesiones, habilidades, bolsas, banco, tooltip de objeto y subasta.
-- Mismo uso que wow_env: Cliente.new(opts) y Cliente.boot(toc, opts). Opciones propias:
--   opts.professions = { { skillLine = 2938, rank = 87, maxRank = 150, name = "Blacksmithing" }, ... }
--       (en el orden de GetProfessions: hueco 1 y 2 primarias, 3 Primeros auxilios...; usa false
--       para dejar un hueco vacío)
--   opts.skills = { [40] = { rank = 120, maxRank = 300 } }  (C_SkillInfo.GetSkillLineInfoByID)
--   opts.bags = { [0] = { [1] = itemID, ... }, ... }  (contenido de las bolsas y del banco)
--   opts.itemNames = { [itemID] = "Nombre" }  (lo que ya está en la caché del cliente)
-- El controlador se obtiene con Cliente.fake(env) (ver más abajo).
local WowEnv = require("wow_env")

local M = {}
for k, v in pairs(WowEnv) do
    M[k] = v
end

local BAG_SLOTS = 4
local controllers = setmetatable({}, { __mode = "k" })

-- Controlador del cliente simulado de un env creado con M.new o M.boot.
function M.fake(env)
    return controllers[env]
end

-- Marco de bolsa de Blizzard reducido a lo que se engancha: UpdateItems y EnumerateValidItems.
local function newContainer(env, name, bagID)
    local frame = env.CreateFrame("Frame", name, env.UIParent)
    frame._buttons = {}
    for slot = 1, BAG_SLOTS do
        local button = env.CreateFrame("Button", nil, frame)
        button._bag, button._slot = bagID, slot
        function button:GetBagID()
            return self._bag
        end
        function button:GetID()
            return self._slot
        end
        frame._buttons[slot] = button
    end
    function frame:UpdateItems() end
    function frame:EnumerateValidItems()
        local i = 0
        return function()
            i = i + 1
            local b = self._buttons[i]
            if b then
                return i, b
            end
        end
    end
    frame:Hide()
    return frame
end

local function newBankPanel(env, tabID)
    local panel = env.CreateFrame("Frame", "BankPanel", env.UIParent)
    panel._buttons = {}
    for slot = 1, BAG_SLOTS do
        local button = env.CreateFrame("Button", nil, panel)
        button._tab, button._slot = tabID, slot
        function button:GetBankTabID()
            return self._tab
        end
        function button:GetContainerSlotID()
            return self._slot
        end
        panel._buttons[slot] = button
    end
    function panel:GenerateItemSlotsForSelectedTab() end
    function panel:RefreshAllItemsForSelectedTab() end
    function panel:EnumerateValidItems()
        local i = 0
        return function()
            i = i + 1
            return self._buttons[i]
        end
    end
    panel:Hide()
    return panel
end

function M.new(opts)
    opts = opts or {}
    local state = {
        professions = opts.professions or {},
        skills = opts.skills or {},
        bags = opts.bags or {},
        postCalls = {},
        onLoaded = {},
        sounds = {},
        itemNames = opts.itemNames or {},
        itemRequests = {},
        counts = opts.counts or {}, -- objetos en bolsas y banco (C_Item.GetItemCount)
        spellNames = opts.spellNames or {},
        knownSpells = opts.knownSpells or {}, -- C_SpellBook.IsSpellKnown
        recipeInfo = opts.recipeInfo or {}, -- C_TradeSkillUI.GetRecipeInfo (ventana abierta)
        menus = {},
        headers = {},
    }

    local function itemAt(bag, slot)
        return (state.bags[bag] or {})[slot]
    end

    -- ItemLocation simplificado: una tabla { bag, slot }.
    local globals = {
        GetProfessions = function()
            local out, n = {}, 0
            for i, p in ipairs(state.professions) do
                if p then
                    out[i] = i
                end
                n = i
            end
            return unpack(out, 1, n)
        end,
        GetProfessionInfo = function(index)
            local p = state.professions[index]
            if p then
                return p.name or "?", p.icon or 1, p.rank, p.maxRank, 2, 0, p.skillLine, 0, 0, 0, p.name
            end
        end,
        C_SkillInfo = {
            GetSkillLineInfoByID = function(id)
                local s = state.skills[id]
                if s then
                    return {
                        skillID = id,
                        name = s.name or "?",
                        isHeader = false,
                        rank = s.rank,
                        maxRank = s.maxRank,
                    }
                end
            end,
        },
        C_Container = {
            GetContainerItemID = function(bag, slot)
                return itemAt(bag, slot)
            end,
        },
        C_Item = {
            DoesItemExist = function(loc)
                return loc ~= nil and itemAt(loc.bag, loc.slot) ~= nil
            end,
            GetItemID = function(loc)
                return itemAt(loc.bag, loc.slot)
            end,
            GetItemNameByID = function(id)
                return state.itemNames[id]
            end,
            GetItemCount = function(id)
                return state.counts[id] or 0
            end,
            RequestLoadItemDataByID = function(id)
                state.itemRequests[#state.itemRequests + 1] = id
            end,
            GetItemLink = function(loc)
                local id = itemAt(loc.bag, loc.slot)
                return id and ("|Hitem:" .. id .. "|h[Objeto " .. id .. "]|h")
            end,
        },
        C_Spell = {
            GetSpellName = function(id)
                return state.spellNames[id]
            end,
        },
        C_SpellBook = {
            IsSpellKnown = function(id)
                return state.knownSpells[id] == true
            end,
        },
        C_TradeSkillUI = {
            GetRecipeInfo = function(id)
                return state.recipeInfo[id]
            end,
        },
        UISpecialFrames = {},
        TooltipDataProcessor = {
            AddTooltipPostCall = function(dataType, fn)
                state.postCalls[#state.postCalls + 1] = { type = dataType, fn = fn }
            end,
        },
        EventUtil = {
            ContinueOnAddOnLoaded = function(addon, fn)
                state.onLoaded[#state.onLoaded + 1] = { addon = addon, fn = fn }
            end,
        },
        Menu = {
            ModifyMenu = function(tag, fn)
                state.menus[tag] = state.menus[tag] or {}
                table.insert(state.menus[tag], fn)
            end,
        },
        CreateSettingsListSectionHeaderInitializer = function(name)
            return { header = name }
        end,
        PlaySound = function(kit)
            state.sounds[#state.sounds + 1] = kit
        end,
        SOUNDKIT = { RAID_WARNING = 8959 },
        UnitClass = function()
            return "Guerrero", "WARRIOR", 1
        end,
        NUM_CONTAINER_FRAMES = 2,
    }
    for k, v in pairs(opts.globals or {}) do
        globals[k] = v
    end
    local envOpts = {}
    for k, v in pairs(opts) do
        envOpts[k] = v
    end
    envOpts.globals = globals

    local env = WowEnv.new(envOpts)
    -- Settings devuelve además el layout de la categoría; aquí solo guarda las cabeceras.
    local register = env.Settings.RegisterVerticalLayoutCategory
    env.Settings.RegisterVerticalLayoutCategory = function(name)
        local layout = {}
        function layout:AddInitializer(initializer)
            state.headers[#state.headers + 1] = initializer.header
        end
        return register(name), layout
    end
    env.Enum.TooltipDataType = { Item = 0, Spell = 1 }
    env:_NewWidget("GameTooltip", "ItemRefTooltip", env.UIParent):Hide()
    newContainer(env, "ContainerFrame1", 0)
    newContainer(env, "ContainerFrame2", 1)
    newContainer(env, "ContainerFrameCombinedBags", 0)
    newBankPanel(env, 6)

    -- Controlador para los tests (fuera de env: el addon no debe verlo como global).
    local fake = { state = state }
    controllers[env] = fake

    function fake.SetProfessions(list)
        state.professions = list
    end
    function fake.SetSkills(skills)
        state.skills = skills
    end
    function fake.SetCounts(counts)
        state.counts = counts
    end
    function fake.SetRecipeInfo(info)
        state.recipeInfo = info
    end
    function fake.SetBags(bags)
        state.bags = bags
    end
    -- Muestra un tooltip de objeto: limpia las líneas previas y llama a los post-calls de Item.
    function fake.ShowItemTooltip(itemID, tooltip)
        tooltip = tooltip or env.GameTooltip
        tooltip._calls.AddLine = nil
        for _, pc in ipairs(state.postCalls) do
            if pc.type == env.Enum.TooltipDataType.Item then
                pc.fn(tooltip, { type = 0, id = itemID })
            end
        end
        local lines = {}
        for _, call in ipairs(tooltip:Calls("AddLine")) do
            lines[#lines + 1] = call[1]
        end
        return lines
    end
    -- Botón de bolsa (ContainerFrameN) o del banco.
    function fake.Button(frameName, slot)
        return env[frameName]._buttons[slot]
    end
    -- Icono pintado en el botón, o nil si no hay marca visible.
    function fake.Mark(button)
        local mark = button.guardaMaterialesMark
        if mark and mark:IsShown() then
            return mark
        end
    end
    -- Carga la interfaz de la subasta (LoadOnDemand) y ejecuta los callbacks pendientes.
    function fake.LoadAuctionHouse()
        local ah = env.CreateFrame("Frame", "AuctionHouseFrame", env.UIParent)
        for _, key in ipairs({ "ItemSellFrame", "CommoditiesSellFrame" }) do
            local frame = env.CreateFrame("Frame", nil, ah)
            frame.ItemDisplay = env.CreateFrame("Button", nil, frame)
            function frame:SetItem(itemLocation)
                self._item = itemLocation
            end
            ah[key] = frame
        end
        for _, pending in ipairs(state.onLoaded) do
            if pending.addon == "Blizzard_AuctionHouseUI" then
                pending.fn()
            end
        end
        return ah
    end
    function fake.Location(bag, slot)
        return { bag = bag, slot = slot }
    end
    function fake.Sounds()
        return state.sounds
    end
    function fake.ItemRequests()
        return state.itemRequests
    end
    function fake.SettingsHeaders()
        return state.headers
    end
    -- Genera un menú de Blizzard con su etiqueta y devuelve lo que han añadido los addons:
    -- { kind = "divider" | "button" | "title" | "checkbox", text, children, onClick, isSelected, setSelected }.
    local function newDescription()
        local d = { entries = {} }
        local function add(entry)
            d.entries[#d.entries + 1] = entry
            return entry
        end
        function d:CreateDivider()
            add({ kind = "divider" })
        end
        function d:CreateTitle(text)
            add({ kind = "title", text = text })
        end
        function d:CreateButton(text, onClick)
            local child = newDescription()
            add({ kind = "button", text = text, onClick = onClick, children = child.entries })
            return child
        end
        function d:CreateCheckbox(text, isSelected, setSelected)
            add({ kind = "checkbox", text = text, isSelected = isSelected, setSelected = setSelected })
        end
        return d
    end
    function fake.OpenMenu(tag)
        local root = newDescription()
        for _, fn in ipairs(state.menus[tag] or {}) do
            fn(env.UIParent, root, nil)
        end
        return root.entries
    end

    return env
end

function M.boot(tocPath, opts)
    local env = M.new(opts)
    local ns, reason = env:LoadToc(tocPath)
    if not ns then
        error("el addon no carga en este cliente: " .. tostring(reason), 2)
    end
    env:Login()
    return env, ns
end

return M
