local _, ns = ...
local module = ns:NewModule("Professions")

-- Profesiones del personaje: skillLine base -> { rank, maxRank }. Solo cuenta las que hay en
-- ns.PROFESSIONS (Datos/Recetas.lua). Ninguna de estas APIs devuelve secretos (economia.md), pero
-- se pasan por ns.Readable por si un parche lo cambia: un rango ilegible cuenta como 0.
local Professions = {}
ns.Professions = Professions

local CHILD = {} -- profesión base -> subhabilidad de Forever (2938 «Blacksmithing» -> 164)

local function Pack(...)
    return { n = select("#", ...), ... }
end

local function Number(value)
    local readable = ns.Readable(value, 0)
    return type(readable) == "number" and readable or 0
end

local function Base(skillLine)
    return ns.SKILL_PARENT[skillLine] or skillLine
end

-- GetProfessions() da hasta siete índices con huecos nil; Forever pone Primeros auxilios en 3.º
-- lugar (Camelot/Blizzard_ProfessionsBook.lua:21). Venenos no está ahí: sale de C_SkillInfo.
function Professions.Read()
    local known = {}
    local slots = Pack(GetProfessions())
    for i = 1, slots.n do
        local index = slots[i]
        if index then
            local _, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
            local skill = Base(Number(skillLine))
            if ns.PROFESSIONS[skill] then
                known[skill] = { rank = Number(rank), maxRank = Number(maxRank) }
            end
        end
    end
    if C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID then
        for skill in pairs(ns.PROFESSIONS) do
            if not known[skill] then
                local info = C_SkillInfo.GetSkillLineInfoByID(skill)
                if not info and CHILD[skill] then
                    info = C_SkillInfo.GetSkillLineInfoByID(CHILD[skill])
                end
                if info and not info.isHeader and Number(info.maxRank) > 0 then
                    known[skill] = { rank = Number(info.rank), maxRank = Number(info.maxRank) }
                end
            end
        end
    end
    return known
end

-- Copia en la entrada de cuenta las profesiones que este personaje piensa aprender, para que otro
-- personaje las vea con la opción de alts (la SV por personaje solo la lee el propio personaje).
local function SavePlanned(entry)
    local planned = {}
    for key, on in pairs(ns.charDB.planned or {}) do
        if on == true then
            planned[key] = true
        end
    end
    entry.planned = planned
end

-- Lee las profesiones, las guarda en la entrada del personaje (para la opción de alts) y avisa a
-- los módulos si han cambiado.
function Professions.Refresh()
    local known = Professions.Read()
    local changed = not ns.Materials.SameProfessions(ns.professions, known)
    ns.professions = known
    local entry = ns.Identity.GetCharEntry(ns.db)
    if entry then
        entry.professions = known
        SavePlanned(entry)
        local _, class = UnitClass("player")
        entry.class = ns.Readable(class, entry.class)
        ns.charKey = ns.Identity.GetCharacterKey()
    end
    if changed then
        ns.Materials.Invalidate()
        ns:ApplySettings()
    end
end

-- SKILL_LINES_CHANGED llega en ráfagas (al entrar, al subir un punto, al aprender): se agrupa.
local pending = false
local function Schedule()
    if pending then
        return
    end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        Professions.Refresh()
    end)
end

function module:OnInitialize()
    for child, parent in pairs(ns.SKILL_PARENT) do
        CHILD[parent] = child
    end
    ns.professions = {}
end

function module:ApplySettings()
    local entry = ns.charKey and ns.db.chars[ns.charKey]
    if entry then
        SavePlanned(entry)
    end
end

function module:OnEnable()
    Professions.Refresh()
    ns:RegisterEvent("SKILL_LINES_CHANGED", Schedule)
    -- Solo como aviso de que algo ha cambiado: su texto es secreto en lockdown y no se lee.
    ns:RegisterEvent("CHAT_MSG_SKILL", Schedule)
end
