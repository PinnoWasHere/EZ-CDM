-- Nothing in EZ-CDM plays the game for the player (Blizzard's terms): no cast, item
-- use, target, attack, movement, chat, emote, macro or key binding. EZ-CDM only
-- changes what the player sees and hears. tests/test_noplay.lua checks every shipped
-- file; the private project runs the same check on its dev addon.

local N = {}

-- The game's calls that act for the player, by name.
N.BANNED = {
    "CastSpell", "CastSpellByName", "CastSpellByID", "CastShapeshiftForm", "CastPetAction",
    "UseAction", "UseItemByName", "UseInventoryItem", "UseContainerItem", "UseToy", "UseToyByName",
    "RunMacro", "RunMacroText", "CreateMacro", "EditMacro", "DeleteMacro",
    "TargetUnit", "TargetNearestEnemy", "TargetNearestFriend", "TargetLastTarget", "AssistUnit", "FocusUnit",
    "ClearTarget", "AttackTarget", "StartAttack", "StopAttack", "PetAttack",
    "SpellStopCasting", "SpellStopTargeting", "SpellTargetUnit", "CameraOrSelectOrMoveStart",
    "MoveForwardStart", "MoveBackwardStart", "TurnLeftStart", "TurnRightStart", "StrafeLeftStart",
    "StrafeRightStart", "JumpOrAscendStart", "ToggleAutoRun", "InteractUnit",
    "SendChatMessage", "DoEmote", "SetRaidTarget",
    "SetBinding", "SetBindingSpell", "SetBindingItem", "SetBindingMacro", "SetBindingClick",
    "SetOverrideBinding", "SetOverrideBindingSpell", "SetOverrideBindingItem", "SetOverrideBindingMacro",
    "SetOverrideBindingClick",
}

-- A file's code with its comments taken out, so a comment may name a call.
local function code(text)
    text = text:gsub("%-%-%[(=*)%[.-%]%1%]", "")
    return (text:gsub("%-%-[^\n]*", ""))
end

-- The banned names a file's text uses, as "name (line n)", in order.
function N.Scan(text)
    local found = {}
    local body = code(text)
    local n = 0
    for lineText in (body .. "\n"):gmatch("([^\n]*)\n") do
        n = n + 1
        for _, name in ipairs(N.BANNED) do
            if lineText:find("%f[%w_]" .. name .. "%f[^%w_]") then found[#found + 1] = name .. " (line " .. n .. ")" end
        end
    end
    return found
end

-- Every .lua file a .toc loads, as paths beside it.
function N.TocFiles(toc)
    local dir = toc:match("^(.*[/\\])") or ""
    local out = {}
    local fh = assert(io.open(toc, "rb"))
    for raw in fh:lines() do
        local f = raw:gsub("\r", ""):gsub("^%s+", ""):gsub("%s+$", "")
        if f ~= "" and not f:find("^#") and f:find("%.lua$") then out[#out + 1] = dir .. f:gsub("\\", "/") end
    end
    fh:close()
    return out
end

-- path -> its banned names, for each file that uses any.
function N.Check(paths)
    local bad = {}
    for _, p in ipairs(paths) do
        local fh = assert(io.open(p, "rb"))
        local found = N.Scan(fh:read("*a"))
        fh:close()
        if #found > 0 then bad[p] = found end
    end
    return bad
end

return N
