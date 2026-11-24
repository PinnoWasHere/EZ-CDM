local stub = require("stub")
local CW = require("cdmworld")

-- EZ-CDM/Settings.lua: EZ-CDM's settings on Daylight UI's Cooldown Manager page,
-- saved in EZCDMDB.settings and read live, the newer-version notice over addon
-- messages, and the what's-new note after an update.

local SHOUT, REND = 6673, 772
local PAGE = "cdm.layout"

-- The game's addon messages, faked: what was sent, and the switches that hold them back.
local comms
local function fakeComms()
    comms = { sent = {}, prefixes = {}, lockdown = false, restricted = false, guild = true }
    _G.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(p) comms.prefixes[p] = true; return 0 end,
        SendAddonMessage = function(p, text, channel)
            if p ~= "EZ-CDM" then return 0 end
            comms.sent[#comms.sent + 1] = { p, text, channel }
            return 0
        end,
        InChatMessagingLockdown = function() return comms.lockdown end,
        AreOutgoingAddonChatMessagesRestricted = function() return comms.restricted end,
    }
    _G.IsInGuild = function() return comms.guild end
end

-- Daylight UI, its Cooldown Manager and EZ-CDM, logged in. db is EZCDMDB as the
-- client hands it over (nil: a first install).
local function world(db)
    stub.neverSecretAuras = {}
    fakeComms()
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        EZCDMDB = db
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND }, showAll = true })
        stub.spells[SHOUT] = { name = "Battle Shout" }
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    return DUI, ns, ns.Settings, stub.actionbars
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

-- EZ-CDM's groups on the page, by label.
local function groups(DUI)
    local out = {}
    for _, g in ipairs(DUI.Options.GetPage(PAGE).groups) do
        if tostring(g.label):find("From EZ%-CDM") then out[#out + 1] = g end
    end
    return out
end

-- The placed row with that label.
local function row(DUI, label)
    for _, g in ipairs(groups(DUI)) do
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

-- ---------------------------------------------------------------------
-- The groups on the page
-- ---------------------------------------------------------------------

T.test("settings: two groups land on the Cooldown Manager page, every row kept", function()
    local DUI, ns, S = world()
    noErrors()
    local placed = groups(DUI)
    T.eq(#placed, #S.GROUPS, "each group on the page")
    for i, g in ipairs(placed) do
        T.eq(#g.items, #S.GROUPS[i].items, "no row left out of " .. tostring(g.label))
    end
    T.truthy(DUI:GetModule("EZ-CDM"), "the module the rows hang on")
    for _, line in ipairs(stub.chat) do
        T.falsy(tostring(line):find("left out"), "no row refused: " .. tostring(line))
    end
end)

T.test("settings: every label is 4 words or fewer, every tooltip short", function()
    local _, _, S = world()
    local n = 0
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

-- ---------------------------------------------------------------------
-- Newer version
-- ---------------------------------------------------------------------

T.test("update: versions compare by number, a source copy compares as nothing", function()
    local _, _, S = world()
    T.truthy(S.Newer("0.10.0", "0.9.9"))
    T.truthy(S.Newer("1.0.0", "0.99.99"))
    T.truthy(S.Newer("v0.2.1", "0.2.0"), "a tag's v")
    T.falsy(S.Newer("0.2.0", "0.2.0"))
    T.falsy(S.Newer("0.1.9", "0.2.0"))
    T.falsy(S.Newer("@project-version@", "0.2.0"))
    T.falsy(S.Newer("0.3.0\0x", "0.2.0"))
end)

T.test("update: tells the guild its version after login, out of combat only", function()
    world()
    T.truthy(comms.prefixes["EZ-CDM"], "the prefix is registered")
    T.eq(#comms.sent, 1, "one message after login")
    T.deq(comms.sent[1], { "EZ-CDM", "V:0.2.0", "GUILD" })
end)

T.test("update: nothing sent in combat, in a chat lockdown, or on a restricted realm", function()
    local _, _, S = world()
    comms.sent = {}
    stub.combat = true
    S.Say("PARTY")
    T.eq(#comms.sent, 0, "held in combat")
    stub.combat = false
    stub.FireEvent("PLAYER_REGEN_ENABLED"); stub.RunTimers()
    T.eq(#comms.sent, 1, "sent once the fight ends")
    comms.sent = {}
    comms.lockdown = true
    S.Say("RAID")
    comms.lockdown, comms.restricted = false, true
    S.Say("RAID")
    T.eq(#comms.sent, 0, "lockdown and restricted realm: nothing")
end)

T.test("update: a newer version heard says so once a session; an older one gets ours", function()
    local _, _, S = world()
    stub.chat, comms.sent = {}, {}
    S.Heard("EZ-CDM", "V:0.3.1", "GUILD", "Someone")
    S.Heard("EZ-CDM", "V:0.4.0", "PARTY", "Other")
    local lines = chatLines()
    T.eq(#lines, 1, "one line a session")
    T.truthy(lines[1]:find("0.3.1", 1, true), "names the version: " .. lines[1])
    S.Heard("EZ-CDM", "V:0.1.0", "PARTY", "Old")
    stub.RunTimers()
    T.eq(#comms.sent, 1, "answers an older copy")
    T.deq(comms.sent[1], { "EZ-CDM", "V:0.2.0", "PARTY" })
    S.Heard("EZ-CDM", "V:0.1.0", "WHISPER", "Old")
    stub.RunTimers()
    T.eq(#comms.sent, 1, "never on a channel it didn't hear from the group or guild")
    S.Heard("OTHER", "V:9.0.0", "GUILD", "x")
    S.Heard("EZ-CDM", "hello", "GUILD", "x")
    noErrors()
end)

T.test("update: a secret payload is ignored", function()
    local _, _, S = world()
    stub.chat = {}
    local secret = _G.issecretvalue
    _G.issecretvalue = function(v) return v == "V:9.9.9" end
    S.Heard("EZ-CDM", "V:9.9.9", "GUILD", "x")
    _G.issecretvalue = secret
    T.eq(#chatLines(), 0)
end)

T.test("update: the notice off sends and hears nothing", function()
    local DUI, _, S = world()
    row(DUI, S.LABELS.updateCheck).set(false)
    stub.chat, comms.sent = {}, {}
    S.Say("GUILD")
    S.Heard("EZ-CDM", "V:9.0.0", "GUILD", "x")
    S.Heard("EZ-CDM", "V:0.0.1", "GUILD", "x")
    stub.RunTimers()
    T.eq(#comms.sent, 0)
    T.eq(#chatLines(), 0)
end)

-- ---------------------------------------------------------------------
-- What's new
-- ---------------------------------------------------------------------

T.test("news: a first install sees no note and marks this version read", function()
    world(nil)
    T.eq(#chatLines(), 0)
    T.eq(EZCDMDB.newsSeen, "0.2.0")
end)

T.test("news: a player from before sees this version's note once", function()
    world({ drawer = false })
    local lines = chatLines()
    T.truthy(#lines >= 2, "a heading and its lines")
    T.truthy(lines[1]:find("0.2.0", 1, true), lines[1])
    T.eq(EZCDMDB.newsSeen, "0.2.0")
    stub.chat = {}
    stub.FireEvent("PLAYER_LOGIN"); stub.RunTimers()
    T.eq(#chatLines(), 0, "not again")
end)

T.test("news: switched off, the note waits unshown; the button shows it any time", function()
    local DUI, _, S = world({ drawer = false, settings = { whatsNew = false } })
    T.eq(#chatLines(), 0, "off: no note")
    local btn = row(DUI, S.LABELS.news)
    T.eq(btn.type, "button")
    btn.func()
    T.truthy(#chatLines() >= 2, "the button prints it")
end)
