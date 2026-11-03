local _, ns = ...

-- Decide si un objeto es material de las profesiones que interesan y si aún sirve para subirlas.
-- Una receta sube habilidad mientras tu rango esté por debajo de su umbral gris
-- (TrivialSkillLineRankHigh, guardado por receta en ns.MATERIALS). Un umbral 0 es una receta sin
-- datos de dificultad: cuenta como uso, no como subida.
local Materials = {}
ns.Materials = Materials

local cache = {}

function Materials.Invalidate()
    wipe(cache)
end

function Materials.SameProfessions(a, b)
    a, b = a or {}, b or {}
    for skill, p in pairs(a) do
        local q = b[skill]
        if not q or q.rank ~= p.rank or q.maxRank ~= p.maxRank then
            return false
        end
    end
    for skill in pairs(b) do
        if not a[skill] then
            return false
        end
    end
    return true
end

-- Profesiones que se pueden marcar como «pienso aprender»: las primarias (Venenos es de clase y las
-- secundarias ya tienen su propia opción).
function Materials.Plannable()
    local list = {}
    for skill, def in pairs(ns.PROFESSIONS) do
        if not def.secondary and skill ~= 40 then
            list[#list + 1] = skill
        end
    end
    table.sort(list, function(a, b)
        return (ns.PROFESSION_NAMES[a] or "") < (ns.PROFESSION_NAMES[b] or "")
    end)
    return list
end

function Materials.PlannedKey(skill)
    return "p" .. skill
end

-- Perfil que se evalúa: las profesiones aprendidas; las que piensas aprender (`planned`, tabla
-- "p<skillLine>" = true) y, si se pide, las secundarias sin aprender, ambas con rango 0: todas sus
-- recetas suben.
function Materials.BuildProfile(professions, includeSecondaries, planned)
    local profile = {}
    for skill, p in pairs(professions or {}) do
        profile[skill] = { rank = p.rank or 0, learned = true }
    end
    for skill in pairs(ns.PROFESSIONS) do
        if not profile[skill] and planned and planned[Materials.PlannedKey(skill)] == true then
            profile[skill] = { rank = 0, learned = false, planned = true }
        end
    end
    if includeSecondaries then
        for skill, def in pairs(ns.PROFESSIONS) do
            if def.secondary and not profile[skill] then
                profile[skill] = { rank = 0, learned = false }
            end
        end
    end
    return profile
end

-- El perfil del personaje con las opciones actuales.
function Materials.MyProfile()
    return Materials.BuildProfile(ns.professions, ns.db.secondaries, ns.charDB and ns.charDB.planned)
end

-- nil si el objeto no es material de ninguna profesión del perfil. Si lo es:
-- { keep, reach, entries = { { skill, rank, learned, useful, total, maxGray, via } } }, con las
-- profesiones en las que sirve primero. `via` = { item, reach }: un material que esa profesión
-- fabrica con este y que aún te sirve (Paño de lino -> Rollo de paño de lino), aunque la receta del
-- intermedio ya sea gris. `reach` = hasta qué rango te sirve, contando los intermedios.
local function EvaluateIn(itemID, profile, visiting)
    local uses = ns.MATERIALS[itemID]
    if not uses then
        return nil
    end
    visiting[itemID] = true -- corta ciclos (A fabrica B y B fabrica A)
    local produces = ns.PRODUCES and ns.PRODUCES[itemID]
    local result
    for skill, grays in pairs(uses) do
        local p = profile[skill]
        if p then
            local useful, maxGray = 0, 0
            for i = 1, #grays do
                local gray = grays[i]
                if gray > p.rank then
                    useful = useful + 1
                end
                if gray > maxGray then
                    maxGray = gray
                end
            end
            local entry = {
                skill = skill,
                rank = p.rank,
                learned = p.learned,
                planned = p.planned,
                useful = useful,
                total = #grays,
                maxGray = maxGray,
                reach = useful > 0 and maxGray or 0,
            }
            for _, product in ipairs(produces and produces[skill] or {}) do
                if not visiting[product] then
                    local sub = EvaluateIn(product, profile, visiting)
                    if sub and sub.keep and (not entry.via or sub.reach > entry.via.reach) then
                        entry.via = { item = product, reach = sub.reach }
                    end
                end
            end
            if entry.via and entry.via.reach > entry.reach then
                entry.reach = entry.via.reach
            end
            result = result or { keep = false, reach = 0, entries = {} }
            result.entries[#result.entries + 1] = entry
            if useful > 0 or entry.via then
                result.keep = true
            end
            if entry.reach > result.reach then
                result.reach = entry.reach
            end
        end
    end
    visiting[itemID] = nil
    if result then
        table.sort(result.entries, function(x, y)
            local xs, ys = x.useful > 0 or x.via ~= nil, y.useful > 0 or y.via ~= nil
            if xs ~= ys then
                return xs
            end
            if x.learned ~= y.learned then
                return x.learned
            end
            return x.skill < y.skill
        end)
    end
    return result
end

function Materials.Evaluate(itemID, profile)
    return EvaluateIn(itemID, profile, {})
end

-- Otros personajes con las mismas reglas (no se comparten objetos entre Hardcore y normal) a los
-- que el material aún les sirve: { { key, skill, rank, learned, planned, useful, via } }.
function Materials.EvaluateAlts(itemID)
    local out = {}
    local uses = ns.MATERIALS[itemID]
    if not uses or not ns.db then
        return out
    end
    local me = ns.charKey and ns.db.chars[ns.charKey]
    local ruleset = me and me.ruleset
    for key, entry in pairs(ns.db.chars) do
        if key ~= ns.charKey and type(entry) == "table" and entry.professions then
            if ruleset == nil or entry.ruleset == nil or entry.ruleset == ruleset then
                local result =
                    Materials.Evaluate(itemID, Materials.BuildProfile(entry.professions, false, entry.planned))
                for _, e in ipairs(result and result.entries or {}) do
                    if e.useful > 0 or e.via then
                        out[#out + 1] = {
                            key = key,
                            skill = e.skill,
                            rank = e.rank,
                            learned = e.learned,
                            planned = e.planned,
                            useful = e.useful,
                            via = e.via,
                        }
                    end
                end
            end
        end
    end
    table.sort(out, function(x, y)
        if x.key ~= y.key then
            return x.key < y.key
        end
        return x.skill < y.skill
    end)
    return out
end

-- Estado para marcar el objeto: "keep" (te sirve), "done" (es material tuyo pero ya no te sube) o
-- nil; y la profesión cuyo icono se pinta. Con la opción de alts, un material que solo le sirve a
-- otro personaje también es "keep". Se cachea por objeto hasta que cambian profesiones u opciones.
function Materials.Status(itemID)
    local cached = cache[itemID]
    if cached ~= nil then
        return cached.status or nil, cached.skill
    end
    local db = ns.db
    local result = Materials.Evaluate(itemID, Materials.MyProfile())
    local status, skill
    if result and result.keep then
        status, skill = "keep", result.entries[1].skill
    else
        if db.alts then
            local alts = Materials.EvaluateAlts(itemID)
            if alts[1] then
                status, skill = "keep", alts[1].skill
            end
        end
        if not status and result then
            status, skill = "done", result.entries[1].skill
        end
    end
    cache[itemID] = { status = status or false, skill = skill }
    return status, skill
end

function Materials.Icon(skill)
    local def = ns.PROFESSIONS[skill]
    return def and def.icon or 134400 -- INV_Misc_QuestionMark
end
