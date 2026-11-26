local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- docs/tasks/w1-reset.md: "When its cooldown resets". Improved Stormstrike's proc is
-- Stormstrike's cooldown resetting on a dodge or parry, scripted on the server. EZ-CDM
-- sees it as Daylight UI's Proc Alerts does: after your own cast, the cooldown ends well
-- before its usual length. The pieces it fits come from Daylight UI's Proc Alerts list,
-- baked into EZ-CDM/AuraLinks.lua with the client's cooldown length.

local STORMSTRIKE, IMPROVED, LIGHTNING_BOLT, EARTH_SHOCK = 17364, 1223031, 403, 8042
local CLIENT_CD, HOLD = 8, 4

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- The game's cooldown answer as Forever's docs give it (SpellSharedDocumentation):
-- isActive, isOnGCD and isEnabled never secret; startTime and duration secret in a
-- fight. The fake world's cooldowns (CW.cooldowns) hold the times.
local function forever()
    C_Spell.GetSpellCooldown = function(id)
        local c = CW.cooldowns[id]
        local active = c ~= nil and (c.duration or 0) > 0 and GetTime() < c.start + c.duration
        local start, dur = c and c.start or 0, c and c.duration or 0
        local hide = stub.combat == true
        return { isActive = active, isOnGCD = active and c.gcd == true, isEnabled = true, modRate = 1,
                 startTime = hide and stub.Secret(start) or start, duration = hide and stub.Secret(dur) or dur }
    end
end

-- A class logged in with spell id placed as an icon (its catalogue row, else added by id).
local function place(class, id)
    local w = W.Build(class)
    forever()
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    local key
    local r = w.Row(id)
    if r and r.spell == id then
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

-- Stormstrike placed with "When its cooldown resets, glow" and a flash.
local function stormstrike(lines)
    local w, key = place("SHAMAN", STORMSTRIKE)
    T.truthy(w.ns.Draft.Write(key, { lines = lines or { { moment = "reset", action = "glow" },
        { moment = "reset", action = "flash" } } }), "the line saves")
    w.Pass()
    return w, key
end

-- Your cast: the spell goes on its cooldown at once, as the client starts it.
local function cast(w, s)
    w.Cast(STORMSTRIKE)
    w.Cooldown(STORMSTRIKE, s or CLIENT_CD)
end

-- Time passes and the poll beats once.
local function after(w, s)
    w.Advance(s)
    stub.RunTickers()
    stub.RunTimers()
end

local GLOW, FLASH = "cooldownReset:glow", "cooldownReset:flash"

-- ---------------------------------------------------------------------
-- 1. Data: grounded in Daylight UI's Proc Alerts list and the client
-- ---------------------------------------------------------------------

T.test("reset data: Stormstrike's reset from Daylight UI's list, its cooldown from the client", function()
    local L = W.Links()
    T.deq(L.resets[STORMSTRIKE], { key = "stormstrike", class = "SHAMAN", talent = IMPROVED, cd = 8000, hold = HOLD },
        "SpellCooldowns 55241: 8000 ms; Data.lua: dur 4")
    local n = 0
    for _ in pairs(L.resets) do n = n + 1 end
    T.eq(n, 1, "one reset spell on Forever")
end)

T.test("reset data: matches the pinned Daylight UI's mode reset procs, every rank", function()
    local chunk = assert(loadfile(stub.DUI_ROOT .. "DaylightUI_Procs/Data.lua"))
    local env = setmetatable({ DaylightUI = { L = setmetatable({}, { __index = function(_, k) return k end }) } },
        { __index = _G })
    setfenv(chunk, env)
    local ns = {}
    chunk("DaylightUI_Procs", ns)
    local want = {}
    for _, p in ipairs(ns.Data.PROCS) do
        if p.mode == "reset" then
            for _, id in ipairs(p.cast) do want[id] = { key = p.key, class = p.class, talent = p.spell, hold = p.dur } end
        end
    end
    T.truthy(next(want), "Daylight UI lists a reset")
    local got = {}
    for id, r in pairs(W.Links().resets) do got[id] = { key = r.key, class = r.class, talent = r.talent, hold = r.hold } end
    T.deq(got, want, "run tools/make_aura_links.py after a re-pin")
end)

-- ---------------------------------------------------------------------
-- 2. Offered only where a reset is grounded
-- ---------------------------------------------------------------------

T.test("reset words: Stormstrike offers When its cooldown resets, with every look", function()
    local w, key = place("SHAMAN", STORMSTRIKE)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.resets, true)
    local m = moments(G, kind)
    T.eq(m.reset, "glow,sound,flash,sparkle,screen,flare,pulse,border,halo,text,swap")
    T.eq((G.MomentWords("reset", nil, kind)), "When its cooldown resets")
    T.eq(G.ClauseWords("cooldownReset"), "its cooldown just reset")
    T.eq(G.Describe({ moment = "reset", action = "glow" }, kind), "When its cooldown resets, glow.")
    noErrors()
end)

T.test("reset words: spells no talent resets have no reset moment", function()
    for _, id in ipairs({ LIGHTNING_BOLT, EARTH_SHOCK }) do
        local w, key = place("SHAMAN", id)
        local G = w.ns.Grammar
        local kind = G.Kind(key)
        T.falsy(kind.resets, tostring(id))
        T.isnil(moments(G, kind).reset, tostring(id))
        T.falsy(w.ns.Conditions.FitsKind("cooldownReset", kind), tostring(id) .. ": no clause either")
    end
    noErrors()
end)

T.test("reset words: Improved Stormstrike's piece shows its mana buff, so no Proc pop, and names Stormstrike", function()
    local w, key = place("SHAMAN", IMPROVED)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.resetOf, STORMSTRIKE)
    T.falsy(kind.resets, "no cooldown of its own to reset")
    T.isnil(moments(G, kind).reset)
    for _, r in ipairs(G.Recipes(kind)) do T.truthy(r ~= "procPop", "no Proc pop") end
    T.truthy(G.Fits(kind, "up", "glow"), "While it's active, glow stays: the buff is real")
    local text = "This talent's proc is Stormstrike's cooldown reset. Place Stormstrike and use "
        .. "\"When its cooldown resets\"."
    T.eq(G.ResetNote(kind), text)
    local ws, ks = place("SHAMAN", STORMSTRIKE)
    T.isnil(ws.ns.Grammar.ResetNote(ws.ns.Grammar.Kind(ks)), "none on Stormstrike")
    -- The drawer shows it under the piece's lines.
    w, key = place("SHAMAN", IMPROVED)
    T.truthy(w.AB.CdmEditor.Open())
    stub.RunTimers()
    w.AB.CdmEditor.Select(key)
    stub.RunTimers()
    local found
    for _, b in ipairs(w.ns.Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b.resetNote then found = b.said end
    end
    T.eq(found, text)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. Detection in the class world
-- ---------------------------------------------------------------------

T.test("reset: in a fight, a cooldown ending early after your cast lights the line", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    T.falsy(lit(w, key, GLOW), "still cooling down")
    w.Ready(STORMSTRIKE)
    T.truthy(lit(w, key, GLOW), "the reset lights the glow")
    T.truthy(lit(w, key, FLASH), "and the flash")
    noErrors()
end)

T.test("reset: a cooldown that runs its usual length never lights it", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, CLIENT_CD)
    w.Ready(STORMSTRIKE)
    after(w, 0.2)
    T.falsy(lit(w, key, GLOW), "the usual end")
    noErrors()
end)

T.test("reset: out of a fight it never lights (a dodge or parry needs one, as Proc Alerts rules)", function()
    local w, key = stormstrike()
    cast(w)
    after(w, 2)
    w.Ready(STORMSTRIKE)
    T.falsy(lit(w, key, GLOW))
    -- A fight starting right after must not bring that end back as a reset.
    w.EnterCombat()
    w.ns.Conditions.Refresh(key)
    T.falsy(lit(w, key, GLOW), "not lit by the fight's start")
    noErrors()
end)

T.test("reset: only the global cooldown left at the cooldown event lights it", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    -- Reset while another cast's global cooldown runs: active, on the GCD.
    CW.Cooldown(STORMSTRIKE, 1.5, true)
    stub.RunTimers()
    T.truthy(lit(w, key, GLOW))
    noErrors()
end)

T.test("reset: the poll sees an early end with no cooldown event", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    CW.cooldowns[STORMSTRIKE] = nil
    T.falsy(lit(w, key, GLOW), "nothing told yet")
    after(w, 0.2)
    T.truthy(lit(w, key, GLOW), "the poll's beat")
    noErrors()
end)

T.test("reset: the first second after the cast is skipped", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 0.5)
    w.Ready(STORMSTRIKE)
    T.falsy(lit(w, key, GLOW))
    noErrors()
end)

T.test("reset: held looks hold for Daylight UI's 4 s, then go", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    w.Ready(STORMSTRIKE)
    after(w, HOLD - 1)
    T.truthy(lit(w, key, GLOW), "held")
    -- No event comes when the hold ends: the poll's beat puts it out.
    stub.Advance(1.2)
    stub.RunTickers()
    T.falsy(lit(w, key, GLOW), "gone after the hold")
    noErrors()
end)

T.test("reset: a read past the hold says no, before the poll's beat", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    w.Ready(STORMSTRIKE)
    T.truthy(lit(w, key, GLOW))
    stub.Advance(HOLD + 0.1)
    w.ns.Conditions.Refresh(key)
    T.falsy(lit(w, key, GLOW))
    noErrors()
end)

T.test("reset: the next cast or the fight's end puts it out", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    w.Ready(STORMSTRIKE)
    T.truthy(lit(w, key, GLOW))
    cast(w)
    T.falsy(lit(w, key, GLOW), "spent by the cast")
    after(w, 2)
    w.Ready(STORMSTRIKE)
    T.truthy(lit(w, key, GLOW), "a second reset")
    w.LeaveCombat()
    T.falsy(lit(w, key, GLOW), "the fight's end")
    noErrors()
end)

T.test("reset: the cooldown seen plainly is its length, so a shorter one's usual end never lights", function()
    local w, key = stormstrike()
    -- Out of a fight the game answers the length: 6 s here (gear or a talent).
    cast(w, 6)
    after(w, 6.1)
    w.Ready(STORMSTRIKE)
    w.EnterCombat()
    cast(w, 6)
    after(w, 6)
    w.Ready(STORMSTRIKE)
    after(w, 0.2)
    T.falsy(lit(w, key, GLOW), "6 s is its usual end now")
    T.eq(w.ns.Resets.Length(STORMSTRIKE), 6)
    noErrors()
end)

T.test("reset: it lights with Proc Alerts off; EZ-CDM never asks it", function()
    local w, key = stormstrike()
    T.isnil(w.DUI.API.ProcAlerts(), "no Proc Alerts in this world")
    w.EnterCombat()
    cast(w)
    after(w, 3)
    w.Ready(STORMSTRIKE)
    T.truthy(lit(w, key, GLOW))
    noErrors()
end)

T.test("reset: a flare line gets the hold as its time", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    w.Ready(STORMSTRIKE)
    local left, dur = w.ns.Conditions.Get("cooldownReset").time(key)
    T.eq(dur, HOLD)
    T.truthy(left > 0 and left <= HOLD)
    noErrors()
end)

T.test("reset: no poll and no events while no rule uses it", function()
    local w = place("SHAMAN", STORMSTRIKE)
    w.EnterCombat()
    cast(w)
    T.falsy(w.ns.Resets.Watching(), "nothing listens")
    T.falsy(w.ns.Resets.Polling(), "no poll")
    noErrors()
end)

T.test("reset: its detail logs what it read, plain in a fight", function()
    local w, key = stormstrike()
    w.EnterCombat()
    cast(w)
    after(w, 2)
    local d = w.ns.Conditions.Get("cooldownReset").detail(key)
    T.eq(d.spell, STORMSTRIKE)
    T.eq(d.isActive, true)
    T.eq(d.length, CLIENT_CD)
    T.eq(d.lengthFrom, "client")
    T.truthy(d.armed and d.armed >= 2)
    for f, v in pairs(d) do T.falsy(issecretvalue(v), f) end
    noErrors()
end)
