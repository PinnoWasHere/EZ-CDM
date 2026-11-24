local stub = require("stub")
local H = require("ez_harness")

-- Daylight UI's guard checks (its tests/test_guards.lua, loaded from the checkout),
-- run on EZ-CDM's shipped files: patterns that broke the game before, each named
-- after its bug, with reviewed exceptions in tests/guards_allow.lua. Its two checks
-- of Daylight UI's own module layout are left out.

-- `git ls-files -- Media` lists Daylight UI's media: EZ-CDM names DUI.MEDIA.
local gitIo = setmetatable({
    popen = function(cmd, ...)
        if cmd:find("^git ls%-files") then cmd = 'git -C "' .. H.DUI_ROOT .. '" ' .. cmd:sub(5) end
        return io.popen(cmd, ...)
    end,
}, { __index = io })

local L = H.daylightChecks("test_guards", {
    skip = {
        "guards: every module lists the parts its files define (restart message)",
        "guards: every .toc has the core's version",
    },
    env = { io = gitIo },
    fit = function(L)
        L.set("TOCS", { stub.PLUGIN_TOC })
        for _, rule in ipairs(L.get("RULES")) do
            if rule[1] == "static-popup" then rule[2] = rule[2]:gsub("by Daylight UI", "by an addon") end
        end
    end,
})

local shippedFiles, RULES, code, hookOf = L.get("shippedFiles"), L.get("RULES"), L.get("code"), L.get("hookOf")

T.test("guards: the shipped list is found (the checks above aren't empty)", function()
    local files, set = shippedFiles(), {}
    for i = 1, #files do
        set[files[i]] = true
        T.truthy(H.exists(files[i]), "a listed file is on disk: " .. files[i])
    end
    T.truthy(#files > 0, "found " .. #files .. " shipped files")
    local dir = stub.PLUGIN_TOC:match("^(.*/)") or ""
    T.truthy(set[dir .. "EZ-CDM.lua"], "EZ-CDM.lua is in the shipped list")
end)

-- A line each rule must catch. A rule Daylight UI adds at a re-pin needs a line here.
local SAMPLES = {
    ["load-game-addon"] = 'C_AddOns.LoadAddOn("Blizzard_Calendar")',
    ["tracker-structural"] = 'ObjectiveTrackerFrame:SetPoint("TOP")',
    ["quest-marker-show"] = "poiButton:Show()",
    ["open-chat"] = 'ChatFrame_OpenChat("/w ")',
    ["confirm-delete-item"] = "C_Item.ConfirmDeleteItem()",
    ["static-popup"] = 'StaticPopupDialogs["EZCDM_X"] = {}',
    ["mouseisover"] = "if MouseIsOver(f) then",
    ["events-list-remove"] = "tremove(ActionBarButtonEventsFrame.frames, i)",
    ["aura-update-secret"] = "if info.isFullUpdate then",
}

T.test("guards: each rule finds the line it bans", function()
    for _, rule in ipairs(RULES) do
        local line = SAMPLES[rule[1]]
        T.truthy(line, "a sample line for rule " .. rule[1])
        T.truthy(rule[3](code(line)), "rule " .. rule[1] .. " finds: " .. line)
    end
    T.truthy(hookOf('hooksecurefunc(GameTooltip, "SetUnit", fn)'), "the hook check finds an object's method hook")
end)

T.test("guards: EZ-CDM's own frames may set scripts by name, game frames may not", function()
    local allow = require("guards_allow").setscript
    T.truthy(allow["Drawer.lua|EZCDMDrawer"], "an EZCDM name")
    T.falsy(allow["Drawer.lua|PlayerFrame"], "a game frame's name")
end)
