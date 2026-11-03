-- luacheck para un addon de WoW Forever (Lua 5.1).
-- Que cada API exista DE VERDAD en Forever lo comprueba api_forever.py; aquí se declara
-- qué globales lee el addon, para que una errata en un nombre salte como "undefined variable".
std = "lua51"
max_line_length = 120
exclude_files = { "Libs/", ".release/", "tools/", ".luacheckrc" }

ignore = {
    "212/self", -- self sin usar en métodos
}

-- Globales que el addon CREA o modifica.
globals = {
    "GuardaMaterialesDB",
    "GuardaMaterialesCharDB",
    "SLASH_GUARDAMATERIALES1",
    "SLASH_GUARDAMATERIALES2",
    "SlashCmdList",
    "GuardaMateriales_OnAddonCompartmentClick",
    "GuardaMateriales_OnAddonCompartmentEnter",
    "GuardaMateriales_OnAddonCompartmentLeave",
}

-- API de WoW que el addon lee. Añade aquí cada global nueva que uses.
read_globals = {
    "AbbreviateNumbers",
    "AuctionHouseFrame",
    "C_AddOns",
    "C_GameRules",
    "C_RestrictedActions",
    "C_Secrets",
    "Constants",
    "CreateFrame",
    "Enum",
    "GameTooltip",
    "GetAddOnMetadata",
    "GetBuildInfo",
    "GetLocale",
    "GetNormalizedRealmName",
    "GetRealmName",
    "InCombatLockdown",
    "LE_EXPANSION_CLASSIC",
    "LE_EXPANSION_LEVEL_CURRENT",
    "MinimalSliderWithSteppersMixin",
    "RegionalUniqueNamesEnabled",
    "Settings",
    "UIParent",
    "UnitGUID",
    "UnitHealth",
    "UnitHealthMax",
    "UnitName",
    "UnitNameUnmodified",
    "issecretvalue",
    "time",
    "wipe",
    "WOW_PROJECT_ID",
    "WOW_PROJECT_MAINLINE",
    "WOW_PROJECT_CLASSIC",
    "WOW_PROJECT_CAMELOT",
    "WOW_PROJECT_FOREVER",
    "BankPanel",
    "C_Container",
    "C_Item",
    "C_SkillInfo",
    "C_Timer",
    "ContainerFrameCombinedBags",
    "EventUtil",
    "GetProfessionInfo",
    "GetProfessions",
    "ItemRefTooltip",
    "NUM_CONTAINER_FRAMES",
    "PlaySound",
    "SOUNDKIT",
    "TooltipDataProcessor",
    "UnitClass",
    "_G",
    "hooksecurefunc",
}

-- Tests fuera del juego (busted o scripts/probar_addon.py): Lua 5.1 estándar + API de busted.
-- Datos/Recetas.lua lo genera tools/generar_datos.py: una línea por material.
files["Datos/**/*.lua"] = { max_line_length = false }

files["tests/**/*.lua"] = {
    std = "lua51+busted",
    globals = { "string" }, -- secret_mock parchea string.format
}
