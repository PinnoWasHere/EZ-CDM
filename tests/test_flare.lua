local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- The flare look (docs/tasks/w1-flare.md): a line's own Daylight UI Proc Alerts
-- flare around the character, through the public API (1.16). It lands once as its
-- line turns on, with Proc Alerts' sound, and goes as the line turns off, since
-- Daylight UI never hides a plugin's alert. Plain lines only.

local SHOUT, REND, CLAP = 6673, 772, 6343
local SEARING = 3599
local ESSENTIAL = 0

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
local function block() usable(false, false); gameSaysUsable() end
local function unblock() usable(true, false); gameSaysUsable() end

-- Thunder Clap placed as an icon, Proc Alerts loaded. opts.minor: Daylight UI's API
-- minor before EZ-CDM loads; opts.procs = false leaves Proc Alerts out.
local function world(lines, opts)
    opts = opts or {}
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, procs = opts.procs ~= false,
        before = function()
            stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                            target = { name = "Boar", reaction = 2 } })
            CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
            stub.spells[CLAP] = { name = "Thunder Clap" }
        end,
        after = function(D) if opts.minor then D.API.minor = opts.minor end end })
    stub.RunTimers()
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

local function full(ns, key, line) return "EZ-CDM:" .. ns.Looks.FlareKey(key, line) end
local function flareOf(key) return stub.procs.Flares.live[key] end

-- Daylight UI's alert sounds as played, by key.
local function sounds(DUI)
    local got = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(k, ...) got[#got + 1] = k; return keep(k, ...) end
    return got
end

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

T.test("flare: a one-shot look that also goes, plain lines only, after the screen edge", function()
    local _, ns = world()
    local C = ns.Conditions
    local got = {}
    for _, l in ipairs(C.Looks()) do got[#got + 1] = l.action end
    T.eq(table.concat(got, ","), "flash,sparkle,screen,flare,pulse,border,halo,text,swap,fill", "the drawer's order")
    local e = C.Effect("flare")
    T.truthy(e.edge and e.hides, "lands once, goes with its line")
    T.falsy(e.client, "never on a client line")
    T.eq(e.value, "flare")
    T.truthy(C.Fits("notUsable", "flare"), "a plain moment takes it")
    T.falsy(C.Fits("targetLow", "flare"), "a client moment doesn't")
    noErrors()
end)

T.test("flare: hidden on a Daylight UI before Proc Alerts (API 1.15), with no error", function()
    local _, ns, _, key = world(nil, { minor = 15 })
    local C = ns.Conditions
    T.isnil(C.Effect("flare"), "no flare effect")
    for _, l in ipairs(C.Looks()) do T.truthy(l.action ~= "flare", "not offered") end
    T.isnil(C.Get("notUsable").actions.flare)
    T.isnil(C.CleanValue("flare", { design = "sun" }), "no flare value kind")
    -- A rule saved on a newer Daylight UI reads without its flare line.
    C.Rule("none")
    EZCDMDB.conditions[ns.Bridge.ProfileOf()] = { [key] = { notUsable = { flare = true, flash = true } } }
    T.deq(C.Rule(key), { notUsable = { flash = true } })
    noErrors()
end)

T.test("flare: its value keeps a known design, animation and sound only", function()
    local _, ns = world()
    local C = ns.Conditions
    T.deq(C.CleanValue("flare", { design = "crown", anim = "flash", sound = "file:568016", x = 1 }),
        { design = "crown", anim = "flash", sound = "file:568016" })
    T.deq(C.CleanValue("flare", { sound = "none" }), { sound = "none" }, "no sound")
    T.isnil(C.CleanValue("flare", {}), "all Proc Alerts' own")
    T.isnil(C.CleanValue("flare", { design = "nope" }), "not one of the twelve")
    T.isnil(C.CleanValue("flare", { anim = "spin" }), "not one of the six")
    T.isnil(C.CleanValue("flare", { sound = "head:own" }), "a heading is no sound")
    T.isnil(C.CleanValue("flare", { sound = 568016 }), "a key of Daylight UI's list, never a bare id")
    T.eq(#ns.Looks.FLARE_DESIGNS, 12)
    T.eq(#ns.Looks.FLARE_ANIMS, 6)
    T.eq(ns.Looks.FLARE_ANIMS[1], "strike", "Daylight UI 2.4.1's Strike first, in its order")
    T.deq(C.CleanValue("flare", { anim = "strike" }), { anim = "strike" })
    for _, d in ipairs(ns.Looks.FLARE_DESIGNS) do T.truthy(stub.procs.Data.DESIGNS[d], d .. " is Daylight UI's") end
    for _, a in ipairs(ns.Looks.FLARE_ANIMS) do T.truthy(stub.procs.Data.ANIMS[a], a .. " is Daylight UI's") end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Showing and going
-- ---------------------------------------------------------------------

T.test("flare: lands as its line turns on, in its picks, and goes as it turns off", function()
    local DUI, ns, _, key = world({ L("unusable", "flare", { design = "crown", anim = "flash", sound = "file:568016" }) })
    local k = full(ns, key, "notUsable:flare")
    local played = sounds(DUI)
    T.isnil(flareOf(k), "castable: nothing")
    block()
    local f = flareOf(k)
    T.truthy(f, "up")
    T.eq(f.design, "crown")
    T.eq(f.anim, "flash")
    T.deq(played, { "file:568016" }, "its sound, once")
    T.truthy(DUI.API.ProcState(k), "others see it as EZ-CDM's")
    T.truthy(ns.Conditions.Visible(key, "notUsable:flare").shown, "Visible finds it")
    ns.Conditions.Refresh(key)
    T.eq(#played, 1, "still on: no second sound")
    unblock()
    T.isnil(flareOf(k), "the line turned off: gone")
    block()
    T.truthy(flareOf(k), "on again: back")
    T.eq(#played, 2, "and its sound again")
    noErrors()
end)

T.test("flare: Proc Alerts' own look and sound with nothing picked; no sound picked plays none", function()
    local DUI, ns, _, key = world({ L("unusable", "flare"), L("blocked", "flare", { sound = "none" }) })
    local played = sounds(DUI)
    block()
    local a, b = flareOf(full(ns, key, "notUsable:flare")), flareOf(full(ns, key, "cantCast:flare"))
    T.truthy(a and b, "one alert per line")
    T.eq(a.design, "sun", "AddProcAlert's default")
    T.eq(a.anim, "pulse")
    T.eq(#played, 1, "only the line with Proc Alerts' sound")
    T.truthy(a.lane ~= b.lane or a.spot ~= b.spot, "Daylight UI lays them apart")
    noErrors()
end)

T.test("flare: goes when its line is removed or its piece leaves", function()
    local _, ns, AB, key = world({ L("unusable", "flare"), L("unusable", "flash") })
    local k = full(ns, key, "notUsable:flare")
    block()
    T.truthy(flareOf(k))
    local ok = ns.Draft.Write(key, { lines = { L("unusable", "flash") } })
    T.truthy(ok)
    pass(AB)
    T.isnil(flareOf(k), "its line removed: gone")
    T.truthy(ns.Draft.Write(key, { lines = { L("unusable", "flare") } }))
    pass(AB)
    unblock(); block()
    T.truthy(flareOf(k), "back")
    AB.CdmData.RemovePiece(AB.CdmData.Ensure(1), key)
    pass(AB)
    T.isnil(flareOf(k), "the piece left: gone")
    noErrors()
end)

T.test("flare: Proc Alerts off shows nothing and errs nothing; back on, the next turn lands", function()
    local DUI, ns, _, key = world({ L("unusable", "flare") })
    local k = full(ns, key, "notUsable:flare")
    DUI:Set("Procs", "enabled", false)
    stub.RunTimers()
    block()
    T.isnil(flareOf(k), "off: nothing")
    unblock()
    DUI:Set("Procs", "enabled", true)
    stub.RunTimers()
    block()
    T.truthy(flareOf(k), "on again: it lands")
    noErrors()
end)

T.test("flare: a Daylight UI with Proc Alerts not loaded draws nothing and errs nothing", function()
    local _, ns, _, key = world({ L("unusable", "flare") }, { procs = false })
    block()
    T.isnil(ns.Looks.Fired(key, "flare"))
    noErrors()
end)

T.test("flare: Daylight UI's motion off still shows it, still", function()
    local DUI, ns, _, key = world({ L("unusable", "flare", { anim = "pulse" }) })
    DUI.DB.General().motion = false
    block()
    T.truthy(flareOf(full(ns, key, "notUsable:flare")), "Daylight UI draws it still")
    noErrors()
end)

T.test("flare: a client clause is refused on a flare line", function()
    local w = W.Build("WARRIOR")
    local _, p = w.ns.Grammar.Compile({ lines = { { moment = "targetEnemy", action = "flare",
        clauses = { { cond = "targetLow" } } } } })
    T.eq(p[1] and p[1].code, "secret", "nothing tells it the secret turned on")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Time left
-- ---------------------------------------------------------------------

T.test("flare: a standing totem's time goes with it when plain, and stays out when secret", function()
    local w = W.Build("SHAMAN", { procs = true })
    local D = w.AB.CdmData
    local r = w.Row(SEARING)
    local key = CW.ID(r.spell, r.category)
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, "icon", 0, 0) end
    w.Pass()
    local ok, why = w.ns.Draft.Write(key, { lines = { { moment = "cooldown", action = "flare" } } })
    T.truthy(ok, tostring(why))
    w.Pass()
    T.deq(w.ns.Conditions.Rule(key), { totemUp = { flare = true } }, "the totem moment's flare")
    local seen = {}
    local me = w.DUI.API.For("EZ-CDM")
    local keep = me.ShowProcAlert
    me.ShowProcAlert = function(k, info) seen[#seen + 1] = info; return keep(k, info) end
    local slot = w.AB.CdmCustom.SlotOf(SEARING)
    -- The client's own duration object: plain out of a fight.
    local function stand(secret)
        local d = C_DurationUtil.CreateDuration()
        if secret then d:SetTimeSpan(stub.Secret(GetTime() - 5), stub.Secret(GetTime() + 55))
        else d:SetTimeSpan(GetTime() - 5, GetTime() + 55) end
        stub.totems[slot] = { spell = SEARING, duration = d }
        w.Cast(SEARING)
        stub.FireEvent("PLAYER_TOTEM_UPDATE", slot)
        w.Pass()
    end
    stand(false)
    T.truthy(#seen >= 1, "shown")
    local info = seen[#seen]
    T.eq(info.dur, 60, "its length")
    T.truthy(info.left and info.left > 54 and info.left <= 55, "its seconds left")
    w.Totem(slot, nil)
    w.Pass()
    local n = #seen
    stand(true)
    T.truthy(#seen > n, "shown again")
    T.isnil(seen[#seen].left, "secret: no time")
    T.isnil(seen[#seen].dur)
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
        if b:IsShown() and b.tokens and b.choices then
            for _, t in ipairs(b.tokens) do
                out.keys[#out.keys + 1] = tostring(t.piece.key)
                out.chip[t.piece.key] = t
            end
        end
    end
    return out
end

local function notes(Drawer, field)
    local n = 0
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and b[field] then n = n + 1 end
    end
    return n
end

T.test("flare drawer: picked as an action, it says Proc Alerts' own picks in words", function()
    local _, ns, AB, key = world({ L("unusable", "glow") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "action"):Click()
    local keys = " " .. table.concat(strip(Drawer).keys, " ") .. " "
    T.truthy(keys:find(" screen flare pulse ", 1, true), keys)
    strip(Drawer).chip.flare:Click()
    T.deq(ns.Conditions.Rule(key), { notUsable = { flare = true } }, "written at once, nothing picked")
    T.eq(sentences(Drawer)[1].said, "When it's not usable, flare around me (Sunrise, Pulse, Proc Alerts' sound).")
    noErrors()
end)

T.test("flare drawer: the twelve designs, the six animations and the sounds, each written as picked", function()
    local DUI, ns, AB, key = world({ L("unusable", "flare") })
    local Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "design"):Click()
    T.eq(table.concat(strip(Drawer).keys, " "), table.concat(ns.Looks.FLARE_DESIGNS, " "), "the twelve, in Daylight UI's order")
    strip(Drawer).chip.crown:Click()
    T.deq(ns.Conditions.Rule(key), { notUsable = { flare = { value = { design = "crown" } } } })
    wordOf(Drawer, 1, "anim"):Click()
    T.eq(table.concat(strip(Drawer).keys, " "), "strike breathe pulse impact flash still")
    strip(Drawer).chip.impact:Click()
    wordOf(Drawer, 1, "flareSound"):Click()
    local s = strip(Drawer)
    T.eq(s.keys[1], "procs", "Proc Alerts' own sound first")
    T.truthy(s.chip.none, "no sound is a pick")
    local values = DUI.Sound.AlertChoices()
    local any
    for k in pairs(s.chip) do if tostring(k):find("^file:") then any = k end end
    T.truthy(any and values[any], "Daylight UI's alert list")
    s.chip.none:Click()
    T.deq(ns.Conditions.Rule(key), { notUsable = { flare = { value = { design = "crown", anim = "impact", sound = "none" } } } })
    T.eq(sentences(Drawer)[1].said, "When it's not usable, flare around me (Crown, Impact, None).")
    -- Back to Proc Alerts' own: left out of the value.
    wordOf(Drawer, 1, "design"):Click()
    strip(Drawer).chip.sun:Click()
    wordOf(Drawer, 1, "anim"):Click()
    strip(Drawer).chip.pulse:Click()
    wordOf(Drawer, 1, "flareSound"):Click()
    strip(Drawer).chip["procs"]:Click()
    T.deq(ns.Conditions.Rule(key), { notUsable = { flare = true } }, "all Proc Alerts' own again")
    noErrors()
end)

T.test("flare drawer: Strike is offered only where Daylight UI's Proc Alerts has it", function()
    local _, ns, AB, key = world({ L("unusable", "flare", { anim = "strike" }) })
    local Drawer = editor(ns, AB, key)
    T.eq(sentences(Drawer)[1].said, "When it's not usable, flare around me (Sunrise, Strike, Proc Alerts' sound).")
    wordOf(Drawer, 1, "anim"):Click()
    T.eq(strip(Drawer).keys[1], "strike")
    AB.CdmEditor.Close(); stub.RunTimers()
    -- An older Proc Alerts: no Strike in its list.
    local strike = stub.procs.Data.ANIMS.strike
    stub.procs.Data.ANIMS.strike = nil
    Drawer = editor(ns, AB, key)
    wordOf(Drawer, 1, "anim"):Click()
    T.eq(table.concat(strip(Drawer).keys, " "), "breathe pulse impact flash still", "not offered")
    T.eq(sentences(Drawer)[1].said, "When it's not usable, flare around me (Sunrise, Strike, Proc Alerts' sound).",
        "a saved Strike still reads as saved")
    stub.procs.Data.ANIMS.strike = strike
    noErrors()
end)

T.test("flare: Strike with Proc Alerts unread follows the Daylight UI version", function()
    local _, ns = world()
    local B = ns.Bridge
    local keep = C_AddOns.GetAddOnMetadata
    local version = "2.4.1"
    C_AddOns.GetAddOnMetadata = function(name, field)
        if name == "DaylightUI" and field == "Version" then return version end
        return keep(name, field)
    end
    local resolve = B.Resolve
    B.Resolve = function(path)
        if path == "Procs.Data.ANIMS" then return nil end
        return resolve(path)
    end
    T.truthy(B.FlareAnimFits("strike"), "2.4.1 has it")
    T.truthy(B.FlareAnimFits("pulse"), "an older animation always fits")
    version = "2.4.0"
    T.falsy(B.FlareAnimFits("strike"), "2.4.0 doesn't")
    version = "2.10.0"
    T.truthy(B.FlareAnimFits("strike"), "numbers compare as numbers")
    B.Resolve, C_AddOns.GetAddOnMetadata = resolve, keep
    noErrors()
end)

T.test("flare: a saved Strike on a Proc Alerts without it lands as the default animation", function()
    local _, ns, _, key = world({ L("unusable", "flare", { design = "crown", anim = "strike" }) })
    local strike = stub.procs.Data.ANIMS.strike
    stub.procs.Data.ANIMS.strike = nil
    block()
    local f = flareOf(full(ns, key, "notUsable:flare"))
    T.truthy(f, "up anyway")
    T.eq(f.design, "crown", "its design kept")
    T.eq(f.anim, ns.Looks.FLARE_ANIM, "Proc Alerts' default animation")
    T.deq(ns.Conditions.Rule(key), { notUsable = { flare = { value = { design = "crown", anim = "strike" } } } },
        "the saved pick stays for a newer Daylight UI")
    stub.procs.Data.ANIMS.strike = strike
    noErrors()
end)

T.test("flare drawer: a note under a flare line while Proc Alerts is off, none while it's on", function()
    local DUI, ns, AB, key = world({ L("unusable", "flare"), L("unusable", "border") })
    local Drawer = editor(ns, AB, key)
    T.eq(notes(Drawer, "procAlertsOff"), 0, "on: no note")
    AB.CdmEditor.Close(); stub.RunTimers()
    DUI:Set("Procs", "enabled", false)
    stub.RunTimers()
    Drawer = editor(ns, AB, key)
    T.eq(notes(Drawer, "procAlertsOff"), 1, "off: under the flare line only")
    noErrors()
end)

T.test("flare drawer: Daylight UI's motion off notes the flash, never the flare", function()
    local DUI, ns, AB, key = world({ L("unusable", "flare"), L("unusable", "flash") })
    DUI.DB.General().motion = false
    local Drawer = editor(ns, AB, key)
    T.eq(notes(Drawer, "motionOff"), 1, "the flash only")
    T.eq(notes(Drawer, "procAlertsOff"), 0)
    noErrors()
end)
