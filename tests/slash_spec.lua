-- Comando /guardamat (Slash.lua): config, debug, reset con confirmación y ayuda.
local WowEnv = require("cliente")

local TOC = "GuardaMateriales.toc"

local function contains(text, fragment)
    assert(text:find(fragment, 1, true), "no aparece «" .. fragment .. "» en:\n" .. text)
end

describe("/guardamat", function()
    local env, ns

    before_each(function()
        env, ns = WowEnv.boot(TOC)
        env:ClearPrinted()
    end)

    it("sin argumentos o con 'config' abre el panel del addon", function()
        env:RunSlash("/guardamat")
        env:RunSlash("/guardamat config")
        local id = ns.settingsCategory:GetID()
        assert.are.same({ id, id }, env:SettingsRegistry().opened)
    end)

    it("en combate no abre el panel y lo explica", function()
        env:SetCombat(true)
        env:RunSlash("/guardamat config")
        assert.are.same({}, env:SettingsRegistry().opened)
        contains(env:Printed(), ns.L.ERR_COMBAT)
    end)

    it("'debug' imprime el diagnóstico de soporte, sin avisos en Forever", function()
        env:RunSlash("/guardamat debug")
        local out = env:Printed()
        contains(out, ns.L.DEBUG_HEADER)
        contains(out, env:AddonName() .. " " .. ns.version .. " | enUS")
        contains(out, "Forever | 1.60.1.70291 Interface 16001 | WOW_PROJECT_ID=18")
        contains(out, "GameMode=Standard")
        contains(out, "HasSecretRestrictions=true")
        contains(out, "Restricciones activas: ninguna")
        contains(out, "InCombatLockdown=false")
        assert.is_nil(out:find("AVISO", 1, true))
    end)

    it("'debug' lista las restricciones activas", function()
        env:SetRestriction(env.Enum.AddOnRestrictionType.Encounter, env.Enum.AddOnRestrictionState.Active)
        env:RunSlash("/guardamat debug")
        contains(env:Printed(), "Restricciones activas: Encounter")
    end)

    it("'reset' sin confirmar no toca nada y explica cómo confirmar", function()
        env.GuardaMaterialesDB.markBags = false
        env:RunSlash("/guardamat reset")
        assert.is_false(env.GuardaMaterialesDB.markBags)
        contains(env:Printed(), ns.L.RESET_CONFIRM)
    end)

    it("'reset confirm' y 'reset confirmar' restauran los valores por defecto y los aplican", function()
        for _, word in ipairs({ "confirm", "confirmar" }) do
            env.GuardaMaterialesDB.markBags = false
            env.GuardaMaterialesDB.alts = true
            local chars = env.GuardaMaterialesDB.chars
            env:RunSlash("/guardamat reset " .. word)
            assert.is_true(env.GuardaMaterialesDB.markBags)
            assert.is_false(env.GuardaMaterialesDB.alts)
            assert.are.equal(chars, env.GuardaMaterialesDB.chars) -- los personajes no son opciones
            contains(env:Printed(), ns.L.RESET_DONE)
        end
        -- La misma tabla: los ajustes de Settings siguen enlazados a ella.
        assert.are.equal(env.GuardaMaterialesDB, ns.db)
    end)

    it("un subcomando desconocido muestra la ayuda", function()
        env:RunSlash("/guardamat foo")
        contains(env:Printed(), ns.L.SLASH_HELP)
    end)

    it("no distingue mayúsculas en el comando ni en el subcomando", function()
        env:RunSlash("/GUARDAMAT DEBUG")
        contains(env:Printed(), ns.L.DEBUG_HEADER)
    end)

    it("en un cliente en español responde en español", function()
        local envES, nsES = WowEnv.boot(TOC, { locale = "esES" })
        envES:RunSlash("/guardamat reset")
        contains(envES:Printed(), nsES.L.RESET_CONFIRM)
        contains(nsES.L.RESET_CONFIRM, "/guardamat reset confirmar")
    end)
end)
