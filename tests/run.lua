-- EZ-CDM's test runner. From the repo root:
--
--   luajit tests/run.lua                      every test file, one after another
--   luajit tests/run.lua grammar              files whose name holds "grammar"
--   luajit tests/run.lua --par                every file in its own process, a few at a time
--   luajit tests/run.lua --par --only test_a test_b   exactly these files
--   luajit tests/run.lua --one test_a         one file (each --par process runs this)
--
-- The fake game is Daylight UI's, loaded from a checkout at the tag in tests/pin.lua
-- (see tests/ez_harness.lua and CONTRIBUTING.md). The game's own UI code the fake game
-- runs comes from `python tools/fetch_blizzard.py`.
--
-- Test files are tests/test_*.lua and tests/repro/*.lua. A test file calls
-- T.test(name, fn); fn fails by raising an error, usually through one of the T
-- checks below. A run ends with "<n> passed, <n> failed".

local ON_WINDOWS = package.config:find("\\", 1, true) == 1
local ROOT = rawget(_G, "EZ_ROOT") or ""
local EXTRA = rawget(_G, "EZ_EXTRA_TESTS")
local SELF = arg and arg[0] or "tests/run.lua"

-- A file over this many CPU seconds fails a --par run, so a slow file is split
-- before it sets the pace of the whole run. EZCDM_FILE_BUDGET changes it (CI runners
-- are slower than a desktop).
local FILE_BUDGET = tonumber(os.getenv("EZCDM_FILE_BUDGET") or "") or 60

-- == Windows: CPU time, and a machine-wide cap on test processes ==

local ffi
local function kernel32()
    if ffi then return ffi end
    ffi = require("ffi")
    ffi.cdef [[
        void *CreateMutexA(void *security, int initialOwner, const char *mutexName);
        uint32_t WaitForSingleObject(void *object, uint32_t timeoutMs);
        uint32_t WaitForMultipleObjects(uint32_t n, void *const *objects, int waitAll, uint32_t timeoutMs);
        int ReleaseMutex(void *mutex);
        void *GetCurrentProcess(void);
        int GetProcessTimes(void *proc, uint64_t *creation, uint64_t *exit, uint64_t *kernelTime, uint64_t *userTime);
    ]]
    return ffi
end

-- os.clock is wall time on Windows; ask the system for this process's CPU time there.
local function processCpu()
    if ON_WINDOWS then
        local k = kernel32()
        local t = k.new("uint64_t[4]")
        k.C.GetProcessTimes(k.C.GetCurrentProcess(), t + 0, t + 1, t + 2, t + 3)
        return tonumber(t[2] + t[3]) * 1e-7
    end
    return os.clock()
end

-- About three test processes for every eight logical cores, and never fewer than
-- two. More than that swamped a PC with the game open.
local function processCount()
    local cores = tonumber(os.getenv("NUMBER_OF_PROCESSORS") or "4") or 4
    local n = math.floor(cores * 0.375)
    if n < 2 then n = 2 end
    return n
end

-- Each test process holds one of these named mutexes while it runs. Daylight UI's
-- runner uses the same names, so runs of both suites share one cap per machine. The
-- system frees the mutex of a process that dies.
local function machineSlots()
    if not ON_WINDOWS then return function() end, function() end end
    local k, n = kernel32(), processCount()
    local mutexes = k.new("void *[?]", n)
    for i = 0, n - 1 do mutexes[i] = k.C.CreateMutexA(nil, 0, "Local\\DaylightUI_tests_" .. (i + 1)) end
    local mine
    return function()
        local r = k.C.WaitForMultipleObjects(n, mutexes, 0, 0xFFFFFFFF)
        -- 0x80 and up: the last holder died, and the mutex is ours now.
        if r < 0x100 then mine = mutexes[r % 0x80] end
    end, function()
        if mine ~= nil then k.C.ReleaseMutex(mine) end
        mine = nil
    end
end

-- A full run waits while another full run is going on this machine.
local function oneFullRunAtATime()
    if not ON_WINDOWS then return end
    local k = kernel32()
    local mutex = k.C.CreateMutexA(nil, 0, "Local\\DaylightUI_tests_full_run")
    local TIMEOUT = 0x102
    if k.C.WaitForSingleObject(mutex, 0) ~= TIMEOUT then return end
    io.write("Waiting: another full test run is going on this PC.\n")
    io.flush()
    k.C.WaitForSingleObject(mutex, 0xFFFFFFFF)
end

-- == Which files ==

local function filesIn(dir, pattern)
    local cmd = ON_WINDOWS and ('dir /b "' .. dir:gsub("/", "\\") .. '" 2>nul') or ('ls "' .. dir .. '" 2>/dev/null')
    local pipe, found = io.popen(cmd), {}
    for entry in pipe:lines() do
        entry = entry:gsub("\r", "")
        if entry:find(pattern) then found[#found + 1] = entry:sub(1, -5) end
    end
    pipe:close()
    return found
end

-- Every test file: name -> path. A name is the file's path inside its tests folder,
-- without .lua ("test_bridge", "repro/mage_fire_blast_fade").
local function allTestFiles()
    local folders = { ROOT .. "tests/" }
    if EXTRA then folders[#folders + 1] = EXTRA end
    local pathOf, order = {}, {}
    local function note(name, path)
        if not pathOf[name] then order[#order + 1] = name end
        pathOf[name] = path
    end
    for _, folder in ipairs(folders) do
        for _, n in ipairs(filesIn(folder, "^test_.+%.lua$")) do note(n, folder .. n .. ".lua") end
        for _, n in ipairs(filesIn(folder .. "repro/", "%.lua$")) do note("repro/" .. n, folder .. "repro/" .. n .. ".lua") end
    end
    -- The sweeps take longest, so --par starts them first.
    local function sweep(name) return name:find("sweep", 1, true) ~= nil end
    table.sort(order, function(a, b)
        if sweep(a) ~= sweep(b) then return sweep(a) end
        return a < b
    end)
    return order, pathOf
end

local mode, picks = {}, {}
for i = 1, #(arg or {}) do
    local word = arg[i]
    local flag = word:match("^%-%-(%a+)$")
    if flag then mode[flag] = true else picks[#picks + 1] = word end
end

-- == A --par worker: takes jobs off the queue until none are left ==

-- The queue is one empty file per job. A worker claims a job by renaming its file,
-- which fails for every other worker. The job's output goes into <job>.out.
local function save(path, text)
    local out = assert(io.open(path, "wb"))
    out:write(text)
    out:close()
end

if mode.worker then
    local queue = picks[1]
    local take, give = machineSlots()
    for job in io.lines(queue .. ".list") do
        local ticket = queue .. "." .. job:gsub("/", "~")
        if os.rename(ticket, ticket .. ".taken") then
            take()
            local child = io.popen("luajit " .. SELF .. " --one " .. job .. " 2>&1")
            local text = child:read("*a")
            child:close()
            give()
            save(ticket .. ".out", text)
            os.remove(ticket .. ".taken")
            -- The parent reads this pipe. Once it's gone, stop.
            local alive = io.write(".")
            alive = alive and io.flush()
            if not alive then break end
        end
    end
    os.exit(0)
end

local order, pathOf = allTestFiles()

local function chosen(name)
    if mode.one then return name == picks[1] end
    if #picks == 0 then return true end
    for _, p in ipairs(picks) do
        if (mode.only and name == p) or (not mode.only and name:find(p, 1, true)) then return true end
    end
    return false
end

-- == --par: each file in its own process ==

if mode.par then
    local jobs = {}
    for _, name in ipairs(order) do
        if chosen(name) then jobs[#jobs + 1] = name end
    end
    if #picks == 0 then oneFullRunAtATime() end

    local tmp = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
    local queue = ("%s/ezcdm_par_%d_%s"):format(tmp, os.time(), tostring(jobs):match("%x+$"))
    for _, job in ipairs(jobs) do save(queue .. "." .. job:gsub("/", "~"), "") end
    save(queue .. ".list", table.concat(jobs, "\n") .. "\n")

    local procs = {}
    for _ = 1, math.min(processCount(), #jobs) do
        local cmd = "luajit " .. SELF .. ' --worker "' .. queue .. '" 2>&1'
        if ON_WINDOWS then cmd = 'start "" /b /low /wait ' .. cmd end
        procs[#procs + 1] = io.popen(cmd)
    end
    for i = 1, #procs do
        procs[i]:read("*a")
        procs[i]:close()
    end
    os.remove(queue .. ".list")

    local good, bad, shown, notes, costs = 0, 0, {}, {}, {}
    for _, job in ipairs(jobs) do
        local outFile = queue .. "." .. job:gsub("/", "~") .. ".out"
        local handle = io.open(outFile, "rb")
        local text = ""
        if handle then
            text = handle:read("*a")
            handle:close()
            os.remove(outFile)
        end
        costs[#costs + 1] = { job = job, cpu = tonumber(text:match("\ncpu ([%d%.]+)")) or 0 }
        local p, f = text:match("(%d+) passed, (%d+) failed")
        p, f = tonumber(p), tonumber(f)
        if not p then
            bad = bad + 1
            shown[#shown + 1] = job .. ": no result\n" .. text
            notes[#notes + 1] = "FAIL " .. job .. " (no result)"
        else
            good, bad = good + p, bad + f
            if f > 0 then
                shown[#shown + 1] = text
                notes[#notes + 1] = ("FAIL %s (%d of %d)"):format(job, f, p + f)
            end
        end
    end
    local cpuTotal = 0
    for _, c in ipairs(costs) do
        cpuTotal = cpuTotal + c.cpu
        if c.cpu > FILE_BUDGET then
            bad = bad + 1
            notes[#notes + 1] = ("FAIL %s took %.0f CPU s, over the %d s a file may take: split it"):format(c.job, c.cpu, FILE_BUDGET)
        end
    end
    table.sort(costs, function(a, b) return a.cpu > b.cpu end)
    local top = {}
    for i = 1, math.min(5, #costs) do top[i] = ("%s %.0f"):format(costs[i].job, costs[i].cpu) end

    -- Failing output first and the count last, so the tail of the output has the count.
    for _, text in ipairs(shown) do io.write("--- ", text, "\n\n") end
    io.write(("CPU %.0f s in all; slowest: %s\n"):format(cpuTotal, table.concat(top, ", ")))
    if #notes > 0 then io.write(table.concat(notes, "\n"), "\n") end
    io.write(("%d passed, %d failed (%d files, %d processes)\n"):format(good, bad, #jobs, math.min(processCount(), #jobs)))
    os.exit(bad > 0 and 1 or 0)
end

-- == In this process ==

-- A later collector pause: less CPU across the suite for some memory.
collectgarbage("setpause", 400)

-- The harness loads as test code: the fake game reads a chunk name under "@tests/"
-- as a test's (see H.chunkname).
local H
do
    local path = ROOT .. "tests/ez_harness.lua"
    local src = assert(io.open(path, "rb"))
    local text = src:read("*a")
    src:close()
    H = assert(load(text, path:find("^%.?/?tests/") and "@" .. path or "@tests/../" .. path))()
end
H.install()

local T = {}
_G.T = T

local function show(v)
    return type(v) == "string" and ("%q"):format(v) or tostring(v)
end

function T.eq(got, want, what)
    if got == want then return end
    error(("%s: expected %s, got %s"):format(what or "eq", show(want), show(got)), 2)
end
function T.near(got, want, tolerance, what)
    if type(got) == "number" and math.abs(got - want) <= (tolerance or 1e-6) then return end
    error(("%s: expected ~%s, got %s"):format(what or "near", show(want), show(got)), 2)
end
-- Two { r, g, b } colors, channel by channel.
function T.rgb(got, want, what)
    local names = { "r", "g", "b" }
    for i = 1, 3 do
        if type(got[i]) ~= "number" or math.abs(got[i] - want[i]) > 1e-6 then
            error(("%s %s: expected ~%s, got %s"):format(what or "rgb", names[i], show(want[i]), show(got[i])), 2)
        end
    end
end
function T.truthy(v, what) if not v then error((what or "truthy") .. ": got " .. show(v), 2) end end
function T.falsy(v, what) if v then error((what or "falsy") .. ": got " .. show(v), 2) end end
function T.isnil(v, what) if v ~= nil then error((what or "isnil") .. ": got " .. show(v), 2) end end
function T.errors(fn, what)
    if not pcall(fn) then return end
    error((what or "errors") .. ": expected an error", 2)
end
function T.noerror(fn, what)
    local fine, problem = pcall(fn)
    if fine then return end
    error(("%s: unexpected error: %s"):format(what or "noerror", tostring(problem)), 2)
end

-- Where two values first differ, as a path, or nil when they match.
local function firstDifference(got, want, at)
    if type(got) ~= type(want) then return ("%s: type %s vs %s"):format(at, type(got), type(want)) end
    if type(got) == "table" then
        for key, value in pairs(got) do
            local d = firstDifference(value, want[key], at .. "." .. tostring(key))
            if d then return d end
        end
        for key in pairs(want) do
            if got[key] == nil then return at .. "." .. tostring(key) .. ": missing in actual" end
        end
        return nil
    end
    if got ~= want then return ("%s: %s vs %s"):format(at, show(got), show(want)) end
    return nil
end
function T.deq(got, want, what)
    local d = firstDifference(got, want, what or "deq")
    if d then error(d, 2) end
end
function T.count(t)
    local n = 0
    for _ in next, t do n = n + 1 end
    return n
end

local registered = {}
function T.test(name, fn) registered[#registered + 1] = { name = name, fn = fn } end

-- Every file starts from the globals the fake game made: files swap in their own
-- GameTooltip, C_* tables and the like, and a later file would meet them.
require("stub")
local pristine = {}
for k, v in next, _G do pristine[k] = v end
local function resetGlobals()
    local extra = {}
    for k in next, _G do
        if pristine[k] == nil then extra[#extra + 1] = k end
    end
    for _, k in ipairs(extra) do _G[k] = nil end
    for k, v in next, pristine do
        if rawget(_G, k) ~= v then rawset(_G, k, v) end
    end
end

local good, bad, report, files = 0, 0, {}, 0
for _, name in ipairs(order) do
    if chosen(name) then
        files = files + 1
        resetGlobals()
        registered = {}
        local chunk, loadProblem = H.loadTestFile(pathOf[name])
        if chunk then
            local loaded, why = xpcall(chunk, debug.traceback)
            if not loaded then
                bad = bad + 1
                report[#report + 1] = name .. " (while loading)\n" .. tostring(why)
            end
            for _, t in ipairs(registered) do
                local passedIt, trace = xpcall(t.fn, debug.traceback)
                if passedIt then
                    good = good + 1
                else
                    bad = bad + 1
                    report[#report + 1] = name .. " / " .. t.name .. "\n" .. tostring(trace)
                    io.write("FAIL ", name, " / ", t.name, "\n")
                end
            end
            io.write(("%-24s %d tests\n"):format(name, #registered))
        else
            bad = bad + 1
            report[#report + 1] = pathOf[name] .. ": " .. tostring(loadProblem)
        end
    end
end
if mode.one and files == 0 then
    bad = bad + 1
    report[#report + 1] = "no test file called " .. tostring(picks[1])
end

io.write(("\n%d passed, %d failed\n"):format(good, bad))
if mode.one then io.write(("cpu %.1f\n"):format(processCpu())) end
for _, entry in ipairs(report) do io.write("\n--- ", entry, "\n") end
os.exit(bad > 0 and 1 or 0)
