local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Wave 1 engine fixes from the owner's in-game check (docs/tasks/w1-engine-fixes.md):
--   1 "When I can't cast it" is any reason; "When it's not usable" the other reasons
--   2 "and" parts that can never both be true are refused, with a reason
--   3 a number word shows with its condition; its box keeps focus until Enter,
--     Escape or a press away
--   4 "more…" shows in the moment and clause strips while advanced conditions exist
--   5 a spell with no cooldown and no buff is a spell button
--   6 an effect draws on the icon its condition is about (layer)
--   coverage: every registered condition has words, layer, excludes and drivers

local SHOUT, REND, CLAP = 6673, 772, 6343
local ESSENTIAL = 0

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

local function usable(can, noPower)
    C_Spell.IsSpellUsable = function() return can, noPower end
    stub.FireEvent("SPELL_UPDATE_USABLE")
    stub.RunTimers()
end

local state

local function wash() return { gray = { effect = "wash", opts = { id = "gray", look = "desat" } } } end

-- Test conditions:
--   boss   plain, any icon
--   low    client, a number
--   soon   plain, advanced
--   upish  plain, about the buff icon (layer buff)
local function register(C)
    local any = function() return true end
    assert(C.Register({ key = "boss", moment = "boss", actions = wash(), fits = any, secrecy = "plain",
        layer = "any", excludes = {},
        read = function() return state.boss end, events = { game = { "PLAYER_TARGET_CHANGED" } },
        words = { moment = "When my target is a boss", clause = "my target is a boss" } }))
    assert(C.Register({ key = "low", moment = "low", actions = wash(), fits = any, secrecy = "client",
        layer = "any", excludes = {}, param = { min = 1, max = 99, default = 20, unit = "%" },
        drive = function(_, layer) layer:SetAlpha(state.low and 1 or 0) end,
        events = { game = { { "UNIT_HEALTH", "target" } } },
        words = { moment = "When my target is below #% health", clause = "my target is below #% health" } }))
    assert(C.Register({ key = "soon", moment = "soon", actions = wash(), fits = any, secrecy = "plain",
        layer = "any", excludes = {}, advanced = true,
        read = function() return state.soon end, events = { game = { "PLAYER_TARGET_CHANGED" } },
        words = { moment = "When it's nearly ready", clause = "it's nearly ready" } }))
    assert(C.Register({ key = "upish", moment = "upish", actions = wash(), fits = any, secrecy = "plain",
        layer = "buff", excludes = {},
        read = function() return state.upish end, events = { game = { "PLAYER_TARGET_CHANGED" } },
        words = { moment = "When its buff glows", clause = "its buff glows" } }))
end

-- Thunder Clap and Rend placed as icons, logged in, motion off.
local function world(opts)
    opts = opts or {}
    state = { boss = false, low = false, soon = false, upish = false }
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[CLAP] = { name = "Thunder Clap" }
        stub.spells[REND] = { name = "Rend" }
        if opts.db then EZCDMDB = opts.db end
    end })
    stub.RunTimers()
    DUI.DB.General().motion = false
    C_Spell.IsSpellUsable = function() return true, false end
    local AB = stub.actionbars
    local key = CW.ID(CLAP, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), CW.ID(REND, ESSENTIAL), "icon", 0, 0)
    pass(AB)
    if not opts.bare then register(ns.Conditions) end
    return DUI, ns, AB, key
end

local function write(ns, AB, key, lines)
    local ok, why, report = ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes[1] and report.notes[1].words))
    pass(AB)
    return report
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

local function firstSound(ns)
    local _, order = ns.Bridge.SoundChoices()
    for _, k in ipairs(order) do
        if k ~= "none" and not tostring(k):find("^head:") then return k end
    end
end

-- The drawer -----------------------------------------------------------

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

local function blocksWith(Drawer, field)
    local out = {}
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b[field] ~= nil then out[#out + 1] = b end
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
    local out = { keys = {}, chip = {}, said = {} }
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
                out.said[#out.said + 1] = b.said
            end
        end
    end
    return out
end

local function pressOn(Drawer, control, stackName)
    stub.MouseEnter(Drawer.Clip())
    local scroll = stackName and Drawer.Parts()[stackName].scroll
    if scroll then stub.MouseEnter(scroll) end
    stub.MouseEnter(control)
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    stub.MouseLeave(control)
    if scroll then stub.MouseLeave(scroll) end
    stub.MouseLeave(Drawer.Clip())
end

local function pressAway()
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    stub.RunTimers()
end

local function script(box, name)
    local fn = box.__scripts and box.__scripts[name]
    if fn then fn(box) end
    stub.RunTimers()
end

-- ---------------------------------------------------------------------
-- 1. Can't cast is any reason; not usable is the rest
-- ---------------------------------------------------------------------

T.test("fix 1: the words: can't cast, not usable, not enough power, cooling down", function()
    local _, ns = world()
    local G = ns.Grammar
    T.eq(G.MomentWords("blocked"), "When I can't cast it")
    T.eq(G.MomentWords("unusable"), "When it's not usable", "Daylight UI's Not usable row, in its own words")
    T.eq(G.MomentWords("cooldown"), "While it's cooling down")
    T.truthy(G.MomentWords("short"):find("^When I don't have enough "), "power stays")
    T.eq(G.ClauseWords("cantCast"), "I can't cast it")
    T.eq(G.ClauseWords("notUsable"), "it's not usable")
    T.eq(G.MAP.blocked.gray.cond, "cantCast", "can't cast is the new moment")
    T.eq(G.MAP.unusable.gray.cond, "notUsable", "not usable keeps Daylight UI's moment")
    T.eq(G.Describe(line("unusable", "hide")), "When it's not usable, hide it.")
    noErrors()
end)

T.test("fix 1: can't cast reads true for a cooldown, short power or not usable; false when castable", function()
    local _, ns, _, key = world()
    local C = ns.Conditions
    usable(true, false)
    T.eq(C.Sample("cantCast", key), false, "castable and ready")
    usable(false, true)
    T.eq(C.Sample("cantCast", key), true, "short of power")
    T.eq(C.Sample("notUsable", key), false, "not usable never counts power")
    usable(false, false)
    T.eq(C.Sample("cantCast", key), true, "not usable")
    T.eq(C.Sample("notUsable", key), true)
    usable(true, false)
    CW.Cooldown(CLAP, 8)
    stub.RunTimers()
    T.eq(C.Sample("cantCast", key), true, "on cooldown")
    T.eq(C.Sample("notUsable", key), false)
    noErrors()
end)

T.test("fix 1: 'When I can't cast it and I don't have enough power, play a sound' fires", function()
    local DUI, ns, AB, key = world()
    local snd = firstSound(ns)
    local played = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(k, ...) played[#played + 1] = k; return keep(k, ...) end
    local _, problems = ns.Grammar.Compile({ lines = { line("blocked", "sound",
        { value = snd, clauses = { { cond = "noMana" } } }) } }, ns.Grammar.Kind(key))
    T.eq(codes(problems), "", "the pair can both be true")
    write(ns, AB, key, { line("blocked", "sound", { value = snd, clauses = { { cond = "noMana" } } }) })
    usable(false, true)
    stub.RunTimers()
    T.eq(#played, 1, "played once as it turned on")
    DUI.Sound.Alert = keep
    noErrors()
end)

T.test("fix 1: a saved can't cast rule from before moves to not usable, once", function()
    local profile
    do
        local _, ns0 = world({ bare = true })
        profile = ns0.Bridge.ProfileOf(1)
    end
    local key = CW.ID(CLAP, ESSENTIAL)
    local db = { conditions = { [profile] = { [key] = {
        cantCast = { gray = true, sound = { value = "x" } },
        noMana = { blue = { clauses = { { cond = "cantCast" } } } },
    } } } }
    local _, ns = world({ db = db, bare = true })
    local C = ns.Conditions
    local rule = C.Rule(key)
    T.isnil(rule.cantCast, "the old meaning is gone")
    T.deq(rule.notUsable, { gray = true, sound = { value = "x" } }, "gray when not usable, as the player made it")
    T.eq(rule.noMana.blue.clauses[1].cond, "notUsable", "a clause moves too")
    T.eq(EZCDMDB.conditionsVersion, C.VERSION, "stamped")
    T.eq(ns.Grammar.Describe(ns.Draft.Rules(key).lines[1]), "When it's not usable, turn it gray.")
    -- A new can't cast rule written after the move stays as it is.
    EZCDMDB.conditions[profile][key].cantCast = { gray = true }
    T.deq(C.Rule(key).cantCast, { gray = true }, "no second move")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. Parts that can never both be true
-- ---------------------------------------------------------------------

T.test("fix 2: the registry declares what never holds together, both ways", function()
    local _, ns = world()
    local C = ns.Conditions
    T.truthy(C.Excludes("notUsable", "noMana"), "declared on not usable")
    T.truthy(C.Excludes("noMana", "notUsable"), "read both ways")
    T.falsy(C.Excludes("cantCast", "noMana"))
    T.eq(ns.Grammar.NeverWords("notUsable", "noMana"), "can't both be true: not usable never counts power")
    noErrors()
end)

T.test("fix 2: the clause strip leaves out a part that can't hold with the line, and says why", function()
    local _, ns, AB, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local keys = table.concat(G.Clauses(kind, line("unusable", "gray"), { drawer = true }), " ")
    T.falsy((" " .. keys .. " "):find(" noMana "), "not offered: " .. keys)
    local refused = {}
    for _, r in ipairs(G.ClauseRefusals(kind, line("unusable", "gray"), { drawer = true })) do refused[r.cond] = r.why end
    T.eq(refused.noMana, "can't both be true: not usable never counts power")
    -- Thunder Clap's aura is a debuff on its targets (AuraLinks.spells).
    T.eq(refused.upish, G.ForKind(G.WORDING.layerClash, kind), "a buff-icon part too")
    T.truthy(refused.upish:find("its debuff", 1, true), refused.upish)
    local _, problems = G.Compile({ lines = { line("unusable", "gray", { clauses = { { cond = "noMana" } } }) } }, kind)
    T.eq(codes(problems), "1:never", "a typed or saved pair is refused too")
    write(ns, AB, key, { line("unusable", "gray") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "and"):Click()
    local s = strip(Drawer)
    T.isnil(s.chip.noMana, "no chip")
    local said = table.concat(s.said, "\n")
    T.truthy(said:find("can't both be true: not usable never counts", 1, true), "the reason shows: " .. said)
    noErrors()
end)

T.test("fix 2: a part about the buff icon and one about the cooldown icon never hold together", function()
    local _, ns = world()
    local G = ns.Grammar
    T.truthy(ns.Conditions.Excludes("cantCast", "upish"), "layers clash")
    T.eq(G.NeverWords("cantCast", "upish"), G.WORDING.layerClash)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. The number word and its box
-- ---------------------------------------------------------------------

T.test("fix 3: a number word shows as soon as its condition is picked, before an action", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray") })
    local Drawer = editor(ns, AB, key)
    Drawer.Parts()  -- drawn
    -- A new line, its moment picked, no action yet.
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b.tokens then
            for _, t in ipairs(b.tokens) do
                if t.piece and t.piece.kind == "add" and t.piece.text == ns.Drawer.ADD_LINE then t:Click() end
            end
        end
    end
    wordOf(Drawer, 2, "moment"):Click()
    strip(Drawer).chip.low:Click()
    local n = wordOf(Drawer, 2, "number")
    T.truthy(n, "the number word is there with no action picked")
    T.eq(sentences(Drawer)[2].said, "When my target is below 20% health, choose what happens.")
    n:Click()
    local s = strip(Drawer)
    s.box:SetFocus(); s.box:SetText("35"); script(s.box, "OnEnterPressed")
    T.eq(sentences(Drawer)[2].said, "When my target is below 35% health, choose what happens.", "kept on the open line")
    noErrors()
end)

T.test("fix 3: the box opens with focus and stays open while pressed; Enter writes", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("low", "gray") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "number"):Click()
    local s = strip(Drawer)
    T.truthy(s.box:HasFocus(), "focus at once, ready to type")
    pressOn(Drawer, s.box, "stripStack")
    T.truthy(Drawer.Slot() and Drawer.Slot().kind == "number", "a press in the box keeps the strip")
    T.truthy(strip(Drawer).box:HasFocus(), "and the focus")
    s = strip(Drawer)
    s.box:SetText("35")
    script(s.box, "OnEnterPressed")
    T.deq(ns.Conditions.Rule(key), { low = { gray = { n = 35 } } }, "Enter writes")
    noErrors()
end)

T.test("fix 3: a redraw while the player types keeps the box, its focus and what is typed", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("low", "gray") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "number"):Click()
    local s = strip(Drawer)
    s.box:SetText("3")
    Drawer.Refresh()
    s = strip(Drawer)
    T.truthy(s.box and s.box:HasFocus(), "still typing")
    T.eq(s.box:GetText(), "3", "what was typed stays")
    T.deq(ns.Conditions.Rule(key), { low = { gray = true } }, "nothing written yet")
    s.box:SetText("33")
    script(s.box, "OnEnterPressed")
    T.deq(ns.Conditions.Rule(key), { low = { gray = { n = 33 } } })
    noErrors()
end)

T.test("fix 3: Escape leaves the number as it was; a press away writes what was typed", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("low", "gray") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "number"):Click()
    local s = strip(Drawer)
    s.box:SetText("44")
    script(s.box, "OnEscapePressed")
    T.deq(ns.Conditions.Rule(key), { low = { gray = true } }, "Escape writes nothing")
    T.isnil(Drawer.Slot(), "and closes the box")
    wordOf(Drawer, 1, "number"):Click()
    s = strip(Drawer)
    s.box:SetText("40")
    pressAway()
    T.deq(ns.Conditions.Rule(key), { low = { gray = { n = 40 } } }, "a press away writes")
    T.isnil(Drawer.Slot(), "and closes")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 4. more…
-- ---------------------------------------------------------------------

T.test("fix 4: more… shows in the moment strip and the clause strip while an advanced condition exists", function()
    local _, ns, AB, key = world()
    write(ns, AB, key, { line("boss", "gray") })
    ns.Settings.Set("more", true)
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "moment"):Click()
    T.truthy(strip(Drawer).chip[Drawer.MORE], "moment strip: fewer, with more on")
    wordOf(Drawer, 1, "and"):Click()
    T.truthy(strip(Drawer).chip[Drawer.MORE], "clause strip")
    ns.Settings.Set("more", false)
    noErrors()
end)

T.test("fix 4: with no advanced condition there is no more… chip", function()
    local _, ns, AB, key = world({ bare = true })
    -- The shipped advanced ones (in combat, in a group...) made plain for this check.
    local was = {}
    for _, c in ipairs(ns.Conditions.List()) do
        was[c] = c.advanced
        c.advanced = nil
    end
    write(ns, AB, key, { line("blocked", "gray") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "moment"):Click()
    T.isnil(strip(Drawer).chip[Drawer.MORE])
    for c, v in pairs(was) do c.advanced = v end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 5. A spell button: no cooldown, no buff
-- ---------------------------------------------------------------------

local LHW = 8004

local function shaman()
    local w = W.Build("SHAMAN")
    stub.knownSpells[LHW] = true
    stub.spells[LHW] = { name = "Lesser Healing Wave" }
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    local key = Ed.KeyForID("spell", tostring(LHW))
    D.AddPiece(D.Ensure(1), key, "icon", 0, 0)
    w.Pass()
    return w, key
end

T.test("fix 5: a spell with no cooldown and no buff reads as a spell button", function()
    local w, key = shaman()
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.button, true, "a spell button")
    T.falsy(kind.cooldown, "no cooldown words")
    T.falsy(kind.buff, "no buff words")
    local moments = {}
    for _, x in ipairs(G.Words(kind)) do moments[x.moment] = x.actions end
    for _, m in ipairs({ "always", "usable", "unusable", "short", "blocked" }) do
        T.truthy(moments[m], m .. " offered")
    end
    for _, m in ipairs({ "ready", "cooldown", "almost", "up", "missing", "ends", "recast" }) do
        T.isnil(moments[m], m .. " not offered")
    end
    T.truthy(G.Fits(kind, "blocked", "glow"), "an EZ glow")
    T.truthy(G.Fits(kind, "blocked", "gray"), "a wash")
    -- A spell with a cooldown, and one with a buff, are not.
    for _, e in ipairs(w.AB.CdmEditor.Spells()) do
        local k = G.Kind(e.id)
        T.falsy(k.button and (k.cooldown or k.buff), "never both")
    end
    noErrors()
end)

T.test("fix 5: a unit condition with a glow fits the spell button", function()
    local w, key = shaman()
    local C = w.ns.Conditions
    local any = function() return true end
    assert(C.Register({ key = "meLow", moment = "meLow", secrecy = "client", layer = "any", excludes = {},
        actions = { glow = { effect = "glow" } }, fits = any, param = { min = 1, max = 99, default = 50 },
        drive = function(_, layer) layer:SetAlpha(1) end, events = { game = { { "UNIT_HEALTH", "player" } } },
        words = { moment = "When I'm below #% health", clause = "I'm below #% health" } }))
    local G = w.ns.Grammar
    T.truthy(G.Fits(G.Kind(key), "meLow", "glow"))
    noErrors()
end)

T.test("fix 5: a spell button that Daylight shows only while a buff is up has a note and a fix", function()
    local w, key = shaman()
    local G = w.ns.Grammar
    local note = G.HiddenNote(G.Kind(key), line("blocked", "gray"))
    T.truthy(note, "hidden: it shows only while a buff is up")
    T.eq(note.code, "button")
    T.eq(note.fixes[1], "shows")
    T.truthy(w.ns.Draft.Write(key, { lines = { line("blocked", "gray") }, shows = "cooldown" }))
    w.Pass()
    T.isnil(G.HiddenNote(G.Kind(key), line("blocked", "gray")), "shown as a cooldown: no note")
    T.truthy(w.ns.Conditions.FrameOf(key), "on show")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 6. The icon a condition is about
-- ---------------------------------------------------------------------

T.test("fix 6: every condition names its icon; a line takes its parts' layer", function()
    local _, ns = world()
    local C = ns.Conditions
    T.eq(C.Get("cantCast").layer, "cooldown")
    T.eq(C.Get("notUsable").layer, "cooldown")
    T.eq(C.Get("noMana").layer, "cooldown")
    T.eq(C.Get("boss").layer, "any")
    T.eq(C.LineLayer("boss", { clauses = { { cond = "cantCast" } } }), "cooldown", "the specific one wins")
    T.eq(C.LineLayer("boss", true), "any")
    local why = select(2, C.Register({ key = "x", moment = "x", actions = wash(), fits = function() return true end,
        secrecy = "plain", read = function() return true end, events = { game = { "PLAYER_TARGET_CHANGED" } } }))
    T.eq(why, "bad layer", "layer is required")
    noErrors()
end)

T.test("fix 6: a cooldown line on a buff-and-cooldown piece stays off while its buff shows", function()
    local _, ns, AB, key = world()
    local keep = ns.Bridge.BuffState
    local up = false
    ns.Bridge.BuffState = function(k, ...) if tostring(k) == tostring(key) then return up end return keep(k, ...) end
    local keepShows = ns.Bridge.Shows
    ns.Bridge.Shows = function(k, ...) if tostring(k) == tostring(key) then return "both" end return keepShows(k, ...) end
    write(ns, AB, key, { line("blocked", "gray"), line("boss", "sound", { value = firstSound(ns) }) })
    usable(false, false)
    T.eq((ns.Conditions.Lit(key) or {}).wash, "blocked" and "cantCast:gray", "lit while the cooldown icon shows")
    local v = ns.Conditions.Visible(key, "cantCast:gray")
    T.truthy(v.shown and v.alpha > 0 and not v.covered, "visible")
    up = true
    ns.Conditions.Refresh(key)
    T.isnil((ns.Conditions.Lit(key) or {}).wash, "off while the buff icon shows")
    T.eq(ns.Conditions.Visible(key, "cantCast:gray").covered, true)
    ns.Bridge.BuffState, ns.Bridge.Shows = keep, keepShows
    noErrors()
end)

T.test("fix 6: the drawer notes a cooldown line hidden by the buff, with two one-click fixes", function()
    local _, ns, AB, key = world()
    local keepShows = ns.Bridge.Shows
    ns.Bridge.Shows = function(k, ...) if tostring(k) == tostring(key) then return "both" end return keepShows(k, ...) end
    local G = ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.shows, "both")
    local note = G.HiddenNote(kind, line("blocked", "gray"))
    T.eq(note.code, "buff")
    T.eq(note.text, "Hidden while its debuff shows.", "Thunder Clap's aura is a debuff")
    T.isnil(G.HiddenNote(kind, line("blocked", "gray", { clauses = { { cond = "noBuff" } } })),
        "with 'and its buff isn't active' it says nothing")
    T.isnil(G.HiddenNote(kind, line("boss", "gray")), "an any-icon line says nothing")
    write(ns, AB, key, { line("blocked", "gray") })
    local Drawer = editor(ns, AB, key)
    local notes = blocksWith(Drawer, "hidden")
    T.eq(#notes, 1, "one note under the line")
    local links = {}
    for _, t in ipairs(notes[1].tokens or {}) do
        if t.piece and t.piece.kind == "add" then links[#links + 1] = t end
    end
    T.eq(#links, 2, "two fixes")
    links[2]:Click()
    T.deq(ns.Conditions.Rule(key), { cantCast = { gray = { clauses = { { cond = "noBuff" } } } } }, "the clause fix")
    ns.Bridge.Shows = keepShows
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Coverage
-- ---------------------------------------------------------------------

T.test("coverage: every registered condition has words, layer, excludes and a class-world driver", function()
    local w = W.Build("WARRIOR")
    local C, G = w.ns.Conditions, w.ns.Grammar
    local fired = {}
    local keep = stub.FireEvent
    stub.FireEvent = function(e, ...) fired[e] = true; return keep(e, ...) end
    local missing = {}
    for _, c in ipairs(C.List()) do
        local function miss(what) missing[#missing + 1] = c.key .. ": " .. what end
        if not G.WORDING.moments[c.moment] then miss("moment words") end
        if not G.WORDING.clauses[c.key] then miss("clause words") end
        if not C.LAYERS[c.layer] then miss("layer") end
        if type(c.excludes) ~= "table" then miss("excludes") end
        for _, e in ipairs(c.events.game or {}) do
            local name = type(e) == "table" and e[1] or e
            local drive = W.EVENT_DRIVERS[name]
            if not drive then
                miss("no driver for " .. name)
            else
                fired = {}
                drive(w)
                if not fired[name] then miss("driver doesn't fire " .. name) end
            end
        end
        for _, h in ipairs(c.events.daylight or {}) do
            if not W.HANDLER_DRIVERS[h] then miss("no driver for Daylight's " .. h) end
        end
    end
    stub.FireEvent = keep
    T.eq(table.concat(missing, "; "), "")
    T.truthy(#C.List() >= 4, "the shipped conditions")
    noErrors()
end)
