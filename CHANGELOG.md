# Changelog

## 1.1.0 (06-11-2026)

- Plan para subir: no elige recetas casi grises (menos de un 20 % de subir) si hay otra, y avisa en los tramos
  con muchas fabricaciones por punto, donde suele hacer falta un plano o patrón.
- Plan para subir cada profesión (`/guardamat plan` o el menú del icono de la bolsa): qué receta
  fabricar en cada tramo y cuántas veces por el camino más barato, con la lista de materiales (lo que
  ya tienes en bolsas y banco, lo que te sale más barato fabricar y lo que hay que comprar) y el coste.
  Precios de Auctionator si está instalado; si no, el precio de tienda de los datos como referencia.
  Solo informa: no compra nada. Nuevos datos `Datos/Planes.lua` (2231 recetas con dificultad).
- Los materiales intermedios cuentan: el paño se guarda mientras el rollo que fabricas con él te siga
  sirviendo, aunque la receta del rollo ya sea gris. El tooltip dice para qué intermedio y hasta qué nivel.
- Profesiones que pienso aprender: por personaje, sus materiales se marcan como si la tuvieras a nivel 1.
- Ajustes dentro del juego: entrada en el menú del icono de la bolsa con todas las opciones, y panel de
  Opciones > AddOns ordenado por secciones.

- Primera versión: marca en bolsas y banco los materiales que aún suben tus profesiones (y las
  secundarias), detalle en el tooltip, aviso al ponerlos en venta en la subasta y opción de contar
  las profesiones de tus otros personajes. Datos de recetas de Forever 1.60.1.70753.

## 1.0.1 (05-11-2026)

- The addon list in game now shows its English name, **Keep Your Mats** (the folder is still `GuardaMateriales`, so your settings are kept). Same code as 1.0.0; the changes above are not in this release.

