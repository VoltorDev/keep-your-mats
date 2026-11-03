local _, ns = ...

-- Tabla de textos: si falta una clave, devuelve la propia clave en vez de nil
-- (un texto sin traducir se ve, pero no rompe el addon).
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L.ADDON_TITLE = "GuardaMateriales"
L.LOADED = "loaded. Type /guardamat for options."
L.SLASH_HELP = "Commands: /guardamat [config | debug | item <link or ID> | reset]"
L.ERR_COMBAT = "Not available in combat; try again when combat ends."
L.RESET_CONFIRM = "Type /guardamat reset confirm to restore the defaults."
L.RESET_DONE = "Settings restored to defaults."
L.COMPARTMENT_TOOLTIP = "Click to open the options."

L.OPT_ENABLED = "Enable"
L.OPT_ENABLED_TT = "Turns every mark, tooltip line and warning of this addon on or off."
L.OPT_MARK_BAGS = "Mark bags and bank"
L.OPT_MARK_BAGS_TT = "Shows the profession icon on materials that still level one of your professions."
L.OPT_SHOW_DONE = "Also mark materials you have outgrown"
L.OPT_SHOW_DONE_TT = "Shows a grey icon on materials of your professions whose recipes are all grey for you."
L.OPT_TOOLTIP = "Tooltip details"
L.OPT_TOOLTIP_TT = "Adds to the item tooltip how many recipes still level each profession and up to what skill."
L.OPT_SECONDARIES = "Count secondary professions"
L.OPT_SECONDARIES_TT = "Cooking, First Aid and Fishing count even if this character has not learned them."
L.OPT_ALTS = "Count my other characters"
L.OPT_ALTS_TT = "Materials that level a profession of another character of yours (same ruleset) are marked too. "
    .. "Each character is remembered once you log in with it."
L.OPT_AH_WARNING = "Warn when selling at the auction house"
L.OPT_AH_WARNING_TT = "Warns, with a message and a sound, when you place a material you need in the sell slot."

L.TOOLTIP_HEADER = "Profession material"
L.NOT_LEARNED = "%s (not learned)"
L.KEEP_LINE = "Keep: %s, %d recipes still level you (up to %d)"
L.DONE_LINE = "%s: no longer levels you (all grey from %d)"
L.USED_LINE = "%s: used in %d recipes"
L.ALT_LINE = "%s, %s %d: %d recipes level them"
L.ALT_MORE = "...and %d more"
L.AH_WARNING = "You need this for %s!"
L.AH_WARNING_CHAT = "%s still levels %s. Keep it instead of selling it."

L.ITEM_UNKNOWN = "Not a material of any profession you count."
L.ITEM_BAD = "Give an item link (shift-click) or a numeric item ID."

L.DEBUG_HEADER = "Diagnostics (paste this when reporting a problem):"

-- Nombres de profesión por skillLine (Datos/Recetas.lua usa las líneas base).
ns.PROFESSION_NAMES = {
    [40] = "Poisons",
    [129] = "First Aid",
    [164] = "Blacksmithing",
    [165] = "Leatherworking",
    [171] = "Alchemy",
    [182] = "Herbalism",
    [185] = "Cooking",
    [186] = "Mining",
    [197] = "Tailoring",
    [202] = "Engineering",
    [333] = "Enchanting",
    [356] = "Fishing",
    [393] = "Skinning",
}
