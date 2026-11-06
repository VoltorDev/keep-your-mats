local _, ns = ...

-- Tabla de textos: si falta una clave, devuelve la propia clave en vez de nil
-- (un texto sin traducir se ve, pero no rompe el addon).
local L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
ns.L = L

L.ADDON_TITLE = "Keep Your Mats"
L.LOADED = "loaded. Settings: click the bag icon, the addons button by the minimap, or Options > AddOns."
L.SLASH_HELP = "Commands: /guardamat [config | plan [chat] [profession] [up to | max] | "
    .. "debug | item <link or ID> | reset]"
L.ERR_COMBAT = "Not available in combat; try again when combat ends."
L.RESET_CONFIRM = "Type /guardamat reset confirm to restore the defaults."
L.RESET_DONE = "Settings restored to defaults."
L.COMPARTMENT_TOOLTIP = "Click to open the options."

L.SECTION_MARKS = "What you see"
L.SECTION_COUNTS = "What counts"
L.SECTION_AUCTION = "Auction house"
L.SECTION_PLANNED = "Professions I plan to learn"
L.OPT_PLANNED_TT = "Marks its materials as if this character had it at skill 1. Only for this character."
L.MENU_MORE = "All settings..."

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
L.PLANNED = "%s (planned)"
L.KEEP_LINE = "Keep: %s, %d recipes still level you (up to %d)"
L.LATER_LINE = "Keep: %s, to make %s, which helps you up to %d"
L.ALSO_LINE = "  and to make %s, which helps you up to %d"
L.DONE_LINE = "%s: no longer levels you (all grey from %d)"
L.USED_LINE = "%s: used in %d recipes"
L.ALT_LINE = "%s, %s: %d recipes level them"
L.ALT_LATER_LINE = "%s, %s: to make %s"
L.ALT_MORE = "...and %d more"
L.AH_WARNING = "You need this for %s!"
L.AH_WARNING_CHAT = "%s still levels %s. Keep it instead of selling it."

L.ITEM_UNKNOWN = "Not a material of any profession you count."
L.ITEM_BAD = "Give an item link (shift-click) or a numeric item ID."

L.MENU_PLAN = "Leveling plan..."
L.PLAN_TITLE = "Keep Your Mats: leveling plan"
L.PLAN_TARGET_CAP = "Up to my current cap"
L.PLAN_TARGET_MAX = "Up to the end"
L.PLAN_HEADER = "%s: from %d to %d"
L.PLAN_NOTHING = "Nothing to plan: you are already there."
L.PLAN_CAP_NOTE = "Your cap now is %d: train the next rank to go past it."
L.PLAN_PRICES_AUCTIONATOR = "Prices: Auctionator's auction price (or a vendor's, if cheaper)."
L.PLAN_PRICES_REFERENCE = "Prices: shop price from the game data, only as a reference. Install Auctionator "
    .. "and scan the auction house for real prices."
L.PLAN_STEP = "%d-%d  %s x%d"
L.PLAN_LEARN = "(learn it: trainer or another source)"
L.PLAN_GRIND =
    "|cffff7f00(many crafts per point: this range is usually levelled with plans or patterns you do not know yet)|r"
L.PLAN_EARLY = "(learn it if your trainer already teaches it; if not, you need another recipe here)"
L.PLAN_NO_PRICE_STEP = "(no price)"
L.PLAN_GAP = "No recipe levels you from %d with what is known: you may need a recipe from an item."
L.PLAN_MATERIALS = "Materials:"
L.PLAN_USE = "  %s: %d from your bags and bank"
L.PLAN_CRAFT = "  %s: make %d yourself (cheaper than buying)"
L.PLAN_BUY = "  %s: buy %d (%s each)"
L.PLAN_BUY_NO_PRICE = "  %s: buy %d (no price)"
L.PLAN_TOTAL = "Estimated cost: %s"
L.PLAN_MISSING = "(+%d materials without a price)"
L.PLAN_ESTIMATE = "Estimate: Vanilla skill-up chances; recipes you do not know count from when they turn yellow."
L.PLAN_ITEM = "item %d"
L.PLAN_RECIPE = "recipe %d"
L.PLAN_NO_SKILLS = 'No profession to plan: learn one or tick one under "Professions I plan to learn".'
L.PLAN_UNKNOWN_SKILL = "Unknown profession: %s"
L.MONEY_GOLD = "g"
L.MONEY_SILVER = "s"
L.MONEY_COPPER = "c"

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
