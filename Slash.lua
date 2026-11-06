local addonName, ns = ...
local L = ns.L

-- Volcado para soporte: todo lo necesario para reproducir un problema en otro cliente.
function ns:PrintDiagnostics()
    local client = self.Client
    self:Print(L.DEBUG_HEADER)
    print(("  %s %s | %s | datos %s"):format(addonName, self.version, GetLocale(), tostring(self.DATA_BUILD)))
    print("  " .. client.Describe())
    print(
        ("  GameMode=%s ForeverExperiencePreset=%s"):format(
            tostring(client.GetGameModeName()),
            tostring(client.GetExperiencePresetName())
        )
    )
    print("  HasSecretRestrictions=" .. tostring(client.HasSecretRestrictions()))
    if Enum.AddOnRestrictionType then
        local active = {}
        for name, value in pairs(Enum.AddOnRestrictionType) do
            if self.IsRestrictionActive(value) then
                active[#active + 1] = name
            end
        end
        print("  Restricciones activas: " .. (#active > 0 and table.concat(active, ", ") or "ninguna"))
    end
    print(("  InCombatLockdown=%s"):format(tostring(InCombatLockdown())))
    -- Lo que devuelve el cliente tal cual, para contrastar con lo que el addon entiende.
    local slots = { n = select("#", GetProfessions()), GetProfessions() }
    for i = 1, slots.n do
        local index = slots[i]
        if index then
            local name, _, rank, maxRank, _, _, skillLine = GetProfessionInfo(index)
            print(
                ("  GetProfessions[%d]=%s %s %s/%s skillLine=%s"):format(
                    i,
                    tostring(index),
                    tostring(name),
                    tostring(rank),
                    tostring(maxRank),
                    tostring(skillLine)
                )
            )
        end
    end
    local known = {}
    for skill, p in pairs(self.professions or {}) do
        known[#known + 1] = ("%s %d/%d"):format(ns.PROFESSION_NAMES[skill] or skill, p.rank, p.maxRank)
    end
    table.sort(known)
    print("  Profesiones: " .. (#known > 0 and table.concat(known, ", ") or "ninguna"))
    local chars = 0
    for _ in pairs(self.db.chars or {}) do
        chars = chars + 1
    end
    print(("  Personaje=%s; personajes recordados=%d"):format(tostring(self.charKey), chars))
    for _, warning in ipairs(client.GetWarnings()) do
        print("  AVISO: " .. warning)
    end
end

-- /guardamat item <enlace o ID>: lo mismo que el tooltip, en el chat.
local function PrintItem(argument)
    local itemID = tonumber(argument) or tonumber(argument:match("item:(%d+)"))
    if not itemID then
        ns:Print(L.ITEM_BAD)
        return
    end
    local lines = ns.Modules.Tooltip.Lines(itemID)
    if #lines == 0 then
        ns:Print(L.ITEM_UNKNOWN)
        return
    end
    ns:Print(L.TOOLTIP_HEADER .. " (" .. itemID .. "):")
    for _, line in ipairs(lines) do
        print("  " .. line)
    end
end

-- /guardamat plan [chat] [profesión] [hasta | max]: ventana del plan de subida (o el plan en el chat).
local function PlanCommand(argument)
    local Plan = ns.Modules.Plan
    local words = {}
    for word in argument:gmatch("%S+") do
        words[#words + 1] = word
    end
    local toChat = words[1] and words[1]:lower() == "chat"
    if toChat then
        table.remove(words, 1)
    end
    local target
    local last = words[#words]
    if last and (tonumber(last) or last:lower() == "max") then
        target = tonumber(last) or "max"
        table.remove(words, #words)
    end
    local name = table.concat(words, " ")
    local skill = Plan.FindSkill(name)
    if name ~= "" and not skill then
        ns:Print(L.PLAN_UNKNOWN_SKILL:format(name))
        return
    end
    if toChat then
        skill = skill or Plan.Skills()[1]
        if not skill then
            ns:Print(L.PLAN_NO_SKILLS)
            return
        end
        for _, line in ipairs(Plan.Lines(skill, target or "cap")) do
            print(line)
        end
        return
    end
    ns:OpenPlan(skill, target)
end

SLASH_GUARDAMATERIALES1 = "/guardamat"
SLASH_GUARDAMATERIALES2 = "/guardamateriales"
SlashCmdList.GUARDAMATERIALES = function(message)
    local command, argument = message:match("^(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" or command == "config" then
        ns:OpenSettings()
    elseif command == "debug" then
        ns:PrintDiagnostics()
    elseif command == "item" then
        PrintItem(argument)
    elseif command == "plan" then
        PlanCommand(argument)
    elseif command == "reset" then
        if argument == "confirm" or argument == "confirmar" then
            ns:ResetDB()
            ns:ApplySettings()
            ns:Print(L.RESET_DONE)
        else
            ns:Print(L.RESET_CONFIRM)
        end
    else
        ns:Print(L.SLASH_HELP)
    end
end
