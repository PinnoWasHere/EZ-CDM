local _, ns = ...

-- The first-run tour: short stops over EZ-CDM's parts in Daylight UI's CDM editor,
-- each lighting the part it talks about. It runs on Daylight UI's own tour engine
-- (Tour.lua, through ns.Bridge), the one its /cdm layout tour runs on, so the dim,
-- the light, the card, Back, Next, Skip tour and the skipped line are all Daylight
-- UI's. The mouse reaches the editor the whole time, so the player tries each thing
-- while reading.
--
-- It comes with the first open of the editor, after Daylight UI's own layout tour
-- when that one runs on the same open. Done or Skip tour saves EZCDMDB.tourSeen.
-- Closing the editor or a fight ends it without saving, so the next open shows it.
-- Tour.Replay() runs it again. The words are Grammar.WORDING.tour's.

local Bridge, Grammar = ns.Bridge, ns.Grammar
local API = DaylightUI.API
local WORDING = Grammar.WORDING
local WORDS = WORDING.tour

local Tour = {}
ns.Tour = Tour

-- Debug handle for an in-game check.
EZCDM_Tour = Tour

Tour.KEY = "ezcdm"
-- After the editor opens: past Daylight UI's layout tour's own wait (CdmGuide.DELAY
-- 0.3), so that one starts first when it comes.
Tour.DELAY = 0.5
-- How often a waiting tour looks again while another tour runs.
Tour.POLL = 0.5
-- Where Replay Tour lives, { row, group }, named in the skipped line. Settings.lua
-- sets it with its row. Nil: no skipped line.
Tour.WHERE = nil

local waiting -- the token of a start waiting for its delay or another tour
local start = {}

local function savedVars()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    return EZCDMDB
end

function Tour.Seen() return savedVars().tourSeen == true end

local function pop(text) return Bridge.TourPop(text) end

-- ---------------------------------------------------------------------
-- What each stop lights
-- ---------------------------------------------------------------------

local function shown(f) return f ~= nil and f:IsVisible() and f or nil end

local function drawer() return shown(ns.Drawer.Clip()) end

-- The first shown token in the drawer's body that matches(t, block).
local function bodyToken(matches)
    local s = ns.Drawer.Parts().bodyStack
    for _, b in ipairs(s and s.pieces or {}) do
        if b:IsShown() then
            for _, t in ipairs(b.tokens or {}) do
                if t:IsShown() and matches(t, b) then return t end
            end
        end
    end
end

-- The add link for word ("line", "recipe", "group"), else the drawer.
local function addLink(word)
    return function()
        return bodyToken(function(t) return t.piece ~= nil and t.piece.word == word end) or drawer()
    end
end

-- The picked spell on screen, else the first placed one, else the tray.
local function somePiece()
    local key = ns.Drawer.Key() or Bridge.Selected()
    local f = key ~= nil and shown(Bridge.PiecePreview(key))
    if f then return f end
    local first
    for k in pairs((Bridge.Layout() or {}).pieces or {}) do
        if first == nil or tostring(k) < tostring(first) then first = k end
    end
    return first ~= nil and shown(Bridge.PiecePreview(first)) or Bridge.EditorTray()
end

-- ---------------------------------------------------------------------
-- The stops
-- ---------------------------------------------------------------------

Tour.STEPS = {
    { id = "start",
      title = WORDS.start.title,
      text = function() return WORDS.start.text:format(pop(WORDING.start.blank), pop(WORDING.start.load)) end,
      -- Settings' Show Start Block off: no block, no stop.
      available = function() return ns.Start.Shown() end,
      part = function() return ns.Start.Frame() end },
    { id = "pick",
      title = WORDS.pick.title,
      text = WORDS.pick.text,
      enter = function() start.key = ns.Drawer.Key() end,
      part = somePiece,
      follow = true,
      done = function()
          local key = ns.Drawer.Key()
          return key ~= nil and key ~= start.key
      end },
    { id = "drawer",
      title = WORDS.drawer.title,
      text = function() return WORDS.drawer.text:format(pop(ns.Drawer.TAB_LABEL)) end,
      enter = function()
          if not ns.Drawer.Expanded() then ns.Drawer.SetExpanded(true) end
      end,
      part = function() return ns.Drawer.Clip(), ns.Drawer.Tab() end,
      follow = true },
    { id = "word",
      title = WORDS.word.title,
      text = WORDS.word.text,
      part = function()
          return bodyToken(function(t) return t.piece ~= nil and t.piece.kind == "link" end) or drawer()
      end,
      follow = true },
    { id = "line",
      title = WORDS.line.title,
      text = function() return WORDS.line.text:format(pop(WORDING.addLine)) end,
      part = addLink("line"),
      follow = true },
    { id = "recipe",
      title = WORDS.recipe.title,
      text = function() return WORDS.recipe.text:format(pop(WORDING.addRecipe), pop(WORDING.recipes.readyAlert)) end,
      part = addLink("recipe"),
      follow = true },
    { id = "group",
      title = WORDS.group.title,
      text = function() return WORDS.group.text:format(pop(WORDING.addGroup), pop(WORDING.group.combat.on)) end,
      part = addLink("group"),
      follow = true },
    { id = "report",
      title = WORDS.report.title,
      text = function() return WORDS.report.text:format(pop(WORDING.copyReport)) end,
      available = function() return Bridge.CanShowText() end,
      part = function()
          return bodyToken(function(_, b) return b.copy == true end) or drawer()
      end,
      follow = true },
}

-- The stops this Daylight UI can show, in order.
local function stops()
    local list = {}
    for _, step in ipairs(Tour.STEPS) do
        if not step.available or step.available() then list[#list + 1] = step end
    end
    return list
end

-- ---------------------------------------------------------------------
-- Running
-- ---------------------------------------------------------------------

function Tour.Running() return Bridge.TourRunning(Tour.KEY) end
function Tour.Waiting() return waiting ~= nil end

local function run()
    return Bridge.RunTour(stops(), {
        key = Tour.KEY,
        through = true,
        skipped = Tour.WHERE and WORDS.skipped:format(pop(Tour.WHERE[1]), pop(Tour.WHERE[2])) or nil,
        finished = function() savedVars().tourSeen = true end,
    })
end

-- Starts once the editor is open, out of a fight, with no other tour running.
local function try(token)
    if waiting ~= token then return end
    if not Bridge.EditorOpen() or InCombatLockdown() then
        waiting = nil
        return
    end
    if Bridge.TourRunning() then
        C_Timer.After(Tour.POLL, function() try(token) end)
        return
    end
    waiting = nil
    run()
end

local function queue()
    local token = {}
    waiting = token
    C_Timer.After(Tour.DELAY, function() try(token) end)
end

-- Runs the tour again, opening the editor if it's shut. False in a fight, while
-- it runs or waits, or when Daylight UI has no tour engine.
function Tour.Replay()
    if InCombatLockdown() or waiting or Tour.Running() then return false end
    if not (Bridge.Ready() and Bridge.CanTour()) then return false end
    if not (Bridge.EditorOpen() or Bridge.OpenEditor()) then return false end
    queue()
    return true
end

-- The editor opened: the first time, the tour comes with it.
local function offer()
    if Tour.Seen() or waiting or Tour.Running() or not Bridge.CanTour() then return end
    queue()
end

-- The editor closed, so the tour goes with it.
local function stop()
    waiting = nil
    if Tour.Running() then Bridge.StopTour() end
end

-- Hooks go on once Daylight UI has started its modules and the Bridge is ready.
local function hookEditor()
    if not Bridge.Ready() then return end
    Bridge.HookEditor("Open", offer)
    Bridge.HookEditor("Close", stop)
end

API.On("Login", hookEditor, "EZ-CDM")
