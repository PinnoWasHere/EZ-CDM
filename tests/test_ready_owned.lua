local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- EZ-CDM takes over a piece's ready glow and ready sound (docs/tasks/w1-ready-owned.md):
--   1 "When it's ready, glow" with an "and" clause is EZ-CDM's line: offCooldown (a
--     real cooldown) or totemDown (a totem showing its time) with the clauses. A
--     plain line stays Daylight UI's readyGlow, as before
--   2 while a piece has such a line, Daylight UI's ready glow (sound) is off for that
--     piece and the player's own value is kept, by profile and piece, as gray is
--     (Gray.lua). The last such line gone puts it back
--   3 never Daylight UI's ready glow and EZ-CDM's at once; EZ-CDM draws a kept plain
--     line too, and stands down while Daylight UI lights another glow on the piece
--   4 nothing changes for a save with no such line

local EARTH_SHOCK, SEARING = 8042, 3599

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function line(moment, action, extra)
    local l = { moment = moment, action = action }
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
end

local COMBAT = { { cond = "inCombat" } }
local GLOW = line("ready", "glow")
local GLOW_FIGHT = line("ready", "glow", { clauses = COMBAT })
local SOUND = "dui:quest"

-- A Shaman logged in with spell id placed as an icon (test_w1_ready_totemdown).
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

local function write(w, key, lines)
    local ok, why, report = w.ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes and report.notes[1]
        and report.notes[1].words))
    w.Pass()
end

local function piece(w, key) return w.AB.CdmData.Get(1).pieces[key] end

-- Daylight UI's own ready glow on the piece's item, and EZ-CDM's glow on its holder.
local function daylightGlow(w, key) return w.AB.CdmEffects.GlowShown(CW.Item(key)) == true end
local function ezGlow(w, key) return (w.ns.Conditions.Lit(key) or {}).glow end

local function cardSets(w, key, field, value)
    local D = w.AB.CdmData
    T.truthy(D.SetSpellValue(D.Ensure(1), key, field, value))
    w.AB.CdmEditor.Changed()
    for _ = 1, 3 do stub.RunTimers() end
    w.Pass()
end

-- Every alert Daylight UI's sound list plays, from Daylight UI or EZ-CDM.
local function listen(w)
    local heard = {}
    local keep = w.DUI.Sound.Alert
    w.DUI.Sound.Alert = function(k, ...)
        heard[#heard + 1] = k
        return keep(k, ...)
    end
    return heard
end

local function readyLines(w, key)
    local out = {}
    for _, l in ipairs(w.ns.Draft.Rules(key).lines) do
        if l.moment == "ready" and (l.action == "glow" or l.action == "sound") then out[#out + 1] = l end
    end
    return out
end

-- ---------------------------------------------------------------------
-- 1. The line
-- ---------------------------------------------------------------------

T.test("line: the owner's sentence, When it's ready and I'm in combat, glow", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy(kind.cooldownReady)
    T.eq(G.Describe(GLOW_FIGHT, kind), "When it's ready and I'm in combat, glow.")
    T.truthy(G.TakesClauses(GLOW, kind), "a plain ready glow takes an and")
    local opts = G.Clauses(kind, GLOW, { drawer = true, more = true })
    local has = false
    for _, c in ipairs(opts) do has = has or c == "inCombat" end
    T.truthy(has, "I'm in combat among them")
    local fields, problems = G.Compile({ lines = { GLOW_FIGHT } }, kind)
    T.eq(#problems, 0, problems[1] and problems[1].code)
    T.isnil(fields.readyGlow, "not Daylight UI's line")
    T.deq(fields["ez:offCooldown:glow"], { clauses = { { cond = "inCombat" } } }, "EZ-CDM's offCooldown glow")
    T.eq(G.LineCondition(GLOW_FIGHT, kind), "offCooldown")
    T.isnil(G.LineCondition(GLOW, kind), "a plain line is Daylight UI's")
    fields = G.Compile({ lines = { GLOW } }, kind)
    T.eq(fields.readyGlow, true, "a plain line stays Daylight UI's readyGlow")
    T.isnil(fields["ez:offCooldown:glow"])
    noErrors()
end)

T.test("line: the sound, the colour and the style go with it, and it reads back as written", function()
    local w, key = place(EARTH_SHOCK)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    local styles = w.ns.Bridge.OfferedStyles()
    local style = styles[#styles].key
    local glow = line("ready", "glow", { value = { 1, 0, 0 }, style = style, clauses = COMBAT })
    local sound = line("ready", "sound", { value = SOUND, clauses = COMBAT })
    local said = w.ns.Bridge.SoundChoices()[SOUND]
    T.eq(G.Describe(sound, kind), "When it's ready and I'm in combat, play \"" .. tostring(said) .. "\".")
    local fields, problems = G.Compile({ lines = { glow, sound } }, kind)
    T.eq(#problems, 0, problems[1] and problems[1].code)
    T.deq(fields["ez:offCooldown:glow"], { value = { 1, 0, 0 }, style = style, clauses = { { cond = "inCombat" } } })
    T.deq(fields["ez:offCooldown:sound"], { value = SOUND, clauses = { { cond = "inCombat" } } })
    T.isnil(fields.readySound)
    write(w, key, { GLOW, glow, sound })
    local got = readyLines(w, key)
    T.eq(#got, 3, "the plain line and both EZ-CDM lines")
    T.deq(got[1], GLOW, "the plain line first, Daylight UI's own")
    T.deq(got[2], glow)
    T.deq(got[3], sound)
    noErrors()
end)

T.test("line: a totem's When my totem is down takes it too", function()
    local w, key = place(SEARING)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.truthy(kind.totemTime)
    T.eq(G.Describe(GLOW_FIGHT, kind), "When my totem is down and I'm in combat, glow.")
    local fields, problems = G.Compile({ lines = { GLOW_FIGHT } }, kind)
    T.eq(#problems, 0, problems[1] and problems[1].code)
    T.deq(fields["ez:totemDown:glow"], { clauses = { { cond = "inCombat" } } })
    T.isnil(fields.readyGlow)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. Who owns the ready glow and sound
-- ---------------------------------------------------------------------

T.test("owned: a clause line turns Daylight UI's ready glow off and keeps the player's own", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW })
    T.eq(piece(w, key).readyGlow, true, "the player's plain line")
    write(w, key, { GLOW, GLOW_FIGHT })
    T.falsy(piece(w, key).readyGlow, "off while EZ-CDM owns it")
    T.deq(w.ns.Ready.Record(key), { glow = true }, "the player's own kept")
    local profile = w.ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.readyOwned[profile][key], { glow = true }, "by profile and piece")
    T.eq(#readyLines(w, key), 2, "the drawer still reads the plain line as the player's")
    write(w, key, { GLOW })
    T.eq(piece(w, key).readyGlow, true, "back once the last clause line goes")
    T.isnil(w.ns.Ready.Record(key), "nothing kept")
    noErrors()
end)

T.test("owned: a line edited to take a clause, then to lose it, leaves no glow behind", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW })
    write(w, key, { GLOW_FIGHT })
    T.falsy(piece(w, key).readyGlow)
    T.deq(w.ns.Ready.Record(key), { glow = false }, "the line moved; the player's own is off")
    write(w, key, {})
    T.falsy(piece(w, key).readyGlow, "nothing comes back that the player removed")
    T.isnil(w.ns.Ready.Record(key))
    write(w, key, { GLOW_FIGHT })
    write(w, key, { GLOW })
    T.eq(piece(w, key).readyGlow, true, "the clause dropped: Daylight UI's line again")
    T.isnil(w.ns.Ready.Record(key))
    noErrors()
end)

T.test("owned: the sound alone, and the glow left alone", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW, line("ready", "sound", { value = SOUND }) })
    write(w, key, { GLOW, line("ready", "sound", { value = SOUND }), line("ready", "sound", { value = "dui:done",
        clauses = COMBAT }) })
    T.eq(piece(w, key).readyGlow, true, "the glow stays Daylight UI's")
    T.isnil(piece(w, key).readySound, "the sound is off")
    T.deq(w.ns.Ready.Record(key), { sound = SOUND })
    write(w, key, { GLOW, line("ready", "sound", { value = SOUND }) })
    T.eq(piece(w, key).readySound, SOUND, "the player's sound back")
    noErrors()
end)

T.test("owned: the kept value survives a /reload and still restores", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW, GLOW_FIGHT })
    w.Reload()
    w.Pass()
    T.falsy(piece(w, key).readyGlow)
    T.deq(w.ns.Ready.Record(key), { glow = true })
    write(w, key, { GLOW })
    T.eq(piece(w, key).readyGlow, true)
    noErrors()
end)

T.test("owned: Ready glow turned on in Daylight UI's card becomes the kept value", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW_FIGHT })
    T.truthy(w.AB.CdmEditor.Open()); stub.RunTimers()
    cardSets(w, key, "readyGlow", true)
    T.falsy(piece(w, key).readyGlow, "EZ-CDM keeps it off, so the glows never double")
    T.deq(w.ns.Ready.Record(key), { glow = true }, "the card's pick is kept")
    T.eq(#readyLines(w, key), 2, "and reads as the player's plain line")
    write(w, key, { GLOW })
    T.eq(piece(w, key).readyGlow, true, "the card's pick comes back")
    noErrors()
end)

T.test("owned: rule gone another way, profile switch and copy, piece removed", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW, GLOW_FIGHT })
    T.truthy(w.ns.Conditions.SetRule(1, key, nil))
    w.Pass()
    T.eq(piece(w, key).readyGlow, true, "the rule gone: the player's own back")
    T.isnil(w.ns.Ready.Record(key))
    write(w, key, { GLOW, GLOW_FIGHT })
    local A = w.ns.Bridge.ProfileOf(1)
    local C = w.ns.Bridge.CopyAndAssign(1, A)
    T.truthy(C)
    w.ns.Conditions.Sync(); w.Pass()
    T.isnil(w.ns.Conditions.Rule(key), "EZ-CDM's lines stay with A")
    T.eq(piece(w, key).readyGlow, true, "the copy has the player's own glow")
    T.truthy(w.ns.Bridge.Assign(1, A))
    w.ns.Conditions.Sync(); w.Pass()
    T.falsy(piece(w, key).readyGlow, "A still owned")
    T.deq(w.ns.Ready.Record(key), { glow = true })
    w.AB.CdmData.RemovePiece(w.AB.CdmData.Ensure(1), key)
    w.ns.Conditions.Sync(); w.Pass()
    T.isnil(w.ns.Ready.Record(key), "a removed piece keeps nothing")
    noErrors()
end)

T.test("owned: migration-free, a save with no clause line is never touched", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW, line("ready", "sound", { value = SOUND }), line("ready", "flash") })
    w.Reload()
    w.Pass()
    T.eq(piece(w, key).readyGlow, true)
    T.eq(piece(w, key).readySound, SOUND)
    T.isnil(EZCDMDB.readyOwned, "nothing kept, nothing written")
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.truthy(daylightGlow(w, key), "Daylight UI's own ready glow, as before")
    T.isnil(ezGlow(w, key))
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. What shows
-- ---------------------------------------------------------------------

T.test("shows: When it's ready and I'm in combat, glow lights only in a fight, and only EZ-CDM's", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW_FIGHT })
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.falsy(daylightGlow(w, key), "out of a fight: no Daylight UI glow")
    T.isnil(ezGlow(w, key), "and no EZ-CDM glow")
    w.EnterCombat(); w.Pass()
    T.eq(ezGlow(w, key), "offCooldown:glow", "in a fight: EZ-CDM's")
    T.falsy(daylightGlow(w, key), "never Daylight UI's with it")
    w.Cooldown(sid, 6); w.Pass()
    T.isnil(ezGlow(w, key), "on cooldown: dark")
    w.Ready(sid); w.Pass()
    T.eq(ezGlow(w, key), "offCooldown:glow")
    w.LeaveCombat()
    T.isnil(ezGlow(w, key), "the fight over: dark")
    noErrors()
end)

T.test("shows: a plain line beside a clause line is one glow, drawn by EZ-CDM", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { line("ready", "glow", { value = { 0, 1, 0 } }), GLOW_FIGHT })
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.falsy(daylightGlow(w, key), "Daylight UI's off")
    T.eq(ezGlow(w, key), w.ns.Conditions.KEPT_READY.offCooldown .. ":glow", "the player's plain line, by EZ-CDM")
    local v = w.ns.Conditions.Visible(key, w.ns.Conditions.KEPT_READY.offCooldown .. ":glow")
    T.truthy(v.lit and v.shown, "on show")
    w.EnterCombat(); w.Pass()
    T.eq(ezGlow(w, key), "offCooldown:glow", "in a fight the clause line wins; still one glow")
    T.falsy(daylightGlow(w, key))
    w.Cooldown(sid, 6); w.Pass()
    T.isnil(ezGlow(w, key))
    noErrors()
end)

T.test("shows: EZ-CDM's ready glow draws as Daylight UI's: its colour, the piece's style, no halo", function()
    local w, key = place(EARTH_SHOCK)
    local B, API = w.ns.Bridge, w.DUI.API
    local paced, drawn = 0, {}
    local keepPaced, keepAround = B.PacedGlow, API.GlowAround
    B.PacedGlow = function(...) paced = paced + 1; return keepPaced(...) end
    API.GlowAround = function(f, on, o)
        if on then drawn[#drawn + 1] = o end
        return keepAround(f, on, o)
    end
    w.DUI.DB.General().motion = true
    T.truthy(w.ns.Draft.Write(key, { lines = { line("ready", "glow", { value = { 0, 1, 0 } }), GLOW_FIGHT },
        style = "breathe" }))
    w.Pass()
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.eq(ezGlow(w, key), w.ns.Conditions.KEPT_READY.offCooldown .. ":glow")
    local o = drawn[#drawn]
    T.truthy(o, "drawn with Daylight UI's GlowAround, as its ready glow is")
    T.eq(o and o.style, "breathe", "the piece's style")
    T.deq(o and { o.r, o.g, o.b }, { 0, 1, 0 }, "the player's colour")
    T.eq(paced, 0, "Daylight UI's own breath, not EZ-CDM's halo")
    B.PacedGlow, API.GlowAround = keepPaced, keepAround
    noErrors()
end)

T.test("shows: EZ-CDM's ready glow stands down while Daylight UI lights another glow there", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { line("usable", "glow"), GLOW_FIGHT })
    local sid = w.ns.Bridge.SpellOf(key)
    w.EnterCombat()
    w.Usable(false, true)
    w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    for _ = 1, 3 do stub.RunTimers() end
    T.eq(ezGlow(w, key), "offCooldown:glow", "not castable: no usable glow, EZ-CDM's ready glow")
    T.falsy(daylightGlow(w, key))
    w.Usable(true, false); w.Pass()
    for _ = 1, 3 do stub.RunTimers() end
    T.truthy(daylightGlow(w, key), "castable: Daylight UI's usable glow, which comes first")
    T.isnil(ezGlow(w, key), "and EZ-CDM's ready glow gives way, as Daylight UI's own would")
    noErrors()
end)

T.test("shows: the sound, one per moment, never Daylight UI's and EZ-CDM's at once", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { line("ready", "sound", { value = SOUND }),
        line("ready", "sound", { value = "dui:done", clauses = COMBAT }) })
    local heard = listen(w)
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cast(sid); w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.eq(table.concat(heard, ","), SOUND, "out of a fight: the player's plain sound, once")
    w.Advance(2)
    w.EnterCombat()
    w.Cast(sid); w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.eq(#heard, 2, "in a fight: one sound, not two: " .. table.concat(heard, ","))
    noErrors()
end)

T.test("shows: the kept sound plays with EZ-CDM's own sounds off; the clause line's doesn't", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { line("ready", "sound", { value = SOUND }),
        line("ready", "sound", { value = "dui:done", clauses = COMBAT }) })
    w.ns.Settings.Set("sounds", false)
    local heard = listen(w)
    local sid = w.ns.Bridge.SpellOf(key)
    w.Cast(sid); w.Cooldown(sid, 6); w.Ready(sid); w.Pass()
    T.eq(table.concat(heard, ","), SOUND, "the player's Daylight UI sound is still theirs")
    noErrors()
end)

T.test("drawer: the ready glow line offers and, and reads naturally with no note", function()
    local w, key = place(EARTH_SHOCK)
    write(w, key, { GLOW_FIGHT })
    T.truthy(w.AB.CdmEditor.Open()); stub.RunTimers()
    w.AB.CdmEditor.Select(key); stub.RunTimers()
    local said = {}
    for _, b in ipairs(w.ns.Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and type(b.said) == "string" then said[#said + 1] = b.said end
    end
    local all = table.concat(said, " | ")
    T.truthy(all:find("When it's ready and I'm in combat, glow", 1, true), all)
    T.falsy(all:find("Daylight", 1, true), "no note about who draws it: " .. all)
    noErrors()
end)
