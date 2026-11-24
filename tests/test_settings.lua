local stub = require("stub")
local CW = require("cdmworld")

-- EZ-CDM/Settings.lua: EZ-CDM's own page in its section under /dui's Plugins,
-- saved in EZCDMDB.settings and read live. News.lua: What's New in Daylight UI's
-- own window, once after an update. Update.lua: the newer-version notice over
-- addon messages to the guild, the group and Battle.net friends.

local SHOUT, REND = 6673, 772
local PAGE = "EZ-CDM.main"
local SECTION = "plugin:EZ-CDM"

-- The game's addon messages and Battle.net friends, faked: what was sent, and the
-- switches that hold it back.
local comms
local function fakeComms()
    comms = { sent = {}, friendSent = {}, prefixes = {}, lockdown = false, restricted = false,
              guild = true, answer = 0, friends = {} }
    _G.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(p) comms.prefixes[p] = true; return 0 end,
        SendAddonMessage = function(p, text, channel)
            if p ~= "EZ-CDM" then return 0 end
            comms.sent[#comms.sent + 1] = { p, text, channel }
            return comms.answer
        end,
        InChatMessagingLockdown = function() return comms.lockdown end,
        AreOutgoingAddonChatMessagesRestricted = function() return comms.restricted end,
    }
    _G.IsInGuild = function() return comms.guild end
    -- The client's group kinds (no fake of them in the stub).
    _G.LE_PARTY_CATEGORY_HOME, _G.LE_PARTY_CATEGORY_INSTANCE = 1, 2
    -- A friend: { id = gameAccountID, program = "WoW", project = 1, here = true, online = true }.
    _G.BNET_CLIENT_WOW, _G.WOW_PROJECT_ID = "WoW", 1
    _G.BNFeaturesEnabledAndConnected = function() return true end
    _G.BNGetNumFriends = function() return #comms.friends end
    _G.C_BattleNet = {
        GetFriendNumGameAccounts = function(i) return comms.friends[i] and 1 or 0 end,
        GetFriendGameAccountInfo = function(i)
            local f = comms.friends[i]
            if not f then return nil end
            return { gameAccountID = f.id, clientProgram = f.program or "WoW", wowProjectID = f.project or 1,
                     isOnline = f.online ~= false, isInCurrentRegion = f.here ~= false }
        end,
        SendGameData = function(id, p, text)
            comms.friendSent[#comms.friendSent + 1] = { id, p, text }
            return 0
        end,
    }
end

-- Daylight UI, its Cooldown Manager and EZ-CDM, logged in. db is EZCDMDB as the
-- client hands it over (nil: a first install).
local function world(db, opts)
    opts = opts or {}
    stub.neverSecretAuras = {}
    fakeComms()
    if opts.friends then comms.friends = opts.friends end
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        EZCDMDB = db
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND }, showAll = true })
        stub.spells[SHOUT] = { name = "Battle Shout" }
        stub.spells[REND] = { name = "Rend" }
    end })
    if opts.combat then stub.combat = true end
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    return DUI, ns, ns.Settings, stub.actionbars
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

-- EZ-CDM's page in /dui.
local function page(DUI) return DUI.Options.GetPage(PAGE) end

-- The row with that label on EZ-CDM's page.
local function row(DUI, label)
    for _, g in ipairs(page(DUI).groups) do
        for _, item in ipairs(g.items) do
            if item.label == label then return item end
        end
    end
end

local function chatLines()
    local out = {}
    for _, line in ipairs(stub.chat) do
        local s = tostring(line)
        if s:find("EZ%-CDM") or s:find("^%- ") then out[#out + 1] = s end
    end
    return out
end

local function words(s)
    local n = 0
    for _ in tostring(s):gmatch("%S+") do n = n + 1 end
    return n
end

local function has(text, part) return tostring(text):find(part, 1, true) ~= nil end

-- ---------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------

T.test("settings: EZ-CDM's own page in its section under Plugins, every row kept", function()
    local DUI, _, S = world()
    noErrors()
    local p = page(DUI)
    T.truthy(p, "the page " .. PAGE)
    T.eq(p.section, SECTION, "in EZ-CDM's own section of the options window")
    T.truthy(DUI.Options.Section(SECTION).plugin, "a plugin's section, under the Plugins heading")
    T.eq(#p.groups, #S.GROUPS, "each group on the page")
    for i, g in ipairs(p.groups) do
        T.eq(#g.items, #S.GROUPS[i].items, "no row left out of " .. tostring(g.label))
    end
    for _, line in ipairs(stub.chat) do
        T.falsy(tostring(line):find("Options %("), "no row refused: " .. tostring(line))
    end
end)

T.test("settings: nothing of EZ-CDM's left on the Cooldown Manager page", function()
    local DUI = world()
    for _, g in ipairs(DUI.Options.GetPage("cdm.layout").groups) do
        T.falsy(tostring(g.label):find("From EZ%-CDM"), "a group still there: " .. tostring(g.label))
    end
end)

T.test("settings: the section has Daylight UI's icon, a short name and a line", function()
    local DUI = world()
    local s = DUI.OptionsTheme.Section(SECTION)
    T.eq(s.short, "EZ-CDM", "the rail's name")
    T.truthy(has(s.icon, "ui-section-cooldowns"), "Daylight UI's own Cooldown Manager icon: " .. tostring(s.icon))
    T.truthy(type(s.blurb) == "string" and words(s.blurb) <= 10, "a short line for the rail's tooltip")
end)

T.test("settings: every label is 4 words or fewer, every tooltip short", function()
    local DUI, _, S = world()
    local n = 0
    T.truthy(words(page(DUI).label) <= 4, "page label: " .. tostring(page(DUI).label))
    for _, g in ipairs(S.GROUPS) do
        T.truthy(words(g.label) <= 4, "group label: " .. tostring(g.label))
        for _, item in ipairs(g.items) do
            n = n + 1
            T.truthy(words(item.label) <= 4, "label over 4 words: " .. tostring(item.label))
            if item.text then T.truthy(words(item.text) <= 4, "button text: " .. tostring(item.text)) end
            if item.desc then T.truthy(words(item.desc) <= 8, "tooltip over 8 words: " .. item.desc) end
            for _, v in pairs(item.values or {}) do T.truthy(words(v) <= 4, "choice: " .. v) end
        end
    end
    T.truthy(n >= 5, "the rows were counted")
end)

T.test("settings: a row reads and writes EZCDMDB.settings, defaults unsaved", function()
    local DUI, _, S = world()
    local sounds = row(DUI, S.LABELS.sounds)
    T.truthy(sounds, "the sounds row")
    T.eq(sounds.get(), true, "on before anything is saved")
    T.isnil(EZCDMDB.settings and EZCDMDB.settings.sounds, "a default isn't written")
    sounds.set(false)
    T.eq(EZCDMDB.settings.sounds, false, "saved in EZCDMDB")
    T.eq(S.Get("sounds"), false)
    T.eq(sounds.get(), false, "the row reads it back")
    sounds.set(true)
    T.isnil((EZCDMDB.settings or {}).sounds, "back to the default: nothing saved")
    local drawer = row(DUI, S.LABELS.drawer)
    T.eq(drawer.get(), "last")
    T.deq(drawer.order, { "last", "open", "closed" }, "the choices in order")
end)

T.test("settings: values saved before the move still read", function()
    local DUI, _, S = world({ settings = { sounds = false, drawer = "closed" } })
    T.eq(row(DUI, S.LABELS.sounds).get(), false)
    T.eq(row(DUI, S.LABELS.drawer).get(), "closed")
end)

-- ---------------------------------------------------------------------
-- Live
-- ---------------------------------------------------------------------

T.test("settings: the start block follows its switch live, editor open or not", function()
    local DUI, ns, S, AB = world()
    local show = row(DUI, S.LABELS.startBlock)
    T.truthy(AB.CdmEditor.Open()); stub.RunTimers()
    T.truthy(ns.Start.Shown(), "shown by default")
    show.set(false)
    T.falsy(ns.Start.Shown(), "hidden the moment it's switched off")
    AB.CdmEditor.Draw(); stub.RunTimers()
    T.falsy(ns.Start.Shown(), "a redraw keeps it hidden")
    AB.CdmEditor.Close(); stub.RunTimers()
    T.truthy(AB.CdmEditor.Open()); stub.RunTimers()
    T.falsy(ns.Start.Shown(), "the next open leaves it off")
    show.set(true)
    T.truthy(ns.Start.Shown(), "back the moment it's switched on")
    noErrors()
end)

T.test("settings: the drawer starts open, closed, or as it was left", function()
    local DUI, ns, S, AB = world()
    local pick = row(DUI, S.LABELS.drawer)
    local function reopen()
        AB.CdmEditor.Close(); stub.RunTimers()
        T.truthy(AB.CdmEditor.Open()); stub.RunTimers()
        return ns.Drawer.Expanded()
    end
    T.truthy(AB.CdmEditor.Open()); stub.RunTimers()
    ns.Drawer.SetExpanded(false)
    T.falsy(reopen(), "as left: still folded")
    pick.set("open")
    T.truthy(reopen(), "open: opens folded or not")
    ns.Drawer.SetExpanded(false)
    T.truthy(reopen(), "open again next time")
    pick.set("closed")
    T.falsy(reopen(), "closed")
    ns.Drawer.SetExpanded(true)
    T.falsy(reopen(), "closed again next time")
    pick.set("last")
    ns.Drawer.SetExpanded(true)
    T.truthy(reopen(), "as left: open")
    noErrors()
end)

T.test("settings: sounds off silences the fall-off sound and the drawer's preview", function()
    local DUI, ns, S = world()
    local played, sampled = {}, {}
    local alert, sample = DUI.Sound.Alert, DUI.Sound.AlertSample
    DUI.Sound.Alert = function(k) played[#played + 1] = k end
    DUI.Sound.AlertSample = function(k) sampled[#sampled + 1] = k end
    local key = "raid"
    ns.Bridge.PlayAlert(key)
    ns.Bridge.PreviewAlert(key)
    T.eq(#played, 1, "on: plays")
    T.eq(#sampled, 1, "on: previews")
    row(DUI, S.LABELS.sounds).set(false)
    ns.Bridge.PlayAlert(key)
    ns.Bridge.PreviewAlert(key)
    T.eq(#played, 1, "off: no fall-off sound")
    T.eq(#sampled, 1, "off: no preview")
    DUI.Sound.Alert, DUI.Sound.AlertSample = alert, sample
end)

T.test("settings: the tour's skipped line names the row and EZ-CDM's section", function()
    local _, ns = world()
    T.deq(ns.Tour.WHERE, { ns.Grammar.WORDING.tour.replay, "EZ-CDM" })
end)

-- ---------------------------------------------------------------------
-- What's new
-- ---------------------------------------------------------------------

T.test("news: a player from before sees What's New in Daylight UI's window, once", function()
    local _, ns = world({ drawer = false, newsSeen = "0.1.0" })
    local mine = ns.Update.Version()
    T.eq(stub.Asked(), "ezcdm:news", "Daylight UI's own window is up")
    T.truthy(DaylightUIAsk:IsShown(), "shown")
    T.eq(DaylightUIAsk.title:GetText(), ns.Grammar.WORDING.settings.newsTitle)
    T.eq(DaylightUIAsk.foot.buttons[1].text:GetText(), ns.Grammar.WORDING.settings.okay, "one Okay")
    T.falsy(DaylightUIAsk.foot.buttons[2] and DaylightUIAsk.foot.buttons[2]:IsShown(), "and no second button")
    local text = stub.AskText()
    T.truthy(has(text, mine), "names this version: " .. text)
    T.truthy(has(text, ns.Grammar.WORDING.news[1].lines[1]), "with its lines")
    T.eq(#chatLines(), 0, "nothing in chat")
    T.eq(EZCDMDB.newsSeen, mine)
    stub.Answer(true)
    T.isnil(stub.Asked(), "Okay closes it")
    noErrors()
    -- Another login (Daylight UI's own login complains about its movers, not ours).
    stub.FireEvent("PLAYER_LOGIN"); stub.RunTimers()
    T.isnil(stub.Asked(), "not again")
end)

T.test("news: each version since the last one read, newest first", function()
    local _, ns = world({ drawer = false, newsSeen = "0.1.0" })
    local text = stub.AskText()
    local list = ns.Grammar.WORDING.news
    T.truthy(#list >= 2, "two versions of notes")
    local a, b = text:find(list[1].version, 1, true), text:find(list[2].version, 1, true)
    T.truthy(a and b and a < b, "the newer first: " .. text)
end)

T.test("news: only what's new since the version last read", function()
    local _, ns = world({ drawer = false, newsSeen = "0.2.0" })
    local list = ns.Grammar.WORDING.news
    local text = stub.AskText()
    T.truthy(has(text, list[1].lines[1]), "this version's lines")
    T.falsy(has(text, list[2].lines[1]), "not the one read before")
end)

T.test("news: in a fight at login, the window waits for the fight to end", function()
    world({ drawer = false, newsSeen = "0.1.0" }, { combat = true })
    T.isnil(stub.Asked(), "nothing in a fight")
    stub.combat = false
    stub.FireEvent("PLAYER_REGEN_ENABLED")
    stub.RunTimers()
    T.eq(stub.Asked(), "ezcdm:news", "up once it ends")
end)

T.test("news: a first install sees no window and marks this version read", function()
    local _, ns = world(nil)
    T.isnil(stub.Asked())
    T.eq(#chatLines(), 0)
    T.eq(EZCDMDB.newsSeen, ns.Update.Version())
end)

T.test("news: switched off, nothing shows; the button shows it any time", function()
    local DUI, ns, S = world({ drawer = false, newsSeen = "0.1.0", settings = { whatsNew = false } })
    T.isnil(stub.Asked(), "off: no window")
    T.eq(#chatLines(), 0, "and nothing in chat")
    local btn = row(DUI, S.LABELS.news)
    T.eq(btn.type, "button")
    btn.func()
    T.eq(stub.Asked(), "ezcdm:news", "the button opens the window")
    T.truthy(has(stub.AskText(), ns.Grammar.WORDING.news[1].version), "with the latest notes")
    noErrors()
end)

T.test("news: the button shows the notes again after they were read", function()
    local DUI, ns, S = world({ drawer = false, newsSeen = "0.1.0" })
    stub.Answer(true)
    row(DUI, S.LABELS.news).func()
    T.eq(stub.Asked(), "ezcdm:news")
    T.truthy(has(stub.AskText(), ns.Grammar.WORDING.news[1].lines[1]))
end)

-- ---------------------------------------------------------------------
-- Newer version
-- ---------------------------------------------------------------------

T.test("update: versions compare by number, a source copy compares as nothing", function()
    local _, ns = world()
    local U = ns.Update
    T.truthy(U.Newer("0.10.0", "0.9.9"))
    T.truthy(U.Newer("1.0.0", "0.99.99"))
    T.truthy(U.Newer("v0.2.1", "0.2.0"), "a tag's v")
    T.falsy(U.Newer("0.2.0", "0.2.0"))
    T.falsy(U.Newer("0.1.9", "0.2.0"))
    T.falsy(U.Newer("@project-version@", "0.2.0"))
    T.falsy(U.Newer("0.3.0\0x", "0.2.0"))
end)

T.test("update: tells the guild its version after login", function()
    local _, ns = world()
    T.truthy(comms.prefixes["EZ-CDM"], "the prefix is registered")
    T.eq(#comms.sent, 1, "one message after login")
    T.deq(comms.sent[1], { "EZ-CDM", "V:" .. ns.Update.Version(), "GUILD" })
end)

-- Forever answers true to AreOutgoingAddonChatMessagesRestricted in town (seen
-- 2026-11-24), and guild and group addon messages still go out.
T.test("update: a realm that says addon messages are restricted still gets them", function()
    local _, ns = world()
    comms.sent, comms.restricted = {}, true
    ns.Update.Say("PARTY")
    T.eq(#comms.sent, 1, "sent; the game's answer says if it went")
end)

T.test("update: held in combat and in a chat lockdown, sent once they end", function()
    local _, ns = world()
    local U = ns.Update
    comms.sent = {}
    stub.combat = true
    U.Say("PARTY")
    T.eq(#comms.sent, 0, "held in combat")
    stub.combat = false
    stub.FireEvent("PLAYER_REGEN_ENABLED"); stub.RunTimers()
    T.eq(#comms.sent, 1, "sent once the fight ends")
    comms.sent, comms.lockdown = {}, true
    U.Say("RAID")
    T.eq(#comms.sent, 0, "held in a lockdown")
    comms.lockdown = false
    stub.FireEvent("ADDON_RESTRICTION_STATE_CHANGED", 0, 0); stub.RunTimers()
    T.eq(#comms.sent, 1, "sent once it lifts")
    T.eq(comms.sent[1][3], "RAID")
end)

T.test("update: the game's lockdown answer holds the message for later", function()
    local _, ns = world()
    comms.sent, comms.answer = {}, 11
    ns.Update.Say("PARTY")
    T.eq(#comms.sent, 1, "tried")
    comms.answer = 0
    stub.FireEvent("PLAYER_REGEN_ENABLED"); stub.RunTimers()
    T.eq(#comms.sent, 2, "tried again later")
end)

T.test("update: a dungeon finder group hears it in its own chat", function()
    local _, ns = world()
    comms.sent = {}
    local inGroup = _G.IsInGroup
    _G.IsInGroup = function(cat) return cat == LE_PARTY_CATEGORY_INSTANCE or cat == nil end
    T.eq(ns.Update.GroupChannel(), "INSTANCE_CHAT")
    _G.IsInGroup = function(cat) return cat ~= LE_PARTY_CATEGORY_INSTANCE end
    T.eq(ns.Update.GroupChannel(), "PARTY")
    _G.IsInGroup = inGroup
end)

T.test("update: Battle.net friends playing Forever here hear it, the rest don't", function()
    local _, ns = world(nil, { friends = {
        { id = 11 }, { id = 12, program = "App" }, { id = 13, project = 2 }, { id = 14, here = false },
        { id = 15, online = false }, { id = 16 },
    } })
    local ids = {}
    for _, s in ipairs(comms.friendSent) do ids[#ids + 1] = s[1] end
    T.deq(ids, { 11, 16 }, "only friends in WoW Forever, online, in this region")
    T.deq(comms.friendSent[1], { 11, "EZ-CDM", "V:" .. ns.Update.Version() })
end)

T.test("update: a newer version heard shows Daylight UI's window once a session", function()
    local _, ns = world()
    local U = ns.Update
    stub.chat, comms.sent = {}, {}
    U.Heard("EZ-CDM", "V:9.3.1", "GUILD", "Someone")
    U.Heard("EZ-CDM", "V:9.4.0", "PARTY", "Other")
    T.eq(stub.Asked(), "ezcdm:newer")
    T.truthy(has(stub.AskText(), "9.3.1"), "names the version: " .. stub.AskText())
    stub.Answer(true)
    T.isnil(stub.Asked(), "one window a session")
    T.eq(#chatLines(), 0, "nothing in chat")
    noErrors()
end)

T.test("update: an older copy heard gets ours on its channel, never a whisper", function()
    local _, ns = world()
    local U = ns.Update
    comms.sent = {}
    U.Heard("EZ-CDM", "V:0.0.1", "PARTY", "Old")
    stub.RunTimers()
    T.eq(#comms.sent, 1, "answers an older copy")
    T.deq(comms.sent[1], { "EZ-CDM", "V:" .. U.Version(), "PARTY" })
    U.Heard("EZ-CDM", "V:0.0.1", "WHISPER", "Old")
    stub.RunTimers()
    T.eq(#comms.sent, 1, "never on a channel it didn't hear from the group or guild")
    U.Heard("OTHER", "V:9.0.0", "GUILD", "x")
    U.Heard("EZ-CDM", "hello", "GUILD", "x")
    T.isnil(stub.Asked())
    noErrors()
end)

T.test("update: a friend's newer copy shows the window; an older one gets ours", function()
    local _, ns = world(nil, { friends = { { id = 21 } } })
    local U = ns.Update
    comms.friendSent = {}
    U.HeardFriend("EZ-CDM", "V:0.0.1", "WHISPER", 21)
    stub.RunTimers()
    T.eq(#comms.friendSent, 1, "an older friend gets ours")
    T.deq(comms.friendSent[1], { 21, "EZ-CDM", "V:" .. U.Version() })
    U.HeardFriend("EZ-CDM", "V:9.9.9", "WHISPER", 21)
    T.eq(stub.Asked(), "ezcdm:newer")
end)

T.test("update: a secret payload is ignored", function()
    local _, ns = world()
    local secret = _G.issecretvalue
    _G.issecretvalue = function(v) return v == "V:9.9.9" end
    ns.Update.Heard("EZ-CDM", "V:9.9.9", "GUILD", "x")
    ns.Update.HeardFriend("EZ-CDM", "V:9.9.9", "WHISPER", 1)
    _G.issecretvalue = secret
    T.isnil(stub.Asked())
end)

T.test("update: the notice off sends and hears nothing", function()
    local DUI, ns, S = world(nil, { friends = { { id = 31 } } })
    row(DUI, S.LABELS.updateCheck).set(false)
    comms.sent, comms.friendSent = {}, {}
    ns.Update.Say("GUILD")
    ns.Update.TellFriends()
    ns.Update.Heard("EZ-CDM", "V:9.0.0", "GUILD", "x")
    ns.Update.Heard("EZ-CDM", "V:0.0.1", "GUILD", "x")
    stub.RunTimers()
    T.eq(#comms.sent, 0)
    T.eq(#comms.friendSent, 0)
    T.isnil(stub.Asked())
end)
