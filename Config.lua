local addonName, ns = ...
local L = ns.L
local module = ns:NewModule("Config")

-- Panel en Opciones > AddOns con la API nativa Settings (Blizzard_Settings_Shared), por secciones.
-- Se registra en OnInitialize porque Settings.RegisterAddOnSetting escribe el valor por defecto
-- en la tabla si la clave es nil: hay que hacerlo DESPUÉS de cargar las SavedVariables.
-- Todas las opciones son casillas: { clave de db, sufijo del ajuste, texto, ayuda }; un texto suelto
-- abre una sección.
local function Layout()
    return {
        L.SECTION_MARKS,
        { "enabled", "Enabled", L.OPT_ENABLED, L.OPT_ENABLED_TT },
        { "markBags", "MarkBags", L.OPT_MARK_BAGS, L.OPT_MARK_BAGS_TT },
        { "showDone", "ShowDone", L.OPT_SHOW_DONE, L.OPT_SHOW_DONE_TT },
        { "tooltip", "Tooltip", L.OPT_TOOLTIP, L.OPT_TOOLTIP_TT },
        L.SECTION_COUNTS,
        { "secondaries", "Secondaries", L.OPT_SECONDARIES, L.OPT_SECONDARIES_TT },
        { "alts", "Alts", L.OPT_ALTS, L.OPT_ALTS_TT },
        L.SECTION_AUCTION,
        { "ahWarning", "AHWarning", L.OPT_AH_WARNING, L.OPT_AH_WARNING_TT },
    }
end
module.Layout = Layout

function module:OnInitialize()
    local db = ns.db
    local category, layout = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)

    local function OnSettingChanged()
        ns:ApplySettings()
    end

    ns.settings = {}
    for _, option in ipairs(Layout()) do
        if type(option) == "string" then
            if layout then
                layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(option))
            end
        else
            local key, suffix, label, help = option[1], option[2], option[3], option[4]
            local setting = Settings.RegisterAddOnSetting(
                category,
                addonName .. "_" .. suffix,
                key,
                db,
                Settings.VarType.Boolean,
                label,
                ns.DEFAULTS[key]
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

function module.AddBagMenu(_, rootDescription)
    rootDescription:CreateDivider()
    local sub = rootDescription:CreateButton(L.ADDON_TITLE)
    for _, option in ipairs(Layout()) do
        if type(option) == "string" then
            sub:CreateTitle(option)
        else
            local key = option[1]
            sub:CreateCheckbox(option[3], function()
                return ns.db[key] == true
            end, function()
                ns:ToggleOption(key)
            end)
        end
    end
    sub:CreateDivider()
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
