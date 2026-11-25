local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- The owner's in-game findings on batch A (docs/tasks/w1-batch-a-fixes.md). Every word
-- stands on the client's spell data (EZ-CDM/AuraLinks.lua, from tools/make_aura_links.py)
-- or the game's own answer, driven through the class world (tests/classworld.lua).

local LIGHTNING_BOLT, EARTH_SHOCK, FLAME_SHOCK, SEARING = 403, 8042, 8050, 3599
local LIGHTNING_SHIELD, WATER_SHIELD, EARTH_SHIELD = 324, 408510, 408514
local LS_RANKS = { 324, 325, 905, 945, 8134, 10431, 10432 }
local TARGET_WORDS = { "hasTarget", "targetEnemy", "targetBoss" }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

-- A class logged in with spell id placed as an icon: a catalogue spell by its row, any
-- other added by its id as the editor adds one, and a named key ("mainhand") as is.
local function place(class, id)
    local w = W.Build(class)
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    local key
    if type(id) == "string" then
        key = id
    else
        local r = w.Row(id)
        if r and r.category == W.ESSENTIAL then
            key = CW.ID(r.spell, r.category)
        else
            stub.knownSpells[id] = true
            stub.spells[id] = stub.spells[id] or { name = "Spell " .. id }
            key = assert(Ed.KeyForID("spell", tostring(id)))
        end
    end
    D.AddPiece(D.Ensure(1), key, "icon", 0, 0)
    w.Pass()
    return w, key
end

local function rule(w, key, moment, action, n)
    T.truthy(w.ns.Draft.Write(key, { lines = { { moment = moment, action = action or "glow", n = n } } }), "the line saved")
    w.Pass()
end

local function lit(w, key, id)
    for _, v in pairs(w.ns.Conditions.Lit(key) or {}) do
        if v == id then return true end
    end
    return false
end

local function moments(w, key)
    local out = {}
    for _, m in ipairs(w.ns.Grammar.Words(w.ns.Grammar.Kind(key), { more = true })) do out[m.moment] = m.actions end
    return out
end

-- Every phrase the drawer could show for a piece: its moments with their actions, its
-- clauses, What it shows and the hidden note.
local function phrases(w, key)
    local G, C = w.ns.Grammar, w.ns.Conditions
    local kind = G.Kind(key)
    local out = {}
    for _, m in ipairs(G.Words(kind, { more = true })) do
        for _, a in ipairs(m.actions) do out[#out + 1] = G.Describe({ moment = m.moment, action = a }, kind) end
    end
    for _, c in ipairs(C.List()) do
        if C.FitsKind(c.key, kind) then out[#out + 1] = G.ClauseWords(c.key, nil, kind) end
    end
    for _, s in ipairs(G.ShowsChoices(kind)) do out[#out + 1] = G.ShowsPhrase(s, kind) end
    return out
end

local function saysAura(text) return text:find("%f[%a]de?buff%f[%A]") ~= nil end

-- ---------------------------------------------------------------------
-- The client's data
-- ---------------------------------------------------------------------

T.test("w1a fixes: the client's data names charges, target spells and no aura where there is none", function()
    local L = W.Links()
    for _, id in ipairs(LS_RANKS) do T.eq(L.charges[id], 3, "Lightning Shield " .. id .. ": 3 charges") end
    T.eq(L.charges[WATER_SHIELD], 3, "Water Shield")
    T.eq(L.charges[EARTH_SHIELD], 9, "Earth Shield")
    T.isnil(L.charges[12536], "Clearcasting's one charge is no count to watch")
    T.isnil(L.charges[FLAME_SHOCK], "Flame Shock has none")
    -- Lightning Bolt: SpellEffect 678918, school damage at the target enemy, nothing else.
    T.eq(L.spells[LIGHTNING_BOLT], "gtn", "Lightning Bolt: the global cooldown, cast at a target, no aura")
    T.falsy(L.spells[12975]:find("n", 1, true), "Last Stand: a dummy effect, whose buff 12976 the server puts up")
    for _, id in ipairs({ 8042, 8044, 8045, 8046, 10412, 10413, 10414 }) do
        T.truthy(L.spells[id]:find("n", 1, true) and not L.spells[id]:find("[bd]"), "Earth Shock " .. id .. " puts up no aura")
        T.truthy(L.spells[id]:find("t", 1, true), "Earth Shock " .. id .. " is cast at a target")
    end
    T.falsy(L.spells[SEARING]:find("t", 1, true), "a totem is cast at no unit")
    T.falsy(L.spells[LIGHTNING_SHIELD]:find("t", 1, true), "a self buff is cast at no unit")
    T.truthy(L.spells[774]:find("t", 1, true), "Rejuvenation is cast at a friend")
    T.truthy(W.Facts()[LIGHTNING_BOLT].harmful, "the game calls Lightning Bolt harmful")
end)

-- ---------------------------------------------------------------------
-- Finding 2: Lightning Bolt has no debuff
-- ---------------------------------------------------------------------

T.test("w1a fixes: Lightning Bolt names no buff or debuff, and shows itself", function()
    local w, key = place("SHAMAN", LIGHTNING_BOLT)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.harmful, true, "the game calls it harmful")
    T.eq(kind.noAura, true, "the client's tables give it no aura")
    T.isnil(kind.aura, "so no aura word")
    T.deq(G.ShowsChoices(kind), { "cooldown" }, "its only pick is itself")
    for _, text in ipairs(phrases(w, key)) do
        T.falsy(saysAura(text), "no aura in \"" .. text .. "\"")
    end
    local m = moments(w, key)
    for _, mm in ipairs({ "up", "ends", "missing", "recast" }) do T.isnil(m[mm], "no " .. mm .. " moment") end
    -- Daylight UI shows it as a buff until the player picks: the note says so and its
    -- one fix shows it.
    local note = G.HiddenNote(kind, { moment = "blocked", action = "glow" })
    T.eq(note and note.code, "button", "hidden while Daylight UI waits for a buff")
    T.eq(G.FixText("shows", kind), "Show it")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Finding 3: Earth Shock has no debuff; What it shows in plain words
-- ---------------------------------------------------------------------

T.test("w1a fixes: Earth Shock has its cooldown only, and the picks read as plain English", function()
    local w, key = place("SHAMAN", EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.noAura, true, "no rank puts up an aura")
    T.isnil(kind.aura)
    T.deq(G.ShowsChoices(kind), { "cooldown" })
    T.falsy(table.concat(G.Extras(kind), " "):find("shows", 1, true), "nothing to choose, so no What it shows")
    for _, text in ipairs(phrases(w, key)) do T.falsy(saysAura(text), "no aura in \"" .. text .. "\"") end
    -- Flame Shock does put up a debuff (SpellEffect apply aura at the enemy).
    local w2, shock = place("SHAMAN", FLAME_SHOCK)
    local fk = w2.ns.Grammar.Kind(shock)
    T.eq(fk.aura, "debuff")
    T.deq(w2.ns.Grammar.ShowsChoices(fk), { "both", "cooldown", "buff" })
    T.eq(w2.ns.Grammar.ShowsPhrase("both", fk), "show its debuff, then its cooldown")
    T.eq(w2.ns.Grammar.ShowsPhrase("buff", fk), "show only its debuff")
    T.eq(w2.ns.Grammar.ShowsPhrase("cooldown", fk), "show its cooldown")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Finding 4: a totem's words fit a totem
-- ---------------------------------------------------------------------

T.test("w1a fixes: Searing Totem offers no target words, no only-on-GCD, and totem time in totem words", function()
    local w, key = place("SHAMAN", SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local m = moments(w, key)
    for _, t in ipairs(TARGET_WORDS) do T.isnil(m[t], "no " .. t .. ": a totem is cast at no unit") end
    T.isnil(m.onlyGcd, "no real cooldown, so the global cooldown is all it ever has")
    T.isnil(m.totemUp, "its glow and sound read under While my totem is up (Grammar.MERGED)")
    T.truthy(G.Fits(kind, "cooldown", "glow"), "the merged moment takes the glow")
    T.eq((G.MomentWords("cooldown", nil, kind)), "While my totem is up", "Daylight UI times the totem as its cooldown")
    T.eq((G.MomentWords("ready", nil, kind)), "When my totem is down")
    T.eq((G.MomentWords("almost", nil, kind)), "When my totem is almost gone")
    -- Standing is no reason it can't be cast: a totem drops again at once.
    rule(w, key, "blocked", "glow")
    w.Usable(true, false)
    w.Totem(1, SEARING)
    T.eq(w.ns.Bridge.TotemUp(SEARING), true, "the totem stands")
    T.eq(select(3, w.ns.Bridge.UsableState(key)), true, "Daylight UI reads the standing totem as its cooldown")
    T.eq(w.ns.Conditions.Sample("cantCast", key), false, "castable while it stands")
    T.falsy(lit(w, key, "cantCast:glow"))
    w.Usable(false, false)
    T.truthy(lit(w, key, "cantCast:glow"), "not usable still counts")
    noErrors()
end)

T.test("w1a fixes: target words only on a spell cast at a unit, only on the GCD only with a real cooldown", function()
    local w, shock = place("SHAMAN", EARTH_SHOCK)
    local m = moments(w, shock)
    for _, t in ipairs(TARGET_WORDS) do T.truthy(m[t], t .. " on Earth Shock") end
    T.truthy(m.onlyGcd, "a real cooldown and the global one")
    local w2, bolt = place("SHAMAN", LIGHTNING_BOLT)
    T.isnil(moments(w2, bolt).onlyGcd, "Lightning Bolt has no cooldown of its own")
    local w3, shield = place("SHAMAN", LIGHTNING_SHIELD)
    for _, t in ipairs(TARGET_WORDS) do T.isnil(moments(w3, shield)[t], "no " .. t .. " on a self buff") end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Finding 5: a weapon buff glows when it wears off
-- ---------------------------------------------------------------------

T.test("w1a fixes: a weapon enchant takes glow when it wears off, lit until it's back", function()
    local w, key = place("SHAMAN", "mainhand")
    local G, AB = w.ns.Grammar, w.AB
    local kind = G.Kind(key)
    T.truthy(G.Fits(kind, "ends", "glow"), "glow when it wears off")
    T.eq(G.ActionWords("ends", "glow"), "glow until it's back")
    local fields = G.Compile({ lines = { { moment = "ends", action = "glow" } } }, kind)
    T.eq(fields.missingGlow, true, "Daylight UI's glow while it's not active")
    rule(w, key, "ends", "glow")
    T.eq(AB.CdmData.Get(1).pieces[key].missingGlow, true, "saved on the piece")
    w.Enchant({})
    w.Advance(1)
    T.truthy(AB.CdmEffects.GlowShown(AB.CdmAuras.Frame(key)), "lit once the enchant is gone")
    w.Enchant({ { slot = 0, timeLeft = 1800000, enchantID = 29 } })
    w.Advance(1)
    T.falsy(AB.CdmEffects.GlowShown(AB.CdmAuras.Frame(key)), "out once it's back")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Finding 7: no target is not out of range
-- ---------------------------------------------------------------------

T.test("w1a fixes: out of range goes dark when the target is cleared", function()
    local w, key = place("SHAMAN", LIGHTNING_BOLT)
    local sid = w.ns.Bridge.SpellOf(key)
    w.HasRange({ [sid] = true })
    rule(w, key, "outOfRange", "glow")
    w.Range(false)
    T.truthy(lit(w, key, "outOfRange:glow"), "lit out of range")
    w.KillTarget()
    T.eq(w.ns.Conditions.Sample("outOfRange", key), false, "no target is not out of range")
    T.falsy(lit(w, key, "outOfRange:glow"), "the glow goes with the target")
    w.NewTarget()
    w.Range(true)
    T.falsy(lit(w, key, "outOfRange:glow"), "a new target in range")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Finding 1: charges left on a buff that comes with charges
-- ---------------------------------------------------------------------

-- Lightning Shield up on the player with n charges, as the client counts them
-- (AuraData.applications).
local function shieldUp(w, n)
    w.BuffDown(LIGHTNING_SHIELD)
    w.BuffUp(LIGHTNING_SHIELD, { unit = "player", duration = 600, applications = n })
end

T.test("w1a fixes: charges left, offered on a charged buff the game never hides", function()
    local w, key = place("SHAMAN", LIGHTNING_SHIELD)
    local C, G = w.ns.Conditions, w.ns.Grammar
    local c = C.Get("chargesLeft")
    T.truthy(c, "registered")
    T.eq(c.secrecy, "plain")
    T.eq(c.layer, "any", "it reads the aura up itself")
    T.eq(G.MomentWords("chargesLeft", 1), "When its charges are down to 1")
    T.eq(G.ClauseWords("chargesLeft", 2), "its charges are down to 2")
    -- The game says whether the aura is ever secret (C_Secrets.GetSpellAuraSecrecy).
    T.falsy(C.FitsKind("chargesLeft", G.Kind(key)), "not while the game may hide the aura in a fight")
    for _, id in ipairs(LS_RANKS) do stub.neverSecretAuras[id] = true end
    local kind = G.Kind(key)
    T.eq(kind.charges, 3, "3 charges by the client's data")
    T.truthy(C.FitsKind("chargesLeft", kind), "offered once the game never hides it")
    local w2, shock = place("SHAMAN", FLAME_SHOCK)
    T.falsy(w2.ns.Conditions.FitsKind("chargesLeft", w2.ns.Grammar.Kind(shock)), "Flame Shock has no charges")
    noErrors()
end)

T.test("w1a fixes: charges left follows the aura's count, in a fight too", function()
    local w, key = place("SHAMAN", LIGHTNING_SHIELD)
    for _, id in ipairs(LS_RANKS) do stub.neverSecretAuras[id] = true end
    rule(w, key, "chargesLeft", "glow", 1)
    T.truthy(table.concat(w.ns.Conditions.Listening(), " "):find("UNIT_AURA", 1, true), "listening to the player's auras")
    shieldUp(w, 3)
    T.falsy(lit(w, key, "chargesLeft:glow"), "3 charges")
    shieldUp(w, 1)
    T.truthy(lit(w, key, "chargesLeft:glow"), "down to 1")
    w.BuffDown(LIGHTNING_SHIELD)
    T.falsy(lit(w, key, "chargesLeft:glow"), "gone is not down to 1")
    T.eq(w.ns.Conditions.Sample("chargesLeft", key, 1), false)
    -- In a fight. The game's docs say a NeverSecret aura "will never yield secret
    -- values when queried" (SecretWrapperConstants); the fake game wraps the call by
    -- its SecretWhenUnitAuraRestricted flag alone. A secret count reads unknown.
    w.EnterCombat()
    shieldUp(w, 1)
    T.isnil(w.ns.Conditions.Sample("chargesLeft", key, 1), "a secret count is no guess")
    local d = w.ns.Conditions.Get("chargesLeft").detail(key)
    T.eq(d.charges, w.ns.Conditions.SECRET, "the dev log says so")
    stub.plainSecrets = true
    shieldUp(w, 2)
    T.falsy(lit(w, key, "chargesLeft:glow"), "2 in a fight, read as the docs say")
    shieldUp(w, 1)
    T.truthy(lit(w, key, "chargesLeft:glow"), "1 in a fight")
    stub.plainSecrets = nil
    w.LeaveCombat()
    noErrors()
end)
