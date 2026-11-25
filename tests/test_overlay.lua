local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")

-- EZ-CDM/Conditions.lua and Overlay.lua: the condition registry's castable washes,
-- "When it's not usable, turn it gray" (notUsable, a desaturated copy of the icon)
-- and "When I don't have enough rage, tint it blue" (noMana), drawn by the wash
-- effect on Daylight UI's API.Attach holder of a piece, driven by Daylight UI's
-- plain state (API.CooldownState usable, noPower). A warrior's Thunder Clap, drawn
-- by the game's own cooldown icon.

local SHOUT, REND, CLAP = 6673, 772, 6343
local ESSENTIAL = 0

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end

local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

-- The game's answer to C_Spell.IsSpellUsable for every spell: castable, short of power.
local function usable(can, noPower)
    C_Spell.IsSpellUsable = function() return can, noPower end
end

-- The game says a spell's usability changed; Daylight UI re-reads on the next frame.
local function gameSaysUsable()
    stub.FireEvent("SPELL_UPDATE_USABLE")
    stub.RunTimers()
end

-- Thunder Clap and Rend placed as icons, logged in, motion off. lines are written
-- to Thunder Clap first.
local function world(lines)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[CLAP] = { name = "Thunder Clap" }
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = false
    usable(true, false)
    local AB = stub.actionbars
    local key = CW.ID(CLAP, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), CW.ID(REND, ESSENTIAL), "icon", 0, 0)
    pass(AB)
    if lines then
        local ok, why, report = ns.Draft.Write(key, { lines = lines })
        T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes[1] and report.notes[1].words))
        pass(AB)
    end
    return DUI, ns, AB, key
end

-- The wash's alpha now, or 0 when it has none. The gray is the copy's frame.
local function alphaOf(ns, key, which)
    local t
    if which == "gray" then
        local c = ns.Overlay.Copy(key, "gray")
        t = c and c.frame
    else
        local w = ns.Overlay.Washes(key)
        t = w and w[which]
    end
    if not t or not t:IsShown() then return 0 end
    return t:GetAlpha()
end

-- What the wash shows: "unusable" (notUsable's gray), "short" (noMana's blue), or nil.
local SHOWN = { ["notUsable:gray"] = "unusable", ["noMana:blue"] = "short" }
local function lit(ns, key)
    local t = ns.Conditions.Lit(key)
    return t and SHOWN[t.wash] or nil
end

-- EZ-CDM's frames that run an OnUpdate now (test_lag's count).
local ourDrivers = require("ez_harness").PluginDriverCount

T.test("conditions: the .toc loads the registry, then its effects, before Grammar and Draft", function()
    local _, files = stub.ReadToc(stub.PLUGIN_TOC)
    local at = {}
    for i, f in ipairs(files) do at[f] = i end
    T.truthy(at["Conditions.lua"] and at["Conditions.lua"] > at["Bridge.lua"], "after the Bridge")
    T.truthy(at["Overlay.lua"] and at["Overlay.lua"] > at["Conditions.lua"], "the wash effect after the registry")
    T.truthy(at["Overlay.lua"] < at["Grammar.lua"] and at["Grammar.lua"] < at["Draft.lua"], "before Grammar and Draft")
end)

T.test("overlay gray: not usable grays the icon, castable again takes it off", function()
    local DUI, ns, _, key = world({ L("unusable", "gray") })
    T.isnil(lit(ns, key), "castable: no wash")
    usable(false, false)
    gameSaysUsable()
    T.eq(lit(ns, key), "unusable", "not usable: the gray")
    T.eq(alphaOf(ns, key, "gray"), 1, "the copy at full strength")
    T.eq(alphaOf(ns, key, "blue"), 0, "no blue")
    local gray = ns.Overlay.Copy(key, "gray")
    T.eq(gray.tex:IsDesaturated(), true, "a desaturated copy of the icon")
    T.isnil(ns.Overlay.Washes(key), "no tint")
    local frame = ns.Conditions.FrameOf(key)
    T.truthy(frame, "the piece's frame, from Daylight UI's frame events")
    T.eq(gray.frame:GetParent(), DUI.API.Attach(frame), "drawn on the piece's API.Attach holder")
    usable(true, false)
    gameSaysUsable()
    T.isnil(lit(ns, key), "castable again")
    T.eq(alphaOf(ns, key, "gray"), 0, "gone")
    noErrors()
end)

T.test("overlay blue: the tint sits at Daylight UI's wash strength", function()
    local DUI, ns, _, key = world({ L("short", "blue") })
    usable(false, true)
    gameSaysUsable()
    local alpha = ns.Bridge.WashAlpha()
    T.eq(alpha, 0.45, "Daylight UI's wash strength (Skin.FLASH_ALPHA)")
    T.near(alphaOf(ns, key, "blue"), alpha, 1e-6, "at the wash strength")
    T.eq(ns.Overlay.Washes(key).blue:GetParent(), DUI.API.Attach(ns.Conditions.FrameOf(key)))
    noErrors()
end)

T.test("overlay gray: short of power alone is not not-usable, as Daylight UI's Not usable", function()
    local _, ns, _, key = world({ L("unusable", "gray") })
    usable(false, true)
    gameSaysUsable()
    T.isnil(lit(ns, key), "only short of rage: no gray")
    noErrors()
end)

T.test("overlay blue: short of power tints it blue; gray comes back when only power returns", function()
    local _, ns, _, key = world({ L("unusable", "gray"), L("short", "blue") })
    usable(false, true)
    gameSaysUsable()
    T.eq(lit(ns, key), "short")
    T.rgb(ns.Overlay.Washes(key).blue.__color, { ns.Bridge.ManaColor() }, "Daylight UI's mana blue (Style.PowerColor)")
    T.near(alphaOf(ns, key, "blue"), ns.Bridge.WashAlpha(), 1e-6)
    T.eq(alphaOf(ns, key, "gray"), 0)
    usable(false, false)
    gameSaysUsable()
    T.eq(lit(ns, key), "unusable", "the power came back, the spell still can't be cast")
    T.eq(alphaOf(ns, key, "blue"), 0)
    usable(true, false)
    gameSaysUsable()
    T.isnil(lit(ns, key))
    noErrors()
end)

T.test("overlay: a state the game won't say shows no wash", function()
    local _, ns, _, key = world({ L("unusable", "gray"), L("short", "blue") })
    usable(false, false)
    gameSaysUsable()
    T.eq(lit(ns, key), "unusable")
    usable(nil, nil)
    gameSaysUsable()
    T.isnil(ns.Bridge.UsableState(key), "Daylight UI says nil")
    T.isnil(lit(ns, key), "nil is unknown: no wash")
    T.eq(alphaOf(ns, key, "gray"), 0)
    noErrors()
end)

T.test("overlay: in a fight the wash follows the state, with no per-frame driver", function()
    local _, ns, _, key = world({ L("short", "blue") })
    stub.EnterCombat(); stub.RunTimers()
    usable(false, true)
    gameSaysUsable()
    T.eq(lit(ns, key), "short", "lit in a fight")
    usable(true, false)
    gameSaysUsable()
    T.isnil(lit(ns, key), "off in a fight")
    T.eq(ourDrivers(), 0, "no OnUpdate of EZ-CDM's")
    stub.LeaveCombat()
    noErrors()
end)

T.test("overlay: removing the line takes the wash off at once and stops watching", function()
    local _, ns, AB, key = world({ L("unusable", "gray") })
    usable(false, false)
    gameSaysUsable()
    T.eq(lit(ns, key), "unusable")
    T.eq(ns.Conditions.Watching(), 1, "one piece watched")
    T.eq(table.concat(ns.Conditions.Listening(), " "), "SPELL_UPDATE_COOLDOWN SPELL_UPDATE_USABLE",
        "the condition's game events")
    T.truthy(ns.Draft.Write(key, { lines = {} }))
    pass(AB)
    T.isnil(lit(ns, key), "off with the rule")
    T.eq(alphaOf(ns, key, "gray"), 0)
    T.eq(ns.Conditions.Watching(), 0, "no watch left")
    T.eq(#ns.Conditions.Listening(), 0, "no game events while no rule exists")
    gameSaysUsable()
    T.isnil(lit(ns, key), "stays off")
    noErrors()
end)

T.test("overlay: no rule, no watch and no game events", function()
    local _, ns, _, key = world()
    T.eq(ns.Conditions.Watching(), 0)
    T.eq(#ns.Conditions.Listening(), 0)
    usable(false, false)
    gameSaysUsable()
    T.isnil(lit(ns, key))
    T.isnil(ns.Overlay.Washes(key), "nothing drawn")
    noErrors()
end)

T.test("conditions rule: lives in EZCDMDB by profile and piece, never in Daylight UI's layout, and round-trips", function()
    local _, ns, AB, key = world()
    local Draft = ns.Draft
    local ok, report = Draft.Write(key, { lines = { L("unusable", "gray"), L("short", "blue") } })
    T.truthy(ok)
    local profile = ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.conditions[profile][key], { notUsable = { gray = true }, noMana = { blue = true } },
        "saved by profile and piece")
    local p = AB.CdmData.Get(1).pieces[key]
    T.isnil(p["ez:notUsable:gray"], "never in Daylight UI's layout")
    T.isnil(p["ez:noMana:blue"], "never in Daylight UI's layout")
    local kinds = {}
    for _, c in ipairs(report.changed) do kinds[#kinds + 1] = c.kind .. ":" .. c.field end
    T.eq(table.concat(kinds, " "), "set:desat ez:grayOwned ez:conditions",
        "a gray line owns the gray: Gray out Stay colored, the player's own kept")
    T.eq(p.desat, "color")
    T.deq(Draft.Rules(key).lines, { L("unusable", "gray"), L("short", "blue") }, "reads back")
    T.eq(select(2, Draft.Write(key, Draft.Rules(key))).changes, 0, "a second write writes nothing")
    T.truthy(Draft.Write(key, { lines = { L("short", "blue") } }))
    T.deq(EZCDMDB.conditions[profile][key], { noMana = { blue = true } })
    T.isnil(AB.CdmData.Get(1).pieces[key].desat, "Gray out back at Default with the gray line gone")
    T.truthy(Draft.Write(key, { lines = {} }))
    T.isnil(EZCDMDB.conditions[profile], "nothing left for the profile")
    noErrors()
end)

T.test("conditions rule: refused in combat", function()
    local _, ns, _, key = world()
    stub.EnterCombat()
    local ok, why = ns.Conditions.SetRule(1, key, { notUsable = { gray = true } })
    T.falsy(ok); T.eq(why, "combat")
    T.isnil(ns.Conditions.Rule(key))
    stub.LeaveCombat()
    noErrors()
end)

T.test("overlay recipes: Can't cast and Mana check write their washes through the drawer's path", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local rules = G.ApplyRecipe(ns.Draft.Rules(key), "canCast")
    G.ApplyRecipe(rules, "manaCheck")
    T.truthy(ns.Draft.Write(key, rules))
    T.deq(ns.Conditions.Rule(key), { cantCast = { gray = true }, noMana = { blue = true } })
    usable(false, true)
    gameSaysUsable()
    T.eq(lit(ns, key), "short")
    noErrors()
end)

T.test("overlay: a piece taken off the layout loses its wash; placed again it gets it back", function()
    local _, ns, AB, key = world({ L("unusable", "gray") })
    usable(false, false)
    gameSaysUsable()
    T.eq(lit(ns, key), "unusable")
    AB.CdmData.RemovePiece(AB.CdmData.Ensure(1), key)
    pass(AB)
    T.isnil(ns.Conditions.FrameOf(key), "Daylight UI said FrameRemoved")
    T.isnil(lit(ns, key))
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    pass(AB)
    gameSaysUsable()
    T.eq(lit(ns, key), "unusable", "back with the piece")
    noErrors()
end)

T.test("conditions: Listen hears each effect on and off once, with the condition's detail", function()
    local _, ns, _, key = world({ L("unusable", "gray"), L("short", "blue") })
    local heard = {}
    ns.Conditions.Listen(function(e)
        heard[#heard + 1] = string.format("%s %s:%s %s %s/%s", e.effect, e.condition, e.action,
            e.on and "on" or "off", tostring(e.usable), tostring(e.noPower))
        T.eq(e.key, tostring(key))
    end)
    usable(false, false); gameSaysUsable()
    gameSaysUsable()
    usable(true, false); gameSaysUsable()
    ns.Conditions.Listen(nil)
    usable(false, false); gameSaysUsable()
    T.eq(table.concat(heard, " | "), "wash notUsable:gray on false/false | wash notUsable:gray off true/false",
        "once per change, nothing after Listen(nil)")
    noErrors()
end)

T.test("conditions: the debug handles", function()
    local _, ns = world()
    T.eq(_G.EZCDM_Conditions, ns.Conditions)
    T.eq(_G.EZCDM_Overlay, ns.Overlay)
end)

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

T.test("conditions registry: each has fits, read, events, secrecy, words, an effect and grammar lines", function()
    local _, ns = world()
    local C, G = ns.Conditions, ns.Grammar
    local keys = {}
    for _, c in ipairs(C.List()) do
        keys[#keys + 1] = c.key
        T.eq(type(c.fits), "function", c.key .. " fits")
        T.eq(type(c.read), "function", c.key .. " read")
        T.truthy(#(c.events.game or {}) + #(c.events.daylight or {}) > 0, c.key .. " has events")
        T.truthy(C.SECRECY[c.secrecy], c.key .. " secrecy")
        T.truthy(G.WORDING.moments[c.moment], c.key .. ": its moment has words")
        for a, act in pairs(c.actions) do
            T.truthy(G.WORDING.actions[a], c.key .. " " .. a .. ": its action has words")
            T.truthy(C.Effect(act.effect), c.key .. " " .. a .. ": effect " .. act.effect .. " is registered")
            local e = G.MAP[c.moment][a]
            T.eq(e and e.cond, c.key, c.key .. " " .. a .. " is a grammar line")
            T.eq(e.field, C.Field(c.key, a))
            local ez = false
            for _, f in ipairs(G.EZ_FIELDS) do ez = ez or f == e.field end
            T.truthy(ez, e.field .. " is EZ-CDM's own field")
        end
        for _, r in ipairs(c.recipes or {}) do
            T.truthy(G.WORDING.recipes[r.key], r.key .. " has a name")
            T.deq(G.RecipeLines(r.key), { { moment = c.moment, action = r.action } }, r.key .. " lines")
        end
    end
    T.eq(table.concat(keys, " "), "cantCast notUsable noMana noBuff hasTarget targetEnemy targetBoss outOfRange "
        .. "targetCasting onlyGcd formBear formCat formAquatic formTravel formMoonkin formStealth formBattle "
        .. "formDefensive formBerserker totemUp weaponBuffMissing inCombat noCombat inGroup inInstance",
        "the shipped ones, in order")
    noErrors()
end)

T.test("conditions registry: a bad or taken condition is refused; a new one is one Register call", function()
    local _, ns, _, key = world()
    local C, G = ns.Conditions, ns.Grammar
    local base = { moment = "ready", actions = { gray = { effect = "wash", opts = { id = "gray", look = "desat" } } },
        fits = function() return true end, read = function() return true end,
        events = { daylight = { "changed" } }, secrecy = "plain", layer = "any" }
    local function with(t)
        local c = {}
        for k, v in pairs(base) do c[k] = v end
        for k, v in pairs(t) do c[k] = v end
        return c
    end
    T.eq(select(2, C.Register(with({ key = "cantCast" }))), "taken", "a key once")
    T.eq(select(2, C.Register(with({ key = "x", moment = "unusable" }))), "taken", "a moment and action once")
    T.eq(select(2, C.Register(with({ key = "x", read = false }))), "no fits or read")
    T.eq(select(2, C.Register(with({ key = "x", events = {} }))), "no events")
    T.eq(select(2, C.Register(with({ key = "x", events = { daylight = { "dance" } } }))), "bad handler")
    T.eq(select(2, C.Register(with({ key = "x", secrecy = "maybe" }))), "bad secrecy")
    -- A new one, "When it's ready, turn it gray", always lit.
    T.truthy(C.Register(with({ key = "readyGray" })))
    T.truthy(G.Fits(G.Kind(key), "ready", "gray"), "Grammar took the line")
    T.truthy(ns.Draft.Write(key, { lines = { L("ready", "gray") } }))
    stub.RunTimers()
    T.eq(C.Lit(key).wash, "readyGray:gray", "the driver draws it")
    noErrors()
end)

T.test("conditions: an outOfCombat condition reads unknown in a fight; a unit event registers", function()
    local _, ns, _, key = world()
    local C = ns.Conditions
    T.truthy(C.Register({ key = "calm", moment = "ready", layer = "any", secrecy = "outOfCombat",
        actions = { gray = { effect = "wash", opts = { id = "gray", look = "desat" } } },
        fits = function() return true end, read = function() return true end,
        events = { game = { { "UNIT_POWER_FREQUENT", "player" } } } }))
    T.truthy(ns.Draft.Write(key, { lines = { L("ready", "gray") } }))
    T.eq(table.concat(C.Listening(), " "), "UNIT_POWER_FREQUENT@player", "a unit event")
    T.eq(C.Lit(key).wash, "calm:gray")
    stub.EnterCombat()
    stub.FireEvent("UNIT_POWER_FREQUENT", "player"); stub.RunTimers()
    T.isnil(C.Lit(key), "unknown in a fight: off")
    stub.LeaveCombat()
    noErrors()
end)
