local stub = require("stub")
local CW = require("cdmworld")

-- EZ-CDM/Effects.lua: "While it's active, glow" built inside the client's aura
-- buttons of Daylight UI's aura icon holder, so it shows in a fight, against
-- Daylight UI's real Cooldown Manager and the game's own viewers (cdmworld, a
-- shaman with Improved Stormstrike).

-- Improved Stormstrike: the talent, its buff, and its row in Tracked Buffs.
local STORMBUFF, STORMBUFF_AURA = 1223031, 1238931
local BUFFS = 2
local RED, BLUE = { 1, 0, 0 }, { 0.2, 0.4, 1 }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
    T.eq(stub.initSecretErrors, 0, "no test on a secret inside initializeFrame")
end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end

-- A shaman with Improved Stormstrike placed as an icon. opts:
--   holder   the game's buff viewers hidden, so Daylight UI's aura icon holder draws it
--   rule     EZ-CDM's up glow saved for it before the holder is made (as after a /reload)
--   combat   the holder is made in a fight
--   seen     fn(ns) right after EZ-CDM loads, before login
--   saved    EZCDMDB as the game loads it, before EZ-CDM's files run
local function procWorld(opts)
    opts = opts or {}
    stub.neverSecretAuras = {}
    local slide
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        if opts.saved then EZCDMDB = opts.saved end
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = STORMBUFF, known = { STORMBUFF }, showAll = true })
        stub.spells[STORMBUFF] = { name = "Improved Stormstrike" }
        -- The game's answers on Forever: the talent is passive and its buff is no
        -- spell of yours, so you never cast it (Grammar.Casts).
        C_Spell.IsSpellPassive = function(id) return id == STORMBUFF end
        _G.IsPlayerSpell = function(id) return id ~= STORMBUFF_AURA end
    end, after = function() slide = stub.actionbars.CdmEffects.MakeSlide end })
    if opts.seen then opts.seen(ns, slide) end
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    local AB = stub.actionbars
    local key = CW.ID(STORMBUFF, BUFFS)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    if opts.rule then
        local profile = ns.Bridge.SavedProfile(1)
        EZCDMDB = EZCDMDB or {}
        EZCDMDB.upGlow = { [profile] = { [key] = opts.rule } }
    end
    if opts.combat then stub.EnterCombat() end
    if opts.holder then
        CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    end
    return DUI, ns, AB, key
end

-- The holder's client buttons.
local function buttons(AB, key)
    local h = AB.CdmAuras.Frame(key)
    return h and h.buttons or {}
end

-- How many of btn's shown animations are ring r's loop.
local function ringsIn(btn, r)
    local n = 0
    for _, a in ipairs(btn.__shownAnims or {}) do
        if r and a == r.anim then n = n + 1 end
    end
    return n
end

local function pieceOf(AB, key) return AB.CdmData.Get(1).pieces[key] end

-- ---------------------------------------------------------------------
-- Step 1: load order and the hook
-- ---------------------------------------------------------------------

T.test("effects: the hook is in place before Daylight UI makes any holder button", function()
    local ok
    local _, ns, AB, key = procWorld({ holder = true, seen = function(ns, slide)
        T.truthy(ns.Effects.hooked, "hooked as EZ-CDM loads")
        T.truthy(slide ~= stub.actionbars.CdmEffects.MakeSlide, "MakeSlide is hooked before login")
        T.eq(ns.Effects.Seen(), 0, "no button made yet")
        ok = true
    end })
    T.truthy(ok, "checked before login")
    T.eq(AB.CdmRows.DrawnBy(key), "aura icon", "Daylight UI's aura icon holder draws it")
    local list = buttons(AB, key)
    T.truthy(#list > 0, "the client made its buttons")
    T.eq(ns.Effects.Seen(), #list, "once per button")
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.eq(ns.Effects.Seen(), #list, "a later pass makes none again")
    noErrors()
end)

T.test("effects: the .toc loads Daylight UI's action bars first, and Effects before Grammar", function()
    local meta, files = stub.ReadToc(stub.PLUGIN_TOC)
    T.eq(meta.OptionalDeps, "DaylightUI_ActionBars", "the holders' module loads before EZ-CDM")
    T.eq(meta.Dependencies, "DaylightUI", "the only hard dependency stays Daylight UI")
    local at = {}
    for i, f in ipairs(files) do at[f] = i end
    T.truthy(at["Effects.lua"] and at["Effects.lua"] > at["Bridge.lua"] and at["Effects.lua"] < at["Grammar.lua"],
        "after the Bridge and before Grammar and Draft, which read it")
end)

T.test("effects: an aura bar holder is skipped", function()
    local _, ns, AB, key = procWorld({ rule = RED })
    local D = AB.CdmData
    D.SetSpellValue(D.Ensure(1), key, "shape", "bar")
    pieceOf(AB, key).shape = "bar"
    CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.eq(AB.CdmRows.DrawnBy(key), "aura bar")
    T.isnil(AB.CdmAuras.Frame(key), "no icon holder")
    T.eq(ns.Effects.Seen(), 0, "the bar's buttons never reach EZ-CDM")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 2: the ring in the button
-- ---------------------------------------------------------------------

T.test("effects: a holder piece with the rule gets Daylight UI's ring in each button, handed over once", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local list = buttons(AB, key)
    T.truthy(#list > 0)
    for i, btn in ipairs(list) do
        local r = ns.Effects.Ring(btn)
        T.truthy(r, "button " .. i .. ": a ring")
        T.eq(r.frame:GetParent(), btn, "inside the client's button")
        T.eq(ringsIn(btn, r), 1, "button " .. i .. ": handed over exactly once")
        T.eq(#btn.__shownAnims, 2, "with Daylight UI's own slide")
        local cr, cg, cb = r.tex:GetVertexColor()
        T.deq({ cr, cg, cb }, RED, "in the rule's color")
        T.truthy(r.frame:IsShown(), "shown whenever the button is")
        T.eq(r.frame:GetAlpha(), 1)
        T.isnil(AB.CdmEffects.GlowFrame(btn), "Daylight UI's own SetGlow never ran on it")
    end
    T.truthy(ns.Effects.Lit(key))
    T.falsy(ns.Effects.Pending(key))
    T.isnil(AB.CdmEffects.glowDriver.__scripts.OnUpdate, "no per-frame driver")
    noErrors()
end)

T.test("effects: in a fight the client shows the ring with the buff, and no EZ-CDM code runs", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local btn = buttons(AB, key)[1]
    local r = ns.Effects.Ring(btn)
    stub.EnterCombat()
    local seen = ns.Effects.Seen()
    -- The proc lands and drops twice; the client plays and stops the loop.
    for _ = 1, 2 do
        stub.AuraAssign(btn, true)
        T.truthy(r.anim:IsPlaying(), "the ring turns while the buff is up")
        T.truthy(btn:IsVisible() and r.tex:IsVisible(), "shown with the button")
        stub.AuraAssign(btn, false)
        T.falsy(r.anim:IsPlaying(), "stopped as it drops")
        T.falsy(btn:IsShown(), "hidden with the button")
    end
    T.eq(ns.Effects.Seen(), seen, "no button made in the fight")
    stub.LeaveCombat()
    noErrors()
end)

T.test("effects: a game-drawn piece gets no ring; its glow stays Daylight UI's", function()
    local _, ns, AB, key = procWorld()
    T.eq(AB.CdmRows.DrawnBy(key), "game")
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    T.eq(pieceOf(AB, key).upGlow, true, "Daylight UI's upGlow")
    T.isnil(ns.Effects.Get(key), "no rule of EZ-CDM's")
    T.eq(ns.Effects.Seen(), 0, "no holder button")
    T.falsy(ns.Effects.Lit(key))
    T.falsy(ns.Effects.Pending(key))
    noErrors()
end)

T.test("effects: removing the rule takes the ring off and out of the button", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local list = buttons(AB, key)
    local was = {}
    for i, btn in ipairs(list) do was[i] = ns.Effects.Ring(btn) end
    T.truthy(ns.Draft.Write(key, { lines = {} }))
    T.isnil(ns.Effects.Get(key))
    for i, btn in ipairs(list) do
        local r = was[i]
        T.eq(ringsIn(btn, r), 0, "button " .. i .. ": no longer the client's to play")
        T.falsy(r.frame:IsShown(), "button " .. i .. ": hidden")
        T.falsy(r.anim:IsPlaying(), "stopped")
        T.isnil(ns.Effects.Ring(btn))
    end
    -- The next proc shows the button and nothing else.
    stub.EnterCombat()
    stub.AuraAssign(list[1], true)
    T.falsy(was[1].tex:IsVisible(), "no glow on the next proc")
    T.falsy(was[1].anim:IsPlaying())
    stub.LeaveCombat()
    T.falsy(ns.Effects.Lit(key))
    noErrors()
end)

T.test("effects: a rule gone in a fight comes off once the fight ends", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local btn = buttons(AB, key)[1]
    local r = ns.Effects.Ring(btn)
    stub.EnterCombat()
    EZCDMDB.upGlow = {}
    ns.Effects.Sync()
    T.eq(ringsIn(btn, r), 1, "left alone while the button is locked")
    stub.LeaveCombat()
    stub.RunTimers()
    T.eq(ringsIn(btn, r), 0, "off after the fight")
    T.falsy(r.frame:IsShown())
    noErrors()
end)

T.test("effects: a holder made in a fight gets its ring once the fight ends", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED, combat = true })
    local list = buttons(AB, key)
    T.truthy(#list > 0, "the client made its buttons in the fight")
    for _, btn in ipairs(list) do T.isnil(ns.Effects.Ring(btn), "no ring on a button that locks") end
    stub.LeaveCombat()
    stub.RunTimers()
    for i, btn in ipairs(list) do
        local r = ns.Effects.Ring(btn)
        T.truthy(r, "button " .. i .. ": a ring after the fight")
        T.eq(ringsIn(btn, r), 1, "button " .. i .. ": handed over once")
    end
    T.falsy(ns.Effects.Pending(key), "nothing waits for a /reload")
    noErrors()
end)

T.test("effects: a rule set after the holder is made lights at once, out of a fight", function()
    local _, ns, AB, key = procWorld({ holder = true })
    local list = buttons(AB, key)
    -- The proc is up already: the client played no shown moment for the new ring.
    stub.AuraAssign(list[1], true)
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    T.deq(ns.Effects.Get(key), RED)
    for i, btn in ipairs(list) do
        local r = ns.Effects.Ring(btn)
        T.truthy(r, "button " .. i .. ": a ring")
        T.eq(r.frame:GetParent(), btn, "inside the client's button")
        T.eq(ringsIn(btn, r), 1, "button " .. i .. ": handed over once")
        local cr, cg, cb = r.tex:GetVertexColor()
        T.deq({ cr, cg, cb }, RED)
    end
    local up = ns.Effects.Ring(list[1])
    T.truthy(up.anim:IsPlaying() and up.tex:IsVisible(), "the ring turns on the buff that is up now")
    T.truthy(ns.Effects.Lit(key))
    T.falsy(ns.Effects.Pending(key), "nothing waits for a /reload")
    -- The client plays it with the next proc, in a fight too.
    stub.AuraAssign(list[1], false)
    stub.EnterCombat()
    stub.AuraAssign(list[1], true)
    T.truthy(up.anim:IsPlaying(), "the next proc in a fight")
    stub.LeaveCombat()
    -- Written again, nothing is handed twice.
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    for _, btn in ipairs(list) do T.eq(ringsIn(btn, ns.Effects.Ring(btn)), 1) end
    noErrors()
end)

T.test("effects: a new color repaints the ring in place, with nothing handed again", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local list = buttons(AB, key)
    local was, count = {}, {}
    for i, btn in ipairs(list) do was[i], count[i] = ns.Effects.Ring(btn), #btn.__shownAnims end
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", BLUE) } }))
    for i, btn in ipairs(list) do
        local r = ns.Effects.Ring(btn)
        T.eq(r, was[i], "button " .. i .. ": the same ring")
        T.eq(#btn.__shownAnims, count[i], "button " .. i .. ": nothing new handed over")
        local cr, cg, cb = r.tex:GetVertexColor()
        T.deq({ cr, cg, cb }, BLUE, "button " .. i .. ": the new color")
    end
    local _, color = ns.Effects.Lit(key)
    T.deq(color, BLUE)
    T.falsy(ns.Effects.Pending(key), "nothing waits for a /reload")
    -- Back to the accent: Daylight UI's own paint.
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow") } }))
    local _, accent = ns.Effects.Lit(key)
    T.eq(accent, true)
    T.falsy(ns.Effects.Pending(key))
    noErrors()
end)

T.test("effects: a rule changed while auras are secret waits for them to lift", function()
    local _, ns, AB, key = procWorld({ holder = true })
    local list = buttons(AB, key)
    -- A PvP match between fights: auras secret, buttons locked, no combat.
    stub.SetRestriction("PvPMatch", true)
    local profile = ns.Bridge.SavedProfile(1)
    EZCDMDB.upGlow = { [profile] = { [key] = RED } }
    ns.Effects.Sync()
    for _, btn in ipairs(list) do T.isnil(ns.Effects.Ring(btn), "nothing while the buttons lock") end
    stub.SetRestriction("PvPMatch", false)
    stub.RunTimers()
    for i, btn in ipairs(list) do T.truthy(ns.Effects.Ring(btn), "button " .. i .. ": a ring after") end
    noErrors()
end)

T.test("effects: a button the client refuses keeps the rule waiting for a /reload", function()
    local _, ns, AB, key = procWorld({ holder = true })
    local list = buttons(AB, key)
    for _, btn in ipairs(list) do
        btn.AddAuraShownAnimation = function() error("refused") end
    end
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    for _, btn in ipairs(list) do T.isnil(ns.Effects.Ring(btn)) end
    T.falsy(ns.Effects.Lit(key))
    T.truthy(ns.Effects.Pending(key), "it lights after a /reload")
    T.truthy(ns.Effects.ReloadDue(), "a /reload is due")
    local n = #stub.errors
    ns.Effects.Sync()
    T.eq(#stub.errors, n, "a refused button is not tried again")
end)

-- ---------------------------------------------------------------------
-- The /reload question as the editor closes
-- ---------------------------------------------------------------------

-- A holder whose buttons the client refuses after initializeFrame, so a new rule waits.
local function refusingWorld()
    local DUI, ns, AB, key = procWorld({ holder = true })
    for _, btn in ipairs(buttons(AB, key)) do
        btn.AddAuraShownAnimation = function() error("refused") end
    end
    stub.Dismiss()
    return DUI, ns, AB, key
end

T.test("reload ask: asked once the editor closes with a glow waiting, and only then", function()
    local _, ns, AB, key = refusingWorld()
    T.truthy(AB.CdmEditor.Open(), "the editor opens")
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    stub.RunTimers()
    T.isnil(stub.Asked(), "nothing asked while the editor is open")
    AB.CdmEditor.Close()
    stub.RunTimers()
    T.eq(stub.Asked(), "ezcdm:reload")
    T.eq(stub.AskText(), "EZ-CDM: /reload to light the new glow.")
end)

T.test("reload ask: its Reload button reloads the UI", function()
    local _, ns, AB, key = refusingWorld()
    AB.CdmEditor.Open()
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    AB.CdmEditor.Close()
    stub.RunTimers()
    T.eq(stub.Asked(), "ezcdm:reload")
    stub.reloaded = nil
    stub.ClickReload()
    T.truthy(stub.reloaded, "ReloadUI ran from the click")
end)

T.test("reload ask: Later keeps quiet until another rule changes", function()
    local _, ns, AB, key = refusingWorld()
    AB.CdmEditor.Open()
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    AB.CdmEditor.Close()
    stub.RunTimers()
    stub.Answer(false)
    T.isnil(stub.Asked())
    AB.CdmEditor.Open()
    AB.CdmEditor.Close()
    stub.RunTimers()
    T.isnil(stub.Asked(), "not asked again for the same rule")
    AB.CdmEditor.Open()
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", BLUE) } }))
    AB.CdmEditor.Close()
    stub.RunTimers()
    T.eq(stub.Asked(), "ezcdm:reload", "asked for the new rule")
end)

T.test("reload ask: nothing asked when the ring lit live", function()
    local _, ns, AB, key = procWorld({ holder = true })
    stub.Dismiss()
    AB.CdmEditor.Open()
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", BLUE) } }))
    AB.CdmEditor.Close()
    stub.RunTimers()
    T.isnil(stub.Asked(), "a live ring and a live color need no /reload")
    T.falsy(ns.Effects.ReloadDue())
    noErrors()
end)

T.test("reload ask: never in a fight", function()
    local _, ns, AB, key = refusingWorld()
    AB.CdmEditor.Open()
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    stub.EnterCombat()
    AB.CdmEditor.Close()
    stub.RunTimers()
    T.isnil(stub.Asked(), "no question in a fight")
    T.falsy(ns.Effects.AskReload(), "and none asked by hand")
    stub.LeaveCombat()
end)

-- ---------------------------------------------------------------------
-- Step 5: the ring built under the game's initializeFrame rule
-- ---------------------------------------------------------------------

T.test("effects: building the ring inside initializeFrame tests nothing the button reports", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local list = buttons(AB, key)
    T.truthy(#list > 0)
    T.eq(stub.initSecretErrors, 0, "no boolean test on a secret while the client makes the button")
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    for i, btn in ipairs(list) do
        local r = ns.Effects.Ring(btn)
        T.truthy(r, "button " .. i .. ": a ring")
        T.eq(ringsIn(btn, r), 1, "button " .. i .. ": handed over exactly once")
    end
    noErrors()
end)

T.test("effects: Daylight UI's SetGlow inside initializeFrame trips on the secrets, as in game", function()
    -- The old route, hooked the way EZ-CDM did: SetGlow on each button as the client makes it.
    local hooked = false
    local _, _, AB, key = procWorld({ holder = true, seen = function()
        local Fx = stub.actionbars.CdmEffects
        _G.DaylightUI.API.For("EZ-CDM").Hook(Fx, "MakeSlide", function(btn) Fx.SetGlow(btn, true, RED) end)
        hooked = true
    end })
    T.truthy(hooked)
    local list = buttons(AB, key)
    T.truthy(#list > 0)
    T.eq(stub.initSecretErrors, #list, "one secret test per button")
    local err = tostring(stub.errors[1])
    T.truthy(err:find("CdmEffects.lua:388", 1, true), err)
    T.truthy(err:find("boolean test on a secret boolean value", 1, true), err)
    T.falsy(stub.InitializingAura(list[1]), "out of initializeFrame once the client is done")
end)

T.test("effects: the ring is Daylight UI's art, measures and loop, sized from the holder", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    local Fx = AB.CdmEffects
    local h = AB.CdmAuras.Frame(key)
    local btn = buttons(AB, key)[1]
    local r = ns.Effects.Ring(btn)
    T.eq(r.tex:GetAtlas(), Fx.GLOW_ATLAS, "the game's proc loop, by Daylight UI's name")
    T.truthy(r.tex:IsDesaturated(), "gray, so the color tints true")
    local pad = h.size * Fx.GLOW_PAD
    local p1, rel1, _, x1, y1 = r.frame:GetPoint(1)
    local p2, rel2, _, x2, y2 = r.frame:GetPoint(2)
    T.eq(p1, "TOPLEFT"); T.eq(rel1, btn); T.eq(x1, -pad); T.eq(y1, pad)
    T.eq(p2, "BOTTOMRIGHT"); T.eq(rel2, btn); T.eq(x2, pad); T.eq(y2, -pad)
    T.eq(r.anim.__looping, "REPEAT", "a loop")
    local cd = h.parts[btn].cd
    T.truthy(r.tex:GetParent():GetFrameLevel() > cd:GetFrameLevel(), "over the button's cooldown")
    noErrors()
end)

T.test("effects: a ring with no color takes the accent as Daylight UI paints it", function()
    local DUI, ns, AB, key = procWorld({ holder = true, rule = true })
    local r = ns.Effects.Ring(buttons(AB, key)[1])
    local ref = CreateFrame("Frame"):CreateTexture()
    DUI.Style.PaintAccent(ref, 1)
    T.deq({ r.tex:GetVertexColor() }, { ref:GetVertexColor() }, "the accent's color")
    T.deq(r.tex.__gradient, ref.__gradient, "and its gradient, if any")
    noErrors()
end)

T.test("effects: the Bridge gives no ring art when one of Daylight UI's measures is gone", function()
    local _, ns, AB = procWorld()
    local art = ns.Bridge.RingArt()
    T.eq(art.atlas, AB.CdmEffects.GLOW_ATLAS); T.eq(art.pad, AB.CdmEffects.GLOW_PAD)
    T.eq(art.rows, AB.CdmEffects.GLOW_ROWS); T.eq(art.columns, AB.CdmEffects.GLOW_COLUMNS)
    T.eq(art.frames, AB.CdmEffects.GLOW_FRAMES); T.eq(art.loop, AB.CdmEffects.GLOW_LOOP)
    local was = AB.CdmEffects.GLOW_PAD
    AB.CdmEffects.GLOW_PAD = nil
    T.isnil(ns.Bridge.RingArt())
    AB.CdmEffects.GLOW_PAD = was
end)

-- ---------------------------------------------------------------------
-- Step 3: where the rule lives, and no double glow
-- ---------------------------------------------------------------------

T.test("effects rule: a holder piece round-trips through EZCDMDB, Daylight UI's upGlow off", function()
    local _, ns, AB, key = procWorld({ holder = true })
    local Draft = ns.Draft
    local ok, report = Draft.Write(key, { lines = { L("up", "glow", RED) } })
    T.truthy(ok)
    T.eq(report.changes, 1, "one change: EZ-CDM's rule")
    T.eq(report.changed[1].kind, "ez")
    local profile = ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.upGlow[profile][key], RED, "saved by profile and piece")
    T.falsy(pieceOf(AB, key).upGlow, "Daylight UI's upGlow off")
    local rules = Draft.Rules(key)
    T.eq(#rules.lines, 1)
    T.deq(rules.lines[1], L("up", "glow", RED), "reads back as the same line")
    local again = select(2, Draft.Write(key, rules))
    T.eq(again.changes, 0, "a second write writes nothing")
    -- The accent.
    T.truthy(Draft.Write(key, { lines = { L("up", "glow") } }))
    T.eq(EZCDMDB.upGlow[profile][key], true, "true is the accent")
    T.deq(Draft.Rules(key).lines[1], L("up", "glow"))
    -- Cleared.
    T.truthy(Draft.Write(key, { lines = {} }))
    T.isnil(EZCDMDB.upGlow[profile], "nothing left for the profile")
    T.eq(#Draft.Rules(key).lines, 0)
    noErrors()
end)

T.test("effects rule: a game piece round-trips through Daylight UI's upGlow", function()
    local _, ns, AB, key = procWorld()
    local Draft = ns.Draft
    T.truthy(Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    T.eq(pieceOf(AB, key).upGlow, true)
    T.deq(pieceOf(AB, key).upGlowColor, RED)
    T.isnil(ns.Effects.Get(key))
    T.deq(Draft.Rules(key).lines[1], L("up", "glow", RED))
    T.eq(select(2, Draft.Write(key, Draft.Rules(key))).changes, 0, "a second write writes nothing")
    noErrors()
end)

T.test("effects rule: Daylight UI's upGlow set on a holder piece moves to EZ-CDM on the next write", function()
    local _, ns, AB, key = procWorld({ holder = true })
    local D = AB.CdmData
    D.SetSpellValue(D.Ensure(1), key, "upGlow", true)
    D.SetSpellValue(D.Ensure(1), key, "upGlowColor", BLUE)
    local rules = ns.Draft.Rules(key)
    T.deq(rules.lines[1], L("up", "glow", BLUE), "the card's glow reads as the line")
    T.truthy(ns.Draft.Write(key, rules))
    T.falsy(pieceOf(AB, key).upGlow, "Daylight UI's upGlow off")
    T.deq(ns.Effects.Get(key), BLUE, "EZ-CDM's, same color")
    noErrors()
end)

T.test("effects rule: no piece ever has both glows", function()
    for _, holder in ipairs({ false, true }) do
        local _, ns, AB, key = procWorld({ holder = holder })
        for _, lines in ipairs({ { L("up", "glow", RED) }, { L("up", "glow") }, {}, { L("up", "glow", BLUE) } }) do
            T.truthy(ns.Draft.Write(key, { lines = lines }))
            local daylight = pieceOf(AB, key).upGlow == true
            local ez = ns.Effects.Get(key) ~= nil
            T.falsy(daylight and ez, (holder and "holder" or "game") .. ": both glows")
            T.eq(daylight or ez, #lines > 0, "one glow when the line is there")
            T.eq(ez, holder and #lines > 0, "EZ-CDM's exactly on a holder piece")
        end
        noErrors()
    end
end)

T.test("effects rule: a rule left on a piece the game now draws goes back to Daylight UI", function()
    local _, ns, AB, key = procWorld({ rule = RED })
    T.eq(AB.CdmRows.DrawnBy(key), "game")
    local rules = ns.Draft.Rules(key)
    T.deq(rules.lines[1], L("up", "glow", RED), "the rule still reads as a line")
    T.truthy(ns.Draft.Write(key, rules))
    T.isnil(ns.Effects.Get(key), "cleared")
    T.eq(pieceOf(AB, key).upGlow, true, "Daylight UI's again")
    T.deq(pieceOf(AB, key).upGlowColor, RED)
    noErrors()
end)

T.test("effects rule: refused in combat and with no write at all", function()
    local _, ns, _, key = procWorld({ holder = true })
    stub.EnterCombat()
    local ok, why = ns.Effects.Set(1, key, RED)
    T.falsy(ok); T.eq(why, "combat")
    T.isnil(ns.Effects.Get(key))
    stub.LeaveCombat()
    noErrors()
end)

T.test("effects: the debug handle", function()
    local _, ns = procWorld()
    T.eq(_G.EZCDM_Effects, ns.Effects)
end)

-- ---------------------------------------------------------------------
-- A piece Daylight UI draws on its own face (docs/tasks/done/sweep.md, step 5): no
-- client button, so its up glow stays Daylight UI's.
-- ---------------------------------------------------------------------

local function deep(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = deep(x) end
    return out
end

local function refresh(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

-- A shaman with an enchant on the main hand, the main-hand and off-hand pieces
-- placed. Daylight UI draws a weapon enchant on its own face (CdmAuras.lua:419-425).
-- db = { dui, ez }: the saved variables of an earlier session, as after a /reload.
local function weaponWorld(db)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = STORMBUFF, known = { STORMBUFF }, showAll = true })
        stub.spells[STORMBUFF] = { name = "Improved Stormstrike" }
        stub.weaponEnchants = { { slot = 0, timeLeft = 1800000, enchantID = 19 } }
        if db then DaylightUIDB, EZCDMDB = deep(db.dui), deep(db.ez) end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    local AB = stub.actionbars
    if not db then
        AB.CdmData.AddPiece(AB.CdmData.Ensure(1), "mainhand", "icon", 0, 0)
        AB.CdmData.AddPiece(AB.CdmData.Ensure(1), "offhand", "icon", 60, 0)
    end
    refresh(AB)
    return DUI, ns, AB
end

T.test("effects face: a weapon enchant has no client button, so its up glow stays Daylight UI's", function()
    local _, ns, AB = weaponWorld()
    local B, E, key = ns.Bridge, ns.Effects, "mainhand"
    T.eq(B.DrawnBy(key), "aura icon", "an aura icon holder draws it")
    T.eq(B.ClientButtons(key), false, "on Daylight UI's own face")
    T.eq(#buttons(AB, key), 0, "no client button")
    T.falsy(E.Drawn(key))
    T.falsy(ns.Grammar.Kind(key).ezGlow)
    T.truthy(ns.Draft.Write(key, { lines = { L("up", "glow", RED) } }))
    T.eq(pieceOf(AB, key).upGlow, true, "Daylight UI's upGlow")
    T.deq(pieceOf(AB, key).upGlowColor, RED)
    T.isnil(E.Get(key), "no rule of EZ-CDM's")
    T.falsy(E.Pending(key), "nothing waits for a /reload")
    T.deq(ns.Draft.Rules(key).lines, { L("up", "glow", RED) }, "reads back as the line")
    -- Daylight UI lights it on its face while the enchant is on, in a fight too.
    refresh(AB)
    local h = AB.CdmAuras.Frame(key)
    T.truthy(AB.CdmEffects.GlowShown(h), "lit out of a fight")
    stub.EnterCombat()
    refresh(AB)
    T.truthy(AB.CdmEffects.GlowShown(h), "lit in a fight")
    stub.LeaveCombat()
    noErrors()
end)

T.test("effects face: a holder with client buttons says so, and its rule stays EZ-CDM's", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    T.eq(ns.Bridge.ClientButtons(key), true, "client containers (CdmAuras.lua:385)")
    T.truthy(#buttons(AB, key) > 0)
    T.truthy(ns.Effects.Drawn(key))
    refresh(AB)
    T.deq(ns.Effects.Get(key), RED, "the rule stays EZ-CDM's")
    T.falsy(pieceOf(AB, key).upGlow, "Daylight UI's upGlow stays off")
    T.eq(ns.Bridge.ClientButtons(12345), nil, "no holder: can't say")
    noErrors()
end)

T.test("effects face: a rule an earlier build saved on a face piece goes back to Daylight UI at load", function()
    local _, ns, AB = weaponWorld()
    local profile = ns.Bridge.SavedProfile(1)
    -- As an earlier build wrote it: EZ-CDM's rule, Daylight UI's upGlow off.
    EZCDMDB.upGlow = { [profile] = { mainhand = RED, offhand = true } }
    T.falsy(pieceOf(AB, "mainhand").upGlow)
    local db = { dui = deep(DaylightUIDB), ez = deep(EZCDMDB) }
    local _, ns2, AB2 = weaponWorld(db)
    local E = ns2.Effects
    T.isnil(E.Get("mainhand"), "EZ-CDM's rule is gone")
    T.isnil(E.Get("offhand"))
    T.isnil(EZCDMDB.upGlow[profile], "nothing left for the profile")
    T.eq(pieceOf(AB2, "mainhand").upGlow, true, "Daylight UI's upGlow is on")
    T.deq(pieceOf(AB2, "mainhand").upGlowColor, RED, "in the rule's color")
    T.eq(pieceOf(AB2, "offhand").upGlow, true)
    T.isnil(pieceOf(AB2, "offhand").upGlowColor, "the accent stays the accent")
    T.falsy(E.Pending("mainhand"), "nothing waits for a /reload")
    T.deq(ns2.Draft.Rules("mainhand").lines, { L("up", "glow", RED) }, "the same line")
    T.truthy(AB2.CdmEffects.GlowShown(AB2.CdmAuras.Frame("mainhand")), "Daylight UI lights it")
    noErrors()
end)

T.test("effects face: a rule on a face piece waits out a fight, then goes back", function()
    local _, ns, AB = weaponWorld()
    local profile = ns.Bridge.SavedProfile(1)
    EZCDMDB.upGlow = { [profile] = { mainhand = RED } }
    local db = { dui = deep(DaylightUIDB), ez = deep(EZCDMDB) }
    local DUI, ns2 = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = STORMBUFF, known = { STORMBUFF }, showAll = true })
        stub.weaponEnchants = { { slot = 0, timeLeft = 1800000, enchantID = 19 } }
        DaylightUIDB, EZCDMDB = deep(db.dui), deep(db.ez)
    end })
    stub.EnterCombat()
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    local AB2 = stub.actionbars
    refresh(AB2)
    T.deq(ns2.Effects.Get("mainhand"), RED, "no write in a fight")
    stub.LeaveCombat()
    refresh(AB2)
    T.isnil(ns2.Effects.Get("mainhand"), "gone once the fight ends")
    T.eq(pieceOf(AB2, "mainhand").upGlow, true)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The fall-off lead (fall-off-lead.md step 1): Daylight UI's recast clock, its
-- due moment moved N seconds before the end. A warrior's Rend, drawn by the
-- game's own cooldown icon, timed from your cast (9 s by the game's data).
-- ---------------------------------------------------------------------

local SHOUT, REND, CLAP = 6673, 772, 6343
local ESSENTIAL = 0

local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

-- Rend placed as an icon, logged in, motion off. lines are written first.
local function leadWorld(lines)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = false
    local AB = stub.actionbars
    local key = CW.ID(REND, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    pass(AB)
    if lines then
        local ok, why, report = ns.Draft.Write(key, { lines = lines })
        T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes[1] and report.notes[1].words))
        pass(AB)
    end
    return DUI, ns, AB, key
end

local function glowing(AB, key) return AB.CdmEffects.GlowShown(CW.Item(key)) == true end

-- Your cast of Rend.
local casts = 0
local function castRend()
    casts = casts + 1
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. casts, REND)
    stub.RunTimers()
end

-- Your cast, and its debuff landing on the target, in a fight.
local function fightAndCast()
    stub.EnterCombat(); stub.RunTimers()
    castRend()
    CW.Aura("target", REND, { harmful = true, duration = 9 }); stub.RunTimers()
end

-- Time passes; Daylight UI's own timer and the pass it asks for run.
local function wait(s)
    stub.Advance(s)
    for _ = 1, 3 do stub.RunTimers() end
end

-- EZ-CDM's frames that run an OnUpdate now (test_lag's count).
local ourDrivers = require("ez_harness").PluginDriverCount

local function RL(action, at, value) return { moment = "recast", action = action, at = at, value = value } end

T.test("fall-off lead: the clock wraps are in place as EZ-CDM loads", function()
    local _, ns = leadWorld()
    T.truthy(ns.Effects.wrapped, "ClipDue, Clip and ClipGlows wrapped")
    noErrors()
end)

T.test("fall-off lead: in a fight the recast glow lights N seconds before the end", function()
    local _, ns, AB, key = leadWorld({ RL("glow", 5) })
    T.eq(ns.Effects.FallOff(key).lead, 5, "the rule")
    T.eq(AB.CdmData.Get(1).pieces[key].clipGlow, true, "Daylight UI's own recast glow on")
    fightAndCast()
    T.falsy(glowing(AB, key), "9 s left")
    wait(3.9)
    T.falsy(glowing(AB, key), "5.1 s left: not yet")
    wait(0.2)
    T.truthy(glowing(AB, key), "4.9 s left: lit, by Daylight UI's own timer")
    wait(2)
    T.truthy(glowing(AB, key), "stays lit")
    T.eq(ourDrivers(), 0, "no per-frame driver of EZ-CDM's")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off lead: a recast puts it out, and it lights again N seconds before the new end", function()
    local _, _, AB, key = leadWorld({ RL("glow", 5) })
    fightAndCast()
    wait(4.5)
    T.truthy(glowing(AB, key), "lit")
    castRend()
    wait(0)
    T.falsy(glowing(AB, key), "the recast restarts the clock: out")
    wait(3.9)
    T.falsy(glowing(AB, key), "5.1 s before the new end")
    wait(0.2)
    T.truthy(glowing(AB, key), "lit again")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off lead: with no lead, Daylight UI's own timing stands", function()
    local _, ns, AB, key = leadWorld({ { moment = "recast", action = "glow" } })
    T.isnil(ns.Effects.FallOff(key), "no rule of EZ-CDM's")
    fightAndCast()
    wait(4.1)
    T.falsy(glowing(AB, key), "4.9 s left: Daylight UI waits")
    wait(3.9)
    T.falsy(glowing(AB, key), "1 s left: a cast now would still clip it")
    -- Another spell keeps you busy past the end: Daylight UI's own moment.
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "clap", CLAP)
    for _ = 1, 3 do stub.RunTimers() end
    T.truthy(glowing(AB, key), "lit when a cast would land as it ends")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off lead: the wraps see only the plain end and key Daylight UI keeps", function()
    local _, _, AB, key = leadWorld({ RL("glow", 5) })
    -- A wrap outside EZ-CDM's: what the clock hands in, and what comes back.
    local seen, bad = 0, {}
    _G.DaylightUI.API.For("EZ-CDM").Wrap(AB.CdmAuras, "ClipDue", function(orig, h, sid)
        seen = seen + 1
        if issecretvalue(h.endsAt) or issecretvalue(h.id) then bad[#bad + 1] = "secret in" end
        local due, at = orig(h, sid)
        if issecretvalue(due) or issecretvalue(at) then bad[#bad + 1] = "secret out" end
        return due, at
    end)
    fightAndCast()
    wait(4.1)
    T.truthy(glowing(AB, key))
    T.truthy(seen > 0, "the clock asked")
    T.eq(table.concat(bad, ", "), "", "nothing secret in or out")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off lead: the rule lives in EZCDMDB by profile and piece, and round-trips", function()
    local _, ns, AB, key = leadWorld()
    local Draft = ns.Draft
    local ok, report = Draft.Write(key, { lines = { RL("glow", 8) } })
    T.truthy(ok)
    local profile = ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.fallOff[profile][key], { lead = 8 }, "saved by profile and piece")
    T.isnil(AB.CdmData.Get(1).pieces[key].ezLead, "never in Daylight UI's layout")
    local kinds = {}
    for _, c in ipairs(report.changed) do kinds[#kinds + 1] = c.kind .. ":" .. c.field end
    table.sort(kinds)
    T.eq(table.concat(kinds, " "), "ez:fallOff set:clipGlow")
    local rules = Draft.Rules(key)
    T.deq(rules.lines, { RL("glow", 8) }, "reads back as the same line")
    T.eq(select(2, Draft.Write(key, rules)).changes, 0, "a second write writes nothing")
    -- Back to Daylight UI's timing, then gone.
    T.truthy(Draft.Write(key, { lines = { { moment = "recast", action = "glow" } } }))
    T.isnil(EZCDMDB.fallOff[profile], "nothing left for the profile")
    T.eq(AB.CdmData.Get(1).pieces[key].clipGlow, true)
    T.truthy(Draft.Write(key, { lines = {} }))
    T.eq(#Draft.Rules(key).lines, 0)
    noErrors()
end)

T.test("fall-off lead: refused in combat", function()
    local _, ns, _, key = leadWorld()
    stub.EnterCombat()
    local ok, why = ns.Effects.SetFallOff(1, key, { lead = 5 })
    T.falsy(ok); T.eq(why, "combat")
    T.isnil(ns.Effects.FallOff(key))
    stub.LeaveCombat()
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The fall-off sound (fall-off-lead.md step 2): played once as the moment comes.
-- ---------------------------------------------------------------------

local RAID = "file:567397"

-- Every sound Daylight UI's Sound.Alert plays from now on.
local function listen(DUI)
    local got = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(k) got[#got + 1] = k; return keep(k) end
    return got
end

T.test("fall-off sound: one sound per due moment, with the glow", function()
    local DUI, ns, AB, key = leadWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    T.deq(ns.Effects.FallOff(key), { lead = 5, sound = RAID }, "the rule")
    local got = listen(DUI)
    fightAndCast()
    wait(3.9)
    T.eq(#got, 0, "not yet")
    wait(0.2)
    T.truthy(glowing(AB, key), "the glow lights")
    T.deq(got, { RAID }, "and the sound plays with it")
    T.eq(ns.Effects.Heard(key), AB.CdmAuras.Watch(key).endsAt, "for this end")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off sound: nothing replays while it stays due", function()
    local DUI, _, AB, key = leadWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    local got = listen(DUI)
    fightAndCast()
    wait(4.1)
    T.eq(#got, 1)
    for _ = 1, 5 do pass(AB) end
    wait(1); wait(1)
    -- Other casts ask the clock again.
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "clap", CLAP)
    for _ = 1, 3 do stub.RunTimers() end
    T.truthy(glowing(AB, key), "still lit")
    T.eq(#got, 1, "still one sound")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off sound: a recast re-arms it", function()
    local DUI, _, AB, key = leadWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    local got = listen(DUI)
    fightAndCast()
    wait(4.5)
    T.eq(#got, 1)
    castRend()
    wait(0)
    T.falsy(glowing(AB, key), "out after the recast")
    wait(3.9)
    T.eq(#got, 1, "not before the new moment")
    wait(0.2)
    T.eq(#got, 2, "once more at the new moment")
    wait(1)
    T.eq(#got, 2)
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off sound: a sound with no glow runs the clock and lights nothing", function()
    local DUI, ns, AB, key = leadWorld({ RL("sound", 5, RAID) })
    local p = AB.CdmData.Get(1).pieces[key]
    T.falsy(p.clipGlow, "Daylight UI's recast glow stays off")
    T.truthy(AB.CdmEffects.ClipGlows(p), "the pass runs the clock for the sound")
    T.deq(ns.Effects.FallOff(key), { lead = 5, sound = RAID })
    local got = listen(DUI)
    fightAndCast()
    T.truthy(AB.CdmAuras.Watch(key).wantsClip, "the watch keeps a clock")
    wait(4.1)
    T.deq(got, { RAID }, "the sound plays at the moment")
    T.falsy(glowing(AB, key), "with no glow")
    wait(2)
    T.eq(#got, 1)
    T.falsy(glowing(AB, key))
    T.eq(ourDrivers(), 0, "no per-frame driver of EZ-CDM's")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off sound: with no lead it plays at Daylight UI's own moment", function()
    local DUI, _, AB, key = leadWorld({ { moment = "recast", action = "glow" }, RL("sound", nil, RAID) })
    local got = listen(DUI)
    fightAndCast()
    wait(4.1)
    T.eq(#got, 0, "Daylight UI's moment hasn't come")
    wait(3.9)
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "clap", CLAP)
    for _ = 1, 3 do stub.RunTimers() end
    T.truthy(glowing(AB, key))
    T.deq(got, { RAID }, "once, with Daylight UI's glow")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off sound: removing the line stops the sound and the clock it ran", function()
    local DUI, ns, AB, key = leadWorld({ RL("sound", 5, RAID) })
    T.truthy(ns.Draft.Write(key, { lines = {} }))
    pass(AB)
    T.isnil(ns.Effects.FallOff(key))
    T.falsy(AB.CdmEffects.ClipGlows(AB.CdmData.Get(1).pieces[key]), "Daylight UI's own answer again")
    local got = listen(DUI)
    fightAndCast()
    wait(8)
    T.eq(#got, 0)
    stub.LeaveCombat()
    noErrors()
end)

-- ---------------------------------------------------------------------
-- A debuff the game's own cooldown icon draws (fall-off-lead.md step 5): a
-- shaman's Flame Shock, timed by its watch. In game a pass runs between your cast
-- and the debuff landing (combat starting, the cooldown, another aura), while the
-- game's icon still says "down".
-- ---------------------------------------------------------------------

local FS1, FS = 8050, 10447

-- Flame Shock placed as an icon, its highest rank known, lines written first.
local function shockWorld(lines)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = FS1, known = { FS1, 8052, 8053, FS }, showAll = true })
        stub.spells[FS1] = { name = "Flame Shock" }
        stub.spells[FS] = { name = "Flame Shock" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = false
    local AB = stub.actionbars
    local key = CW.ID(FS1, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    pass(AB)
    if lines then
        local ok, why = ns.Draft.Write(key, { lines = lines })
        T.truthy(ok, tostring(why))
        pass(AB)
    end
    T.eq(ns.Bridge.DrawnBy(key), "game", "the game's cooldown icon draws it")
    return DUI, ns, AB, key
end

-- In a fight: your cast, a pass before the debuff lands, then the debuff (12 s).
local function shockLands()
    stub.EnterCombat(); stub.RunTimers()
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "shock", FS)
    stub.RunTimers()
    pass(stub.actionbars)
    stub.Advance(0.2)
    CW.Aura("target", FS, { harmful = true, duration = 12 }); stub.RunTimers()
end

-- Stormstrike, the other spell cast in session 10.
local SS = 17364

-- The game's icon looks for its debuff again and doesn't find it, though the debuff
-- is still on the target (session 10, +20.9: "down" with 7.2 s left). The client
-- sends one full cooldown update as another spell's global cooldown ends, and the
-- icon's full refresh asks the client's aura list again. Why that list misses the
-- debuff in a fight is the client's own, so the debuff steps out of the list for
-- that one refresh.
local function iconLosesIt(sid)
    local list = stub.auras.target.HARMFUL
    local out = {}
    for i = #list, 1, -1 do
        if list[i].spellId == sid then out[#out + 1] = table.remove(list, i) end
    end
    CW.Run(CW.G.CooldownViewer_MarkAuraCacheDirty)
    stub.FireEvent("SPELL_UPDATE_COOLDOWN")
    for _, a in ipairs(out) do list[#list + 1] = a end
    stub.RunTimers()
end

-- After the debuff lands: another spell and its global cooldown, then the icon's
-- full refresh at its end, and a pass that reads the icon's "down".
local function otherSpellThenDown(AB, castAt, gcdEnds)
    wait(castAt)
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "storm", SS)
    CW.Cooldown(SS, 1.5, true); stub.RunTimers()
    stub.Advance(gcdEnds)
    CW.Cooldown(SS, nil)
    iconLosesIt(FS)
    pass(AB)
end

-- ---------------------------------------------------------------------
-- The fall-off clock on Daylight UI's buff moments (fall-off-events.md): the
-- pinned Daylight UI's own moments, recorded in stub.buffMoments.
-- ---------------------------------------------------------------------

-- Daylight UI's buff moments fired for a piece: "up down up".
local function momentsFor(key)
    local out = {}
    for _, m in ipairs(stub.buffMoments or {}) do
        if m.key == tostring(key) then out[#out + 1] = m.event == "CooldownBuffUp" and "up" or "down" end
    end
    return table.concat(out, " ")
end

-- The game's icon finds its debuff again on its next full refresh, and a pass reads it.
local function iconFindsIt(AB)
    CW.Run(CW.G.CooldownViewer_MarkAuraCacheDirty)
    stub.FireEvent("SPELL_UPDATE_COOLDOWN")
    stub.RunTimers()
    pass(AB)
end

T.test("fall-off events: the clock starts as the debuff lands, through a pass before it lands", function()
    local DUI, ns, AB, key = shockWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    local got = listen(DUI)
    shockLands()
    T.eq(momentsFor(key), "up", "CooldownBuffUp as it lands")
    T.eq(ns.Effects.Route(key), "events")
    T.near(ns.Effects.EventEnds(key) - GetTime(), 12, 0.01, "12 s from the landing")
    wait(6.9)
    T.falsy(glowing(AB, key), "5.1 s before the landing's end (4.9 s on the cast's clock): not yet")
    T.eq(#got, 0)
    wait(0.2)
    T.truthy(glowing(AB, key), "4.9 s left: lit")
    T.deq(got, { RAID }, "the sound, once")
    wait(2)
    T.eq(#got, 1)
    T.eq(ourDrivers(), 0, "no per-frame driver of EZ-CDM's")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off events: a down with an up inside the grace keeps the landing's end", function()
    local DUI, ns, AB, key = shockWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    local got = listen(DUI)
    shockLands()
    local ends = ns.Effects.EventEnds(key)
    T.truthy(ends, "the landing's clock")
    -- The game's icon loses the debuff for one refresh, then finds it again.
    otherSpellThenDown(AB, 3.056, 1.579)
    T.eq(CW.Item(key).wasSetFromAura, false, "the game's icon says down")
    wait(0.5)
    T.eq(ns.Effects.EventEnds(key), ends, "inside the grace the clock stands")
    iconFindsIt(AB)
    T.eq(momentsFor(key), "up down up")
    T.eq(ns.Effects.EventEnds(key), ends, "the same end: a blip, not a new debuff")
    wait(1.765)
    T.falsy(glowing(AB, key), "5.1 s left: not yet")
    wait(0.2)
    T.truthy(glowing(AB, key), "4.9 s left: lit")
    T.deq(got, { RAID }, "the sound, once")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off events: a debuff gone early puts the glow out and plays nothing more", function()
    local DUI, ns, AB, key = shockWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    local got = listen(DUI)
    shockLands()
    wait(7.1)
    T.truthy(glowing(AB, key), "4.9 s left: lit")
    T.deq(got, { RAID })
    -- The target dies with 4.9 s left.
    CW.Unaura("target", FS); stub.RunTimers()
    T.eq(momentsFor(key), "up down")
    wait(0.5)
    T.truthy(glowing(AB, key), "inside the grace: still lit")
    wait(0.6)
    T.falsy(glowing(AB, key), "past the grace: out")
    T.eq(ns.Effects.Route(key), "cast", "the events' clock stopped")
    T.isnil(AB.CdmAuras.Watch(key).endsAt, "and Daylight UI's own")
    wait(5)
    T.falsy(glowing(AB, key))
    T.eq(#got, 1, "no second sound")
    stub.LeaveCombat()
    noErrors()
    -- Dispelled with 9 s left: no glow and no sound at all.
    local DUI2, _, AB2, key2 = shockWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    local got2 = listen(DUI2)
    shockLands()
    wait(3)
    CW.Unaura("target", FS); stub.RunTimers()
    for _ = 1, 10 do wait(1) end
    T.falsy(glowing(AB2, key2), "never lit")
    T.eq(#got2, 0, "never played")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off events: a recast while it's up restarts the clock from the cast", function()
    local _, ns, AB, key = shockWorld({ RL("glow", 5) })
    shockLands()
    wait(3)
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "shock2", FS)
    stub.RunTimers()
    CW.Aura("target", FS, { harmful = true, duration = 12 }); stub.RunTimers()
    pass(AB)
    T.eq(momentsFor(key), "up", "no new moment: up stays up")
    T.eq(ns.Effects.Route(key), "events")
    T.near(ns.Effects.EventEnds(key) - GetTime(), 12, 0.01, "12 s from the recast")
    wait(4)
    T.falsy(glowing(AB, key), "the old end's moment passes unlit")
    wait(2.8)
    T.falsy(glowing(AB, key), "5.2 s before the new end: not yet")
    wait(0.3)
    T.truthy(glowing(AB, key), "4.9 s before the new end: lit")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off events: an up just after a target change starts no clock of its own", function()
    local _, ns, AB, key = shockWorld({ RL("glow", 5) })
    shockLands()
    wait(2)
    -- Off to another target, whose icon shows no Flame Shock, then back.
    CW.Unaura("target", FS); stub.RunTimers()
    wait(1.5)
    T.eq(ns.Effects.Route(key), "cast", "the drop stopped the clock")
    stub.FireEvent("PLAYER_TARGET_CHANGED")
    CW.Aura("target", FS, { harmful = true, duration = 12 }); stub.RunTimers()
    T.eq(momentsFor(key), "up down up")
    T.isnil(ns.Effects.EventEnds(key), "seen again: its time left is unknown")
    for _ = 1, 10 do wait(1) end
    T.falsy(glowing(AB, key), "no glow from a full new length")
    stub.LeaveCombat()
    noErrors()
end)

-- Flame Shock placed as a bar, so Daylight UI's aura and cooldown bar (a holder)
-- draws it, and the game's cooldown icon, out of sight, still says up or down
-- (CdmRows truthUp). lines are written first.
local function shockHolderWorld(lines)
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "SHAMAN", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = FS1, known = { FS1, 8052, 8053, FS }, showAll = true })
        stub.spells[FS1] = { name = "Flame Shock" }
        stub.spells[FS] = { name = "Flame Shock" }
    end })
    stub.neverSecretAuras = {}
    stub.RunTimers()
    DUI.DB.General().motion = false
    local AB = stub.actionbars
    local key = CW.ID(FS1, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "bar", 0, 0)
    pass(AB)
    if lines then
        local ok, why = ns.Draft.Write(key, { lines = lines })
        T.truthy(ok, tostring(why))
        pass(AB)
    end
    return DUI, ns, AB, key
end

T.test("fall-off events: a holder no moment comes for keeps the cast clock and its hold", function()
    local DUI, ns, AB, key = shockHolderWorld({ RL("glow", 5), RL("sound", 5, RAID) })
    T.eq(ns.Bridge.DrawnBy(key), "aura and cooldown bar", "Daylight UI's holder draws it")
    local got = listen(DUI)
    local heard = {}
    _G.DaylightUI.API.For("EZ-CDM").Wrap(AB.CdmAuras, "Told", function(orig, h, up)
        if h.id == key then heard[#heard + 1] = up end
        return orig(h, up)
    end)
    shockLands()
    local bar = AB.CdmBars.AuraFrame(key)
    local ends = bar.endsAt
    T.truthy(ends, "the cast's clock runs on the holder")
    otherSpellThenDown(AB, 3.056, 1.579)
    T.eq(heard[#heard], false, "the pass tells the holder down")
    T.near(ends - GetTime(), 7.165, 0.01, "7.2 s left")
    T.eq(bar.endsAt, ends, "the clock stands")
    wait(2.065)
    T.falsy(AB.CdmEffects.GlowShown(bar), "5.1 s left: not yet")
    wait(0.2)
    T.truthy(AB.CdmEffects.GlowShown(bar), "4.9 s left: lit")
    T.deq(got, { RAID }, "the sound, once")
    T.eq(momentsFor(key), "", "no buff moment: the holder has no up or down option")
    T.eq(ns.Effects.Route(key), "cast", "the cast's clock timed it")
    T.falsy(ns.Effects.Covered(key), "not covered")
    stub.LeaveCombat()
    noErrors()
end)

T.test("fall-off lead: without a rule of EZ-CDM's the game's down stands at once", function()
    local _, _, AB, key = shockWorld({ { moment = "recast", action = "glow" } })
    stub.EnterCombat(); stub.RunTimers()
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "shock", FS)
    stub.RunTimers()
    T.truthy(AB.CdmAuras.Watch(key).endsAt, "the cast's clock")
    pass(AB)
    T.isnil(AB.CdmAuras.Watch(key).endsAt, "Daylight UI's own handling")
    stub.LeaveCombat()
    noErrors()
    -- The same mid-debuff "down" as session 10's, the debuff landing before any pass.
    local _, _, AB2, key2 = shockWorld({ { moment = "recast", action = "glow" } })
    stub.EnterCombat(); stub.RunTimers()
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "shock", FS)
    stub.Advance(0.2)
    CW.Aura("target", FS, { harmful = true, duration = 12 }); stub.RunTimers()
    pass(AB2)
    T.truthy(AB2.CdmAuras.Watch(key2).endsAt, "the debuff landed")
    otherSpellThenDown(AB2, 3.056, 1.579)
    T.eq(CW.Item(key2).wasSetFromAura, false, "the game's icon says down")
    T.isnil(AB2.CdmAuras.Watch(key2).endsAt, "Daylight UI drops the clock, as before")
    stub.LeaveCombat()
    noErrors()
end)

-- ---------------------------------------------------------------------
-- A glow style per moment (task7-finish.md step 1): Daylight UI's own glows, each
-- moment in its own style. A warrior's Rend (a ready glow and a recast glow) and
-- Thunder Clap (a ready glow), motion on so the light styles run.
-- ---------------------------------------------------------------------

local function SL(moment, style, value, at)
    return { moment = moment, action = "glow", style = style, value = value, at = at }
end

-- Rend and Thunder Clap placed as icons, motion on. lines: { rend = ..., clap = ... },
-- written first. pieceStyle: Rend's saved style for glows with none of their own.
local watchStyles
local function styleWorld(lines, pieceStyle)
    local DUI, ns, AB, rend = leadWorld()
    DUI.DB.General().motion = true
    local styleOf = watchStyles(DUI)
    local clap = CW.ID(CLAP, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), clap, "icon", 60, 0)
    pass(AB)
    local keys = { rend = rend, clap = clap }
    for name, list in pairs(lines or {}) do
        local rules = { lines = list }
        if name == "rend" then rules.style = pieceStyle end
        local ok, why, report = ns.Draft.Write(keys[name], rules)
        T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes[1] and report.notes[1].words))
    end
    pass(AB)
    return DUI, ns, AB, keys, styleOf
end

-- What each glow frame shows: a light's style, or "ring". Spied on Daylight UI's
-- GlowAround, which lays a light on the glow frame (CdmEffects.lua:364-372).
function watchStyles(DUI)
    local on = setmetatable({}, { __mode = "k" })
    local keep = DUI.Widgets.GlowAround
    DUI.Widgets.GlowAround = function(host, show, shape)
        on[host] = show and type(shape) == "table" and shape.style or nil
        return keep(host, show, shape)
    end
    return function(AB, item)
        if type(item) ~= "table" then item = CW.Item(item) end
        if not AB.CdmEffects.GlowShown(item) then return nil end
        return on[AB.CdmEffects.GlowFrame(item)] or "ring"
    end
end

T.test("glow style: the wraps are in place as EZ-CDM loads", function()
    local _, ns = leadWorld()
    T.truthy(ns.Effects.styled, "SetDown, EndPass and GlowStyle wrapped")
    noErrors()
end)

T.test("glow style: each moment lights in its own style", function()
    local _, _, AB, k, styleOf = styleWorld({ rend = { SL("ready", "comet"), SL("recast", "breathe", nil, 5) } })
    pass(AB)
    T.eq(styleOf(AB, k.rend), "comet", "ready: Comet")
    fightAndCast()
    wait(4.1)
    T.eq(styleOf(AB, k.rend), "breathe", "about to fall off: Breathing")
    castRend()
    wait(0)
    T.eq(styleOf(AB, k.rend), "comet", "the recast puts the recast glow out: ready again, Comet")
    T.eq(ourDrivers(), 0, "no per-frame driver of EZ-CDM's")
    stub.LeaveCombat()
    noErrors()
end)

T.test("glow style: a moment with no style of its own takes the piece's style", function()
    local _, _, AB, k, styleOf = styleWorld({ rend = { SL("ready"), SL("recast", "breathe", nil, 5) } }, "twinkle")
    pass(AB)
    T.eq(styleOf(AB, k.rend), "twinkle", "ready has none: the piece's Twinkle")
    fightAndCast()
    wait(4.1)
    T.eq(styleOf(AB, k.rend), "breathe", "its own style where it has one")
    stub.LeaveCombat()
    noErrors()
end)

T.test("glow style: motion off keeps the ring, by Daylight UI's own rule", function()
    local _, _, AB, k, styleOf = styleWorld({ rend = { SL("ready", "comet") } })
    _G.DaylightUI.DB.General().motion = false
    AB.CdmEffects.UpdateAll()
    pass(AB)
    T.eq(styleOf(AB, k.rend), "ring")
    noErrors()
end)

T.test("glow style: passes between the cast and its landing keep each moment's style", function()
    local _, _, AB, k, styleOf = styleWorld({ rend = { SL("ready", "comet"), SL("recast", "breathe", nil, 5) } })
    stub.EnterCombat(); stub.RunTimers()
    castRend()
    -- Daylight UI's passes before the debuff lands, and a cooldown event between them.
    pass(AB); AB.CdmEffects.UpdateAll(); pass(AB)
    T.eq(styleOf(AB, k.rend), "comet", "not due yet: still the ready glow's Comet")
    CW.Aura("target", REND, { harmful = true, duration = 9 }); stub.RunTimers()
    wait(4.1)
    T.eq(styleOf(AB, k.rend), "breathe")
    AB.CdmEffects.UpdateAll()
    T.eq(styleOf(AB, k.rend), "breathe", "the moment is kept between passes")
    pass(AB)
    T.eq(styleOf(AB, k.rend), "breathe")
    stub.LeaveCombat()
    noErrors()
end)

T.test("glow style: a pass that doesn't tell an item forgets its moment, as Daylight UI does", function()
    local _, ns, AB, k = styleWorld({ rend = { SL("ready", "comet"), SL("recast", "breathe", nil, 5) } })
    fightAndCast()
    wait(4.1)
    local item = CW.Item(k.rend)
    T.eq(ns.Effects.MomentOf(item), "recast")
    AB.CdmEffects.EndPass({})
    T.isnil(ns.Effects.MomentOf(item), "nothing kept for an item the pass left out")
    stub.LeaveCombat()
    noErrors()
end)

-- Battle Shout drawn by Daylight UI's aura icon holder, its buff down: the missing
-- glow on the holder, a frame Daylight UI doesn't hold. The rule is saved first, so
-- the pass that builds the holder also lights it.
local function shoutWorld(style)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[SHOUT] = { name = "Battle Shout" }
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = true
    local styleOf = watchStyles(DUI)
    local AB = stub.actionbars
    local key = CW.ID(SHOUT, BUFFS)
    local D = AB.CdmData
    local set = D.Ensure(1)
    D.AddPiece(set, key, "icon", 0, 0)
    D.SetSpellValue(set, key, "missingGlow", true)
    local profile = ns.Bridge.SavedProfile(1)
    EZCDMDB = EZCDMDB or {}
    EZCDMDB.glowStyle = { [profile] = { [key] = style and { missing = style } or nil } }
    T.isnil(AB.CdmAuras.Frame(key), "no holder yet")
    pass(AB)
    T.eq(AB.CdmRows.DrawnBy(key), "aura icon", "Daylight UI's aura icon holder draws it")
    return DUI, ns, AB, key, styleOf
end

T.test("glow style: a holder's glow takes its moment's style, lit in the pass that builds it", function()
    local _, _, AB, key, styleOf = shoutWorld("comet")
    local h = AB.CdmAuras.Frame(key)
    T.eq(styleOf(AB, h), "comet", "the missing glow on the holder, as a Comet")
    pass(AB)
    T.eq(styleOf(AB, h), "comet", "the next pass keeps it")
    noErrors()
    -- With no style of its own, Daylight UI's ring, as before.
    local _, _, AB2, key2, styleOf2 = shoutWorld(nil)
    T.eq(styleOf2(AB2, AB2.CdmAuras.Frame(key2)), "ring")
    noErrors()
end)

T.test("glow style: one pass with two moments uses the right style for each", function()
    local _, ns, AB, shout, styleOf = shoutWorld("shine")
    local rend = CW.ID(REND, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), rend, "icon", 60, 0)
    pass(AB)
    T.truthy(ns.Draft.Write(rend, { lines = { SL("ready", "comet"), SL("recast", "breathe", nil, 5) } }))
    pass(AB)
    fightAndCast()
    wait(4.1)
    local h = AB.CdmAuras.Frame(shout)
    -- One pass tells both: Battle Shout's holder is missing, Rend about to fall off.
    pass(AB)
    T.eq(styleOf(AB, h), "shine", "Battle Shout: missing")
    T.eq(styleOf(AB, rend), "breathe", "Rend: about to fall off")
    -- A cooldown event re-asks Rend's lit glow outside a pass.
    AB.CdmEffects.UpdateAll()
    T.eq(styleOf(AB, rend), "breathe")
    T.eq(styleOf(AB, h), "shine")
    stub.LeaveCombat()
    noErrors()
end)

T.test("glow style: the styles live in EZCDMDB by profile, piece and moment, and round-trip", function()
    local _, ns, AB, k = styleWorld()
    local Draft = ns.Draft
    local GOLD = { 1, 0.8, 0 }
    local lines = { SL("ready", "comet", GOLD), SL("recast", "breathe", nil, 5) }
    local ok, report = Draft.Write(k.rend, { lines = lines })
    T.truthy(ok)
    local profile = ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.glowStyle[profile][k.rend], { ready = "comet", recast = "breathe" }, "by profile, piece, moment")
    local p = AB.CdmData.Get(1).pieces[k.rend]
    T.isnil(p.ezStyles, "never in Daylight UI's layout")
    T.isnil(p.glowStyle, "the piece's own style untouched")
    local kinds = {}
    for _, c in ipairs(report.changed) do kinds[#kinds + 1] = c.kind .. ":" .. c.field end
    table.sort(kinds)
    T.eq(table.concat(kinds, " "), "ez:fallOff ez:glowStyles set:clipGlow set:readyGlow set:readyGlowColor")
    local rules = Draft.Rules(k.rend)
    T.deq(rules.lines, lines, "reads back as the same lines")
    T.eq(select(2, Draft.Write(k.rend, rules)).changes, 0, "a second write writes nothing")
    -- One style off: the other stays.
    T.truthy(Draft.Write(k.rend, { lines = { SL("ready", nil, GOLD), SL("recast", "breathe", nil, 5) } }))
    T.deq(EZCDMDB.glowStyle[profile][k.rend], { recast = "breathe" })
    T.truthy(Draft.Write(k.rend, { lines = {} }))
    T.isnil(EZCDMDB.glowStyle[profile], "nothing left for the profile")
    stub.EnterCombat()
    local okc, why = ns.Effects.SetStyles(1, k.rend, { ready = "comet" })
    T.falsy(okc); T.eq(why, "combat")
    stub.LeaveCombat()
    noErrors()
end)

-- ---------------------------------------------------------------------
-- A proc EZ-CDM draws has no fall-off moment (docs/tasks/done/scrap-proc-lead.md):
-- Improved Stormstrike's aura is secret in a fight, so nothing can time its end.
-- ---------------------------------------------------------------------

-- Improved Stormstrike's length, once Daylight UI's holder has read it.
local PROC_LASTS = 15

T.test("proc: a proc EZ-CDM draws offers no fall-off glow or sound, even with a known length", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    -- Out of a fight the holder reads the proc's length, as it did for the old ring.
    local h = AB.CdmAuras.Frame(key)
    CW.Aura("player", next(h.ids), { duration = PROC_LASTS }); stub.RunTimers()
    AB.CdmAuras.Read(h)
    T.eq(ns.Bridge.AuraLasts(key), PROC_LASTS, "the length is known")
    local kind = ns.Draft.Kind(key)
    T.truthy(kind.ezGlow and kind.proc, "your own proc, drawn in the client's buttons")
    T.falsy(kind.cast, "never cast")
    for _, a in ipairs({ "glow", "sound" }) do
        T.falsy(ns.Grammar.Fits(kind, "recast", a), "no fall-off " .. a)
    end
    for _, w in ipairs(ns.Grammar.Words(kind)) do
        T.truthy(w.moment ~= "recast", "no fall-off moment in its words")
    end
    -- The line is refused, and nothing is saved for it.
    local bad, why = ns.Draft.Write(key, { lines = { { moment = "recast", action = "glow", at = 5 } } })
    T.falsy(bad); T.eq(why, "problems")
    T.isnil(ns.Effects.FallOff(key))
    noErrors()
end)

T.test("proc: the up ring still lights in a fight, alone in each button", function()
    local _, ns, AB, key = procWorld({ holder = true, rule = RED })
    T.truthy(ns.Grammar.Fits(ns.Draft.Kind(key), "up", "glow"), "While it's active, glow")
    local list = buttons(AB, key)
    T.truthy(#list > 0)
    for i, btn in ipairs(list) do
        local r = ns.Effects.Ring(btn)
        T.truthy(r, "button " .. i .. ": the up ring")
        T.eq(#btn.__shownAnims, 2, "button " .. i .. ": Daylight UI's slide and the ring's loop, no hold")
        T.eq(r.frame:GetAlpha(), 1)
    end
    local btn = list[1]
    local r = ns.Effects.Ring(btn)
    stub.EnterCombat(); stub.RunTimers()
    stub.AuraAssign(btn, true)
    stub.Advance(12)
    T.truthy(r.anim:IsPlaying() and r.tex:IsVisible(), "12 s in: still the up ring")
    stub.AuraAssign(btn, false)
    T.falsy(r.anim:IsPlaying())
    stub.LeaveCombat(); stub.RunTimers()
    T.truthy(ns.Effects.Ring(btn), "a fight's end leaves it in place")
    noErrors()
end)

T.test("proc: an earlier build's saved fall-off ring is dropped as EZ-CDM loads", function()
    -- The profile and keys, from a plain load.
    local _, ns0, _, key = procWorld({ holder = true })
    local profile = ns0.Bridge.SavedProfile(1)
    local other = CW.ID(8050, 0)
    local saved = {
        upGlow = { [profile] = { [key] = RED } },
        fallOff = { [profile] = { [key] = { lead = 5, ring = BLUE }, [other] = { lead = 4, sound = "ding" } },
                    Old = { [key] = { lead = 3, ring = true } } },
        procLasts = { [key] = PROC_LASTS },
    }
    local _, ns, AB = procWorld({ holder = true, saved = saved })
    T.isnil(EZCDMDB.fallOff[profile][key], "the proc's ring rule is gone")
    T.deq(EZCDMDB.fallOff[profile][other], { lead = 4, sound = "ding" }, "another piece's lead stays")
    T.isnil(EZCDMDB.fallOff.Old, "a profile left with nothing goes")
    T.isnil(EZCDMDB.procLasts, "the kept lengths go")
    T.deq(EZCDMDB.upGlow[profile][key], RED, "the up ring's rule stays")
    T.isnil(ns.Effects.FallOff(key))
    T.deq(ns.Draft.Rules(key).lines, { L("up", "glow", RED) }, "reads back as the up line alone")
    T.isnil(pieceOf(AB, key).clipGlow, "Daylight UI's clipGlow untouched")
    for i, btn in ipairs(buttons(AB, key)) do
        T.eq(#btn.__shownAnims, 2, "button " .. i .. ": the slide and the up ring only")
    end
    noErrors()
end)
