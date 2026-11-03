# Plan — GuardaMateriales

Único plan vivo del addon. Actualizado el 03-11-2026.

## Objetivo

Que Nico no venda en la subasta materiales que le sirven para subir las profesiones de su personaje
(y las secundarias), porque en Forever el progreso horizontal pesa más. Pedido el 03-11-2026, la víspera
del lanzamiento.

## Estado

| Pieza | Implementado | Verificado |
|---|---|---|
| Datos de recetas: `tools/generar_datos.py` con las DB2 de Forever (wago.tools, `wowf` 1.60.1.70753, 03-11-2026). 528 materiales en 13 profesiones; 287 recetas de Season of Discovery descartadas por su categoría «SEASON OF DISCOVERY» | Sí | Tests de forma del fichero y de materiales clásicos conocidos. **Sin contrastar en el cliente** que cada receta exista de verdad en Forever |
| Profesiones del personaje: `GetProfessions` + `GetProfessionInfo` (subhabilidades 2937-2948 → profesión base) y `C_SkillInfo.GetSkillLineInfoByID` para lo que no esté ahí (Venenos) | Sí | Tests con el cliente simulado. **Sin probar en el cliente** qué `skillLine` devuelve `GetProfessionInfo` (base o subhabilidad: se aceptan las dos) |
| Marca en bolsas (ContainerFrame1..N y bolsa combinada) y banco (`BankPanel`) | Sí | Tests. Puntos de enganche leídos en la interfaz de Forever (build 70291). **Sin ver en el cliente** |
| Tooltip de objeto (`TooltipDataProcessor`) | Sí | Tests en inglés y español. **Sin ver en el cliente** |
| Aviso al poner en venta en la subasta (`ItemSellFrame`/`CommoditiesSellFrame:SetItem`) | Sí | Tests. **Sin ver en el cliente** dónde queda el texto rojo |
| Materiales intermedios (03-11-2026, pedido de Nico: «que marque las que me servirán más adelante»). Las recetas de nivel superior ya contaban; faltaban los intermedios: el paño de lino salía «ya no te sube» para un sastre de 60 aunque el rollo le sirve hasta 115. `PRODUCES` (SpellEffect, efecto 24 «crear objeto»): 172 materiales con intermedio; solo cuenta si tienes la profesión que lo fabrica; ciclos cortados | Sí | Tests con datos inventados (cadena, ciclo, otra profesión, alts) y con los reales (paño de lino → rollo para un sastre de 60). **Sin ver en el cliente** |
| Ajustes dentro del juego (03-11-2026, pedido de Nico: «menú de ajustes dentro del juego, no por comando»): panel de Opciones > AddOns por secciones y entrada en el menú del icono de la bolsa (`Menu.ModifyMenu` con `MENU_CONTAINER_FRAME` y `MENU_CONTAINER_FRAME_COMBINED`) con las 7 casillas y «Todos los ajustes...». Los comandos quedan como extra | Sí | Tests del menú y del panel (casilla → opción guardada, aplicada y reflejada en el panel; sin abrir en combate). Etiquetas de menú leídas en la interfaz de Forever (build 70291). **Sin ver en el cliente** |
| Opciones (7 casillas) y `/guardamat` (`item`, `debug`, `reset`) | Sí | Tests |
| Comprobaciones fuera del juego | — | Las seis pasan (03-11-2026): luacheck, StyLua, LuaLS, `api_forever` (3 avisos de secretos revisados: GUID y clase se filtran, `CHAT_MSG_SKILL` no se lee), 124 tests en Lua 5.1 y LuaJIT, sin XML |
| Enlazado en `_forever_\Interface\AddOns` | Sí | Junction creada el 03-11-2026 |

## Pendiente

1. **Primera prueba en el cliente (05-11-2026)**. Reiniciar el cliente la primera vez (addon nuevo).
   - `/guardamat debug`: que las líneas `GetProfessions[...]` y `Profesiones:` coincidan con el libro de
     profesiones. Si `Profesiones: ninguna` con profesiones aprendidas, el `skillLine` que devuelve el
     cliente no es ni la base ni la subhabilidad: copiar la línea para corregir `SKILL_PARENT`.
   - Con un personaje recién creado, abrir las bolsas: el material de inicio de Cocina o Primeros
     auxilios (carne, paño de lino) debe llevar el icono de la profesión.
   - Pasar el ratón por un material: líneas «Material de profesión». Comprobar una cifra con la
     ventana de la profesión (que el «hasta N» coincida con cuándo se pone gris la receta).
   - Subir un punto y ver que la marca se actualiza sola (sin `/reload`).
   - En la subasta, poner un material en la ranura de venta: texto rojo, mensaje y sonido. Mirar que el
     texto no tape nada; si lo tapa, mover el anclaje en `Modules/AuctionHouse.lua`.
   - Abrir el banco y ver las marcas en sus huecos.
   - Clic en el icono de la mochila: entrada «GuardaMateriales» con las casillas; quitar «Marcar en
     bolsas y banco» y ver que las marcas desaparecen; «Todos los ajustes...» abre el panel con sus tres
     secciones.
   - Con Sastrería por encima de 50 y paño de lino en la bolsa: marca y línea «para fabricar Rollo de
     paño de lino».
2. **Regenerar los datos tras cada parche** que toque recetas (`python -I -B tools/generar_datos.py`) y
   repasar el recuento por profesión que imprime.
3. **Ideas, sin decidir**: lista de objetos a ignorar a mano; aviso también al vender al mercader;
   marcas en las bolsas de SegundaPantalla o de addons de bolsas (Baganator, etc.) si Nico los usa;
   refinar con las recetas aprendidas al abrir la ventana de la profesión (`C_TradeSkillUI`).

## Decisiones

- Se cuentan las recetas no aprendidas: el addon avisa de lo que te servirá para subir, no solo de lo
  que ya puedes fabricar. El tooltip enseña el detalle para decidir.
- Una receta con umbral gris 0 (3 en los datos) cuenta como uso pero no como subida.
- Los alts solo cuentan con el mismo ruleset: entre Hardcore y normal no se pasan objetos.
