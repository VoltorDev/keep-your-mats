# GuardaMateriales

Addon para World of Warcraft: Forever. Marca en las bolsas y el banco los materiales que aún te sirven
para subir tus profesiones, para que los guardes en vez de venderlos en la subasta.

## Qué hace

- **Marca en bolsas y banco**: el icono de la profesión en la esquina superior derecha del hueco, solo
  en los materiales con los que todavía puedes subir algún punto.
- **Tooltip**: en cada material, para cada profesión tuya, cuántas recetas aún te suben y hasta qué
  nivel, o que ya no te sube («todo gris desde 210»).
- **Aviso en la subasta**: al poner en venta un material que te sirve, aparece un texto rojo sobre el
  objeto, un mensaje en el chat y un sonido. No bloquea nada: publicar sigue siendo cosa tuya.
- **Profesiones que cuenta**: las que tiene el personaje (incluida Minería por la fundición, Venenos en
  pícaros y las recetas de campamento de Herboristería, Desuello y Pesca) y, por defecto, las
  secundarias Cocina, Primeros auxilios y Pesca aunque no estén aprendidas.
- **Profesiones que piensas aprender**: eliges, por personaje, las primarias que aún no tienes y quieres
  subir; sus materiales se marcan como si la tuvieras a nivel 1, y el tooltip lo indica («pienso
  aprenderla»).
- **Otros personajes** (opción, apagada por defecto): marca también lo que le sube una profesión a
  otro de tus personajes con las mismas reglas de reino (Hardcore aparte). Cada personaje se recuerda al
  entrar con él.

Un material «te sirve» si alguna receta que lo usa sigue por debajo de gris para tu nivel actual, o si
con él fabricas un intermedio que te servirá más adelante (paño de lino → rollo de paño de lino, mena →
barra): el paño se guarda aunque la receta del rollo ya sea gris, mientras el rollo te siga subiendo. Se
cuentan todas las recetas de la profesión que trae el cliente de Forever, aprendidas o no y de cualquier
nivel, menos las de Season of Discovery, que el cliente arrastra pero Forever no ofrece.

## Ajustes dentro del juego

- **Icono de la bolsa**: clic en el retrato de la mochila (o de la bolsa combinada) → «GuardaMateriales»,
  con todas las opciones en casillas, el submenú «Profesiones que pienso aprender» y «Todos los
  ajustes...».
- **Panel completo**: Esc → Opciones → AddOns → GuardaMateriales, por secciones (Qué se ve, Qué
  cuenta, Profesiones que pienso aprender, Subasta). También se abre desde el botón de addons junto al minimapa.

## Comandos (opcionales)

- `/guardamat` (o `/guardamateriales`) abre el panel.
- `/guardamat item <enlace o ID>` escribe en el chat lo mismo que el tooltip.
- `/guardamat debug` muestra el diagnóstico, con las profesiones tal como las devuelve el cliente.
- `/guardamat reset confirmar` restaura las opciones (los personajes recordados se conservan).

## Datos de recetas

`Datos/Recetas.lua` lo genera `tools/generar_datos.py` a partir de las tablas DB2 del propio cliente
de Forever (wago.tools, producto `wowf`: SkillLine, SkillLineAbility, SpellReagents,
SpellEffect, TradeSkillCategory e ItemSparse). Tras un parche que cambie recetas:

```powershell
python -I -B tools/generar_datos.py
```

Sin `--build` usa la última build de `wowf` que indexa wago.tools. La build de los datos sale en
`/guardamat debug`.

## Informar de un problema

Abre un issue con el texto de `/guardamat debug` y, si hay error, la exportación de BugSack.

## Desarrollo

Proyecto creado con la plantilla de la skill `wow-addons`. Comprobaciones fuera del juego (luacheck,
StyLua, LuaLS, API real de Forever, tests en Lua 5.1 y XML):

```powershell
C:\Users\Nico\.claude\skills\wow-addons\scripts\verificar-addon.ps1 -Carpeta .
```

Tests solos: `python tools/probar_addon.py . --ambos`. El cliente simulado propio del addon
(profesiones, bolsas, banco, tooltip y subasta) está en `tests/support/cliente.lua`.

## Licencia

MIT (ver `LICENSE`).
