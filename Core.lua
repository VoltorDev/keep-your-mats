local addonName, ns = ...
local L = ns.L

ns.name = addonName
ns.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or "dev"

-- SavedVariables. Solo se guardan strings, números, booleanos y tablas.
-- `schema` es la versión del formato: súbela y añade una migración cuando cambies su forma.
ns.DEFAULTS = {
    schema = 1,
    enabled = true,
    markBags = true, -- icono de la profesión en los huecos de bolsas y banco
    showDone = false, -- marca en gris los materiales que ya no te suben ninguna receta
    tooltip = true, -- líneas en el tooltip del objeto
    secondaries = true, -- Cocina, Primeros auxilios y Pesca cuentan aunque no estén aprendidas
    alts = false, -- cuentan también las profesiones de tus otros personajes
    ahWarning = true, -- aviso al poner en venta en la subasta un material que te sirve
    chars = {}, -- profesiones de cada personaje (Identity.GetCharEntry), para la opción alts
}
ns.CHAR_DEFAULTS = {
    schema = 1,
}

-- MIGRATIONS[n] convierte la base de datos de cuenta del esquema n-1 al n; CHAR_MIGRATIONS hace lo
-- mismo con la de personaje (cada una tiene su propio `schema`). Ejemplo:
-- [2] = function(db) db.newName = db.oldName; db.oldName = nil end,
local MIGRATIONS = {}
local CHAR_MIGRATIONS = {}

local function MergeDefaults(db, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(db[key]) ~= "table" then
                db[key] = {}
            end
            MergeDefaults(db[key], value)
        elseif db[key] == nil then
            db[key] = value
        end
    end
end

-- Una tabla guardada con un esquema MÁS NUEVO (versión posterior del addon) no se toca:
-- el bucle no se ejecuta y solo se completan los valores por defecto que falten.
local function PrepareDB(saved, defaults, migrations)
    if type(saved) ~= "table" then
        saved = {}
    end
    if next(saved) ~= nil then
        for version = (saved.schema or 1) + 1, defaults.schema do
            local migrate = migrations[version]
            if migrate then
                migrate(saved)
            end
            saved.schema = version
        end
    end
    MergeDefaults(saved, defaults)
    return saved
end

-- Restaura las opciones; las profesiones conocidas de cada personaje no son opciones y se conservan.
function ns:ResetDB()
    local chars = GuardaMaterialesDB.chars
    wipe(GuardaMaterialesDB)
    MergeDefaults(GuardaMaterialesDB, self.DEFAULTS)
    GuardaMaterialesDB.chars = type(chars) == "table" and chars or {}
end

function ns:Print(...)
    print("|cff33ff99" .. L.ADDON_TITLE .. "|r:", ...)
end

-- Módulos: cada fichero crea el suyo con ns:NewModule(nombre) y define, si los necesita,
-- OnInitialize (SavedVariables ya cargadas) y OnEnable (personaje en el mundo, PLAYER_LOGIN).
local modules = {}
ns.Modules = {} -- por nombre, para que un módulo use otro (Slash usa Tooltip)

function ns:NewModule(name)
    local module = { name = name }
    modules[#modules + 1] = module
    ns.Modules[name] = module
    return module
end

local function CallModules(method)
    for _, module in ipairs(modules) do
        if module[method] then
            module[method](module)
        end
    end
end

-- Despachador de eventos globales: varios manejadores por evento, cada uno recibe (ns, evento, ...).
-- Para eventos de una unidad concreta, usa RegisterUnitEvent en un marco propio del módulo.
local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns:RegisterEvent(event, handler)
    if not handlers[event] then
        handlers[event] = {}
        eventFrame:RegisterEvent(event)
    end
    table.insert(handlers[event], handler)
end

-- Quita un manejador concreto; el marco deja de escuchar el evento cuando no queda ninguno.
function ns:UnregisterEvent(event, handler)
    local list = handlers[event]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == handler then
            table.remove(list, i)
        end
    end
    if #list == 0 then
        handlers[event] = nil
        eventFrame:UnregisterEvent(event)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then
        return
    end
    -- Copia: un manejador puede desregistrarse mientras se recorre la lista.
    local snapshot = { unpack(list) }
    for i = 1, #snapshot do
        snapshot[i](ns, event, ...)
    end
end)

local function OnAddonLoaded(self, event, loadedName)
    if loadedName ~= addonName then
        return
    end
    self:UnregisterEvent(event, OnAddonLoaded)
    GuardaMaterialesDB = PrepareDB(GuardaMaterialesDB, self.DEFAULTS, MIGRATIONS)
    GuardaMaterialesCharDB = PrepareDB(GuardaMaterialesCharDB, self.CHAR_DEFAULTS, CHAR_MIGRATIONS)
    self.db = GuardaMaterialesDB
    self.charDB = GuardaMaterialesCharDB
    CallModules("OnInitialize")
end
ns:RegisterEvent("ADDON_LOADED", OnAddonLoaded)

local function OnPlayerLogin(self, event)
    self:UnregisterEvent(event, OnPlayerLogin)
    CallModules("OnEnable")
    self:Print(self.version, L.LOADED)
end
ns:RegisterEvent("PLAYER_LOGIN", OnPlayerLogin)

-- Notifica a los módulos que han cambiado las opciones.
-- Las opciones cambian qué cuenta como material (secundarias, alts): se vacía la caché antes.
function ns:ApplySettings()
    self.Materials.Invalidate()
    CallModules("ApplySettings")
end
