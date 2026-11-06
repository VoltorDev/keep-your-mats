# Plan — GuardaMateriales

Único plan vivo del addon. Actualizado el 05-11-2026.

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
| Profesiones que pienso aprender (03-11-2026, aceptado por Nico): una casilla por primaria (9) y por personaje (`GuardaMaterialesCharDB.planned`, claves `p<skillLine>`), en su sección del panel y en un submenú del icono de la bolsa. Cuentan con rango 0 y se copian a `db.chars` para que los alts las vean | Sí | Tests: perfil, submenú → marca y tooltip, alt previsto, español. **Sin ver en el cliente** |
| Opciones (7 casillas) y `/guardamat` (`item`, `debug`, `reset`) | Sí | Tests |
| Plan para subir (05-11-2026, pedido de Nico: réplica gratis de las guías de profesiones de Zygor). Datos: `Datos/Planes.lua` (2231 recetas con umbral amarillo y gris, reactivos con cantidad, objeto fabricado, si se aprende sola y qué objeto la enseña; 513 precios de tienda), del mismo generador y build 70753. `Planner.lua` (camino más barato punto a punto: coste esperado = coste / probabilidad de Vanilla; descuenta bolsas y banco; intermedios fabricados si salen más baratos, un nivel; recetas no conocidas desde su amarillo y, para rellenar huecos, antes con aviso; las de objeto solo si se conocen). `Prices.lua` (Auctionator subasta/mercader, firma leída en su código v341; si no, BuyPrice de referencia). `Modules/Plan.lua` (ventana con botón por profesión y «Hasta mi tope actual»/«Hasta el final», `/guardamat plan [chat] [profesión] [hasta\|max]`, entrada en el menú de la bolsa, recetas conocidas con `C_TradeSkillUI.GetRecipeInfo` al abrir la profesión y `C_SpellBook.IsSpellKnown` de respaldo) | Sí | 24 tests (`tests/plan_spec.lua`): dificultad, camino más barato, inventario, sin precio, sin Auctionator y con él, recetas por aprender y de objeto, hueco, intermedio, ventana, comando, menú y escaneo de conocidas; con los datos reales, Sastrería 1→150 sin huecos. **Sin ver en el cliente** |
| Ajuste tras revisar el plan con datos reales (05-11-2026): las recetas con menos de un 20 % de probabilidad de subir (`Planner.MIN_CHANCE`) solo se usan si no hay otra; los tramos con más de 3 fabricaciones por punto (`GRIND_PER_POINT`) llevan el aviso «aquí suele subirse con planos o patrones». Medido con precios de referencia: Herrería 267→285 sigue pidiendo ~3700 barras de mitril y Peletería ~3700 de cuero grueso, porque con solo recetas de entrenador no hay alternativa; en Vanilla ese tramo se sube con planos y patrones de objeto | Sí | 1 test nuevo (153 en total); el aviso se ve en el texto del plan |
| Comprobaciones fuera del juego | — | Las seis pasan (05-11-2026): luacheck, StyLua, LuaLS, `api_forever` (3 avisos de secretos revisados: GUID y clase se filtran, `CHAT_MSG_SKILL` no se lee), 152 tests en Lua 5.1 y LuaJIT, sin XML |
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
     bolsas y banco» y ver que las marcas desaparecen; «Todos los ajustes...» abre el panel con sus cuatro
     secciones.
   - En el submenú «Profesiones que pienso aprender», marcar una que no tengas y ver que sus materiales
     se marcan y el tooltip dice «(pienso aprenderla)». Aprenderla después: debe pasar a tu rango real.
   - Con Sastrería por encima de 50 y paño de lino en la bolsa: marca y línea «para fabricar Rollo de
     paño de lino».
   - **Plan para subir** (`/guardamat plan`): que la ventana se abra, se mueva, se cierre con Escape y que
     el texto quepa y haga scroll. Que los pasos salgan con el nombre de la receta (`C_Spell.GetSpellName`)
     y los materiales con su nombre (si salen «objeto N», que se corrijan solos al cargar).
   - Abrir la ventana de la profesión y volver al plan: las recetas que conoces ya no deben llevar
     «apréndela». Si siguen, `C_TradeSkillUI.GetRecipeInfo(...).learned` no se lee como se espera con la
     ventana abierta: anotar qué devuelve con `/dump C_TradeSkillUI.GetRecipeInfo(2963)`.
   - Con Auctionator y un escaneo hecho: «Precios: subasta de Auctionator» y cifras parecidas a las que
     enseña Auctionator en el tooltip. Sin escaneo, cae al precio de referencia.
   - Comprobar un tramo contra el juego: que el color del paso coincida con el de la receta en la ventana de
     la profesión (los umbrales de las DB2 y la fórmula de Vanilla son una estimación) y que las cantidades
     del inventario cuadren con las bolsas y el banco.
   - Con una profesión sin aprender marcada en «Profesiones que pienso aprender»: que aparezca su botón y
     empiece en 1.
2. **Regenerar los datos tras cada parche** que toque recetas (`python -I -B tools/generar_datos.py`) y
   repasar el recuento por profesión que imprime.
3. **Ideas, sin decidir**: lista de objetos a ignorar a mano; aviso también al vender al mercader;
   marcas en las bolsas de SegundaPantalla o de addons de bolsas (Baganator, etc.) si Nico los usa;
   refinar las marcas con las recetas aprendidas (el plan ya las guarda en `known`). Plan: rango de
   aprendizaje real de cada receta (la DB2 no lo trae; quizá `C_TradeSkillUI.GetRecipeSourceText`, sin
   documentar); coste de comprar las recetas de objeto; contar los puntos que dan los intermedios.

## Decisiones

- Plan para subir: solo informa (nada de comprar ni publicar; política de Blizzard y un clic por acción).
  Las recetas que no conoces se planifican desde su amarillo porque la DB2 de Forever no trae su rango de
  aprendizaje (MinSkillLineRank vale 1 en casi todas); no se inventa. Sin Auctionator, el precio de tienda
  (BuyPrice) se enseña como referencia, no como precio real.

- Se cuentan las recetas no aprendidas: el addon avisa de lo que te servirá para subir, no solo de lo
  que ya puedes fabricar. El tooltip enseña el detalle para decidir.
- Una receta con umbral gris 0 (3 en los datos) cuenta como uso pero no como subida.
- Los alts solo cuentan con el mismo ruleset: entre Hardcore y normal no se pasan objetos.
