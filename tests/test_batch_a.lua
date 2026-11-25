local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Wave 1, conditions batch A (docs/tasks/w1-batch-a.md): plain conditions read from
-- the game, each offered only where the client's data says it makes sense, driven
-- through the class world (tests/classworld.lua).

local KICK, PUMMEL, CHARGE, REND = 1766, 6552, 100, 772
local EARTH_SHOCK, SEARING, WINDFURY, ROCKBITER = 8042, 3599, 8232, 8017

local BATCH = { "hasTarget", "targetEnemy", "targetBoss", "outOfRange", "targetCasting", "onlyGcd", "totemUp",
                "weaponBuffMissing", "inCombat", "noCombat", "inGroup", "inInstance" }
local FORMS = { DRUID = { "formBear", "formCat", "formAquatic", "formTravel", "formMoonkin" },
                WARRIOR = { "formBattle", "formDefensive", "formBerserker" }, ROGUE = { "formStealth" } }

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

local function rule(w, key, moment, action)
    T.truthy(w.ns.Draft.Write(key, { lines = { { moment = moment, action = action or "glow" } } }), "the line saved")
    w.Pass()
end

local function lit(w, key, id)
    for _, v in pairs(w.ns.Conditions.Lit(key) or {}) do
        if v == id then return true end
    end
    return false
end

local function fits(w, key, ck) return w.ns.Conditions.FitsKind(ck, w.ns.Grammar.Kind(key)) end

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

T.test("batch A: each condition is plain, reads, has words, and gets glow and sound", function()
    local w = W.Build("WARRIOR")
    local C, G = w.ns.Conditions, w.ns.Grammar
    local keys = {}
    for _, k in ipairs(BATCH) do keys[#keys + 1] = k end
    for _, list in pairs(FORMS) do
        for _, k in ipairs(list) do keys[#keys + 1] = k end
    end
    for _, k in ipairs(keys) do
        local c = C.Get(k)
        T.truthy(c, k .. " is registered")
        if c then
            T.eq(c.secrecy, "plain", k .. " is plain")
            T.eq(type(c.read), "function", k .. " reads")
            T.truthy(G.WORDING.moments[c.moment], k .. " has its moment words")
            T.truthy(G.WORDING.clauses[k], k .. " has its clause words")
            T.truthy(c.actions.glow and c.actions.sound, k .. " glow and sound")
            -- Gray stays with the cooldown icon's words, as Daylight UI's card keeps it.
            T.eq(c.actions.gray ~= nil, c.layer == "cooldown", k .. " gray only on the cooldown icon")
            T.eq(type(c.detail), "function", k .. " logs what it read")
        end
    end
    noErrors()
end)

T.test("batch A: the rows Forever can't answer plainly are not registered", function()
    local w = W.Build("WARRIOR")
    local C = w.ns.Conditions
    -- Interruptible: the cast's notInterruptible is secret in boss fights, keystones
    -- and battlegrounds (Daylight UI CastBar.lua), so it is never plain: batch B
    -- draws it through the client tier (test_batch_b).
    T.eq(C.Get("targetInterruptible") and C.Get("targetInterruptible").secrecy, "client", "no plain interruptible")
    -- Charges: no class spell in the client's tables has a charge category.
    T.falsy(C.Get("fullCharges"), "no full charges")
    T.falsy(C.Get("recharging"), "no recharging")
    local charged = {}
    for id, v in pairs(W.Links().spells) do
        if v:find("h", 1, true) then charged[#charged + 1] = id end
    end
    T.eq(#charged, 0, "no class spell has charges")
end)

T.test("batch A: the words read as sentences", function()
    local w = W.Build("WARRIOR")
    local G = w.ns.Grammar
    T.eq(G.MomentWords("outOfRange"), "When my target is out of range")
    T.eq(G.MomentWords("formBattle"), "When I'm in Battle Stance")
    T.eq(G.ClauseWords("totemUp"), "my totem is up")
    T.eq(G.Describe({ moment = "targetCasting", action = "glow", clauses = { { cond = "targetEnemy" } } }),
        "When my target is casting and my target is an enemy, glow.")
    T.eq(G.NeverWords("inCombat", "noCombat"), "can't both be true: I'm in combat or out of it")
    T.eq(G.NeverWords("formBattle", "formDefensive"), "can't both be true: I'm in one at a time")
end)

T.test("batch A: the client's data letters: global cooldown, interrupt, weapon buffs", function()
    local L = W.Links()
    T.truthy(L.spells[KICK]:find("i", 1, true) and L.spells[KICK]:find("g", 1, true), "Kick interrupts, on the GCD")
    T.truthy(L.spells[2139]:find("i", 1, true), "Counterspell interrupts")
    T.falsy(L.spells[2139]:find("g", 1, true), "Counterspell is off the GCD")
    T.falsy(L.spells[CHARGE]:find("g", 1, true), "Charge is off the GCD")
    T.truthy(L.spells[116]:find("g", 1, true), "Frostbolt is on it")
    T.eq(table.concat(L.imbues[ROCKBITER], ","), "1,6,29,503,683,1663,1664", "Rockbiter's ranks' enchants")
    T.eq(table.concat(L.imbues[WINDFURY], ","), "283,284,525,1669", "Windfury's")
end)

-- ---------------------------------------------------------------------
-- Where each is offered
-- ---------------------------------------------------------------------

T.test("batch A: forms are offered to their class only, and never two at once", function()
    local w, key = place("WARRIOR", REND)
    T.truthy(fits(w, key, "formBattle"), "a warrior's stance")
    T.falsy(fits(w, key, "formCat"), "no druid form")
    T.falsy(fits(w, key, "formStealth"), "no stealth")
    T.truthy(w.ns.Conditions.Excludes("formBattle", "formBerserker"), "one stance at a time")
    local d, shred = place("DRUID", 5221)
    T.truthy(fits(d, shred, "formCat"), "a druid's Cat Form")
    T.falsy(fits(d, shred, "formBattle"), "no warrior stance")
    T.falsy(d.ns.Conditions.Get("formCaster"), "no form is no condition")
    noErrors()
end)

T.test("batch A: target casting on interrupts, only on the GCD on spells it touches", function()
    local w, pummel = place("WARRIOR", PUMMEL)
    T.truthy(fits(w, pummel, "targetCasting"), "Pummel interrupts")
    T.truthy(fits(w, pummel, "onlyGcd"), "Pummel is on the GCD")
    local w2, charge = place("WARRIOR", CHARGE)
    T.falsy(fits(w2, charge, "targetCasting"), "Charge doesn't interrupt")
    T.falsy(fits(w2, charge, "onlyGcd"), "Charge is off the GCD")
    noErrors()
end)

T.test("batch A: out of range only on a spell that checks range", function()
    local w, key = place("WARRIOR", REND)
    w.HasRange({})
    T.falsy(fits(w, key, "outOfRange"), "no range, no words")
    w.HasRange({ [w.ns.Bridge.SpellOf(key)] = true })
    T.truthy(fits(w, key, "outOfRange"), "a range")
    noErrors()
end)

T.test("batch A: totem and weapon buff words on a shaman's totem and imbue only", function()
    local w, totem = place("SHAMAN", SEARING)
    T.truthy(fits(w, totem, "totemUp"), "Searing Totem")
    T.falsy(fits(w, totem, "weaponBuffMissing"), "a totem casts no weapon buff")
    local w2, wind = place("SHAMAN", WINDFURY)
    T.truthy(fits(w2, wind, "weaponBuffMissing"), "Windfury Weapon")
    T.falsy(fits(w2, wind, "totemUp"), "Windfury Weapon is no totem")
    local w3, shock = place("SHAMAN", EARTH_SHOCK)
    T.falsy(fits(w3, shock, "totemUp") or fits(w3, shock, "weaponBuffMissing"), "Earth Shock neither")
    T.truthy(fits(w3, shock, "targetCasting"), "Earth Shock interrupts")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Reads, events and the drawn line
-- ---------------------------------------------------------------------

T.test("batch A: target, enemy and boss follow the target", function()
    local w, key = place("WARRIOR", REND)
    local C = w.ns.Conditions
    rule(w, key, "hasTarget", "glow")
    w.Unit("target", { reaction = 2 })
    T.eq(C.Sample("hasTarget", key), true)
    T.eq(C.Sample("targetEnemy", key), true)
    T.eq(C.Sample("targetBoss", key), false)
    T.truthy(lit(w, key, "hasTarget:glow"), "glow with a target")
    rule(w, key, "targetBoss", "glow")
    T.falsy(lit(w, key, "targetBoss:glow"), "no boss")
    w.Unit("target", { boss = true })
    T.truthy(lit(w, key, "targetBoss:glow"), "glow on a boss")
    w.Unit("target", { boss = false, classification = "worldboss" })
    T.eq(C.Sample("targetBoss", key), true, "a world boss")
    w.Unit("target", { reaction = 5, classification = "normal" })
    T.eq(C.Sample("targetEnemy", key), false, "a friend")
    rule(w, key, "hasTarget", "glow")
    w.KillTarget()
    T.eq(C.Sample("hasTarget", key), false)
    T.eq(C.Sample("targetEnemy", key), false, "no target is no enemy")
    T.falsy(lit(w, key, "hasTarget:glow"), "the glow goes")
    noErrors()
end)

T.test("batch A: out of range turns on the spell's range check and follows its event", function()
    local w, key = place("WARRIOR", REND)
    local sid = w.ns.Bridge.SpellOf(key)
    w.HasRange({ [sid] = true })
    rule(w, key, "outOfRange", "glow")
    T.eq(w.rangeChecks[sid], true, "the range check is on while a rule uses it")
    T.truthy(table.concat(w.ns.Conditions.Listening(), " "):find("SPELL_RANGE_CHECK_UPDATE", 1, true), "listening")
    w.Range(false)
    T.truthy(lit(w, key, "outOfRange:glow"), "glow out of range")
    w.Range(true)
    T.falsy(lit(w, key, "outOfRange:glow"), "in range")
    w.Range(stub.Secret(false))
    T.eq(w.ns.Conditions.Sample("outOfRange", key), nil, "a secret answer reads unknown")
    w.ns.Draft.Write(key, { lines = {} })
    w.Pass()
    T.eq(w.rangeChecks[sid], false, "off once no rule uses it")
    noErrors()
end)

T.test("batch A: target casting follows the target's casts and channels", function()
    local w, key = place("WARRIOR", PUMMEL)
    rule(w, key, "targetCasting", "glow")
    w.NewTarget()
    T.falsy(lit(w, key, "targetCasting:glow"))
    w.TargetCasts("cast")
    T.truthy(lit(w, key, "targetCasting:glow"), "a cast")
    w.TargetCasts(nil)
    T.falsy(lit(w, key, "targetCasting:glow"), "stopped")
    w.TargetCasts("channel")
    T.truthy(lit(w, key, "targetCasting:glow"), "a channel")
    -- In a boss fight the cast's fields are secret, but whether one came is a type.
    stub.units.target.channel = { name = stub.Secret("Drain"), notInterruptible = stub.Secret(true) }
    T.eq(w.ns.Conditions.Sample("targetCasting", key), true, "a secret cast still reads")
    noErrors()
end)

T.test("batch A: only on the GCD follows SPELL_UPDATE_COOLDOWN", function()
    local w, key = place("WARRIOR", PUMMEL)
    rule(w, key, "onlyGcd", "gray")
    local sid = w.ns.Bridge.SpellOf(key)
    w.Gcd(sid, true)
    T.truthy(lit(w, key, "onlyGcd:gray"), "gray while only the GCD holds it")
    w.EnterCombat()
    T.truthy(lit(w, key, "onlyGcd:gray"), "still plain in a fight")
    w.Gcd(sid, false)
    T.falsy(lit(w, key, "onlyGcd:gray"))
    w.LeaveCombat()
    noErrors()
end)

T.test("batch A: a stance, a druid form and stealth", function()
    local w, key = place("WARRIOR", REND)
    rule(w, key, "formBerserker", "glow")
    w.Form("Battle")
    T.falsy(lit(w, key, "formBerserker:glow"))
    w.Form("Berserker")
    T.truthy(lit(w, key, "formBerserker:glow"), "in Berserker Stance")
    w.Form("Berserker", { secret = true })
    T.eq(w.ns.Conditions.Sample("formBerserker", key), nil, "a secret form reads unknown")
    local r, stab = place("ROGUE", 53)
    rule(r, stab, "formStealth", "glow")
    r.Form("Stealth")
    T.truthy(lit(r, stab, "formStealth:glow"), "stealthed")
    r.Form(nil)
    T.falsy(lit(r, stab, "formStealth:glow"))
    noErrors()
end)

T.test("batch A: my totem stands, from my own cast into its slot", function()
    local w, key = place("SHAMAN", SEARING)
    rule(w, key, "totemUp", "glow")
    local slot = w.AB.CdmCustom.SlotOf(SEARING)
    T.truthy(slot, "Searing Totem has a slot")
    w.Totem(slot, SEARING)
    T.truthy(lit(w, key, "totemUp:glow"), "it stands")
    w.EnterCombat()
    T.eq(w.ns.Conditions.Sample("totemUp", key), true, "plain in a fight")
    w.Totem(slot, nil)
    T.falsy(lit(w, key, "totemUp:glow"), "gone")
    w.LeaveCombat()
    noErrors()
end)

T.test("batch A: my weapon buff is missing until a weapon holds any rank's enchant", function()
    local w, key = place("SHAMAN", WINDFURY)
    rule(w, key, "weaponBuffMissing", "glow")
    w.Enchant({})
    T.truthy(lit(w, key, "weaponBuffMissing:glow"), "missing")
    w.Enchant({ { slot = 1, enchantID = 5 } })
    T.truthy(lit(w, key, "weaponBuffMissing:glow"), "Flametongue's enchant on the off hand isn't Windfury's")
    w.Enchant({ { slot = 0, enchantID = 1669 } })
    T.falsy(lit(w, key, "weaponBuffMissing:glow"), "Windfury's top rank on the main hand")
    noErrors()
end)

T.test("batch A: combat, group and instance", function()
    local w, key = place("WARRIOR", REND)
    local C = w.ns.Conditions
    w.ns.Draft.Write(key, { lines = { { moment = "inCombat", action = "glow", clauses = { { cond = "inGroup" } } } } })
    w.Pass()
    w.EnterCombat()
    T.falsy(lit(w, key, "inCombat:glow"), "in a fight, not in a group")
    w.Group(true)
    T.truthy(lit(w, key, "inCombat:glow"), "in a fight and a group")
    w.LeaveCombat()
    T.falsy(lit(w, key, "inCombat:glow"))
    T.eq(C.Sample("noCombat", key), true)
    w.Instance("party")
    T.eq(C.Sample("inInstance", key), true, "a dungeon")
    w.Instance("pvp")
    T.eq(C.Sample("inInstance", key), true, "a battleground, as Daylight UI's Instances")
    w.Instance(nil)
    T.eq(C.Sample("inInstance", key), false, "the open world")
    w.Group(false)
    noErrors()
end)

T.test("batch A: the combat, group and instance words wait behind more…", function()
    local w, key = place("WARRIOR", REND)
    local kind = w.ns.Grammar.Kind(key)
    local plain, more = {}, {}
    for _, m in ipairs(w.ns.Grammar.Words(kind, { drawer = true })) do plain[m.moment] = true end
    for _, m in ipairs(w.ns.Grammar.Words(kind, { drawer = true, more = true })) do more[m.moment] = true end
    for _, k in ipairs({ "inCombat", "noCombat", "inGroup", "inInstance" }) do
        T.falsy(plain[k], k .. " hidden")
        T.truthy(more[k], k .. " behind more…")
    end
    T.truthy(plain.hasTarget and plain.formBattle, "the rest show")
    noErrors()
end)
