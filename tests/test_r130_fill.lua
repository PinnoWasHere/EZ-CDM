local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Fill follow-ups (1.3.0, docs/tasks/r130-fill.md):
--   1 a fill's color may shift with the amount: Daylight UI's health gradient, green
--     with much left, red with little, whichever way it fills. Power repaints on its
--     events, a secret too; the thin bar paints as Daylight UI's health bar
--   2 time left repaints on a ticker at Daylight UI's low-time beat, running only while
--     such a fill shows a clock
--   3 "While it's cooling down" and "While it's active" take "and" parts
--   4 the thin bar is the only shape (owner, 2026-11-27): 1.2.0's tint lines load and
--     draw as the thin bar, and no fill moves the game's own frames

local EARTH_SHOCK, LIGHTNING_SHIELD = 8042, 324

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A Shaman logged in with spell id placed as an icon (as test_w2_fill).
local function place(id, opts)
    local w = W.Build("SHAMAN", opts)
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    local key
    local r = w.Row(id)
    if r and r.category then
        key = CW.ID(r.spell, r.category)
    else
        stub.knownSpells[id] = true
        stub.spells[id] = stub.spells[id] or { name = "Spell " .. id }
        key = assert(Ed.KeyForID("spell", tostring(id)))
    end
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, (opts and opts.shape) or "icon", 0, 0) end
    w.Pass()
    return w, key
end

local function write(w, key, lines)
    local ok, why, report = w.ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes and report.notes[1]
        and report.notes[1].words))
    w.Pass()
end

local function fillOf(w, key)
    local holder = w.DUI.API.Attach(w.ns.Conditions.FrameOf(key))
    return w.ns.Looks.Frame(holder, "fill"), holder
end

local function mana(w, pct, how)
    w.Power(Enum.PowerType.Mana, pct, how)
    stub.FireEvent("UNIT_POWER_FREQUENT", "player", "MANA")
end

-- The gradient's color at p, as Daylight UI softens its stops.
local function gradientAt(w, p)
    return { w.DUI.Health.GradientAt(p) }
end

local function near(a, b, why)
    T.truthy(math.abs(stub.Plain(a) - b) < 1e-3, (why or "") .. ": " .. tostring(stub.Plain(a)) .. " vs " .. tostring(b))
end

local function rgbNear(got, want, why)
    for i = 1, 3 do near(got[i], want[i], why) end
end

-- ---------------------------------------------------------------------
-- 1. The shifting color on power
-- ---------------------------------------------------------------------

T.test("shift: the value saves as \"shift\" and reads back; a bad color is refused", function()
    local w, key = place(EARTH_SHOCK)
    local C = w.ns.Conditions
    T.deq(C.CleanValue("fill", { color = "shift" }), { color = "shift" })
    T.deq(C.CleanValue("fill", { source = "power", color = "shift" }), { source = "power", color = "shift" })
    T.isnil(C.CleanValue("fill", { color = "rainbow" }), "only shift or an r, g, b")
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", color = "shift" } } })
    T.deq(C.Rule(key), { always = { fill = { value = { source = "power", color = "shift" } } } })
    w.Reload()
    w.Pass()
    T.deq(C.Rule(key), { always = { fill = { value = { source = "power", color = "shift" } } } }, "after a reload")
    noErrors()
end)

T.test("shift: power paints the thin bar through Daylight UI's health gradient, a secret too", function()
    local w, key = place(EARTH_SHOCK)
    T.truthy(w.ns.Bridge.GradientCurve(), "Daylight UI's curve")
    mana(w, 0.9)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", color = "shift" } } })
    local f = fillOf(w, key)
    T.truthy(f.bar:IsShown())
    near(f.bar:GetValue(), 0.9, "the amount")
    rgbNear(f.bar.__barColor, gradientAt(w, 0.9), "much left: green")
    T.isnil(f.tint, "no tint")
    mana(w, 0.1)
    rgbNear(f.bar.__barColor, gradientAt(w, 0.1), "little left: red")
    mana(w, 0.5, "secret")
    T.truthy(issecretvalue(f.bar.__barColor[1]), "a secret color goes in whole")
    rgbNear(f.bar.__barColor, gradientAt(w, 0.5), "and is the gradient's")
    T.truthy(w.ns.Looks.FillState(w.DUI.API.Attach(w.ns.Conditions.FrameOf(key))).shift)
    noErrors()
end)

T.test("shift: rises keeps green for much left, whichever way it fills", function()
    local w, key = place(EARTH_SHOCK)
    mana(w, 0.8)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", dir = "rise", color = "shift" } } })
    local f = fillOf(w, key)
    near(f.bar:GetValue(), 0.2, "rises: a fifth full")
    rgbNear(f.bar.__barColor, gradientAt(w, 0.8), "80% mana: still green")
    noErrors()
end)

T.test("shift: the thin bar paints as Daylight UI's health bar, its empty part neutral", function()
    local w, key = place(EARTH_SHOCK)
    mana(w, 0.3)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", shape = "bar", color = "shift" } } })
    local f = fillOf(w, key)
    T.truthy(f.bar and f.bar:IsShown())
    rgbNear(f.bar.__barColor, gradientAt(w, 0.3), "the fill")
    T.eq(f.bar.__barColor[4], 1)
    local S = w.DUI.Style
    local lo = S.FillColors(f.bar:GetStatusBarTexture())
    rgbNear(lo, gradientAt(w, 0.3), "Daylight UI's bar effects know the fill's color")
    local back = S.BarBack(f.bar)
    if back then
        local n = { S.Neutral() }
        local k = S.BAR_BACK_DIM
        rgbNear(back.__vertex, { n[1] * k, n[2] * k, n[3] * k }, "the empty part neutral")
    end
    noErrors()
end)

T.test("shift: a picked color and the accent stay as they were", function()
    local w, key = place(EARTH_SHOCK)
    mana(w, 0.3)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", color = { 1, 0.8, 0.2 } } } })
    local f = fillOf(w, key)
    T.eq(f.bar.__barColor[1], 1); T.eq(f.bar.__barColor[2], 0.8)
    mana(w, 0.9)
    T.eq(f.bar.__barColor[2], 0.8, "no shift on a picked color")
    noErrors()
end)

T.test("shift: with no curve of Daylight UI's, the text colors' BAD, WARN and GOOD", function()
    local w, key = place(EARTH_SHOCK)
    local keep = w.DUI.Health.GradientCurve
    w.DUI.Health.GradientCurve = function() return nil end
    stub.onReset[#stub.onReset + 1] = function() w.DUI.Health.GradientCurve = keep end
    mana(w, 1)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", color = "shift" } } })
    local f = fillOf(w, key)
    local ink = w.DUI.API.Colors()
    rgbNear(f.bar.__barColor, ink.GOOD, "full: GOOD")
    mana(w, 0)
    rgbNear(f.bar.__barColor, ink.BAD, "empty: BAD")
    mana(w, 0.5)
    rgbNear(f.bar.__barColor, ink.WARN, "half: WARN")
    noErrors()
end)

T.test("shift: its words and the drawer's color chip", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(G.Describe({ moment = "always", action = "fill", value = { source = "power", color = "shift" } }, kind),
        "Always fill it with my mana (thin bar, drains) in a color that shifts with the amount.")
    write(w, key, { { moment = "blocked", action = "fill" } })
    T.truthy(w.AB.CdmEditor.Open())
    stub.RunTimers()
    w.AB.CdmEditor.Select(key)
    stub.RunTimers()
    local Drawer = w.ns.Drawer
    local function said()
        for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
            if b:IsShown() and b.line then return b end
        end
    end
    local color
    for _, t in ipairs(said().tokens) do
        if t.piece and t.piece.word == "color" then color = t end
    end
    T.truthy(color, "the color word")
    color:Click()
    local chips = {}
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() and b.tokens and b.choices then
            for _, t in ipairs(b.tokens) do chips[#chips + 1] = t.piece.key; chips[t.piece.key] = t end
        end
    end
    T.eq(table.concat(chips, " "), "accent pick shift")
    chips.shift:Click()
    T.deq(w.ns.Conditions.Rule(key), { cantCast = { fill = { value = { color = "shift" } } } })
    T.eq(said().said, "When I can't cast it, fill it with my mana (thin bar, drains) in a color that shifts with the amount.")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. The shifting color on time left
-- ---------------------------------------------------------------------

-- The tickers running now.
local function ticking()
    local n = 0
    for _, t in ipairs(stub.tickers) do
        if not t.cancelled then n = n + 1 end
    end
    return n
end

T.test("shift: time left repaints on Daylight UI's low-time beat while its buff's clock runs", function()
    local w, key = place(LIGHTNING_SHIELD)
    local L, B = w.ns.Looks, w.ns.Bridge
    T.eq(B.LowTick(), w.AB.Cooldowns.LOW_TICK, "Daylight UI's own beat")
    write(w, key, { { moment = "up", action = "fill", value = { source = "time", color = "shift" } } })
    T.falsy(L.ShiftTicking(), "no buff: no ticker")
    local before = ticking()
    w.Cast(LIGHTNING_SHIELD)
    w.BuffUp(LIGHTNING_SHIELD, { duration = 600 })
    w.Pass()
    local f = fillOf(w, key)
    T.truthy(f and f.bar and f.bar:IsShown(), "lit while its buff is up")
    T.truthy(L.ShiftTicking(), "the ticker runs")
    T.eq(ticking(), before + 1, "one ticker")
    local beat
    for _, t in ipairs(stub.tickers) do if not t.cancelled then beat = t.interval end end
    T.eq(beat, w.AB.Cooldowns.LOW_TICK)
    rgbNear(f.bar.__barColor, gradientAt(w, 1), "all of it left: green")
    stub.Advance(300)
    stub.RunTickers()
    rgbNear(f.bar.__barColor, gradientAt(w, 0.5), "half left")
    stub.Advance(270)
    stub.RunTickers()
    rgbNear(f.bar.__barColor, gradientAt(w, 0.05), "little left: red")
    local st = L.FillState(w.DUI.API.Attach(w.ns.Conditions.FrameOf(key)))
    T.truthy(st.shift and st.ticking)
    w.BuffDown(LIGHTNING_SHIELD)
    w.Pass()
    T.falsy(L.ShiftTicking(), "the buff gone: the ticker stops")
    noErrors()
end)

T.test("shift: a cooldown's time left follows its duration object; no ticker once ready", function()
    local w, key = place(EARTH_SHOCK)
    local L = w.ns.Looks
    local keep = C_Spell.GetSpellCooldownDuration
    local left = 1
    C_Spell.GetSpellCooldownDuration = function(id)
        local info = C_Spell.GetSpellCooldown(id)
        if not (type(info) == "table" and info.isActive and not info.isOnGCD) then return nil end
        return { EvaluateRemainingPercent = function(_, curve) return curve:Evaluate(left) end }
    end
    stub.onReset[#stub.onReset + 1] = function() C_Spell.GetSpellCooldownDuration = keep end
    local sid = w.ns.Bridge.SpellOf(key)
    write(w, key, { { moment = "always", action = "fill", value = { source = "time", dir = "rise", color = "shift" } } })
    local f = fillOf(w, key)
    T.falsy(L.ShiftTicking(), "ready: nothing to follow")
    rgbNear(f.bar.__barColor, gradientAt(w, 0), "no time left: red, though it rises full")
    w.Cooldown(sid, 6)
    T.truthy(L.ShiftTicking())
    rgbNear(f.bar.__barColor, gradientAt(w, 1), "a whole cooldown left: green")
    left = 0.25
    stub.RunTickers()
    rgbNear(f.bar.__barColor, gradientAt(w, 0.25))
    w.Ready(sid)
    T.falsy(L.ShiftTicking(), "ready again: the ticker stops")
    write(w, key, {})
    T.falsy(L.ShiftTicking())
    noErrors()
end)

T.test("shift: a power fill and a plain time-left fill run no ticker", function()
    local w, key = place(EARTH_SHOCK)
    local L = w.ns.Looks
    local sid = w.ns.Bridge.SpellOf(key)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", color = "shift" } } })
    w.Cooldown(sid, 6)
    T.falsy(L.ShiftTicking(), "power repaints on its events")
    write(w, key, { { moment = "always", action = "fill", value = { source = "time" } } })
    w.Cooldown(sid, 6)
    T.falsy(L.ShiftTicking(), "no shift: no ticker")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. "And" on cooling down and active
-- ---------------------------------------------------------------------

local function has(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then return true end
    end
    return false
end

local function lit(w, key, id)
    for _, v in pairs(w.ns.Conditions.Lit(key) or {}) do
        if v == id then return true end
    end
    return false
end

T.test("and: While it's cooling down takes and parts; the ones that clash are refused and said why", function()
    local w, key = place(EARTH_SHOCK)
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    local line = { moment = "cooldown", action = "fill" }
    T.truthy(G.TakesClauses(line, kind), "it takes them")
    local offered = G.Clauses(kind, line, { more = true })
    T.truthy(has(offered, "inCombat"), "in combat")
    T.falsy(has(offered, "offCooldown"), "never off cooldown too")
    T.falsy(has(offered, "always"), "always is no and part")
    T.falsy(has(offered, "cooling"), "never itself twice")
    local why
    for _, r in ipairs(G.ClauseRefusals(kind, line, { more = true })) do
        if r.cond == "offCooldown" then why = r.why end
    end
    T.truthy(type(why) == "string" and why:find("it's on cooldown or off it", 1, true), tostring(why))
    T.falsy(C.Get("cooling").alone)
    T.falsy(C.Get("active").alone)
    T.truthy(C.Get("always").alone, "Always still stands alone")
    noErrors()
end)

T.test("and: a cooling-down fill with an and part writes, reads back and lights only when both hold", function()
    local w, key = place(EARTH_SHOCK)
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    local line = { moment = "cooldown", action = "fill", value = { source = "time" },
                   clauses = { { cond = "inCombat" } } }
    T.eq(G.Describe(line, kind), "While it's cooling down and I'm in combat, fill it with time left (thin bar, drains).")
    local fields, problems = G.Compile({ lines = { line } }, kind)
    T.eq(#problems, 0)
    T.deq(fields["ez:cooling:fill"], { value = { source = "time" }, clauses = { { cond = "inCombat" } } })
    write(w, key, { line })
    T.deq(C.Rule(key), { cooling = { fill = { value = { source = "time" }, clauses = { { cond = "inCombat" } } } } })
    local back = w.ns.Draft.Rules(key).lines
    T.eq(#back, 1)
    T.eq(back[1].moment, "cooldown", "under Daylight UI's own moment")
    T.deq(back[1].clauses, { { cond = "inCombat" } })
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6)
    T.falsy(lit(w, key, "cooling:fill"), "cooling down, out of a fight: dark")
    w.EnterCombat()
    T.truthy(lit(w, key, "cooling:fill"), "cooling down in a fight: lit")
    w.Ready(sid)
    T.falsy(lit(w, key, "cooling:fill"), "ready: dark")
    noErrors()
end)

T.test("and: a gray and a fill with an and part are two sentences", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local lines = { { moment = "cooldown", action = "gray" },
                    { moment = "cooldown", action = "fill", clauses = { { cond = "inCombat" } } } }
    T.deq(G.Rows(lines, kind), { { 1 }, { 2 } })
    write(w, key, lines)
    T.eq(#w.ns.Draft.Rules(key).lines, 2)
    noErrors()
end)

T.test("and: While it's active takes and parts on Lightning Shield", function()
    local w, key = place(LIGHTNING_SHIELD)
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    local line = { moment = "up", action = "fill", value = { source = "time" }, clauses = { { cond = "inCombat" } } }
    T.truthy(G.TakesClauses({ moment = "up", action = "fill" }, kind))
    T.falsy(has(G.Clauses(kind, { moment = "up", action = "fill" }, { more = true }), "noBuff"),
        "never its buff up and not up")
    T.eq(G.Describe(line, kind), "While it's active and I'm in combat, fill it with time left (thin bar, drains).")
    write(w, key, { line })
    T.deq(C.Rule(key), { active = { fill = { value = { source = "time" }, clauses = { { cond = "inCombat" } } } } })
    w.Cast(LIGHTNING_SHIELD)
    w.BuffUp(LIGHTNING_SHIELD, { duration = 600 })
    w.Pass()
    T.falsy(lit(w, key, "active:fill"), "out of a fight: dark")
    w.EnterCombat()
    T.truthy(lit(w, key, "active:fill"), "in a fight: lit")
    noErrors()
end)

T.test("and: it's on cooldown is an and part on other lines", function()
    local w, key = place(EARTH_SHOCK)
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    T.truthy(has(G.Clauses(kind, { moment = "blocked", action = "glow" }, { more = true }), "cooling"))
    local line = { moment = "blocked", action = "glow", clauses = { { cond = "cooling" } } }
    T.eq(G.Describe(line, kind), "When I can't cast it and it's on cooldown, glow.")
    write(w, key, { line })
    T.deq(C.Rule(key), { cantCast = { glow = { clauses = { { cond = "cooling" } } } } })
    local _, problems = G.Compile({ lines = { { moment = "ready", action = "glow",
        clauses = { { cond = "cooling" } } } } }, kind)
    T.eq(problems[1] and problems[1].code, "never", "ready and on cooldown never hold together")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 4. The thin bar only
-- ---------------------------------------------------------------------

-- A table as text, keys sorted, so two reads compare byte for byte.
local function dump(v)
    if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(x, y)
        if type(x) ~= type(y) then return type(x) < type(y) end
        return x < y
    end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = "[" .. dump(k) .. "]=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function savedWorld(id, rule)
    local w, key = place(id)
    local C = w.ns.Conditions
    EZCDMDB.conditionsVersion = C.VERSION
    EZCDMDB.conditions = { [w.ns.Bridge.ProfileOf(1)] = { [key] = rule } }
    C.Sync()
    w.Pass()
    return w, key
end

-- 1.2.0 saved a tint fill with no shape (its default) or with shape "tint".
T.test("bar only: 1.2.0's tint fills load, draw and say the thin bar; an edit saves the bar", function()
    for _, case in ipairs({
        { saved = { source = "power" }, read = { source = "power" }, said = "(thin bar, drains)" },
        { saved = { source = "power", shape = "tint", dir = "rise" },
          read = { source = "power", shape = "bar", dir = "rise" }, said = "(thin bar, rises)" },
        { saved = { shape = "tint" }, read = { shape = "bar" }, said = "(thin bar, drains)" },
    }) do
        local w, key = savedWorld(EARTH_SHOCK, { always = { fill = { value = case.saved } } })
        local C, G = w.ns.Conditions, w.ns.Grammar
        mana(w, 0.4)
        local saved = dump(EZCDMDB.conditions)
        T.eq(C.VERSION, 6, "no new saved form")
        T.deq(C.Rule(key), { always = { fill = { value = case.read } } }, "read as the thin bar")
        T.eq(dump(EZCDMDB.conditions), saved, "the save untouched on load")
        local lines = w.ns.Draft.Rules(key).lines
        T.eq(#lines, 1, "no line dropped")
        T.eq(G.Describe(lines[1], G.Kind(key)), "Always fill it with my mana " .. case.said .. ".")
        local _, problems = G.Compile({ lines = lines }, G.Kind(key))
        T.eq(#problems, 0, "no problem with the line")
        T.truthy(lit(w, key, "always:fill"), "lit")
        local f = fillOf(w, key)
        T.truthy(f.bar and f.bar:IsShown(), "drawn as the thin bar")
        T.isnil(f.tint, "no tint")
        near(f.bar:GetValue(), case.read.dir == "rise" and 0.6 or 0.4, "the amount")
        T.eq(w.ns.Looks.FillState(w.DUI.API.Attach(C.FrameOf(key))).shape, "bar")
        local ok, report = w.ns.Draft.Write(key, w.ns.Draft.Rules(key))
        T.truthy(ok)
        T.eq(report.changes, 0, "written again: nothing changes")
        T.eq(dump(EZCDMDB.conditions), saved, "and the save stays as it was")
        local line = w.ns.Draft.Rules(key).lines[1]
        line.value.color = "shift"
        T.truthy((w.ns.Draft.Write(key, { lines = { line } })))
        w.Pass()
        local want = {}
        for k, v in pairs(case.read) do want[k] = v end
        want.color = "shift"
        T.deq(EZCDMDB.conditions[w.ns.Bridge.ProfileOf(1)][key], { always = { fill = { value = want } } },
            "an edit saves the thin bar")
        noErrors()
    end
end)

-- The tint needed the game's swipe, count and flash moved up to show over the icon's
-- picture. The owner declined that, so no fill touches the game's frames.
T.test("bar only: a fill leaves the game's own frames at their levels", function()
    local w, key = place(EARTH_SHOCK)
    local sid = w.ns.Bridge.SpellOf(key)
    write(w, key, { { moment = "cooldown", action = "fill", value = { source = "time", color = "shift" } } })
    local item = w.AB.CdmRows.pieceInfo[w.ns.Conditions.FrameOf(key)].item
    local icon = w.AB.Cooldowns.IconOf(item)
    local frames = { item = icon:GetParent(), swipe = item.Cooldown, count = item.ChargeCount, flash = item.CooldownFlash }
    local before = {}
    for k, fr in pairs(frames) do before[k] = fr:GetFrameLevel() end
    w.Cast(sid)
    w.Cooldown(sid, 6)
    local f = fillOf(w, key)
    T.truthy(f and f.bar and f.bar:IsShown(), "lit while it cools")
    for k, fr in pairs(frames) do T.eq(fr:GetFrameLevel(), before[k], "the item's " .. k .. " where the game put it") end
    T.isnil(w.ns.Looks.TINT_STEP, "no tint step")
    T.isnil(w.ns.Looks.OVER_TINT, "no frames to lift")
    T.deq(w.ns.Looks.FILL_SHAPES, { "bar" })
    w.Ready(sid)
    noErrors()
end)
