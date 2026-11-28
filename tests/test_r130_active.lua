local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- "While it's active" and "its buff isn't active" on a buff Daylight UI's aura holder
-- draws (docs/tasks/r130-fill.md, Notes). Water Shield set to Cooldown and buff is
-- drawn as "aura and cooldown icon"; Daylight UI's pass reports no buff state there
-- unless one of its own buff options needs it, so Bridge.BuffState reads what the
-- pass told the holder. A buff nothing can tell up or down is never offered these.

local WATER_SHIELD, LIGHTNING_SHIELD = 408510, 324

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A Shaman with spell id placed as an icon, its What it shows set to track.
local function place(id, track, opts)
    local w = W.Build("SHAMAN", opts)
    local D = w.AB.CdmData
    local r = assert(w.Row(id))
    local key = CW.ID(r.spell, r.category)
    D.AddPiece(D.Ensure(1), key, "icon", 0, 0)
    D.Get(1).pieces[key].track = track
    w.Pass()
    return w, key
end

local function write(w, key, lines)
    local ok, why = w.ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why))
    w.Pass()
end

local function lit(w, key, id)
    for _, v in pairs(w.ns.Conditions.Lit(key) or {}) do
        if v == id then return true end
    end
    return false
end

local function fillState(w, key)
    return w.ns.Looks.FillState(w.DUI.API.Attach(w.ns.Conditions.FrameOf(key)))
end

-- The owner's line (profile p7, 200335): no source, a shifting color, rising.
local OWNER = { moment = "up", action = "fill", value = { color = "shift", dir = "rise" } }

T.test("active: Water Shield as Cooldown and buff reads its buff up and down, in a fight too", function()
    local w, key = place(WATER_SHIELD, "both")
    local B, C = w.ns.Bridge, w.ns.Conditions
    T.eq(B.DrawnBy(key), "aura and cooldown icon")
    T.isnil(w.DUI.API.CooldownState(tostring(key)).buffUp, "Daylight UI's own state stays silent")
    local up, drawnBy, from = B.BuffState(key)
    T.eq(up, false, "down before the cast")
    T.eq(drawnBy, "aura and cooldown icon")
    T.eq(from, "holder")
    T.eq(C.Get("active").read(key), false)
    T.eq(C.Get("noBuff").read(key), true)
    w.Cast(WATER_SHIELD)
    w.BuffUp(WATER_SHIELD, { duration = 600 })
    T.eq(C.Get("active").read(key), true, "up")
    T.eq(C.Get("noBuff").read(key), false)
    w.EnterCombat()
    w.Pass()
    T.eq(C.Get("active").read(key), true, "up in a fight")
    w.BuffDown(WATER_SHIELD)
    T.eq(C.Get("active").read(key), false, "down in a fight")
    T.falsy(w.ns.Effects.Covered(key), "no buff moment times its fall-off")
    noErrors()
end)

T.test("active: the owner's Water Shield line lights with the buff and goes with it", function()
    local w, key = place(WATER_SHIELD, "both")
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    T.truthy(G.Fits(kind, "up", "fill"), "offered")
    write(w, key, { OWNER })
    T.deq(C.Rule(key), { active = { fill = { value = { color = "shift", dir = "rise" } } } })
    local source = G.FillPicks(OWNER.value, kind, OWNER)
    T.eq(G.Describe(OWNER, kind), "While it's active, fill it with time left (thin bar, rises) in a color that shifts with the amount.")
    T.falsy(lit(w, key, "active:fill"), "no buff: dark")
    w.Cast(WATER_SHIELD)
    w.BuffUp(WATER_SHIELD, { duration = 600 })
    T.truthy(lit(w, key, "active:fill"), "lit as the buff lands, with no pass of the test's own")
    local st = fillState(w, key)
    T.truthy(st, "the fill shows")
    T.eq(st.source, source, "the draw path fills with the drawer's source")
    T.eq(st.source, "time")
    T.truthy(st.shift and st.ticking, "shifts on the low-time beat")
    local E = w.ns.Effects
    local ends, lasts = E.BuffClock(key)
    T.eq(lasts, 600, "the game's data: ten minutes")
    stub.Advance(200)
    T.eq(E.BuffClock(key), ends, "the clock holds")
    w.Cast(WATER_SHIELD)
    T.truthy(E.BuffClock(key) > ends + 100, "a recast while up starts it again")
    w.EnterCombat()
    T.truthy(lit(w, key, "active:fill"), "lit in a fight")
    w.BuffDown(WATER_SHIELD)
    T.falsy(lit(w, key, "active:fill"), "the buff gone: dark")
    T.isnil(fillState(w, key))
    noErrors()
end)

T.test("active: Lightning Shield as Cooldown and buff lights the same way", function()
    local w, key = place(LIGHTNING_SHIELD, "both")
    write(w, key, { OWNER })
    w.Cast(LIGHTNING_SHIELD)
    w.BuffUp(LIGHTNING_SHIELD, { duration = 600 })
    T.eq(w.ns.Bridge.DrawnBy(key), "aura and cooldown icon")
    T.truthy(lit(w, key, "active:fill"))
    w.BuffDown(LIGHTNING_SHIELD)
    T.falsy(lit(w, key, "active:fill"))
    noErrors()
end)

T.test("active: a buff its holder can't tell up or down is never offered, and a saved line says so", function()
    local w, key = place(WATER_SHIELD, "both", { hidden = true })
    local G, B = w.ns.Grammar, w.ns.Bridge
    T.eq(B.Tracked(key), false, "the game's buff rows hidden: nothing tells")
    local kind = G.Kind(key)
    T.truthy(kind.clocked, "its clock still runs")
    T.falsy(G.Fits(kind, "up", "fill"), "While it's active isn't offered")
    T.falsy(w.ns.Conditions.Fits("noBuff", "gray", kind), "nor its buff isn't active")
    local _, problems = G.Compile({ lines = { OWNER } }, kind)
    local codes = {}
    for _, p in ipairs(problems or {}) do codes[#codes + 1] = p.code end
    T.deq(codes, { "kind" }, "a saved line says it doesn't fit this spell")
    noErrors()
end)
