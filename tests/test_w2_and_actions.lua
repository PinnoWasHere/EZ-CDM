local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Several actions on one line (wave 2, docs/tasks/w2-and-actions.md): "When I can't
-- cast it, pulse it and glow." A line of several actions is the lines that share its
-- moment, number and clauses, one per action, each with its own picks:
--   1 they save and compile as lines of one action each, so saves from before load
--     as they were and read back as one sentence (Grammar.Rows, DescribeRow)
--   2 an action joins a line only where it can show with the others: never two that
--     set the same thing, the gray with the icon swap, an action that can't take the
--     line's "and" parts, a look that can't follow a part the game hides in a fight,
--     or one another line does at that moment (Grammar.LineActions)
--   3 each action draws as its own line did: one-shot looks fire as the line turns
--     on, held looks stay while it is on, a client line draws held looks only
--   4 Daylight UI's own actions keep their fields beside EZ-CDM's, and an owned ready
--     glow is never drawn twice
--   5 the drawer reads them as one sentence, with an "and …" blank after the last action

local SHOUT, REND, CLAP = 6673, 772, 6343
local EXECUTE = 5308
local EARTH_SHOCK = 8042
local ESSENTIAL = 0
local GOLD = { 1, 0.8, 0.2 }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function L(moment, action, extra)
    local l = { moment = moment, action = action }
    for k, v in pairs(type(extra) == "table" and extra or {}) do l[k] = v end
    return l
end

local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

local function usable(can, noPower)
    C_Spell.IsSpellUsable = function() return can, noPower end
end

local function gameSaysUsable()
    stub.FireEvent("SPELL_UPDATE_USABLE")
    stub.RunTimers()
end

-- Thunder Clap placed as an icon, logged in, with lines written to it.
local function world(lines, motion)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[CLAP] = { name = "Thunder Clap" }
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = motion ~= false
    usable(true, false)
    local AB = stub.actionbars
    local key = CW.ID(CLAP, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    pass(AB)
    if lines then
        local ok, why, report = ns.Draft.Write(key, { lines = lines })
        T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes[1] and report.notes[1].words))
        pass(AB)
    end
    return DUI, ns, AB, key
end

local function block() usable(false, false); gameSaysUsable() end
local function unblock() usable(true, false); gameSaysUsable() end

local function holderOf(DUI, ns, key) return DUI.API.Attach(ns.Conditions.FrameOf(key)) end

-- A class world with spell id placed as an icon on its row.
local function placed(class, id)
    local w = W.Build(class)
    local key
    local r = w.Row(id)
    if r and r.category == W.ESSENTIAL then
        key = CW.ID(r.spell, r.category)
    else
        key = CW.ID(id, W.ESSENTIAL)
    end
    local D = w.AB.CdmData
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, "icon", 0, 0) end
    w.Pass()
    return w, key
end

local function write(w, key, lines)
    local ok, why, report = w.ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes and report.notes[1]
        and report.notes[1].words))
    w.Pass()
end

-- A table as text, keys sorted, so two reads compare byte for byte.
local function dump(v)
    if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = "[" .. dump(k) .. "]=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function has(list, v)
    for _, x in ipairs(list) do
        if x == v then return true end
    end
    return false
end

local function refusedOf(refused, action)
    for _, r in ipairs(refused) do
        if r.action == action or r.cond == action then return r.why end
    end
end

-- ---------------------------------------------------------------------
-- 1. One sentence, saved as one line per action
-- ---------------------------------------------------------------------

T.test("rows: lines sharing a moment, number and clauses read as one sentence, with 2 or 3 actions", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local breathe = L("blocked", "glow", { style = "breathe" })
    local pulse = L("blocked", "pulse")
    local sound = L("blocked", "sound", { value = "dui:quest" })
    local said = ns.Bridge.SoundChoices()["dui:quest"]
    T.deq(G.Rows({ pulse, breathe }, kind), { { 2, 1 } }, "one row, glow first in reading order")
    T.eq(G.DescribeRow({ breathe, pulse }, kind),
        "When I can't cast it, glow with a " .. G.StyleName("breathe") .. " and pulse it.")
    T.deq(G.Rows({ sound, pulse, breathe }, kind), { { 3, 2, 1 } }, "a sound reads last")
    T.eq(G.DescribeRow({ breathe, pulse, sound }, kind), "When I can't cast it, glow with a "
        .. G.StyleName("breathe") .. ", pulse it, and play \"" .. tostring(said) .. "\".")
    -- What keeps lines apart: another moment, number or clause, a blank action.
    local combat = L("blocked", "flash", { clauses = { { cond = "inCombat" } } })
    T.deq(G.Rows({ pulse, combat, breathe }, kind), { { 3, 1 }, { 2 } }, "a clause makes its own line")
    T.deq(G.Rows({ pulse, L("unusable", "glow") }, kind), { { 1 }, { 2 } })
    T.deq(G.Rows({ pulse, L("blocked", nil) }, kind), { { 1 }, { 2 } }, "a blank action stands alone")
    T.eq(G.RowKey(L("targetLow", "border")), G.RowKey(L("targetLow", "pulse", { n = 20 })),
        "the default number is the number")
    T.falsy(G.RowKey(L("targetLow", "border", { n = 30 })) == G.RowKey(L("targetLow", "pulse")))
    noErrors()
end)

T.test("rows: a line of three actions compiles, reads back and round-trips unchanged", function()
    local lines = { L("blocked", "glow", { value = { 1, 0, 0 }, style = "breathe" }), L("blocked", "flash"),
        L("blocked", "pulse", { value = GOLD }) }
    local _, ns, AB, key = world(lines)
    local G, C = ns.Grammar, ns.Conditions
    local kind = G.Kind(key)
    T.deq(C.Rule(key), { cantCast = { glow = { value = { 1, 0, 0 }, style = "breathe" },
        pulse = { value = GOLD }, flash = true } }, "one record per action, each with its own picks")
    local rules = ns.Draft.Rules(key)
    local rows = G.Rows(rules.lines, kind)
    T.eq(#rows, 1, "read back as one line")
    local back = {}
    for p, x in ipairs(rows[1]) do back[p] = rules.lines[x] end
    T.deq(back, lines, "each action with its picks, in reading order")
    local before = dump(DaylightUIDB) .. dump(EZCDMDB)
    local ok, report = ns.Draft.Write(key, rules)
    T.truthy(ok)
    T.eq(report.changes, 0, "written again: nothing changes")
    pass(AB)
    T.eq(dump(DaylightUIDB) .. dump(EZCDMDB), before, "byte for byte")
    local fields = G.Compile(rules, kind)
    T.deq(C.Split(fields), C.Rule(key), "compile after decompile gives the save")
    noErrors()
end)

T.test("rows: a save from 1.0.0 loads as it was, draws as it did, and reads as one line", function()
    local _, ns, AB, key = world()
    local C = ns.Conditions
    local profile = ns.Bridge.ProfileOf(1)
    EZCDMDB.conditionsVersion = C.VERSION
    EZCDMDB.conditions = { [profile] = { [key] = { cantCast = { glow = true, pulse = { value = GOLD } },
        notUsable = { gray = true } } } }
    local saved = dump(EZCDMDB.conditions)
    C.Sync(); pass(AB)
    T.eq(C.VERSION, 6, "no new saved form")
    T.eq(dump(EZCDMDB.conditions), saved, "the save is untouched")
    block()
    local lit = C.Lit(key) or {}
    T.eq(lit.glow, "cantCast:glow", "the glow lights as before")
    T.truthy(C.Visible(key, "cantCast:pulse").shown, "the pulse shows as before")
    T.truthy(C.Visible(key, "notUsable:gray").lit, "the gray as before")
    local rules = ns.Draft.Rules(key)
    local rows = ns.Grammar.Rows(rules.lines, ns.Grammar.Kind(key))
    T.eq(#rows, 2, "can't cast's two lines read as one; not usable's on its own")
    local ok, report = ns.Draft.Write(key, rules)
    T.truthy(ok)
    T.eq(report.changes, 0, "and write back unchanged")
    T.eq(dump(EZCDMDB.conditions), saved)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. What may join a line
-- ---------------------------------------------------------------------

T.test("refusals: never two that set the same thing, never gray with the icon swap", function()
    local _, ns, _, key = world()
    local G = ns.Grammar
    local kind = G.Kind(key)
    local W_ = G.WORDING
    local keys, refused = G.LineActions(kind, { L("cooldown", "fade") }, {})
    T.falsy(has(keys, "hide"))
    T.eq(refusedOf(refused, "hide"), W_.neverAction:format("make it see-through", "hide it"))
    T.eq(refusedOf(refused, "show"), W_.neverAction:format("make it see-through", "show it"))
    T.truthy(has(keys, "gray"), "gray sets another field")
    -- Hidden, the piece shows nothing drawn on it; a sound still plays.
    keys, refused = G.LineActions(kind, { L("blocked", "pulse") }, {})
    T.truthy(has(keys, "sound") and has(keys, "screen"), "off the piece: still fine")
    keys, refused = G.LineActions(kind, { L("cooldown", "hide") }, {})
    T.eq(refusedOf(refused, "gray"), W_.neverAction:format("hide it", "turn it gray"))
    T.eq(refusedOf(refused, "nosweep"), W_.neverAction:format("hide it", "hide the sweep"))
    -- One hides the other: no global cooldown sweep with no sweep at all.
    keys, refused = G.LineActions(kind, { L("cooldown", "nosweep") }, {})
    T.eq(refusedOf(refused, "nogcd"), W_.neverAction:format("hide the sweep", "hide the global cooldown sweep"))
    keys, refused = G.LineActions(kind, { L("cooldown", "gray") }, {})
    T.eq(refusedOf(refused, "color"), W_.neverAction:format("turn it gray", "keep its color"))
    keys, refused = G.LineActions(kind, { L("blocked", "gray") }, {})
    T.falsy(has(keys, "swap"))
    T.eq(refusedOf(refused, "swap"), W_.neverAction:format("turn it gray", "swap its icon"))
    T.falsy(has(keys, "gray"), "an action already on the line isn't offered again")
    T.truthy(has(keys, "glow") and has(keys, "pulse") and has(keys, "flash") and has(keys, "sound"))
    -- Another line at this moment does it already.
    local other = L("blocked", "glow", { clauses = { { cond = "inCombat" } } })
    keys, refused = G.LineActions(kind, { L("blocked", "pulse") }, { other })
    T.falsy(has(keys, "glow"))
    T.eq(refusedOf(refused, "glow"), W_.neverTaken)
    -- Three is the most.
    keys, refused = G.LineActions(kind, { L("blocked", "glow"), L("blocked", "pulse"), L("blocked", "flash") }, {})
    T.eq(#keys + #refused, 0, "a full line takes no more")
    T.eq(G.MAX_ACTIONS, 3)
    noErrors()
end)

T.test("refusals: a line with and-parts takes only actions that can; a client part only held looks", function()
    local w, key = placed("WARRIOR", EXECUTE)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local W_ = G.WORDING
    T.truthy(kind.targeted, "Execute is cast at a target")
    -- A client clause: only the looks that stay on can follow it.
    local low = { { cond = "targetLow" } }
    local keys, refused = G.LineActions(kind, { L("blocked", "pulse", { clauses = low }) }, {})
    T.truthy(has(keys, "border") and has(keys, "halo") and has(keys, "text"), table.concat(keys, " "))
    for _, a in ipairs({ "flash", "sparkle", "screen", "sound" }) do
        T.falsy(has(keys, a), a .. " not offered")
        T.eq(refusedOf(refused, a), W_.neverSecret:format("my target is below 20% health"), a)
    end
    -- A client moment offers only the looks that stay on at all.
    keys = G.LineActions(kind, { L("targetLow", "border") }, {})
    T.truthy(has(keys, "pulse"))
    T.falsy(has(keys, "flash") or has(keys, "sound"))
    -- The clause strip: a client part only where every action can follow it.
    local row = { L("blocked", "pulse"), L("blocked", "flash") }
    local conds, why = G.RowClauses(kind, row, { drawer = true, more = true })
    T.falsy(has(conds, "targetLow"))
    T.eq(refusedOf(why, "targetLow"), W_.neverOther:format("flash it"))
    T.truthy(has(conds, "inCombat"), "a plain part fits both")
    conds = G.RowClauses(kind, { L("blocked", "pulse"), L("blocked", "border") }, { drawer = true, more = true })
    T.truthy(has(conds, "targetLow"), "two held looks take it")
    noErrors()
end)

T.test("refusals: Daylight UI's show, fade and hide can't join a line with and-parts", function()
    local w, key = placed("SHAMAN", EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy(kind.cooldownReady)
    local fight = { { cond = "inCombat" } }
    local keys, refused = G.LineActions(kind, { L("ready", "glow", { clauses = fight }) }, {})
    for _, a in ipairs({ "show", "fade" }) do
        T.falsy(has(keys, a), a)
        T.eq(refusedOf(refused, a), G.WORDING.neverClauses, a)
    end
    T.eq(refusedOf(refused, "hide"), G.WORDING.neverAction:format("glow", "hide it"), "hidden, it shows no glow")
    T.truthy(has(keys, "pulse") and has(keys, "sound"), "EZ-CDM's looks and the owned sound take them")
    -- With show on the line, no "and" part at all.
    T.falsy(G.RowTakesClauses({ L("ready", "show"), L("ready", "glow") }, kind))
    T.truthy(G.RowTakesClauses({ L("ready", "glow"), L("ready", "pulse") }, kind))
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. How they draw
-- ---------------------------------------------------------------------

T.test("draw: two and three actions on one line light together and go together", function()
    local DUI, ns, _, key = world({ L("blocked", "glow"), L("blocked", "pulse"), L("blocked", "border", { value = GOLD }) })
    local C = ns.Conditions
    for _, id in ipairs({ "cantCast:glow", "cantCast:pulse", "cantCast:border" }) do
        T.falsy(C.Visible(key, id).lit, id .. ": off while castable")
    end
    block()
    for _, id in ipairs({ "cantCast:glow", "cantCast:pulse", "cantCast:border" }) do
        local v = C.Visible(key, id)
        T.truthy(v.lit and v.shown, id .. ": on")
    end
    T.truthy(ns.Looks.Frame(holderOf(DUI, ns, key), "border").shell, "the border in its own color")
    unblock()
    for _, id in ipairs({ "cantCast:glow", "cantCast:pulse", "cantCast:border" }) do
        T.falsy(C.Visible(key, id).shown, id .. ": gone with the line")
    end
    noErrors()
end)

T.test("draw: a one-shot look and a held look on one line: the flash once, the pulse held", function()
    local DUI, ns, _, key = world({ L("unusable", "flash", { value = GOLD }), L("unusable", "pulse"),
        L("unusable", "sound", { value = "dui:quest" }) })
    local heard = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(k, ...)
        heard[#heard + 1] = k
        return keep(k, ...)
    end
    block()
    local f = ns.Looks.Fired(key, "flash")
    T.truthy(f, "the flash fired")
    T.truthy(ns.Conditions.Visible(key, "notUsable:pulse").shown, "the pulse holds")
    T.eq(#heard, 1, "the sound played once")
    ns.Conditions.Refresh(key)
    T.eq(ns.Looks.Fired(key, "flash").n, f.n, "still on: no second flash")
    T.eq(#heard, 1, "and no second sound")
    T.truthy(ns.Conditions.Visible(key, "notUsable:pulse").shown, "the pulse still holds")
    unblock()
    T.falsy(ns.Conditions.Visible(key, "notUsable:pulse").shown)
    block()
    T.eq(ns.Looks.Fired(key, "flash").n, f.n + 1, "on again: the flash fires again")
    T.eq(#heard, 2)
    DUI.Sound.Alert = keep
    noErrors()
end)

T.test("draw: a client line of three held looks hangs each under the layer the game drives", function()
    local w, key = placed("WARRIOR", EXECUTE)
    write(w, key, { L("targetLow", "border"), L("targetLow", "pulse"), L("targetLow", "text", { value = "Low!" }) })
    T.eq(#w.ns.Grammar.Rows(w.ns.Draft.Rules(key).lines, w.ns.Grammar.Kind(key)), 1, "one line")
    w.NewTarget()
    w.EnterCombat()
    w.Health("target", 0.1, "secret")
    for _, id in ipairs({ "targetLow:border", "targetLow:pulse", "targetLow:text" }) do
        local v = w.ns.Conditions.Visible(key, id)
        T.eq(v.alpha, w.ns.Conditions.SECRET, id .. ": the game's secret")
        T.truthy(v.layered, id .. ": under the driven layer")
    end
    -- A one-shot look can't go on it: compiling one refuses the whole line part.
    local _, problems = w.ns.Grammar.Compile({ lines = { L("blocked", "flash", { clauses = { { cond = "targetLow" } } }) } },
        w.ns.Grammar.Kind(key))
    T.eq(problems[1] and problems[1].code, "secret")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 4. Daylight UI's own actions on one line with EZ-CDM's
-- ---------------------------------------------------------------------

T.test("owned: When it's ready, glow and pulse it: Daylight UI's glow, EZ-CDM's pulse", function()
    local w, key = placed("SHAMAN", EARTH_SHOCK)
    write(w, key, { L("ready", "glow"), L("ready", "pulse") })
    local piece = w.AB.CdmData.Get(1).pieces[key]
    T.eq(piece.readyGlow, true, "the glow stays Daylight UI's field")
    T.deq(w.ns.Conditions.Rule(key), { offCooldown = { pulse = true } }, "the pulse is EZ-CDM's")
    T.isnil(w.ns.Ready.Record(key), "Daylight UI keeps its ready glow")
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.truthy(w.AB.CdmEffects.GlowShown(CW.Item(key)), "Daylight UI's glow")
    local lit = w.ns.Conditions.Lit(key) or {}
    T.isnil(lit.glow, "never an EZ-CDM glow beside it")
    T.truthy(w.ns.Conditions.Visible(key, "offCooldown:pulse").shown, "the pulse")
    noErrors()
end)

T.test("owned: with and I'm in combat, both are EZ-CDM's and there is one glow, never two", function()
    local w, key = placed("SHAMAN", EARTH_SHOCK)
    local fight = { { cond = "inCombat" } }
    write(w, key, { L("ready", "glow", { clauses = fight }), L("ready", "pulse", { clauses = fight }) })
    local piece = w.AB.CdmData.Get(1).pieces[key]
    T.falsy(piece.readyGlow == true, "Daylight UI's ready glow off for this piece")
    T.deq(w.ns.Conditions.Rule(key), { offCooldown = { glow = { clauses = fight }, pulse = { clauses = fight } } })
    local rows = w.ns.Grammar.Rows(w.ns.Draft.Rules(key).lines, w.ns.Grammar.Kind(key))
    T.eq(#rows, 1, "one line")
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Ready(sid); w.EnterCombat(); w.Pass()
    local lit = w.ns.Conditions.Lit(key) or {}
    T.eq(lit.glow, "offCooldown:glow", "EZ-CDM's glow")
    T.falsy(w.AB.CdmEffects.GlowShown(CW.Item(key)), "never Daylight UI's with it")
    T.truthy(w.ns.Conditions.Visible(key, "offCooldown:pulse").shown, "and the pulse")
    w.LeaveCombat()
    lit = w.ns.Conditions.Lit(key) or {}
    T.isnil(lit.glow)
    T.falsy(w.ns.Conditions.Visible(key, "offCooldown:pulse").shown, "both go with the fight")
    noErrors()
end)

T.test("owned: When I can't cast it, turn it gray and glow: one gray, EZ-CDM's", function()
    local w, key = placed("SHAMAN", EARTH_SHOCK)
    write(w, key, { L("blocked", "gray"), L("blocked", "glow") })
    T.eq(w.AB.CdmData.Get(1).pieces[key].desat, "color", "Daylight UI's Gray out stays colored")
    T.truthy(w.ns.Gray.Record(key), "the player's own Gray out kept")
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Pass()
    local lit = w.ns.Conditions.Lit(key) or {}
    T.eq(lit.glow, "cantCast:glow")
    local v = w.ns.Conditions.Visible(key, "cantCast:gray")
    T.truthy(v.lit, "the gray line lit")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 5. The drawer
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

-- Line i's words of a kind, in order.
local function wordsOf(Drawer, i, kind)
    local out = {}
    local b = sentences(Drawer)[i]
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == kind then out[#out + 1] = t end
    end
    return out
end
local function wordOf(Drawer, i, kind) return wordsOf(Drawer, i, kind)[1] end

local function strip(Drawer)
    local out = { keys = {}, chip = {}, never = {} }
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() then
            if b.box then out.box = b.box end
            if b.never then out.never[b.never] = b.said end
            if b.tokens and b.choices then
                for _, t in ipairs(b.tokens) do
                    out.keys[#out.keys + 1] = tostring(t.piece.key)
                    out.chip[t.piece.key] = t
                end
            elseif b.tokens and not b.never and not out.heading then
                out.heading = b.said
            end
        end
    end
    return out
end

T.test("drawer: and … after the last action adds one; the strip says why for the rest", function()
    local _, ns, AB, key = world({ L("blocked", "glow") })
    local Drawer = editor(ns, AB, key)
    local G = ns.Grammar
    T.eq(#sentences(Drawer), 1)
    local also = wordOf(Drawer, 1, "also")
    T.truthy(also, "an and … chip after the action")
    T.eq(stub.Text(also.text), G.WORDING.addAction)
    T.truthy(also.SetOn, "a blank: Daylight UI's chip")
    T.falsy(sentences(Drawer)[1].said:find("and …", 1, true), "the chip isn't part of what it says")
    local tokens = sentences(Drawer)[1].tokens
    T.eq(tokens[#tokens - 1].piece.word, "also", "after the last action, before the stop")
    also:Click()
    local s = strip(Drawer)
    T.eq(s.heading, "Choose what else happens:")
    T.falsy(has(s.keys, "glow"), "not the action it has")
    T.truthy(has(s.keys, "pulse") and has(s.keys, "gray"), table.concat(s.keys, " "))
    s.chip.gray:Click()
    T.deq(ns.Conditions.Rule(key), { cantCast = { glow = true, gray = true } }, "written at once")
    T.eq(#sentences(Drawer), 1, "still one line")
    T.eq(sentences(Drawer)[1].said, "When I can't cast it, glow with the spell's style in the accent color and turn it gray.")
    -- The strip stays open on the chip, now refusing the swap beside the gray.
    s = strip(Drawer)
    T.eq(s.heading, "Choose what else happens:", "the strip stays open for the next pick")
    T.truthy(s.never.swap, "the swap is refused")
    T.truthy(s.never.swap:find("turn it gray and swap its icon at once", 1, true), s.never.swap)
    noErrors()
end)

T.test("drawer: three actions read naturally, fit the drawer's width, and take no fourth", function()
    local _, ns, AB, key = world({ L("blocked", "glow", { value = GOLD }), L("blocked", "pulse", { value = GOLD }),
        L("blocked", "flare") })
    local Drawer = editor(ns, AB, key)
    local G = ns.Grammar
    local b = sentences(Drawer)[1]
    T.eq(#sentences(Drawer), 1)
    local flare = ns.Grammar.Describe(L("blocked", "flare")):match(", (.-)%.$")
    T.eq(b.said, "When I can't cast it, glow with the spell's style in gold, " .. flare .. ", and pulse it in gold.",
        "the action words' order: one-shot looks before held ones")
    T.isnil(wordOf(Drawer, 1, "also"), "three is the most: no and … chip")
    T.eq(#wordsOf(Drawer, 1, "action"), 3, "each action its own word")
    -- Every word inside the drawer's width.
    local width = b:GetWidth()
    T.truthy(width > 0)
    for _, t in ipairs(b.tokens) do
        local _, _, _, x = t:GetPoint(1)
        T.truthy(x + t:GetWidth() <= width + 0.5, "inside the width: " .. tostring(stub.Text(t.text or t)))
    end
    local one = sentences(Drawer)
    T.truthy(b:GetHeight() > 0 and #one == 1)
    T.isnil(G.LineActions(G.Kind(key), { L("blocked", "glow"), L("blocked", "pulse"), L("blocked", "flare") }, {})[1])
    noErrors()
end)

T.test("drawer: right-click clears one action; the line's other words go to every action", function()
    local _, ns, AB, key = world({ L("blocked", "glow"), L("blocked", "pulse"), L("blocked", "flash") })
    local Drawer = editor(ns, AB, key)
    local acts = wordsOf(Drawer, 1, "action")
    T.eq(stub.Text(acts[3].text), "pulse it")
    acts[3]:Click("RightButton")
    T.deq(ns.Conditions.Rule(key), { cantCast = { glow = true, flash = true } }, "the pulse alone goes")
    T.eq(sentences(Drawer)[1].said, "When I can't cast it, glow with the spell's style in the accent color and flash it in the accent color.")
    -- A clause goes on every action.
    ns.Settings.Set("more", true)
    wordOf(Drawer, 1, "and"):Click()
    strip(Drawer).chip.inCombat:Click()
    local fight = { { cond = "inCombat" } }
    T.deq(ns.Conditions.Rule(key), { cantCast = { glow = { clauses = fight }, flash = { clauses = fight } } })
    T.eq(sentences(Drawer)[1].said,
        "When I can't cast it and I'm in combat, glow with the spell's style in the accent color and flash it in the accent color.")
    -- A new moment takes every action that fits it.
    wordOf(Drawer, 1, "moment"):Click()
    strip(Drawer).chip.unusable:Click()
    T.deq(ns.Conditions.Rule(key), { notUsable = { glow = { clauses = fight }, flash = { clauses = fight } } })
    -- The remove button takes the whole line.
    sentences(Drawer)[1].remove:Click()
    T.isnil(ns.Conditions.Rule(key), "every action gone")
    noErrors()
end)

T.test("drawer: words or an icon picked after and … wait with their blank open", function()
    local _, ns, AB, key = world({ L("blocked", "glow") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "also"):Click()
    strip(Drawer).chip.text:Click()
    T.deq(ns.Conditions.Rule(key), { cantCast = { glow = true } }, "nothing new written yet; the glow stays")
    T.eq(#sentences(Drawer), 1, "the waiting action reads on its line")
    T.truthy(sentences(Drawer)[1].said:find("and show words on it type…", 1, true), sentences(Drawer)[1].said)
    local s = strip(Drawer)
    T.truthy(s.box, "the words' box opens at once")
    s.box:SetFocus(); s.box:SetText("Go!"); s.box:ClearFocus()
    T.deq(ns.Conditions.Rule(key), { cantCast = { glow = true, text = { value = "Go!" } } })
    T.eq(sentences(Drawer)[1].said, "When I can't cast it, glow with the spell's style in the accent color and show words on it \"Go!\".")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 6. The repro tool
-- ---------------------------------------------------------------------

T.test("repro: a report's line of several actions prints as one sentence, each action under it", function()
    local R = require("repro_world")
    local text = R.Sample("SHAMAN", { { "Earth Shock", { L("blocked", "glow"), L("blocked", "pulse", { value = GOLD }),
        L("blocked", "sound", { value = "dui:quest" }) } } })
    local w, report, missed = R.Build(text)
    T.eq(#missed, 0, "every piece placed")
    local key = R.Keys(w, report)[1]
    local about = table.concat(R.Describe(w, report, key), "\n")
    T.truthy(about:find("When I can't cast it, glow, pulse it in the color you picked, and play", 1, true), about)
    T.truthy(about:find("+ {action=pulse,moment=blocked", 1, true), about)
    noErrors()
end)
