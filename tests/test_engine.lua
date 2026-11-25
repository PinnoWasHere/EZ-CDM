local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")

-- The conditions engine (docs/specs/conditions-waves.md, Engine): the client tier
-- (drive on a layer), "and" clauses, typed numbers, advanced words behind "more…",
-- the shared ticker, and a sound on any plain condition. Test conditions are
-- registered here; the shipped ones are in test_overlay.

local SHOUT, REND, CLAP = 6673, 772, 6343
local ESSENTIAL = 0

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

-- What the test conditions read: set a field, then fire its event.
local state

-- A fresh actions table per condition: Register adds a sound to a plain one's.
local function wash() return { gray = { effect = "wash", opts = { id = "gray", look = "desat" } } } end

-- Five test conditions:
--   boss    plain, "my target is a boss" (PLAYER_TARGET_CHANGED)
--   near    plain, "my target is near" (PLAYER_TARGET_CHANGED)
--   low     client, "my target is below #% health" (UNIT_HEALTH target), a number
--   soon    client, advanced, on the shared ticker
--   calm    outOfCombat: never offered in the drawer
local function register(C)
    local any = function() return true end
    assert(C.Register({ key = "boss", moment = "boss", layer = "any", excludes = {}, actions = wash(), fits = any, secrecy = "plain",
        read = function() return state.boss end, events = { game = { "PLAYER_TARGET_CHANGED" } },
        words = { moment = "When my target is a boss", clause = "my target is a boss" } }))
    assert(C.Register({ key = "near", moment = "near", layer = "any", excludes = {}, actions = wash(), fits = any, secrecy = "plain",
        read = function() return state.near end, events = { game = { "PLAYER_TARGET_CHANGED" } },
        words = { moment = "When my target is near", clause = "my target is near" } }))
    assert(C.Register({ key = "low", moment = "low", layer = "any", excludes = {}, actions = wash(), fits = any, secrecy = "client",
        param = { min = 1, max = 99, default = 20, unit = "%" },
        drive = function(_, layer, opts)
            state.drives = state.drives + 1
            state.lastN = opts.n
            -- The game's answer arrives secret; it goes to the setter whole.
            layer:SetAlphaFromBoolean(stub.Secret(state.low == true), 1, 0)
        end,
        events = { game = { { "UNIT_HEALTH", "target" } } },
        words = { moment = "When my target is below #% health", clause = "my target is below #% health" } }))
    assert(C.Register({ key = "soon", moment = "soon", layer = "any", excludes = {}, actions = wash(), fits = any, secrecy = "client",
        advanced = true, ticker = true,
        drive = function(_, layer)
            state.ticks = state.ticks + 1
            layer:SetAlpha(stub.Secret(1))
        end,
        events = { game = { "SPELL_UPDATE_COOLDOWN" } },
        words = { moment = "When it's nearly ready", clause = "it's nearly ready" } }))
    assert(C.Register({ key = "calm", moment = "calm", layer = "any", excludes = {}, actions = wash(), fits = any, secrecy = "outOfCombat",
        read = function() return true end, events = { game = { "PLAYER_REGEN_ENABLED" } },
        words = { moment = "When I'm calm", clause = "I'm calm" } }))
end

-- Thunder Clap placed as an icon, logged in, motion off, the test conditions in.
local function world()
    state = { boss = false, near = false, low = false, drives = 0, ticks = 0 }
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
    C_Spell.IsSpellUsable = function() return true, false end
    local AB = stub.actionbars
    local key = CW.ID(CLAP, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    pass(AB)
    register(ns.Conditions)
    return DUI, ns, AB, key
end

local function write(ns, AB, key, lines)
    local ok, why, report = ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes[1] and report.notes[1].words))
    pass(AB)
    return report
end

local function fire(event, ...)
    stub.FireEvent(event, ...)
    stub.RunTimers()
end

local function line(moment, action, extra)
    local l = { moment = moment, action = action }
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
end

local function codes(problems)
    local out = {}
    for _, p in ipairs(problems) do out[#out + 1] = (p.line or "-") .. ":" .. p.code end
    return table.concat(out, " ")
end

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

T.test("engine registry: the client tier needs drive; plain needs read; params and tickers are checked", function()
    local _, ns = world()
    local C = ns.Conditions
    T.truthy(C.SECRECY.client, "client is a tier")
    local function try(t)
        local c = { key = "x", moment = "x", actions = wash(), fits = function() return true end,
            events = { game = { "PLAYER_TARGET_CHANGED" } }, secrecy = "plain", read = function() return true end }
        for k, v in pairs(t) do c[k] = v end
        if t.read == false then c.read = nil end
        return select(2, C.Register(c))
    end
    T.eq(try({ secrecy = "client", read = false }), "no drive", "client needs drive")
    T.eq(try({ read = false }), "no fits or read", "plain needs read")
    T.eq(try({ param = { min = 5, max = 1, default = 3 } }), "bad param", "min over max")
    T.eq(try({ param = { min = 1, max = 9, default = 12 } }), "bad param", "default out of range")
    T.eq(try({ ticker = true }), "bad ticker", "a ticker only on a client condition")
    T.eq(C.Get("soon").advanced, true, "advanced is kept")
    noErrors()
end)

T.test("engine registry: a plain condition gets a sound action, a client one doesn't", function()
    local _, ns = world()
    local C, G = ns.Conditions, ns.Grammar
    T.truthy(C.Get("boss").actions.sound, "plain: sound")
    T.isnil(C.Get("low").actions.sound, "client: no sound")
    T.truthy(G.MAP.boss.sound and G.MAP.boss.sound.sound, "a grammar sound line")
    T.truthy(C.Get("cantCast").actions.sound, "the shipped plain ones too")
    T.eq(G.WORDING.moments.boss, "When my target is a boss", "its words went into Grammar.WORDING")
    T.eq(G.WORDING.clauses.boss, "my target is a boss")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Grammar: clauses and numbers
-- ---------------------------------------------------------------------

T.test("engine grammar: an and-clause line compiles, reads back and says both parts", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local l = line("boss", "gray", { clauses = { { cond = "near" } } })
    T.eq(G.Describe(l), "When my target is a boss and my target is near, turn it gray.")
    local fields, problems = G.Compile({ lines = { l } }, kind)
    T.eq(#problems, 0, codes(problems))
    T.deq(fields[ns.Conditions.Field("boss", "gray")], { clauses = { { cond = "near" } } })
    local back = G.Decompile(fields, kind)
    T.deq(back.lines, { l }, "round trip")
    noErrors()
end)

T.test("engine grammar: a typed number reads in the sentence, keeps its range, and the default saves nothing", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local l = line("low", "gray", { n = 35 })
    T.eq(G.Describe(l), "When my target is below 35% health, turn it gray.")
    T.eq(G.Describe(line("low", "gray")), "When my target is below 20% health, turn it gray.", "the default")
    T.eq(G.MomentWords("low"), "When my target is below N% health", "a chip names the number N")
    local fields = G.Compile({ lines = { l } }, kind)
    T.deq(fields[ns.Conditions.Field("low", "gray")], { n = 35 })
    T.deq(G.Decompile(fields, kind).lines, { l })
    fields = G.Compile({ lines = { line("low", "gray", { n = 20 }) } }, kind)
    T.eq(fields[ns.Conditions.Field("low", "gray")], true, "the default is no extra")
    for _, bad in ipairs({ 0, 100, 2.5, "x" }) do
        local _, problems = G.Compile({ lines = { line("low", "gray", { n = bad }) } }, kind)
        T.eq(codes(problems), "1:value", "out of range: " .. tostring(bad))
    end
    local _, problems = G.Compile({ lines = { line("boss", "gray", { n = 3 }) } }, kind)
    T.eq(codes(problems), "1:value", "a number on a condition that takes none")
    noErrors()
end)

T.test("engine grammar: a client condition goes last, once; clauses only on EZ lines", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local function check(l, want, why)
        local _, problems = G.Compile({ lines = { l } }, kind)
        T.eq(codes(problems), want, why)
    end
    check(line("boss", "gray", { clauses = { { cond = "low", n = 30 } } }), "", "client last: fine")
    check(line("low", "gray", { clauses = { { cond = "boss" } } }), "1:order", "client moment with a clause after it")
    check(line("boss", "gray", { clauses = { { cond = "low" }, { cond = "near" } } }), "1:order", "client in the middle")
    check(line("boss", "gray", { clauses = { { cond = "low" }, { cond = "soon" } } }), "1:order", "two client parts")
    check(line("boss", "gray", { clauses = { { cond = "dance" } } }), "1:pair", "no such condition")
    check(line("boss", "gray", { clauses = { { cond = "boss" } } }), "1:twice", "the same condition twice")
    check(line("ready", "glow", { clauses = { { cond = "boss" } } }), "1:pair", "Daylight UI's own moment takes none")
    check(line("boss", "sound", { value = "none", clauses = { { cond = "low" } } }), "1:secret",
        "a sound can't follow a client part")
    check(line("boss", "gray", { clauses = { { cond = "low", n = 120 } } }), "1:value", "a clause's number is checked")
    noErrors()
end)

T.test("engine grammar: the drawer's words hide combat-dead and advanced conditions; clauses follow the rules", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local function moments(opts)
        local out = {}
        for _, w in ipairs(G.Words(kind, opts)) do out[w.moment] = true end
        return out
    end
    local all, plainView, more = moments(), moments({ drawer = true }), moments({ drawer = true, more = true })
    T.truthy(all.calm and all.soon, "every word without the drawer's view")
    T.falsy(plainView.calm, "an out-of-combat condition never shows in the drawer")
    T.falsy(plainView.soon, "advanced hides")
    T.truthy(more.soon, "more shows it")
    T.falsy(more.calm, "still no out-of-combat one")
    T.truthy(plainView.boss and plainView.low and plainView.ready, "the rest stay")
    local function keys(l, opts) return table.concat(G.Clauses(kind, l, opts), " ") end
    T.eq(keys(line("boss", "gray"), { drawer = true }), "cantCast notUsable noMana noBuff onlyGcd formBattle formDefensive formBerserker playerLow powerLow near low", "the others, in registry order")
    T.eq(keys(line("boss", "gray"), { drawer = true, more = true }), "cantCast notUsable noMana noBuff onlyGcd formBattle formDefensive formBerserker playerLow powerLow inCombat noCombat inGroup inInstance near low soon")
    T.eq(keys(line("boss", "gray", { clauses = { { cond = "low" } } }), { drawer = true }), "", "nothing after a client part")
    T.eq(keys(line("low", "gray"), { drawer = true }), "", "nor after a client moment")
    T.eq(keys(line("boss", "sound", { value = "none" }), { drawer = true }),
        "cantCast notUsable noMana noBuff onlyGcd formBattle formDefensive formBerserker near",
        "a sound line takes plain parts only")
    T.eq(keys(line("ready", "glow"), { drawer = true }), "", "Daylight UI's moments take none")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Saved rules
-- ---------------------------------------------------------------------

T.test("engine rules: clauses and numbers save in EZCDMDB and read back; old rules read as they were", function()
    local _, ns, AB, key = world()
    local l = line("boss", "gray", { clauses = { { cond = "low", n = 35 } } })
    write(ns, AB, key, { l })
    local profile = ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.conditions[profile][key], { boss = { gray = { clauses = { { cond = "low", n = 35 } } } } })
    T.deq(ns.Draft.Rules(key).lines, { l })
    T.eq(select(2, ns.Draft.Write(key, ns.Draft.Rules(key))).changes, 0, "a second write writes nothing")
    -- A rule from before the engine, and junk the engine drops.
    EZCDMDB.conditions[profile][key] = { cantCast = { gray = true },
        boss = { gray = { clauses = { { cond = "dance" } }, n = "x" } } }
    T.deq(ns.Conditions.Rule(key), { cantCast = { gray = true }, boss = { gray = true } }, "unknown parts drop")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The driver
-- ---------------------------------------------------------------------

-- The lit line on the wash: its shared slot, or a client line's own slot.
local function lit(ns, key)
    local t = ns.Conditions.Lit(key) or {}
    if t.wash then return t.wash end
    for slot, id in pairs(t) do
        if slot:find("^wash|") then return id end
    end
end

T.test("engine driver: an and-line lights only while both parts read true", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray", { clauses = { { cond = "near" } } }) })
    T.eq(table.concat(ns.Conditions.Listening(), " "), "PLAYER_TARGET_CHANGED", "the clause's events are heard")
    T.isnil(lit(ns, key))
    state.boss = true; fire("PLAYER_TARGET_CHANGED")
    T.isnil(lit(ns, key), "one part is not enough")
    state.near = true; fire("PLAYER_TARGET_CHANGED")
    T.eq(lit(ns, key), "boss:gray", "both")
    state.boss = nil; fire("PLAYER_TARGET_CHANGED")
    T.isnil(lit(ns, key), "unknown is off")
    noErrors()
end)

T.test("engine driver: a client part draws on a layer whose alpha the client sets, with no compare", function()
    local DUI, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray", { clauses = { { cond = "low", n = 35 } } }) })
    local holder = DUI.API.Attach(ns.Conditions.FrameOf(key))
    T.eq(state.drives, 0, "not driven while the plain part is off")
    state.boss = true; state.low = true; fire("PLAYER_TARGET_CHANGED")
    local layer = ns.Conditions.Layer(key, "boss:gray")
    T.truthy(layer, "a layer for the line")
    T.eq(layer:GetParent(), holder, "a child of the piece's holder")
    T.truthy(state.drives > 0, "driven")
    T.eq(state.lastN, 35, "with the clause's number")
    T.truthy(issecretvalue(layer:GetAlpha()), "its alpha is the client's")
    T.eq(stub.Plain(layer:GetAlpha()), 1)
    local wash = ns.Overlay.Washes(key) or {}
    T.isnil(wash.gray, "nothing on the holder itself")
    T.isnil(ns.Overlay.Copy(key, "gray"), "no gray copy on the holder itself: it rides the layer")
    T.eq(lit(ns, key), "boss:gray", "the plain part is lit")
    state.low = false; fire("UNIT_HEALTH", "target")
    T.eq(stub.Plain(layer:GetAlpha()), 0, "the client hides it")
    state.boss = false; fire("PLAYER_TARGET_CHANGED")
    T.isnil(lit(ns, key), "plain part off")
    T.falsy(layer:IsShown(), "the layer goes with it")
    noErrors()
end)

T.test("engine driver: a client moment alone works in a fight with no OnUpdate", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("low", "gray") })
    stub.EnterCombat(); stub.RunTimers()
    state.low = true; fire("UNIT_HEALTH", "target")
    local layer = ns.Conditions.Layer(key, "low:gray")
    T.eq(stub.Plain(layer:GetAlpha()), 1)
    T.eq(state.lastN, 20, "the default number")
    T.eq(require("ez_harness").PluginDriverCount(), 0, "no OnUpdate of EZ-CDM's")
    stub.LeaveCombat()
    noErrors()
end)

T.test("engine driver: one shared ticker, only while a rule uses a ticker condition", function()
    local _, ns, AB, key = world()
    T.falsy(ns.Conditions.Ticking(), "no ticker with no rule")
    local function active()
        local n = 0
        for _, t in ipairs(stub.tickers) do if not t.cancelled then n = n + 1 end end
        return n
    end
    local others = active()
    write(ns, AB, key, { line("soon", "gray"), line("boss", "gray", { clauses = { { cond = "soon" } } }) })
    T.truthy(ns.Conditions.Ticking(), "on")
    T.eq(active() - others, 1, "one ticker for every ticking line")
    local before = state.ticks
    stub.RunTickers()
    T.eq(state.ticks - before, 1, "a tick re-drives the lit line only (the boss line's plain part is off)")
    write(ns, AB, key, {})
    T.falsy(ns.Conditions.Ticking(), "off with the rule")
    T.eq(active(), others, "cancelled")
    noErrors()
end)

T.test("engine driver: a sound line plays once as it turns on", function()
    local DUI, ns, AB, key = world()
    local played = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(k, ...) played[#played + 1] = k; return keep(k, ...) end
    local _, order = ns.Bridge.SoundChoices()
    local snd
    for _, k in ipairs(order) do if k ~= "none" and not tostring(k):find("^head:") then snd = snd or k end end
    write(ns, AB, key, { line("boss", "sound", { value = snd }), line("boss", "gray") })
    T.deq(EZCDMDB.conditions[ns.Bridge.ProfileOf(1)][key].boss.sound, { value = snd }, "the sound key saves")
    state.boss = true; fire("PLAYER_TARGET_CHANGED")
    T.eq(#played, 1, "once on")
    fire("PLAYER_TARGET_CHANGED"); fire("PLAYER_TARGET_CHANGED")
    T.eq(#played, 1, "not again while it stays on")
    T.eq(lit(ns, key), "boss:gray", "the wash beside it")
    state.boss = false; fire("PLAYER_TARGET_CHANGED")
    state.boss = true; fire("PLAYER_TARGET_CHANGED")
    T.eq(#played, 2, "again after it went off")
    T.eq(played[1], snd)
    DUI.Sound.Alert = keep
    noErrors()
end)

-- ---------------------------------------------------------------------
-- For the dev suite
-- ---------------------------------------------------------------------

T.test("engine sample: plain values read plainly, a client one reads <secret>", function()
    local _, ns, _, key = world()
    local C = ns.Conditions
    state.boss = true
    T.eq(C.Sample("boss", key), true)
    T.eq(C.Sample("near", key), false)
    state.low = true
    T.eq(C.Sample("low", key), "<secret>", "the client's answer never comes back plain")
    stub.EnterCombat()
    T.isnil(C.Sample("calm", key), "out of combat only: unknown in a fight")
    stub.LeaveCombat()
    noErrors()
end)

T.test("engine lines: Conditions.Lines lists each line with its parts, for repro and scenarios", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray", { clauses = { { cond = "near" }, { cond = "low", n = 40 } } }) })
    local out = {}
    for _, l in ipairs(ns.Conditions.Lines(key)) do
        local parts = {}
        for _, p in ipairs(l.parts) do parts[#parts + 1] = p.cond .. (p.n and ("=" .. p.n) or "") end
        out[#out + 1] = l.id .. " " .. table.concat(parts, "+")
    end
    T.eq(table.concat(out, "|"), "boss:gray boss+near+low=40")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The drawer
-- ---------------------------------------------------------------------

local function editor(ns, AB, key)
    T.truthy(AB.CdmEditor.Open())
    stub.RunTimers()
    AB.CdmEditor.Select(key)
    stub.RunTimers()
    return ns.Drawer
end

local function sentences(Drawer)
    local out = {}
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b.line then out[#out + 1] = b end
    end
    return out
end

local function wordOf(Drawer, i, kind, nth)
    local b = sentences(Drawer)[i]
    local seen = 0
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == kind then
            seen = seen + 1
            if seen == (nth or 1) then return t end
        end
    end
end

local function strip(Drawer)
    local out = { keys = {}, chip = {} }
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() then
            if b.box then out.box = b.box; out.range = b.range end
            if b.tokens and b.choices then
                for _, t in ipairs(b.tokens) do
                    out.keys[#out.keys + 1] = tostring(t.piece.key)
                    out.chip[t.piece.key] = t
                end
            elseif b.tokens and not b.hint then
                out.heading = out.heading or b.said
            end
        end
    end
    return out
end

T.test("engine drawer: the moment strip hides combat-dead words and keeps advanced ones behind more…", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "moment"):Click()
    local s = strip(Drawer)
    local keys = " " .. table.concat(s.keys, " ") .. " "
    T.truthy(keys:find(" boss "), "boss offered")
    T.falsy(keys:find(" calm "), "an out-of-combat condition is never offered")
    T.falsy(keys:find(" soon "), "advanced hidden")
    T.truthy(s.chip[Drawer.MORE], "a more… chip")
    s.chip[Drawer.MORE]:Click()
    T.eq(ns.Settings.Get("more"), true, "it flips EZ-CDM's setting")
    keys = " " .. table.concat(strip(Drawer).keys, " ") .. " "
    T.truthy(keys:find(" soon "), "advanced shown")
    T.truthy(Drawer.Slot(), "the strip stayed open")
    noErrors()
end)

T.test("engine drawer: the and … chip adds a clause; a clause word changes or removes it", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray") })
    local Drawer = editor(ns, AB, key)
    local add = wordOf(Drawer, 1, "and")
    T.truthy(add, "an and … chip on the line")
    T.eq(add.piece.kind, "chip", "a blank, Daylight UI's chip")
    add:Click()
    T.eq(table.concat(strip(Drawer).keys, " "), "cantCast notUsable noMana noBuff onlyGcd formBattle formDefensive formBerserker playerLow powerLow near low " .. Drawer.MORE,
        "the parts the line can take, and more… for the advanced one")
    strip(Drawer).chip.near:Click()
    T.deq(ns.Conditions.Rule(key), { boss = { gray = { clauses = { { cond = "near" } } } } }, "written at once")
    T.eq(sentences(Drawer)[1].said, "When my target is a boss and my target is near, turn it gray.")
    wordOf(Drawer, 1, "clause"):Click()
    local s = strip(Drawer)
    T.truthy(s.chip.low and s.chip[Drawer.DROP], "other parts and remove")
    s.chip.low:Click()
    T.deq(ns.Conditions.Rule(key), { boss = { gray = { clauses = { { cond = "low" } } } } })
    T.isnil(wordOf(Drawer, 1, "and"), "no more parts after a client one")
    T.truthy(Drawer.Slot(), "the strip stays open on the clause")
    strip(Drawer).chip[Drawer.DROP]:Click()
    T.deq(ns.Conditions.Rule(key), { boss = { gray = true } }, "removed")
    noErrors()
end)

T.test("engine drawer: a number word opens Daylight UI's number box; out of range writes nothing", function()
    local DUI, ns, AB, key = world()
    write(ns, AB, key, { line("low", "gray") })
    local Drawer = editor(ns, AB, key)
    T.eq(sentences(Drawer)[1].said, "When my target is below 20% health, turn it gray.")
    local made, numeric = 0, false
    local keep = DUI.API.Input
    DUI.API.Input = function(parent, opts, ...)
        made = made + 1
        numeric = numeric or (type(opts) == "table" and opts.numeric == true)
        return keep(parent, opts, ...)
    end
    wordOf(Drawer, 1, "number"):Click()
    DUI.API.Input = keep
    local s = strip(Drawer)
    T.truthy(s.box, "a box in the strip")
    T.truthy(made >= 1, "made by API.Input")
    T.truthy(s.box.hint, "Daylight UI's own box (its hint line)")
    T.truthy(numeric, "numbers only")
    T.eq(stub.Text(s.range), ns.Grammar.WORDING.range:format(1, 99), "its range under it")
    s.box:SetFocus(); s.box:SetText("150"); s.box:ClearFocus()
    T.eq(ns.Conditions.Rule(key).low.gray, true, "out of range: nothing written")
    local bad = DUI.API.Colors().BAD
    local r, g, b = strip(Drawer).range:GetTextColor()
    T.deq({ r, g, b }, { bad[1], bad[2], bad[3] }, "the range turns BAD")
    s = strip(Drawer)
    s.box:SetFocus(); s.box:SetText("35"); s.box:ClearFocus()
    T.deq(ns.Conditions.Rule(key), { low = { gray = { n = 35 } } }, "written")
    T.eq(sentences(Drawer)[1].said, "When my target is below 35% health, turn it gray.")
    noErrors()
end)

T.test("engine drawer: picking a condition as the moment takes its number's default", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray", { clauses = { { cond = "near" } } }) })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "moment"):Click()
    strip(Drawer).chip.low:Click()
    T.deq(ns.Conditions.Rule(key), { low = { gray = true } }, "a client moment keeps no clause")
    T.eq(sentences(Drawer)[1].said, "When my target is below 20% health, turn it gray.")
    noErrors()
end)

T.test("engine settings: the more switch sits on EZ-CDM's page, off by default", function()
    local _, ns = world()
    T.eq(ns.Settings.Get("more"), false)
    local found
    for _, g in ipairs(ns.Settings.GROUPS) do
        for _, it in ipairs(g.items) do
            if it.label == ns.Grammar.WORDING.settings.more then found = it end
        end
    end
    T.truthy(found, "a row")
    found.set(true)
    T.eq(EZCDMDB.settings.more, true)
    noErrors()
end)
