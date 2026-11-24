local stub = require("stub")
local H = require("ez_harness")

-- Idle cost. Daylight UI loads with every module and EZ-CDM on top, logs in, and sits
-- still for a few seconds at 60 frames a second, alone and then in a fight with a
-- target. Only EZ-CDM's own files count; Daylight UI's per-frame work is its own
-- tests' business. Fails when:
--   * an EZ-CDM frame runs an OnUpdate while nothing happens. Hide the frame while it
--     has nothing to do, or list it in DRIVERS with the reason it can't be an event.
--   * EZ-CDM's Lua per idle frame grows past BUDGET. It counts Lua instructions, so
--     the number is the same on every PC. After a real speed-up, lower it.
--   * an EZ-CDM ticker repeats faster than Daylight UI's fade, every 0.1 s.

-- File -> { how many idle OnUpdates, why }. None yet.
local DRIVERS = {}
-- Lua instructions per idle frame. Nothing of EZ-CDM's runs per idle frame yet; a
-- driver added to DRIVERS raises these to its measure plus about a fifth.
local BUDGET = { solo = 0, fight = 0 }
-- Daylight UI's fade steps every 0.1 s; nothing of ours repeats faster.
local TICKER_FLOOR = 0.1

local MODULES = {
    "module", "actionbars", "buffs", "skins", "bags", "nameplates", "tooltip", "qol", "auctionhouse", "chat",
    "infopanel", "quests",
}

local function sourceOf(fn)
    local info = debug.getinfo(fn, "S")
    return (info.source:gsub("^@", "")), info.linedefined
end

-- Every frame whose OnUpdate the client would run now, EZ-CDM's marked.
local idleDrivers = H.OnUpdateFrames

-- Steps n frames of dt seconds. With count, returns the Lua instructions EZ-CDM's
-- OnUpdates ran per frame (the hook fires every 10th instruction).
local function runFrames(n, dt, count)
    local ticks = 0
    local function tick() ticks = ticks + 1 end
    local drivers = idleDrivers()
    for _ = 1, n do
        stub.Advance(dt)
        for _, d in ipairs(drivers) do
            if d.frame.__scripts.OnUpdate == d.fn then
                local measured = count and d.ours
                if measured then debug.sethook(tick, "", 10) end
                d.fn(d.frame, dt)
                if measured then debug.sethook() end
            end
        end
    end
    return ticks * 10 / n
end

-- Lets login settle: the unit watch, timers and tickers, then 3 s of frames for
-- every fade, glide and login move to end.
local function settle()
    stub.UnitWatch()
    for _ = 1, 5 do
        stub.RunTimers()
        stub.RunTickers()
    end
    runFrames(180, 1 / 60)
    stub.RunTimers()
end

local function login()
    local opts = {}
    for _, m in ipairs(MODULES) do opts[m] = true end
    stub.LoadPlugin(opts)
    stub.FireEvent("PLAYER_ENTERING_WORLD")
    settle()
end

local function checkIdle(scene)
    local drivers, ours = idleDrivers(), {}
    T.truthy(#drivers > 0, scene .. ": no OnUpdate at all, not even Daylight UI's: the check measures nothing")
    for _, d in ipairs(drivers) do
        if d.ours then
            ours[d.src] = ours[d.src] or {}
            table.insert(ours[d.src], d.line)
        end
    end
    local over = {}
    for src, lines in pairs(ours) do
        local allowed = DRIVERS[src] and DRIVERS[src][1] or 0
        if #lines > allowed then
            table.sort(lines)
            over[#over + 1] = ("%s: %d idle OnUpdate (line %s), %d allowed"):format(src, #lines,
                table.concat(lines, ", "), allowed)
        end
    end
    table.sort(over)
    T.eq(table.concat(over, "\n  "), "", scene .. ": runs every frame while nothing happens (hide the frame"
        .. " while idle, or add it to DRIVERS with why)")
    -- Counted in the interpreter: compiled code skips the count hook.
    local compiler = rawget(_G, "jit")
    if compiler then
        compiler.off()
        compiler.flush()
    end
    local work = runFrames(120, 1 / 60, true)
    if compiler then compiler.on() end
    T.truthy(work <= BUDGET[scene], ("%s: %d Lua instructions of EZ-CDM's per idle frame, budget %d"
        .. " (a real speed-up: lower BUDGET)"):format(scene, work, BUDGET[scene]))
end

T.test("lag: idle and alone, no new per-frame work, within the budget", function()
    login()
    checkIdle("solo")
end)

T.test("lag: idle in a fight with a target, no new per-frame work, within the budget", function()
    login()
    stub.SetUnits({ target = { name = "Training Dummy", level = 20, reaction = 2, health = 900, maxHealth = 1000 } })
    stub.FireEvent("PLAYER_TARGET_CHANGED")
    stub.EnterCombat()
    settle()
    checkIdle("fight")
end)

T.test("lag: no ticker of EZ-CDM's repeats faster than the fade's 0.1 s", function()
    login()
    local tickers = stub.tickers
    T.truthy(#tickers > 0, "no tickers at all, not even Daylight UI's: the check measures nothing")
    local fast = {}
    for i = 1, #tickers do
        local every = tickers[i].interval
        if not tickers[i].cancelled and type(every) == "number" and every < TICKER_FLOOR then
            local src, line = sourceOf(tickers[i].fn)
            if H.IsPluginFile(src) then fast[#fast + 1] = ("%s:%d every %s s"):format(src, line, every) end
        end
    end
    T.eq(table.concat(fast, "\n  "), "", "tickers faster than " .. TICKER_FLOOR .. " s")
end)

T.test("lag: the scan tells EZ-CDM's files from Daylight UI's", function()
    local dir = stub.PLUGIN_TOC:match("^(.*/)") or ""
    T.truthy(H.IsPluginFile("@" .. dir .. "EZ-CDM.lua"), "an EZ-CDM file counts")
    T.falsy(H.IsPluginFile("@" .. stub.DUI_ROOT .. "Windows/Follow.lua"), "a Daylight UI file doesn't")
    T.falsy(H.IsPluginFile("@tests/test_lag.lua"), "a test file doesn't")
end)
