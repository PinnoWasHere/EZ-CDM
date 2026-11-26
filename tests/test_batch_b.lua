local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Wave 1, conditions batch B (docs/tasks/w1-batch-b.md): the client tier. Each
-- condition hands the game's answer to its line's layer alpha and never reads it.
-- The fake game (W.ClientTier) answers plain, secret or nil, as the game may.

local EXECUTE, HEROIC_STRIKE, BATTLE_SHOUT, PUMMEL = 5308, 78, 6673, 6552
local LIGHTNING_BOLT, EARTH_SHOCK, SEARING, KICK = 403, 8042, 3599, 1766
local SKULL_BASH, WRATH, GROWL = 410176, 5176, 2649
local MANA, RAGE, ENERGY = 0, 1, 3

local BATCH = { "targetLow", "playerLow", "powerLow" }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A class logged in with spell id placed as an icon: a catalogue spell by its
-- Essential row, any other by its tray key.
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

local function rule(w, key, line)
    line.action = line.action or "glow"
    local ok, why = w.ns.Draft.Write(key, { lines = { line } })
    w.Pass()
    return ok, why
end

local function fits(w, key, ck) return w.ns.Conditions.FitsKind(ck, w.ns.Grammar.Kind(key)) end

-- What the game drew on a line's layer: its alpha as the client holds it, and
-- whether that alpha is secret.
local function drawn(w, key, id)
    local layer = w.ns.Conditions.Layer(key, id)
    if not layer then return nil end
    local a = layer:GetAlpha()
    return stub.Plain(a), issecretvalue(a)
end

-- ---------------------------------------------------------------------
-- The client's data
-- ---------------------------------------------------------------------

T.test("batch B: the client's data names each class's own powers (ChrClassesXPowerTypes)", function()
    local p = W.Links().classPowers
    T.truthy(type(p) == "table", "AuraLinks.classPowers")
    T.deq(p.DRUID, { "mana", "rage", "energy", "combo points" })
    T.deq(p.WARRIOR, { "rage", "combo points" })
    T.deq(p.ROGUE, { "energy", "combo points" })
    T.deq(p.SHAMAN, { "mana" })
    -- A hunter's spells cost focus (Growl, Claw), but the focus is its pet's.
    T.deq(p.HUNTER, { "mana" })
    T.deq(W.Links().costs[GROWL], { "focus" })
end)

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

T.test("batch B: each condition is client tier, drives, takes a number where it has one, and has no sound", function()
    local w = W.Build("WARRIOR")
    local C, G = w.ns.Conditions, w.ns.Grammar
    local defaults = { targetLow = 20, playerLow = 30, powerLow = 30 }
    for _, k in ipairs(BATCH) do
        local c = C.Get(k)
        T.truthy(c, k .. " is registered")
        if c then
            T.eq(c.secrecy, "client", k .. " is client tier")
            T.eq(type(c.drive), "function", k .. " drives")
            T.isnil(c.read, k .. " never reads")
            T.isnil(c.ticker, k .. " runs on events, no ticker")
            T.isnil(c.actions.sound, k .. " has no sound: nothing tells it turned on")
            T.truthy(c.actions.glow, k .. " glows")
            T.eq(c.actions.gray ~= nil, c.layer == "cooldown", k .. " gray only on the cooldown icon")
            T.eq(type(c.detail), "function", k .. " logs what the game answered")
            T.truthy(G.WORDING.moments[c.moment], k .. " has its moment words")
            T.truthy(G.WORDING.clauses[k], k .. " has its clause words")
            if defaults[k] then
                T.deq({ c.param.min, c.param.max, c.param.default }, { 1, 99, defaults[k] }, k .. " takes 1-99")
            else
                T.isnil(c.param, k .. " takes no number")
            end
        end
    end
    noErrors()
end)

T.test("batch B: the words read as sentences, numbers and powers put in", function()
    local w, key = place("WARRIOR", EXECUTE)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(G.Describe({ moment = "targetLow", action = "glow", n = 20 }, kind), "When my target is below 20% health, glow.")
    T.eq(G.Describe({ moment = "playerLow", action = "glow", n = 35 }, kind), "When I'm below 35% health, glow.")
    T.eq(G.Describe({ moment = "powerLow", action = "glow", n = 25 }, kind), "When my rage is below 25%, glow.")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Where each fits, from the client's data
-- ---------------------------------------------------------------------

T.test("batch B: target health fits a spell cast at a unit you pick (letter t)", function()
    local w, key = place("WARRIOR", EXECUTE)
    T.truthy(fits(w, key, "targetLow"), "Execute (gt)")
    local w2, shout = place("WARRIOR", BATTLE_SHOUT)
    T.falsy(fits(w2, shout, "targetLow"), "Battle Shout (bg) is cast at no one")
    local w3, totem = place("SHAMAN", SEARING)
    T.falsy(fits(w3, totem, "targetLow"), "Searing Totem (g)")
    noErrors()
end)

T.test("batch B: my health fits a piece you can cast", function()
    for _, x in ipairs({ { "WARRIOR", EXECUTE }, { "SHAMAN", LIGHTNING_BOLT }, { "SHAMAN", SEARING } }) do
        local w, key = place(x[1], x[2])
        T.truthy(fits(w, key, "playerLow"), x[1] .. " " .. x[2])
    end
    -- Battle Shout has no cooldown, so its piece shows the buff: nothing to press.
    local w, shout = place("WARRIOR", BATTLE_SHOUT)
    T.falsy(w.ns.Grammar.Kind(shout).cooldown, "a buff piece")
    T.falsy(fits(w, shout, "playerLow"), "Battle Shout's buff")
    noErrors()
end)

T.test("batch B: my power fits only a power the spell costs and my class has", function()
    local w, key = place("WARRIOR", HEROIC_STRIKE)
    T.truthy(fits(w, key, "powerLow"), "Heroic Strike costs rage, a warrior's")
    local w2, bolt = place("SHAMAN", LIGHTNING_BOLT)
    T.truthy(fits(w2, bolt, "powerLow"), "Lightning Bolt costs mana")
    T.eq(w2.ns.Grammar.MomentWords("powerLow", 40, w2.ns.Grammar.Kind(bolt)), "When my mana is below 40%")
    local w3, kick = place("SHAMAN", KICK)
    T.falsy(fits(w3, kick, "powerLow"), "a shaman has no energy (Kick added by id)")
    local w4, bash = place("DRUID", SKULL_BASH)
    T.truthy(fits(w4, bash, "powerLow"), "Skull Bash: energy in Cat Form, rage in Bear Form, both a druid's")
    T.eq(w4.ns.Grammar.MomentWords("powerLow", 30, w4.ns.Grammar.Kind(bash)), "When my energy or rage is below 30%")
    local w5, growl = place("HUNTER", GROWL)
    T.falsy(fits(w5, growl, "powerLow"), "Growl's focus is the pet's")
    local w6, charge = place("WARRIOR", 100)
    T.falsy(fits(w6, charge, "powerLow"), "Charge costs nothing")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The number box: typed, 1-99, saved and read back
-- ---------------------------------------------------------------------

T.test("batch B: a typed number round-trips through the draft, its default saved as none", function()
    local w, key = place("WARRIOR", EXECUTE)
    local C, D = w.ns.Conditions, w.ns.Draft
    T.truthy(rule(w, key, { moment = "targetLow", n = 35 }))
    T.deq(C.Rule(key), { targetLow = { glow = { n = 35 } } })
    local back
    for _, l in ipairs(D.Rules(key).lines) do if l.moment == "targetLow" then back = l end end
    T.eq(back and back.n, 35, "read back")
    T.truthy(rule(w, key, { moment = "targetLow", n = 20 }))
    T.deq(C.Rule(key), { targetLow = { glow = true } }, "the default is saved as none")
    T.falsy(C.NumberFits("targetLow", 0), "0 is out of range")
    T.falsy(C.NumberFits("targetLow", 100), "100 is out of range")
    T.falsy(C.NumberFits("targetLow", 12.5), "whole numbers only")
    T.truthy(C.NumberFits("playerLow", 99))
    noErrors()
end)

T.test("batch B: a client part goes last; first in a line with an and-part, it is refused", function()
    local w, key = place("WARRIOR", EXECUTE)
    local ok, why = rule(w, key, { moment = "targetLow", clauses = { { cond = "targetBoss" } } })
    T.falsy(ok, "refused")
    T.eq(why, "problems")
    T.truthy(rule(w, key, { moment = "targetBoss", clauses = { { cond = "targetLow", n = 30 } } }), "last is fine")
    T.deq(w.ns.Conditions.Rule(key), { targetBoss = { glow = { clauses = { { cond = "targetLow", n = 30 } } } } })
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The drive: the game's answer, plain, secret or nil, into the layer
-- ---------------------------------------------------------------------

T.test("batch B: my target below 20%: the curve's answer lands in the layer, secret or plain", function()
    local w, key = place("WARRIOR", EXECUTE)
    T.truthy(rule(w, key, { moment = "targetLow" }))
    local id = "targetLow:glow"
    T.eq((drawn(w, key, id)), 0, "no target: dark")
    w.NewTarget()
    w.Health("target", 0.5)
    T.eq((drawn(w, key, id)), 0, "50%: dark")
    w.Health("target", 0.1)
    T.eq((drawn(w, key, id)), 1, "10%: lit")
    w.Health("target", 0.2)
    T.eq((drawn(w, key, id)), 0, "20% is not below 20%")
    w.Health("target", 0)
    T.eq((drawn(w, key, id)), 0, "dead is not low")
    w.EnterCombat()
    w.Health("target", 0.1, "secret")
    local a, isSecret = drawn(w, key, id)
    T.eq(a, 1, "the game's 1 under the secret")
    T.truthy(isSecret, "the layer's alpha is the game's secret")
    T.eq(w.ns.Conditions.Visible(key, id).alpha, w.ns.Conditions.SECRET, "Visible says secret")
    T.truthy(w.ns.Conditions.Visible(key, id).layered, "the glow hangs under the layer")
    w.Health("target", 0.1, "nil")
    T.eq((drawn(w, key, id)), 0, "no answer: dark, no error")
    w.KillTarget()
    T.eq((drawn(w, key, id)), 0, "target gone: dark")
    noErrors()
end)

T.test("batch B: I'm below 30%: my health into the layer, in and out of a fight", function()
    local w, key = place("SHAMAN", LIGHTNING_BOLT)
    T.truthy(rule(w, key, { moment = "playerLow" }))
    local id = "playerLow:glow"
    w.Health("player", 0.9)
    T.eq((drawn(w, key, id)), 0, "90%: dark")
    w.Health("player", 0.25)
    T.eq((drawn(w, key, id)), 1, "25%: lit")
    w.EnterCombat()
    w.Health("player", 0.8, "secret")
    local a, isSecret = drawn(w, key, id)
    T.eq(a, 0, "80% in a fight: the game's 0")
    T.truthy(isSecret)
    w.Health("player", 0.1, "secret")
    T.eq((drawn(w, key, id)), 1, "10% in a fight: the game's 1")
    -- Daylight UI's own low-health warning hands the answer to SetAlpha unchecked
    -- (CombatText/Feed.lua), so a nil errors there, in the event, before EZ-CDM hears
    -- it. Forever's docs say this answer is never nil; the fake game models it anyway,
    -- and EZ-CDM's own read of it follows.
    local ok, err = pcall(w.Health, "player", 0.1, "nil")
    T.truthy(ok or tostring(err):find("CombatText/Feed.lua", 1, true), tostring(err))
    w.ns.Conditions.Refresh(key)
    T.eq((drawn(w, key, id)), 0, "no answer: dark")
    noErrors()
end)

T.test("batch B: my rage below 30% reads rage; a secret bar lands whole", function()
    local w, key = place("WARRIOR", HEROIC_STRIKE)
    T.truthy(rule(w, key, { moment = "powerLow" }))
    local id = "powerLow:glow"
    w.Power(RAGE, 0.8)
    T.eq((drawn(w, key, id)), 0, "80 rage: dark")
    w.Power(RAGE, 0)
    T.eq((drawn(w, key, id)), 1, "an empty bar is low")
    w.Power(MANA, 0)
    w.Power(RAGE, 0.5)
    T.eq((drawn(w, key, id)), 0, "reads rage, not mana")
    w.EnterCombat()
    w.Power(RAGE, 0.1, "secret")
    local a, isSecret = drawn(w, key, id)
    T.eq(a, 1)
    T.truthy(isSecret, "secret in a fight")
    w.Power(RAGE, 0.1, "nil")
    T.eq((drawn(w, key, id)), 0, "no answer: dark")
    noErrors()
end)

T.test("batch B: Skull Bash reads the bar the druid shows now, energy or rage", function()
    local w, key = place("DRUID", SKULL_BASH)
    T.truthy(rule(w, key, { moment = "powerLow" }))
    local id = "powerLow:glow"
    w.Power(ENERGY, 0.1)
    w.Power(RAGE, 0.9)
    w.Bar(ENERGY, "ENERGY")
    T.eq((drawn(w, key, id)), 1, "Cat Form: 10 energy")
    w.Bar(RAGE, "RAGE")
    T.eq((drawn(w, key, id)), 0, "Bear Form: 90 rage")
    w.Bar(MANA, "MANA")
    T.eq((drawn(w, key, id)), 0, "caster form: neither")
    noErrors()
end)

T.test("batch B: a plain part and a client part: the plain one gates, the client one draws", function()
    local w, key = place("WARRIOR", EXECUTE)
    T.truthy(rule(w, key, { moment = "targetBoss", clauses = { { cond = "targetLow" } } }))
    local id = "targetBoss:glow"
    w.NewTarget()
    w.Health("target", 0.1)
    T.falsy(w.ns.Conditions.Lit(key), "not a boss: not lit")
    w.Unit("target", { boss = true })
    w.Health("target", 0.1)
    T.eq((drawn(w, key, id)), 1, "a boss at 10%")
    w.Health("target", 0.6)
    T.eq((drawn(w, key, id)), 0, "a boss at 60%")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The dev suite's view: Sample and detail log plain, <secret> or nil
-- ---------------------------------------------------------------------

T.test("batch B: Sample says what the drive set; detail logs the game's answer plain, <secret> or nil", function()
    local w, key = place("WARRIOR", EXECUTE)
    local C = w.ns.Conditions
    -- Health: SecretReturns, secret always (seen in game for UnitHealth out of combat).
    w.NewTarget()
    w.Health("target", 0.1)
    T.eq(C.Sample("targetLow", key), C.SECRET, "health is always the game's secret")
    T.eq(C.Get("targetLow").detail(key).pct, C.SECRET)
    w.Health("target", 0.1, "nil")
    T.eq(C.Sample("targetLow", key), false, "no answer: dark")
    T.eq(C.Get("targetLow").detail(key).pct, "nil", "and the log says nil")
    -- Power: plain out of a fight, secret in one (SecretWhenUnitPowerRestricted).
    w.Power(RAGE, 0.1)
    T.eq(C.Sample("powerLow", key), true)
    local d = C.Get("powerLow").detail(key)
    T.eq(d.power, RAGE)
    T.eq(d.pct, 0.1)
    w.Power(RAGE, 0.9)
    T.eq(C.Sample("powerLow", key), false)
    w.EnterCombat()
    w.Power(RAGE, 0.1)
    T.eq(C.Sample("powerLow", key), C.SECRET, "in a fight")
    T.eq(C.Get("powerLow").detail(key).pct, C.SECRET)
    w.Power(RAGE, 0.1, "nil")
    T.eq(C.Get("powerLow").detail(key).pct, "nil")
    noErrors()
end)
