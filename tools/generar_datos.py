"""Genera Datos/Recetas.lua a partir de las tablas DB2 del cliente de WoW Forever.

Fuente: wago.tools, producto `wowf` (las tablas se leen del propio cliente de Forever).
Tablas: SkillLine, SkillLineAbility, SpellReagents, SpellEffect, TradeSkillCategory, ItemSparse,
ItemEffect e ItemXItemEffect.

Salidas: Datos/Recetas.lua (materiales, para las marcas) y Datos/Planes.lua (recetas completas,
para el plan de subida: dificultad, reactivos con cantidad, objeto fabricado y receta de objeto).

Uso:
    python -I -B tools/generar_datos.py                 # última build de wowf
    python -I -B tools/generar_datos.py --build 1.60.1.70753
    python -I -B tools/generar_datos.py --cache C:/ruta/csv   # reutiliza CSV ya descargados

Reglas:
- Cuenta toda receta de una profesión con reactivos, salvo las de las categorías
  «SEASON OF DISCOVERY», que el cliente arrastra pero Forever no ofrece.
- Para cada material y profesión guarda el umbral gris (TrivialSkillLineRankHigh) de cada
  receta que lo usa: con la habilidad actual del personaje se sabe cuántas aún le suben.
- Un reactivo que no existe en ItemSparse no puede estar en las bolsas: se descarta.
- Plan de subida (Datos/Planes.lua): por receta, su umbral amarillo (TrivialSkillLineRankLow) y
  gris (TrivialSkillLineRankHigh), si se aprende sola con la profesión (AcquireMethod 1), el objeto
  que la enseña si lo hay (ItemEffect con TriggerType 6, directo o por un hechizo de aprender), lo
  que fabrica y cuántos, y sus reactivos con cantidad. Precio de tienda (BuyPrice) de cada reactivo.
  La DB2 de Forever no trae el rango con el que se aprende cada receta (MinSkillLineRank vale 1 en
  casi todas): no se guarda.
- Materiales intermedios: si una receta convierte un material en otro que también es material
  (Paño de lino -> Rollo de paño de lino), se guarda en PRODUCES. Así el paño cuenta mientras el
  rollo te siga sirviendo, aunque la receta del rollo ya sea gris.
"""

import argparse
import csv
import datetime
import io
import json
import pathlib
import sys
import urllib.request

WAGO = "https://wago.tools"
PRODUCT = "wowf"
TABLES = [
    "SkillLine",
    "SkillLineAbility",
    "SpellReagents",
    "SpellEffect",
    "TradeSkillCategory",
    "ItemSparse",
    "ItemEffect",
    "ItemXItemEffect",
]
CREATE_ITEM = 24  # SpellEffect.Effect de las recetas que fabrican un objeto
LEARN_SPELL = 36  # SpellEffect.Effect de los hechizos que enseñan otro (EffectTriggerSpell)
TRIGGER_LEARN = 6  # ItemEffect.TriggerType de los objetos que enseñan un hechizo al usarlos

# Líneas de habilidad que se tratan como profesión. "secondary": se vigila aunque el personaje
# no la haya aprendido (Cocina, Primeros auxilios y Pesca). Venenos es de pícaro y solo cuenta si
# el personaje tiene la habilidad.
PROFESSIONS = {
    164: {"secondary": False},  # Herrería
    165: {"secondary": False},  # Peletería
    171: {"secondary": False},  # Alquimia
    182: {"secondary": False},  # Herboristería (recetas de campamento)
    186: {"secondary": False},  # Minería (fundición)
    197: {"secondary": False},  # Sastrería
    202: {"secondary": False},  # Ingeniería
    333: {"secondary": False},  # Encantamiento
    393: {"secondary": False},  # Desuello (recetas de campamento)
    129: {"secondary": True},  # Primeros auxilios
    185: {"secondary": True},  # Cocina
    356: {"secondary": True},  # Pesca (recetas de campamento)
    40: {"secondary": False},  # Venenos (pícaro)
}

EXCLUDED_CATEGORY_NAME = "SEASON OF DISCOVERY"


def latest_build():
    with urllib.request.urlopen(f"{WAGO}/api/builds", timeout=60) as response:
        builds = json.load(response)
    return builds[PRODUCT][0]["version"]


def load_table(name, build, cache):
    path = cache / f"{name}.csv" if cache else None
    if path and path.exists():
        text = path.read_text(encoding="utf-8")
    else:
        url = f"{WAGO}/db2/{name}/csv?build={build}"
        with urllib.request.urlopen(url, timeout=300) as response:
            text = response.read().decode("utf-8")
        if path:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
    return list(csv.DictReader(io.StringIO(text)))


def build_data(tables):
    skill_lines = {int(r["ID"]): r for r in tables["SkillLine"]}
    categories = {int(r["ID"]): r for r in tables["TradeSkillCategory"]}
    reagents_by_spell = {int(r["SpellID"]): r for r in tables["SpellReagents"]}
    items = {int(r["ID"]) for r in tables["ItemSparse"]}
    outputs = {}  # spell -> objetos que fabrica
    for r in tables["SpellEffect"]:
        item = int(r["EffectItemType"])
        if int(r["Effect"]) == CREATE_ITEM and item:
            outputs.setdefault(int(r["SpellID"]), set()).add(item)

    excluded = {
        cid for cid, r in categories.items() if EXCLUDED_CATEGORY_NAME in (r["Name_lang"] or "").upper()
    }

    # Subhabilidades de Forever (p. ej. 2938 «Blacksmithing» con padre 164) → profesión base.
    parents = {}
    for sid, r in skill_lines.items():
        parent = int(r["ParentSkillLineID"])
        if parent in PROFESSIONS:
            parents[sid] = parent

    materials = {}  # itemID -> skillLine -> [umbral gris por receta]
    made = []  # (material, skillLine, objeto fabricado)
    recipes = {p: 0 for p in PROFESSIONS}
    skipped_sod = 0
    for row in tables["SkillLineAbility"]:
        skill = int(row["SkillLine"])
        if skill not in PROFESSIONS:
            continue
        spell = int(row["Spell"])
        reagents = reagents_by_spell.get(spell)
        if not reagents:
            continue
        if int(row["TradeSkillCategoryID"]) in excluded:
            skipped_sod += 1
            continue
        gray = int(row["TrivialSkillLineRankHigh"])
        used = False
        for i in range(8):
            item = int(reagents[f"Reagent_{i}"])
            if item == 0 or item not in items:
                continue
            materials.setdefault(item, {}).setdefault(skill, []).append(gray)
            used = True
            for output in outputs.get(spell, ()):
                if output != item:
                    made.append((item, skill, output))
        if used:
            recipes[skill] += 1

    # Solo interesan los productos que a su vez son material de alguna profesión.
    produces = {}  # itemID -> skillLine -> {objetos fabricados que son material}
    for item, skill, output in made:
        if output in materials:
            produces.setdefault(item, {}).setdefault(skill, set()).add(output)

    icons = {p: int(skill_lines[p]["SpellIconFileID"]) for p in PROFESSIONS if p in skill_lines}
    return materials, produces, parents, icons, recipes, skipped_sod


def build_plans(tables):
    """Recetas completas por profesión base, para el planificador de subida."""
    categories = {int(r["ID"]): r for r in tables["TradeSkillCategory"]}
    excluded = {
        cid for cid, r in categories.items() if EXCLUDED_CATEGORY_NAME in (r["Name_lang"] or "").upper()
    }
    reagents_by_spell = {int(r["SpellID"]): r for r in tables["SpellReagents"]}
    sparse = {int(r["ID"]): r for r in tables["ItemSparse"]}
    created = {}  # spell -> (objeto, cantidad)
    learns = {}  # hechizo de aprender -> hechizos que enseña
    for r in tables["SpellEffect"]:
        effect = int(r["Effect"])
        spell = int(r["SpellID"])
        if effect == CREATE_ITEM and int(r["EffectItemType"]) and spell not in created:
            qty = max(1, int(round(float(r["EffectBasePointsF"] or 1))))
            created[spell] = (int(r["EffectItemType"]), qty)
        elif effect == LEARN_SPELL and int(r["EffectTriggerSpell"]):
            learns.setdefault(spell, set()).add(int(r["EffectTriggerSpell"]))
    effect_item = {int(r["ItemEffectID"]): int(r["ItemID"]) for r in tables["ItemXItemEffect"]}
    taught_by = {}  # receta -> objeto que la enseña (el de menor ID si hay varios)
    for r in tables["ItemEffect"]:
        if int(r["TriggerType"]) != TRIGGER_LEARN:
            continue
        item = effect_item.get(int(r["ID"]))
        if not item:
            continue
        spell = int(r["SpellID"])
        for taught in {spell} | learns.get(spell, set()):
            if taught not in taught_by or item < taught_by[taught]:
                taught_by[taught] = item

    plans = {p: [] for p in PROFESSIONS}
    prices = {}
    seen = set()
    for row in tables["SkillLineAbility"]:
        skill = int(row["SkillLine"])
        spell = int(row["Spell"])
        if skill not in PROFESSIONS or (skill, spell) in seen:
            continue
        reagents = reagents_by_spell.get(spell)
        if not reagents or int(row["TradeSkillCategoryID"]) in excluded:
            continue
        yellow = int(row["TrivialSkillLineRankLow"])
        gray = int(row["TrivialSkillLineRankHigh"])
        if gray <= 0:
            continue  # sin datos de dificultad: no sirve para planificar
        parts = []
        for i in range(8):
            item = int(reagents[f"Reagent_{i}"])
            count = int(reagents[f"ReagentCount_{i}"])
            if item == 0 or count <= 0 or item not in sparse:
                continue
            parts.append((item, count))
            buy = int(sparse[item]["BuyPrice"] or 0)
            if buy > 0:
                prices[item] = buy
        if not parts:
            continue
        seen.add((skill, spell))
        output, qty = created.get(spell, (0, 1))
        plans[skill].append(
            {
                "s": spell,
                "y": min(yellow, gray) if yellow > 0 else gray,
                "g": gray,
                "a": int(row["AcquireMethod"]) == 1,
                "t": taught_by.get(spell, 0),
                "o": output,
                "q": qty,
                "r": parts,
            }
        )
    for skill in plans:
        plans[skill].sort(key=lambda p: (p["y"], p["g"], p["s"]))
    return plans, prices


def plans_to_lua(plans, prices, build):
    today = datetime.date.today().strftime("%d-%m-%Y")
    out = io.StringIO()
    out.write("local _, ns = ...\n\n")
    out.write(f"-- GENERADO por tools/generar_datos.py con las tablas DB2 de Forever (wago.tools, {PRODUCT}\n")
    out.write(f"-- build {build}, {today}). No se edita a mano: se regenera.\n")
    out.write("-- RECIPES[skillLine] = { { s = hechizo, y = umbral amarillo, g = umbral gris, a = se aprende\n")
    out.write("-- con la profesión, t = objeto que la enseña (0 si ninguno), o = objeto fabricado, q = cuántos,\n")
    out.write("-- r = { objeto, cantidad, objeto, cantidad... } } }. BUY_PRICE[objeto] = precio de tienda (cobre).\n\n")
    out.write("ns.RECIPES = {\n")
    for skill in sorted(plans):
        out.write(f"    [{skill}] = {{\n")
        for p in plans[skill]:
            r = ", ".join(f"{item}, {count}" for item, count in p["r"])
            a = "true" if p["a"] else "false"
            out.write(
                f"        {{ s = {p['s']}, y = {p['y']}, g = {p['g']}, a = {a}, t = {p['t']}, "
                f"o = {p['o']}, q = {p['q']}, r = {{ {r} }} }},\n"
            )
        out.write("    },\n")
    out.write("}\n\n")
    out.write("ns.BUY_PRICE = {\n")
    for item in sorted(prices):
        out.write(f"    [{item}] = {prices[item]},\n")
    out.write("}\n")
    return out.getvalue()


def to_lua(materials, produces, parents, icons, build):
    today = datetime.date.today().strftime("%d-%m-%Y")
    out = io.StringIO()
    out.write("local _, ns = ...\n\n")
    out.write(f"-- GENERADO por tools/generar_datos.py con las tablas DB2 de Forever (wago.tools, {PRODUCT}\n")
    out.write(f"-- build {build}, {today}). No se edita a mano: se regenera.\n")
    out.write("-- MATERIALS[itemID][skillLine] = umbrales grises de las recetas que usan ese material.\n")
    out.write("-- PRODUCES[itemID][skillLine] = materiales que esa profesión fabrica con él.\n\n")
    out.write(f'ns.DATA_BUILD = "{build}"\n\n')
    out.write("ns.PROFESSIONS = {\n")
    for p in sorted(PROFESSIONS):
        secondary = "true" if PROFESSIONS[p]["secondary"] else "false"
        out.write(f"    [{p}] = {{ icon = {icons.get(p, 0)}, secondary = {secondary} }},\n")
    out.write("}\n\n")
    out.write("ns.SKILL_PARENT = {\n")
    for child in sorted(parents):
        out.write(f"    [{child}] = {parents[child]},\n")
    out.write("}\n\n")
    out.write("ns.MATERIALS = {\n")
    for item in sorted(materials):
        parts = []
        for skill in sorted(materials[item]):
            grays = ", ".join(str(g) for g in sorted(materials[item][skill], reverse=True))
            parts.append(f"[{skill}] = {{ {grays} }}")
        out.write(f"    [{item}] = {{ {', '.join(parts)} }},\n")
    out.write("}\n\n")
    out.write("ns.PRODUCES = {\n")
    for item in sorted(produces):
        parts = []
        for skill in sorted(produces[item]):
            made = ", ".join(str(o) for o in sorted(produces[item][skill]))
            parts.append(f"[{skill}] = {{ {made} }}")
        out.write(f"    [{item}] = {{ {', '.join(parts)} }},\n")
    out.write("}\n")
    return out.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--build", help="versión de wowf (por defecto, la última que indexa wago.tools)")
    parser.add_argument("--cache", type=pathlib.Path, help="carpeta donde leer o guardar los CSV")
    parser.add_argument(
        "--salida",
        type=pathlib.Path,
        default=pathlib.Path(__file__).resolve().parent.parent / "Datos" / "Recetas.lua",
    )
    args = parser.parse_args()

    build = args.build or latest_build()
    tables = {name: load_table(name, build, args.cache) for name in TABLES}
    materials, produces, parents, icons, recipes, skipped = build_data(tables)

    args.salida.parent.mkdir(parents=True, exist_ok=True)
    args.salida.write_text(to_lua(materials, produces, parents, icons, build), encoding="utf-8", newline="\n")
    plans, prices = build_plans(tables)
    planes = args.salida.parent / "Planes.lua"
    planes.write_text(plans_to_lua(plans, prices, build), encoding="utf-8", newline="\n")
    print(f"Planes.lua: {sum(len(v) for v in plans.values())} recetas con dificultad, {len(prices)} precios de tienda")

    print(
        f"build {build}: {len(materials)} materiales, {len(produces)} con productos intermedios; "
        f"recetas de Season of Discovery descartadas: {skipped}"
    )
    for p in sorted(recipes):
        print(f"  {p}: {recipes[p]} recetas")
    if not materials:
        print("ERROR: sin materiales; revisa la build o el formato de las tablas", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
