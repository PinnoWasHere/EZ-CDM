-- EZ-CDM's side of the test harness.
--
-- The fake game is Daylight UI's own (tests/stub.lua and its helpers), loaded at run
-- time from a Daylight UI checkout at the tag in tests/pin.lua. None of its code is
-- copied here. This file finds the checkout, loads its harness modules, and fits the
-- fake game to EZ-CDM by wrapping its functions and swapping its locals through the
-- debug library. Each local it reaches for is asserted by name, so a re-pin that
-- renames one fails with the name.

local H = {}

-- Paths. EZ_ROOT is the addon folder as seen from the working folder: "" in the public
-- repo, "EZ-CDM/" when the private project runs the suite. EZ_EXTRA_TESTS adds a
-- second test folder (the private project's own tests).

H.ROOT = rawget(_G, "EZ_ROOT") or os.getenv("EZCDM_ROOT") or ""
H.TESTS = H.ROOT .. "tests/"
H.EXTRA_TESTS = rawget(_G, "EZ_EXTRA_TESTS")
H.PIN = assert(loadfile(H.TESTS .. "pin.lua"))()

local function onDisk(path)
    local handle = io.open(path, "rb")
    if not handle then return false end
    handle:close()
    return true
end
H.exists = onDisk

local function slash(dir)
    dir = dir:gsub("\\", "/")
    if dir ~= "" and not dir:find("/$") then dir = dir .. "/" end
    return dir
end

-- Daylight UI's folder: DUI_ROOT, else a clone inside the repo (.daylight/DaylightUI,
-- where CI puts it), else the owner's pinned worktree beside the project.
local function findDaylight()
    local env = os.getenv("DUI_ROOT")
    if env and env ~= "" then return slash(env) end
    for _, dir in ipairs({ H.ROOT .. ".daylight/DaylightUI/", H.ROOT .. "../../DaylightUI-worktrees/ezcdm-pin/DaylightUI/" }) do
        if onDisk(dir .. "DaylightUI.toc") then return dir end
    end
    error(string.format("Daylight UI not found. Clone it at the pinned tag:\n"
        .. "  git clone --depth 1 --branch %s %s .daylight/DaylightUI\n"
        .. "or set DUI_ROOT to a checkout of %s.", H.PIN.tag, H.PIN.repo, H.PIN.tag), 0)
end
H.DUI_ROOT = findDaylight()
H.DUI_TESTS = H.DUI_ROOT .. "tests/"

-- The fake game tells test code from addon code by the chunk name: anything under
-- "@tests/" is test code. Files outside tests/ (the private project's run of the
-- public suite, the Daylight UI checkout) get a name that still starts there.
function H.chunkname(path)
    path = path:gsub("\\", "/")
    if path:find("^%.?/?tests/") then return "@" .. path end
    return "@tests/../" .. path
end

function H.read(path)
    local fh = io.open(path, "rb")
    if not fh then return nil end
    local text = fh:read("*a")
    fh:close()
    return text
end

function H.loadTestFile(path, env)
    local text = H.read(path)
    if not text then return nil, "cannot open " .. path end
    local chunk, err = load(text, H.chunkname(path))
    if chunk and env then setfenv(chunk, env) end
    return chunk, err
end

-- == Module search: our test folders first, then Daylight UI's tests/ ==

-- A Daylight UI helper that opens Daylight UI files by a path relative to its own
-- root (cdmworld reads CdmSpells.lua and the Cooldown Manager catalogue) runs with
-- loadfile and dofile reading a missing local path from the checkout.
local function fromCheckout(path)
    if type(path) == "string" and not onDisk(path) and onDisk(H.DUI_ROOT .. path) then
        return H.DUI_ROOT .. path
    end
    return path
end
local REDIRECT = { cdmworld = true }
local function redirectEnv()
    return setmetatable({
        loadfile = function(path, ...) return loadfile(fromCheckout(path), ...) end,
        dofile = function(path) return dofile(fromCheckout(path)) end,
    }, { __index = _G, __newindex = _G })
end

local function searchDirs()
    local dirs = {}
    if H.EXTRA_TESTS then dirs[#dirs + 1] = H.EXTRA_TESTS end
    dirs[#dirs + 1] = H.TESTS
    dirs[#dirs + 1] = H.DUI_TESTS
    return dirs
end

local function searcher(name)
    local file = name:gsub("%.", "/") .. ".lua"
    for _, dir in ipairs(searchDirs()) do
        local candidate = dir .. file
        if onDisk(candidate) then
            local env = dir == H.DUI_TESTS and REDIRECT[name] and redirectEnv() or nil
            local chunk, why = H.loadTestFile(candidate, env)
            if not chunk then error(why, 0) end
            return chunk
        end
    end
    return "\n\tno file '" .. file .. "' in the test folders or " .. H.DUI_TESTS
end

-- == Reaching Daylight UI's locals ==

local function upvalueOf(fn, name)
    for i = 1, math.huge do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return i, v end
    end
end

-- The value of a local that fn closes over; errors when fn no longer reaches it.
local function need(fn, name, where)
    local i, v = upvalueOf(fn, name)
    if not i then
        error(string.format("Daylight UI's %s no longer reaches a local %q: re-fit tests/ez_harness.lua", where, name), 2)
    end
    return v, i
end
H.need = need

-- Points the local fn closes over at a new value. Every function sharing that local
-- sees the change.
local function swap(fn, name, value, where)
    local _, i = need(fn, name, where)
    debug.setupvalue(fn, i, value)
end
H.swap = swap

-- Every local the functions in list reach, directly or through the functions they
-- reach: name -> { fn, index, value }. Used on a Daylight UI test file's checks.
function H.locals(list)
    local found, seen = {}, {}
    local function walk(fn)
        if seen[fn] then return end
        seen[fn] = true
        for i = 1, math.huge do
            local n, v = debug.getupvalue(fn, i)
            if not n then break end
            if not found[n] then found[n] = { fn = fn, i = i, value = v } end
            if type(v) == "function" then walk(v) end
        end
    end
    for _, fn in ipairs(list) do walk(fn) end
    return found
end

-- == The fits to Daylight UI's fake game ==

local stub

-- Containers made since the last Reset, for the rebuild on the events below.
local auraContainers = {}

-- Inside a client aura button's initializeFrame, the button and everything on it
-- answer addon code in secrets: IsShown, IsVisible, an animation group's IsPlaying,
-- and the sizes. Seen in game at Daylight UI 2.2 ("attempt to perform boolean test
-- on a secret boolean value" on IsShown). Plain Lua can't trap a test on a table,
-- so a boolean read errors at once and counts in stub.initSecretErrors.
local function initializing(t)
    local button = rawget(t, "__inAura")
    return button ~= nil and rawget(button, "__auraLock") ~= true
end
local function initSecretBool(k)
    stub.initSecretErrors = stub.initSecretErrors + 1
    error("attempt to perform boolean test on a secret boolean value (" .. k .. " inside initializeFrame)", 3)
end

local function fitWidgets(fromAddon)
    local W = assert(stub.Widget, "Daylight UI's stub no longer exports stub.Widget: re-fit tests/ez_harness.lua")
    stub.initSecretErrors = 0
    stub.InitializingAura = initializing
    stub.InitSecretBool = initSecretBool

    local isShown, isVisible, getWidth, getHeight = W.IsShown, W.IsVisible, W.GetWidth, W.GetHeight
    function W.IsShown(self)
        if initializing(self) and fromAddon(2) then initSecretBool("IsShown") end
        return isShown(self)
    end
    function W.IsVisible(self)
        if initializing(self) and fromAddon(2) then initSecretBool("IsVisible") end
        return isVisible(self)
    end
    function W.GetWidth(self)
        if initializing(self) and fromAddon(2) then return stub.Secret(rawget(self, "__w") or 0) end
        return getWidth(self)
    end
    function W.GetHeight(self)
        if initializing(self) and fromAddon(2) then return stub.Secret(rawget(self, "__h") or 0) end
        return getHeight(self)
    end

    -- Animations keep their kind, timing, alpha values and target, and a group keeps
    -- its animations and when it last played, so stub.AnimAlpha can read them. The
    -- setters are fields on the animation, so a locked button never refuses them.
    local Anim = {}
    function Anim.SetDuration(a, d) a.__duration = d end
    function Anim.GetDuration(a) return a.__duration or 0 end
    function Anim.SetStartDelay(a, d) a.__startDelay = d end
    function Anim.GetStartDelay(a) return a.__startDelay or 0 end
    function Anim.SetFromAlpha(a, v) a.__fromAlpha = v end
    function Anim.GetFromAlpha(a) return a.__fromAlpha or 0 end
    function Anim.SetToAlpha(a, v) a.__toAlpha = v end
    function Anim.GetToAlpha(a) return a.__toAlpha or 0 end
    function Anim.GetTarget(a) return a.__target end
    -- The target keeps the group, so stub.AnimAlpha finds it from the target too.
    function Anim.SetTarget(a, t)
        a.__target = t
        if type(t) ~= "table" then return end
        local by = rawget(t, "__targetedBy")
        if not by then by = {}; rawset(t, "__targetedBy", by) end
        by[#by + 1] = a.__group
    end

    local createGroup = W.CreateAnimationGroup
    function W.CreateAnimationGroup(self, ...)
        local g = createGroup(self, ...)
        local list = rawget(self, "__animGroups")
        if not list then list = {}; rawset(self, "__animGroups", list) end
        list[#list + 1] = g
        g.__anims = {}
        local createAnim, play, isPlaying = g.CreateAnimation, g.Play, g.IsPlaying
        g.CreateAnimation = function(group, kind, ...)
            local a = createAnim(group, kind, ...)
            a.__kind, a.__group = kind, group
            group.__anims[#group.__anims + 1] = a
            for k, fn in pairs(Anim) do a[k] = fn end
            return a
        end
        g.Play = function(group, ...)
            group.__playedAt = GetTime()
            return play(group, ...)
        end
        g.IsPlaying = function(group, ...)
            if initializing(group) and fromAddon(2) then initSecretBool("IsPlaying") end
            return isPlaying(group, ...)
        end
        return g
    end
end

-- The alpha a playing Alpha animation holds region at now, or nil when none does (the
-- region shows its own alpha). An Alpha animation acts on its target, else on its
-- group's region, from its start delay to the end of its duration after the group's
-- Play (stub.Advance moves the clock). After that the region's own alpha is back, as
-- for a group with no SetToFinalAlpha.
local function animAlpha(region)
    local now, groups = GetTime(), {}
    for _, g in ipairs(rawget(region, "__animGroups") or {}) do groups[#groups + 1] = g end
    for _, g in ipairs(rawget(region, "__targetedBy") or {}) do groups[#groups + 1] = g end
    for i = 1, #groups do
        local g = groups[i]
        local started = rawget(g, "__playing") and rawget(g, "__playedAt")
        if started then
            local t = now - started
            for _, a in ipairs(rawget(g, "__anims") or {}) do
                if a.__kind == "Alpha" and (a.__target or rawget(g, "__parent")) == region then
                    local from, length = a.__startDelay or 0, a.__duration or 0
                    if t >= from and t < from + length then
                        local a0, a1 = a.__fromAlpha or 0, a.__toAlpha or 0
                        return a0 + (a1 - a0) * ((t - from) / length)
                    end
                end
            end
        end
    end
    return nil
end

-- Aura buttons. A group handed to a button (InitializeInboundAnimationGroup in
-- Blizzard_AuraContainerUtil.lua) gets ForbiddenAspect.QueryAnimationProgress, so
-- addon code asking its IsPlaying is refused from then on; tests and the game's
-- code may still ask. A shown animation given twice errors (AddDisplayElement,
-- Blizzard_CustomAuraButton.lua), one given after initializeFrame to a locked button
-- is refused like any method, and RemoveAuraShownAnimation
-- (CustomAuraButtonSharedMixin) takes one back.
local function fitAuras(fromAddon, isLocked, badSelf)
    local function handOver(g)
        if rawget(g, "__handedOver") then return end
        rawset(g, "__handedOver", true)
        local real = g.IsPlaying
        g.IsPlaying = function(group, ...)
            if fromAddon(2) then
                stub.lockErrors = (stub.lockErrors or 0) + 1
                error("calling 'IsPlaying' on bad self (forbidden aspect QueryAnimationProgress)", 2)
            end
            return real(group, ...)
        end
    end

    local function fitButton(btn)
        local addShown, addAssigned = btn.AddAuraShownAnimation, btn.AddAuraAssignedAnimation
        btn.AddAuraShownAnimation = function(self, g)
            if isLocked(self) and fromAddon(2) then badSelf("AddAuraShownAnimation")() end
            for _, x in ipairs(rawget(self, "__shownAnims") or {}) do
                if x == g then error("Display element has already been added.", 2) end
            end
            addShown(self, g)
            handOver(g)
        end
        btn.RemoveAuraShownAnimation = function(self, g)
            if isLocked(self) and fromAddon(2) then badSelf("RemoveAuraShownAnimation")() end
            local list = rawget(self, "__shownAnims") or {}
            for i, x in ipairs(list) do
                if x == g then table.remove(list, i); return end
            end
        end
        btn.AddAuraAssignedAnimation = function(self, g)
            addAssigned(self, g)
            handOver(g)
        end
    end

    local makeFrame = _G.CreateFrame
    local newContainer = need(makeFrame, "newAuraContainer", "CreateFrame")
    local newButton = need(newContainer, "newAuraButton", "aura container")
    swap(newContainer, "newAuraButton", function(c, initializeFrame)
        local init = initializeFrame and function(btn, ...)
            fitButton(btn)
            return initializeFrame(btn, ...)
        end
        return newButton(c, init)
    end, "aura container")
    swap(makeFrame, "newAuraContainer", function(...)
        local c = newContainer(...)
        auraContainers[#auraContainers + 1] = c
        return c
    end, "CreateFrame")
end

-- The events on which a custom aura container rebuilds every button
-- (FullAuraRefreshEvents, Blizzard_CustomAuraContainer.lua). The unit events count
-- only for a container on that unit. The rebuild runs on the container's next
-- OnUpdate (MarkDirty, then ProcessResetFrameAssignments): each shown button is
-- released and acquired again for its aura, so its shown animations play from the
-- start. A timer stands for the next frame.
local AURA_REBUILDS = { PLAYER_ENTERING_WORLD = true, PLAYER_LEAVING_WORLD = true, PLAYER_REGEN_DISABLED = true,
                        PLAYER_REGEN_ENABLED = true, PLAYER_SPECIALIZATION_CHANGED = true,
                        UNIT_FACTION = "unit", UNIT_FLAGS = "unit" }
local function queueAuraRebuild(event, unit)
    local kind = AURA_REBUILDS[event]
    if not kind then return end
    for _, c in ipairs(auraContainers) do
        if kind ~= "unit" or c.__unit == unit then
            C_Timer.After(0, function()
                for _, key in ipairs(c.__groupOrder) do
                    for _, btn in ipairs(c.__groups[key].buttons or {}) do
                        if btn.__auraShown then
                            stub.AuraAssign(btn, false)
                            stub.AuraAssign(btn, true)
                        end
                    end
                end
            end)
        end
    end
end

-- With stub.timeTimers on, a timer with a delay waits until stub.Advance has moved
-- the clock past it; otherwise every timer runs on the next stub.RunTimers.
local later = {}
local function fitTimers()
    local after = need(stub.ResetTimers, "timerAfter", "stub.ResetTimers")
    swap(stub.ResetTimers, "timerAfter", function(d, fn)
        if stub.timeTimers and type(d) == "number" and d > 0 then
            later[#later + 1] = { due = GetTime() + d, fn = fn }
        else
            after(d, fn)
        end
    end, "stub.ResetTimers")
    stub.ResetTimers()
    local runTimers = stub.RunTimers
    function stub.RunTimers(...)
        if #later > 0 then
            local now, keep = GetTime(), {}
            for _, t in ipairs(later) do
                if t.due <= now then after(0, t.fn) else keep[#keep + 1] = t end
            end
            later = keep
        end
        return runTimers(...)
    end
end

-- A restriction's event comes before the restriction is active and after it lifts
-- (RestrictedActionsDocumentation.lua), so while it is sent for one coming on, auras
-- still read plainly and aura buttons still answer. Entering combat sends the
-- combat restriction first; which of the two the client sends first is not known,
-- and both come before the aura containers' rebuild on the next frame.
local function fitRestrictions()
    local setRestriction, enterCombat = stub.SetRestriction, stub.EnterCombat
    stub.SetRestriction = function(kind, turnOn)
        local t = Enum.AddOnRestrictionType[kind]
        if not turnOn or t == nil or stub.restrictions[t] then return setRestriction(kind, turnOn) end
        local view = {}
        for k, v in pairs(stub.restrictions) do view[k] = v end
        stub.restrictions = setmetatable(view, { __newindex = function(tbl, k, v)
            if k ~= t then rawset(tbl, k, v) end
        end })
        local fine, problem = pcall(setRestriction, kind, turnOn)
        local now = {}
        for k, v in pairs(stub.restrictions) do now[k] = v end
        now[t] = true
        stub.restrictions = now
        if not fine then error(problem, 0) end
    end
    stub.EnterCombat = function(...)
        stub.SetRestriction("Combat", true)
        return enterCombat(...)
    end
end

-- Loading. Daylight UI's files come from the checkout. opts.after(DUI) runs after
-- Daylight UI's ADDON_LOADED events and before PLAYER_LOGIN (at the end with
-- login = false), where the client loads an addon that depends on it. It runs as
-- stub.Load sends PLAYER_LOGIN, ahead of it, through whatever stub.FireEvent is
-- then, so a test watching the events sees them in the client's order.
local loadingDUI
local function fitLoad()
    local loadFiles = need(stub.Load, "loadFiles", "stub.Load")
    swap(stub.Load, "loadFiles", function(dir, files, addonName, ns, after)
        if type(addonName) == "string" and addonName:find("^DaylightUI") then
            if addonName == "DaylightUI" then loadingDUI = ns end
            dir = H.DUI_ROOT .. dir
        end
        return loadFiles(dir, files, addonName, ns, after)
    end, "stub.Load")

    local load = stub.Load
    stub.Load = function(options)
        local opts = options or {}
        local after = opts.after
        if not after then return load(opts) end
        local outer, done = stub.FireEvent, false
        stub.FireEvent = function(event, ...)
            if event == "PLAYER_LOGIN" and not done then
                done = true
                stub.FireEvent = outer
                after(loadingDUI)
            end
            return outer(event, ...)
        end
        local ok, DUI, UF = xpcall(load, debug.traceback, opts)
        if not done then stub.FireEvent = outer end
        if not ok then error(DUI, 0) end
        if not done then after(DUI) end
        return DUI, UF
    end

    local send = stub.FireEvent
    stub.FireEvent = function(name, ...)
        send(name, ...)
        queueAuraRebuild(name, (...))
    end
end

local function fitReset()
    local reset = stub.Reset
    function stub.Reset(...)
        reset(...)
        later, stub.timeTimers = {}, nil
        for i = #auraContainers, 1, -1 do auraContainers[i] = nil end
        stub.initSecretErrors = 0
    end
    stub.RESET_GLOBALS[#stub.RESET_GLOBALS + 1] = "EZCDMDB"
end

-- == EZ-CDM on top of Daylight UI ==

-- A .toc's ## fields and its Lua files in order, as written.
local function readToc(path)
    local meta, files = {}, {}
    local text = assert(H.read(path), "cannot read " .. path)
    for raw in (text .. "\n"):gmatch("(.-)\r?\n") do
        local entry = raw:gsub("\\", "/"):match("^(.-)%s*$")
        local field, value = entry:match("^##%s*([^:]+):%s*(.-)$")
        if field then
            meta[field] = value
        elseif entry:sub(1, 1) ~= "#" and entry:sub(-4) == ".lua" then
            files[#files + 1] = entry
        end
    end
    return meta, files
end

-- Daylight UI's Cooldown Manager buff moments (API 1.14) as fired: CooldownBuffUp
-- and CooldownBuffDown from Fx.BuffMoment after each pass. stub.buffMoments lists
-- each { event, key, spellID }.
local function recordBuffMoments(DUI)
    stub.buffMoments = {}
    for _, event in ipairs({ "CooldownBuffUp", "CooldownBuffDown" }) do
        DUI.API.On(event, function(spellID, key)
            stub.buffMoments[#stub.buffMoments + 1] = { event = event, key = key, spellID = spellID }
        end, "stub")
    end
end

-- Daylight UI as API 1.13, before EZ-CDM loads: the minor version, no
-- API.CooldownState or API.OpenCooldownEditor, and the 1.14 events refused with
-- Daylight UI's own line.
local API14_EVENTS = { CooldownUsable = true, CooldownBuffUp = true, CooldownBuffDown = true }
local function olderApi(DUI)
    local API, L = DUI.API, DUI.L
    API.minor = 13
    API.CooldownState, API.OpenCooldownEditor = nil, nil
    local on = API.On
    API.On = function(event, fn, owner)
        if not API14_EVENTS[event] then return on(event, fn, owner) end
        DUI.Print(string.format(L["%s: DaylightUI has no event called %s."], owner and tostring(owner) or L["an addon"], tostring(event)))
        return nil
    end
end

-- Daylight UI (opts as stub.Load), then EZ-CDM from its .toc the way the client loads
-- it: after Daylight UI, before login, Libs/ left out. opts.api13 makes Daylight UI
-- an API 1.13 one first. With the action bars on 1.14, stub.buffMoments records the
-- buff moments. Returns DUI, EZ-CDM's namespace and UF.
local function loadPlugin(opts)
    opts = opts or {}
    local toc = stub.PLUGIN_TOC
    local dir = toc:gsub("[^/]*$", "")
    local addon = toc:match("([^/]+)%.toc$")
    local meta, listed = readToc(toc)
    local files = {}
    for _, f in ipairs(listed) do
        if not f:find("^Libs/") then files[#files + 1] = f end
    end
    local ns, load = {}, {}
    for k, v in pairs(opts) do load[k] = v end
    load.after = function(DUI)
        stub.buffMoments = nil
        if opts.api13 then olderApi(DUI) end
        if opts.after then opts.after(DUI) end
        stub.addonMeta[addon] = meta
        stub.installedAddOns[addon], stub.loadedAddOns[addon] = true, true
        stub.LoadFiles(dir, files, addon, ns)
        stub.FireEvent("ADDON_LOADED", addon)
        if opts.actionbars and not opts.api13 then recordBuffMoments(DUI) end
    end
    local DUI, UF = stub.Load(load)
    stub.plugin = ns
    return DUI, ns, UF
end

-- Is a chunk source ("@path" or a path) one of the files EZ-CDM's .toc lists?
local pluginFiles = {}
function H.IsPluginFile(source)
    local toc = stub.PLUGIN_TOC
    local set = pluginFiles[toc]
    if not set then
        set = {}
        local dir = toc:gsub("[^/]*$", "")
        local _, files = readToc(toc)
        for _, f in ipairs(files) do set[dir .. f] = true end
        pluginFiles[toc] = set
    end
    local path = tostring(source):gsub("^@", ""):gsub("\\", "/"):gsub("^%./", "")
    return set[path] == true
end

-- Every frame whose OnUpdate the client would run now (it and its parents shown):
-- { frame, fn, src, line, ours }, ours when the script is in one of EZ-CDM's files.
function H.OnUpdateFrames()
    local found, frame = {}, nil
    repeat
        frame = EnumerateFrames(frame)
        local scripts = frame and rawget(frame, "__scripts")
        local onUpdate = scripts and scripts.OnUpdate
        if onUpdate and frame:IsVisible() then
            local info = debug.getinfo(onUpdate, "S")
            local src = info.source:gsub("^@", "")
            found[#found + 1] = { frame = frame, fn = onUpdate, src = src, line = info.linedefined, ours = H.IsPluginFile(src) }
        end
    until not frame
    return found
end

-- How many of those run EZ-CDM's code.
function H.PluginDriverCount()
    local n = 0
    for _, d in ipairs(H.OnUpdateFrames()) do
        if d.ours then n = n + 1 end
    end
    return n
end

-- Loads Daylight UI's stub from the checkout and fits it. package.preload["stub"].
function H.loadStub()
    local chunk = assert(H.loadTestFile(H.DUI_TESTS .. "stub.lua"))
    stub = chunk("stub")
    package.loaded.stub = stub

    local WidgetMT = need(stub.NewWidget, "WidgetMT", "stub.NewWidget")
    local index = WidgetMT.__index
    local fromAddon = need(index, "fromAddon", "widget lookup")
    local isLocked = need(index, "isLocked", "widget lookup")
    local badSelf = need(index, "badSelf", "widget lookup")

    fitWidgets(fromAddon)
    fitAuras(fromAddon, isLocked, badSelf)
    fitTimers()
    fitRestrictions()
    fitLoad()
    fitReset()

    stub.DUI_ROOT = H.DUI_ROOT
    stub.PLUGIN_TOC = (os.getenv("EZCDM_TOC") or (H.ROOT .. "EZ-CDM.toc")):gsub("\\", "/")
    stub.AnimAlpha = animAlpha
    stub.QueueAuraRebuild = queueAuraRebuild
    stub.ReadToc = readToc
    stub.RecordBuffMoments = recordBuffMoments
    stub.OlderApi = olderApi
    stub.LoadPlugin = loadPlugin

    -- Traces compiled before the swaps above could hold the old locals.
    if jit then jit.flush() end
    stub.Reset()
    return stub
end

-- == Daylight UI's own check files ==

-- Runs Daylight UI's tests/<name>.lua and registers its checks with T.test. spec:
--   skip      check names left out (Daylight UI's own business)
--   rename    { [old name] = new name }
--   env       globals the file sees in place of the real ones
--   fit(L)    called with H.locals of every check before they run, to point the
--             file's lists and helpers at EZ-CDM
-- Returns the locals, so the caller's own checks can use the file's helpers.
function H.daylightChecks(name, spec)
    spec = spec or {}
    local env
    if spec.env then env = setmetatable(spec.env, { __index = _G, __newindex = _G }) end
    local chunk = assert(H.loadTestFile(H.DUI_TESTS .. name .. ".lua", env))
    local found, test = {}, T.test
    T.test = function(title, fn) found[#found + 1] = { title = title, fn = fn } end
    local fine, problem = pcall(chunk)
    T.test = test
    if not fine then error(problem, 0) end
    local skip, fns, names = {}, {}, {}
    for _, s in ipairs(spec.skip or {}) do skip[s] = true end
    for _, t in ipairs(found) do
        fns[#fns + 1] = t.fn
        names[t.title] = true
    end
    for s in pairs(skip) do
        assert(names[s], "Daylight UI's " .. name .. " has no check called \"" .. s .. "\" any more: re-fit tests/" .. name .. ".lua")
    end
    local L = H.locals(fns)
    function L.set(n, value)
        local u = L[n]
        if not u then error("Daylight UI's " .. name .. " no longer has a local " .. n .. ": re-fit tests/" .. name .. ".lua", 2) end
        debug.setupvalue(u.fn, u.i, value)
        u.value = value
    end
    function L.get(n)
        local u = L[n]
        if not u then error("Daylight UI's " .. name .. " no longer has a local " .. n .. ": re-fit tests/" .. name .. ".lua", 2) end
        return u.value
    end
    if spec.fit then spec.fit(L) end
    if jit then jit.flush() end
    for _, t in ipairs(found) do
        if not skip[t.title] then T.test((spec.rename or {})[t.title] or t.title, t.fn) end
    end
    return L
end

-- Empties a table in place (an allow list every function holding it then sees empty).
function H.empty(t)
    for k in pairs(t) do t[k] = nil end
    return t
end

-- Puts the module searcher and the stub in place. Called once by tests/run.lua.
function H.install()
    package.preload.stub = H.loadStub
    table.insert(package.loaders, 2, searcher)
    package.loaded.ez_harness = H
end

return H
