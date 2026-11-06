local addonName, ns = ...
local L = ns.L
local module = ns:NewModule("Config")

-- Panel en Opciones > AddOns con la API nativa Settings (Blizzard_Settings_Shared), por secciones.
-- Se registra en OnInitialize porque Settings.RegisterAddOnSetting escribe el valor por defecto
-- en la tabla si la clave es nil: hay que hacerlo DESPUÉS de cargar las SavedVariables.
-- Todas las opciones son casillas: { clave, sufijo del ajuste, texto, ayuda, tabla }. La tabla es
-- "char" para las de este personaje (profesiones que piensa aprender) y la de cuenta si falta.

local Materials = ns.Materials

-- Una clave a false por profesión prevista: así la SV por personaje nace completa y
-- RegisterAddOnSetting no tiene que escribir nada.
for _, skill in ipairs(Materials.Plannable()) do
    ns.CHAR_DEFAULTS.planned[Materials.PlannedKey(skill)] = false
end

local function Layout()
    local planned = {}
    for _, skill in ipairs(Materials.Plannable()) do
        planned[#planned + 1] = {
            Materials.PlannedKey(skill),
            "Planned" .. skill,
            ns.PROFESSION_NAMES[skill] or tostring(skill),
            L.OPT_PLANNED_TT,
            "char",
        }
    end
    return {
        {
            title = L.SECTION_MARKS,
            { "enabled", "Enabled", L.OPT_ENABLED, L.OPT_ENABLED_TT },
            { "markBags", "MarkBags", L.OPT_MARK_BAGS, L.OPT_MARK_BAGS_TT },
            { "showDone", "ShowDone", L.OPT_SHOW_DONE, L.OPT_SHOW_DONE_TT },
            { "tooltip", "Tooltip", L.OPT_TOOLTIP, L.OPT_TOOLTIP_TT },
        },
        {
            title = L.SECTION_COUNTS,
            { "secondaries", "Secondaries", L.OPT_SECONDARIES, L.OPT_SECONDARIES_TT },
            { "alts", "Alts", L.OPT_ALTS, L.OPT_ALTS_TT },
        },
        -- En el menú de la bolsa va en su propio submenú: son nueve casillas.
        { title = L.SECTION_PLANNED, submenu = true, unpack(planned) },
        {
            title = L.SECTION_AUCTION,
            { "ahWarning", "AHWarning", L.OPT_AH_WARNING, L.OPT_AH_WARNING_TT },
        },
    }
end
module.Layout = Layout

local function Table(option)
    return option[5] == "char" and ns.charDB.planned or ns.db
end

local function Default(option)
    if option[5] == "char" then
        return false
    end
    return ns.DEFAULTS[option[1]]
end

function module:OnInitialize()
    local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)

    local function OnSettingChanged()
        ns:ApplySettings()
    end

    ns.settings = {}
    for _, section in ipairs(Layout()) do
        if layout then
            layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(section.title))
        end
        for _, option in ipairs(section) do
            local key, suffix, label, help = option[1], option[2], option[3], option[4]
            local setting = Settings.RegisterAddOnSetting(
                category,
                addonName .. "_" .. suffix,
                key,
                Table(option),
                Settings.VarType.Boolean,
                label,
                Default(option)
            )
            setting:SetValueChangedCallback(OnSettingChanged)
            Settings.CreateCheckbox(category, setting, help)
            ns.settings[key] = setting
        end
    end

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
end

-- Cambia una opción desde fuera del panel (menú de las bolsas): pasa por el ajuste para que el
-- panel muestre el valor nuevo y se apliquen los cambios.
function ns:ToggleOption(key)
    local setting = self.settings[key]
    setting:SetValue(not setting:GetValue())
end

-- Menú del icono de la bolsa (clic en el retrato de la mochila o de la bolsa combinada): las
-- opciones en casillas y un acceso al panel completo. Menu.ModifyMenu es el punto de extensión
-- oficial; la entrada se añade cada vez que Blizzard genera el menú.
local BAG_MENUS = { "MENU_CONTAINER_FRAME", "MENU_CONTAINER_FRAME_COMBINED" }

local function AddCheckboxes(description, section)
    for _, option in ipairs(section) do
        local key = option[1]
        description:CreateCheckbox(option[3], function()
            return ns.settings[key]:GetValue() == true
        end, function()
            ns:ToggleOption(key)
        end)
    end
end

function module.AddBagMenu(_, rootDescription)
    rootDescription:CreateDivider()
    local sub = rootDescription:CreateButton(L.ADDON_TITLE)
    for _, section in ipairs(Layout()) do
        if section.submenu then
            AddCheckboxes(sub:CreateButton(section.title), section)
        else
            sub:CreateTitle(section.title)
            AddCheckboxes(sub, section)
        end
    end
    sub:CreateDivider()
    sub:CreateButton(L.MENU_PLAN, function()
        ns:OpenPlan()
    end)
    sub:CreateButton(L.MENU_MORE, function()
        ns:OpenSettings()
    end)
end

function module:OnEnable()
    for _, tag in ipairs(BAG_MENUS) do
        Menu.ModifyMenu(tag, module.AddBagMenu)
    end
end

-- Abrir el panel está restringido en combate (C_SettingsUtil.OpenSettingsPanel lleva HasRestrictions).
function ns:OpenSettings()
    if InCombatLockdown() then
        self:Print(L.ERR_COMBAT)
        return
    end
    Settings.OpenToCategory(self.settingsCategory:GetID())
end

-- Compartimento de addons (botón del minimapa). Los nombres coinciden con el TOC.
-- El cliente llama a la función de clic con (addonName, buttonName) y a las de ratón
-- con (addonName, menuButtonFrame).
function GuardaMateriales_OnAddonCompartmentClick()
    ns:OpenSettings()
end

function GuardaMateriales_OnAddonCompartmentEnter(_, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    GameTooltip:SetText(L.ADDON_TITLE)
    GameTooltip:AddLine(L.COMPARTMENT_TOOLTIP, 1, 1, 1)
    GameTooltip:Show()
end

function GuardaMateriales_OnAddonCompartmentLeave()
    GameTooltip:Hide()
end
