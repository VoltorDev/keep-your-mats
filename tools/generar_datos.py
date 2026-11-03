"""Genera Datos/Recetas.lua a partir de las tablas DB2 del cliente de WoW Forever.

Fuente: wago.tools, producto `wowf` (las tablas se leen del propio cliente de Forever).
Tablas: SkillLine, SkillLineAbility, SpellReagents, TradeSkillCategory e ItemSparse.

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
TABLES = ["SkillLine", "SkillLineAbility", "SpellReagents", "TradeSkillCategory", "ItemSparse"]

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
        if used:
            recipes[skill] += 1

    icons = {p: int(skill_lines[p]["SpellIconFileID"]) for p in PROFESSIONS if p in skill_lines}
    return materials, parents, icons, recipes, skipped_sod


def to_lua(materials, parents, icons, build):
    today = datetime.date.today().strftime("%d-%m-%Y")
    out = io.StringIO()
    out.write("local _, ns = ...\n\n")
    out.write(f"-- GENERADO por tools/generar_datos.py con las tablas DB2 de Forever (wago.tools, {PRODUCT}\n")
    out.write(f"-- build {build}, {today}). No se edita a mano: se regenera.\n")
    out.write("-- MATERIALS[itemID][skillLine] = umbrales grises de las recetas que usan ese material.\n\n")
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
    materials, parents, icons, recipes, skipped = build_data(tables)

    args.salida.parent.mkdir(parents=True, exist_ok=True)
    args.salida.write_text(to_lua(materials, parents, icons, build), encoding="utf-8", newline="\n")

    print(f"build {build}: {len(materials)} materiales; recetas de Season of Discovery descartadas: {skipped}")
    for p in sorted(recipes):
        print(f"  {p}: {recipes[p]} recetas")
    if not materials:
        print("ERROR: sin materiales; revisa la build o el formato de las tablas", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
