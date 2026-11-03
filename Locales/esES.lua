local _, ns = ...

local locale = GetLocale()
if locale ~= "esES" and locale ~= "esMX" then
    return
end

local L = ns.L

L.LOADED = "cargado. Ajustes: clic en el icono de la bolsa, en el botón de addons del minimapa o en Opciones > AddOns."
L.SLASH_HELP = "Comandos: /guardamat [config | debug | item <enlace o ID> | reset]"
L.ERR_COMBAT = "No disponible en combate; inténtalo al salir de él."
L.RESET_CONFIRM = "Escribe /guardamat reset confirmar para volver a los valores por defecto."
L.RESET_DONE = "Opciones restauradas a los valores por defecto."
L.COMPARTMENT_TOOLTIP = "Clic para abrir las opciones."

L.SECTION_MARKS = "Qué se ve"
L.SECTION_COUNTS = "Qué cuenta"
L.SECTION_AUCTION = "Subasta"
L.SECTION_PLANNED = "Profesiones que pienso aprender"
L.OPT_PLANNED_TT = "Marca sus materiales como si este personaje la tuviera a nivel 1. Solo para este personaje."
L.MENU_MORE = "Todos los ajustes..."

L.OPT_ENABLED = "Activar"
L.OPT_ENABLED_TT = "Enciende o apaga todas las marcas, líneas del tooltip y avisos del addon."
L.OPT_MARK_BAGS = "Marcar en bolsas y banco"
L.OPT_MARK_BAGS_TT = "Pone el icono de la profesión en los materiales que aún te suben alguna profesión."
L.OPT_SHOW_DONE = "Marcar también los que ya no te suben"
L.OPT_SHOW_DONE_TT = "Pone un icono gris en los materiales de tus profesiones cuyas recetas ya son todas grises "
    .. "para ti."
L.OPT_TOOLTIP = "Detalle en el tooltip"
L.OPT_TOOLTIP_TT = "Añade al tooltip del objeto cuántas recetas aún te suben cada profesión y hasta qué nivel."
L.OPT_SECONDARIES = "Contar las profesiones secundarias"
L.OPT_SECONDARIES_TT = "Cocina, Primeros auxilios y Pesca cuentan aunque este personaje no las haya aprendido."
L.OPT_ALTS = "Contar mis otros personajes"
L.OPT_ALTS_TT = "Se marcan también los materiales que suben una profesión de otro de tus personajes (mismas "
    .. "reglas de reino). Cada personaje se recuerda en cuanto entras con él."
L.OPT_AH_WARNING = "Avisar al vender en la subasta"
L.OPT_AH_WARNING_TT = "Avisa con un mensaje y un sonido al poner en venta un material que te sirve."

L.TOOLTIP_HEADER = "Material de profesión"
L.NOT_LEARNED = "%s (sin aprender)"
L.PLANNED = "%s (pienso aprenderla)"
L.KEEP_LINE = "Guárdalo: %s, te suben %d recetas (hasta %d)"
L.LATER_LINE = "Guárdalo: %s, para fabricar %s, que te sirve hasta %d"
L.ALSO_LINE = "  y para fabricar %s, que te sirve hasta %d"
L.DONE_LINE = "%s: ya no te sube (todo gris desde %d)"
L.USED_LINE = "%s: se usa en %d recetas"
L.ALT_LINE = "%s, %s: le suben %d recetas"
L.ALT_LATER_LINE = "%s, %s: para fabricar %s"
L.ALT_MORE = "...y %d más"
L.AH_WARNING = "¡Lo necesitas para %s!"
L.AH_WARNING_CHAT = "%s aún te sube %s. Guárdalo en vez de venderlo."

L.ITEM_UNKNOWN = "No es material de ninguna profesión que cuentes."
L.ITEM_BAD = "Indica un enlace de objeto (mayús + clic) o un ID numérico."

L.DEBUG_HEADER = "Diagnóstico (pégalo al informar de un problema):"

-- Nombres de profesión por skillLine.
ns.PROFESSION_NAMES[40] = "Venenos"
ns.PROFESSION_NAMES[129] = "Primeros auxilios"
ns.PROFESSION_NAMES[164] = "Herrería"
ns.PROFESSION_NAMES[165] = "Peletería"
ns.PROFESSION_NAMES[171] = "Alquimia"
ns.PROFESSION_NAMES[182] = "Herboristería"
ns.PROFESSION_NAMES[185] = "Cocina"
ns.PROFESSION_NAMES[186] = "Minería"
ns.PROFESSION_NAMES[197] = "Sastrería"
ns.PROFESSION_NAMES[202] = "Ingeniería"
ns.PROFESSION_NAMES[333] = "Encantamiento"
ns.PROFESSION_NAMES[356] = "Pesca"
ns.PROFESSION_NAMES[393] = "Desuello"
