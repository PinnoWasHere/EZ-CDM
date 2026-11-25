local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- docs/tasks/w1-totem-mana.md: one "While my totem is up" moment on a totem showing its
-- own time, and the short-of-power words only on a spell that costs, in its own power
-- (EZ-CDM/AuraLinks.lua costs, from SpellPower by tools/make_aura_links.py).

local SEARING, LIGHTNING_BOLT, KICK, EXECUTE, CHARGE, BATTLE_STANCE = 3599, 403, 1766, 5308, 100, 2457
local GHOST_WOLF, AUTO_ATTACK, EVISCERATE, SKULL_BASH, HEALTH_FUNNEL = 2645, 6603, 2098, 410176, 755

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A class logged in with spell id placed as an icon: a catalogue spell by its row, any
-- other added by its id as the editor adds one.
local function place(class, id)
    local w = W.Build(class)
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    local key
    local r = w.Row(id)
    if r and r.category == W.ESSENTIAL then
        key = CW.ID(r.spell, r.category)
    else
        stub.knownSpells[id] = true
        stub.spells[id] = stub.spells[id] or { name = "Spell " .. id }
        key = assert(Ed.KeyForID("spell", tostring(id)))
    end
    D.AddPiece(D.Ensure(1), key, "icon", 0, 0)
    w.Pass()
    return w, key
end

local function lit(w, key, id)
    for _, v in pairs(w.ns.Conditions.Lit(key) or {}) do
        if v == id then return true end
    end
    return false
end

local function moments(G, kind)
    local out = {}
    for _, m in ipairs(G.Words(kind, { more = true })) do out[m.moment] = table.concat(m.actions, ",") end
    return out
end

local function sound(w)
    local values, order = w.ns.Bridge.SoundChoices()
    for _, k in ipairs(order) do
        if k ~= "none" and not tostring(k):find("^head:") and values[k] then return k end
    end
end

-- ---------------------------------------------------------------------
-- 1. While my totem is up
-- ---------------------------------------------------------------------

T.test("totem merge: Searing Totem shows one While my totem is up, with Daylight UI's rows and the glow and sound", function()
    local w, key = place("SHAMAN", SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy(kind.totemTime, "Daylight UI times the standing totem as its cooldown")
    local m = moments(G, kind)
    T.isnil(m.totemUp, "no second totem moment")
    T.eq(m.cooldown, "show,fade,hide,glow,gray,color,sound,nosweep,nogcd,flash,pop,shake,sparkle,screen,pulse,border,"
        .. "halo,text,swap", "the union, in action order, totemUp's looks too")
    T.eq((G.MomentWords("cooldown", nil, kind)), "While my totem is up")
    T.eq((G.MomentWords("ready", nil, kind)), "When my totem is down", "kept")
    T.eq((G.MomentWords("almost", nil, kind)), "When my totem is almost gone", "kept")
    T.eq(G.Describe({ moment = "cooldown", action = "glow" }, kind), "While my totem is up, glow.")
    -- Each action still writes its own store: Daylight UI's row, or totemUp's field.
    local fields, problems = G.Compile({ lines = { { moment = "cooldown", action = "fade" },
        { moment = "cooldown", action = "glow" } } }, kind)
    T.eq(#problems, 0)
    T.eq(fields.onCd, "fade", "Daylight UI's row")
    T.eq(fields["ez:totemUp:glow"], true, "EZ-CDM's condition")
    T.isnil(fields.readyGlow)
    -- The merged glow is EZ-CDM's line: it takes "and" clauses.
    T.eq(G.LineCondition({ moment = "cooldown", action = "glow" }), "totemUp")
    T.isnil(G.LineCondition({ moment = "cooldown", action = "fade" }))
    T.truthy(G.TakesClauses({ moment = "cooldown", action = "glow" }))
    noErrors()
end)

T.test("totem merge: rules round-trip through the merged moment", function()
    local w, key = place("SHAMAN", SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local snd = sound(w)
    local rules = { lines = {
        { moment = "cooldown", action = "fade", value = 0.25 },
        { moment = "cooldown", action = "glow", value = { 1, 0, 0 } },
        { moment = "cooldown", action = "sound", value = snd },
        { moment = "ready", action = "glow" },
    }, group = {}, forms = {} }
    local fields, problems = G.Compile(rules, kind)
    T.eq(#problems, 0, "compiles")
    local back, bp = G.Decompile(fields, kind)
    T.eq(#bp, 0, "decompiles")
    T.deq(back.lines, {
        { moment = "ready", action = "glow" },
        { moment = "cooldown", action = "fade", value = 0.25 },
        { moment = "cooldown", action = "glow", value = { 1, 0, 0 } },
        { moment = "cooldown", action = "sound", value = snd },
    }, "canonical order, the merged lines under cooldown")
    -- Written and read back through the layout and EZ-CDM's store.
    T.truthy(w.ns.Draft.Write(key, rules))
    w.Pass()
    T.deq(w.ns.Draft.Rules(key).lines, back.lines, "the saved rules read the same")
    T.deq(w.ns.Conditions.Rule(key), { totemUp = { glow = { value = { 1, 0, 0 } }, sound = { value = snd } } },
        "the glow and sound stay in totemUp's store")
    noErrors()
end)

T.test("totem merge: a rule saved as While my totem stands loads into the merged moment, lit the same", function()
    local w, key = place("SHAMAN", SEARING)
    local G = w.ns.Grammar
    -- The drawer before the merge wrote the totemUp moment.
    T.truthy(w.ns.Draft.Write(key, { lines = { { moment = "totemUp", action = "glow" } } }), "the old line saves")
    w.Pass()
    local saved = w.ns.Conditions.Rule(key)
    T.deq(saved, { totemUp = { glow = true } }, "the store the old rule left")
    local rules, problems = w.ns.Draft.Rules(key)
    T.eq(#problems, 0)
    T.deq(rules.lines, { { moment = "cooldown", action = "glow" } }, "reads as While my totem is up, glow")
    T.eq(G.Describe(rules.lines[1], G.Kind(key)), "While my totem is up, glow.")
    local slot = w.AB.CdmCustom.SlotOf(SEARING)
    w.Totem(slot, SEARING)
    T.truthy(lit(w, key, "totemUp:glow"), "lit while it stands")
    w.Totem(slot, nil)
    T.falsy(lit(w, key, "totemUp:glow"), "dark once it's gone")
    -- Saving the merged rules back changes nothing.
    T.truthy(w.ns.Draft.Write(key, rules))
    w.Pass()
    T.deq(w.ns.Conditions.Rule(key), saved, "store unchanged")
    w.Totem(slot, SEARING)
    T.truthy(lit(w, key, "totemUp:glow"), "still lit while it stands")
    noErrors()
end)

T.test("totem merge: a totem not showing its own time keeps its totem moment, in the merged words", function()
    local w, key = place("SHAMAN", SEARING)
    local G = w.ns.Grammar
    local kind = setmetatable({ totemTime = false }, { __index = G.Kind(key) })
    local m = moments(G, kind)
    T.truthy(m.totemUp, "its own moment, since cooling down isn't the totem there")
    T.falsy(G.Fits(kind, "cooldown", "glow"))
    T.eq((G.MomentWords("totemUp", nil, kind)), "While my totem is up")
    T.eq(G.ClauseWords("totemUp"), "my totem is up")
    local fields = G.Compile({ lines = { { moment = "totemUp", action = "glow" } } }, kind)
    T.deq(G.Decompile(fields, kind).lines, { { moment = "totemUp", action = "glow" } })
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. Short of power, from SpellPower
-- ---------------------------------------------------------------------

T.test("cost data: SpellPower rows give each spell its powers, and free spells none", function()
    local w = W.Build("SHAMAN")
    local L = w.ns.AuraLinks
    T.deq(L.costs[LIGHTNING_BOLT], { "mana" }, "row 169133: 15, type 0")
    T.deq(L.costs[KICK], { "energy" }, "row 169820: 25, type 3")
    T.deq(L.costs[EXECUTE], { "rage" }, "row 172234: 150, type 1")
    T.deq(L.costs[GHOST_WOLF], { "mana" }, "row 171027: 100, type 0")
    T.deq(L.costs[EVISCERATE], { "energy", "combo points" }, "rows 170004 (35, type 3) and 310621 (1, type 4)")
    T.deq(L.costs[SKULL_BASH], { "energy", "rage" }, "rows 305589 (Cat Form) and 305656 (Bear Form)")
    T.deq(L.costs[HEALTH_FUNNEL], { "health" }, "row 169634: type -2")
    T.truthy(L.spells[CHARGE] and L.spells[BATTLE_STANCE], "listed")
    T.isnil(L.costs[CHARGE], "row 169341 costs 0")
    T.isnil(L.costs[BATTLE_STANCE], "row 171047 costs 0")
    T.isnil(L.spells[AUTO_ATTACK], "Auto Attack isn't a listed class spell")
    noErrors()
end)

T.test("cost words: a free spell has no short words, no blue wash and no Mana check", function()
    local w, key = place("WARRIOR", CHARGE)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.cost, false)
    local m = moments(G, kind)
    T.isnil(m.short, "no When I don't have enough rage")
    T.falsy(G.Fits(kind, "short", "blue"), "no blue wash")
    for _, r in ipairs(G.Recipes(kind)) do T.truthy(r ~= "manaCheck", "no Mana check") end
    T.falsy(w.ns.Conditions.FitsKind("noMana", kind), "no clause")
    local _, problems = G.Compile({ lines = { { moment = "short", action = "blue" } } }, kind)
    T.eq(problems[1] and problems[1].code, "kind", "a saved blue wash reads as one that doesn't fit")
    noErrors()
end)

T.test("cost words: the short words name the spell's own power, whatever the player's bar", function()
    local cases = {
        { "SHAMAN", LIGHTNING_BOLT, "mana" },
        { "SHAMAN", KICK, "energy" },
        { "SHAMAN", EVISCERATE, "energy" },
        { "SHAMAN", SKULL_BASH, "energy or rage" },
        { "WARLOCK", HEALTH_FUNNEL, "health" },
        { "WARRIOR", EXECUTE, "rage" },
    }
    local washed = 0
    for _, c in ipairs(cases) do
        local w, key = place(c[1], c[2])
        local G = w.ns.Grammar
        local kind = G.Kind(key)
        local what = c[1] .. " " .. c[2]
        T.eq(kind.cost, true, what)
        T.eq((G.MomentWords("short", nil, kind)), "When I don't have enough " .. c[3], what)
        T.eq(G.ClauseWords("noMana", nil, kind), "I don't have enough " .. c[3], what)
        -- The blue wash and Mana check need a piece that tells castable at all (Health
        -- Funnel shows as its channel's buff).
        local castable = kind.cooldown == true or kind.button == true
        T.eq(G.Fits(kind, "short", "blue"), castable, what .. ": the blue wash")
        local recipes = " " .. table.concat(G.Recipes(kind), " ") .. " "
        T.eq(recipes:find(" manaCheck ", 1, true) ~= nil, castable, what .. ": Mana check")
        if castable then washed = washed + 1 end
    end
    T.eq(washed, 5, "every case but Health Funnel takes the wash")
    noErrors()
end)
