local stub = require("stub")
local CW = require("cdmworld")

-- EZ-CDM/Grammar.lua: sentences to Daylight UI's CDM fields and back, against Daylight
-- UI's real Cooldown Manager and the game's own viewers (cdmworld, a warrior).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871
local ESSENTIAL, UTILITY, BUFFS = 0, 1, 2

-- Daylight UI, the game's Cooldown Manager and EZ-CDM, logged in.
local function world()
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        _G.RAGE = "Rage"   -- the game's global string for the power token
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true, powerType = 1, powerToken = "RAGE" },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, BLOCK, RAGE, CLAP, WALL }, showAll = true })
        for id, name in pairs({ [SHOUT] = "Battle Shout", [REND] = "Rend", [BLOCK] = "Shield Block",
                                [RAGE] = "Bloodrage", [CLAP] = "Thunder Clap", [WALL] = "Shield Wall" }) do
            stub.spells[id] = { name = name }
        end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    return DUI, ns, ns.Grammar, stub.actionbars
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end

local function codes(problems)
    local out = {}
    for i, p in ipairs(problems) do
        out[i] = (p.line and ("line " .. p.line) or p.group and ("group " .. p.group)
            or p.shows and ("shows " .. p.shows) or ("form " .. tostring(p.form)))
            .. ": " .. p.code
    end
    return table.concat(out, ", ")
end

local COLOR = { 0.2, 0.4, 0.6 }
local SOUND = "dui:quest"

-- ---------------------------------------------------------------------
-- Step 1: word tables and the field map
-- ---------------------------------------------------------------------

-- Whether a field is EZ-CDM's own (Grammar.EZ_FIELDS).
local function isEz(G, field)
    for _, f in ipairs(G.EZ_FIELDS) do
        if f == field then return true end
    end
    return false
end

-- Every { field, value } the grammar can write, with a sample color, sound and fade.
local function emissions(G, B)
    local out = {}
    local function add(field, value, why) out[#out + 1] = { field = field, value = value, why = why } end
    for _, m in ipairs(G.MOMENTS) do
        for _, a in ipairs(G.ACTIONS) do
            local e = G.MAP[m][a]
            if e then
                local why = m .. " " .. a
                if e.look then
                    -- Look keys are checked on their own (lookEmissions).
                elseif e.alias then
                    -- It writes the line it stands for (Grammar.Canonical), listed there.
                elseif e.all then
                    for _, f in ipairs(e.all) do add(f, e.value, why) end
                elseif e.paint then
                    add(e.paint, { 0.2, 0.4, 0.6, 0.5 }, why)
                elseif isEz(G, e.field) then
                    -- EZ-CDM's own (Effects, Overlay), never written to Daylight UI.
                elseif e.sound then
                    add(e.field, SOUND, why)
                else
                    add(e.field, e.value, why)
                end
                if e.color then add(e.color, COLOR, why) end
                if e.alpha then add("cdAlpha", 0.25, why) end
            end
        end
    end
    for _, list in pairs(B.Forms()) do
        for _, f in ipairs(list) do add("hideIn" .. f.key, true, "form " .. f.key) end
    end
    for _, st in ipairs(B.GlowStyles()) do add("glowStyle", st.key, "style " .. st.key) end
    return out
end

-- Every { look key, value } the grammar can write.
local function lookEmissions(G)
    local out = {}
    for _, m in ipairs(G.MOMENTS) do
        for _, a in ipairs(G.ACTIONS) do
            local e = G.MAP[m][a]
            if e and e.look then
                local why = m .. " " .. a
                out[#out + 1] = { field = e.look, value = true, why = why }
                out[#out + 1] = { field = e.lookColor, value = COLOR, why = why }
                out[#out + 1] = { field = e.at, value = 5, why = why }
            end
        end
    end
    return out
end

-- Daylight UI's own rule for a value (CdmData.lua SPELL_FIELDS and CHAIN_FIELDS).
local function validSpell(spec, v, B)
    if not spec then return false end
    if spec.bool then return type(v) == "boolean" end
    if spec.color then return type(v) == "table" and (#v == 3 or (spec.alpha and #v == 4)) and type(v[1]) == "number" end
    if spec.values then
        for _, x in ipairs(spec.values) do if x == v then return true end end
        return false
    end
    if spec.sound then return (B.SoundChoices())[v] ~= nil end
    if spec.glow then return v == "ring" or _G.DaylightUI.Motion.GLOW_STYLES[v] ~= nil end
    if spec.min then return type(v) == "number" and v >= spec.min and v <= spec.max end
    return false
end

T.test("grammar: every field and value it can write is valid on Daylight UI 2.3.0", function()
    local _, ns, G, AB = world()
    local B = ns.Bridge
    local spell, bad = AB.CdmData.SPELL_FIELDS, {}
    local list = emissions(G, B)
    T.truthy(#list > 30, "the map writes many fields: " .. #list)
    for _, e in ipairs(list) do
        if not validSpell(spell[e.field], e.value, B) then
            bad[#bad + 1] = e.why .. ": " .. e.field .. " = " .. tostring(e.value)
        end
        -- Daylight UI's own setter takes it, on a scratch set never saved, in the
        -- shape the field is for.
        local shape = spell[e.field] and spell[e.field].bar and "bar" or "icon"
        local set = { pieces = { k = { shape = shape } }, chains = {} }
        if not AB.CdmData.SetSpellValue(set, "k", e.field, e.value) then
            bad[#bad + 1] = e.why .. ": SetSpellValue refused " .. e.field
        end
    end
    local looks = AB.CdmData.LOOK_FIELDS
    local lookList = lookEmissions(G)
    T.truthy(#lookList >= 3, "the look keys")
    for _, e in ipairs(lookList) do
        if not looks[e.field] then bad[#bad + 1] = e.why .. ": " .. e.field .. " isn't a look key" end
        local set = { pieces = { k = { shape = "icon" } }, chains = {} }
        if not AB.CdmData.SetLook(set, "k", e.field, e.value) then
            bad[#bad + 1] = e.why .. ": SetLook refused " .. e.field
        end
    end
    for _, f in ipairs(G.LOOK_FIELDS) do
        if not looks[f] then bad[#bad + 1] = "LOOK_FIELDS lists " .. f .. ", which Daylight UI lacks" end
    end
    for _, f in ipairs(G.FIELDS) do
        if not spell[f] then bad[#bad + 1] = "FIELDS lists " .. f .. ", which Daylight UI lacks" end
    end
    -- Each group word as the chain field and value it compiles to.
    local chain = AB.CdmData.CHAIN_FIELDS
    for i, word in ipairs(G.GROUP) do
        local field = G.CHAIN[i]
        T.eq(field, G.GROUP_FIELD[word] or word, word .. "'s chain field")
        local values = word == "where" and G.WHERE or { true }
        for _, w in ipairs(values) do
            local v = G.Compile({ group = { [word] = w } }).chain[field]
            T.truthy(v ~= nil, word .. " sets " .. field)
            local spec = chain[field]
            local ok = spec == true and type(v) == "boolean"
            if type(spec) == "table" then
                for _, x in ipairs(spec) do ok = ok or x == v end
            end
            if not ok then bad[#bad + 1] = "group " .. word .. ": " .. field .. " = " .. tostring(v) end
            local set = { pieces = { k = { shape = "icon", x = 0, y = 0 } }, chains = {} }
            if not AB.CdmData.SetChainValue(set, "k", field, v) then
                bad[#bad + 1] = "SetChainValue refused " .. field
            end
        end
        T.truthy(B.ChainDefault(field) ~= nil, field .. " has a default")
    end
    T.eq(G.Compile({ group = { keep = true } }).chain.collapse, false, "keep turns Slide over off")
    T.eq(table.concat(bad, "\n  "), "", "every emission is valid")
    noErrors()
end)

T.test("grammar: gray and color go with cooldown only, and sounds only where Daylight UI has one", function()
    local _, _, G = world()
    for _, m in ipairs(G.MOMENTS) do
        T.eq(G.MAP[m].gray ~= nil, m == "cooldown" or m == "unusable" or m == "blocked" or m == "noBuff"
            or m == "outOfRange" or m == "targetCasting" or m == "onlyGcd" or m == "targetInterruptible", m .. " gray")
        T.eq(G.MAP[m].color ~= nil, m == "cooldown", m .. " color")
    end
    T.eq(G.MAP.blocked.gray.cond, "cantCast", "can't cast gray is EZ-CDM's condition")
    T.eq(G.MAP.unusable.gray.cond, "notUsable", "not usable gray too")
    T.eq(G.MAP.short.blue.cond, "noMana", "short blue too")
    T.deq(G.MAP.ends, { sound = { field = "buffEndSound", sound = true },
                        glow = { alias = { moment = "missing", action = "glow" } } },
        "ends takes sound, and glow as the missing glow")
    T.eq(G.MAP.up.hide.field, "hideActive")
    T.eq(G.MAP.missing.show.field, "missing")
    T.eq(G.MAP.missing.hide.field, "hideMissing")
    T.deq(G.MAP.always, { show = G.MAP.always.show }, "always only takes show")
    T.eq(_G.EZCDM_Grammar, G, "the debug handle")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 2: Compile and Decompile for lines
-- ---------------------------------------------------------------------

-- Every moment x action pair the map allows, with the fields it compiles to.
local CASES = {
    { L("always", "show"), {} },
    { L("ready", "show"), {} },
    { L("ready", "fade"), { onReady = "fade" } },
    { L("ready", "fade", 0.25), { onReady = "fade", cdAlpha = 0.25 } },
    { L("ready", "hide"), { onReady = "hide" } },
    { L("ready", "glow"), { readyGlow = true } },
    { L("ready", "glow", COLOR), { readyGlow = true, readyGlowColor = COLOR } },
    { L("ready", "sound", SOUND), { readySound = SOUND } },
    { L("cooldown", "show"), {} },
    { L("cooldown", "fade"), { onCd = "fade" } },
    { L("cooldown", "hide"), { onCd = "hide" } },
    { L("cooldown", "gray"), { desat = "grey" } },
    { L("cooldown", "color"), { desat = "color" } },
    { L("unusable", "show"), {} },
    { L("unusable", "fade"), { onUnusable = "fade" } },
    { L("unusable", "hide"), { onUnusable = "hide" } },
    { L("short", "show"), {} },
    { L("short", "fade"), { onShort = "fade" } },
    { L("short", "hide"), { onShort = "hide" } },
    { L("unusable", "gray"), { ["ez:notUsable:gray"] = true } },
    { L("blocked", "gray"), { ["ez:cantCast:gray"] = true } },
    { L("blocked", "glow"), { ["ez:cantCast:glow"] = true } },
    { L("blocked", "glow", COLOR), { ["ez:cantCast:glow"] = { value = COLOR } } },
    { L("short", "blue"), { ["ez:noMana:blue"] = true } },
    { L("unusable", "glow"), { ["ez:notUsable:glow"] = true } },
    { L("short", "glow", COLOR), { ["ez:noMana:glow"] = { value = COLOR } } },
    -- "Its buff isn't active" is a clause only; as a moment it fits no piece.
    { L("noBuff", "gray"), { ["ez:noBuff:gray"] = true } },
    -- A plain condition's sound line keeps its sound key (Conditions.Spec).
    { L("unusable", "sound", SOUND), { ["ez:notUsable:sound"] = { value = SOUND } } },
    { L("blocked", "sound", SOUND), { ["ez:cantCast:sound"] = { value = SOUND } } },
    { L("short", "sound", SOUND), { ["ez:noMana:sound"] = { value = SOUND } } },
    { L("usable", "glow"), { usableGlow = true } },
    { L("usable", "glow", COLOR), { usableGlow = true, usableGlowColor = COLOR } },
    { L("usable", "sound", SOUND), { usableSound = SOUND } },
    { L("up", "show"), {} },
    { L("up", "hide"), { hideActive = true } },
    { L("up", "glow"), { upGlow = true } },
    { L("up", "glow", COLOR), { upGlow = true, upGlowColor = COLOR } },
    { L("up", "sound", SOUND), { buffSound = SOUND } },
    { L("ends", "sound", SOUND), { buffEndSound = SOUND } },
    { L("missing", "show"), { missing = true } },
    { L("missing", "hide"), { hideMissing = true } },
    { L("missing", "glow"), { missingGlow = true } },
    { L("missing", "glow", COLOR), { missingGlow = true, missingGlowColor = COLOR } },
    { L("recast", "glow"), { clipGlow = true } },
    { L("recast", "glow", COLOR), { clipGlow = true, clipGlowColor = COLOR } },
    { { moment = "recast", action = "glow", at = 5 }, { clipGlow = true, ezLead = 5 } },
    { L("recast", "sound", SOUND), { ezSound = SOUND } },
    { { moment = "recast", action = "sound", value = SOUND, at = 8 }, { ezSound = SOUND, ezLead = 8 } },
    { L("up", "nosweep"), { noDurationSwipe = true } },
    { L("up", "tint"), {} },
    { L("up", "tint", { 0.2, 0.4, 0.6, 0.5 }), { activeColor = { 0.2, 0.4, 0.6, 0.5 } } },
    { L("up", "tint", COLOR), { activeColor = COLOR } },
    { L("cooldown", "nosweep"), { noSwipe = true } },
    { L("cooldown", "nogcd"), { noGcd = true } },
    { L("almost", "numbers"), { look = { low = true } } },
    { L("almost", "numbers", COLOR), { look = { low = true, lowColor = COLOR } } },
    { { moment = "almost", action = "numbers", at = 5 }, { look = { low = true, lowAt = 5 } } },
    -- A glow when it wears off is the glow while it's not active (Grammar.Canonical).
    { L("ends", "glow"), { missingGlow = true } },
    { L("ends", "glow", COLOR), { missingGlow = true, missingGlowColor = COLOR } },
    { { moment = "chargesLeft", action = "glow", n = 2 }, { ["ez:chargesLeft:glow"] = { n = 2 } } },
    -- "While my totem is up" takes totemUp's glow and sound (Grammar.MERGED); no kind takes every pair.
    { L("cooldown", "glow"), { ["ez:totemUp:glow"] = true } },
    { L("cooldown", "sound", SOUND), { ["ez:totemUp:sound"] = { value = SOUND } } },
    { { moment = "chargesLeft", action = "sound", value = SOUND }, { ["ez:chargesLeft:sound"] = { value = SOUND } } },
}

-- Batch A's conditions (test_batch_a): each action is EZ-CDM's own field.
local BATCH_A = { "hasTarget", "targetEnemy", "targetBoss", "outOfRange", "targetCasting", "onlyGcd", "formBear",
                  "formCat", "formAquatic", "formTravel", "formMoonkin", "formStealth", "formBattle", "formDefensive",
                  "formBerserker", "totemUp", "weaponBuffMissing", "inCombat", "noCombat", "inGroup", "inInstance" }
local GRAYS = { outOfRange = true, targetCasting = true, onlyGcd = true }
for _, k in ipairs(BATCH_A) do
    CASES[#CASES + 1] = { L(k, "glow"), { ["ez:" .. k .. ":glow"] = true } }
    CASES[#CASES + 1] = { L(k, "sound", SOUND), { ["ez:" .. k .. ":sound"] = { value = SOUND } } }
    if GRAYS[k] then CASES[#CASES + 1] = { L(k, "gray"), { ["ez:" .. k .. ":gray"] = true } } end
end

-- Batch B's client conditions (test_batch_b): glow, and gray on the cooldown one; no
-- sound, and a typed number where it takes one.
for _, k in ipairs({ "targetLow", "playerLow", "powerLow", "targetInterruptible" }) do
    CASES[#CASES + 1] = { L(k, "glow"), { ["ez:" .. k .. ":glow"] = true } }
end
CASES[#CASES + 1] = { { moment = "targetLow", action = "glow", n = 35 }, { ["ez:targetLow:glow"] = { n = 35 } } }
CASES[#CASES + 1] = { L("targetInterruptible", "gray"), { ["ez:targetInterruptible:gray"] = true } }

local function withChain(t)
    local out = { chain = {} }
    for k, v in pairs(t) do out[k] = v end
    return out
end

T.test("grammar compile: each sentence gives the expected fields", function()
    local _, ns, G = world()
    local seen = {}
    for _, c in ipairs(CASES) do
        local line = c[1]
        local what = line.moment .. " " .. line.action
        seen[what] = true
        local fields, problems = G.Compile({ lines = { line } })
        T.eq(codes(problems), "", what .. ": no problems")
        T.deq(fields, withChain(c[2]), what)
    end
    -- Flash needs "show it" with it, as the card does (CdmCard.lua:709).
    local fields, problems = G.Compile({ lines = { L("missing", "show"), L("missing", "flash") } })
    T.eq(codes(problems), "")
    T.deq(fields, withChain({ missing = true, inactiveFlash = true }), "missing flash")
    seen["missing flash"] = true
    fields, problems = G.Compile({ lines = { L("missing", "flash") } })
    T.eq(codes(problems), "line 1: needs", "flash alone needs show it")
    T.deq(fields, withChain({}))
    fields, problems = G.Compile({ lines = { L("missing", "flash"), L("missing", "hide") } })
    T.eq(codes(problems), "line 1: needs", "Hide (Buff missing) leaves nothing to flash")
    -- Every look on every EZ-CDM moment: its field, with its value where it takes one.
    local samples = { color = COLOR, text = "Kick!", icon = 136048 }
    for _, l in ipairs(ns.Conditions.Looks()) do
        for _, m in ipairs(G.MOMENTS) do
            local e = G.MAP[m][l.action]
            if e and e.cond then
                local v = e.valued and samples[e.valued]
                local f, p = G.Compile({ lines = { L(m, l.action, v) } })
                T.eq(codes(p), "", m .. " " .. l.action .. ": no problems")
                T.deq(f, withChain({ [e.field] = v and { value = v } or true }), m .. " " .. l.action)
                seen[m .. " " .. l.action] = true
            elseif e and e.alias and e.merge then
                seen[m .. " " .. l.action] = true
            end
        end
    end
    -- The cases cover every pair the map has.
    for _, m in ipairs(G.MOMENTS) do
        for _, a in ipairs(G.ACTIONS) do
            if G.MAP[m][a] then T.truthy(seen[m .. " " .. a], m .. " " .. a .. " has a case") end
        end
    end
    noErrors()
end)

T.test("grammar compile: refused pairs come back as problems, not fields", function()
    local _, _, G = world()
    local refused = {
        L("ready", "gray"), L("ready", "color"),
        L("usable", "hide"), L("usable", "show"), L("up", "fade"), L("ends", "show"), L("ends", "fade"),
        L("missing", "sound"), L("missing", "fade"), L("recast", "hide"), L("recast", "fade"),
        L("always", "hide"), L("always", "glow"), L("someday", "show"), L("ready", "dance"),
    }
    for _, line in ipairs(refused) do
        local fields, problems = G.Compile({ lines = { line } })
        local what = line.moment .. " " .. line.action
        T.eq(codes(problems), "line 1: pair", what)
        T.deq(fields, { chain = {} }, what .. ": no fields")
    end
    local fields, problems = G.Compile({ lines = { L("ready", "glow"), L("ready", "gray"), L("ready", "hide") } })
    T.eq(codes(problems), "line 2: pair", "only the refused line")
    T.deq(fields, withChain({ readyGlow = true, onReady = "hide" }), "the others still compile")
    noErrors()
end)

T.test("grammar compile: bad values, twice-set fields and hidden glows", function()
    local _, _, G = world()
    local function run(lines) return G.Compile({ lines = lines }) end
    local f, p = run({ L("ready", "glow", "gold") })
    T.eq(codes(p), "line 1: value", "a color that isn't { r, g, b }")
    T.deq(f, { chain = {} })
    f, p = run({ L("ready", "sound", "nope:1"), L("usable", "sound") })
    T.eq(codes(p), "line 1: value, line 2: value", "a sound Daylight UI doesn't list, and none")
    f, p = run({ L("ready", "fade", 2) })
    T.eq(codes(p), "line 1: value", "a fade amount past 1")
    f, p = run({ L("ready", "fade"), L("ready", "hide") })
    T.eq(codes(p), "line 1: twice", "the earlier line loses")
    T.deq(f, withChain({ onReady = "hide" }))
    f, p = run({ L("missing", "show"), L("missing", "hide") })
    T.eq(codes(p), "line 1: twice", "Show and Hide under Buff missing are one choice")
    T.deq(f, withChain({ hideMissing = true }))
    f, p = run({ L("ready", "fade", 0.2), L("cooldown", "fade", 0.3) })
    T.eq(codes(p), "line 1: twice", "one fade amount per spell")
    T.eq(f.cdAlpha, 0.3)
    f, p = run({ L("up", "hide"), L("up", "glow", COLOR), L("recast", "glow") })
    T.eq(codes(p), "line 2: hidden, line 3: hidden", "Hide (Buff up) keeps the up and recast glows dark")
    T.deq(f, withChain({ hideActive = true }))
    f, p = run({ L("missing", "glow"), L("missing", "hide") })
    T.eq(codes(p), "line 1: hidden", "Hide (Buff missing) keeps the missing glow dark")
    T.deq(f, withChain({ hideMissing = true }))
    noErrors()
end)

T.test("grammar compile: fields equal to Daylight UI's defaults are left out", function()
    local _, ns, G = world()
    local B = ns.Bridge
    local f, p = G.Compile({ lines = {
        L("ready", "show"), L("cooldown", "show"), L("unusable", "show"), L("short", "show"),
        L("up", "show"), L("ready", "sound", "none"), L("ends", "sound", "none"),
    } })
    T.eq(codes(p), "")
    T.deq(f, { chain = {} }, "every one is Daylight UI's default")
    T.eq(B.Option({}, "onReady"), "show", "Daylight UI's own default")
    T.eq(B.Option({}, "readySound"), "none")
    f = G.Compile({ lines = { L("cooldown", "fade", 0.4) } })
    T.deq(f, withChain({ onCd = "fade" }), "the default fade amount")
    f = G.Compile({ lines = { L("always", "show"), L("cooldown", "hide") } })
    T.deq(f, withChain({ onCd = "hide" }), "always show leaves the named rules alone")
    f = G.Compile({ lines = { L("cooldown", "hide"), L("always", "show") } })
    T.deq(f, withChain({ onCd = "hide" }), "in either order")
    local _, _, flags = G.Compile({ lines = { L("missing", "show") } })
    T.truthy(flags.keepBuffOnly, "missing show asks for Buff only, as the card sets it")
    noErrors()
end)

-- Canonical rule sets: lines in Grammar.MOMENTS then Grammar.ACTIONS order, no
-- default-valued line.
local CANON = {
    { L("ready", "fade", 0.25), L("ready", "glow", COLOR), L("ready", "sound", SOUND), L("cooldown", "hide"),
      L("cooldown", "gray"), L("unusable", "fade"), L("short", "hide"), L("usable", "glow"),
      L("usable", "sound", SOUND), L("up", "glow", COLOR), L("up", "sound", SOUND), L("ends", "sound", SOUND),
      L("missing", "show"), L("missing", "glow"), L("recast", "glow", COLOR) },
    { L("cooldown", "color"), L("up", "hide"), L("missing", "hide") },
    { L("ready", "hide"), L("cooldown", "fade", 0.1), L("short", "fade") },
    {},
}

local function rulesOf(lines, group, forms) return { lines = lines, group = group or {}, forms = forms or {} } end

T.test("grammar: round trip, sentences to fields to sentences", function()
    local _, _, G = world()
    for i, lines in ipairs(CANON) do
        local fields, problems = G.Compile(rulesOf(lines))
        T.eq(codes(problems), "", "set " .. i .. " compiles")
        local back, bp = G.Decompile(fields)
        T.eq(#bp, 0, "set " .. i .. " decompiles")
        T.deq(back, rulesOf(lines), "set " .. i)
    end
    -- The fade amount sits on the first fade line, wherever it was written.
    local fields = G.Compile(rulesOf({ L("cooldown", "fade"), L("short", "fade", 0.1) }))
    T.deq(G.Decompile(fields), rulesOf({ L("cooldown", "fade", 0.1), L("short", "fade") }))
    noErrors()
end)

T.test("grammar: round trip, fields to sentences to fields", function()
    local _, _, G = world()
    local FIELDS = {
        withChain({ onReady = "hide", onCd = "fade", cdAlpha = 0.7, desat = "grey", readyGlow = true,
                    readyGlowColor = COLOR, usableGlow = true, upGlow = true, clipGlow = true,
                    readySound = SOUND, buffEndSound = SOUND, missing = true, missingGlow = true }),
        withChain({ onUnusable = "hide", onShort = "fade", hideMissing = true }),
        withChain({}),
    }
    -- Plus each case's fields on its own.
    for _, c in ipairs(CASES) do FIELDS[#FIELDS + 1] = withChain(c[2]) end
    for i, fields in ipairs(FIELDS) do
        local rules = G.Decompile(fields)
        local back, problems = G.Compile(rules)
        T.eq(codes(problems), "", "fields " .. i .. " compile back")
        T.deq(back, fields, "fields " .. i)
    end
    -- Fields the grammar doesn't own make no line, and Daylight UI's defaults none.
    local rules = G.Decompile({ barMode = "solid", glowStyle = "ring", onReady = "show", readySound = "none",
        look = { cdSize = 14, low = false } })
    T.deq(rules, rulesOf({}), "nothing to say")
    rules = G.Decompile({ glowStyle = "comet" })
    T.eq(rules.style, "comet", "the glow style is the grammar's now")
    T.deq(G.Compile(rules), { chain = {}, glowStyle = "comet" }, "and back")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 3: applicability
-- ---------------------------------------------------------------------

-- Batch A's moments, which test_batch_a checks; the card checks here leave them out.
local BATCH_MOMENT = {}
for _, k in ipairs(BATCH_A) do BATCH_MOMENT[k] = true end

-- Words(kind) as text, batch A's left out, with the batch A lines a merged moment
-- shows (Grammar.MERGED): "ready(show,fade) up(glow)".
local function wordsOf(G, kind)
    local out = {}
    for _, e in ipairs(G.Words(kind)) do
        local acts = {}
        for _, a in ipairs(e.actions) do
            local entry = G.MAP[e.moment][a]
            if not (entry.merge and BATCH_MOMENT[entry.alias.moment]) then acts[#acts + 1] = a end
        end
        if not BATCH_MOMENT[e.moment] then out[#out + 1] = e.moment .. "(" .. table.concat(acts, ",") .. ")" end
    end
    return table.concat(out, " ")
end
local function cardMoments(G, kind)
    local n = 0
    for _, e in ipairs(G.Words(kind)) do
        if not BATCH_MOMENT[e.moment] then n = n + 1 end
    end
    return n
end

-- A layout with one piece of each kind, drawn once. hidden = the game's buff rows
-- set to Hidden in Edit Mode, so no buff can be told up or down.
local function pieceWorld(hidden)
    local DUI, ns, G, AB = world()
    local D = AB.CdmData
    local set = D.Ensure(1)
    local k = {
        icon = CW.ID(CLAP, ESSENTIAL), bar = CW.ID(RAGE, UTILITY), buff = CW.ID(SHOUT, BUFFS),
        own = "s" .. CLAP, weapon = "mainhand",
    }
    D.AddPiece(set, k.icon, "icon", 0, 0)
    set.pieces[k.icon].track = "cooldown"
    D.AddPiece(set, k.bar, "bar", 0, -100)
    D.AddPiece(set, k.buff, "icon", 100, 0)
    D.AddPiece(set, k.own, "icon", 200, 0)
    D.AddPiece(set, k.weapon, "icon", 300, 0)
    if hidden then
        CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    end
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, G, AB, k
end

-- The looks (Looks.lua) an icon takes on a plain line and on a client one.
local LOOKS = "flash,sparkle,screen,flare,pulse,border,halo,text,swap"
local CLIENT_LOOKS = "pulse,border,halo,text,swap"
local COOLDOWN_WORDS = "always(show) ready(show,fade,hide,glow,sound) cooldown(show,fade,hide,gray,color,nosweep,nogcd) "
    .. "almost(numbers) blocked(glow,gray,sound," .. LOOKS .. ") unusable(show,fade,hide,glow,gray,sound," .. LOOKS
    .. ") short(show,fade,hide,glow,sound," .. LOOKS .. ",blue) usable(glow,sound)"

T.test("grammar kind: an icon cooldown takes the cooldown words, gray included", function()
    local _, ns, G, _, k = pieceWorld()
    local kind = G.Kind(k.icon)
    T.eq(kind.shape, "icon")
    T.eq(kind.shows, "cooldown", "set to Cooldown")
    T.truthy(kind.cooldown, "a cooldown")
    T.falsy(kind.custom, "the game's piece")
    T.falsy(kind.showsBuff, "its buff isn't shown")
    T.deq(kind.forms, { "Battle", "Defensive", "Berserker" }, "the warrior's stances")
    -- Buff up's Visibility and the missing glow still apply (CdmCard.lua:678, 702).
    -- Batch B: health and the rage it costs, as a percent (test_batch_b).
    T.eq(wordsOf(G, kind), COOLDOWN_WORDS .. " up(show,hide,nosweep,tint) missing(glow) playerLow(glow," .. CLIENT_LOOKS
        .. ") powerLow(glow," .. CLIENT_LOOKS .. ")")
    T.eq(ns.Bridge.Tracked(k.icon) ~= false, kind.tracked)
    noErrors()
end)

T.test("grammar kind: a bar loses gray and keep color, which are icon rows", function()
    local _, _, G, _, k = pieceWorld()
    local kind = G.Kind(k.bar)
    T.eq(kind.shape, "bar")
    T.falsy(G.Fits(kind, "cooldown", "gray"))
    T.falsy(G.Fits(kind, "cooldown", "color"))
    T.truthy(G.Fits(kind, "cooldown", "fade"))
    T.falsy(G.Fits(kind, "unusable", "gray"), "the washes cover an icon")
    T.falsy(G.Fits(kind, "short", "blue"))
    -- A bar takes the looks that don't cover an icon.
    local barLooks = "sparkle,screen,flare,border,text"
    T.eq(wordsOf(G, kind), "always(show) ready(show,fade,hide,glow,sound) cooldown(show,fade,hide) "
        .. "blocked(glow,sound," .. barLooks .. ") unusable(show,fade,hide,glow,sound," .. barLooks
        .. ") short(show,fade,hide,glow,sound," .. barLooks .. ") usable(glow,sound)"
        .. " up(show,hide) missing(glow) playerLow(glow,border,text)")
    local f, p = G.Compile({ lines = { L("cooldown", "gray"), L("ready", "glow") } }, kind)
    T.eq(codes(p), "line 1: kind", "gray on a bar is refused")
    T.deq(f, withChain({ readyGlow = true }))
    noErrors()
end)

T.test("grammar kind: a tracked buff takes the buff words and no cooldown words", function()
    local _, ns, G, _, k = pieceWorld()
    local kind = G.Kind(k.buff)
    T.eq(ns.Bridge.Tracked(k.buff), true, "the game's item tells its state")
    T.truthy(kind.buffOnly, "Battle Shout shows only its buff")
    T.isnil(kind.forms, "form rows are for cooldowns (CdmCard.lua:817)")
    T.eq(wordsOf(G, kind), "up(show,hide,glow,sound,nosweep,tint) ends(glow,sound) missing(show,hide,glow) recast(glow,sound)")
    local f, p = G.Compile({ lines = { L("ready", "glow"), L("missing", "glow") }, forms = { "Battle" } }, kind)
    T.eq(codes(p), "line 1: kind, form Battle: kind")
    T.deq(f, withChain({ missingGlow = true }))
    noErrors()
end)

T.test("grammar kind: an untracked buff has no up, ends or missing glow words", function()
    local _, ns, G, _, k = pieceWorld(true)
    local kind = G.Kind(k.buff)
    T.eq(ns.Bridge.Tracked(k.buff), false, "nothing can tell its state")
    T.falsy(kind.tracked)
    -- The card keeps Buff missing's Visibility (CdmCard.lua:699) and Glow to recast,
    -- which runs on your own cast's clock (CdmCard.lua:684). An aura icon holder
    -- draws it, so EZ-CDM's up glow needs no told state (Effects).
    T.eq(ns.Bridge.DrawnBy(k.buff), "aura icon")
    T.truthy(kind.ezGlow, "EZ-CDM draws its up glow")
    T.eq(wordsOf(G, kind), "up(glow,nosweep,tint) missing(show,hide) recast(glow,sound)",
        "the sweep rows need no told state (CdmCard.lua:514, 692-697)")
    local f, p = G.Compile({ lines = { L("up", "glow"), L("ends", "sound", SOUND), L("recast", "glow") } }, kind)
    T.eq(codes(p), "line 2: kind")
    T.deq(f, withChain({ upGlow = true, clipGlow = true }))
    -- Without EZ-CDM's glow it takes no up glow either.
    local plainKind = setmetatable({ ezGlow = false }, { __index = kind })
    T.falsy(G.Fits(plainKind, "up", "glow"), "nothing could light it")
    noErrors()
end)

T.test("grammar kind: Daylight UI's own piece", function()
    local _, _, G, _, k = pieceWorld()
    local kind = G.Kind(k.own)
    T.truthy(kind.custom, "Daylight UI's own piece")
    T.truthy(kind.cooldown, "Thunder Clap has a cooldown")
    T.falsy(kind.buff)
    T.eq(wordsOf(G, kind), COOLDOWN_WORDS .. " playerLow(glow," .. CLIENT_LOOKS .. ") powerLow(glow," .. CLIENT_LOOKS .. ")")
    noErrors()
end)

T.test("grammar kind: a weapon enchant has no recast", function()
    local _, _, G, _, k = pieceWorld()
    local kind = G.Kind(k.weapon)
    T.truthy(kind.custom)
    T.falsy(kind.cast, "no spell to time a recast by (CdmCard.lua:422-424)")
    T.eq(wordsOf(G, kind), "up(show,hide,glow,sound,nosweep,tint) ends(glow,sound) missing(show,hide,glow)")
    local _, p = G.Compile({ lines = { L("recast", "glow") } }, kind)
    T.eq(codes(p), "line 1: kind")
    noErrors()
end)

-- Improved Stormstrike (cooldown id 200320 in Tracked Buffs): Stormstrike procs it, so
-- none of its own ids is ever cast.
local STORMBUFF, STORMBUFF_AURA = 1223031, 1238931

-- A shaman with Improved Stormstrike placed as an icon.
local function procWorld()
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = STORMBUFF, known = { STORMBUFF }, showAll = true })
        stub.spells[STORMBUFF] = { name = "Improved Stormstrike" }
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    local AB = stub.actionbars
    local key = CW.ID(STORMBUFF, BUFFS)
    T.eq(key, 200320, "the game's row for Improved Stormstrike")
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, ns.Grammar, AB, key
end

-- Runs fn with the game's answers: passive and player are { [id] = true } (nil
-- leaves that call out of the game).
local function withSpellAnswers(passive, player, fn)
    local keepPassive, keepPlayer = C_Spell.IsSpellPassive, rawget(_G, "IsPlayerSpell")
    C_Spell.IsSpellPassive = passive and function(id) return passive[id] == true end or nil
    _G.IsPlayerSpell = player and function(id) return player[id] == true end or nil
    local ok, err = pcall(fn)
    C_Spell.IsSpellPassive, _G.IsPlayerSpell = keepPassive, keepPlayer
    assert(ok, err)
end

T.test("grammar kind: a buff you never cast has no recast moment", function()
    local _, ns, G, _, storm = procWorld()
    local ids = ns.Bridge.SpellIDs(storm)
    T.truthy(ids[STORMBUFF], "its own spell id, from Daylight UI's holder ids")
    withSpellAnswers({ [STORMBUFF] = true }, {}, function()
        local kind = G.Kind(storm)
        T.truthy(kind.showsBuff and kind.tracked, "a tracked buff")
        T.falsy(kind.cast, "never cast")
        T.eq(wordsOf(G, kind), "up(show,hide,glow,sound,nosweep,tint) ends(glow,sound) missing(show,hide,glow)", "no recast")
        local _, p = G.Compile({ lines = { L("recast", "glow") } }, kind)
        T.eq(codes(p), "line 1: kind", "a recast glow doesn't fit")
    end)
    -- Not passive but not the player's either (the buff's own aura id) counts the same.
    withSpellAnswers({}, {}, function() T.falsy(G.Kind(storm).cast, "not the player's") end)
    -- Any id the player casts brings it back.
    withSpellAnswers({ [STORMBUFF] = true }, { [STORMBUFF_AURA] = true, [STORMBUFF] = true }, function()
        T.falsy(G.Kind(storm).cast, "a passive id stays out even when known")
    end)
    -- With neither call in the game, it follows the card.
    withSpellAnswers(nil, nil, function() T.truthy(G.Kind(storm).cast, "the game won't say: the card's answer") end)
    noErrors()
end)

T.test("grammar kind: Battle Shout, a buff you cast, keeps its recast moment", function()
    local _, _, G, _, k = pieceWorld()
    withSpellAnswers({}, { [SHOUT] = true }, function()
        local kind = G.Kind(k.buff)
        T.truthy(kind.cast, "the player casts it")
        T.truthy(G.Fits(kind, "recast", "glow"))
    end)
    noErrors()
end)

T.test("grammar: Casts reads the game's answers and stays quiet on a secret one", function()
    local _, _, G = world()
    withSpellAnswers({ [1] = true }, { [1] = true, [2] = true }, function()
        T.eq(G.Casts(1), false, "passive")
        T.eq(G.Casts(2), true, "the player's")
        T.eq(G.Casts(3), false, "not the player's")
    end)
    withSpellAnswers({}, nil, function() T.isnil(G.Casts(2), "no IsPlayerSpell: the game won't say") end)
    local keep = rawget(_G, "IsPlayerSpell")
    _G.IsPlayerSpell = function() return stub.Secret(true) end
    local ok, err = pcall(function() T.isnil(G.Casts(2), "a secret answer says nothing") end)
    _G.IsPlayerSpell = keep
    assert(ok, err)
    noErrors()
end)

-- The in-game check in docs/tasks/done/grammar.md, run as written.
local IN_GAME = "/run local G,B=EZCDM_Grammar,EZCDM_Bridge local k=next(B.Layout().pieces) print(k,#G.Words(G.Kind(k)))"

T.test("grammar kind: the in-game /run line prints a piece and its word count", function()
    pieceWorld()
    T.truthy(#IN_GAME <= 255, "fits a /run line: " .. #IN_GAME)
    local out, keep = {}, _G.print
    _G.print = function(...) out[#out + 1] = { ... } end
    local ok, err = pcall(assert(loadstring(IN_GAME:sub(6))))
    _G.print = keep
    assert(ok, err)
    T.eq(#out, 1, "one line")
    T.truthy(out[1][1] ~= nil, "a placed key")
    T.truthy(type(out[1][2]) == "number" and out[1][2] > 0, "with its moments: " .. tostring(out[1][2]))
    noErrors()
end)

T.test("grammar kind: a draft piece not placed yet, and Decompile flags lines that don't fit", function()
    local _, _, G, _, k = pieceWorld()
    local kind = G.Kind(CW.ID(BLOCK, ESSENTIAL), { shape = "bar" })
    T.eq(kind.shape, "bar", "the draft's own shape")
    local rules, p = G.Decompile({ readyGlow = true, upGlow = true }, G.Kind(k.weapon))
    T.eq(#rules.lines, 2, "the line is kept")
    T.eq(codes(p), "line 1: kind", "and named")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 4: group and form words
-- ---------------------------------------------------------------------

T.test("grammar group: group words compile to the group's fields and back", function()
    local _, _, G = world()
    local rules = rulesOf({ L("ready", "glow") }, { combat = true, target = true, group = true, mounted = true,
        where = "instance" })
    local f, p = G.Compile(rules)
    T.eq(codes(p), "")
    T.deq(f.chain, { combat = true, target = true, group = true, mounted = true, where = "instance" })
    T.deq(G.Decompile(f), rules, "round trip")
    for _, where in ipairs({ "instance", "world" }) do
        local r = rulesOf({}, { where = where })
        T.deq(G.Decompile((G.Compile(r))), r, "where " .. where)
    end
    -- Daylight UI's defaults make no field.
    f, p = G.Compile(rulesOf({}, { combat = false, where = "any" }))
    T.eq(codes(p), "")
    T.deq(f.chain, {}, "off and everywhere are the defaults")
    f, p = G.Compile(rulesOf({}, { where = "space", combat = "yes", raid = true }))
    T.eq(codes(p), "group combat: value, group where: value, group raid: pair")
    T.deq(f.chain, {})
    local back = G.Decompile({ chain = { combat = true, spacing = 4, grow = "center", where = "any" } })
    T.deq(back.group, { combat = true }, "only the group words, never spacing or grow")
    noErrors()
end)

T.test("grammar forms: form words compile to hideIn<Key> and back", function()
    local _, _, G = world()
    local rules = rulesOf({}, {}, { "Battle", "Berserker" })
    local f, p = G.Compile(rules)
    T.eq(codes(p), "")
    T.deq(f, { chain = {}, hideInBattle = true, hideInBerserker = true })
    T.deq(G.Decompile(f), rules, "round trip")
    T.deq(G.Decompile({ hideInCat = true, hideInBear = true, hideInStealth = false }).forms, { "Bear", "Cat" },
        "sorted, and false makes no word")
    _, p = G.Compile(rulesOf({}, {}, { "Moon" }))
    T.eq(codes(p), "form Moon: pair", "Daylight UI has no such form")
    -- With a warrior's piece: stances fit, a druid's form doesn't.
    local kind = { cooldown = true, forms = { "Battle", "Defensive", "Berserker" } }
    f, p = G.Compile(rulesOf({}, {}, { "Defensive", "Cat" }), kind)
    T.eq(codes(p), "form Cat: kind")
    T.deq(f, { chain = {}, hideInDefensive = true })
    local back
    back, p = G.Decompile({ hideInDefensive = true, hideInCat = true }, kind)
    T.deq(back.forms, { "Cat", "Defensive" })
    T.eq(codes(p), "form Cat: kind", "kept and named")
    noErrors()
end)

T.test("grammar group: a group word on a spell sharing a group compiles to its group's words only", function()
    local _, _, G, AB, k = pieceWorld()
    local D = AB.CdmData
    local set = D.Current()
    T.truthy(D.Hook(set, k.icon, k.bar, "right", "center"), "Thunder Clap joins Bloodrage's group")
    local f, p, flags = G.Compile(rulesOf({}, { combat = true }, { "Defensive" }), G.Kind(k.icon))
    T.eq(codes(p), "")
    T.deq(f.chain, { combat = true }, "the group's word")
    T.deq(flags, {}, "no flag asks for a move")
    T.eq(set.pieces[k.icon].parent, k.bar, "still hooked: Compile moves nothing")
    T.isnil((set.chains[k.bar] or {}).combat, "and writes nothing")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- More conditions, step 2: buff extras and What it shows
-- ---------------------------------------------------------------------

T.test("grammar buff extras: the sweep while active, its color, and flash on a bar", function()
    local _, _, G, AB, k = pieceWorld()
    local kind = G.Kind(k.buff)
    T.truthy(kind.highlight, "the sweep is on by default (activeGlow)")
    local f, p = G.Compile({ lines = { L("up", "nosweep") } }, kind)
    T.eq(codes(p), "")
    T.deq(f, withChain({ noDurationSwipe = true }), "hide the sweep")
    f, p = G.Compile({ lines = { L("up", "tint", { 1, 0, 0, 0.5 }) } }, kind)
    T.deq(f, withChain({ activeColor = { 1, 0, 0, 0.5 } }), "color the sweep, alpha kept")
    T.truthy(G.IsDefault(L("up", "tint"), kind), "the accent sweep is Daylight UI's own")
    f, p = G.Compile({ lines = { L("up", "nosweep"), L("up", "tint", COLOR) } }, kind)
    T.eq(codes(p), "line 2: hidden", "no sweep leaves nothing to color (CdmCard.lua:695-697)")
    T.deq(f, withChain({ noDurationSwipe = true }))
    f, p = G.Compile({ lines = { L("up", "tint", { 1, 0, 0, 2 }) } }, kind)
    T.eq(codes(p), "line 1: value", "an alpha past 1")
    -- Highlight off on the card: no color word, as the card hides its row.
    AB.CdmData.SetSpellValue(AB.CdmData.Current(), k.buff, "activeGlow", false)
    T.falsy(G.Fits(G.Kind(k.buff), "up", "tint"))
    T.truthy(G.Fits(G.Kind(k.buff), "up", "nosweep"))
    -- A bar takes neither sweep word; flash is for a Buff only bar showing while down.
    local bar = G.Kind(k.buff, { shape = "bar" })
    T.falsy(G.Fits(bar, "up", "nosweep")); T.falsy(G.Fits(bar, "up", "tint"))
    T.falsy(G.Fits(bar, "missing", "flash"), "not until Buff missing shows")
    T.truthy(G.Fits(G.Kind(k.buff, { shape = "bar", missing = true }), "missing", "flash"))
    f, p = G.Compile({ lines = { L("missing", "show"), L("missing", "flash") } }, bar)
    T.eq(codes(p), "", "a show line in the same rules counts")
    T.deq(f, withChain({ missing = true, inactiveFlash = true }))
    T.falsy(G.Fits(G.Kind(k.icon, { shape = "bar", missing = true }), "missing", "flash"), "a cooldown bar")
    -- Decompile gives each back.
    local back = G.Decompile({ noDurationSwipe = true, activeColor = { 1, 0, 0, 0.5 }, missing = true, inactiveFlash = true })
    T.deq(back.lines, { L("up", "nosweep"), L("up", "tint", { 1, 0, 0, 0.5 }), L("missing", "show"), L("missing", "flash") })
    noErrors()
end)

T.test("grammar shows: What it shows in both vocabularies, as the card writes them", function()
    local _, _, G, AB, k = pieceWorld()
    local game, own = G.Kind(k.icon), G.Kind(k.own)
    T.eq(game.trackRow, "game"); T.eq(own.trackRow, "own")
    T.eq(game.showing, "cooldown", "Thunder Clap set to Cooldown")
    T.isnil(G.Kind(k.weapon).trackRow, "a weapon enchant picks nothing (CanTrack)")
    T.deq(G.Extras(game), { "shows", "style" }); T.deq(G.Extras(G.Kind(k.weapon)), { "style" })
    local f, p = G.Compile({ lines = {}, shows = "buff" }, game)
    T.eq(codes(p), "")
    T.eq(f.track, "buff", "a game piece's word")
    f = G.Compile({ lines = {}, shows = "buff" }, own)
    T.eq(f.track, "aura", "Daylight UI's own piece's word")
    f = G.Compile({ lines = {}, shows = "both" }, own)
    T.eq(f.track, "both")
    _, p = G.Compile({ lines = {}, shows = "buff" }, G.Kind(k.weapon))
    T.eq(codes(p), "shows buff: kind")
    _, p = G.Compile({ lines = {}, shows = "totem" }, game)
    T.eq(codes(p), "shows totem: value")
    T.eq(G.Decompile({ track = "aura" }, own).shows, "buff")
    T.eq(G.Decompile({ track = "cooldown" }, game).shows, "cooldown")
    T.isnil(G.Decompile({ track = "totem" }).shows, "a totem's own word")
    T.isnil(G.Decompile({}).shows, "no pick saved")
    -- The piece reads as after the pick: Buff only takes Buff missing's words.
    local after = G.Kind(k.icon, nil, "buff")
    T.truthy(after.buffOnly, "Thunder Clap as Buff only")
    T.truthy(G.Fits(after, "missing", "show"))
    T.falsy(G.Fits(after, "ready", "glow"))
    T.truthy(G.Kind(k.own, nil, "buff").buffOnly, "Daylight UI's own piece too")
    T.eq(G.ShowsWords("both"), "Show its buff, then its cooldown.")
    T.eq(G.ShowsWords("buff"), "Show only its buff.")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 5: plain words and conflicts
-- ---------------------------------------------------------------------

T.test("grammar words: Describe says each line in US English", function()
    local _, ns, G = world()
    local quest = (ns.Bridge.SoundChoices())[SOUND]
    T.eq(type(quest), "string", "Daylight UI names the sound")
    local cases = {
        { L("always", "show"), "Always show it." },
        { L("ready", "show"), "When it's ready, show it." },
        { L("ready", "glow"), "When it's ready, glow." },
        { L("ready", "glow", COLOR), "When it's ready, glow in the color you picked." },
        { L("ready", "fade", 0.25), "When it's ready, make it see-through (25% visible)." },
        { L("ready", "sound", SOUND), "When it's ready, play \"" .. quest .. "\"." },
        { L("cooldown", "fade"), "While it's cooling down, make it see-through." },
        { L("cooldown", "gray"), "While it's cooling down, turn it gray." },
        { L("cooldown", "color"), "While it's cooling down, keep its color." },
        { L("unusable", "hide"), "When it's not usable, hide it." },
        { L("blocked", "gray"), "When I can't cast it, turn it gray." },
        { L("short", "hide"), "When I don't have enough rage, hide it." },
        { L("usable", "glow"), "When it becomes castable, glow." },
        { L("up", "hide"), "While it's active, hide it." },
        { L("ends", "sound", SOUND), "When it wears off, play \"" .. quest .. "\"." },
        { L("missing", "show"), "While it's not active, show it." },
        { L("recast", "glow"), "When it's about to fall off, glow." },
    }
    for _, c in ipairs(cases) do T.eq(G.Describe(c[1]), c[2]) end
    -- Every pair the map has says something of its own.
    local said = {}
    for _, m in ipairs(G.MOMENTS) do
        for _, a in ipairs(G.ACTIONS) do
            if G.MAP[m][a] then
                local text = G.Describe(L(m, a, a == "sound" and SOUND or nil))
                T.truthy(not said[text], text .. " is said once")
                T.truthy(text:find("%.$") and not text:lower():find("colour") and not text:find("grey"), text)
                said[text] = true
            end
        end
    end
    T.eq(G.Describe(nil), "")
    noErrors()
end)

-- The spec's "Player wording" table, as the player reads it.
local PLAYER_MOMENTS = {
    ready = "When it's ready", cooldown = "While it's cooling down", unusable = "When it's not usable",
    blocked = "When I can't cast it",
    short = "When I don't have enough rage", usable = "When it becomes castable", up = "While it's active",
    ends = "When it wears off", missing = "While it's not active", recast = "When it's about to fall off",
}
local PLAYER_ACTIONS = { fade = "make it see-through", gray = "turn it gray", color = "keep its color" }
local PLAYER_GROUP = {
    combat = "only show it in combat", target = "only when I have a target", group = "only in a group",
    mounted = "hide it while mounted",
}
local PLAYER_WHERE = { instance = "only in dungeons and raids", world = "only in the open world" }

T.test("grammar wording: every moment, action, group and form word reads as the spec's table", function()
    local _, _, G = world()
    for m, want in pairs(PLAYER_MOMENTS) do
        local phrase, joint = G.MomentWords(m)
        T.eq(phrase, want, m .. ": one phrase, no separate When")
        T.eq(joint, ", ")
        local action = G.MAP[m].glow and "glow" or G.MAP[m].sound and "sound" or "show"
        T.eq(G.Describe(L(m, action, action == "sound" and SOUND or nil)):sub(1, #want + 2), want .. ", ",
            "Describe opens with it: " .. m)
    end
    for a, want in pairs(PLAYER_ACTIONS) do
        T.eq(G.WORDING.actions[a], want, a)
        T.eq(G.Describe(L("cooldown", a)), "While it's cooling down, " .. want .. ".", "Describe says it: " .. a)
    end
    for w, want in pairs(PLAYER_GROUP) do T.eq(G.GroupWords(w, true), want, w) end
    for v, want in pairs(PLAYER_WHERE) do T.eq(G.GroupWords("where", v), want, v) end
    T.eq(G.FormWords("Battle Stance"), "hide it while I'm in Battle Stance")
    noErrors()
end)

T.test("grammar wording: Always reads as one phrase with no comma", function()
    local _, _, G = world()
    local phrase, joint = G.MomentWords("always")
    T.eq(phrase, "Always")
    T.eq(joint, " ", "no comma after Always")
    T.eq(G.Describe(L("always", "show")), "Always show it.")
    T.eq(G.WORDING.moments.always, "Always", "the chip and the sentence read the same table")
    noErrors()
end)

T.test("grammar wording: placeholders and strip headings", function()
    local _, _, G = world()
    T.eq(G.WORDING.chooseMoment, "choose a moment")
    T.eq(G.WORDING.chooseWhat, "choose what happens")
    T.eq(G.MomentWords(nil), "choose a moment", "a moment not picked yet reads as its blank")
    T.eq(G.Describe({}), "Choose a moment, choose what happens.", "a new line")
    T.eq(G.Describe(L("ready", nil)), "When it's ready, choose what happens.")
    T.deq(G.WORDING.headings, {
        moment = "Choose a moment:", action = "Choose what happens:", color = "Choose a color:",
        sound = "Choose a sound:", fade = "Choose how much shows:", group = "Choose for the whole group:",
        form = "Choose a form:", shows = "Choose what it shows:", style = "Choose a glow style:",
        seconds = "Choose how many seconds:", recipe = "Choose a recipe:",
        clause = "Choose another condition:", number = "Type a number:",
        text = "Type a few words:", icon = "Choose an icon:",
        design = "Choose a flare:", anim = "Choose how it moves:", flareSound = "Choose a sound:",
    })
    -- No phrase starts with a separate When or While: each moment is one phrase.
    for m, phrase in pairs(G.WORDING.moments) do
        T.truthy(not phrase:find("^When When") and phrase:sub(1, 1):upper() == phrase:sub(1, 1), m)
    end
    noErrors()
end)

T.test("grammar: IsDefault finds a finished line that asks for Daylight UI's default", function()
    local _, _, G = world()
    T.truthy(G.IsDefault(L("always", "show")), "Always show it.")
    T.truthy(G.IsDefault(L("unusable", "show")), "When I can't cast it, show it.")
    T.falsy(G.IsDefault(L("ready", "fade")), "When it's ready, make it see-through.")
    T.falsy(G.IsDefault(L("ready", "glow")), "a glow")
    T.falsy(G.IsDefault(L("ready", nil)), "a line with a blank")
    T.falsy(G.IsDefault(L("always", "hide")), "no such sentence")
    noErrors()
end)

T.test("grammar wording: short names the class's power, from the game", function()
    local _, _, G = world()
    T.eq(G.PowerName(), "rage", "the game's name for the player's power, in a sentence's case")
    T.eq(G.MomentWords("short"), "When I don't have enough rage")
    _G.RAGE = nil
    T.eq(G.PowerName(), "power", "no name from the game: the plain word")
    _G.RAGE = "Rage"
    noErrors()
end)

local function winners(notes)
    local out = {}
    for i, n in ipairs(notes) do out[i] = n.winner .. ">" .. n.loser end
    return table.concat(out, " ")
end

T.test("grammar notes: the glow that wins, by Daylight UI's priority", function()
    local _, _, G = world()
    T.eq(winners(G.Notes(rulesOf({ L("ready", "glow") }))), "", "one glow: nothing to say")
    T.eq(winners(G.Notes(rulesOf({ L("ready", "glow"), L("usable", "glow") }))), "usable>ready")
    T.eq(winners(G.Notes(rulesOf({ L("ready", "glow", COLOR), L("recast", "glow"), L("up", "glow") }))),
        "recast>up recast>ready up>ready", "winners first, in priority order")
    T.eq(winners(G.Notes(rulesOf({ L("up", "glow"), L("missing", "glow") }))), "",
        "a buff is never up and missing at once")
    T.eq(winners(G.Notes(rulesOf({ L("recast", "glow"), L("missing", "glow") }))), "",
        "recast never lights on a missing buff (CdmEffects.lua:503-508)")
    local all = G.Notes(rulesOf({ L("ready", "glow"), L("usable", "glow"), L("up", "glow"), L("recast", "glow"),
        L("missing", "glow"), L("ready", "hide") }))
    T.eq(winners(all), "missing>usable missing>ready recast>up recast>usable recast>ready up>usable up>ready usable>ready")
    T.eq(all[1].text, "Only one glow shows at a time. When both apply, the glow while it's not active shows instead of the glow when it becomes castable.")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 6: cross-check against Daylight UI's card
-- ---------------------------------------------------------------------

-- What each card row writes, as grammar words: { moment = { actions } }. Rows are
-- keyed as the card keys them, less "cdm.card.".
local CARD_WORDS = {
    onReady = { ready = { "show", "fade", "hide" } },
    readyGlow = { ready = { "glow" } },
    readySound = { ready = { "sound" } },
    onCd = { cooldown = { "show", "fade", "hide" } },
    desat = { cooldown = { "gray", "color" } },
    onUnusable = { unusable = { "show", "fade", "hide" } },
    onShort = { short = { "show", "fade", "hide" } },
    usableGlow = { usable = { "glow" } },
    usableSound = { usable = { "sound" } },
    buffUp = { up = { "show", "hide" } },
    upGlow = { up = { "glow" } },
    buffSound = { up = { "sound" } },
    activeColor = { up = { "tint" } },
    noDurationSwipe = { up = { "nosweep" } },
    -- EZ-CDM's fall-off sound rides on the same moment as the card's Glow to recast,
    -- wherever the card offers it (Effects.lua).
    clipGlow = { recast = { "glow", "sound" } },
    buffEndSound = { ends = { "sound" } },
    buffDown = { missing = { "show", "hide" } },
    missingGlow = { missing = { "glow" } },
    inactiveFlash = { missing = { "flash" } },
    noSwipe = { cooldown = { "nosweep" } },
    noGcd = { cooldown = { "nogcd" } },
    low = { almost = { "numbers" } },
}
-- Rows that are a whole-spell word of their own (Grammar.Extras).
local CARD_EXTRAS = { track = "shows", ownTrack = "shows", glowStyle = "style" }
-- Rows with no word of their own: a value of a covered word (a glow's color, the
-- fade amount).
local CARD_OTHER = {
    readyGlowColor = true, usableGlowColor = true, upGlowColor = true, clipGlowColor = true,
    missingGlowColor = true, cdAlpha = true, lowAt = true, lowColor = true,
}
-- Rows EZ-CDM leaves to Daylight UI's card, each with its reason.
local LEFT = {
    -- Behavior
    activeGlow = "Highlight off: \"hide the sweep\" (noDurationSwipe) covers it, Daylight UI's own buff holders too (CdmEffects.lua:17-19, 863)",
    totemTrack = "a totem's What it shows has its own values (Totem, Cooldown; CdmCard.lua:388-391)",
    buffTotemTrack = "a totem's What it shows reads Totem and buff (CdmCard.lua:395-405)",
    -- Look: size, the reverse sweep, text, bars and their animation
    size = "size", ["chain.size"] = "size", width = "size", height = "size",
    ["chain.width"] = "size", ["chain.height"] = "size",
    reverse = "the sweep's direction is pure look",
    shieldAmount = "bar and icon text", fillBy = "a shield bar's fill, pure look",
    cdNumbers = "text and fonts", cdSize = "text and fonts", cdColor = "text and fonts",
    countSize = "text and fonts", countColor = "text and fonts", countSpot = "text and fonts",
    keyShown = "text and fonts", keySize = "text and fonts", keySpot = "text and fonts",
    showName = "bar text and fonts", nameAlign = "bar text and fonts", nameSize = "bar text and fonts",
    nameColor = "bar text and fonts", time = "bar text and fonts", timeSize = "bar text and fonts",
    timeColor = "bar text and fonts", ["chain.text"] = "bar text and fonts", ["chain.time"] = "bar text and fonts",
    icon = "a bar's icon, pure look", ["chain.icon"] = "a bar's icon, pure look",
    chargeLines = "a bar's look", barMode = "bar colors", barColor = "bar colors", barGradient = "bar colors",
    backMode = "bar colors", backColor = "bar colors", backGradient = "bar colors",
    ["chain.color"] = "bar colors", ["chain.back"] = "bar colors", ["chain.backColor"] = "bar colors",
    ["chain.backGradient"] = "bar colors",
    fxStyle = "bar animation", fxSpeed = "bar animation", fxStrength = "bar animation",
    fxColors = "bar animation", fxColorA = "bar animation", fxColorB = "bar animation",
    -- Group: position, spacing, grow side, order and hooks
    ["chain.spacing"] = "spacing", ["chain.grow"] = "grow side",
    back = "position: Daylight UI's editor moves pieces", forward = "position: Daylight UI's editor moves pieces",
    alignAcross = "position", alignDown = "position", gap = "spacing", unhook = "position",
    ["chain.tether"] = "position: Attach to, the frame a group follows (CdmCard.lua:483)",
}
-- Custom gradient rows are numbered (barStops.count, barStops.c1...): bar colors.
local LEFT_PATTERNS = { "^barStops%.", "^chain%.barStops%." }
local function leftWhy(key)
    if LEFT[key] then return LEFT[key] end
    for _, pat in ipairs(LEFT_PATTERNS) do
        if key:find(pat) then return "bar colors" end
    end
end
-- The Group tab's rows that are group words, by chain field.
local CARD_GROUP = {}
-- "always show" sets every show rule, so it goes with all four rows.
local ALWAYS_ROWS = { "onReady", "onCd", "onUnusable", "onShort" }

-- The card's visible rows for a piece on all three tabs, picked the editor's way.
-- Every row is a grammar word, a value of one, or left to Daylight UI with a reason.
-- left gets the rows left out, by reason.
local function cardRows(AB, id, left)
    local Ed = AB.CdmEditor
    Ed.Select(id)
    T.eq(Ed.Selected(), id, "picked " .. tostring(id))
    local set = Ed.Set()
    local p = set.pieces[id]
    local on = {}
    for _, tab in ipairs(AB.CdmCard.TABS) do
        for _, row in ipairs(AB.CdmCard.ROWS[tab]) do
            if row.item and row.show(set, id, p) then
                local key = row.item.key:gsub("^cdm%.card%.", "")
                local group = key:match("^chain%.(.+)$")
                -- Form rows (hideIn<Key>) are the piece's form words, Grammar.Kind's forms.
                if group and CARD_GROUP[group] then
                    on[key] = true
                elseif CARD_WORDS[key] or CARD_EXTRAS[key] or CARD_OTHER[key] or key:find("^hideIn") then
                    on[key] = true
                elseif leftWhy(key) then
                    if left then left[key] = leftWhy(key) end
                else
                    error("a " .. tab .. " row with no grammar mapping and no reason: " .. key)
                end
            end
        end
    end
    return on
end

-- The one deliberate departure. The card shows Buff missing's Glow on a Buff only
-- piece only once something shows while the buff is down (CdmCard.lua:285-294,
-- 693), as after "missing show". The grammar offers it at once, since a missing
-- glow keeps the icon itself (Data.PieceBlock). So it counts as offered when the
-- card shows it with the piece saved as Buff missing: Show.
local DEPARTURE = "missing glow (CdmCard.lua:285-294, 704)"
-- The second departure. The card offers Glow to recast on any spell (CdmCard.lua:
-- 413-415), but its clock starts only on a cast of one of the piece's own ids
-- (CdmAuras.lua:1194-1211). The grammar leaves it out where every id is passive or
-- not the player's (Grammar.Casts), as on Improved Stormstrike.
local RECAST = "recast glow on a spell you never cast (CdmCard.lua:422-424)"
-- The third departure. The card offers Color when almost ready on any icon with
-- numbers (CdmCard.lua:522-524), but it only colors a spell cooldown's numbers
-- (Cooldowns.lua:336-350), so the grammar offers it on cooldowns only.
local LOW = "almost-ready color on a buff alone (CdmCard.lua:522-524)"
-- The fourth departure. The card hides Glow (Buff up) on a buff nothing can tell
-- about (CdmCard.lua:294-299). EZ-CDM draws that glow inside the client's aura
-- button for a piece an aura icon holder draws (Effects.lua), which needs no state.
local EZGLOW = "up glow EZ-CDM draws in the client's button (Effects.lua)"
-- The fifth departure. The card offers Glow to recast on any spell, but an aura the
-- client's tables call untimed (AuraLinks.untimed: Ghost Wolf) never falls off.
local UNTIMED = "recast glow on an aura that never falls off (CdmCard.lua:422-424)"
-- The third departure: a glow when it wears off is the card's missing glow (Grammar.Canonical).
local ENDS_GLOW = "glow when it wears off, written as the missing glow"
local function exceptions(G, AB, id, on)
    local out = {}
    -- EZ-CDM's conditions (Conditions.lua) have no card row: every one that fits.
    local kind = G.Kind(id)
    on.ezConditions = {}
    for _, m in ipairs(G.MOMENTS) do
        for _, a in ipairs(G.ACTIONS) do
            local e = G.MAP[m] and G.MAP[m][a]
            if e and e.cond and G.Fits(kind, m, a) then
                on.ezConditions[m] = on.ezConditions[m] or {}
                table.insert(on.ezConditions[m], a)
            end
        end
    end
    if not on.upGlow and G.Kind(id).ezGlow and not G.Kind(id).tracked then
        on.upGlow = true
        out[#out + 1] = EZGLOW
    end
    if on.clipGlow and not G.Kind(id).cast then
        on.clipGlow, on.clipGlowColor = nil, nil
        out[#out + 1] = RECAST
    end
    if on.clipGlow and G.Kind(id).untimed then
        on.clipGlow, on.clipGlowColor = nil, nil
        out[#out + 1] = UNTIMED
    end
    if on.low and not G.Kind(id).cooldown then
        on.low, on.lowAt, on.lowColor = nil, nil, nil
        out[#out + 1] = LOW
    end
    if G.Fits(G.Kind(id), "ends", "glow") then
        on.endsGlow = { ends = { "glow" } }
        out[#out + 1] = ENDS_GLOW
    end
    if not on.buffDown or on.missingGlow then return out end
    local p = AB.CdmEditor.Set().pieces[id]
    local had = p.missing
    p.missing = true
    local with = cardRows(AB, id)
    p.missing = had
    if with.missingGlow then
        on.missingGlow = true
        out[#out + 1] = DEPARTURE
    end
    return out
end

-- The card's words for a piece, as wordsOf prints them, and the departures taken.
local function cardWords(G, AB, id)
    for i, word in ipairs(G.GROUP) do CARD_GROUP[G.CHAIN[i]] = word end
    local on = cardRows(AB, id)
    local why = exceptions(G, AB, id, on)
    local offered = {}
    for key in pairs(on) do
        for m, actions in pairs(CARD_WORDS[key] or (type(on[key]) == "table" and on[key]) or {}) do
            offered[m] = offered[m] or {}
            for _, a in ipairs(actions) do offered[m][a] = true end
        end
    end
    local all = true
    for _, key in ipairs(ALWAYS_ROWS) do all = all and on[key] == true end
    if all then offered.always = { show = true } end
    local out = {}
    for _, m in ipairs(G.MOMENTS) do
        local acts = {}
        for _, a in ipairs(G.ACTIONS) do
            if offered[m] and offered[m][a] then acts[#acts + 1] = a end
        end
        if #acts > 0 and not BATCH_MOMENT[m] then out[#out + 1] = m .. "(" .. table.concat(acts, ",") .. ")" end
    end
    local extras = {}
    for _, e in ipairs(G.EXTRAS) do
        for key, x in pairs(CARD_EXTRAS) do
            if x == e and on[key] then extras[#extras + 1] = e; break end
        end
    end
    if #extras > 0 then out[#out + 1] = "+" .. table.concat(extras, "+") end
    local group = {}
    for i, word in ipairs(G.GROUP) do
        if on["chain." .. G.CHAIN[i]] then group[#group + 1] = word end
    end
    if #group > 0 then out[#out + 1] = "group(" .. table.concat(group, ",") .. ")" end
    return table.concat(out, " "), why
end

-- Grammar.Words and Grammar.Extras as one line, as cardWords prints them.
local function offeredOf(G, kind)
    local out = { wordsOf(G, kind) }
    if out[1] == "" then out = {} end
    local extras = G.Extras(kind)
    if #extras > 0 then out[#out + 1] = "+" .. table.concat(extras, "+") end
    out[#out + 1] = "group(" .. table.concat(G.GROUP, ",") .. ")"
    return table.concat(out, " ")
end

-- Grammar.Words against the card, for one piece as it's saved now.
local function agrees(G, AB, id, what)
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    local card, why = cardWords(G, AB, id)
    local words = offeredOf(G, G.Kind(id))
    T.eq(words, card, what .. ": the grammar offers what the card shows")
    if os.getenv("EZCDM_SHOW_WORDS") then print(what .. " | card: " .. card .. " | grammar: " .. words) end
    return words, why
end

T.test("grammar vs card: every step 3 kind offers exactly the card's words", function()
    local _, _, G, AB, k = pieceWorld()
    local seen = {}
    for _, name in ipairs({ "icon", "bar", "buff", "own", "weapon" }) do
        local _, why = agrees(G, AB, k[name], name)
        seen[name] = table.concat(why, ", ")
    end
    T.eq(seen.buff, LOW .. ", " .. ENDS_GLOW .. ", " .. DEPARTURE, "the departures on Buff only")
    T.eq(seen.weapon, LOW .. ", " .. ENDS_GLOW .. ", " .. DEPARTURE, "a weapon enchant is Buff only too")
    T.eq(seen.icon .. seen.bar .. seen.own, "", "none elsewhere")
    noErrors()
end)

T.test("grammar vs card: all three tabs, a hooked group of icons and bars, every row placed", function()
    local _, _, G, AB, k = pieceWorld()
    local D = AB.CdmData
    local set = D.Current()
    T.truthy(D.Hook(set, k.bar, k.icon, "right", "center"), "Bloodrage joins Thunder Clap's group")
    T.truthy(D.Hook(set, k.buff, k.bar, "down", "start"))
    D.SetLook(set, k.icon, "keyShown", true)
    D.SetLook(set, k.icon, "low", true)
    D.SetSpellValue(set, k.bar, "barMode", "solid")
    local left = {}
    for _, name in ipairs({ "icon", "bar", "buff" }) do
        agrees(G, AB, k[name], name .. ", hooked")
        cardRows(AB, k[name], left)
    end
    -- Each left row names why; the groups the task leaves to Daylight UI all appear.
    local reasons = {}
    for key, why in pairs(left) do
        T.truthy(type(why) == "string" and why ~= "", key .. " has a reason")
        reasons[why] = true
    end
    for _, why in ipairs({ "size", "text and fonts", "bar text and fonts", "spacing", "grow side",
        "position: Daylight UI's editor moves pieces", "position" }) do
        T.truthy(reasons[why], "left to Daylight UI: " .. why)
    end
    T.truthy(left.reverse and left.cdSize and left.width and left["chain.spacing"] and left["chain.grow"]
        and left.unhook and left.gap and left.alignAcross, "the rows as named")
    noErrors()
end)

T.test("grammar vs card: Improved Stormstrike drops the recast glow, the second departure", function()
    local _, _, G, AB, storm = procWorld()
    withSpellAnswers({ [STORMBUFF] = true }, {}, function()
        local _, why = agrees(G, AB, storm, "Improved Stormstrike")
        T.eq(table.concat(why, ", "), RECAST .. ", " .. LOW .. ", " .. ENDS_GLOW .. ", " .. DEPARTURE,
            "the departures, named")
    end)
    withSpellAnswers(nil, nil, function()
        local _, why = agrees(G, AB, storm, "Improved Stormstrike, the game silent")
        T.eq(table.concat(why, ", "), LOW .. ", " .. ENDS_GLOW .. ", " .. DEPARTURE, "no recast departure while the game won't say")
    end)
    noErrors()
end)

T.test("grammar vs card: a Buff only bar offers flash once Buff missing shows", function()
    local _, _, G, AB, k = pieceWorld()
    local D = AB.CdmData
    local set = D.Current()
    D.SetShape(set, k.buff, "bar")
    agrees(G, AB, k.buff, "buff bar")
    T.falsy(G.Fits(G.Kind(k.buff), "missing", "flash"))
    D.SetSpellValue(set, k.buff, "missing", true)
    agrees(G, AB, k.buff, "buff bar, Buff missing shown")
    T.truthy(G.Fits(G.Kind(k.buff), "missing", "flash"), "the card's Flash row")
    noErrors()
end)

T.test("grammar vs card: an untracked buff offers exactly the card's words", function()
    local _, _, G, AB, k = pieceWorld(true)
    local _, why = agrees(G, AB, k.buff, "untracked buff")
    T.eq(table.concat(why, ", "), EZGLOW .. ", " .. LOW, "the fourth departure, named")
    noErrors()
end)

-- Improved Stormstrike drawn by Daylight UI's aura icon holder (the game's buff rows
-- hidden).
local function heldProc()
    local DUI, ns, G, AB, storm = procWorld()
    CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, G, AB, storm
end

T.test("grammar vs card: a proc EZ-CDM draws offers no fall-off moment, as the card's clock never starts", function()
    local _, ns, G, AB, storm = heldProc()
    T.eq(ns.Bridge.DrawnBy(storm), "aura icon")
    withSpellAnswers({ [STORMBUFF] = true }, {}, function()
        local kind = G.Kind(storm)
        T.truthy(kind.ezGlow and kind.proc, "a proc EZ-CDM draws")
        T.falsy(G.Fits(kind, "recast", "glow"), "no fall-off glow")
        T.falsy(G.Fits(kind, "recast", "sound"), "no fall-off sound")
        local _, why = agrees(G, AB, storm, "Improved Stormstrike")
        T.eq(table.concat(why, ", "), EZGLOW .. ", " .. RECAST .. ", " .. LOW, "the departures, named")
    end)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The aura links (EZ-CDM/AuraLinks.lua, tools/make_aura_links.py)
-- ---------------------------------------------------------------------

local function has(list, v)
    for _, x in ipairs(list or {}) do if x == v then return true end end
    return false
end

T.test("aura links: the client's tables give each talent's auras, both ways", function()
    local _, ns = world()
    local AL = ns.AuraLinks
    T.truthy(type(AL) == "table", "loaded before Grammar.lua")
    T.truthy(type(AL.build) == "string" and AL.build:match("^%d+%.%d+%.%d+%.%d+$"), "the client build: " .. tostring(AL.build))
    T.deq(AL.bySource[STORMBUFF], { STORMBUFF_AURA }, "Improved Stormstrike 1223031 -> its buff 1238931")
    T.deq(AL.bySource[11213], { 12536 }, "Arcane Concentration -> Clearcasting")
    T.deq(AL.byAura[12536], { 11213 }, "and back")
    T.deq(AL.onCast[24907], { 24858 }, "Moonkin Aura comes with Moonkin Form's cast")
    T.isnil(AL.onCast[12536], "Clearcasting is a proc, not a cast's aura")
    local pairs1, pairs2 = 0, 0
    for s, auras in pairs(AL.bySource) do
        for _, a in ipairs(auras) do
            pairs1 = pairs1 + 1
            T.truthy(has(AL.byAura[a], s), s .. " -> " .. a .. " is in byAura")
        end
    end
    for a, sources in pairs(AL.byAura) do
        for _, s in ipairs(sources) do
            pairs2 = pairs2 + 1
            T.truthy(has(AL.bySource[s], a), a .. " <- " .. s .. " is in bySource")
        end
    end
    T.eq(pairs1, pairs2, "the same pairs both ways")
    for a, sources in pairs(AL.onCast) do
        for _, s in ipairs(sources) do T.truthy(has(AL.byAura[a], s), a .. " <- " .. s .. " is a link") end
    end
end)

-- Every spell named Windfury Weapon on Forever: the imbue casts and their enchants,
-- and 439431, a talent-style passive of the same name.
local WINDFURY_WEAPON = { 8232, 8233, 8235, 8236, 10484, 10486, 16361, 16362, 16363, 439431, 439440, 439441, 461636 }

T.test("aura links: a weapon imbue's name gives no same-name links", function()
    local _, ns = world()
    local AL = ns.AuraLinks
    for _, id in ipairs(WINDFURY_WEAPON) do
        T.isnil(AL.bySource[id], "Windfury Weapon " .. id .. " links nothing")
        T.isnil(AL.byAura[id], "Windfury Weapon " .. id .. " is nobody's aura")
    end
end)

T.test("grammar ProcSource: the spells that put an aura up, from an id, a list or a set", function()
    local _, _, G = world()
    T.deq(G.ProcSource(12536), { 11213 }, "Clearcasting <- Arcane Concentration")
    T.deq(G.ProcSource({ STORMBUFF_AURA }), { STORMBUFF })
    T.deq(G.ProcSource({ [STORMBUFF_AURA] = true, [12536] = true }), { 11213, STORMBUFF }, "a set, in id order")
    T.isnil(G.ProcSource(2645), "Ghost Wolf: no spell puts it up under another id")
    T.isnil(G.ProcSource({}))
    noErrors()
end)

T.test("grammar kind: a proc the aura links name, from a talent you have", function()
    local _, ns, G, _, storm = heldProc()
    -- Improved Stormstrike known and passive, its buff not yours: the links decide.
    withSpellAnswers({ [STORMBUFF] = true }, { [STORMBUFF] = true }, function()
        local kind = G.Kind(storm)
        T.truthy(kind.proc, "your own proc")
        T.falsy(G.Fits(kind, "recast", "glow"), "no fall-off moment")
    end)
    -- An id of the piece you cast: never a proc, links or not.
    withSpellAnswers({}, { [STORMBUFF] = true, [STORMBUFF_AURA] = true }, function()
        local kind = G.Kind(storm)
        T.truthy(kind.cast)
        T.falsy(kind.proc, "you cast it")
    end)
    -- A spell you know that only puts it up as its cast (onCast, Moonkin Form's way).
    local AL = ns.AuraLinks
    local keep = AL.onCast
    AL.onCast = { [STORMBUFF_AURA] = { STORMBUFF } }
    local ok, err = pcall(withSpellAnswers, { [STORMBUFF] = true }, { [STORMBUFF] = true }, function()
        local kind = G.Kind(storm)
        T.falsy(kind.cast)
        T.falsy(kind.proc, "a cast's own aura is no proc")
    end)
    AL.onCast = keep
    assert(ok, err)
    noErrors()
end)

T.test("grammar kind: with no spell you know behind it, the old rule decides", function()
    local _, ns, G, _, storm = heldProc()
    -- The talent not known: the links name no spell of yours, so a buff you never cast is a proc.
    withSpellAnswers({ [STORMBUFF] = true }, {}, function()
        T.truthy(G.Kind(storm).proc, "never cast")
    end)
    -- No table at all: the same.
    local keep = ns.AuraLinks
    ns.AuraLinks = nil
    local ok, err = pcall(withSpellAnswers, { [STORMBUFF] = true }, { [STORMBUFF] = true }, function()
        T.isnil(G.ProcSource(STORMBUFF_AURA))
        T.truthy(G.Kind(storm).proc)
    end)
    ns.AuraLinks = keep
    assert(ok, err)
    noErrors()
end)

-- Ghost Wolf (both ids), Shadowform, Moonkin Aura and Moonkin Form: auras with no end.
local UNTIMED_AURAS = { 2645, 1238640, 15473, 24907, 24858 }
-- Lightning Shield's ranks (10 min), Flame Shock (12 s), Clearcasting (15 s), Kidney
-- Shot (0 s rising by combo points) and Improved Stormstrike's passive talent.
local TIMED_AURAS = { 324, 325, 905, 945, 8134, 10431, 10432, 8050, 12536, 408, STORMBUFF }

T.test("aura links: untimed lists the auras with no end, and no timed one", function()
    local _, ns = world()
    local U = ns.AuraLinks.untimed
    T.truthy(type(U) == "table", "the table carries untimed")
    for _, id in ipairs(UNTIMED_AURAS) do T.eq(U[id], true, id .. " never falls off") end
    for _, id in ipairs(TIMED_AURAS) do T.isnil(U[id], id .. " is timed or passive") end
end)

-- A class's Tracked Buffs rows for spells, placed as icons; keys by spell id.
local function buffWorld(class, spells)
    stub.neverSecretAuras = {}
    local known = {}
    for id in pairs(spells) do known[#known + 1] = id end
    table.sort(known)
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = class, friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = known[1], known = known, showAll = true })
        for id, name in pairs(spells) do stub.spells[id] = { name = name } end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    local AB, keys = stub.actionbars, {}
    for _, id in ipairs(known) do
        keys[id] = CW.ID(id, BUFFS)
        T.truthy(keys[id], spells[id] .. " has a Tracked Buffs row")
        AB.CdmData.AddPiece(AB.CdmData.Ensure(1), keys[id], "icon", 0, 0)
    end
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return ns, ns.Grammar, keys
end

-- Every id each piece holds, and its spell, cast by the player.
local function castAll(ns, keys)
    local player = {}
    for id, key in pairs(keys) do
        player[id] = true
        for held in pairs(ns.Bridge.SpellIDs(key) or {}) do player[held] = true end
    end
    return player
end

local function recastOf(G, kind)
    return G.Fits(kind, "recast", "glow") or G.Fits(kind, "recast", "sound")
end

T.test("grammar kind: an aura that never falls off offers no recast moment", function()
    local cases = {
        { "SHAMAN", { [2645] = "Ghost Wolf", [324] = "Lightning Shield", [8050] = "Flame Shock" },
          { 2645 }, { 324, 8050 } },
        { "PRIEST", { [15473] = "Shadowform", [1243] = "Power Word: Fortitude" }, { 15473 }, { 1243 } },
        { "DRUID", { [24907] = "Moonkin Aura", [1126] = "Mark of the Wild" }, { 24907 }, { 1126 } },
    }
    for _, c in ipairs(cases) do
        local ns, G, keys = buffWorld(c[1], c[2])
        withSpellAnswers({}, castAll(ns, keys), function()
            for _, id in ipairs(c[3]) do
                local kind = G.Kind(keys[id])
                T.truthy(kind.showsBuff and kind.cast, c[2][id] .. ": a buff you cast")
                T.eq(kind.untimed, true, c[2][id] .. " never falls off")
                T.falsy(recastOf(G, kind), c[2][id] .. ": no recast moment")
                local _, p = G.Compile({ lines = { L("recast", "glow") } }, kind)
                T.eq(codes(p), "line 1: kind", c[2][id] .. ": a recast glow doesn't fit")
                T.falsy(G.Fits(kind, "ends", "sound"), c[2][id] .. ": no wears-off moment")
            end
            for _, id in ipairs(c[4]) do
                local kind = G.Kind(keys[id])
                T.isnil(kind.untimed, c[2][id] .. " is timed")
                T.truthy(recastOf(G, kind), c[2][id] .. " keeps its recast moment")
                T.eq(G.Fits(kind, "ends", "sound"), kind.showsBuff and kind.tracked, c[2][id] .. " keeps its wears-off moment")
            end
        end)
        noErrors()
    end
end)

T.test("grammar kind: untimed needs every id the piece holds in the table", function()
    local ns, G, keys = buffWorld("SHAMAN", { [2645] = "Ghost Wolf" })
    local wolf = keys[2645]
    withSpellAnswers({}, castAll(ns, keys), function()
        T.eq(G.Kind(wolf).untimed, true)
        local U = ns.AuraLinks.untimed
        local keep = U[1238640]
        U[1238640] = nil
        local ok, err = pcall(function()
            T.truthy(ns.Bridge.SpellIDs(wolf)[1238640], "Daylight UI holds Ghost Wolf by 1238640 too")
            T.isnil(G.Kind(wolf).untimed, "one id not in the table: unknown")
            T.truthy(recastOf(G, G.Kind(wolf)), "so the card's recast moment stays")
        end)
        U[1238640] = keep
        assert(ok, err)
        local links = ns.AuraLinks
        ns.AuraLinks = nil
        ok, err = pcall(function() T.isnil(G.Kind(wolf).untimed, "no table: unknown") end)
        ns.AuraLinks = links
        assert(ok, err)
    end)
    noErrors()
end)

-- fn runs with the game saying which spell ids are cast on an enemy.
local function harmfulIds(set, fn)
    local keep = C_Spell.IsSpellHarmful
    C_Spell.IsSpellHarmful = function(id) return set[id] == true end
    local ok, err = pcall(fn)
    C_Spell.IsSpellHarmful = keep
    if not ok then error(err, 0) end
end

T.test("grammar kind: a debuff on the target is no proc, by the links or the old rule", function()
    local _, _, G, _, storm = heldProc()
    local ids = { [STORMBUFF] = true, [STORMBUFF_AURA] = true }
    -- The links name a known talent: your proc, until the game calls the piece harmful.
    withSpellAnswers({ [STORMBUFF] = true }, { [STORMBUFF] = true }, function()
        harmfulIds({}, function()
            T.truthy(G.Kind(storm).proc, "the game says not harmful: still a proc")
        end)
        harmfulIds(ids, function()
            local kind = G.Kind(storm)
            T.eq(kind.harmful, true)
            T.falsy(kind.proc, "harmful: no proc by the links")
            T.falsy(G.Fits(kind, "recast", "glow"), "no fall-off glow offered")
        end)
    end)
    -- No talent known: the old rule (never cast) would say proc; harmful still stops it.
    withSpellAnswers({ [STORMBUFF] = true }, {}, function()
        harmfulIds({}, function() T.truthy(G.Kind(storm).proc, "old rule: a proc") end)
        harmfulIds(ids, function() T.falsy(G.Kind(storm).proc, "old rule: harmful, no proc") end)
    end)
    noErrors()
end)

T.test("grammar vs card: an enchanted weapon learns a length and still offers no fall-off glow", function()
    local _, ns, G, AB, k = pieceWorld()
    stub.weaponEnchants = { { slot = 0, timeLeft = 1800000, enchantID = 19 } }
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.eq(ns.Bridge.AuraLasts(k.weapon), 1800, "Daylight UI read the enchant's length (CdmAuras.lua:1017)")
    T.eq(ns.Bridge.ClientButtons(k.weapon), false, "drawn on Daylight UI's own face")
    local kind = G.Kind(k.weapon)
    T.falsy(kind.ezGlow, "its up glow is Daylight UI's")
    T.falsy(kind.proc)
    T.falsy(G.Fits(kind, "recast", "glow"))
    local _, why = agrees(G, AB, k.weapon, "enchanted weapon")
    T.eq(table.concat(why, ", "), LOW .. ", " .. ENDS_GLOW .. ", " .. DEPARTURE, "the same departures as with no enchant")
    -- Were it drawn in the client's buttons, it still has no spell, so it is no proc.
    local drawn = ns.Effects.Drawn
    ns.Effects.Drawn = function() return true end
    local ok, err = pcall(function()
        local k2 = G.Kind(k.weapon)
        T.truthy(k2.ezGlow)
        T.falsy(k2.proc, "no spell, no proc (CdmCard.lua:420-424)")
    end)
    ns.Effects.Drawn = drawn
    assert(ok, err)
    noErrors()
end)

-- Power Word: Fortitude, a priest's buff on a warrior: the tray's Group buffs.
local FORTITUDE = 1243

T.test("grammar vs card: another class's buff on you is no proc of yours", function()
    local _, ns, G, AB = world()
    local key = "s" .. FORTITUDE
    stub.spells[FORTITUDE] = { name = "Power Word: Fortitude" }
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    withSpellAnswers({}, {}, function()
        local kind = G.Kind(key)
        T.truthy(kind.groupBuff, "a Group buff (CdmCustom.IsGroup)")
        T.truthy(kind.ezGlow, "drawn in the client's buttons")
        T.falsy(kind.cast, "never yours to cast")
        T.falsy(kind.proc)
        T.falsy(G.Fits(kind, "recast", "glow"), "no fall-off glow")
        agrees(G, AB, key, "Power Word: Fortitude")
    end)
    noErrors()
end)

-- A shaman with a totem of each element known: Searing (fire, no buff), Strength
-- of Earth (earth, a buff), Healing Stream (water, no buff), Windfury (air, a buff).
local SHOCK, SEARING, STRENGTH, STREAM, WINDFURY = 8042, 3599, 8075, 5394, 8512

-- hidden = the game's buff rows set to Hidden in Edit Mode, as in pieceWorld.
local function shamanWorld(hidden)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOCK, known = { SHOCK, SEARING, STRENGTH, STREAM, WINDFURY }, showAll = true })
        stub.knownSpells = { [SHOCK] = true, [SEARING] = true, [STRENGTH] = true, [STREAM] = true, [WINDFURY] = true }
        for id, name in pairs({ [SHOCK] = "Earth Shock", [SEARING] = "Searing Totem",
                                [STRENGTH] = "Strength of Earth Totem", [STREAM] = "Healing Stream Totem",
                                [WINDFURY] = "Windfury Totem" }) do
            stub.spells[id] = { name = name }
        end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    local AB = stub.actionbars
    local D = AB.CdmData
    local set = D.Ensure(1)
    local k = { searing = CW.ID(SEARING, ESSENTIAL), strength = CW.ID(STRENGTH, ESSENTIAL),
                ownSearing = "s" .. SEARING, ownStrength = "s" .. STRENGTH }
    T.truthy(k.searing and k.strength, "the game's rows for both totems")
    local x = 0
    for _, key in ipairs({ "fire", "earth", "water", "air", k.searing, k.strength, k.ownSearing, k.ownStrength }) do
        D.AddPiece(set, key, "icon", x, 0)
        x = x + 50
    end
    if hidden then
        CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    end
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, ns.Grammar, AB, k
end

-- An element piece is Totem and buff (CdmOwn.lua:126-127), so the card offers it
-- every cooldown and buff row, as it does a totem with a buff.
T.test("grammar vs card: the shaman's element pieces", function()
    for _, hidden in ipairs({ false, true }) do
        local _, ns, G, AB = shamanWorld(hidden)
        local set = AB.CdmData.Current()
        for _, el in ipairs({ "fire", "earth", "water", "air" }) do
            T.truthy(AB.CdmCustom.Element(el), el .. " is an element piece")
            T.eq(ns.Bridge.Shows(el, set.pieces[el]), "both", el .. ": Totem and buff")
            agrees(G, AB, el, el .. (hidden and ", buff rows hidden" or ""))
            if not hidden then
                -- And batch B's health and mana words.
                T.eq(cardMoments(G, G.Kind(el)), 14, el .. ": all 11 of the card's moments, EZ-CDM's can't cast, health and mana")
            end
        end
        noErrors()
    end
end)

T.test("grammar vs card: a totem with no buff, as Totem and as Cooldown", function()
    local _, ns, G, AB, k = shamanWorld()
    local set = AB.CdmData.Current()
    for _, key in ipairs({ k.searing, k.ownSearing }) do
        T.eq(ns.Bridge.Shows(key, set.pieces[key]), "totem", tostring(key) .. ": Totem")
        agrees(G, AB, key, tostring(key) .. " as Totem")
        set.pieces[key].track = "cooldown"
        T.isnil(ns.Bridge.Shows(key, set.pieces[key]), tostring(key) .. ": Cooldown, the plain path")
        agrees(G, AB, key, tostring(key) .. " as Cooldown")
        set.pieces[key].track = nil
    end
    noErrors()
end)

T.test("grammar vs card: a totem with a buff, each way it can show", function()
    local _, ns, G, AB, k = shamanWorld()
    local set = AB.CdmData.Current()
    local game = k.strength
    T.eq(ns.Bridge.Shows(game, set.pieces[game]), "both", "Totem and buff")
    agrees(G, AB, game, "totem and buff")
    for _, t in ipairs({ "buff", "cooldown" }) do
        set.pieces[game].track = t
        agrees(G, AB, game, "totem with a buff as " .. t)
    end
    set.pieces[game].track = nil
    agrees(G, AB, k.ownStrength, "Daylight UI's own totem with a buff")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The fall-off lead and sound (fall-off-lead.md)
-- ---------------------------------------------------------------------

T.test("grammar fall-off: the lead is one per piece, checked, and read back on each line", function()
    local _, _, G = world()
    local function RL(action, at, value) return { moment = "recast", action = action, at = at, value = value } end
    local f, p = G.Compile({ lines = { RL("glow", 5), RL("sound", 5, SOUND) } })
    T.eq(codes(p), "")
    T.deq(f, withChain({ clipGlow = true, ezLead = 5, ezSound = SOUND }))
    f, p = G.Compile({ lines = { RL("glow", 5), RL("sound", 8, SOUND) } })
    T.eq(codes(p), "line 1: twice", "two leads: the later wins")
    T.eq(f.ezLead, 8)
    for _, bad in ipairs({ 0, 11, 2.5, "5" }) do
        _, p = G.Compile({ lines = { RL("glow", bad) } })
        T.eq(codes(p), "line 1: value", "lead " .. tostring(bad))
    end
    local rules = G.Decompile({ clipGlow = true, ezLead = 4, ezSound = SOUND })
    T.deq(rules.lines, { RL("glow", 4), RL("sound", 4, SOUND) }, "every fall-off line carries the lead")
    T.deq(G.Decompile({ clipGlow = true }).lines, { RL("glow") }, "no lead: Daylight UI's timing")
    T.falsy(G.IsDefault(RL("sound", nil, SOUND)), "a sound is never Daylight UI's default")
    T.deq(G.LEADS, { 2, 3, 4, 5, 8, 10 })
    noErrors()
end)

T.test("grammar fall-off: the sentence and the limit notes", function()
    local _, _, G = world()
    local W = G.WORDING
    T.eq(G.Describe({ moment = "recast", action = "glow", at = 5 }),
        "When it's about to fall off (5 seconds before), glow.")
    T.eq(G.Describe({ moment = "recast", action = "glow" }), "When it's about to fall off, glow.")
    T.eq(G.Describe({ moment = "almost", action = "numbers", at = 3 }),
        "When it's almost ready, color the numbers for the last 3 seconds.", "only the fall-off moment takes a lead")
    local function codesOf(kind)
        local out = {}
        for _, n in ipairs(G.FallOffNotes(kind)) do out[#out + 1] = n.code end
        return table.concat(out, " ")
    end
    T.eq(codesOf({ drawnBy = "game" }), "own")
    T.eq(codesOf({ drawnBy = "game", harmful = true }), "own target")
    T.eq(codesOf({ drawnBy = "aura icon" }), "own early")
    T.eq(codesOf({ drawnBy = "aura bar", harmful = true }), "own early target")
    T.eq(codesOf({ drawnBy = "aura and cooldown icon", harmful = false }), "own early")
    T.eq(codesOf({ harmful = nil }), "own", "the game silent: no target note")
    T.eq(G.FallOffNotes({})[1].text, W.fallOff.own)
    -- A rule of EZ-CDM's (a lead or a sound) trusts the clock, whoever draws it.
    local function codesWith(kind, lines)
        local out = {}
        for _, n in ipairs(G.FallOffNotes(kind, lines)) do out[#out + 1] = n.code end
        return table.concat(out, " ")
    end
    local lead = { { moment = "recast", action = "glow", at = 5 } }
    local sound = { { moment = "recast", action = "sound", value = "x" } }
    local plain = { { moment = "recast", action = "glow" } }
    T.eq(codesWith({ drawnBy = "game", harmful = true }, lead), "own early target", "a lead")
    T.eq(codesWith({ drawnBy = "game" }, sound), "own early", "a sound")
    T.eq(codesWith({ drawnBy = "game" }, plain), "own", "Daylight's timing: Daylight UI's own handling")
    T.eq(codesWith({ drawnBy = "aura icon" }, lead), "own early", "said once")
    T.eq(codesWith({ drawnBy = "game" }, { { moment = "ready", action = "glow", at = 5 } }), "own",
        "only a fall-off line counts")
    T.eq(G.FallOffNotes({}, lead)[2].text, "In a fight it can't tell if it falls off early.")
    -- Daylight UI's buff moments time an EZ-CDM rule: lands, in place of own and early.
    T.eq(codesWith({ drawnBy = "game", harmful = true, buffEvents = true }, lead), "lands target", "a lead")
    T.eq(codesWith({ drawnBy = "aura and cooldown icon", buffEvents = true }, sound), "lands", "a sound")
    T.eq(codesWith({ drawnBy = "game", buffEvents = true }, plain), "own", "Daylight's timing: its own clock")
    T.eq(codesWith({ drawnBy = "aura icon", buffEvents = false }, lead), "own early", "not covered")
    T.eq(G.FallOffNotes({ buffEvents = true }, lead)[1].text,
        "Counts from when it lands, and stops if it falls off early.")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- A glow style per moment (task7-finish.md step 1)
-- ---------------------------------------------------------------------

local function GL(moment, style, value) return { moment = moment, action = "glow", style = style, value = value } end

T.test("grammar style: each glow line's own style compiles to ezStyles and back", function()
    local _, _, G = world()
    local lines = { GL("ready", "comet", COLOR), GL("usable", "shine"), GL("up", "breathe"), GL("missing"),
                    { moment = "recast", action = "glow", style = "twinkle", at = 5 } }
    local fields, problems = G.Compile(rulesOf(lines))
    T.eq(codes(problems), "", "every glow moment takes a style")
    T.deq(fields.ezStyles, { ready = "comet", usable = "shine", up = "breathe", recast = "twinkle" },
        "by moment; a line with none has none")
    T.isnil(fields.glowStyle, "the piece's own style is a separate word")
    local back = G.Decompile(fields)
    T.deq(back.lines, lines, "reads back as the same lines")
    -- Both words at once: the piece's style for the rest.
    local both = G.Compile({ lines = { GL("ready", "comet") }, style = "shine" })
    T.eq(both.glowStyle, "shine")
    T.deq(both.ezStyles, { ready = "comet" })
    noErrors()
end)

T.test("grammar style: a style only on a glow, a known style, and never on EZ-CDM's ring", function()
    local _, _, G = world()
    local _, p1 = G.Compile(rulesOf({ { moment = "ready", action = "sound", value = SOUND, style = "comet" } }))
    T.eq(codes(p1), "line 1: value", "a sound has no style")
    local _, p2 = G.Compile(rulesOf({ GL("ready", "nope") }))
    T.eq(codes(p2), "line 1: value", "an unknown style")
    -- On a piece whose up glow is EZ-CDM's combat ring, that glow takes no style.
    local ringKind = { cooldown = true, buff = true, showsBuff = true, tracked = false, ezGlow = true, cast = true }
    local _, p3 = G.Compile(rulesOf({ GL("up", "comet") }), ringKind)
    T.eq(codes(p3), "line 1: kind")
    T.truthy(G.RingOnly(ringKind, "up"))
    T.falsy(G.RingOnly(ringKind, "ready"))
    T.falsy(G.RingOnly({ proc = true, ezGlow = true }, "recast"), "a proc has no fall-off ring")
    noErrors()
end)

T.test("grammar proc: a proc EZ-CDM draws has no fall-off moment, and a note says why", function()
    local _, _, G = world()
    local proc = { buff = true, showsBuff = true, tracked = false, ezGlow = true, cast = false, proc = true }
    T.falsy(G.Fits(proc, "recast", "glow"), "no fall-off glow")
    T.falsy(G.Fits(proc, "recast", "sound"), "no fall-off sound")
    T.truthy(G.Fits(proc, "up", "glow"), "the up ring stays")
    local _, p = G.Compile(rulesOf({ { moment = "recast", action = "glow", at = 5 } }), proc)
    T.eq(codes(p), "line 1: kind", "a saved line on it is refused")
    T.eq(G.WORDING.fallOff.hidden, "The game hides this buff's timer in a fight, so EZ can't time its end.")
    T.isnil(G.WORDING.fallOff.proc); T.isnil(G.WORDING.fallOff.procFrom)
    T.isnil(G.PROC_LEAD)
    noErrors()
end)

T.test("grammar style: the words", function()
    local _, _, G = world()
    local W = G.WORDING
    T.eq(G.Describe(GL("ready", "comet")), "When it's ready, glow with a Comet.")
    T.eq(G.Describe(GL("ready", "comet", COLOR)), "When it's ready, glow with a Comet in the color you picked.")
    T.eq(G.Describe(GL("ready")), "When it's ready, glow.", "no style of its own: no style words")
    T.eq(G.StyleWords("Comet"), "Other glows use Comet.", "the piece's style line")
    T.eq(W.lineStyle:format("Comet"), "with a Comet")
    T.eq(W.lineStyleNone:format(W.pieceStyle), "with the spell's style")
    T.isnil(W.styleNote, "no one-style note")
    T.eq(G.StyleName("breathe"), "Breathing", "the card's label")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Recipes (docs/specs/recipes.md)
-- ---------------------------------------------------------------------

local PROC_SOUND = "file:568016"   -- Daylight UI's "Proc" (Sound.ALERT_PUNCHY)

local function recipeKeys(G, kind) return table.concat(G.Recipes(kind), " ") end

T.test("grammar recipes: the owner's twelve, their lines and names", function()
    local _, _, G = world()
    local keys = {}
    for _, r in ipairs(G.RECIPES) do keys[#keys + 1] = r.key end
    T.eq(table.concat(keys, " "), "readyAlert outOfWay dimCooling canCast manaCheck almostThere nowUsable procPop missingReminder "
        .. "refreshWarning endedPing fightOnly")
    local said = {}
    for _, k in ipairs(keys) do
        local lines = G.RecipeLines(k)
        local out = {}
        for _, l in ipairs(lines) do out[#out + 1] = G.Describe(l) end
        said[#said + 1] = G.WORDING.recipes[k] .. ": " .. table.concat(out, " ")
    end
    T.eq(table.concat(said, "\n"), table.concat({
        "Ready alert: When it's ready, glow. When it's ready, play \"Proc\".",
        "Hidden: While it's cooling down, hide it.",
        "Dim while cooling: While it's cooling down, make it see-through.",
        "Can't cast: When I can't cast it, turn it gray.",
        "Mana check: When I don't have enough " .. G.PowerName() .. ", tint it blue.",
        "Almost there: When it's almost ready, color the numbers.",
        "Now usable: When it becomes castable, glow.",
        "Proc pop: While it's active, glow.",
        "Missing reminder: While it's not active, glow.",
        "Refresh warning: When it's about to fall off (5 seconds before), glow. "
            .. "When it's about to fall off (5 seconds before), play \"Proc\".",
        "Ended ping: When it wears off, play \"Proc\".",
        "Fight only: ",
    }, "\n"))
    T.deq(G.RecipeLines("readyAlert")[2], { moment = "ready", action = "sound", value = PROC_SOUND })
    T.isnil(G.RecipeLines("readyAlert")[1].value, "the glow in the accent")
    T.eq(G.WORDING.addRecipe, "+ a recipe")
    T.eq(G.WORDING.headings.recipe, "Choose a recipe:")
    T.isnil(G.RecipeLines("nope"))
    noErrors()
end)

T.test("grammar recipes: each one's lines compile with no problems and round-trip", function()
    local _, _, G = world()
    for _, r in ipairs(G.RECIPES) do
        local rules = G.ApplyRecipe(rulesOf({}), r.key)
        local fields, problems = G.Compile(rules)
        T.eq(codes(problems), "", r.key .. " compiles")
        local back, bp = G.Decompile(fields)
        T.eq(#bp, 0, r.key .. " decompiles")
        T.deq(back.lines, rules.lines, r.key .. " lines back")
        T.deq(back.group, rules.group, r.key .. " group back")
    end
    T.deq(G.ApplyRecipe(rulesOf({}), "fightOnly"), rulesOf({}, { combat = true }), "the group word")
    noErrors()
end)

T.test("grammar recipes: shown only where every line fits the piece", function()
    local _, ns, G, _, k = pieceWorld()
    T.eq(recipeKeys(G, G.Kind(k.icon)), "readyAlert outOfWay dimCooling canCast manaCheck almostThere nowUsable missingReminder fightOnly",
        "icon cooldown: its missing glow is the card's (CdmCard.lua:704)")
    T.eq(recipeKeys(G, G.Kind(k.bar)), "readyAlert outOfWay dimCooling nowUsable missingReminder fightOnly",
        "a bar: no numbers, no washes")
    withSpellAnswers({}, { [SHOUT] = true }, function()
        T.eq(recipeKeys(G, G.Kind(k.buff)), "procPop missingReminder refreshWarning endedPing fightOnly", "Battle Shout")
    end)
    T.eq(recipeKeys(G, nil), table.concat((function()
        local out = {}
        for _, r in ipairs(G.RECIPES) do out[#out + 1] = r.key end
        return out
    end)(), " "), "no kind: every recipe")
    T.eq(recipeKeys(G, {}), "fightOnly", "a piece nothing fits still takes the group recipe")
    noErrors()
end)

T.test("grammar recipes: a holder proc gets no Refresh warning", function()
    local _, _, G, _, storm = heldProc()
    withSpellAnswers({ [STORMBUFF] = true }, {}, function()
        local kind = G.Kind(storm)
        T.truthy(kind.proc, "a proc EZ-CDM draws")
        -- No Proc pop either: Improved Stormstrike's buff is its mana buff, and its proc is
        -- Stormstrike's cooldown reset (kind.resetOf), which Proc Alerts flares.
        T.eq(recipeKeys(G, kind), "fightOnly", "no fall-off recipe on it")
        stub.spells[17364] = { name = "Stormstrike" }
        T.eq(kind.resetOf, 17364, "the spell its proc resets")
        T.eq(G.ResetNote(kind), "This talent's proc is Stormstrike's cooldown reset, which Daylight UI's Proc Alerts flares.")
        T.isnil(G.ResetNote({}), "no note on another piece")
        for _, m in ipairs(G.MOMENTS) do T.falsy(m == "reset", "no moment for the reset") end
    end)
    noErrors()
end)

T.test("grammar recipes: an untimed aura gets no Refresh warning or Ended ping", function()
    local ns, G, keys = buffWorld("SHAMAN", { [2645] = "Ghost Wolf", [8050] = "Flame Shock" })
    withSpellAnswers({}, castAll(ns, keys), function()
        local wolf, shock = recipeKeys(G, G.Kind(keys[2645])), recipeKeys(G, G.Kind(keys[8050]))
        T.falsy(wolf:find("refreshWarning"), "Ghost Wolf: " .. wolf)
        T.falsy(wolf:find("endedPing"), "Ghost Wolf: " .. wolf)
        T.truthy(shock:find("refreshWarning"), "Flame Shock keeps it: " .. shock)
    end)
    noErrors()
end)

T.test("grammar recipes: apply adds, replaces by moment and family, and never doubles", function()
    local _, _, G = world()
    local GOLDEN = { 1, 0.8, 0 }
    -- A glow on the same moment is replaced in place; its sound joins after.
    local rules = rulesOf({ L("cooldown", "fade", 0.3), L("ready", "glow", GOLDEN), {} })
    G.ApplyRecipe(rules, "readyAlert")
    T.deq(rules.lines, { L("cooldown", "fade", 0.3), L("ready", "glow"), {}, L("ready", "sound", PROC_SOUND) },
        "the old glow replaced in place, the blank kept, the sound added")
    -- The same family: hide replaces fade on the cooldown.
    G.ApplyRecipe(rules, "outOfWay")
    T.deq(rules.lines[1], L("cooldown", "hide"), "fade gave way to hide")
    T.eq(#rules.lines, 4, "nothing doubled")
    -- Twice is the same as once.
    G.ApplyRecipe(rules, "readyAlert")
    T.eq(#rules.lines, 4, "a second apply adds nothing")
    -- Another family on the same moment stays.
    local r2 = rulesOf({ L("cooldown", "gray") })
    G.ApplyRecipe(r2, "dimCooling")
    T.deq(r2.lines, { L("cooldown", "gray"), L("cooldown", "fade") }, "gray and fade both stay")
    -- Buff missing's show and hide share a slot; a glow is its own.
    local r3 = rulesOf({ L("missing", "show") })
    G.ApplyRecipe(r3, "missingReminder")
    T.deq(r3.lines, { L("missing", "show"), L("missing", "glow") })
    -- The lead is one per piece: every fall-off line takes 5 s.
    local r4 = rulesOf({ { moment = "recast", action = "glow", value = GOLDEN, at = 3 }, L("up", "glow") })
    G.ApplyRecipe(r4, "refreshWarning")
    T.deq(r4.lines, { { moment = "recast", action = "glow", at = 5 }, L("up", "glow"),
        { moment = "recast", action = "sound", value = PROC_SOUND, at = 5 } })
    local _, p = G.Compile(r4)
    T.eq(codes(p), "", "one lead, no twice")
    -- The group recipe keeps the other group words.
    local r5 = rulesOf({ L("ready", "glow") }, { target = true })
    G.ApplyRecipe(r5, "fightOnly")
    T.deq(r5.group, { target = true, combat = true })
    T.deq(r5.lines, { L("ready", "glow") })
    -- Rules with no tables yet get them.
    local r6 = G.ApplyRecipe({}, "nowUsable")
    T.deq(r6.lines, { L("usable", "glow") })
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The washes EZ-CDM draws (Overlay.lua): gray when it can't be cast, blue when
-- short of power
-- ---------------------------------------------------------------------

T.test("grammar wash: not usable gray and short of power blue are EZ-CDM's own fields", function()
    local _, _, G, _, k = pieceWorld()
    local kind = G.Kind(k.icon)
    T.truthy(G.Fits(kind, "unusable", "gray"))
    T.truthy(G.Fits(kind, "short", "blue"))
    T.falsy(G.Fits(kind, "cooldown", "blue"), "blue is the short-of-power wash only")
    T.falsy(G.Fits(G.Kind(k.buff), "unusable", "gray"), "a buff alone has no castable state")
    local f, p = G.Compile({ lines = { L("unusable", "gray"), L("short", "blue"), L("cooldown", "gray") } }, kind)
    T.eq(codes(p), "")
    T.deq(f, withChain({ ["ez:notUsable:gray"] = true, ["ez:noMana:blue"] = true, desat = "grey" }),
        "gray on the cooldown stays Daylight UI's")
    local back = G.Decompile(f, kind)
    T.deq(back.lines, { L("cooldown", "gray"), L("unusable", "gray"), L("short", "blue") }, "canonical order")
    for _, field in ipairs({ "ez:notUsable:gray", "ez:cantCast:gray", "ez:noMana:blue" }) do
        local found = false
        for _, e in ipairs(G.EZ_FIELDS) do found = found or e == field end
        T.truthy(found, field .. " is EZ-CDM's own")
    end
    T.eq(G.Describe(L("unusable", "gray")), "When it's not usable, turn it gray.")
    T.eq(G.Describe(L("blocked", "gray")), "When I can't cast it, turn it gray.")
    T.eq(G.Describe(L("short", "blue")), "When I don't have enough " .. G.PowerName() .. ", tint it blue.")
    T.falsy(G.IsDefault(L("unusable", "gray"), kind), "never Daylight UI's default")
    noErrors()
end)

T.test("grammar wash: a recipe replaces neither the show rule nor the cooldown gray", function()
    local _, _, G = world()
    local rules = rulesOf({ L("unusable", "hide"), L("cooldown", "gray") })
    G.ApplyRecipe(rules, "canCast")
    G.ApplyRecipe(rules, "manaCheck")
    T.deq(rules.lines, { L("unusable", "hide"), L("cooldown", "gray"), L("blocked", "gray"), L("short", "blue") })
    G.ApplyRecipe(rules, "canCast")
    T.eq(#rules.lines, 4, "a second apply adds nothing")
    noErrors()
end)
