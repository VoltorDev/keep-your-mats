local addonName, ns = ...
local L = ns.L
local module = ns:NewModule("Config")

-- Panel en Opciones > AddOns con la API nativa Settings (Blizzard_Settings_Shared).
-- Se registra en OnInitialize porque Settings.RegisterAddOnSetting escribe el valor por defecto
-- en la tabla si la clave es nil: hay que hacerlo DESPUÉS de cargar las SavedVariables.
function module:OnInitialize()
    local db = ns.db
    local category = Settings.RegisterVerticalLayoutCategory(L.ADDON_TITLE)

    local function OnSettingChanged()
        ns:ApplySettings()
    end

    -- Todas las opciones son casillas: { clave de db, sufijo del ajuste, texto, ayuda }.
    local checkboxes = {
        { "enabled", "Enabled", L.OPT_ENABLED, L.OPT_ENABLED_TT },
        { "markBags", "MarkBags", L.OPT_MARK_BAGS, L.OPT_MARK_BAGS_TT },
        { "showDone", "ShowDone", L.OPT_SHOW_DONE, L.OPT_SHOW_DONE_TT },
        { "tooltip", "Tooltip", L.OPT_TOOLTIP, L.OPT_TOOLTIP_TT },
        { "secondaries", "Secondaries", L.OPT_SECONDARIES, L.OPT_SECONDARIES_TT },
        { "alts", "Alts", L.OPT_ALTS, L.OPT_ALTS_TT },
        { "ahWarning", "AHWarning", L.OPT_AH_WARNING, L.OPT_AH_WARNING_TT },
    }
    for _, option in ipairs(checkboxes) do
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
    end

    Settings.RegisterAddOnCategory(category)
    ns.settingsCategory = category
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
