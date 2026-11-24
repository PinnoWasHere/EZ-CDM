local addonName, ns = ...

-- What's New: the notes in Grammar.WORDING.news, in Daylight UI's own window (its
-- question box with a title and one Okay, Bridge.Note). After an update it shows once,
-- every version newer than the one last read (EZCDMDB.newsSeen) up to this one. The
-- What's New button on the settings page shows the latest two, read or not. A first
-- install marks this version read and shows nothing. Nothing opens in a fight; a
-- window asked for there waits for the fight to end.
--
-- The newer-version notice (Update.lua) opens the same window, once a session.
--
-- Without Daylight UI's box the notes go to chat instead.

local Bridge, Grammar, Update = ns.Bridge, ns.Grammar, ns.Update
local WORDS = Grammar.WORDING.settings

local News = {}
ns.News = News

News.KEY, News.NEWER_KEY = "ezcdm:news", "ezcdm:newer"
News.SHOWN = 2

local function savedVars()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    return EZCDMDB
end

-- ---------------------------------------------------------------------
-- Out of a fight
-- ---------------------------------------------------------------------

local waiting = {}

local function afterCombat(key, fn)
    if not InCombatLockdown() then return fn() end
    waiting[key] = fn
end

-- ---------------------------------------------------------------------
-- The notes
-- ---------------------------------------------------------------------

-- The notes to show, newest first: those newer than seen up to this version, or with
-- all the latest News.SHOWN. A note for a version newer than this one is never shown.
function News.Notes(all)
    local mine = Update.Version()
    local seen = not all and savedVars().newsSeen or nil
    local out = {}
    for _, n in ipairs(Grammar.WORDING.news or {}) do
        if seen and not Update.Newer(n.version, seen) then break end
        if not (mine and Update.Newer(n.version, mine)) then out[#out + 1] = n end
        if all and #out >= News.SHOWN then break end
    end
    return out
end

-- Each version in the accent, its lines under it behind an accent dot.
function News.Text(notes)
    local parts = {}
    for _, n in ipairs(notes) do
        local lines = { Bridge.TourPop(n.version) }
        for _, line in ipairs(n.lines) do lines[#lines + 1] = Bridge.TourPop("•") .. "  " .. line end
        parts[#parts + 1] = table.concat(lines, "\n")
    end
    return table.concat(parts, "\n\n")
end

local function inChat(title, text)
    if not DEFAULT_CHAT_FRAME then return end
    DEFAULT_CHAT_FRAME:AddMessage(title)
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        if line ~= "" then DEFAULT_CHAT_FRAME:AddMessage(line) end
    end
end

local function note(key, title, text)
    if not Bridge.Note(key, title, text, WORDS.okay) then inChat(title, text) end
end

-- Shows What's New (all: the latest notes, read or not) and marks this version read.
-- Returns whether there was anything to show.
function News.Show(all)
    local notes = News.Notes(all)
    local mine = Update.Version()
    if mine then savedVars().newsSeen = mine end
    if #notes == 0 then return false end
    afterCombat(News.KEY, function() note(News.KEY, WORDS.newsTitle, News.Text(notes)) end)
    return true
end

-- ---------------------------------------------------------------------
-- A newer version, once a session
-- ---------------------------------------------------------------------

local told = false

function News.Newer(version)
    if told then return false end
    told = true
    afterCombat(News.NEWER_KEY, function() note(News.NEWER_KEY, WORDS.newerTitle, WORDS.newer:format(version)) end)
    return true
end

-- ---------------------------------------------------------------------
-- After an update
-- ---------------------------------------------------------------------

local function greet()
    local mine = Update.Version()
    if not mine or savedVars().newsSeen == mine then return end
    if ns.Settings.Get("whatsNew") == false then return end
    News.Show(false)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= addonName then return end
        -- A first install: this version's notes count as read.
        local mine = Update.Version()
        if not (type(EZCDMDB) == "table" and next(EZCDMDB) ~= nil) and mine then
            savedVars().newsSeen = mine
        end
        f:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        C_Timer.After(4, greet)
    elseif event == "PLAYER_REGEN_ENABLED" then
        for key, fn in pairs(waiting) do
            waiting[key] = nil
            fn()
        end
    end
end)
