local addonName, ns = ...

-- EZ-CDM's settings, on Daylight UI's Cooldown Manager page ("Cooldown layout") through
-- me.AddOptionsGroup. Each row carries its own get and set, so the values live in
-- EZCDMDB.settings (a default is never written) and take effect at once.
--
-- Where each setting acts:
--   startBlock  Start.Attach is wrapped here: off, the block detaches instead.
--   drawer      the drawer's saved open state is set as the editor closes and at login.
--   sounds      Bridge.PlayAlert and Bridge.PreviewAlert read it.
--   updateCheck the newer-version notice below.
--   whatsNew    the what's-new note below.
--
-- Newer version: each copy tells the guild and the group which version it is, in an
-- addon message (never seen in chat), at login and on joining a group. Hearing a newer
-- one, it says so once a session; hearing an older one, it answers a moment later.
-- Nothing is sent in combat, in a chat lockdown (boss fights, keystones, PvP) or on a
-- realm that restricts addon messages, and a secret payload is never read.
--
-- What's new: after an update, the latest Grammar.WORDING.news entries in chat, once.
-- A first install marks this version read and sees none.

local Bridge, Grammar = ns.Bridge, ns.Grammar
local API = DaylightUI.API
local WORDS = Grammar.WORDING.settings

local Settings = {}
ns.Settings = Settings

Settings.PAGE = "cdm.layout"
Settings.PREFIX = "EZ-CDM"
Settings.LABELS = {
    startBlock = WORDS.startBlock, drawer = WORDS.drawer, sounds = WORDS.sounds,
    updateCheck = WORDS.updateCheck, whatsNew = WORDS.whatsNew, news = WORDS.news,
}
Settings.DEFAULTS = {
    startBlock = true, drawer = "last", sounds = true, updateCheck = true, whatsNew = true,
}

local function savedVars()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    return EZCDMDB
end

local function say(text)
    if text and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text) end
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

-- ---------------------------------------------------------------------
-- The rows
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
        -- The first-run tour again (Tour.lua), opening the editor.
        { type = "button", label = Grammar.WORDING.tour.replay, text = Grammar.WORDING.tour.replayShow,
          func = function() ns.Tour.Replay() end },
    } },
    { label = WORDS.updates, items = {
        toggle("updateCheck", WORDS.updateCheckTip),
        toggle("whatsNew", WORDS.whatsNewTip),
        { type = "button", label = WORDS.news, text = WORDS.newsShow,
          func = function() Settings.News(true) end },
    } },
}

local me = API.For(addonName)
for _, g in ipairs(Settings.GROUPS) do me.AddOptionsGroup(Settings.PAGE, g) end

-- The tour's skipped line names the Replay Tour row and its group.
ns.Tour.WHERE = { Grammar.WORDING.tour.replay, WORDS.editor }

-- ---------------------------------------------------------------------
-- Versions
-- ---------------------------------------------------------------------

-- "1.6.11" (a tag's "v1.6.11" too) as { 1, 6, 11 }; nil for anything else.
local function parts(v)
    if type(v) ~= "string" then return nil end
    local a, b, c = v:match("^v?(%d+)%.(%d+)%.(%d+)$")
    if a then return { tonumber(a), tonumber(b), tonumber(c) } end
end

-- Whether version a is newer than b. False when either isn't a version.
function Settings.Newer(a, b)
    local x, y = parts(a), parts(b)
    if not (x and y) then return false end
    for i = 1, 3 do
        if x[i] ~= y[i] then return x[i] > y[i] end
    end
    return false
end

local mine = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version")
mine = parts(mine) and (mine:gsub("^v", "")) or nil
function Settings.Version() return mine end

-- ---------------------------------------------------------------------
-- The newer-version notice
-- ---------------------------------------------------------------------

local ANSWER = { GUILD = true, PARTY = true, RAID = true }
local THROTTLE = 60
local sentAt, waiting, told = {}, {}, false

local function canSend()
    local Chat = C_ChatInfo
    if not (Chat and Chat.SendAddonMessage) then return false end
    if Chat.InChatMessagingLockdown and Chat.InChatMessagingLockdown() then return false end
    if Chat.AreOutgoingAddonChatMessagesRestricted and Chat.AreOutgoingAddonChatMessagesRestricted() then
        return false
    end
    return true
end

-- Tells one channel this copy's version, at most once a minute. A fight holds it
-- until the fight ends.
function Settings.Say(channel)
    if not (channel and mine) or Settings.Get("updateCheck") == false then return end
    if InCombatLockdown() then
        waiting[channel] = true
        return
    end
    if not canSend() then return end
    local now = GetTime()
    if sentAt[channel] and now - sentAt[channel] < THROTTLE then return end
    sentAt[channel] = now
    C_ChatInfo.SendAddonMessage(Settings.PREFIX, "V:" .. mine, channel)
end

local function groupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

local function plain(...)
    local secret = _G.issecretvalue
    if not secret then return true end
    for i = 1, select("#", ...) do
        if secret((select(i, ...))) then return false end
    end
    return true
end

-- One addon message heard (CHAT_MSG_ADDON's prefix, text, channel).
function Settings.Heard(prefix, text, channel)
    if not plain(prefix, text, channel) then return end
    if prefix ~= Settings.PREFIX or type(text) ~= "string" or not mine then return end
    if Settings.Get("updateCheck") == false then return end
    local v = text:match("^V:(%d+%.%d+%.%d+)$")
    if not v then return end
    if Settings.Newer(v, mine) then
        if not told then
            told = true
            say(WORDS.newer:format(v))
        end
    elseif Settings.Newer(mine, v) and ANSWER[channel] then
        -- A moment later, so a whole group doesn't answer at once.
        C_Timer.After(1 + math.random() * 4, function() Settings.Say(channel) end)
    end
end

-- ---------------------------------------------------------------------
-- What's new
-- ---------------------------------------------------------------------

-- Prints the notes this version has that newsSeen hasn't (all: the latest one,
-- read or not) and marks them read. Returns whether it printed.
function Settings.News(all)
    local seen = not all and savedVars().newsSeen or nil
    local printed = false
    for _, n in ipairs(Grammar.WORDING.news or {}) do
        if seen and not Settings.Newer(n.version, seen) then break end
        if not (mine and Settings.Newer(n.version, mine)) then
            say(WORDS.newsTitle:format(n.version))
            for _, line in ipairs(n.lines) do say("- " .. line) end
            printed = true
            if all or not seen then break end
        end
    end
    if mine then savedVars().newsSeen = mine end
    return printed
end

local function greet()
    if InCombatLockdown() then return C_Timer.After(5, greet) end
    local db = savedVars()
    if not mine or db.newsSeen == mine or Settings.Get("whatsNew") == false then return end
    Settings.News(false)
end

-- ---------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------

local grouped = false
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, event, a, b, c)
    if event == "CHAT_MSG_ADDON" then
        Settings.Heard(a, b, c)
    elseif event == "ADDON_LOADED" then
        if a ~= addonName then return end
        -- A first install: this version's notes count as read.
        if not (type(EZCDMDB) == "table" and next(EZCDMDB) ~= nil) and mine then
            savedVars().newsSeen = mine
        end
        f:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
            C_ChatInfo.RegisterAddonMessagePrefix(Settings.PREFIX)
        end
        C_Timer.After(4, greet)
        C_Timer.After(15, function()
            if IsInGuild and IsInGuild() then Settings.Say("GUILD") end
            Settings.Say(groupChannel())
        end)
    elseif event == "GROUP_ROSTER_UPDATE" then
        local now = groupChannel() ~= nil
        if now and not grouped then C_Timer.After(3, function() Settings.Say(groupChannel()) end) end
        grouped = now
    elseif event == "PLAYER_REGEN_ENABLED" then
        for channel in pairs(waiting) do
            waiting[channel] = nil
            Settings.Say(channel)
        end
    end
end)

-- The drawer's start state, at login and as the editor closes.
API.On("Login", function()
    drawerStart()
    if Bridge.Ready() then Bridge.HookEditor("Close", drawerStart) end
end, "EZ-CDM")
