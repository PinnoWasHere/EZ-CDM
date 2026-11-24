local stub = require("stub")
local CW = require("cdmworld")
local IPW = require("infopanelworld")

-- EZ-CDM/Tour.lua: the first-run tour on Daylight UI's own tour card (Tour.lua),
-- over Daylight UI's real CDM editor with EZ-CDM's start block and drawer (cdmworld,
-- a warrior).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871
local ESSENTIAL, UTILITY, BUFFS = 0, 1, 2

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

-- Daylight UI with its info panel, the game's Cooldown Manager and EZ-CDM, logged in.
-- db = { dui, ez }: the saved variables of an earlier session (a /reload).
local function world(db)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, infopanel = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, BLOCK, RAGE, CLAP, WALL }, showAll = true })
        for id, name in pairs({ [SHOUT] = "Battle Shout", [REND] = "Rend", [BLOCK] = "Shield Block",
                                [RAGE] = "Bloodrage", [CLAP] = "Thunder Clap", [WALL] = "Shield Wall" }) do
            stub.spells[id] = { name = name }
        end
        IPW.Install()
        if db then
            DaylightUIDB = copy(db.dui)
            EZCDMDB = copy(db.ez)
        end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    DUI:Set("general", "motion", false)
    return DUI, ns, stub.actionbars
end

-- A saved layout on talent set 1: Rend - Thunder Clap - Shield Wall in a group, and
-- Bloodrage on its own. A player with a layout gets no Daylight UI layout tour.
local function layoutWorld()
    local DUI, ns, AB = world()
    local D = AB.CdmData
    local set = D.Ensure(1)
    local k = { rend = CW.ID(REND, ESSENTIAL), clap = CW.ID(CLAP, ESSENTIAL), wall = CW.ID(WALL, BUFFS),
        rage = CW.ID(RAGE, UTILITY) }
    D.AddPiece(set, k.rend, "icon", 0, 0)
    D.AddPiece(set, k.clap, "icon", 0, 0)
    D.Hook(set, k.clap, k.rend, "right", "center")
    D.AddPiece(set, k.wall, "icon", 0, 0)
    D.Hook(set, k.wall, k.clap, "right", "center")
    D.AddPiece(set, k.rage, "bar", 0, -200)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, AB, k
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

local function ours(ns) return ns.Tour.Running() end

local function seen() return type(EZCDMDB) == "table" and EZCDMDB.tourSeen == true end

-- Walks the running tour to its end with Next.
local function finishTour(DUI)
    for _ = 1, 20 do
        if not DUI.Tour.Running() then return end
        DUI.Tour.Next(); stub.RunTimers()
    end
end

-- The drawer body's shown blocks.
local function body(ns)
    local out = {}
    for _, b in ipairs(ns.Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() then out[#out + 1] = b end
    end
    return out
end

-- The first token in the drawer body that matches(t).
local function token(ns, matches)
    for _, b in ipairs(body(ns)) do
        for _, t in ipairs(b.tokens or {}) do
            if t:IsShown() and matches(t, b) then return t end
        end
    end
end

T.test("tour: shows once, on the first /cdm with EZ-CDM, on Daylight UI's own tour card", function()
    local DUI, ns, AB = layoutWorld()
    local Ed = AB.CdmEditor
    T.falsy(seen(), "not seen yet")
    T.truthy(Ed.Open()); stub.RunTimers()
    T.eq(AB.CdmGuide.Running(), false, "a player with a layout gets no Daylight UI layout tour")
    T.truthy(ours(ns), "EZ-CDM's tour comes with the first open")
    T.truthy(DUI.Tour.Running(ns.Tour.KEY), "run by Daylight UI's own tour engine")
    T.eq(DUI.Tour.StepId(), "start")
    T.eq(DUI.Tour.card.skip.text:GetText(), "Skip tour", "Daylight UI's own card")
    T.eq(DaylightUITour:IsMouseEnabled(), false, "the mouse reaches the editor, so each step can be tried")
    finishTour(DUI)
    T.falsy(ours(ns), "Done ends it")
    T.truthy(seen(), "saved in EZCDMDB")
    Ed.Close(); T.truthy(Ed.Open()); stub.RunTimers()
    T.falsy(ours(ns), "once")
    noErrors()
end)

T.test("tour: closing the editor ends it, and the next open shows it again", function()
    local DUI, ns, AB = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open(); stub.RunTimers()
    T.truthy(ours(ns))
    Ed.Close()
    T.falsy(ours(ns), "gone with the editor")
    T.falsy(seen(), "not finished, so not seen")
    Ed.Open(); stub.RunTimers()
    T.truthy(ours(ns), "back on the next open")
    noErrors()
end)

T.test("tour: never in a fight", function()
    local DUI, ns, AB = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open()
    stub.EnterCombat()      -- before the tour's delay ran out
    stub.RunTimers()
    T.falsy(ours(ns), "a fight before it starts keeps it away")
    T.falsy(seen())
    T.eq(ns.Tour.Replay(), false, "Replay refuses in a fight")
    T.falsy(ours(ns))
    stub.LeaveCombat()
    Ed.Open(); stub.RunTimers()
    T.truthy(ours(ns), "after the fight, the next open")
    stub.EnterCombat()
    T.falsy(ours(ns), "a fight ends it")
    T.falsy(seen(), "a fight's end isn't a skip")
    stub.LeaveCombat()
    noErrors()
end)

T.test("tour: waits for Daylight UI's own layout tour on the same open", function()
    local DUI, ns, AB = world()
    local Ed = AB.CdmEditor
    T.falsy(DUI.DB.Root().cdmGuideSeen)
    Ed.Open(); stub.RunTimers()
    T.eq(AB.CdmGuide.Running(), true, "Daylight UI's layout tour first")
    T.falsy(ours(ns), "EZ-CDM's waits")
    DUI.Tour.Next(); stub.RunTimers()
    T.eq(AB.CdmGuide.Running(), true)
    T.falsy(ours(ns), "still waiting")
    DUI.Tour.Skip(); stub.RunTimers()
    T.eq(AB.CdmGuide.Running(), false)
    T.truthy(ours(ns), "EZ-CDM's tour follows it")
    T.eq(DUI.Tour.StepId(), "start")
    noErrors()
end)

T.test("tour: Skip tour saves the flag and says how to replay it", function()
    local DUI, ns, AB = layoutWorld()
    T.truthy(ns.Tour.WHERE, "Settings.lua names the Replay Tour row")
    AB.CdmEditor.Open(); stub.RunTimers()
    T.truthy(ours(ns))
    DUI.Tour.OnKey("ESCAPE")
    T.falsy(ours(ns), "Escape skips it")
    T.truthy(seen(), "a skip counts as seen")
    local text = DUI.Tour.toast.text:GetText()
    T.truthy(string.find(tostring(text), ns.Grammar.WORDING.tour.replay, 1, true), "the toast names Replay tour: " .. tostring(text))
    AB.CdmEditor.Close(); AB.CdmEditor.Open(); stub.RunTimers()
    T.falsy(ours(ns), "not again")
    noErrors()
end)

T.test("tour: Replay runs it again, opening the editor when it's shut", function()
    local DUI, ns, AB = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open(); stub.RunTimers()
    DUI.Tour.Skip()
    Ed.Close()
    T.truthy(seen())
    T.eq(ns.Tour.Replay(), true)
    stub.RunTimers()
    T.truthy(Ed.IsOpen(), "the editor opens")
    T.truthy(ours(ns), "the tour runs")
    T.eq(DUI.Tour.StepId(), "start", "from its first step")
    T.eq(ns.Tour.Replay(), false, "not twice at once")
    finishTour(DUI)
    T.eq(ns.Tour.Replay(), true, "with the editor open")
    stub.RunTimers()
    T.truthy(ours(ns))
    noErrors()
end)

T.test("tour: each step lights an EZ-CDM part that is on screen, on the demo spell", function()
    local DUI, ns, AB, k = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open(); stub.RunTimers()
    Ed.Select(k.clap); stub.RunTimers()
    local demo = ns.Tour.Demo()
    T.truthy(demo, "a demo spell")
    local W = ns.Grammar.WORDING
    local want = {
        start = function() return ns.Start.Frame() end,
        pick = function() return Ed.PreviewOf(demo) end,
        drawer = function() return ns.Drawer.Clip() end,
        word = function() return token(ns, function(t) return t.piece and t.piece.kind == "link" end) end,
        line = function() return token(ns, function(t) return t.piece and t.piece.word == "line" end) end,
        recipe = function() return token(ns, function(t) return t.piece and t.piece.word == "recipe" end) end,
        group = function() return token(ns, function(t) return t.piece and t.piece.word == "group" end) end,
        report = function() return token(ns, function(_, b) return b.copy end) end,
    }
    local order = {}
    for _, step in ipairs(ns.Tour.STEPS) do order[#order + 1] = step.id end
    T.eq(table.concat(order, " "), "start pick drawer word line recipe group report")
    for i, step in ipairs(ns.Tour.STEPS) do
        T.eq(DUI.Tour.StepId(), step.id, "step " .. i)
        if i > 2 then T.eq(ns.Drawer.Key(), demo, step.id .. ": the drawer shows the demo") end
        if step.id == "pick" then
            for name, key in pairs(k) do T.falsy(step.part() == Ed.PreviewOf(key), "pick: not " .. name) end
        end
        local f = want[step.id]()
        T.truthy(f, step.id .. ": its part exists")
        T.eq(step.part(), f, step.id .. ": lights it")
        T.truthy(f:IsVisible(), step.id .. ": on screen")
        local title = type(step.title) == "function" and step.title() or step.title
        local text = type(step.text) == "function" and step.text() or step.text
        T.truthy(type(title) == "string" and title ~= "", step.id .. ": a title")
        T.truthy(type(text) == "string" and text ~= "", step.id .. ": a text")
        DUI.Tour.Next(); stub.RunTimers()
    end
    T.falsy(ours(ns), "Done after the last")
    T.truthy(W.tour.replay ~= nil)
    noErrors()
end)

T.test("tour: the pick step moves on once the demo is picked, and the light finds it", function()
    local DUI, ns, AB, k = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open()
    -- The start block is on screen before the tour's delay runs out.
    local blk = ns.Start.Frame()
    blk.GetLeft = function() return 1010 end
    blk.GetBottom = function() return 16 end
    blk.GetRight = function() return 1250 end
    blk.GetTop = function() return 140 end
    stub.RunTimers()
    T.eq(DUI.Tour.StepId(), "start")
    T.eq(DUI.Tour.Lit(), blk, "the start block lit")
    DUI.Tour.Next(); stub.RunTimers()
    T.eq(DUI.Tour.StepId(), "pick")
    local demo = ns.Tour.Demo()
    T.eq(ns.Tour.STEPS[2].part(), Ed.PreviewOf(demo), "the demo lit, never a spell of the player's")
    Ed.Select(k.rage); stub.RunTimers()
    DaylightUITour:GetScript("OnUpdate")(DaylightUITour, 1); stub.RunTimers()
    T.eq(DUI.Tour.StepId(), "pick", "a spell of the player's isn't the one it asks for")
    Ed.Select(demo); stub.RunTimers()
    DaylightUITour:GetScript("OnUpdate")(DaylightUITour, 1); stub.RunTimers()
    T.eq(DUI.Tour.StepId(), "drawer", "the demo picked: on to the drawer")
    noErrors()
end)

T.test("tour: Settings' Replay Tour row runs it again", function()
    local DUI, ns, AB = layoutWorld()
    local row
    for _, g in ipairs(ns.Settings.GROUPS) do
        for _, item in ipairs(g.items) do
            if item.label == ns.Grammar.WORDING.tour.replay then row = item end
        end
    end
    T.truthy(row, "a Replay Tour row")
    T.eq(row.type, "button")
    local words = 0
    for _ in row.label:gmatch("%S+") do words = words + 1 end
    T.truthy(words <= 4, "a label of four words or fewer")
    EZCDMDB = EZCDMDB or {}
    EZCDMDB.tourSeen = true
    row.func(); stub.RunTimers()
    T.truthy(AB.CdmEditor.IsOpen(), "the editor opens")
    T.truthy(ours(ns), "the tour runs")
    noErrors()
end)

T.test("tour: with Show Start Block off, it starts at the pick step", function()
    local DUI, ns, AB = layoutWorld()
    ns.Settings.Set("startBlock", false)
    AB.CdmEditor.Open(); stub.RunTimers()
    T.falsy(ns.Start.Shown(), "no start block")
    T.truthy(ours(ns))
    T.eq(DUI.Tour.StepId(), "pick", "the start step is left out")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The demo spell: placed for the tour, gone after it
-- ---------------------------------------------------------------------

-- Talent set 1's saved layout.
local function layout(AB) return AB.CdmData.Profile(AB.CdmData.Use(1)).set end

-- EZCDMDB without the flag a finished tour sets.
local function ezState()
    local db = copy(type(EZCDMDB) == "table" and EZCDMDB or {})
    db.tourSeen = nil
    return db
end

local function snap(AB) return { set = copy(layout(AB)), ez = ezState() } end

local function unchanged(AB, before, what)
    T.deq(layout(AB), before.set, what .. ": layout")
    T.deq(ezState(), before.ez, what .. ": EZCDMDB")
end

-- Next until the tour stands on step id.
local function walkTo(DUI, id)
    for _ = 1, 20 do
        if DUI.Tour.StepId() == id or not DUI.Tour.Running() then return end
        DUI.Tour.Next(); stub.RunTimers()
    end
end

local function stepOf(ns, id)
    for _, step in ipairs(ns.Tour.STEPS) do
        if step.id == id then return step end
    end
end

T.test("tour: an empty layout gets a demo spell, and it goes when the tour ends", function()
    local DUI, ns, AB = world()
    local Ed = AB.CdmEditor
    DUI.DB.Root().cdmGuideSeen = true
    -- An open without the tour first, so EZ-CDM has made its saved tables.
    EZCDMDB = EZCDMDB or {}
    EZCDMDB.tourSeen = true
    Ed.Open(); stub.RunTimers(); Ed.Close()
    EZCDMDB.tourSeen = nil
    Ed.Open()
    local before = snap(AB)
    T.eq(next(before.set.pieces), nil, "nothing placed")
    stub.RunTimers()
    T.truthy(ours(ns))
    local demo = ns.Tour.Demo()
    T.truthy(demo, "a demo spell")
    T.truthy(layout(AB).pieces[demo], "placed in the layout")
    T.truthy(Ed.PreviewOf(demo):IsVisible(), "on screen")
    T.truthy(EZCDMDB.tourDemo, "a marker for the next login")
    finishTour(DUI); stub.RunTimers()
    T.isnil(ns.Tour.Demo(), "gone")
    T.truthy(seen())
    unchanged(AB, before, "done")
    noErrors()
end)

T.test("tour: the demo is a known cooldown the player hasn't placed", function()
    local DUI, ns, AB, k = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open()
    local before = snap(AB)
    stub.RunTimers()
    local demo = ns.Tour.Demo()
    T.truthy(demo)
    T.isnil(before.set.pieces[demo], "not one of the player's")
    local entry
    for _, e in ipairs(Ed.Spells()) do
        if e.id == demo then entry = e end
    end
    T.truthy(entry, "on the tray")
    T.falsy(entry.unlearned, "known")
    T.falsy(entry.aura, "a cooldown, not a buff")
    for key, p in pairs(before.set.pieces) do T.deq(layout(AB).pieces[key], p, "the player's " .. tostring(key)) end
    noErrors()
end)

T.test("tour: the recipe step puts Ready alert on the demo, never on the player's spells", function()
    local DUI, ns, AB, k = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open()
    local before = snap(AB)
    stub.RunTimers()
    local demo = ns.Tour.Demo()
    walkTo(DUI, "recipe")
    T.eq(DUI.Tour.StepId(), "recipe")
    T.eq(ns.Drawer.Key(), demo)
    local rules = ns.Draft.Rules(demo)
    local ready = {}
    for _, l in ipairs(rules.lines) do
        if l.moment == "ready" then ready[l.action] = true end
    end
    T.truthy(ready.glow and ready.sound, "Ready alert's lines on the demo")
    for key, p in pairs(before.set.pieces) do T.deq(layout(AB).pieces[key], p, "the player's " .. tostring(key)) end
    noErrors()
end)

-- Each way a tour can end, from the recipe step with the drawer folded at the start.
local ENDINGS = {
    done = function(DUI) finishTour(DUI) end,
    skip = function(DUI) DUI.Tour.Skip() end,
    escape = function(DUI) DUI.Tour.OnKey("ESCAPE") end,
    close = function(_, _, AB) AB.CdmEditor.Close() end,
    fight = function(_, ns, AB, demo)
        stub.EnterCombat(); stub.RunTimers()
        T.falsy(ours(ns), "a fight ends it")
        T.truthy(layout(AB).pieces[demo], "no layout write in a fight")
        stub.LeaveCombat()
    end,
    error = function(DUI, ns)
        stepOf(ns, "group").enter = function() error("a broken step") end
        DUI.Tour.Next()
    end,
}

for _, how in ipairs({ "done", "skip", "escape", "close", "fight", "error" }) do
    T.test("tour: " .. how .. " removes the demo and leaves the layout and EZCDMDB as they were", function()
        local DUI, ns, AB = layoutWorld()
        local Ed = AB.CdmEditor
        ns.Drawer.SetExpanded(false)
        Ed.Open()
        local before = snap(AB)
        stub.RunTimers()
        local demo = ns.Tour.Demo()
        T.truthy(demo)
        walkTo(DUI, "recipe")
        T.truthy(ns.Drawer.Expanded(), "the tour opened the drawer")
        ENDINGS[how](DUI, ns, AB, demo)
        stub.RunTimers()
        T.falsy(ours(ns), "ended")
        T.isnil(ns.Tour.Demo(), "no demo")
        T.isnil(layout(AB).pieces[demo], "the demo is gone")
        unchanged(AB, before, how)
        if how ~= "error" then noErrors() end
    end)
end

T.test("tour: a /reload mid-tour removes the demo at the next login", function()
    local DUI, ns, AB = layoutWorld()
    local Ed = AB.CdmEditor
    ns.Drawer.SetExpanded(false)
    Ed.Open()
    local before = snap(AB)
    stub.RunTimers()
    local demo = ns.Tour.Demo()
    walkTo(DUI, "group")
    T.truthy(layout(AB).pieces[demo])
    local db = { dui = copy(DaylightUIDB), ez = copy(EZCDMDB) }
    DUI, ns = world(db)
    AB = stub.actionbars
    stub.RunTimers()
    T.isnil(layout(AB).pieces[demo], "gone after the login")
    T.isnil(EZCDMDB.tourDemo, "the marker too")
    unchanged(AB, before, "reload")
    noErrors()
end)

T.test("tour: Replay twice leaves no demo behind", function()
    local DUI, ns, AB = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open()
    local before = snap(AB)
    stub.RunTimers()
    finishTour(DUI); stub.RunTimers()
    T.eq(ns.Tour.Replay(), true); stub.RunTimers()
    T.truthy(ns.Tour.Demo(), "a fresh demo")
    walkTo(DUI, "recipe")
    DUI.Tour.Skip(); stub.RunTimers()
    unchanged(AB, before, "replay")
    noErrors()
end)

T.test("tour: the start block's Blank takes the demo out of the old layout first", function()
    local DUI, ns, AB = layoutWorld()
    local Ed, D = AB.CdmEditor, AB.CdmData
    Ed.Open()
    local old = D.Use(1)
    local before = snap(AB)
    stub.RunTimers()
    local demo = ns.Tour.Demo()
    walkTo(DUI, "recipe")
    T.truthy(layout(AB).pieces[demo])
    local S = ns.Start.Parts()
    S.picker.cards.blank:Click()
    S.input:SetText("Raid night")
    S.create:Click()
    stub.RunTimers()
    T.truthy(D.Use(1) ~= old, "a new layout")
    T.deq(D.Profile(old).set, before.set, "the old layout as it was")
    T.isnil(layout(AB).pieces[demo], "not in the new one")
    T.isnil(ns.Tour.Demo())
    finishTour(DUI); stub.RunTimers()
    T.isnil(EZCDMDB.tourDemo, "the marker goes with the tour")
    T.deq(D.Profile(old).set, before.set, "still as it was")
    T.deq(ezState(), before.ez, "EZCDMDB as it was")
    noErrors()
end)

-- Blizzard's rules on automation: the tour changes only Daylight UI's layout,
-- its editor's pick and EZ-CDM's lines. It never acts in the game for the player.
local GAME_ACTIONS = {
    "CastSpell", "CastSpellByName", "CastSpellByID", "CastPetAction", "CastShapeshiftForm",
    "UseAction", "UseItemByName", "UseInventoryItem", "UseContainerItem", "UseToy", "UseToyByName",
    "TargetUnit", "TargetNearest", "TargetNearestEnemy", "TargetLastTarget", "AssistUnit", "FocusUnit",
    "ClearTarget", "ClearFocus", "InteractUnit", "StartAttack", "StopAttack", "PetAttack",
    "AttackTarget", "SpellStopCasting", "SpellTargetUnit", "CancelUnitBuff",
    "MoveForwardStart", "MoveBackwardStart", "StrafeLeftStart", "StrafeRightStart", "TurnLeftStart",
    "TurnRightStart", "JumpOrAscendStart", "ToggleAutoRun", "ToggleRun", "FollowUnit",
    "RunBinding", "SetBinding", "SetBindingClick", "SetBindingSpell", "SetOverrideBinding",
    "SetOverrideBindingClick", "RunMacro", "RunMacroText", "DoEmote",
    "SendChatMessage", "SendAddonMessage", "BNSendWhisper",
}

T.test("tour: Tour.lua never acts in the game for the player", function()
    local H = require("ez_harness")
    local f = assert(io.open(H.ROOT .. "Tour.lua", "rb"))
    local src = f:read("*a")
    f:close()
    -- Code only: long comments, then line comments.
    src = src:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
    local found = {}
    for _, name in ipairs(GAME_ACTIONS) do
        if src:find("%f[%w_]" .. name .. "%f[^%w_]") then found[#found + 1] = name end
    end
    for _, pat in ipairs({ ":Click%s*%(", "SetAttribute", "Secure%w*Template", "C_ChatInfo", "ChatFrame_" }) do
        if src:find(pat) then found[#found + 1] = pat end
    end
    T.eq(table.concat(found, ", "), "", "game actions in Tour.lua")
end)
