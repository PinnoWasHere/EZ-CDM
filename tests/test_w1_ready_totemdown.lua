local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- docs/tasks/w1-ready-totemdown.md: two EZ-CDM moments that every EZ look takes.
--   offCooldown  its real cooldown is over (C_Spell.GetSpellCooldown isActive and
--                isOnGCD, both NeverSecret). On a spell with a real cooldown that is no
--                totem, Daylight UI's "When it's ready" means the same, so the two are
--                one chip. One-shot looks fire as the cooldown ends; held looks stay lit
--                while it's ready
--   totemDown    the totem is gone, the opposite of totemUp. On a totem showing its own
--                time, one chip with Daylight UI's "When my totem is down"

local EARTH_SHOCK, SEARING, GROUNDING, LIGHTNING_BOLT = 8042, 3599, 8177, 403

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A Shaman logged in with spell id placed as an icon, as test_w1_totem_mana places it.
-- The piece's spell is the highest rank the Shaman knows (Bridge.SpellOf), which the
-- cooldown drivers take.
local function place(id, opts)
    local w = W.Build("SHAMAN", opts)
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

local function fired(w, key, effect)
    local f = w.ns.Looks.Fired(key, effect)
    return f and f.n or 0
end

local LOOKS = "flash,sparkle,screen,flare,pulse,border,halo,text,swap"

-- ---------------------------------------------------------------------
-- 1. When it's ready: Daylight UI's moment and EZ-CDM's offCooldown, one chip
-- ---------------------------------------------------------------------

T.test("ready merge: Earth Shock shows one When it's ready, with Daylight UI's rows and every EZ look", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.realCooldown, true, "a real cooldown by the client's tables")
    T.truthy(kind.cooldownReady, "Daylight UI's ready is its cooldown's end")
    local m = moments(G, kind)
    T.isnil(m.offCooldown, "no second chip that means the same")
    T.eq(m.ready, "show,fade,hide,glow,sound," .. LOOKS, "Daylight UI's glow and sound, EZ-CDM's looks")
    T.eq((G.MomentWords("ready", nil, kind)), "When it's ready", "Daylight UI's words")
    T.eq(G.Describe({ moment = "ready", action = "flash" }, kind), "When it's ready, flash it.")
    local fields, problems = G.Compile({ lines = { { moment = "ready", action = "glow" },
        { moment = "ready", action = "flash" }, { moment = "ready", action = "pulse" } } }, kind)
    T.eq(#problems, 0)
    T.eq(fields.readyGlow, true, "the glow stays Daylight UI's")
    T.eq(fields["ez:offCooldown:flash"], true, "the looks are EZ-CDM's")
    T.eq(fields["ez:offCooldown:pulse"], true)
    T.isnil(fields["ez:offCooldown:glow"])
    T.eq(G.LineCondition({ moment = "ready", action = "flash" }, kind), "offCooldown")
    T.isnil(G.LineCondition({ moment = "ready", action = "glow" }, kind), "Daylight UI's own line")
    T.truthy(G.TakesClauses({ moment = "ready", action = "flash" }, kind))
    noErrors()
end)

T.test("ready merge: a one-shot look fires as the real cooldown ends, never on the GCD or at login", function()
    local w, key = place(EARTH_SHOCK)
    local sid = w.ns.Bridge.SpellOf(key)
    T.truthy(w.ns.Draft.Write(key, { lines = { { moment = "ready", action = "flash" } } }))
    w.Pass()
    T.eq(fired(w, key, "flash"), 0, "ready at login: no flash")
    w.Gcd(sid, true)
    T.eq(fired(w, key, "flash"), 0, "the global cooldown: nothing")
    w.Gcd(sid, false)
    T.eq(fired(w, key, "flash"), 0, "the global cooldown over: still nothing")
    w.Cooldown(sid, 6)
    T.eq(fired(w, key, "flash"), 0, "on cooldown: nothing")
    w.Ready(sid)
    T.eq(fired(w, key, "flash"), 1, "its cooldown ends: one flash")
    w.ns.Conditions.Refresh(key)
    T.eq(fired(w, key, "flash"), 1, "still ready: no second flash")
    w.Cooldown(sid, 6)
    w.Ready(sid)
    T.eq(fired(w, key, "flash"), 2, "the next cooldown's end: again")
    noErrors()
end)

T.test("ready merge: a held look is lit while it's ready, the GCD too, dark on its cooldown", function()
    local w, key = place(EARTH_SHOCK)
    local sid = w.ns.Bridge.SpellOf(key)
    T.truthy(w.ns.Draft.Write(key, { lines = { { moment = "ready", action = "pulse" } } }))
    w.Pass()
    T.truthy(lit(w, key, "offCooldown:pulse"), "ready: lit")
    w.Gcd(sid, true)
    T.truthy(lit(w, key, "offCooldown:pulse"), "the global cooldown isn't its cooldown")
    w.Gcd(sid, false)
    w.Cooldown(sid, 6)
    T.falsy(lit(w, key, "offCooldown:pulse"), "on cooldown: dark")
    w.Ready(sid)
    T.truthy(lit(w, key, "offCooldown:pulse"), "ready again: lit")
    noErrors()
end)

T.test("ready merge: and I'm in combat fires only as the cooldown ends in a fight", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local line = { moment = "ready", action = "flash", clauses = { { cond = "inCombat" } } }
    T.eq(G.Describe(line, G.Kind(key)), "When it's ready and I'm in combat, flash it.")
    local sid = w.ns.Bridge.SpellOf(key)
    T.truthy(w.ns.Draft.Write(key, { lines = { line } }))
    w.Pass()
    w.Cooldown(sid, 6)
    w.Ready(sid)
    T.eq(fired(w, key, "flash"), 0, "out of a fight: nothing")
    w.EnterCombat()
    T.eq(fired(w, key, "flash"), 0, "a fight starts while it's ready: nothing, its cooldown didn't end")
    w.Cooldown(sid, 6)
    w.Ready(sid)
    T.eq(fired(w, key, "flash"), 1, "its cooldown ends in a fight: one flash")
    noErrors()
end)

T.test("ready merge: rules round-trip through the merged moment and a reload", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local rules = { lines = {
        { moment = "ready", action = "glow" },
        { moment = "ready", action = "flash", value = { 1, 0, 0 } },
        { moment = "ready", action = "text", value = "Go", clauses = { { cond = "inCombat" } } },
    }, group = {}, forms = {} }
    local fields, problems = G.Compile(rules, kind)
    T.eq(#problems, 0, "compiles")
    local back, bp = G.Decompile(fields, kind)
    T.eq(#bp, 0, "decompiles")
    T.deq(back.lines, rules.lines, "the same lines, under ready")
    T.truthy(w.ns.Draft.Write(key, rules))
    w.Pass()
    T.deq(w.ns.Draft.Rules(key).lines, rules.lines, "saved and read back")
    T.deq(w.ns.Conditions.Rule(key), { offCooldown = { flash = { value = { 1, 0, 0 } },
        text = { value = "Go", clauses = { { cond = "inCombat" } } } } }, "EZ-CDM's store")
    w.Reload()
    T.deq(w.ns.Draft.Rules(key).lines, rules.lines, "the same after a reload")
    noErrors()
end)

T.test("ready merge: Lightning Bolt has no real cooldown, so no EZ look on When it's ready", function()
    local w, key = place(LIGHTNING_BOLT)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.falsy(kind.cooldownReady)
    T.falsy(w.ns.Conditions.FitsKind("offCooldown", kind))
    local m = moments(G, kind)
    T.isnil(m.offCooldown)
    T.falsy((m.ready or ""):find("flash", 1, true), "Daylight UI's rows only")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. When my totem is down
-- ---------------------------------------------------------------------

T.test("totem down merge: Searing Totem shows one When my totem is down, Daylight UI's rows and every EZ look", function()
    local w, key = place(SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy(kind.totemTime)
    local m = moments(G, kind)
    T.isnil(m.totemDown, "no second chip")
    T.isnil(m.offCooldown, "no real cooldown")
    T.eq(m.ready, "show,fade,hide,glow,sound," .. LOOKS)
    T.eq((G.MomentWords("ready", nil, kind)), "When my totem is down")
    local fields = G.Compile({ lines = { { moment = "ready", action = "hide" },
        { moment = "ready", action = "flare" } } }, kind)
    T.eq(fields.onReady, "hide", "Daylight UI's row")
    T.truthy(fields["ez:totemDown:flare"], "EZ-CDM's look in totemDown's store")
    T.eq(G.LineCondition({ moment = "ready", action = "flare" }, kind), "totemDown")
    noErrors()
end)

T.test("totem down: When my totem is down and I'm in combat, flare around me (Flames, Impact)", function()
    local w, key = place(SEARING, { procs = true })
    local G = w.ns.Grammar
    local line = { moment = "ready", action = "flare", value = { design = "flames", anim = "impact" },
                   clauses = { { cond = "inCombat" } } }
    T.eq(G.Describe(line, G.Kind(key)),
        "When my totem is down and I'm in combat, flare around me (Flames, Impact, Proc Alerts' sound).")
    T.truthy(w.ns.Draft.Write(key, { lines = { line } }))
    w.Pass()
    local fk = "EZ-CDM:" .. w.ns.Looks.FlareKey(key, "totemDown:flare")
    local function flare() return stub.procs.Flares.live[fk] end
    T.isnil(flare(), "out of a fight: nothing")
    local slot = w.AB.CdmCustom.SlotOf(SEARING)
    w.Totem(slot, SEARING)
    w.EnterCombat()
    T.isnil(flare(), "the totem stands: nothing")
    w.Totem(slot, nil)
    local f = flare()
    T.truthy(f, "the totem is gone in a fight: the flare lands")
    T.eq(f and f.design, "flames")
    T.eq(f and f.anim, "impact")
    w.Totem(slot, SEARING)
    T.isnil(flare(), "a new totem: gone")
    w.Totem(slot, nil)
    T.truthy(flare(), "down again: back")
    w.LeaveCombat()
    T.isnil(flare(), "the fight ends: gone")
    noErrors()
end)

T.test("ready merge: Grounding Totem is a catalogue cooldown, not a Daylight UI totem, so its ready merges", function()
    local w, key = place(GROUNDING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.falsy(kind.totem, "Daylight UI times it by its spell's cooldown")
    T.truthy(kind.cooldownReady)
    local m = moments(G, kind)
    T.eq(m.ready, "show,fade,hide,glow,sound," .. LOOKS)
    T.isnil(m.offCooldown)
    T.isnil(m.totemDown, "no totem moment, as totemUp")
    noErrors()
end)

-- No placed piece on Forever is a Daylight UI totem with a real cooldown (test_sweep_ready
-- counts them), so this one is made from Searing Totem's kind.
T.test("totem down: a totem with a real cooldown keeps When it's off cooldown as its own chip", function()
    local w, key = place(SEARING)
    local G = w.ns.Grammar
    local kind = setmetatable({ realCooldown = true }, { __index = G.Kind(key) })
    T.falsy(kind.cooldownReady, "Daylight UI's ready is the totem there")
    local m = moments(G, kind)
    T.isnil(m.totemDown)
    T.eq(m.offCooldown, "glow,sound," .. LOOKS, "its own chip, glow and sound too")
    T.eq((G.MomentWords("offCooldown", nil, kind)), "When it's off cooldown")
    T.eq(G.Describe({ moment = "offCooldown", action = "flash", clauses = { { cond = "inCombat" } } }, kind),
        "When it's off cooldown and I'm in combat, flash it.")
    noErrors()
end)

T.test("totem down: a totem not showing its own time keeps When my totem is down as its own chip", function()
    local w, key = place(SEARING)
    local G = w.ns.Grammar
    local kind = setmetatable({ totemTime = false }, { __index = G.Kind(key) })
    local m = moments(G, kind)
    T.eq(m.totemDown, "glow,sound," .. LOOKS)
    T.eq((G.MomentWords("totemDown", nil, kind)), "When my totem is down")
    T.falsy(G.Fits(kind, "ready", "flare"))
    noErrors()
end)

T.test("totem down: never with my totem is up, and the store round-trips", function()
    local w, key = place(SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local refused = G.ClauseRefusals(kind, { moment = "ready", action = "flash" }, { more = true })
    local why
    for _, r in ipairs(refused) do if r.cond == "totemUp" then why = r.why end end
    T.eq(why, "can't both be true: my totem is up or down")
    local rules = { lines = { { moment = "ready", action = "fade", value = 0.5 }, { moment = "ready", action = "sparkle" },
        { moment = "cooldown", action = "glow" } }, group = {}, forms = {} }
    T.truthy(w.ns.Draft.Write(key, rules))
    w.Pass()
    T.deq(w.ns.Draft.Rules(key).lines, rules.lines)
    T.deq(w.ns.Conditions.Rule(key), { totemDown = { sparkle = true }, totemUp = { glow = true } })
    local slot = w.AB.CdmCustom.SlotOf(SEARING)
    w.Totem(slot, SEARING)
    T.falsy(lit(w, key, "totemDown:sparkle"))
    T.truthy(lit(w, key, "totemUp:glow"))
    w.Totem(slot, nil)
    T.truthy(lit(w, key, "totemDown:sparkle"))
    T.falsy(lit(w, key, "totemUp:glow"))
    noErrors()
end)
