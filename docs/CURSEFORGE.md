# Publicar GuardaMateriales en CurseForge — kit

Preparado el 03-11-2026. Paquete: `mods\wow\dist\GuardaMateriales-1.0.0.zip` (generado con
`python -I mods\herramientas\empaquetar-wow.py mods\wow\GuardaMateriales --version 1.0.0`; pasa
`comprobar-paquete.py --juego wow`: solo `.toc`, `.lua`, `LICENSE` y `CHANGELOG.md`, sin ejecutables).

**Estado honesto:** pasa las seis comprobaciones fuera del juego (128 tests, 03-11-2026). Las marcas de bolsas y
banco, el tooltip y el aviso de la subasta están **sin ver en el cliente**: Forever todavía no ha salido
([PLAN.md](../PLAN.md)). Solo carga en Forever (`AllowLoadGameType: camelot, forever`). Recomendación (juicio
propio): subirlo como **Beta** y pasarlo a Release cuando se vea en el juego el 05-11.

**Subido el 04-11-2026 hacia las 07:00 (por Claude, con la sesión de Nico en el navegador de la app, por orden suya):** proyecto «Keep Your Mats», n.º **1782810** (`https://authors.curseforge.com/#/projects/1782810`), estado «New» hasta que lo apruebe un moderador. Fichero «Keep Your Mats 1.0.0», tipo Release (subido como Beta y pasado a Release a las 08:00 del mismo día, por orden de Nico: «que lo descargue quien quiera»), versiones Forever 1.60.1, publicación automática al aprobarse, changelog del kit. Licencia MIT, distribución a terceros permitida (WowUp y otros gestores), comentarios activados, avatar `docs/avatar-curseforge.png` (lo dibuja `mods/herramientas/avatares_curseforge.py`). Falta: capturas (solo en el juego) y verlo en el cliente.

## Campos del formulario

| Campo | Valor |
|---|---|
| Juego | World of Warcraft |
| Nombre del proyecto | **Decisión de Nico.** En inglés y sin el nombre del juego. Propuesta: `Keep Your Mats`. La carpeta sigue siendo `GuardaMateriales` |
| Resumen | `Marks the materials in your bags and bank that still level your professions, so you keep them instead of selling them.` |
| Categoría principal | Professions (secundarias: Bags & Inventory, Tooltip). Comprobar los nombres exactos en el formulario |
| Licencia | MIT (está en `LICENSE`) |
| Donaciones | Ko-fi, usuario `thevoltor` (General › Donation Method). Puesto el 05-11-2026; sale como botón «Donate» en la página, y además el botón «Buy me a coffee» bajo la introducción de la descripción (con `width`: CurseForge quita el estilo de altura y sin él sale a 580 px). Nunca dentro del addon: la política de Blizzard prohíbe pedir donaciones en la interfaz |
| Versión de juego | **Forever 1.60.1** (Interface 16001). No marcar retail ni Classic |
| Tipo de fichero | Beta (ver arriba) |
| Avatar | 400×400, sin imágenes con copyright (nada de iconos de Blizzard). **Falta** |
| Capturas | **Faltan**: bolsa con las marcas, tooltip de un material y el aviso rojo en la subasta. Solo en el juego |

## Descripción (pegar en el editor de CurseForge)

```markdown
**Keep Your Mats** marks, in your bags and bank, the materials that can still level one of your professions, so
you keep them instead of vendoring them or posting them on the Auction House.

Made for **World of Warcraft: Forever**.

<p align="center"><a href="https://ko-fi.com/thevoltor"><img src="https://storage.ko-fi.com/cdn/kofi6.png?v=6" alt="Buy Me a Coffee at ko-fi.com" width="145" height="36"></a><br><em>Free and always will be. If it helps you, you can buy me a coffee.</em></p>

## Features

- **Bag and bank marks**: the profession icon in the top-right corner of every material that can still give you
  a skill point.
- **Tooltip**: for each of your professions, how many recipes still level you with that material and up to which
  skill, or that it no longer does ("all grey from 210").
- **Auction House warning**: when you put up a material you still need, a red text over the item, a chat message
  and a sound. It never blocks anything: posting is still your call.
- **Professions counted**: the ones your character has (including Mining for smelting, Poisons for rogues and the
  camp recipes of Herbalism, Skinning and Fishing) and, by default, Cooking, First Aid and Fishing even if not
  learned yet.
- **Professions you plan to learn**: pick, per character, primary professions you do not have yet; their
  materials are marked as if you had them at skill 1.
- **Your other characters** (optional, off by default): also mark what levels a profession of an alt with the
  same realm rules (Hardcore apart).

A material is useful if a recipe that uses it is still below grey for your skill, or if it makes an intermediate
that will be (linen cloth → bolt of linen cloth, ore → bar). All the profession's recipes in the Forever client
count, learned or not.

## Settings

- Click the backpack portrait → "GuardaMateriales" for quick checkboxes and "Professions I plan to learn".
- Full panel: Esc → Options → AddOns → GuardaMateriales, or the addon compartment next to the minimap.
- `/guardamat` opens the panel; `/guardamat item <link or ID>` prints the tooltip text; `/guardamat debug` shows
  diagnostics.

## Data

Recipe data comes from the Forever client's own tables (DB2 files via wago.tools, product `wowf`) and is
regenerated after each patch. Season of Discovery recipes that the client still carries but Forever does not offer
are left out.

## Bugs

Please report with the output of `/guardamat debug` and, if there is an error, the BugSack export.

---

**Español.** Marca en bolsas y banco los materiales que aún te suben alguna profesión, te dice en el tooltip
cuántas recetas te quedan y te avisa si los pones en la subasta. Cuenta las secundarias y las profesiones que
piensas aprender. Solo para WoW: Forever. Comando: `/guardamat`.
```

## Changelog del fichero 1.0.0

```markdown
First public release, for World of Warcraft: Forever.

- Profession icon on bag and bank materials that can still level you.
- Tooltip with the recipes each material still levels, per profession.
- Warning when you put a still-useful material on the Auction House (never blocks).
- Secondary professions and "professions I plan to learn" per character.
- Optional marks for what your other characters can still level.
```

## Pasos que solo puede hacer Nico

1. Crear el proyecto en `https://authors.curseforge.com/#/projects/create/choose-game` con los campos de arriba y
   subir el avatar.
2. Subir `GuardaMateriales-1.0.0.zip`, marcar solo Forever 1.60.1 y pegar el changelog.
3. **Plazo:** moderación de 08:00 a 15:00 (hora de España); para que se vea el día del lanzamiento tiene que estar
   aprobado antes del **04-11-2026 a las 15:00**.
4. Pasarle a Claude el número de proyecto si se quiere publicar luego por GitHub Actions (`X-Curse-Project-ID`).

Antes de pasarlo a Release: verlo en Forever (`/reload`, BugSack limpio, marcas, tooltip y aviso de subasta).

**1.0.1, nombre en inglés (05-11-2026, por orden de Nico: «Nombres en inglés siempre»):** el `## Title` del TOC pasa a «Keep Your Mats» y el zip a `mods\wow\dist\KeepYourMats-1.0.1.zip`. Es el zip publicado anterior con solo el título y la versión cambiados (los cambios sin publicar del repo no entran); la carpeta interna sigue siendo `GuardaMateriales`, así que las SavedVariables y la junction de `Interface\AddOns` no cambian. Subido como Release con las mismas versiones de juego; pasa por moderación. Desde ahora `empaquetar-wow.py` nombra el zip por el `## Title`.

**1.1.0 (06-11-2026, por Claude con la sesión de Nico en Chrome, por orden suya: «Sí, súbelas»):** fichero «Keep Your Mats 1.1.0», `mods\wow\dist\KeepYourMats-1.1.0.zip`, tipo **Release**, versiones Forever 1.60.1, publicación automática al aprobarse. Changelog en inglés que nombra lo nuevo: plan para subir profesiones (`/guardamat plan`), recetas casi grises, materiales intermedios, «Professions I plan to learn», ajustes en el menú de la bolsa; además el nombre dentro del juego (enUS) pasa a «Keep Your Mats». Pasa las comprobaciones fuera del juego (06-11-2026); **sin probar en el cliente**.
