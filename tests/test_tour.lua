local stub = require("stub")
local CW = require("cdmworld")
local IPW = require("infopanelworld")

-- EZ-CDM/Tour.lua: the first-run tour on Daylight UI's own tour card (Tour.lua),
-- over Daylight UI's real CDM editor with EZ-CDM's start block and drawer (cdmworld,
-- a warrior).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871
local ESSENTIAL, UTILITY, BUFFS = 0, 1, 2

-- Daylight UI with its info panel, the game's Cooldown Manager and EZ-CDM, logged in.
local function world()
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

T.test("tour: each step lights an EZ-CDM part that is on screen", function()
    local DUI, ns, AB, k = layoutWorld()
    local Ed = AB.CdmEditor
    Ed.Open(); stub.RunTimers()
    Ed.Select(k.clap); stub.RunTimers()
    local W = ns.Grammar.WORDING
    local want = {
        start = function() return ns.Start.Frame() end,
        pick = function() return Ed.PreviewOf(k.clap) end,
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

T.test("tour: the pick step moves on once a spell is picked, and the light finds it", function()
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
    Ed.Select(k.rage); stub.RunTimers()
    DaylightUITour:GetScript("OnUpdate")(DaylightUITour, 1); stub.RunTimers()
    T.eq(DUI.Tour.StepId(), "drawer", "a spell picked: on to the drawer")
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
