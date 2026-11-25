local addonName, ns = ...

-- EZ-CDM's settings, on its own page in its section under /dui's Plugins (the module
-- registered below, the plugin in EZ-CDM.lua). Each row carries its own get and set,
-- so the values live in EZCDMDB.settings (a default is never written) and take effect
-- at once.
--
-- Where each setting acts:
--   startBlock  Start.Attach is wrapped here: off, the block detaches instead.
--   drawer      the drawer's saved open state is set as the editor closes and at login.
--   sounds      Bridge.PlayAlert and Bridge.PreviewAlert read it.
--   updateCheck the newer-version notice (Update.lua).
--   whatsNew    What's New after an update (News.lua).
--   more        the drawer offers advanced conditions too (its "more…" chip flips it).

local Bridge, Grammar = ns.Bridge, ns.Grammar
local API = DaylightUI.API
local WORDS = Grammar.WORDING.settings

local Settings = {}
ns.Settings = Settings

Settings.PAGE = addonName .. ".main"
Settings.LABELS = {
    startBlock = WORDS.startBlock, drawer = WORDS.drawer, sounds = WORDS.sounds,
    updateCheck = WORDS.updateCheck, whatsNew = WORDS.whatsNew, news = WORDS.news, more = WORDS.more,
}
Settings.DEFAULTS = {
    startBlock = true, drawer = "last", sounds = true, updateCheck = true, whatsNew = true, more = false,
}

local function savedVars()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    return EZCDMDB
end

-- ---------------------------------------------------------------------
-- Reading and writing
-- ---------------------------------------------------------------------

function Settings.Get(key)
    local saved = type(EZCDMDB) == "table" and EZCDMDB.settings
    if type(saved) ~= "table" or saved[key] == nil then return Settings.DEFAULTS[key] end
    return saved[key]
end

-- What changes on screen the moment a setting does.
local APPLY = {}

function Settings.Set(key, value)
    if Settings.DEFAULTS[key] == nil then return end
    local db = savedVars()
    if type(db.settings) ~= "table" then db.settings = {} end
    if value == Settings.DEFAULTS[key] then value = nil end
    db.settings[key] = value
    if next(db.settings) == nil then db.settings = nil end
    if APPLY[key] then APPLY[key](Settings.Get(key)) end
end

-- ---------------------------------------------------------------------
-- Live
-- ---------------------------------------------------------------------

local Start, Drawer = ns.Start, ns.Drawer

local attach = Start.Attach
function Start.Attach(...)
    if Settings.Get("startBlock") == false then return Start.Detach() end
    return attach(...)
end

function APPLY.startBlock(on)
    if not Bridge.EditorOpen() then return end
    if on then Start.Attach() else Start.Detach() end
end

-- The drawer's open state for the editor's next open, unless it stays as left.
local function drawerStart()
    local how = Settings.Get("drawer")
    if how == "last" or Bridge.EditorOpen() then return end
    Drawer.SetExpanded(how == "open")
end
APPLY.drawer = drawerStart

function APPLY.more() Drawer.Refresh() end

-- ---------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------

local function toggle(key, tip)
    return { type = "toggle", label = Settings.LABELS[key], desc = tip,
        get = function() return Settings.Get(key) end,
        set = function(v) Settings.Set(key, v and true or false) end,
        default = function() return Settings.DEFAULTS[key] end }
end

Settings.GROUPS = {
    { label = WORDS.editor, items = {
        toggle("startBlock", WORDS.startBlockTip),
        { type = "dropdown", label = WORDS.drawer, desc = WORDS.drawerTip,
          values = { last = WORDS.drawerLast, open = WORDS.drawerOpen, closed = WORDS.drawerClosed },
          order = { "last", "open", "closed" },
          get = function() return Settings.Get("drawer") end,
          set = function(v) Settings.Set("drawer", v) end,
          default = function() return Settings.DEFAULTS.drawer end },
        toggle("sounds", WORDS.soundsTip),
        toggle("more", WORDS.moreTip),
        -- The first-run tour again (Tour.lua), opening the editor.
        { type = "button", label = Grammar.WORDING.tour.replay, text = Grammar.WORDING.tour.replayShow,
          func = function() ns.Tour.Replay() end },
    } },
    { label = WORDS.updates, items = {
        toggle("updateCheck", WORDS.updateCheckTip),
        toggle("whatsNew", WORDS.whatsNewTip),
        { type = "button", label = WORDS.news, text = WORDS.newsShow,
          func = function() ns.News.Show(true) end },
    } },
}

-- The module's defaults stay empty: every row reads and writes EZCDMDB itself.
DaylightUI:RegisterModule(addonName, { plugin = addonName, label = addonName, defaults = {},
    options = { pages = {
        { id = "main", label = WORDS.page, desc = WORDS.pageDesc, groups = Settings.GROUPS },
    } } })

-- The tour's skipped line names the Replay Tour row and EZ-CDM's section.
ns.Tour.WHERE = { Grammar.WORDING.tour.replay, addonName }

-- The drawer's start state, at login and as the editor closes.
API.On("Login", function()
    drawerStart()
    if Bridge.Ready() then Bridge.HookEditor("Close", drawerStart) end
end, "EZ-CDM")
