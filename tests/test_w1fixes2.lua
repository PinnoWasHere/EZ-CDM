local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Wave 1 fixes, second round (docs/tasks/w1-fixes-2.md):
--   1 words come from the client's spell data: no cooldown words for a spell with
--     no real cooldown, debuff words for an aura on an enemy
--   2 a can't cast gray on top of Daylight UI's own gray: the drawer says so and
--     offers "keep its color while it cools down"

local LHW, SHIELD, FLAME = 8004, 324, 8050

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function line(moment, action, extra)
    local l = { moment = moment, action = action }
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
end

-- A Shaman with a spell placed as an icon: an added spell (Lesser Healing Wave,
-- Lightning Shield) by its tray key, a catalogue spell by its Essential row.
local function shaman(id)
    local w = W.Build("SHAMAN")
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    local key
    local r = w.Row(id)
    if r and r.category == W.ESSENTIAL then
        key = CW.ID(r.spell, r.category)
    else
        stub.knownSpells[id] = true
        stub.spells[id] = stub.spells[id] or { name = "Spell " .. id }
        key = Ed.KeyForID("spell", tostring(id))
    end
    D.AddPiece(D.Ensure(1), key, "icon", 0, 0)
    w.Pass()
    return w, key
end

-- Whole-word "buff" in a phrase.
local function saysBuff(text) return tostring(text):find("%f[%a]buff%f[%A]") ~= nil end

-- ---------------------------------------------------------------------
-- 1. Words from the client's data
-- ---------------------------------------------------------------------

T.test("data: the shipped spell facts name cooldowns and auras from the client's tables", function()
    local spells = W.Links().spells
    T.truthy(type(spells) == "table", "AuraLinks.spells")
    T.eq(spells[LHW], "", "Lesser Healing Wave: no cooldown, no aura")
    T.eq(spells[FLAME], "cd", "Flame Shock: a cooldown (its category's 6 s) and a debuff")
    T.eq(spells[SHIELD], "b", "Lightning Shield: a buff, no cooldown")
    T.eq(spells[122], "cd", "Frost Nova")
    T.eq(spells[20271], "c", "Judgement: its own 10 s")
end)

T.test("data: the facts agree with Daylight UI's own cooldowns and the catalogue's aura targets", function()
    local spells = W.Links().spells
    local DUIns = {}
    assert(loadfile(stub.DUI_ROOT .. "DaylightUI_ActionBars/CdmSpells.lua"))("DaylightUI_ActionBars", DUIns)
    local bad = {}
    for id, f in pairs(DUIns.CdmSpells.FACTS) do
        local v = spells[id]
        if v ~= nil and type(f.cd) == "number" and (f.cd > 0) ~= (v:find("c", 1, true) ~= nil) then
            bad[#bad + 1] = id .. " cd=" .. f.cd .. " facts=" .. v
        end
    end
    table.sort(bad)
    T.eq(table.concat(bad, "; "), "", "Daylight UI's cooldown facts")
    bad = {}
    for _, r in ipairs(CW.Catalogue()) do
        local v = spells[r.spell]
        if v ~= nil and r.aura and r.selfAura and v:find("d", 1, true) and not v:find("b", 1, true) then
            bad[#bad + 1] = r.spell .. " " .. r.name .. " self aura read as a debuff"
        end
    end
    T.eq(table.concat(bad, "; "), "", "the catalogue's own auras on you")
end)

T.test("fix 1: Lesser Healing Wave has no cooldown words, and its fix reads Show it", function()
    local w, key = shaman(LHW)
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.noCooldown, true)
    local note = G.HiddenNote(kind, line("blocked", "gray"))
    T.eq(note and note.fixes[1], "shows")
    T.eq(G.FixText("shows", kind), "Show it")
    for _, s in ipairs(G.SHOWS) do T.falsy(G.ShowsPhrase(s, kind):find("cooldown"), s) end
    noErrors()
end)

T.test("fix 1: a buff with no cooldown (Lightning Shield) has no cooling down words", function()
    local w, key = shaman(SHIELD)
    local G = w.ns.Grammar
    local kind = G.Kind(key, nil, "both")
    T.eq(kind.noCooldown, true)
    T.eq(kind.aura, "buff")
    for _, x in ipairs(G.Words(kind)) do
        T.truthy(x.moment ~= "almost", x.moment)
        if x.moment == "cooldown" then T.eq(table.concat(x.actions, ","), "nosweep,nogcd", "only the sweep") end
    end
    T.eq((G.MomentWords("cooldown", nil, kind)), "While the global cooldown runs")
    T.eq(G.ShowsWords("both", kind), "Show it, and its buff while it's up.")
    T.eq(G.ShowsWords("cooldown", kind), "Show it.")
    noErrors()
end)

T.test("fix 1: Flame Shock reads as a debuff in every word", function()
    local w, key = shaman(FLAME)
    local G = w.ns.Grammar
    T.truthy(w.ns.Draft.Write(key, { lines = { line("blocked", "gray") }, shows = "both" }))
    w.Pass()
    local kind = G.Kind(key)
    T.eq(kind.aura, "debuff")
    T.falsy(kind.noCooldown)
    T.eq(G.ShowsWords("both", kind), "Show its debuff and its cooldown.")
    T.eq(G.ShowsWords("buff", kind), "Show its debuff.")
    local note = G.HiddenNote(kind, line("blocked", "gray"))
    T.eq(note.text, "Hidden while its debuff shows.")
    T.eq(G.FixText("clause", kind), "Add \"and its debuff isn't active\"")
    T.eq(G.Describe(line("blocked", "gray", { clauses = { { cond = "noBuff" } } }), kind),
        "When I can't cast it and its debuff isn't active, turn it gray.")
    noErrors()
end)

T.test("fix 1: the drawer shows Flame Shock's words as a debuff", function()
    local w, key = shaman(FLAME)
    T.truthy(w.ns.Draft.Write(key, { lines = { line("blocked", "gray") }, shows = "both" }))
    w.Pass()
    T.truthy(w.AB.CdmEditor.Open())
    stub.RunTimers()
    w.AB.CdmEditor.Select(key)
    stub.RunTimers()
    local said = {}
    for _, b in ipairs(w.ns.Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and type(b.said) == "string" then said[#said + 1] = b.said end
    end
    local all = table.concat(said, " | ")
    T.truthy(all:find("debuff", 1, true), all)
    T.falsy(saysBuff(all), all)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. Daylight UI's own gray under EZ-CDM's
-- ---------------------------------------------------------------------

-- The game's own item draws Flame Shock. With its debuff on the target and the
-- spell cooling down, the game keeps the icon gray (CooldownViewer.lua: it clears
-- the cooldown's gray only for an aura on you), while EZ-CDM's wash stays off
-- (its line is about the cooldown icon). Once the debuff is gone the wash lights
-- on top of the same gray: the darker gray the owner saw.
local function iconGray(key)
    local item = CW.Item(key)
    local on
    CW.Run(function() on = item:GetIconTexture():IsDesaturated() end)
    return on
end

T.test("fix 2: with its debuff up and cooling down, the gray is the game's, not EZ-CDM's", function()
    local w, key = shaman(FLAME)
    local ns = w.ns
    T.truthy(ns.Draft.Write(key, { lines = { line("blocked", "gray") }, shows = "both" }))
    w.Pass()
    w.Usable(true, false)
    w.EnterCombat()
    local sp = ns.Bridge.SpellOf(key)
    w.Cast(sp)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    w.BuffUp(FLAME, { unit = "target", duration = 12 })
    T.eq(iconGray(key), true, "the game's gray while the debuff shows")
    local v = ns.Conditions.Visible(key, "cantCast:gray")
    T.falsy(v.lit, "EZ-CDM's wash is off")
    T.eq(v.covered, true)
    w.Ready(sp); w.Ready(FLAME)
    T.eq(iconGray(key), false, "full color once the cooldown ends")
    w.BuffDown(FLAME)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    T.eq(iconGray(key), true, "the game's gray")
    T.truthy(ns.Conditions.Visible(key, "cantCast:gray").lit, "and EZ-CDM's wash on top")
    noErrors()
end)

T.test("fix 2: the drawer notes Daylight's own gray and its fix keeps the color", function()
    local w, key = shaman(FLAME)
    local ns, G = w.ns, w.ns.Grammar
    T.truthy(ns.Draft.Write(key, { lines = { line("blocked", "gray") }, shows = "both" }))
    w.Pass()
    local kind = G.Kind(key)
    T.eq(kind.desat, "game")
    local note = G.GrayNote(kind, { line("blocked", "gray") })
    T.eq(note and note.code, "gray")
    T.eq(note.text, G.WORDING.grayDebuff)
    T.isnil(G.GrayNote(kind, { line("blocked", "gray"), line("cooldown", "color") }), "kept in color: no note")
    T.isnil(G.GrayNote(kind, { line("blocked", "glow") }), "no gray line: no note")
    T.truthy(w.AB.CdmEditor.Open())
    stub.RunTimers()
    w.AB.CdmEditor.Select(key)
    stub.RunTimers()
    local block
    for _, b in ipairs(ns.Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b.gray then block = b end
    end
    T.truthy(block, "the note under the line")
    local link
    for _, t in ipairs(block.tokens or {}) do
        if t.piece and t.piece.kind == "add" then link = t end
    end
    link:Click()
    stub.RunTimers()
    local p = w.AB.CdmData.Get(1).pieces[key]
    T.eq(p.desat, "color", "Gray out: Stay colored")
    -- With the debuff up and the spell cooling down, the icon now keeps its color.
    w.Usable(true, false)
    w.EnterCombat()
    local sp = ns.Bridge.SpellOf(key)
    w.Cast(sp)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    w.BuffUp(FLAME, { unit = "target", duration = 12 })
    T.eq(iconGray(key), false, "no gray while the debuff shows")
    w.BuffDown(FLAME)
    T.truthy(ns.Conditions.Visible(key, "cantCast:gray").lit, "EZ-CDM's gray alone once it's gone")
    T.eq(iconGray(key), false, "and no game gray under it")
    noErrors()
end)
