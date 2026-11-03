-- Lógica del addon: qué cuenta como material que te sirve (Materials.lua), de dónde salen tus
-- profesiones (Professions.lua) y lo que se ve: marcas en bolsas y banco, tooltip, aviso en la
-- subasta y /guardamat item. Con datos de recetas inventados para que no dependan de la build;
-- el fichero real se comprueba aparte al final.
local Cliente = require("cliente")
local Secret = require("secret_mock")

local TOC = "GuardaMateriales.toc"

local BLACKSMITHING, MINING, TAILORING, COOKING, POISONS = 164, 186, 197, 185, 40
local BS_ICON = 136241

-- Objetos de prueba: 100 Herrería + Minería, 200 Cocina, 300 Sastrería (receta sin dificultad),
-- 400 Venenos. 999 no es material.
local MATERIALS = {
    [100] = { [BLACKSMITHING] = { 50, 30 }, [MINING] = { 25 } },
    [200] = { [COOKING] = { 90, 85 } },
    [300] = { [TAILORING] = { 0 } },
    [400] = { [POISONS] = { 200 } },
}

local function contains(text, fragment)
    assert(text:find(fragment, 1, true), "no aparece «" .. fragment .. "» en:\n" .. text)
end

local function joined(lines)
    return table.concat(lines, "\n")
end

-- Arranca con unas profesiones y bolsas, y los materiales de prueba en lugar de los reales.
local function boot(opts)
    opts = opts or {}
    opts.professions = opts.professions
        or { { skillLine = 2938, rank = 40, maxRank = 75, name = "Blacksmithing", icon = BS_ICON } }
    local env, ns = Cliente.boot(TOC, opts)
    ns.MATERIALS = MATERIALS
    ns.Materials.Invalidate()
    return env, ns, Cliente.fake(env)
end

describe("Materials.Evaluate", function()
    local ns

    before_each(function()
        local _
        _, ns = boot()
    end)

    it("una receta sube mientras tu rango está por debajo de su umbral gris", function()
        local result = ns.Materials.Evaluate(100, { [BLACKSMITHING] = { rank = 40, learned = true } })
        assert.is_true(result.keep)
        assert.are.equal(1, #result.entries) -- Minería no está en el perfil: no cuenta
        local e = result.entries[1]
        local got = { e.skill, e.rank, e.learned, e.useful, e.total, e.maxGray }
        assert.are.same({ BLACKSMITHING, 40, true, 1, 2, 50 }, got)
    end)

    it("en el umbral gris exacto ya no sube: es material tuyo pero no te sirve", function()
        local result = ns.Materials.Evaluate(100, { [BLACKSMITHING] = { rank = 50, learned = true } })
        assert.is_false(result.keep)
        assert.are.equal(0, result.entries[1].useful)
    end)

    it("un objeto que no es material, o de una profesión que no tienes, da nil", function()
        assert.is_nil(ns.Materials.Evaluate(999, { [BLACKSMITHING] = { rank = 1, learned = true } }))
        assert.is_nil(ns.Materials.Evaluate(200, { [BLACKSMITHING] = { rank = 1, learned = true } }))
    end)

    it("una receta sin datos de dificultad (umbral 0) cuenta como uso, no como subida", function()
        local result = ns.Materials.Evaluate(300, { [TAILORING] = { rank = 0, learned = true } })
        assert.is_false(result.keep)
        assert.are.equal(1, result.entries[1].total)
    end)

    it("las profesiones en las que aún sube van primero", function()
        local profile = { [BLACKSMITHING] = { rank = 60, learned = true }, [MINING] = { rank = 1, learned = true } }
        local result = ns.Materials.Evaluate(100, profile)
        assert.are.equal(MINING, result.entries[1].skill)
        assert.are.equal(BLACKSMITHING, result.entries[2].skill)
    end)

    it("con secundarias, Cocina cuenta sin aprender (rango 0); sin ellas, no", function()
        local with = ns.Materials.BuildProfile({}, true)
        assert.are.same({ rank = 0, learned = false }, with[COOKING])
        assert.is_true(ns.Materials.Evaluate(200, with).keep)
        assert.is_nil(ns.Materials.Evaluate(200, ns.Materials.BuildProfile({}, false)))
        assert.is_nil(with[BLACKSMITHING]) -- una primaria sin aprender no se añade
    end)

    it("una secundaria aprendida usa su rango real", function()
        local profile = ns.Materials.BuildProfile({ [COOKING] = { rank = 90, maxRank = 150 } }, true)
        assert.is_false(ns.Materials.Evaluate(200, profile).keep)
    end)
end)

describe("Materials.Status y otros personajes", function()
    it("keep con la profesión que se pinta; done si ya no sube; nil si no es material", function()
        local _, ns = boot()
        assert.are.same({ "keep", BLACKSMITHING }, { ns.Materials.Status(100) })
        assert.are.same({ "keep", COOKING }, { ns.Materials.Status(200) }) -- secundaria por defecto
        assert.is_nil(ns.Materials.Status(999))
        local _, nsHigh = boot({ professions = { { skillLine = 164, rank = 70, maxRank = 75 } } })
        assert.are.same({ "done", BLACKSMITHING }, { nsHigh.Materials.Status(100) })
    end)

    it("la caché se vacía al cambiar las opciones", function()
        local env, ns = boot()
        assert.are.equal("keep", (ns.Materials.Status(200)))
        env:SettingsRegistry().settings[env:AddonName() .. "_Secondaries"]:SetValue(false)
        assert.is_nil(ns.Materials.Status(200))
    end)

    it("con la opción de alts, un material que solo sirve a otro personaje también es keep", function()
        local env, ns = boot({ professions = {} })
        local me = ns.db.chars[ns.charKey]
        ns.db.chars["Otra Pj"] = { ruleset = me.ruleset, professions = { [TAILORING] = { rank = 1, maxRank = 75 } } }
        ns.db.chars["Alta Pj"] = { ruleset = me.ruleset, professions = { [MINING] = { rank = 10, maxRank = 75 } } }
        ns.db.chars["Dura Pj"] =
            { ruleset = "Hardcore", professions = { [BLACKSMITHING] = { rank = 1, maxRank = 75 } } }
        ns.Materials.Invalidate()
        assert.is_nil(ns.Materials.Status(100)) -- sin la opción, no cuenta

        env:SettingsRegistry().settings[env:AddonName() .. "_Alts"]:SetValue(true)
        assert.are.same({ "keep", MINING }, { ns.Materials.Status(100) })
        local alts = ns.Materials.EvaluateAlts(100)
        assert.are.equal(1, #alts) -- la de Hardcore no comparte objetos con esta
        assert.are.same({ "Alta Pj", MINING, 10, 1 }, { alts[1].key, alts[1].skill, alts[1].rank, alts[1].useful })
        assert.are.same({}, ns.Materials.EvaluateAlts(300)) -- umbral 0: no le sube a nadie
    end)
end)

describe("profesiones del personaje", function()
    it("lee GetProfessions con huecos y subhabilidades de Forever (2938 -> Herrería)", function()
        local _, ns = boot({
            professions = {
                { skillLine = 2938, rank = 87, maxRank = 150 },
                false,
                { skillLine = 129, rank = 12, maxRank = 75 },
                { skillLine = 9999, rank = 5, maxRank = 75 }, -- no es profesión del addon
            },
        })
        assert.are.same({ rank = 87, maxRank = 150 }, ns.professions[BLACKSMITHING])
        assert.are.same({ rank = 12, maxRank = 75 }, ns.professions[129])
        assert.is_nil(ns.professions[9999])
    end)

    it("Venenos sale de C_SkillInfo; una habilidad con maxRank 0 no está aprendida", function()
        local _, ns = boot({
            professions = {},
            skills = { [POISONS] = { rank = 120, maxRank = 300 }, [MINING] = { rank = 0, maxRank = 0 } },
        })
        assert.are.same({ rank = 120, maxRank = 300 }, ns.professions[POISONS])
        assert.is_nil(ns.professions[MINING])
        assert.are.equal("keep", (ns.Materials.Status(400)))
    end)

    it("guarda las profesiones y la clase en la entrada del personaje (para los alts)", function()
        local _, ns = boot()
        local entry = ns.db.chars[ns.charKey]
        assert.is_not_nil(ns.charKey)
        assert.are.equal(ns.professions, entry.professions)
        assert.are.equal("WARRIOR", entry.class)
    end)

    it("al subir de rango (SKILL_LINES_CHANGED, agrupado) cambia la marca", function()
        local env, ns, fake = boot({ bags = { [0] = { [1] = 100 } } })
        env.ContainerFrame1:Show()
        env.ContainerFrame1:UpdateItems()
        local button = fake.Button("ContainerFrame1", 1)
        assert.is_not_nil(fake.Mark(button))

        fake.SetProfessions({ { skillLine = 2938, rank = 50, maxRank = 75 } })
        env:Fire("SKILL_LINES_CHANGED")
        env:Fire("SKILL_LINES_CHANGED")
        assert.are.equal(40, ns.professions[BLACKSMITHING].rank) -- aún no: espera a la ráfaga
        env:Advance(0.5)
        assert.are.equal(50, ns.professions[BLACKSMITHING].rank)
        assert.is_nil(fake.Mark(button)) -- ya no te sube: sin marca (showDone desactivado)
    end)
end)

describe("marcas en bolsas y banco", function()
    local env, ns, fake

    before_each(function()
        env, ns, fake = boot({ bags = { [0] = { [1] = 100, [2] = 999, [4] = 300 }, [6] = { [2] = 100 } } })
        env.ContainerFrame1:Show()
        env.ContainerFrame1:UpdateItems()
    end)

    it("pinta el icono de la profesión solo en los materiales que te sirven", function()
        local mark = fake.Mark(fake.Button("ContainerFrame1", 1))
        assert.is_not_nil(mark)
        assert.are.equal(BS_ICON, (mark:LastCall("SetTexture")))
        assert.is_false((mark:LastCall("SetDesaturated")))
        assert.is_nil(fake.Mark(fake.Button("ContainerFrame1", 2))) -- no es material
        assert.is_nil(fake.Mark(fake.Button("ContainerFrame1", 3))) -- hueco vacío
        assert.is_nil(fake.Mark(fake.Button("ContainerFrame1", 4))) -- material de otra profesión
    end)

    it("un hueco que se vacía pierde la marca en la siguiente actualización", function()
        fake.SetBags({ [0] = {} })
        env.ContainerFrame1:UpdateItems()
        assert.is_nil(fake.Mark(fake.Button("ContainerFrame1", 1)))
    end)

    it("con showDone, los que ya no suben se marcan en gris", function()
        fake.SetProfessions({ { skillLine = 2938, rank = 70, maxRank = 75 } })
        ns.Professions.Refresh()
        assert.is_nil(fake.Mark(fake.Button("ContainerFrame1", 1)))
        ns.db.showDone = true
        ns:ApplySettings()
        local mark = fake.Mark(fake.Button("ContainerFrame1", 1))
        assert.is_not_nil(mark)
        assert.is_true((mark:LastCall("SetDesaturated")))
    end)

    it("el banco se marca al actualizarse con el panel abierto, y no hace nada cerrado", function()
        local bankButton = fake.Button("BankPanel", 2)
        env:Fire("BAG_UPDATE_DELAYED")
        assert.is_nil(fake.Mark(bankButton))
        env.BankPanel:Show()
        env.BankPanel:RefreshAllItemsForSelectedTab()
        assert.is_not_nil(fake.Mark(bankButton))
        fake.SetBags({ [6] = {} })
        env:Fire("BAG_UPDATE_DELAYED")
        assert.is_nil(fake.Mark(bankButton))
    end)

    it("las bolsas cerradas no se repintan al cambiar opciones", function()
        env.ContainerFrame2:Hide()
        ns:ApplySettings()
        assert.is_nil(fake.Button("ContainerFrame2", 1).guardaMaterialesMark)
    end)
end)

describe("tooltip del objeto", function()
    it("dice en cuántas recetas te sube y hasta qué rango", function()
        local _, _, fake = boot()
        local text = joined(fake.ShowItemTooltip(100))
        contains(text, "Profession material")
        contains(text, "Keep: Blacksmithing 40, 1 recipes still level you (up to 50)")
        contains(text, "|T136241:0|t")
    end)

    it("marca las secundarias sin aprender y los materiales que ya no suben", function()
        local _, _, fake = boot({ professions = { { skillLine = 197, rank = 10, maxRank = 75 } } })
        contains(joined(fake.ShowItemTooltip(200)), "Cooking (not learned)")
        contains(joined(fake.ShowItemTooltip(300)), "Tailoring 10: used in 1 recipes")
        local _, _, high = boot({ professions = { { skillLine = 164, rank = 70, maxRank = 75 } } })
        contains(joined(high.ShowItemTooltip(100)), "no longer levels you (all grey from 50)")
    end)

    it("en español", function()
        local _, _, fake = boot({ locale = "esES" })
        contains(joined(fake.ShowItemTooltip(100)), "Guárdalo: Herrería 40, te suben 1 recetas (hasta 50)")
    end)

    it("no añade nada a un objeto que no es material, con la opción apagada o a otros tooltips", function()
        local env, ns, fake = boot()
        assert.are.same({}, fake.ShowItemTooltip(999))
        assert.is_true(#fake.ShowItemTooltip(100, env.ItemRefTooltip) > 0)
        local other = env:_NewWidget("GameTooltip", "ShoppingTooltip1", env.UIParent)
        assert.are.same({}, fake.ShowItemTooltip(100, other))
        ns.db.tooltip = false
        assert.are.same({}, fake.ShowItemTooltip(100))
    end)

    it("un ID secreto se ignora sin error", function()
        local _, _, fake = boot()
        assert.are.same({}, fake.ShowItemTooltip(Secret.wrap(100)))
    end)

    it("con alts, nombra a los otros personajes que lo aprovechan", function()
        local _, ns, fake = boot({ professions = {} })
        ns.db.alts = true
        ns.db.chars["Alta Pj"] = { professions = { [MINING] = { rank = 10, maxRank = 75 } } }
        contains(joined(fake.ShowItemTooltip(100)), "Alta Pj, Mining 10: 1 recipes level them")
    end)
end)

describe("aviso en la subasta", function()
    local env, ns, fake, ah

    before_each(function()
        env, ns, fake = boot({ bags = { [0] = { [1] = 100, [2] = 999 } } })
        ah = fake.LoadAuctionHouse()
        env:ClearPrinted()
    end)

    it("avisa al poner en venta un material que te sirve: texto, chat y sonido una vez", function()
        local sell = ah.CommoditiesSellFrame
        sell:SetItem(fake.Location(0, 1))
        local warning = sell.guardaMaterialesWarning
        assert.is_true(warning:IsShown())
        assert.are.equal("You need this for Blacksmithing!", warning:GetText())
        contains(env:Printed(), "[Objeto 100]")
        assert.are.same({ 8959 }, fake.Sounds())

        sell:SetItem(fake.Location(0, 1))
        assert.are.equal(1, #fake.Sounds()) -- mismo objeto en la misma visita: sin repetir
        env:Fire("AUCTION_HOUSE_CLOSED")
        sell:SetItem(fake.Location(0, 1))
        assert.are.equal(2, #fake.Sounds())
    end)

    it("quita el aviso al cambiar a un objeto que no es material o vaciar la ranura", function()
        local sell = ah.ItemSellFrame
        sell:SetItem(fake.Location(0, 1))
        assert.is_true(sell.guardaMaterialesWarning:IsShown())
        sell:SetItem(fake.Location(0, 2))
        assert.is_false(sell.guardaMaterialesWarning:IsShown())
        sell:SetItem(fake.Location(0, 1))
        sell:SetItem(nil)
        assert.is_false(sell.guardaMaterialesWarning:IsShown())
    end)

    it("con la opción apagada no avisa", function()
        ns.db.ahWarning = false
        ah.ItemSellFrame:SetItem(fake.Location(0, 1))
        assert.is_nil(ah.ItemSellFrame.guardaMaterialesWarning)
        assert.are.same({}, fake.Sounds())
    end)
end)

describe("/guardamat item", function()
    local env, ns

    before_each(function()
        env, ns = boot()
        env:ClearPrinted()
    end)

    it("acepta un ID o un enlace y muestra lo mismo que el tooltip", function()
        env:RunSlash("/guardamat item 100")
        contains(env:Printed(), "Keep: Blacksmithing 40")
        env:ClearPrinted()
        env:RunSlash("/guardamat item |cff9d9d9d|Hitem:100::::::::|h[Barra]|h|r")
        contains(env:Printed(), "Keep: Blacksmithing 40")
    end)

    it("explica si no es material o si no entiende el argumento", function()
        env:RunSlash("/guardamat item 999")
        contains(env:Printed(), ns.L.ITEM_UNKNOWN)
        env:RunSlash("/guardamat item cobre")
        contains(env:Printed(), ns.L.ITEM_BAD)
    end)

    it("debug enseña las profesiones leídas tal cual y como las entiende el addon", function()
        env:RunSlash("/guardamat debug")
        contains(env:Printed(), "GetProfessions[1]=1 Blacksmithing 40/75 skillLine=2938")
        contains(env:Printed(), "Profesiones: Blacksmithing 40/75")
    end)
end)

describe("Datos/Recetas.lua (generado)", function()
    local _, ns = Cliente.boot(TOC)

    it("tiene la forma que espera Materials: objeto -> profesión conocida -> umbrales de mayor a menor", function()
        local items = 0
        for item, uses in pairs(ns.MATERIALS) do
            items = items + 1
            assert.are.equal("number", type(item))
            for skill, grays in pairs(uses) do
                assert(ns.PROFESSIONS[skill], "profesión desconocida " .. tostring(skill) .. " en " .. item)
                assert.is_true(#grays > 0)
                for i = 2, #grays do
                    assert(grays[i] <= grays[i - 1], "umbrales desordenados en " .. item)
                end
            end
        end
        assert(items > 400, "muy pocos materiales: " .. items)
        for _, parent in pairs(ns.SKILL_PARENT) do
            assert(ns.PROFESSIONS[parent], "subhabilidad con padre desconocido " .. parent)
        end
        assert(ns.DATA_BUILD:match("^1%.%d+%.%d+%.%d+$"), ns.DATA_BUILD)
    end)

    it("incluye materiales clásicos conocidos y las secundarias", function()
        assert.is_not_nil(ns.MATERIALS[2840][BLACKSMITHING]) -- Barra de cobre
        assert.is_not_nil(ns.MATERIALS[2589][129]) -- Paño de lino -> Primeros auxilios
        assert.is_true(ns.PROFESSIONS[COOKING].secondary)
        assert.is_false(ns.PROFESSIONS[BLACKSMITHING].secondary)
        for skill in pairs(ns.PROFESSIONS) do
            assert(ns.PROFESSION_NAMES[skill], "sin nombre la profesión " .. skill)
        end
    end)
end)
