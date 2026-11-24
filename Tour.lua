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
--
-- The tour works on a demo spell it places itself: a known cooldown from the tray
-- the layout doesn't hold yet. Each stop after the pick shows the demo in the
-- drawer, and the recipe stop puts a recipe on it. However the tour ends, the demo
-- goes and EZCDMDB is put back as it was; in a fight that waits for the fight's
-- end. EZCDMDB.tourDemo marks a demo still placed, so a /reload mid-tour clears
-- it at the next login. The player's own spells are never written.

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
-- The recipe the recipe stop puts on the demo, when it fits.
Tour.RECIPE = "readyAlert"

local waiting -- the token of a start waiting for its delay or another tour
local start = {}
local demo    -- the demo spell's key while this session placed it

local function savedVars()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    return EZCDMDB
end

function Tour.Seen() return savedVars().tourSeen == true end

local function pop(text) return Bridge.TourPop(text) end

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

-- ---------------------------------------------------------------------
-- The demo spell
-- ---------------------------------------------------------------------

-- EZCDMDB.tourDemo: { profile, key, had, keys, drawer, recipe, gone }, or nil.
--   had     what each EZCDMDB store held for key on profile before the tour
--   keys    the layout's top-level keys before the tour (Bridge.LayoutKeys)
--   drawer  true when the tour opened a folded drawer
--   recipe  the recipe put on the demo
--   gone    the demo left already, ahead of the tour's end
local function marker()
    local m = type(EZCDMDB) == "table" and EZCDMDB.tourDemo
    return type(m) == "table" and m or nil
end

-- The demo's key while this session placed it, else nil.
function Tour.Demo() return demo end

-- Each store's hold on key under profile p: EZ-CDM's rules live as
-- EZCDMDB[store][profile][key] (Effects, Conditions).
local function keep(db, p, key)
    local had = {}
    for name, store in pairs(db) do
        if type(store) == "table" and name ~= "tourDemo" then
            local byKey = store[p]
            had[name] = { profile = type(byKey) == "table", value = type(byKey) == "table" and copy(byKey[key]) or nil }
        end
    end
    return had
end

-- Puts each store's hold on key back, and drops the tables the tour made.
local function putBack(db, p, key, had)
    for name, store in pairs(db) do
        if type(store) == "table" and name ~= "tourDemo" then
            local h = had[name]
            if type(store[p]) == "table" then
                store[p][key] = h and copy(h.value) or nil
                if next(store[p]) == nil and not (h and h.profile) then store[p] = nil end
            end
            if h == nil and next(store) == nil then db[name] = nil end
        end
    end
end

-- The first known cooldown on the tray the layout doesn't hold: not a buff, not
-- one Daylight UI adds, not a bar.
local function pickDemo()
    for _, e in ipairs(Bridge.TraySpells() or {}) do
        if type(e) == "table" and e.id ~= nil and not (e.placed or e.unlearned or e.aura or e.custom)
            and e.kind ~= "bar" then
            return e.id
        end
    end
end

-- Removes the demo piece and puts its EZCDMDB rules back. False while a layout
-- write is refused; the marker stays for later.
local function dropPiece(m)
    if m.profile ~= nil and m.key ~= nil and not m.gone then
        -- A profile deleted since has nothing left to remove.
        if Bridge.Profile(m.profile) then
            local done, why = Bridge.RemovePiece(m.profile, m.key, m.keys)
            if not done and why ~= "rejected" then return false end
        end
        putBack(savedVars(), m.profile, m.key, type(m.had) == "table" and m.had or {})
        m.gone = true
    end
    demo = nil
    return true
end

-- Removes the demo and puts back everything the tour changed. False while a
-- layout write would be refused (a fight, EZ-CDM off).
local function clearDemo()
    local m = marker()
    if not m then
        demo = nil
        return true
    end
    if InCombatLockdown() or not Bridge.Ready() or not dropPiece(m) then return false end
    local db = savedVars()
    db.tourDemo = nil
    if m.drawer then
        if Bridge.EditorOpen() then ns.Drawer.SetExpanded(false) else db.drawer = false end
    end
    return true
end

-- The start block points the talent set at another layout: the demo leaves the
-- old one first, so a copy never holds it. The tour goes on without it.
Bridge.BeforeSwitch(function()
    local m = marker()
    if m and not InCombatLockdown() then dropPiece(m) end
end)

-- Clears the demo a frame on, out of a fight and the client's restrictions. The
-- frame's wait lets a fight that ends the tour show first, and lets the passes at
-- a fight's end finish with the demo still placed.
local function endDemo()
    local m = marker()
    if not m then
        demo = nil
        return
    end
    C_Timer.After(0, function()
        if marker() ~= m then return end
        if InCombatLockdown() or Bridge.Restricted() then
            Bridge.AfterRestrictions(endDemo, "EZ-CDM.tourDemo")
            return
        end
        clearDemo()
    end)
end

-- Places the demo in the open editor's layout, the way the tray adds a spell.
-- The marker is saved first, so a /reload at any point clears it. The editor's
-- pick stays as it was: the pick stop asks for the demo.
local function makeDemo()
    if not Bridge.CanDemo() or InCombatLockdown() or not Bridge.EditorOpen() then return end
    if marker() and not clearDemo() then return end
    local key = pickDemo()
    if key == nil then return end
    local p = Bridge.SavedProfile()
    if not p then return end
    local db, picked = savedVars(), Bridge.Selected()
    db.tourDemo = { profile = p, key = key, had = keep(db, p, key), keys = Bridge.LayoutKeys(p) }
    if not Bridge.AddPiece(key, "icon") then
        db.tourDemo = nil
        return
    end
    demo = key
    Bridge.Select(picked)
end

local function placed()
    local set = Bridge.Layout()
    return demo ~= nil and type(set) == "table" and type(set.pieces) == "table" and set.pieces[demo] ~= nil
end

-- Picks the demo, so the drawer shows it.
local function pickTheDemo()
    if placed() and Bridge.Selected() ~= demo then Bridge.Select(demo) end
end

-- Puts Tour.RECIPE on the demo through Draft, as the drawer's recipe chip does.
local function addRecipe()
    local m = marker()
    if not (m and placed() and ns.Drawer.Key() == demo) then return end
    local fits = false
    for _, k in ipairs(Grammar.Recipes(Grammar.Kind(demo))) do fits = fits or k == Tour.RECIPE end
    local rules = fits and ns.Draft.Rules(demo)
    if not rules then return end
    Grammar.ApplyRecipe(rules, Tour.RECIPE)
    if ns.Draft.Write(demo, rules) then
        m.recipe = Tour.RECIPE
        Bridge.EditorChanged()
    end
end

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

-- The demo on screen, else the picked spell, else the tray.
local function pickPart()
    local key = demo
    if key == nil then key = ns.Drawer.Key() or Bridge.Selected() end
    return key ~= nil and shown(Bridge.PiecePreview(key)) or Bridge.EditorTray()
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
      text = function()
          if demo == nil then return WORDS.pick.text end
          return WORDS.pick.demo:format(pop(Bridge.SpellName(demo) or tostring(demo)))
      end,
      enter = function() start.key = ns.Drawer.Key() end,
      part = pickPart,
      follow = true,
      done = function()
          local key = ns.Drawer.Key()
          if demo ~= nil then return key == demo and start.key ~= demo end
          return key ~= nil and key ~= start.key
      end },
    { id = "drawer",
      title = WORDS.drawer.title,
      text = function() return WORDS.drawer.text:format(pop(ns.Drawer.TAB_LABEL)) end,
      enter = function()
          pickTheDemo()
          if not ns.Drawer.Expanded() then
              local m = marker()
              if m then m.drawer = true end
              ns.Drawer.SetExpanded(true)
          end
      end,
      part = function() return ns.Drawer.Clip(), ns.Drawer.Tab() end,
      follow = true },
    { id = "word",
      title = WORDS.word.title,
      text = WORDS.word.text,
      enter = pickTheDemo,
      part = function()
          return bodyToken(function(t) return t.piece ~= nil and t.piece.kind == "link" end) or drawer()
      end,
      follow = true },
    { id = "line",
      title = WORDS.line.title,
      text = function() return WORDS.line.text:format(pop(WORDING.addLine)) end,
      enter = pickTheDemo,
      part = addLink("line"),
      follow = true },
    { id = "recipe",
      title = WORDS.recipe.title,
      text = function()
          local m = marker()
          local done = demo ~= nil and m and m.recipe
          if done then return WORDS.recipe.demo:format(pop(WORDING.addRecipe), pop(WORDING.recipes[done])) end
          return WORDS.recipe.text:format(pop(WORDING.addRecipe), pop(WORDING.recipes.readyAlert))
      end,
      enter = function()
          pickTheDemo()
          addRecipe()
      end,
      part = addLink("recipe"),
      follow = true },
    { id = "group",
      title = WORDS.group.title,
      text = function() return WORDS.group.text:format(pop(WORDING.addGroup), pop(WORDING.group.combat.on)) end,
      enter = pickTheDemo,
      part = addLink("group"),
      follow = true },
    { id = "report",
      title = WORDS.report.title,
      text = function() return WORDS.report.text:format(pop(WORDING.copyReport)) end,
      available = function() return Bridge.CanShowText() end,
      enter = pickTheDemo,
      part = function()
          return bodyToken(function(_, b) return b.copy == true end) or drawer()
      end,
      follow = true },
}

-- The engine leaves a stop with no next one only as the tour ends, however it ends:
-- Done, Skip tour, Escape, a fight, the editor's close, an error in a stop.
for _, step in ipairs(Tour.STEPS) do
    step.leave = function(nextStep)
        if nextStep == nil then endDemo() end
    end
end

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
    makeDemo()
    local ok = Bridge.RunTour(stops(), {
        key = Tour.KEY,
        through = true,
        skipped = Tour.WHERE and WORDS.skipped:format(pop(Tour.WHERE[1]), pop(Tour.WHERE[2])) or nil,
        finished = function() savedVars().tourSeen = true end,
    })
    if not ok then endDemo() end
    return ok
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

-- The editor closed, so the tour and its demo go with it.
local function stop()
    waiting = nil
    if Tour.Running() then Bridge.StopTour() end
    endDemo()
end

-- Hooks go on once Daylight UI has started its modules and the Bridge is ready.
-- A demo a /reload left behind goes now.
local function hookEditor()
    if not Bridge.Ready() then return end
    Bridge.HookEditor("Open", offer)
    Bridge.HookEditor("Close", stop)
    if marker() then endDemo() end
end

API.On("Login", hookEditor, "EZ-CDM")
