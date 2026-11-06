-- Plan para subir una profesión: el planificador (Planner.lua), los precios (Prices.lua) y la
-- ventana y el comando (Modules/Plan.lua). Con recetas inventadas para no depender de la build; al
-- final, una comprobación con los datos reales de Datos/Planes.lua.
local Cliente = require("cliente")

local TOC = "GuardaMateriales.toc"
local TAILORING = 197

-- Reactivos: 10 paño (precio 10), 11 hilo (3), 12 rollo (100, o fabricado con 2 paños), 13 tinte
-- (sin precio). Precios en PRICES. Recetas:
--   A: y 30, g 50, 1 paño (10)            -> se aprende sola
--   B: y 20, g 40, 1 hilo (3)
--   ROLL: fabrica el rollo con 2 paños, y 25, g 50, automática
--   COAT: 1 rollo, y 50, g 90, entrenador (no la conoces)
--   RARE: y 70, g 100, la enseña un objeto
local A = { s = 1, y = 30, g = 50, a = true, t = 0, o = 0, q = 1, r = { 10, 1 } }
local B = { s = 2, y = 20, g = 40, a = true, t = 0, o = 0, q = 1, r = { 11, 1 } }
local ROLL = { s = 3, y = 25, g = 50, a = true, t = 0, o = 12, q = 1, r = { 10, 2 } }
local COAT = { s = 4, y = 50, g = 90, a = false, t = 0, o = 0, q = 1, r = { 12, 1 } }
local RARE = { s = 5, y = 70, g = 100, a = false, t = 900, o = 0, q = 1, r = { 13, 1 } }

local PRICES = { [10] = 10, [11] = 3, [12] = 100 }
local function price(item)
    return PRICES[item]
end

local function boot(opts)
    opts = opts or {}
    opts.professions = opts.professions
        or { { skillLine = 2948, rank = 1, maxRank = 75, name = "Tailoring", icon = 1 } }
    local env, ns = Cliente.boot(TOC, opts)
    return env, ns, Cliente.fake(env)
end

local function contains(text, fragment)
    assert(text:find(fragment, 1, true), "no aparece «" .. fragment .. "» en:\n" .. text)
end

describe("Planner: dificultad", function()
    local Planner

    before_each(function()
        local _, ns = boot()
        Planner = ns.Planner
    end)

    it("naranja bajo el amarillo, amarillo hasta el punto medio, verde hasta el gris", function()
        assert.are.equal("orange", Planner.Color(A, 29))
        assert.are.equal("yellow", Planner.Color(A, 30))
        assert.are.equal("green", Planner.Color(A, 40))
        assert.are.equal("gray", Planner.Color(A, 50))
    end)

    it("probabilidad: 1 en naranja, lineal hasta 0 en el gris", function()
        assert.are.equal(1, Planner.Chance(A, 10))
        assert.are.equal(1, Planner.Chance(A, 30))
        assert.are.equal(0.5, Planner.Chance(A, 40))
        assert.are.equal(0, Planner.Chance(A, 50))
    end)

    it("origen de la receta: conocida, automática, de objeto o por aprender", function()
        assert.are.equal("known", Planner.Source(COAT, { [4] = true }))
        assert.are.equal("auto", Planner.Source(A, {}))
        assert.are.equal("item", Planner.Source(RARE, {}))
        assert.are.equal("learn", Planner.Source(COAT, {}))
    end)
end)

describe("Planner.Plan", function()
    local Planner

    before_each(function()
        local _, ns = boot()
        Planner = ns.Planner
    end)

    it("elige el camino más barato en cada punto", function()
        local plan = Planner.Plan({ recipes = { A, B }, from = 1, to = 45, price = price })
        -- B (3) gana mientras su coste esperado (3 / probabilidad) no supere al de A (10 / prob. de A).
        local first, last = plan.segments[1], plan.segments[#plan.segments]
        assert.are.equal(B, first.recipe)
        assert.are.equal(1, first.from)
        assert.are.equal("orange", first.color)
        assert.are.equal(A, last.recipe)
        assert.are.equal(45, last.to)
        assert.are.equal(45, plan.reached)
        assert.is_nil(plan.gap)
        -- Coste = lo que se compra por su precio.
        local expected = (plan.buy[10] or 0) * 10 + (plan.buy[11] or 0) * 3
        assert.are.equal(expected, plan.cost)
        assert.is_true(plan.cost > 0)
    end)

    it("no elige una verde casi gris aunque salga barata; solo si no hay otra", function()
        local cheap = { s = 5, y = 20, g = 40, a = true, t = 0, o = 0, q = 1, r = { 13, 1 } }
        local function prices(item)
            return ({ [10] = 10, [13] = 1 })[item]
        end
        -- En 37 la barata sube un 15 % (1 / 0,15 ≈ 6,7 de coste esperado) y A un 65 % (≈ 15,4).
        local plan = Planner.Plan({ recipes = { A, cheap }, from = 37, to = 38, price = prices })
        assert.are.equal(A, plan.segments[1].recipe)
        local alone = Planner.Plan({ recipes = { cheap }, from = 37, to = 38, price = prices })
        assert.are.equal(cheap, alone.segments[1].recipe)
        assert.is_true(alone.segments[1].grind) -- 6,7 fabricaciones para un punto: se avisa
        assert.is_false(plan.segments[1].grind)
    end)

    it("los tramos seguidos con la misma receta se juntan y redondean hacia arriba", function()
        local plan = Planner.Plan({ recipes = { B }, from = 1, to = 20, price = price })
        assert.are.equal(1, #plan.segments)
        assert.are.equal(19, plan.segments[1].crafts) -- naranja: una fabricación por punto
        assert.are.equal(19, plan.buy[11])
    end)

    it("descuenta lo que ya tienes: gasta primero tus materiales y compra solo el resto", function()
        local plan = Planner.Plan({ recipes = { A, B }, from = 1, to = 20, price = price, have = { [10] = 5 } })
        assert.are.equal(5, plan.use[10])
        assert.are.equal(A, plan.segments[1].recipe) -- con paño gratis, A es más barata al principio
        assert.are.equal(5, plan.segments[1].crafts)
        assert.are.equal(B, plan.segments[2].recipe)
        assert.is_nil(plan.buy[10])
        assert.are.equal(14, plan.buy[11])
        assert.are.equal(14 * 3, plan.cost)
    end)

    it("sin precio de ningún sitio, la receta se usa solo si no hay otra y se avisa", function()
        local blind = { s = 9, y = 30, g = 60, a = true, t = 0, o = 0, q = 1, r = { 13, 1 } }
        local plan = Planner.Plan({ recipes = { blind }, from = 1, to = 10, price = price })
        assert.is_true(plan.segments[1].unknownCost)
        assert.is_true(plan.noPrice[13])
        assert.are.equal(0, plan.cost)
        local mixed = Planner.Plan({ recipes = { blind, B }, from = 1, to = 10, price = price })
        assert.are.equal(B, mixed.segments[1].recipe)
    end)

    it("una receta que no conoces solo cuenta desde su amarillo; una de objeto, nunca", function()
        local later = Planner.Plan({ recipes = { A, COAT, RARE }, from = 30, to = 80, price = price })
        -- De 30 a 50 solo vale A (el abrigo aún no es amarillo); desde 50, el abrigo por aprender.
        assert.are.equal(A, later.segments[1].recipe)
        assert.are.equal(50, later.segments[1].to)
        assert.are.equal(COAT, later.segments[2].recipe)
        assert.are.equal("learn", later.segments[2].source)
        assert.are.equal("yellow", later.segments[2].color)
        assert.is_false(later.segments[2].early)
        assert.is_nil(later.gap)
        local known = Planner.Plan({ recipes = { RARE }, from = 1, to = 5, price = price, known = { [5] = true } })
        assert.are.equal(RARE, known.segments[1].recipe)
        assert.are.equal("known", known.segments[1].source)
    end)

    it("si no hay otra cosa, rellena el hueco con una por aprender aún en naranja, avisando", function()
        local plan = Planner.Plan({ recipes = { COAT, RARE }, from = 1, to = 60, price = price })
        assert.are.equal(COAT, plan.segments[1].recipe)
        assert.is_true(plan.segments[1].early)
        assert.are.equal("orange", plan.segments[1].color)
        assert.are.equal(50, plan.segments[1].to)
        assert.is_false(plan.segments[2].early) -- desde el amarillo, ya sin aviso
        assert.is_nil(plan.gap)
    end)

    it("fabrica el intermedio si sale más barato que comprarlo", function()
        -- El rollo cuesta 100 en la subasta y 20 fabricado (2 paños de 10). El abrigo, conocido y
        -- en naranja, cuesta lo mismo que fabricar el rollo: con empate gana el primero.
        local plan = Planner.Plan({
            recipes = { COAT, ROLL },
            from = 10,
            to = 11,
            price = price,
            known = { [4] = true },
        })
        assert.are.equal(COAT, plan.segments[1].recipe)
        assert.are.equal(1, plan.craft[12])
        assert.is_nil(plan.buy[12])
        assert.are.equal(2, plan.buy[10])
        assert.are.equal(20, plan.cost)
    end)

    it("se detiene donde ninguna receta sube y lo dice", function()
        local plan = Planner.Plan({ recipes = { B }, from = 1, to = 60, price = price })
        assert.are.equal(40, plan.gap)
        assert.are.equal(40, plan.reached)
    end)

    it("MaxRank es el gris más alto; Money escribe oro, plata y cobre", function()
        assert.are.equal(100, Planner.MaxRank({ A, RARE }))
        assert.are.equal("1g 2s 3c", Planner.Money(10203))
        assert.are.equal("0c", Planner.Money(0))
    end)
end)

describe("Prices", function()
    it("sin Auctionator, usa el precio de tienda de los datos como referencia", function()
        local _, ns = boot()
        ns.BUY_PRICE = { [10] = 40 }
        assert.is_false(ns.Prices.HasAuctionator())
        assert.are.same({ 40, "reference" }, { ns.Prices.Get(10) })
        assert.is_nil(ns.Prices.Get(11))
    end)

    it("con Auctionator, el menor entre subasta y mercader, con su nombre de addon", function()
        local callers = {}
        local auction = { [10] = 25, [11] = 90 }
        local vendor = { [11] = 50 }
        local Auctionator = {
            API = {
                v1 = {
                    GetAuctionPriceByItemID = function(caller, id)
                        callers[#callers + 1] = caller
                        return auction[id]
                    end,
                    GetVendorPriceByItemID = function(_, id)
                        return vendor[id]
                    end,
                },
            },
        }
        local _, ns = boot({ globals = { Auctionator = Auctionator } })
        ns.BUY_PRICE = { [12] = 7 }
        assert.is_true(ns.Prices.HasAuctionator())
        assert.are.same({ 25, "auction" }, { ns.Prices.Get(10) })
        assert.are.same({ 50, "vendor" }, { ns.Prices.Get(11) })
        assert.are.same({ 7, "reference" }, { ns.Prices.Get(12) }) -- Auctionator no lo conoce
        assert.are.equal("GuardaMateriales", callers[1])
    end)

    it("si Auctionator falla, no rompe: cae al precio de referencia", function()
        local Auctionator = {
            API = {
                v1 = {
                    GetAuctionPriceByItemID = function()
                        error("roto")
                    end,
                },
            },
        }
        local _, ns = boot({ globals = { Auctionator = Auctionator } })
        ns.BUY_PRICE = { [10] = 40 }
        assert.are.same({ 40, "reference" }, { ns.Prices.Get(10) })
    end)

    it("inventario: bolsas y banco con C_Item.GetItemCount", function()
        local _, ns = boot({ counts = { [10] = 7 } })
        assert.are.equal(7, ns.Prices.Have(10))
        assert.are.equal(0, ns.Prices.Have(11))
    end)
end)

describe("ventana, comando y menú del plan", function()
    local env, ns, fake

    before_each(function()
        env, ns, fake = boot({
            counts = { [10] = 3 },
            itemNames = { [10] = "Paño de lino", [11] = "Hilo", [12] = "Rollo" },
            spellNames = { [1] = "Capa", [2] = "Camisa", [3] = "Rollo", [4] = "Abrigo" },
        })
        ns.RECIPES = { [TAILORING] = { A, B, ROLL, COAT } }
        ns.BUY_PRICE = PRICES
    end)

    it("hasta el tope actual por defecto; «max» hasta que ninguna receta suba", function()
        local Plan = ns.Modules.Plan
        assert.are.same({ TAILORING }, Plan.Skills())
        assert.are.equal(75, Plan.Target(TAILORING, "cap"))
        assert.are.equal(90, Plan.Target(TAILORING, "max"))
        assert.are.equal(30, Plan.Target(TAILORING, 30))
    end)

    it("el texto lleva cabecera, pasos con color, materiales y coste", function()
        local text = table.concat(ns.Modules.Plan.Lines(TAILORING, "cap"), "\n")
        contains(text, "Tailoring: from 1 to 75")
        contains(text, "Camisa x")
        contains(text, "|cffff8040") -- primer tramo en naranja
        contains(text, "Paño de lino: 3 from your bags and bank")
        contains(text, "Estimated cost:")
        contains(text, "shop price from the game data")
    end)

    it("/guardamat plan chat sastr imprime el plan; un nombre desconocido avisa", function()
        env:ClearPrinted()
        env.SlashCmdList.GUARDAMATERIALES("plan chat tailor 20")
        contains(env:Printed(), "Tailoring: from 1 to 20")
        env:ClearPrinted()
        env.SlashCmdList.GUARDAMATERIALES("plan chat herreria")
        contains(env:Printed(), "Unknown profession: herreria")
    end)

    it("/guardamat plan abre la ventana con el plan; Escape la cierra", function()
        env.SlashCmdList.GUARDAMATERIALES("plan")
        local frame = env.GuardaMaterialesPlanFrame
        assert.is_true(frame:IsShown())
        contains(frame.text:GetText(), "Tailoring: from 1 to 75")
        assert.are.equal("GuardaMaterialesPlanFrame", env.UISpecialFrames[1])
        -- El botón «Hasta el final» recalcula.
        local found
        for _, child in ipairs(frame.skillButtons) do
            found = found or child:IsShown()
        end
        assert.is_true(found)
        ns:OpenPlan(nil, "max")
        contains(frame.text:GetText(), "from 1 to 90")
    end)

    it("el menú del icono de la bolsa tiene la entrada del plan", function()
        local entries = fake.OpenMenu("MENU_CONTAINER_FRAME")
        local sub = entries[2].children
        local plan
        for _, entry in ipairs(sub) do
            if entry.text == ns.L.MENU_PLAN then
                plan = entry
            end
        end
        assert(plan, "falta la entrada del plan en el menú")
        plan.onClick()
        assert.is_true(env.GuardaMaterialesPlanFrame:IsShown())
    end)

    it("con la ventana de la profesión abierta aprende qué recetas conoces", function()
        -- Sin conocerla, el abrigo sale como «apréndela» (desde el 50, cuando el resto ya es gris).
        local before = table.concat(ns.Modules.Plan.Lines(TAILORING, "max"), "\n")
        contains(before, "(learn it: trainer or another source)")
        fake.SetRecipeInfo({ [4] = { learned = true }, [1] = { learned = false } })
        env:Fire("TRADE_SKILL_LIST_UPDATE")
        env:Advance(1)
        assert.is_true(ns.charDB.known[4])
        assert.is_nil(ns.charDB.known[1])
        local text = table.concat(ns.Modules.Plan.Lines(TAILORING, "max"), "\n")
        assert.is_nil(text:find("learn it", 1, true))
        contains(text, "Abrigo x")
    end)
end)

describe("datos reales (Datos/Planes.lua)", function()
    it("sastrería: el rollo de paño de lino se aprende solo y hay plan de 1 a 150 sin huecos", function()
        local _, ns = boot()
        local recipes = ns.RECIPES[TAILORING]
        assert.is_true(#recipes > 100)
        local bolt
        for _, recipe in ipairs(recipes) do
            if recipe.s == 2963 then
                bolt = recipe
            end
        end
        assert(bolt, "falta el Rollo de paño de lino (2963)")
        assert.are.same({ 25, 50, true, 2996, 1 }, { bolt.y, bolt.g, bolt.a, bolt.o, bolt.q })
        assert.are.same({ 2589, 2 }, bolt.r)
        local plan = ns.Planner.Plan({ recipes = recipes, from = 1, to = 150, price = ns.Prices.Get })
        assert.is_nil(plan.gap)
        assert.are.equal(150, plan.reached)
        assert.is_true(plan.cost > 0)
    end)

    it("cada receta tiene umbrales coherentes y reactivos en pares", function()
        local _, ns = boot()
        for skill, list in pairs(ns.RECIPES) do
            for _, recipe in ipairs(list) do
                assert(recipe.y <= recipe.g and recipe.g > 0, "umbrales raros en " .. skill .. "/" .. recipe.s)
                assert(#recipe.r >= 2 and #recipe.r % 2 == 0, "reactivos impares en " .. recipe.s)
            end
        end
    end)
end)
