-- Panel de opciones (Config.lua) con la API Settings: se registra DESPUÉS de cargar las
-- SavedVariables, queda enlazado a esa misma tabla y cada cambio se guarda y se aplica.
local WowEnv = require("cliente")

local TOC = "GuardaMateriales.toc"
local COPPER_BAR = 2840 -- material de Herrería, Minería, Ingeniería y Peletería

local OPTIONS = {
    Enabled = "enabled",
    MarkBags = "markBags",
    ShowDone = "showDone",
    Tooltip = "tooltip",
    Secondaries = "secondaries",
    Alts = "alts",
    AHWarning = "ahWarning",
}

local function countKeys(t)
    local n = 0
    for _ in pairs(t) do
        n = n + 1
    end
    return n
end

describe("opciones en Settings", function()
    it("no registra nada al cargar los ficheros; sí tras el ADDON_LOADED propio", function()
        local env = WowEnv.new()
        env.GuardaMaterialesDB = { schema = 1, alts = true }
        local ns = env:LoadToc(TOC) or error("el addon no cargó")
        local registry = env:SettingsRegistry()
        assert.are.equal(0, countKeys(registry.settings))

        env:Fire("ADDON_LOADED", env:AddonName(), false)
        assert.are.equal(countKeys(OPTIONS), countKeys(registry.settings))
        assert.are.equal(1, #registry.addOnCategories)
        assert.are.equal(ns.settingsCategory, registry.addOnCategories[1])
        assert.are.equal(ns.L.ADDON_TITLE, ns.settingsCategory:GetName())

        for suffix, key in pairs(OPTIONS) do
            local setting = registry.settings[env:AddonName() .. "_" .. suffix]
            assert(setting ~= nil, "falta el ajuste " .. suffix)
            assert.are.equal(env.GuardaMaterialesDB, setting.variableTbl) -- la tabla ya cargada, no otra
            assert.are.equal(key, setting.variableKey)
            assert.are.equal("boolean", setting:GetVariableType())
            assert.are.equal("boolean", type(ns.DEFAULTS[key]), "sin valor por defecto: " .. key)
        end
        assert.is_true(registry.settings[env:AddonName() .. "_Alts"]:GetValue()) -- no pisa lo guardado
    end)

    it("crea una casilla por opción", function()
        local env = WowEnv.boot(TOC)
        local controls = env:SettingsRegistry().controls
        assert.are.equal(countKeys(OPTIONS), #controls)
        for _, control in ipairs(controls) do
            assert.are.equal("Checkbox", control.kind)
        end
    end)

    it("cambiar una opción la guarda y la aplica a las bolsas abiertas", function()
        local env = WowEnv.boot(TOC, {
            professions = { { skillLine = 2938, rank = 50, maxRank = 75, name = "Blacksmithing" } },
            bags = { [0] = { [1] = COPPER_BAR } },
        })
        env.ContainerFrame1:Show()
        env.ContainerFrame1:UpdateItems()
        local button = WowEnv.fake(env).Button("ContainerFrame1", 1)
        assert.is_not_nil(WowEnv.fake(env).Mark(button))

        local settings = env:SettingsRegistry().settings
        settings[env:AddonName() .. "_MarkBags"]:SetValue(false)
        assert.is_false(env.GuardaMaterialesDB.markBags)
        assert.is_nil(WowEnv.fake(env).Mark(button))

        settings[env:AddonName() .. "_MarkBags"]:SetValue(true)
        assert.is_not_nil(WowEnv.fake(env).Mark(button))
        settings[env:AddonName() .. "_Enabled"]:SetValue(false)
        assert.is_nil(WowEnv.fake(env).Mark(button))
    end)

    it("un valor de otro tipo se rechaza, como en el cliente", function()
        local env = WowEnv.boot(TOC)
        local alts = env:SettingsRegistry().settings[env:AddonName() .. "_Alts"]
        assert.has_error(function()
            alts:SetValue("sí")
        end)
        assert.is_false(env.GuardaMaterialesDB.alts)
    end)
end)
