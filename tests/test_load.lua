local stub = require("stub")

-- EZ-CDM loads on top of Daylight UI (stub.LoadPlugin), registers as a plugin
-- and raises no error. The last test checks the Daylight UI checkout is the
-- pinned release.

local ADDON = "EZ-CDM"
-- Every Daylight UI module on.
local ALL = {}
for _, m in ipairs({ "module", "actionbars", "buffs", "skins", "bags", "nameplates", "tooltip", "qol",
                     "auctionhouse", "chat", "infopanel", "quests" }) do
    ALL[m] = true
end

-- Is an error raised in one of EZ-CDM's files? Lua cuts a long chunk name to
-- "...<its end>", so the place matches when it ends one of their paths.
local function inPlugin(e)
    local where = e:match("^(.-):%d+:")
    if not where then return true end
    local cut = where:find("^%.%.%.")
    where = where:gsub("^%.%.%.", "")
    local dir = stub.PLUGIN_TOC:match("^(.*/)") or ""
    local _, files = stub.ReadToc(stub.PLUGIN_TOC)
    for _, f in ipairs(files) do
        local path = dir .. f
        if path == where or (cut and path:sub(-#where) == where) then return true end
    end
    return false
end

-- Errors that reached the error handler. With every module on, the bare fake
-- game (no bags, no XP) trips a few of Daylight UI's own files; those are its
-- tests' business, so allowDui keeps only errors raised in EZ-CDM's files, or
-- with no place at all.
local function errors(allowDui)
    local out = {}
    for _, e in ipairs(stub.errors) do
        if not allowDui or inPlugin(e) then out[#out + 1] = e end
    end
    return table.concat(out, "\n")
end

local function registered(DUI, allowDui)
    local p = DUI.Plugins.list[ADDON]
    T.truthy(p, "EZ-CDM registered with DaylightUI:RegisterPlugin")
    T.falsy(p.off, "Daylight UI's API fits what EZ-CDM needs: " .. tostring(p.why))
    T.eq(p.addon, ADDON)
    T.eq(p.title, "EZ-CDM", "the title from the .toc, the plugin tag taken off")
    T.falsy(p.untagged, "the .toc title carries (DaylightUI Plugin)")
    T.eq(p.version, "0.1.0", "the version from the .toc")
    T.eq(errors(allowDui), "", "no error reached the error handler")
end

T.test("load: EZ-CDM loads on Daylight UI's core and registers as a plugin", function()
    local DUI, ns = stub.LoadPlugin()
    T.truthy(DUI.Plugins, "Daylight UI's core loaded from " .. stub.DUI_ROOT)
    T.eq(type(ns), "table", "EZ-CDM got its namespace")
    T.truthy(stub.loadedAddOns[ADDON], "EZ-CDM counts as loaded")
    registered(DUI)
end)

T.test("load: EZ-CDM loads with every Daylight UI module on", function()
    local DUI = stub.LoadPlugin(ALL)
    T.truthy(stub.actionbars, "the action bars module (the Cooldown Manager) loaded")
    registered(DUI, true)
end)

T.test("load: EZ-CDM loads on the action bars with the game's own Cooldown Manager", function()
    local CW = require("cdmworld")
    local SHOUT, REND = 6673, 772
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND }, showAll = true })
    end })
    stub.RunTimers()
    T.eq(type(ns), "table", "EZ-CDM got its namespace")
    T.truthy(_G.EssentialCooldownViewer, "the game's viewers are built")
    T.truthy(CW.Item(CW.ID(REND, 0)), "the game made Rend's cooldown icon")
    T.truthy(stub.actionbars.CdmData, "Daylight UI's Cooldown Manager loaded")
    registered(DUI)
end)

T.test("load: the error filter keeps EZ-CDM's errors and drops Daylight UI's", function()
    local dir = stub.PLUGIN_TOC:match("^(.*/)") or ""
    local mine = dir .. "EZ-CDM.lua"
    T.truthy(inPlugin(mine .. ":3: boom"), "an error in EZ-CDM.lua")
    T.truthy(inPlugin("..." .. mine:sub(-20) .. ":3: boom"), "the same with its name cut short")
    T.truthy(inPlugin("boom"), "an error with no place")
    T.falsy(inPlugin(stub.DUI_ROOT .. "DaylightUI_Bags/Window.lua:1490: boom"), "an error in Daylight UI")
    T.falsy(inPlugin("...UI/DaylightUI_Bags/Window.lua:1490: boom"), "the same with its name cut short")
end)

T.test("load: EZ-CDM's files load after Daylight UI's and before login", function()
    local order = {}
    local realFire = stub.FireEvent
    stub.FireEvent = function(event, ...)
        if event == "ADDON_LOADED" or event == "PLAYER_LOGIN" then order[#order + 1] = event .. " " .. tostring((...)) end
        return realFire(event, ...)
    end
    local ok, err = pcall(stub.LoadPlugin)
    stub.FireEvent = realFire
    assert(ok, err)
    T.eq(table.concat(order, ", "), "ADDON_LOADED DaylightUI, ADDON_LOADED EZ-CDM, PLAYER_LOGIN nil")
end)

-- The harness loads Daylight UI's own fake game from the checkout, so its file lists
-- always match that checkout. What can drift is the checkout itself.
T.test("load: the Daylight UI checkout is the pinned release (tests/pin.lua)", function()
    local H = require("ez_harness")
    local meta = stub.ReadToc(stub.DUI_ROOT .. "DaylightUI.toc")
    T.eq(meta.Version, H.PIN.version, "DaylightUI.toc's version at " .. stub.DUI_ROOT
        .. " (check out " .. H.PIN.tag .. ", or move the pin and re-fit)")
end)
