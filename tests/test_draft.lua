local stub = require("stub")
local CW = require("cdmworld")

-- EZ-CDM/Draft.lua: one placed spell read from and written live to the layout
-- Daylight UI's editor shows, against Daylight UI's real Cooldown Manager and the
-- game's own viewers (cdmworld, a warrior).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871
local ESSENTIAL, UTILITY, BUFFS = 0, 1, 2

local RED, GOLD, BLUE = { 1, 0, 0 }, { 1, 0.82, 0 }, { 0.2, 0.4, 1 }

-- Daylight UI, the game's Cooldown Manager and EZ-CDM, logged in.
local function world()
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
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
    return DUI, ns, ns.Draft, stub.actionbars
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end

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

local function db() return dump(DaylightUIDB) end

-- A saved layout on talent set 1:
--   Rend - Thunder Clap - Shield Wall  (a group of three, running right)
--   Bloodrage                          (a bar on its own)
-- Thunder Clap glows gold when ready and fades on cooldown; its look, glow style and
-- size are set too.
local function layoutWorld()
    local DUI, ns, Draft, AB = world()
    local D = AB.CdmData
    local set = D.Ensure(1)
    local k = { rend = CW.ID(REND, ESSENTIAL), clap = CW.ID(CLAP, ESSENTIAL), wall = CW.ID(WALL, BUFFS),
        rage = CW.ID(RAGE, UTILITY), shout = CW.ID(SHOUT, BUFFS) }
    D.AddPiece(set, k.rend, "icon", 0, 0)
    D.AddPiece(set, k.clap, "icon", 0, 0)
    D.Hook(set, k.clap, k.rend, "right", "center")
    D.AddPiece(set, k.wall, "icon", 0, 0)
    D.Hook(set, k.wall, k.clap, "right", "center")
    D.AddPiece(set, k.rage, "bar", 0, -200)
    set.pieces[k.clap].track = "cooldown"
    D.SetSpellValue(set, k.clap, "readyGlow", true)
    D.SetSpellValue(set, k.clap, "readyGlowColor", GOLD)
    D.SetSpellValue(set, k.clap, "onCd", "fade")
    D.SetSpellValue(set, k.clap, "glowStyle", "comet")
    D.SetLook(set, k.clap, "size", 40)
    D.SetLook(set, k.clap, "cdSize", 14)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, Draft, AB, k, set
end

local function pieceOf(key) return stub.actionbars.CdmData.Get(1).pieces[key] end

-- The fields a write must never touch: the look keys the grammar doesn't own, size
-- and shape. The glow style is the grammar's since the pivot's Look settings row.
local function untouched(key)
    local p = pieceOf(key)
    return dump({ look = p.look, size = p.size, shape = p.shape })
end

-- The fields a report says landed, in order.
local function landed(report)
    local out = {}
    for _, c in ipairs(report.changed) do out[#out + 1] = c.kind .. ":" .. c.field end
    return table.concat(out, ",")
end

-- ---------------------------------------------------------------------
-- Reading
-- ---------------------------------------------------------------------

T.test("draft rules: a placed spell reads as its sentences, its group's words included", function()
    local _, ns, Draft, AB, k, set = layoutWorld()
    AB.CdmData.SetChainValue(set, k.rend, "combat", true)
    local rules = Draft.Rules(k.clap)
    T.deq(rules.lines, { L("ready", "glow", GOLD), L("cooldown", "fade") }, "Grammar.Decompile of its fields")
    T.deq(rules.group, { combat = true }, "the words of the group it's in")
    T.deq(rules.forms, {})
    T.isnil(Draft.Rules(k.shout), "a spell not placed has none")
    T.eq(ns.Draft, Draft); T.eq(_G.EZCDM_Draft, Draft, "the debug handle")
    noErrors()
end)

T.test("draft rules: read from the talent set the editor shows", function()
    local _, _, Draft, AB, k = layoutWorld()
    local D = AB.CdmData
    local set2 = D.Ensure(2)
    D.AddPiece(set2, k.clap, "icon", 0, 0)
    D.SetSpellValue(set2, k.clap, "onReady", "hide")
    D.SetViewing(2)
    T.deq(Draft.Rules(k.clap).lines, { L("ready", "hide") }, "set 2's Thunder Clap")
    T.eq(Draft.Write(k.clap, { lines = { L("ready", "fade") } }), true)
    T.eq(D.Get(2).pieces[k.clap].onReady, "fade", "written to set 2")
    D.SetViewing(nil)
    T.eq(pieceOf(k.clap).onReady, nil, "set 1 untouched")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------

T.test("draft write: only the fields that change, and it reads back as written", function()
    local _, _, Draft, _, k = layoutWorld()
    local look = untouched(k.clap)
    local rules = { lines = { L("ready", "glow", BLUE), L("ready", "sound", "dui:quest"),
        L("cooldown", "hide"), L("cooldown", "gray") }, group = {}, forms = { "Battle" }, style = "comet" }
    local ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "set:onCd,set:desat,set:readyGlowColor,set:readySound,set:hideInBattle",
        "in Grammar.FIELDS order; the glow itself was on already")
    T.eq(report.changes, 5)
    rules.shows = "cooldown"
    T.deq(Draft.Rules(k.clap), rules, "reads back as written, with its saved What it shows pick")
    T.eq(pieceOf(k.clap).readyGlowColor[3], 1, "the blue landed")
    T.eq(untouched(k.clap), look, "look, size and shape unchanged")
    local before = db()
    ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true)
    T.eq(#report.changed, 0, "the same rules again write nothing")
    T.eq(db(), before, "DaylightUIDB deep-equal")
    noErrors()
end)

T.test("draft write: a dropped line writes Daylight UI's default, which its setter drops", function()
    local _, _, Draft, _, k = layoutWorld()
    local ok, report = Draft.Write(k.clap, { lines = {} })
    T.eq(ok, true)
    T.eq(landed(report), "clear:onCd,clear:readyGlow,clear:glowStyle")
    local p = pieceOf(k.clap)
    T.isnil(p.readyGlow, "readyGlow dropped")
    T.isnil(p.onCd, "onCd dropped")
    T.eq(p.readyGlowColor[2], GOLD[2], "the unlit color stays, as the card leaves it")
    T.isnil(p.glowStyle, "no style word: back to Daylight UI's Ring")
    noErrors()
end)

T.test("draft write: the fade amount counts only with a fade line", function()
    local _, _, Draft, _, k = layoutWorld()
    T.eq(Draft.Write(k.clap, { lines = { L("ready", "glow", GOLD), L("cooldown", "fade", 0.25) } }), true)
    T.eq(pieceOf(k.clap).cdAlpha, 0.25)
    local ok, report = Draft.Write(k.clap, { lines = { L("ready", "glow", GOLD), L("cooldown", "hide") } })
    T.eq(ok, true)
    T.eq(landed(report), "set:onCd", "the amount stays, unused")
    T.eq(pieceOf(k.clap).cdAlpha, 0.25)
    noErrors()
end)

T.test("draft write: a glow color back to the accent can't be written, and says so", function()
    local _, _, Draft, _, k = layoutWorld()
    local before = db()
    local ok, report = Draft.Write(k.clap, { lines = { L("ready", "glow"), L("cooldown", "fade") }, style = "comet" })
    T.eq(ok, true)
    T.eq(#report.changed, 0, "nothing to write")
    T.eq(db(), before)
    T.eq(report.notes[1].code, "accent")
    T.eq(report.notes[1].words, "Thunder Clap: Daylight UI can't set a glow back to the accent color, so it stays gold.")
    T.falsy(report.notes[1].blocking)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Refusals
-- ---------------------------------------------------------------------

T.test("draft write: a refused write leaves DaylightUIDB as it was", function()
    local _, ns, Draft, _, k = layoutWorld()
    local rules = { lines = { L("ready", "glow", RED), L("cooldown", "hide") }, group = { combat = true } }
    local before = db()
    local function refused(want, key, r)
        local ok, why, report = Draft.Write(key, r or rules)
        T.falsy(ok, want)
        T.eq(why, want)
        T.eq(#report.changed, 0, want .. ": nothing written")
        T.eq(db(), before, want .. ": DaylightUIDB deep-equal")
        return report
    end
    stub.EnterCombat()
    refused("combat", k.clap)
    stub.LeaveCombat()
    ns.Bridge.NEEDS[#ns.Bridge.NEEDS + 1] = "ActionBars.CdmData.EZCDMGone"
    refused("off", k.clap)
    ns.Bridge.NEEDS[#ns.Bridge.NEEDS] = nil
    refused("unplaced", k.shout)
    refused("unplaced", nil)
    -- A line the piece doesn't take: gray on a bar.
    local report = refused("problems", k.rage, { lines = { L("cooldown", "gray") } })
    T.eq(report.notes[1].code, "kind")
    T.truthy(report.notes[1].blocking)
    T.eq(report.notes[1].words, "Bloodrage: \"While it's cooling down, turn it gray.\" doesn't fit this spell.")
    report = refused("problems", k.clap, { lines = { L("ready") } })
    T.eq(report.notes[1].code, "blank")
    noErrors()
end)

T.test("draft write: a write refused part way stops, says what landed, and the next one finishes", function()
    local _, ns, Draft, _, k = layoutWorld()
    local rules = { lines = { L("ready", "glow", BLUE), L("ready", "sound", "dui:quest"), L("cooldown", "hide") },
        group = { combat = true } }
    local B = ns.Bridge
    local keep, calls = B.SetSpellValue, 0
    B.SetSpellValue = function(...)
        calls = calls + 1
        if calls == 2 then return false, "rejected" end
        return keep(...)
    end
    local ok, why, report = Draft.Write(k.rage, rules)
    B.SetSpellValue = keep
    T.falsy(ok)
    T.eq(why, "rejected")
    T.eq(landed(report), "group:combat,set:onCd", "group words first, then spell fields in order")
    T.eq(pieceOf(k.rage).onCd, "hide", "what landed is saved")
    T.isnil(pieceOf(k.rage).readyGlow, "the rest is not")
    T.eq(Draft.Write(k.rage, rules), true, "the next write finishes")
    T.deq(Draft.Rules(k.rage), { lines = rules.lines, group = rules.group, forms = {}, shows = pieceOf(k.rage).track },
        "its saved What it shows pick, if any, reads back too")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Groups and the grammar's flags
-- ---------------------------------------------------------------------

-- Where every piece sits: x, y, parent, side, align, gap and its group's first piece.
local function places(AB)
    local D = AB.CdmData
    local set = D.Get(1)
    local out = {}
    for key, p in pairs(set.pieces) do
        out[key] = { x = p.x, y = p.y, parent = p.parent, side = p.side, align = p.align, gap = p.gap,
            root = D.Root(set, key) }
    end
    return dump(out)
end

-- The first sound Daylight UI's list offers.
local function aSound(ns)
    local values, order = ns.Bridge.SoundChoices()
    for _, k in ipairs(order) do
        if not tostring(k):find("^head:") and k ~= "none" and values[k] then return k end
    end
end

T.test("draft write: no word ever moves a piece", function()
    local _, ns, Draft, AB, k = layoutWorld()
    local G = ns.Grammar
    local before = places(AB)
    local sound = aSound(ns)
    T.truthy(sound, "a sound to play")
    local tried = 0
    local function try(rules, what)
        local ok, why = Draft.Write(k.clap, rules)
        T.truthy(ok, what .. ": " .. tostring(why))
        T.eq(places(AB), before, what .. " leaves every piece where it was")
        tried = tried + 1
    end
    for _, w in ipairs(G.Words(G.Kind(k.clap))) do
        for _, a in ipairs(w.actions) do
            local value = a == "sound" and sound or a == "glow" and GOLD or nil
            try({ lines = { L(w.moment, a, value) } }, w.moment .. " " .. a)
        end
    end
    for _, word in ipairs(G.GROUP) do
        if word == "where" then
            for _, x in ipairs(G.WHERE) do try({ lines = {}, group = { where = x } }, "where " .. x) end
        else
            try({ lines = {}, group = { [word] = true } }, word)
        end
    end
    for _, f in ipairs(G.Kind(k.clap).forms or {}) do try({ lines = {}, forms = { f } }, "form " .. f) end
    for _, x in ipairs(G.SHOWS) do try({ lines = {}, shows = x }, "shows " .. x) end
    try({ lines = {}, shows = "cooldown" }, "nothing")
    T.truthy(tried > 20, "every word tried: " .. tried)
    noErrors()
end)

T.test("draft write: a group word lands on the spell's group, and the note names the others", function()
    local _, _, Draft, AB, k, set = layoutWorld()
    local D = AB.CdmData
    D.SetChainValue(set, k.rend, "target", true)
    local rules = Draft.Rules(k.clap)
    T.deq(rules.group, { target = true }, "it comes in with its group's words")
    rules.group.combat = true
    local ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true)
    T.eq(landed(report), "group:combat", "only the new word")
    set = D.Get(1)
    T.eq(set.pieces[k.clap].parent, k.rend, "still in Rend's group")
    T.eq(set.chains[k.rend].combat, true, "on the group, where Daylight UI's Group tab writes it")
    T.eq(set.chains[k.rend].target, true)
    T.isnil(set.chains[k.clap], "no group of its own")
    T.deq(Draft.Rules(k.wall).group, { combat = true, target = true }, "Shield Wall shares it")
    local shared = Draft.SHARED:format("Rend and Shield Wall")
    T.eq(Draft.GroupNote(k.clap), shared)
    T.eq(#report.notes, 1)
    T.eq(report.notes[1].code, "shared")
    T.eq(report.notes[1].words, shared)
    T.falsy(report.notes[1].blocking, "a note, not a refusal")
    -- A word cleared clears it on the group.
    rules.group.combat = nil
    ok, report = Draft.Write(k.clap, rules)
    T.eq(landed(report), "group:combat")
    T.isnil(D.Get(1).chains[k.rend].combat)
    -- Alone in its group: no note.
    T.isnil(Draft.GroupNote(k.rage))
    ok, report = Draft.Write(k.rage, { lines = {}, group = { mounted = false } })
    T.eq(ok, true)
    T.eq(#report.notes, 0)
    noErrors()
end)

T.test("draft: GroupNote lists three or more with commas", function()
    local _, _, Draft, AB, k, set = layoutWorld()
    local D = AB.CdmData
    D.Hook(set, k.rage, k.wall, "right", "center")
    T.eq(Draft.GroupNote(k.clap), Draft.SHARED:format("Rend, Shield Wall, and Bloodrage"))
    noErrors()
end)

T.test("draft: GroupNames lists every spell in the group, the spell itself included", function()
    local _, _, Draft, AB, k, set = layoutWorld()
    T.eq(table.concat(Draft.GroupNames(k.clap), ", "), "Rend, Thunder Clap, Shield Wall", "Daylight UI's order")
    T.eq(table.concat(Draft.GroupNames(k.rend), ", "), "Rend, Thunder Clap, Shield Wall", "the same from any of them")
    T.eq(table.concat(Draft.GroupNames(k.rage), ", "), "Bloodrage", "alone")
    AB.CdmData.Hook(set, k.rage, k.wall, "right", "center")
    T.eq(table.concat(Draft.GroupNames(k.rage), ", "), "Rend, Thunder Clap, Shield Wall, Bloodrage")
    noErrors()
end)

T.test("draft flags: missing show keeps a game piece on Buff only, through SetSpellValue", function()
    local _, _, Draft, AB, k, set = layoutWorld()
    AB.CdmData.AddPiece(set, k.shout, "icon", 300, 0)
    local ok, report = Draft.Write(k.shout, { lines = { L("missing", "show") } })
    T.eq(ok, true)
    T.eq(landed(report), "track:track,set:missing")
    T.eq(pieceOf(k.shout).track, "buff", "the card's word for a game piece")
    T.eq(pieceOf(k.shout).missing, true)
    T.deq(Draft.Rules(k.shout).lines, { L("missing", "show") })
    noErrors()
end)

T.test("draft flags: missing show keeps Daylight UI's own piece on Buff only, through SetTrack", function()
    local _, ns, Draft, AB = layoutWorld()
    local own = "s" .. RAGE
    local D = AB.CdmData
    D.AddPiece(D.Get(1), own, "icon", 300, 0)
    D.Get(1).pieces[own].hideMissing = true
    -- Bloodrage as a buff with no cooldown of its own, so Buff missing's words fit.
    local B, keep = ns.Bridge, ns.Bridge.Entry
    B.Entry = function(key)
        local e = keep(key)
        if key == own then e = { kind = e and e.kind, aura = true } end
        return e
    end
    local ok, err = pcall(function()
        local done, report = Draft.Write(own, { lines = { L("missing", "show") } })
        T.eq(done, true)
        T.eq(landed(report), "track:track,set:missing,clear:hideMissing")
        T.eq(pieceOf(own).track, "aura", "the card's word for Daylight UI's own piece")
        T.eq(pieceOf(own).missing, true)
        T.isnil(pieceOf(own).hideMissing)
    end)
    B.Entry = keep
    assert(ok, err)
    noErrors()
end)

T.test("draft write: a line the layout holds that doesn't fit the piece is left as it is", function()
    local _, _, Draft, _, k, set = layoutWorld()
    -- Gray out stays in a layout when its piece becomes a bar; Daylight UI's setter
    -- won't take it back on a bar.
    set.pieces[k.rage].desat = "grey"
    local rules, problems = Draft.Rules(k.rage)
    T.deq(rules.lines, { L("cooldown", "gray") })
    T.eq(problems[1].code, "kind", "it doesn't fit a bar")
    rules.lines[#rules.lines + 1] = L("ready", "hide")
    local ok, report = Draft.Write(k.rage, rules)
    T.eq(ok, true, "it doesn't stop the write")
    T.eq(landed(report), "set:onReady")
    T.eq(pieceOf(k.rage).desat, "grey", "left as it is")
    -- Dropping it asks Daylight UI to clear it, which its setter refuses for a bar.
    local before = db()
    local why
    ok, why = Draft.Write(k.rage, { lines = { L("ready", "hide") } })
    T.falsy(ok)
    T.eq(why, "rejected")
    T.eq(db(), before, "nothing written")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- More conditions, step 2: buff extras and What it shows
-- ---------------------------------------------------------------------

T.test("draft write: the sweep while active and its color write live, and read back", function()
    local _, _, Draft, AB, k, set = layoutWorld()
    AB.CdmData.AddPiece(set, k.shout, "icon", 300, 0)
    local ok, report = Draft.Write(k.shout, { lines = { L("up", "nosweep") } })
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "set:noDurationSwipe")
    T.eq(pieceOf(k.shout).noDurationSwipe, true, "the card's Hide while buff is up")
    T.deq(Draft.Rules(k.shout).lines, { L("up", "nosweep") })
    local half = { 1, 0, 0, 0.5 }
    ok, report = Draft.Write(k.shout, { lines = { L("up", "tint", half) } })
    T.eq(landed(report), "clear:noDurationSwipe,set:activeColor")
    T.deq(pieceOf(k.shout).activeColor, half, "the card's Highlight color, alpha kept")
    T.deq(Draft.Rules(k.shout).lines, { L("up", "tint", half) })
    -- Back to the accent: Daylight UI's setter takes no "none".
    local before = dump(DaylightUIDB)
    ok, report = Draft.Write(k.shout, { lines = {} })
    T.eq(ok, true)
    T.eq(#report.changed, 0)
    T.eq(dump(DaylightUIDB), before)
    T.eq(report.notes[1].code, "accent")
    T.eq(report.notes[1].words, "Battle Shout: Daylight UI can't set the sweep back to the accent color, so it stays red.")
    noErrors()
end)

T.test("draft write: flash on a Buff only bar writes show it with it", function()
    local _, _, Draft, AB, k, set = layoutWorld()
    AB.CdmData.AddPiece(set, k.shout, "bar", 300, 0)
    local ok, why, report = Draft.Write(k.shout, { lines = { L("missing", "flash") } })
    T.falsy(ok)
    T.eq(why, "problems", "flash alone isn't offered before Buff missing shows")
    ok, report = Draft.Write(k.shout, { lines = { L("missing", "show"), L("missing", "flash") } })
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "track:track,set:missing,set:inactiveFlash")
    T.eq(pieceOf(k.shout).inactiveFlash, true, "the card's Flash")
    T.deq(Draft.Rules(k.shout).lines, { L("missing", "show"), L("missing", "flash") })
    ok, why, report = Draft.Write(k.shout, { lines = { L("missing", "flash") }, shows = "buff" })
    T.falsy(ok)
    T.eq(report.notes[1].code, "needs")
    T.eq(report.notes[1].words, "Battle Shout: \"While it's not active, flash it.\" needs \"While it's not active, show it.\" too.")
    noErrors()
end)

T.test("draft write: What it shows writes track in each piece's own words", function()
    local _, ns, Draft, AB, k, set = layoutWorld()
    local rules = Draft.Rules(k.clap)
    rules.shows = "both"
    local ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "track:track", "only the pick")
    T.eq(pieceOf(k.clap).track, "both", "a game piece's word")
    T.eq(Draft.Rules(k.clap).shows, "both")
    -- Buff only drops the lines a buff doesn't take; Buff missing's then fit.
    ok, report = Draft.Write(k.clap, { lines = { L("missing", "show") }, shows = "buff" })
    T.eq(ok, true, tostring(report))
    T.eq(pieceOf(k.clap).track, "buff")
    T.eq(pieceOf(k.clap).missing, true)
    local why
    ok, why, report = Draft.Write(k.clap, { lines = { L("missing", "show") }, shows = "cooldown" })
    T.falsy(ok); T.eq(why, "problems", "Buff missing doesn't fit a cooldown")
    -- Daylight UI's own piece takes aura through SetTrack.
    local own = "s" .. RAGE
    AB.CdmData.AddPiece(set, own, "icon", 300, 0)
    T.truthy(ns.Bridge.CanTrack(own))
    ok, report = Draft.Write(own, { lines = {}, shows = "buff" })
    T.eq(ok, true, tostring(report))
    T.eq(pieceOf(own).track, "aura", "Daylight UI's own piece's word")
    T.eq(Draft.Rules(own).shows, "buff")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- More conditions, step 3: look words
-- ---------------------------------------------------------------------

T.test("draft write: the glow style, the cooldown's sweep and the almost-ready color write live", function()
    local _, ns, Draft, AB, k = layoutWorld()
    local rules = Draft.Rules(k.clap)
    T.eq(rules.style, "comet", "the saved style reads as the style word")
    rules.style = "breathe"
    rules.lines[#rules.lines + 1] = L("cooldown", "nosweep")
    local ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "set:noSwipe,set:glowStyle")
    T.eq(pieceOf(k.clap).glowStyle, "breathe")
    T.eq(pieceOf(k.clap).noSwipe, true, "the card's Hide on cooldown")
    -- The global cooldown's sweep only.
    rules = Draft.Rules(k.clap)
    rules.lines[#rules.lines] = L("cooldown", "nogcd")
    ok, report = Draft.Write(k.clap, rules)
    T.eq(landed(report), "clear:noSwipe,set:noGcd")
    -- Almost ready: a look key, through Data.SetLook.
    local cdSize = pieceOf(k.clap).look.cdSize
    rules = Draft.Rules(k.clap)
    rules.lines[#rules.lines + 1] = { moment = "almost", action = "numbers", value = BLUE, at = 5 }
    ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "set:low,set:lowAt,set:lowColor")
    local look = pieceOf(k.clap).look
    T.eq(look.low, true); T.eq(look.lowAt, 5); T.deq(look.lowColor, BLUE)
    T.eq(look.cdSize, cdSize, "its other look keys untouched")
    T.deq(Draft.Rules(k.clap).lines[4], { moment = "almost", action = "numbers", value = BLUE, at = 5 }, "reads back")
    -- Dropping it writes Daylight UI's fallbacks, which read as no line.
    rules = Draft.Rules(k.clap)
    table.remove(rules.lines, 4)
    ok, report = Draft.Write(k.clap, rules)
    T.eq(landed(report), "clear:low,clear:lowAt,clear:lowColor")
    T.eq(#Draft.Rules(k.clap).lines, 3, "gone")
    T.eq(ns.Bridge.PieceLook(k.clap, "low"), false, "the card's toggle reads off")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- More conditions, step 4: the group extra
-- ---------------------------------------------------------------------

T.test("draft write: keep every spell in place writes the group's Slide over off, and nothing moves", function()
    local _, ns, Draft, AB, k = layoutWorld()
    local before = places(AB)
    local rules = Draft.Rules(k.clap)
    rules.group.keep = true
    local ok, report = Draft.Write(k.clap, rules)
    T.eq(ok, true, tostring(report))
    T.eq(landed(report), "group:collapse", "the chain field, from the spell")
    local set = AB.CdmData.Get(1)
    T.eq(set.chains[k.rend].collapse, false, "on the group, where the Group tab writes it")
    T.eq(AB.CdmData.ChainValue(set, k.wall, "collapse"), false, "the whole group's")
    T.eq(places(AB), before, "nothing moved")
    T.deq(Draft.Rules(k.wall).group, { keep = true }, "the others share it")
    T.eq(report.notes[1].code, "shared", "the note names them")
    T.eq(ns.Grammar.GroupWords("keep", true), "keep every spell in place when a buff drops")
    rules.group.keep = nil
    ok, report = Draft.Write(k.clap, rules)
    T.eq(landed(report), "group:collapse")
    T.isnil(AB.CdmData.Get(1).chains[k.rend].collapse, "Slide over back on, Daylight UI's default")
    T.eq(places(AB), before)
    noErrors()
end)

T.test("draft: ColorName names a color in everyday words", function()
    local _, _, Draft = world()
    T.eq(Draft.ColorName(RED), "red")
    T.eq(Draft.ColorName(GOLD), "gold")
    T.eq(Draft.ColorName(BLUE), "blue")
    T.eq(Draft.ColorName({ 0.5, 0.5, 0.5 }), "gray")
    T.eq(Draft.ColorName(nil), "the accent color")
    noErrors()
end)
