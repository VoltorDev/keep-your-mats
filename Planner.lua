local _, ns = ...

-- Plan para subir una profesión: qué receta fabricar en cada tramo y cuántas veces, por el camino
-- más barato. Lógica pura (sin API del juego): recibe las recetas, los precios y el inventario, y
-- se prueba fuera del juego. Los datos salen de Datos/Planes.lua (DB2 de Forever).
--
-- Dificultad (convención de Vanilla, estimada; Forever no la documenta): naranja por debajo del
-- umbral amarillo (y), amarilla hasta el punto medio, verde hasta el gris (g) y gris desde ahí.
-- Probabilidad de subir un punto: 1 en naranja y (g - rango) / (g - y) entre amarillo y gris.
--
-- La DB2 de Forever no dice con qué rango se aprende cada receta. Por eso una receta que el
-- personaje no conoce solo se planifica desde su umbral amarillo (en ese punto seguro que ya se
-- puede aprender) y las que enseña un objeto (t > 0) no se proponen si no las conoces. Si eso deja
-- un hueco, se rellena con la más barata de las que no conoces aunque siga en naranja, marcada
-- como `early` (quizá el entrenador aún no te la enseñe).
local Planner = {}
ns.Planner = Planner

local COLORS = { "orange", "yellow", "green", "gray" }
Planner.COLORS = COLORS

function Planner.Color(recipe, rank)
    if rank < recipe.y then
        return "orange"
    elseif rank < (recipe.y + recipe.g) / 2 then
        return "yellow"
    elseif rank < recipe.g then
        return "green"
    end
    return "gray"
end

-- Por debajo de esta probabilidad de subir (verde tardío) una receta solo se usa si no hay otra.
Planner.MIN_CHANCE = 0.2
Planner.GRIND_PER_POINT = 3

function Planner.Chance(recipe, rank)
    if rank >= recipe.g then
        return 0
    elseif rank < recipe.y or recipe.g <= recipe.y then
        return 1
    end
    return (recipe.g - rank) / (recipe.g - recipe.y)
end

-- Cómo se consigue la receta: "known" (la conoces), "auto" (se aprende sola con la profesión),
-- "item" (la enseña un objeto) o "learn" (entrenador u otra fuente: la DB2 no lo dice).
function Planner.Source(recipe, known)
    if known and known[recipe.s] then
        return "known"
    elseif recipe.a then
        return "auto"
    elseif recipe.t and recipe.t > 0 then
        return "item"
    end
    return "learn"
end

-- ¿Se puede usar esta receta con este rango para el plan?
local function Usable(recipe, rank, known)
    local source = Planner.Source(recipe, known)
    if source == "known" or source == "auto" then
        return true
    elseif source == "learn" then
        return rank >= recipe.y
    end
    return false
end
Planner.Usable = Usable

-- Recorre los reactivos de una receta: r = { objeto, cantidad, objeto, cantidad... }.
local function Reagents(recipe)
    local r, i = recipe.r, -1
    return function()
        i = i + 2
        if r[i] then
            return r[i], r[i + 1]
        end
    end
end
Planner.Reagents = Reagents

-- args = {
--   recipes = lista de Datos/Planes.lua de una profesión,
--   from = rango actual (0 si no la tienes), to = rango al que llegar,
--   known = { [hechizo] = true } recetas que conoces (nil: ninguna salvo las automáticas),
--   price = function(itemID) -> cobre o nil (sin precio),
--   have = { [itemID] = cantidad } en bolsas y banco,
-- }
-- Devuelve {
--   segments = { { recipe, from, to, crafts, color, source, unknownCost, early } },
--   buy = { [itemID] = cantidad a comprar }, use = { [itemID] = cantidad que ya tienes y gastas },
--   craft = { [itemID] = cantidad de intermedios que te sale más barato fabricar },
--   cost = cobre total de lo que compras (sin los objetos sin precio),
--   noPrice = { [itemID] = true }, gap = rango donde no hay receta (o nil), reached = rango final,
-- }
function Planner.Plan(args)
    local recipes, known, price = args.recipes or {}, args.known or {}, args.price
    local inventory = {}
    for item, count in pairs(args.have or {}) do
        inventory[item] = count
    end

    -- Quién fabrica cada objeto (para intermedios como el rollo de paño), en esta profesión.
    local producers = {}
    for _, recipe in ipairs(recipes) do
        if recipe.o and recipe.o > 0 then
            local list = producers[recipe.o] or {}
            producers[recipe.o] = list
            list[#list + 1] = recipe
        end
    end

    local priceCache = {}
    local function Price(item)
        local cached = priceCache[item]
        if cached == nil then
            cached = price and price(item) or false
            priceCache[item] = cached
        end
        return cached or nil
    end

    -- Coste de una unidad comprada o fabricada (un nivel de intermedios, sin ciclos):
    -- devuelve coste, fabricante (si fabricar sale más barato) o nil si no hay precio.
    local CraftCost
    local function UnitCost(item, rank, depth)
        local best = Price(item)
        local via
        if depth == 0 then
            for _, producer in ipairs(producers[item] or {}) do
                if Usable(producer, rank, known) then
                    local cost = CraftCost(producer, rank, 1, true)
                    if cost then
                        cost = cost / (producer.q or 1)
                        if not best or cost < best then
                            best, via = cost, producer
                        end
                    end
                end
            end
        end
        return best, via
    end

    -- Coste de fabricar una vez, descontando lo que ya tienes (ignoreInventory para intermedios).
    function CraftCost(recipe, rank, depth, ignoreInventory)
        local total = 0
        for item, count in Reagents(recipe) do
            local need = count
            if not ignoreInventory then
                need = math.max(0, count - (inventory[item] or 0))
            end
            if need > 0 then
                local unit = UnitCost(item, rank, depth)
                if not unit then
                    return nil
                end
                total = total + need * unit
            end
        end
        return total
    end

    local plan = { segments = {}, buy = {}, use = {}, craft = {}, cost = 0, noPrice = {} }
    local craftNeeds = {} -- intermedio -> { cantidad, fabricante }

    local function Consume(recipe, crafts, rank)
        for item, count in Reagents(recipe) do
            local need = count * crafts
            local owned = inventory[item] or 0
            local used = math.min(owned, need)
            if used > 0 then
                inventory[item] = owned - used
                plan.use[item] = (plan.use[item] or 0) + used
            end
            local rest = need - used
            if rest > 0 then
                local _, via = UnitCost(item, rank, 0)
                if via then
                    local entry = craftNeeds[item] or { count = 0, producer = via }
                    craftNeeds[item] = entry
                    entry.count = entry.count + rest
                else
                    plan.buy[item] = (plan.buy[item] or 0) + rest
                end
            end
        end
    end

    local rank = math.max(args.from or 0, 1)
    local to = args.to or rank
    local last
    while rank < to do
        local best, bestCost, bestChance
        local fallback, fallbackChance -- sin precio: solo si no hay otra
        -- Primero solo recetas con probabilidad razonable: una verde casi gris pide decenas de
        -- fabricaciones por punto y, con precios de referencia baratos, salían miles de unidades.
        for _, minChance in ipairs({ Planner.MIN_CHANCE, 0 }) do
            for _, recipe in ipairs(recipes) do
                local chance = Planner.Chance(recipe, rank)
                if chance > minChance and chance > 0 and Usable(recipe, rank, known) then
                    local cost = CraftCost(recipe, rank, 0)
                    if cost then
                        local expected = cost / chance
                        if not best or expected < bestCost or (expected == bestCost and chance > bestChance) then
                            best, bestCost, bestChance = recipe, expected, chance
                        end
                    elseif not fallback or chance > fallbackChance then
                        fallback, fallbackChance = recipe, chance
                    end
                end
            end
            if best or fallback then
                break
            end
        end
        local unknownCost, early = false, false
        if not best then
            best, bestChance, unknownCost = fallback, fallbackChance, fallback ~= nil
        end
        -- Hueco: ninguna receta sirve con la regla del amarillo. Último recurso, la más barata de las
        -- que no conoces aunque aún esté en naranja, avisando de que quizá aún no se pueda aprender.
        if not best then
            for _, recipe in ipairs(recipes) do
                if Planner.Source(recipe, known) == "learn" and Planner.Chance(recipe, rank) > 0 then
                    local cost = CraftCost(recipe, rank, 0)
                    if cost and (not best or cost < bestCost) then
                        best, bestCost, bestChance, early = recipe, cost, 1, true
                    end
                end
            end
        end
        if not best then
            plan.gap = rank
            break
        end
        local crafts = 1 / bestChance
        Consume(best, crafts, rank)
        if unknownCost then
            for item in Reagents(best) do
                if not Price(item) then
                    plan.noPrice[item] = true
                end
            end
        end
        if last and last.recipe == best and last.early == early then
            last.to = rank + 1
            last.crafts = last.crafts + crafts
        else
            last = {
                recipe = best,
                from = rank,
                to = rank + 1,
                crafts = crafts,
                color = Planner.Color(best, rank),
                source = Planner.Source(best, known),
                unknownCost = unknownCost,
                early = early, -- puede que el entrenador aún no te la enseñe
            }
            plan.segments[#plan.segments + 1] = last
        end
        last.unknownCost = last.unknownCost or unknownCost
        rank = rank + 1
    end
    plan.reached = rank
    -- Tramo «a base de repetir»: más de GRIND_PER_POINT fabricaciones por punto. Suele ser que en
    -- ese tramo se sube con recetas de objeto (planos, patrones) que aún no conoces.
    for _, segment in ipairs(plan.segments) do
        segment.grind = segment.crafts / math.max(segment.to - segment.from, 1) > Planner.GRIND_PER_POINT
    end

    -- Intermedios: se fabrican con sus propios reactivos (descontando lo que quede en bolsas).
    for item, entry in pairs(craftNeeds) do
        local producer = entry.producer
        local crafts = math.ceil(entry.count / (producer.q or 1))
        plan.craft[item] = crafts * (producer.q or 1)
        Consume(producer, crafts, plan.reached)
    end

    -- Cantidades enteras y coste total.
    for item, count in pairs(plan.buy) do
        count = math.ceil(count - 1e-9)
        plan.buy[item] = count
        local unit = Price(item)
        if unit then
            plan.cost = plan.cost + count * unit
        else
            plan.noPrice[item] = true
        end
    end
    for item, count in pairs(plan.use) do
        plan.use[item] = math.ceil(count - 1e-9)
    end
    for _, segment in ipairs(plan.segments) do
        segment.crafts = math.ceil(segment.crafts - 1e-9)
    end
    return plan
end

-- Rango más alto que da algún punto en esta profesión (el gris más alto de sus recetas).
function Planner.MaxRank(recipes)
    local max = 0
    for _, recipe in ipairs(recipes or {}) do
        if recipe.g > max then
            max = recipe.g
        end
    end
    return max
end

-- Cobre a texto: "1o 2p 3c" en español, "1g 2s 3c" en inglés.
function Planner.Money(copper)
    copper = math.floor((copper or 0) + 0.5)
    local gold = math.floor(copper / 10000)
    local silver = math.floor(copper / 100) % 100
    local rest = copper % 100
    local L = ns.L
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. L.MONEY_GOLD
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. L.MONEY_SILVER
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = rest .. L.MONEY_COPPER
    end
    return table.concat(parts, " ")
end
