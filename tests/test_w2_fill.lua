local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- The progress fill (wave 2, 1.2.0, docs/tasks/w2-fill.md): "fill it with my health /
-- target health / my power / time left", a look a line may end in.
--   1 the registry: always, cooling and active take the fill only, no sound, and are
--     never an "and" part; the fill's watch joins a piece's handlers and events;
--     1.1.0 saves load unchanged
--   2 the look: a tint stood up over the icon or a thin bar under it; health and power
--     go to the bar as the game gives them, through a curve ("rises" flips it); no
--     target is empty; its events listen only while a fill of that source is lit
--   3 time left: a real cooldown's duration object, a totem's, or Daylight UI's clock
--     of your own buff; never on a proc or a buff that never wears off
--   4 Daylight UI's "While it's cooling down" and "While it's active" take the fill on
--     pieces where EZ-CDM's cooling and active mean the same
--   5 its words and the drawer's picks

local EARTH_SHOCK, SEARING, LIGHTNING_SHIELD, STORMSTRIKE, IMP_STORMSTRIKE = 8042, 3599, 324, 17364, 1223031
local GOLD = { 1, 0.8, 0.2 }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A Shaman logged in with spell id placed as an icon (as test_w1_ready_totemdown).
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

local function has(list, v)
    for _, x in ipairs(list or {}) do
        if x == v then return true end
    end
    return false
end

-- The fill frame EZ-CDM drew on a piece's holder (or a line's layer).
local function fillOf(w, key, target)
    local holder = w.DUI.API.Attach(w.ns.Conditions.FrameOf(key))
    return w.ns.Looks.Frame(target or holder, "fill"), holder
end

-- The game keeps health secret (UnitHealthPercent SecretReturns); the fake game's
-- secret still holds its number for a test to read.
local function near(a, b)
    a = stub.Plain(a)
    return type(a) == "number" and math.abs(a - b) < 1e-6
end

-- A duration object as the client hands one over, and the calls that ask for it.
local function cooldownDurations()
    local keep = C_Spell.GetSpellCooldownDuration
    local made = {}
    C_Spell.GetSpellCooldownDuration = function(id, ignoreGcd)
        local info = C_Spell.GetSpellCooldown(id)
        if not (type(info) == "table" and info.isActive and not info.isOnGCD) then return nil end
        made[id] = made[id] or { id = id, ignoreGcd = ignoreGcd }
        return made[id]
    end
    stub.onReset = stub.onReset or {}
    stub.onReset[#stub.onReset + 1] = function() C_Spell.GetSpellCooldownDuration = keep end
    return made
end

local function dump(v)
    if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = "[" .. dump(k) .. "]=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

-- ---------------------------------------------------------------------
-- 1. The registry
-- ---------------------------------------------------------------------

T.test("fill: the fill is the last look, held, alpha-safe, and takes a fill value", function()
    local w = place(EARTH_SHOCK)
    local C = w.ns.Conditions
    local got = {}
    for _, l in ipairs(C.Looks()) do got[#got + 1] = l.action end
    T.eq(got[#got], "fill", "after the other looks, in the drawer's order")
    local e = C.Effect("fill")
    T.truthy(e, "the fill effect")
    T.falsy(e.edge, "held while its line is on")
    T.truthy(e.client, "alpha only, so a client line may take it")
    T.eq(e.value, "fill")
    T.eq(type(e.shown), "function", "says what it drew")
    T.eq(type(e.watch), "table", "what may change what it draws")
    noErrors()
end)

T.test("fill: always, cooling and active take only the fill, no sound, and are never an and part", function()
    local w, key = place(EARTH_SHOCK)
    local C, G = w.ns.Conditions, w.ns.Grammar
    local kind = G.Kind(key)
    for _, ck in ipairs({ "always", "cooling", "active" }) do
        local c = C.Get(ck)
        T.truthy(c, ck .. " is registered")
        local acts = {}
        for a in pairs(c.actions) do acts[#acts + 1] = a end
        table.sort(acts)
        T.eq(table.concat(acts, ","), "fill", ck .. " takes the fill alone")
        T.truthy(c.alone, ck .. " stands alone")
        T.eq(c.secrecy, "plain")
    end
    T.eq(C.Get("always").layer, "any")
    T.eq(C.Get("always").read("x"), true, "always is true")
    local clauses = G.Clauses(kind, { moment = "blocked", action = "glow" }, { more = true })
    for _, ck in ipairs({ "always", "cooling", "active" }) do
        T.falsy(has(clauses, ck), ck .. " is no and part")
    end
    T.falsy(G.TakesClauses({ moment = "always", action = "fill" }, kind), "Always takes no and part")
    local _, problems = G.Compile({ lines = { { moment = "always", action = "fill",
        clauses = { { cond = "inCombat" } } } } }, kind)
    T.eq(problems[1] and problems[1].code, "pair", "a saved and part on Always is refused")
    noErrors()
end)

T.test("fill: Always offers the fill beside Daylight UI's show, and the fill sits under other lines", function()
    local w, key = place(EARTH_SHOCK)
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    T.eq(moments(G, kind).always, "show,fill")
    local fields, problems = G.Compile({ lines = { { moment = "always", action = "show" },
        { moment = "always", action = "fill" } } }, kind)
    T.eq(#problems, 0)
    T.eq(fields["ez:always:fill"], true)
    T.truthy(C.Get("always").priority < C.Get("cantCast").priority, "any other line's fill wins")
    noErrors()
end)

T.test("fill: a 1.1.0 save loads and reads back unchanged", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, {
        { moment = "blocked", action = "glow", clauses = { { cond = "inCombat" } } },
        { moment = "blocked", action = "pulse", clauses = { { cond = "inCombat" } } },
        { moment = "ready", action = "flare", value = { design = "crown" } },
        { moment = "targetLow", action = "border", n = 25 },
    })
    local before = dump(EZCDMDB.conditions)
    local version = EZCDMDB.conditionsVersion
    T.eq(version, 6, "the saved form stays 6")
    local lines = dump(w.ns.Draft.Rules(key).lines)
    w.Reload()
    w.Pass()
    T.eq(dump(EZCDMDB.conditions), before, "the saved rules, byte for byte")
    T.eq(EZCDMDB.conditionsVersion, 6)
    T.eq(dump(w.ns.Draft.Rules(key).lines), lines, "the same lines")
    noErrors()
end)

T.test("fill: a fill line's piece reads again on the fill's watch", function()
    local w, key = place(SEARING)
    write(w, key, { { moment = "always", action = "fill", value = { source = "time" } } })
    local listening = table.concat(w.ns.Conditions.Listening(), " ")
    T.truthy(listening:find("PLAYER_TOTEM_UPDATE", 1, true), listening)
    T.truthy(listening:find("SPELL_UPDATE_COOLDOWN", 1, true), listening)
    T.truthy(w.ns.Conditions.Watching() >= 1, "Daylight UI watches it")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. The look
-- ---------------------------------------------------------------------

-- Your mana at pct, then the event a power fill listens for.
local function mana(w, pct, how)
    w.Power(Enum.PowerType.Mana, pct, how)
    stub.FireEvent("UNIT_POWER_FREQUENT", "player", "MANA")
end

T.test("fill: my power goes to the tint as the game gives it, a secret too", function()
    local w, key = place(EARTH_SHOCK)
    mana(w, 0.6)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power" } } })
    T.truthy(lit(w, key, "always:fill"), "always lit")
    local f, holder = fillOf(w, key)
    T.truthy(f and f.tint, "the tint")
    T.eq(f.tint:GetOrientation(), "VERTICAL", "stood up")
    T.truthy(f.tint:IsShown())
    T.truthy(not f.bar or not f.bar:IsShown(), "no bar")
    T.truthy(near(f.tint:GetValue(), 0.6), "60%: " .. tostring(stub.Plain(f.tint:GetValue())))
    mana(w, 0.4, "secret")
    T.truthy(issecretvalue(f.tint:GetValue()), "a secret goes in whole")
    local r, g, b, a = unpack(f.tint.__barColor)
    local ar, ag, ab = w.DUI.API.Accent()
    T.eq(r, ar); T.eq(g, ag); T.eq(b, ab)
    T.truthy(near(a, w.ns.Bridge.WashAlpha()), "the held tint's strength")
    local v = w.ns.Conditions.Visible(key, "always:fill")
    T.truthy(v.lit and v.shown, "Conditions.Visible sees it")
    T.eq(f:GetParent(), holder)
    noErrors()
end)

T.test("fill: rises fills as the number drops, through the flipped curve", function()
    local w, key = place(EARTH_SHOCK)
    mana(w, 0.25)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", dir = "rise", color = GOLD } } })
    local f = fillOf(w, key)
    T.truthy(near(f.tint:GetValue(), 0.75), "25% mana: three quarters full, " .. tostring(f.tint:GetValue()))
    local r, g, b = unpack(f.tint.__barColor)
    T.eq(r, GOLD[1]); T.eq(g, GOLD[2]); T.eq(b, GOLD[3])
    noErrors()
end)

T.test("fill: its events listen only while a power fill is lit", function()
    local w, key = place(EARTH_SHOCK)
    local L = w.ns.Looks
    T.eq(#L.FillEvents(), 0, "no fill: nothing")
    write(w, key, { { moment = "always", action = "fill", value = { source = "power" } } })
    local on = table.concat(L.FillEvents(), " ")
    T.truthy(on:find("UNIT_POWER_FREQUENT@player", 1, true), on)
    T.truthy(on:find("UNIT_DISPLAYPOWER@player", 1, true), on)
    T.falsy(on:find("HEALTH", 1, true), on)
    write(w, key, { { moment = "always", action = "fill", value = { source = "time" } } })
    T.eq(#L.FillEvents(), 0, "time left: none of its own")
    write(w, key, {})
    T.eq(#L.FillEvents(), 0, "the line gone: nothing")
    noErrors()
end)

T.test("fill: the thin bar is Daylight UI's bar, 2 px under the icon", function()
    local w, key = place(EARTH_SHOCK)
    mana(w, 0.5)
    write(w, key, { { moment = "always", action = "fill", value = { source = "power", shape = "bar" } } })
    local f, holder = fillOf(w, key)
    T.truthy(f.bar and f.bar:IsShown(), "the bar")
    T.truthy(not f.tint or not f.tint:IsShown(), "no tint")
    T.truthy(near(f.bar:GetValue(), 0.5))
    T.eq(f.bar:GetHeight(), w.ns.Bridge.BarHeight(), "Daylight UI's thin bar height")
    local point, rel, relPoint, x, y = f.bar:GetPoint(1)
    T.eq(point, "TOPLEFT"); T.eq(rel, holder); T.eq(relPoint, "BOTTOMLEFT")
    T.eq(x, 0); T.eq(y, -2, "2 px clear of the icon's border")
    noErrors()
end)

T.test("fill: a client line's fill hangs under its layer", function()
    local w, key = place(EARTH_SHOCK)
    w.Unit("target", { name = "Boar", reaction = 2 })
    write(w, key, { { moment = "targetLow", action = "fill" } })
    w.Health("target", 0.1)
    local v = w.ns.Conditions.Visible(key, "targetLow:fill")
    T.truthy(v.lit and v.shown, "lit and on show")
    T.truthy(v.layered, "under the layer its condition drives")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. Time left
-- ---------------------------------------------------------------------

T.test("fill: time left on Earth Shock's cooldown runs on its duration object", function()
    local w, key = place(EARTH_SHOCK)
    local made = cooldownDurations()
    local sid = w.ns.Bridge.SpellOf(key)
    write(w, key, { { moment = "always", action = "fill", value = { source = "time" } } })
    local f = fillOf(w, key)
    T.eq(f.tint:GetValue(), 0, "ready: no time left, empty")
    w.Cooldown(sid, 6)
    local t = f.tint.__timer
    T.truthy(t and t[1] == made[sid], "its cooldown's duration object")
    T.eq(made[sid].ignoreGcd, true, "the real cooldown, not the global one")
    T.eq(t[3], Enum.StatusBarTimerDirection.RemainingTime, "drains as the time runs out")
    w.Ready(sid)
    T.eq(f.tint:GetValue(), 0, "ready again: empty")
    write(w, key, { { moment = "always", action = "fill", value = { source = "time", dir = "rise" } } })
    f = fillOf(w, key)
    T.eq(f.tint:GetValue(), 1, "rises: full when ready")
    w.Cooldown(sid, 6)
    T.eq(f.tint.__timer[3], Enum.StatusBarTimerDirection.ElapsedTime, "fills as it comes back")
    noErrors()
end)

T.test("fill: time left on a totem is its own duration", function()
    local w, key = place(SEARING)
    local sid = w.ns.Bridge.SpellOf(key)
    write(w, key, { { moment = "cooldown", action = "fill", value = { source = "time" } } })
    T.truthy(w.ns.Draft.Rules(key).lines[1], "the line wrote")
    w.Totem(1, sid)
    T.truthy(lit(w, key, "totemUp:fill"), "lit while the totem stands")
    local f = fillOf(w, key)
    local t = f.tint.__timer
    T.truthy(t and t[1] == stub.totems[1].duration, "the totem's own duration object")
    noErrors()
end)

T.test("fill: time left on Lightning Shield is Daylight UI's clock of its buff", function()
    local w, key = place(LIGHTNING_SHIELD)
    write(w, key, { { moment = "up", action = "fill", value = { source = "time" } } })
    w.Cast(LIGHTNING_SHIELD)
    w.BuffUp(LIGHTNING_SHIELD, { duration = 600 })
    w.Pass()
    T.truthy(lit(w, key, "active:fill"), "lit while it's active")
    local f = fillOf(w, key)
    local t = f.tint.__timer
    T.truthy(t and type(t[1]) == "table", "a duration")
    T.truthy(near(t[1]:GetEndTime(), w.ns.Effects.BuffClock(key)), "ends where Daylight UI's clock does")
    T.truthy(near(t[1]:GetTotalDuration(), 600), "its whole length")
    noErrors()
end)

T.test("fill: no time left on a proc or a buff that never wears off, and why", function()
    local w, key = place(IMP_STORMSTRIKE)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local keys, refused = G.FillSources(kind, { moment = "always", action = "fill" })
    T.falsy(has(keys, "time"), "no time left on a buff you never cast")
    T.truthy(refused[1] and refused[1].key == "time" and type(refused[1].why) == "string", "and the drawer says why")
    T.eq(#keys, 0, "nothing else to fill with either")
    T.falsy(G.Fits(kind, "always", "fill"), "so the fill isn't offered")
    local proc = { shape = "icon", buff = true, showsBuff = true, buffOnly = true, proc = true, cast = false }
    keys, refused = G.FillSources(proc, { moment = "always", action = "fill" })
    T.falsy(has(keys, "time"))
    T.eq(refused[1] and refused[1].key, "time")
    local untimed = { shape = "icon", buff = true, showsBuff = true, buffOnly = true, cast = true, untimed = true }
    keys, refused = G.FillSources(untimed, { moment = "always", action = "fill" })
    T.falsy(has(keys, "time"))
    T.eq(refused[1] and refused[1].key, "time")
    local w2, es = place(EARTH_SHOCK)
    keys = w2.ns.Grammar.FillSources(w2.ns.Grammar.Kind(es), { moment = "always", action = "fill" })
    T.eq(table.concat(keys, ","), "power,time", "Earth Shock: both")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 4. Daylight UI's cooling down and active take the fill
-- ---------------------------------------------------------------------

T.test("fill: While it's cooling down takes the fill on Earth Shock, one chip", function()
    local w, key = place(EARTH_SHOCK)
    cooldownDurations()
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local m = moments(G, kind)
    T.truthy((m.cooldown or ""):find("fill", 1, true), "cooling down: " .. tostring(m.cooldown))
    T.isnil(m.cooling, "no second chip")
    local fields, problems = G.Compile({ lines = { { moment = "cooldown", action = "gray" },
        { moment = "cooldown", action = "fill", value = { source = "time" } } } }, kind)
    T.eq(#problems, 0)
    T.eq(fields.desat, "grey", "the gray stays Daylight UI's")
    T.eq(type(fields["ez:cooling:fill"]), "table", "the fill is EZ-CDM's cooling")
    T.eq(G.LineCondition({ moment = "cooldown", action = "fill" }, kind), "cooling")
    T.eq(G.DescribeRow({ { moment = "cooldown", action = "gray" },
        { moment = "cooldown", action = "fill", value = { source = "time" } } }, kind),
        "While it's cooling down, turn it gray and fill it with time left (tint, drains).")
    local sid = w.ns.Bridge.SpellOf(key)
    write(w, key, { { moment = "cooldown", action = "fill", value = { source = "time" } } })
    T.falsy(lit(w, key, "cooling:fill"), "ready: dark")
    w.Cooldown(sid, 6)
    T.truthy(lit(w, key, "cooling:fill"), "cooling down: lit")
    w.Gcd(sid, true)
    w.Ready(sid)
    T.falsy(lit(w, key, "cooling:fill"), "the global cooldown is no cooldown")
    noErrors()
end)

T.test("fill: While it's active takes the fill on Lightning Shield, one chip", function()
    local w, key = place(LIGHTNING_SHIELD)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy(kind.clocked, "Daylight UI clocks its buff")
    local m = moments(G, kind)
    T.truthy((m.up or ""):find("fill", 1, true), "active: " .. tostring(m.up))
    T.isnil(m.active, "no second chip")
    local fields, problems = G.Compile({ lines = { { moment = "up", action = "fill" } } }, kind)
    T.eq(#problems, 0)
    T.eq(fields["ez:active:fill"], true)
    noErrors()
end)

T.test("fill: Searing Totem's While my totem is up takes the fill", function()
    local w, key = place(SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy((moments(G, kind).cooldown or ""):find("fill", 1, true))
    T.eq(G.LineCondition({ moment = "cooldown", action = "fill" }, kind), "totemUp")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 5. Words
-- ---------------------------------------------------------------------

T.test("fill: its words name the number, the shape, the way it fills and the colour", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(G.Describe({ moment = "always", action = "fill" }, kind), "Always fill it with my mana (tint, drains).", "the first that fits")
    T.eq(G.Describe({ moment = "always", action = "fill",
        value = { source = "time", shape = "bar", dir = "rise", color = GOLD } }, kind),
        "Always fill it with time left (thin bar, rises) in the color you picked.")
    T.eq(G.Describe({ moment = "always", action = "fill", value = { source = "power" } }, kind),
        "Always fill it with my mana (tint, drains).")
    T.eq(G.DescribeRow({ { moment = "ready", action = "glow" },
        { moment = "ready", action = "fill", value = { source = "time" } } }, kind),
        "When it's ready, glow and fill it with time left (tint, drains).")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 5b. The drawer
-- ---------------------------------------------------------------------

local function editor(w, key)
    T.truthy(w.AB.CdmEditor.Open())
    stub.RunTimers()
    w.AB.CdmEditor.Select(key)
    stub.RunTimers()
    return w.ns.Drawer
end

local function sentences(Drawer)
    local out = {}
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b.line then out[#out + 1] = b end
    end
    return out
end

local function wordOf(Drawer, i, kind)
    local b = sentences(Drawer)[i]
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == kind then return t end
    end
end

local function strip(Drawer)
    local out = { keys = {}, chip = {}, never = {} }
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() and b.tokens and b.choices then
            for _, t in ipairs(b.tokens) do
                out.keys[#out.keys + 1] = tostring(t.piece.key)
                out.chip[t.piece.key] = t
            end
        end
        if b:IsShown() and b.never then out.never[#out.never + 1] = b.never end
    end
    return out
end

T.test("fill drawer: picked as an action, each pick a word, written as picked", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { { moment = "blocked", action = "glow" } })
    local Drawer = editor(w, key)
    wordOf(Drawer, 1, "action"):Click()
    T.truthy(strip(Drawer).chip.fill, "the fill is offered")
    strip(Drawer).chip.fill:Click()
    T.deq(w.ns.Conditions.Rule(key), { cantCast = { fill = true } }, "written at once, nothing picked")
    T.eq(sentences(Drawer)[1].said, "When I can't cast it, fill it with my mana (tint, drains) in the accent color.")
    wordOf(Drawer, 1, "fillSource"):Click()
    T.eq(table.concat(strip(Drawer).keys, " "), "power time", "both on Earth Shock")
    strip(Drawer).chip.time:Click()
    wordOf(Drawer, 1, "fillShape"):Click()
    T.eq(table.concat(strip(Drawer).keys, " "), "tint bar")
    strip(Drawer).chip.bar:Click()
    wordOf(Drawer, 1, "fillDir"):Click()
    T.eq(table.concat(strip(Drawer).keys, " "), "drain rise")
    strip(Drawer).chip.rise:Click()
    T.deq(w.ns.Conditions.Rule(key), { cantCast = { fill = { value = { source = "time", shape = "bar", dir = "rise" } } } })
    T.eq(sentences(Drawer)[1].said, "When I can't cast it, fill it with time left (thin bar, rises) in the accent color.")
    -- Back to each default: left out of the value.
    wordOf(Drawer, 1, "fillSource"):Click()
    strip(Drawer).chip.power:Click()
    wordOf(Drawer, 1, "fillShape"):Click()
    strip(Drawer).chip.tint:Click()
    wordOf(Drawer, 1, "fillDir"):Click()
    strip(Drawer).chip.drain:Click()
    T.deq(w.ns.Conditions.Rule(key), { cantCast = { fill = true } }, "every default again")
    T.truthy(wordOf(Drawer, 1, "color"), "a color word like any color look's")
    noErrors()
end)

T.test("fill drawer: not offered on a buff you never cast, which has nothing to fill with", function()
    local w, key = place(IMP_STORMSTRIKE)
    write(w, key, { { moment = "up", action = "glow" } })
    local Drawer = editor(w, key)
    wordOf(Drawer, 1, "action"):Click()
    T.truthy(strip(Drawer).chip.glow, "the action strip is open")
    T.falsy(strip(Drawer).chip.fill, "no fill chip")
    noErrors()
end)
