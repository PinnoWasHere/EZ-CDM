local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- EZ-CDM/Looks.lua: the looks every condition's lines may end in (wave 1, effects
-- and looks, docs/tasks/w1-effects.md). One-shot looks fire once as their line turns
-- on, plain lines only; held looks stay while it is on, client lines too. Each is
-- drawn with Daylight UI's own builders on the piece's API.Attach holder, or on a
-- client line's layer.

local SHOUT, REND, CLAP = 6673, 772, 6343
local EXECUTE = 5308
local ESSENTIAL = 0
local GOLD = { 1, 0.8, 0.2 }

local ONCE = { "flash", "pop", "shake", "sparkle", "screen" }
local HELD = { "pulse", "border", "halo", "text", "swap" }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end
local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

local function usable(can, noPower)
    C_Spell.IsSpellUsable = function() return can, noPower end
end

local function gameSaysUsable()
    stub.FireEvent("SPELL_UPDATE_USABLE")
    stub.RunTimers()
end

-- Thunder Clap placed as an icon, logged in. motion: Daylight UI's motion switch.
-- lines go to Thunder Clap.
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

local function holderOf(DUI, ns, key) return DUI.API.Attach(ns.Conditions.FrameOf(key)) end

-- Not usable on, then off.
local function block() usable(false, false); gameSaysUsable() end
local function unblock() usable(true, false); gameSaysUsable() end

-- Daylight UI's shared tween driver run to the end.
local function finishTweens(DUI)
    local d = DUI.Motion.Driver()
    for _ = 1, 200 do
        if d then stub.RunOnUpdate(d, 0.05) end
    end
end

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

T.test("looks: the .toc loads Looks.lua after Overlay.lua and before Grammar", function()
    local _, files = stub.ReadToc(stub.PLUGIN_TOC)
    local at = {}
    for i, f in ipairs(files) do at[f] = i end
    T.truthy(at["Looks.lua"] and at["Looks.lua"] > at["Overlay.lua"], "after the wash and the gray copy")
    T.truthy(at["Looks.lua"] < at["Grammar.lua"], "before Grammar takes the actions")
end)

T.test("looks: ten looks, five once and plain only, five held and alpha-safe", function()
    local _, ns = world()
    local C = ns.Conditions
    local got = {}
    for _, l in ipairs(C.Looks()) do got[#got + 1] = l.action end
    T.eq(table.concat(got, ","), "flash,pop,shake,sparkle,screen,pulse,border,halo,text,swap", "the drawer's order")
    for _, a in ipairs(ONCE) do
        local e = C.Effect(a)
        T.truthy(e and e.edge, a .. " fires once")
        T.falsy(e and e.client, a .. " moves, so no client line takes it")
    end
    for _, a in ipairs(HELD) do
        local e = C.Effect(a)
        T.falsy(e and e.edge, a .. " is held")
        T.truthy(e and e.client, a .. " is alpha only")
        T.eq(type(e and e.shown), "function", a .. " says what it drew (Conditions.Visible)")
    end
    T.eq(C.Effect("text").value, "text")
    T.eq(C.Effect("swap").value, "icon")
    for _, a in ipairs({ "flash", "sparkle", "screen", "pulse", "border", "halo" }) do
        T.eq(C.Effect(a).value, "color", a .. " takes a color")
    end
    noErrors()
end)

T.test("looks: every condition takes them; a client one only the held ones; a clause-only one none", function()
    local _, ns = world()
    local C = ns.Conditions
    for _, c in ipairs(C.List()) do
        for _, l in ipairs(C.Looks()) do
            local has = c.actions[l.action] ~= nil
            if c.clauseOnly then
                T.falsy(has, c.key .. " is a clause only: no " .. l.action)
            elseif c.secrecy == "client" then
                T.eq(has, C.Effect(l.effect).client == true, c.key .. " " .. l.action)
            else
                T.truthy(has, c.key .. " takes " .. l.action)
            end
        end
    end
    T.falsy(C.Fits("targetLow", "flash"), "no flash on a client moment")
    T.truthy(C.Fits("targetLow", "border"), "a border is alpha only")
    noErrors()
end)

T.test("looks: a look's value is cleaned as saved: a color, a few words, an icon", function()
    local _, ns = world()
    local C = ns.Conditions
    T.deq(C.CleanValue("color", { 1, 0.5, 0, 0.3 }), { 1, 0.5, 0 })
    T.isnil(C.CleanValue("color", "red"))
    T.eq(C.CleanValue("text", "  Kick!  "), "Kick!", "trimmed")
    T.eq(C.CleanValue("text", "|cffff0000Red"), "cffff0000Red", "no escape codes")
    T.isnil(C.CleanValue("text", ""), "nothing")
    T.isnil(C.CleanValue("text", string.rep("a", C.TEXT_MAX + 1)), "too long")
    T.eq(C.CleanValue("text", "ÄÖÜ"), "ÄÖÜ", "letters, not bytes")
    T.eq(C.CleanValue("icon", 136048), 136048)
    T.isnil(C.CleanValue("icon", -1))
    T.isnil(C.CleanValue("icon", "|T"), "no escape")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Grammar: words, values, round trips
-- ---------------------------------------------------------------------

T.test("looks grammar: lines compile, read back and say their words", function()
    local _, ns, _, key = world()
    local G, D = ns.Grammar, ns.Draft
    local lines = { L("unusable", "flash", GOLD), L("blocked", "text", "Kick!"), L("short", "swap", 136048),
                    L("unusable", "border") }
    local ok, why = D.Write(key, { lines = lines })
    T.truthy(ok, tostring(why))
    T.deq(ns.Conditions.Rule(key), {
        notUsable = { flash = { value = GOLD }, border = true },
        cantCast = { text = { value = "Kick!" } },
        noMana = { swap = { value = 136048 } },
    })
    local back = {}
    for _, l in ipairs(D.Rules(key).lines) do back[l.moment .. " " .. l.action] = l.value end
    T.deq(back["unusable flash"], GOLD)
    T.eq(back["blocked text"], "Kick!")
    T.eq(back["short swap"], 136048)
    T.eq(G.Describe(L("unusable", "flash", GOLD)), "When it's not usable, flash it in the color you picked.")
    T.eq(G.Describe(L("blocked", "text", "Kick!")), "When I can't cast it, show \"Kick!\" on it.")
    T.eq(G.Describe(L("short", "swap", 136048)), "When I don't have enough power, swap its icon for the icon you picked.")
    T.eq(G.Describe(L("unusable", "halo")), "When it's not usable, light a halo behind it.")
    noErrors()
end)

T.test("looks grammar: words and an icon must be picked; a bad value is refused", function()
    local _, ns = world()
    local G = ns.Grammar
    local function codes(p)
        local out = {}
        for _, x in ipairs(p) do out[#out + 1] = x.code end
        return table.concat(out, ",")
    end
    local _, p = G.Compile({ lines = { L("blocked", "text") } })
    T.eq(codes(p), "blank", "no words yet")
    _, p = G.Compile({ lines = { L("blocked", "swap") } })
    T.eq(codes(p), "blank", "no icon yet")
    _, p = G.Compile({ lines = { L("blocked", "text", string.rep("x", 40)) } })
    T.eq(codes(p), "value", "too many letters")
    _, p = G.Compile({ lines = { L("blocked", "pulse", "red") } })
    T.eq(codes(p), "value", "a color is three numbers")
    local f
    f, p = G.Compile({ lines = { L("blocked", "pulse") } })
    T.eq(codes(p), "")
    T.deq(f["ez:cantCast:pulse"], true, "no color: the accent")
    noErrors()
end)

T.test("looks grammar: a client clause goes only on a line whose look is held", function()
    local w = W.Build("WARRIOR")
    local G = w.ns.Grammar
    local _, p = G.Compile({ lines = { { moment = "targetEnemy", action = "flash",
        clauses = { { cond = "targetLow" } } } } })
    T.eq(p[1] and p[1].code, "secret", "a flash fires once; nothing tells it the secret turned on")
    _, p = G.Compile({ lines = { { moment = "targetEnemy", action = "border",
        clauses = { { cond = "targetLow" } } } } })
    T.eq(#p, 0, "a border is alpha only")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Once, as the line turns on
-- ---------------------------------------------------------------------

T.test("looks flash: Daylight UI's wash, flashed once as the line turns on, in its color", function()
    local DUI, ns, _, key = world({ L("unusable", "flash", GOLD) })
    T.isnil(ns.Looks.Fired(key, "flash"), "castable: nothing")
    block()
    local f = ns.Looks.Fired(key, "flash")
    T.truthy(f, "fired")
    local tex = f.shown
    T.eq(tex:GetParent():GetParent(), holderOf(DUI, ns, key), "on the piece's holder")
    local r, g, b, a = tex:GetVertexColor()
    if tex.__color then r, g, b, a = unpack(tex.__color) end
    T.truthy(tex.__duiFlash, "played by Motion.Flash")
    local at = f.at
    ns.Conditions.Refresh(key)
    T.eq(ns.Looks.Fired(key, "flash").at, at, "still on: no second flash")
    unblock()
    block()
    T.truthy(ns.Looks.Fired(key, "flash"), "on again: fires again")
    noErrors()
end)

T.test("looks once: motion off in Daylight UI keeps every one-shot look away", function()
    local _, ns, _, key = world({ L("unusable", "flash"), L("unusable", "pop"), L("unusable", "shake"),
        L("unusable", "sparkle"), L("unusable", "screen") }, false)
    block()
    for _, a in ipairs(ONCE) do T.isnil(ns.Looks.Fired(key, a), a .. ": nothing with motion off") end
    noErrors()
end)

T.test("looks pop: Daylight UI's ready ping on a copy of the icon, at the ping's own scale and times", function()
    local DUI, ns, AB, key = world({ L("unusable", "pop") })
    local M = DUI.Motion
    local bumps, flashes = {}, {}
    local keepBump, keepFlash = M.Bump, M.Flash
    M.Bump = function(region, from, dur) bumps[#bumps + 1] = { region = region, from = from, dur = dur }; return keepBump(region, from, dur) end
    M.Flash = function(tex, dur) flashes[#flashes + 1] = { tex = tex, dur = dur }; return keepFlash(tex, dur) end
    block()
    M.Bump, M.Flash = keepBump, keepFlash
    T.truthy(ns.Looks.Fired(key, "pop"), "fired")
    local c = ns.Overlay.CopyOn(holderOf(DUI, ns, key), "pop")
    T.truthy(c, "a copy on the holder")
    T.eq(c.tex:IsDesaturated(), false, "in color, unlike the gray")
    T.falsy(c.shade:IsShown(), "no shade")
    -- Ping.Light (DaylightUI_ActionBars/Ping.lua:156): the icon and its lit copy
    -- bumped from Ping.SCALE over NORMAL, the light flashed over SLOW.
    T.eq(#bumps, 2, "two bumps, as the ping's")
    T.eq(bumps[1].region, c.tex, "the copy, standing in for the icon")
    T.eq(bumps[2].region, c.light, "its light")
    for _, b in ipairs(bumps) do
        T.eq(b.from, AB.Ping.SCALE, "from the ping's scale")
        T.eq(b.dur, M.NORMAL, "over NORMAL")
    end
    T.eq(#flashes, 1)
    T.eq(flashes[1].tex, c.light, "the light flashes")
    T.eq(flashes[1].dur, M.SLOW, "over SLOW")
    T.eq(c.light:GetBlendMode(), "ADD", "the icon's own picture added on top, as Ping.Setup's")
    T.eq(select(4, c.light:GetVertexColor()), AB.Ping.FLASH_ALPHA, "at the ping's brightness")
    T.eq(c.light:GetTexture(), c.tex:GetTexture(), "the same picture")
    stub.RunTimers()
    T.eq(c.frame:GetAlpha(), 0, "gone after the flash")
    noErrors()
end)

T.test("looks shake: the copy and its crop sway together on Motion.Tween and come back to rest", function()
    local DUI, ns, _, key = world({ L("unusable", "shake") })
    -- A shaped icon: the copy takes the icon's mask.
    local icon = ns.Bridge.PieceIcon(ns.Conditions.FrameOf(key))
    local mask = icon:GetParent():CreateMaskTexture()
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    block()
    T.truthy(ns.Looks.Fired(key, "shake"), "fired")
    local c = ns.Overlay.CopyOn(holderOf(DUI, ns, key), "shake")
    T.truthy(c, "a copy on the holder")
    T.eq(#c.masks, 1, "the icon's mask copied")
    stub.RunOnUpdate(DUI.Motion.Driver(), 0.05)
    local _, _, _, x = c.tex:GetPoint(1)
    local _, _, _, mx = c.masks[1]:GetPoint(1)
    T.truthy(x ~= 0, "mid-sway")
    T.eq(mx, x, "the crop moves with the picture")
    finishTweens(DUI)
    _, _, _, x = c.tex:GetPoint(1)
    _, _, _, mx = c.masks[1]:GetPoint(1)
    T.eq(x, 0, "at rest where the icon is")
    T.eq(mx, 0, "its crop too")
    noErrors()
end)

T.test("looks sparkle: the twinkle glow for one lap, then out", function()
    local DUI, ns, _, key = world({ L("unusable", "sparkle", GOLD) })
    block()
    local f = ns.Looks.Fired(key, "sparkle")
    T.truthy(f, "fired")
    T.eq(f.shown:GetParent(), holderOf(DUI, ns, key), "its frame on the holder")
    T.eq(ns.Bridge.GlowLap("twinkle"), DUI.Widgets.GLOW_LAP.twinkle, "Daylight UI's lap")
    noErrors()
end)

T.test("looks screen: Daylight UI's vignette over the whole screen, in and out", function()
    local DUI, ns = world({ L("unusable", "screen", GOLD) })
    block()
    local edge = ns.Looks.Edge()
    T.truthy(edge, "the screen edge")
    T.eq(edge:GetParent(), UIParent, "over the screen")
    T.eq(edge.tex:GetTexture(), DUI.API.Media("portrait-vignette.png"), "Daylight UI's vignette art")
    T.falsy(edge:IsMouseEnabled(), "never takes a click")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Held while the line is on
-- ---------------------------------------------------------------------

T.test("looks held: each shows while its line is on and goes with it", function()
    local DUI, ns, _, key = world({ L("unusable", "pulse"), L("blocked", "border", GOLD), L("short", "halo"),
        L("unusable", "text", "Kick!"), L("blocked", "swap", 136048) })
    local C = ns.Conditions
    for _, id in ipairs({ "notUsable:pulse", "cantCast:border", "notUsable:text", "cantCast:swap" }) do
        T.falsy(C.Visible(key, id).lit, id .. ": off while castable")
    end
    block()
    for _, id in ipairs({ "notUsable:pulse", "cantCast:border", "notUsable:text", "cantCast:swap" }) do
        local v = C.Visible(key, id)
        T.truthy(v.lit and v.shown, id .. ": on")
    end
    local holder = holderOf(DUI, ns, key)
    T.eq(ns.Looks.Frame(holder, "text").words:GetText(), "Kick!", "the line's words")
    local swap = ns.Overlay.CopyOn(holder, "swap")
    T.eq(swap.tex:GetTexture(), 136048, "the picked icon")
    T.eq(swap.tex:IsDesaturated(), false)
    T.truthy(ns.Looks.Frame(holder, "border").shell, "a Style.Shell outline")
    unblock()
    for _, id in ipairs({ "notUsable:pulse", "cantCast:border", "notUsable:text", "cantCast:swap" }) do
        T.falsy(C.Visible(key, id).shown, id .. ": gone")
    end
    noErrors()
end)

T.test("looks pulse: Daylight UI's own pulse driver breathes it; still with motion off", function()
    local DUI, ns, AB, key = world({ L("unusable", "pulse") })
    block()
    local f = ns.Looks.Frame(holderOf(DUI, ns, key), "pulse")
    T.truthy(AB.CdmEffects.Flashing(f), "on CdmEffects.Flash's driver")
    unblock()
    T.falsy(AB.CdmEffects.Flashing(f), "off the driver with the line")
    local DUI2, ns2, AB2, key2 = world({ L("unusable", "pulse") }, false)
    block()
    local f2 = ns2.Looks.Frame(holderOf(DUI2, ns2, key2), "pulse")
    T.truthy(f2:IsShown(), "shown")
    T.falsy(AB2.CdmEffects.Flashing(f2), "motion off: still")
    noErrors()
end)

T.test("looks halo: Daylight UI's aura halo art behind the piece", function()
    local DUI, ns, _, key = world({ L("unusable", "halo", GOLD) })
    block()
    local f = ns.Looks.Frame(holderOf(DUI, ns, key), "halo")
    T.eq(f.tex:GetTexture(), DUI.Style.AURA_HALO, "Style.AURA_HALO")
    T.truthy(f:GetFrameLevel() < ns.Conditions.FrameOf(key):GetFrameLevel(), "behind the piece")
    noErrors()
end)

T.test("looks client: a held look hangs under the layer the game drives", function()
    local w = W.Build("WARRIOR")
    local key = CW.ID(EXECUTE, W.ESSENTIAL)
    local D = w.AB.CdmData
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, "icon", 0, 0) end
    w.Pass()
    local ok, why = w.ns.Draft.Write(key, { lines = { { moment = "targetLow", action = "border" },
        { moment = "targetLow", action = "text", value = "Low!" } } })
    T.truthy(ok, tostring(why))
    w.Pass()
    w.NewTarget()
    w.EnterCombat()
    w.Health("target", 0.1, "secret")
    for _, id in ipairs({ "targetLow:border", "targetLow:text" }) do
        local v = w.ns.Conditions.Visible(key, id)
        T.eq(v.alpha, w.ns.Conditions.SECRET, id .. ": the game's secret")
        T.truthy(v.layered, id .. ": under the driven layer")
    end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Cost
-- ---------------------------------------------------------------------

T.test("looks cost: no look runs an OnUpdate of its own", function()
    local DUI, ns, _, key = world({ L("unusable", "pulse"), L("unusable", "flash"), L("unusable", "sparkle"),
        L("unusable", "shake"), L("blocked", "border"), L("blocked", "text", "Hi") })
    block()
    local holder = holderOf(DUI, ns, key)
    for _, name in ipairs({ "pulse", "flash", "border", "text" }) do
        local f = ns.Looks.Frame(holder, name)
        T.isnil(f and f.__scripts and f.__scripts.OnUpdate, name .. ": no OnUpdate")
    end
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

local function wordOf(Drawer, i, kind)
    local b = sentences(Drawer)[i]
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == kind then return t end
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
            end
        end
    end
    return out
end

T.test("looks drawer: the action strip offers the looks in order", function()
    local _, ns, AB, key = world({ L("unusable", "glow") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "action"):Click()
    local keys = " " .. table.concat(strip(Drawer).keys, " ") .. " "
    T.truthy(keys:find(" flash pop shake sparkle screen pulse border halo text swap ", 1, true), keys)
    strip(Drawer).chip.halo:Click()
    T.deq(ns.Conditions.Rule(key), { notUsable = { halo = true } }, "written at once")
    T.eq(sentences(Drawer)[1].said, "When it's not usable, light a halo behind it in the accent color.")
    noErrors()
end)

T.test("looks drawer: words are typed in Daylight UI's box; too many letters write nothing", function()
    local DUI, ns, AB, key = world({ L("unusable", "glow") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "action"):Click()
    strip(Drawer).chip.text:Click()
    T.eq(sentences(Drawer)[1].said, "When it's not usable, show words on it type….")
    wordOf(Drawer, 1, "text"):Click()
    local s = strip(Drawer)
    T.truthy(s.box and s.box.hint, "Daylight UI's own box")
    s.box:SetFocus(); s.box:SetText(string.rep("x", 30)); s.box:ClearFocus()
    T.isnil(ns.Conditions.Rule(key), "too long: nothing written")
    local bad = DUI.API.Colors().BAD
    local r, g, b = strip(Drawer).range:GetTextColor()
    T.deq({ r, g, b }, { bad[1], bad[2], bad[3] }, "its note turns BAD")
    s = strip(Drawer)
    s.box:SetFocus(); s.box:SetText("Kick!"); s.box:ClearFocus()
    T.deq(ns.Conditions.Rule(key), { notUsable = { text = { value = "Kick!" } } }, "written")
    noErrors()
end)

T.test("looks drawer: the icon word opens Daylight UI's icon picker; its pick is written", function()
    local DUI, ns, AB, key = world({ L("unusable", "glow") })
    local asked
    DUI.Widgets.PickIcon = function(spec) asked = spec end
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "action"):Click()
    strip(Drawer).chip.swap:Click()
    wordOf(Drawer, 1, "icon"):Click()
    strip(Drawer).chip.pick:Click()
    T.truthy(asked, "Widgets.PickIcon asked")
    T.eq(type(asked.onPick), "function")
    asked.onPick(136048)
    T.deq(ns.Conditions.Rule(key), { notUsable = { swap = { value = 136048 } } })
    noErrors()
end)

T.test("looks drawer: a one-shot look says so while Daylight UI's motion is off", function()
    local _, ns, AB, key = world({ L("unusable", "flash"), L("unusable", "border") }, false)
    local Drawer = editor(ns, AB, key)
    local notes = {}
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b.motionOff then notes[#notes + 1] = b.motionOff end
    end
    T.eq(#notes, 1, "under the flash line only")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Glow style and color per line (built before this task; checked here)
-- ---------------------------------------------------------------------

T.test("looks glow: an EZ-CDM glow line runs API.GlowAround in its own style and color", function()
    local DUI, ns, _, key = world({ { moment = "unusable", action = "glow", value = GOLD, style = "comet" },
        { moment = "short", action = "glow" } })
    local asked = {}
    local keep = DUI.API.GlowAround
    DUI.API.GlowAround = function(frame, on, opts)
        if on then asked[#asked + 1] = opts end
        return keep(frame, on, opts)
    end
    block()
    DUI.API.GlowAround = keep
    T.eq(asked[1] and asked[1].style, "comet", "the line's own style")
    T.deq(asked[1] and { asked[1].r, asked[1].g, asked[1].b }, GOLD, "the line's own color")
    T.deq(ns.Conditions.Rule(key).notUsable.glow, { value = GOLD, style = "comet" }, "saved per line")
    noErrors()
end)
