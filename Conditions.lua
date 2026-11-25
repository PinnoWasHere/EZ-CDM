local addonName, ns = ...

-- EZ-CDM's own conditions: things Daylight UI's card has no row for, each one line
-- in the grammar ("When I can't cast it, turn it gray"), drawn by an EZ-CDM effect
-- on Daylight UI's API.Attach holder of the piece's frame, never inside the game's
-- icon. Adding one is a Conditions.Register call, its words in Grammar.WORDING, and
-- tests.
--
-- A condition:
--   key        its name, as saved ("cantCast")
--   moment     the grammar moment its lines start with (Grammar.MOMENTS; a new one
--              joins the end)
--   actions    action word -> { effect = effect key, opts = what the effect draws }
--   fits(kind) whether a piece has the state it reads (Grammar.Kind)
--   read(key)  true, false, or nil when unknown, from plain sources only
--   detail(key)  optional: plain fields for the dev log
--   events     { game = { "EVENT" or { "EVENT", unit } }, daylight = { WatchCooldown
--              handler names } }: what may change it
--   secrecy    "plain" (its source answers in a fight) or "outOfCombat" (unknown in
--              a fight)
--   priority   optional: on one effect, the higher lit condition wins (default 0)
--   recipes    optional: { { key, action, after = recipe key } }, ready-made lines
--
-- An effect (Conditions.RegisterEffect):
--   key, fits(kind) optional, draw(holder, on, opts), clear(holder)
--
-- The driver reads each ruled piece on its conditions' events, two frames on (after
-- Daylight UI's own re-read on the next frame), on its Daylight UI watch handlers,
-- and as Daylight UI's frame events bring its frame. Watches and events run only
-- while a rule exists. No per-frame driver.
--
-- Rules live in EZCDMDB.conditions[profile][key] = { [condition] = { [action] = true } }.
-- Draft reads and writes them through Conditions.Merge and Conditions.Split.

local Bridge = ns.Bridge

local Conditions = {}
ns.Conditions = Conditions

-- Debug handle for an in-game check.
EZCDM_Conditions = Conditions

local API = _G.DaylightUI and _G.DaylightUI.API
local weak = { __mode = "k" }

-- Daylight UI's WatchCooldown handlers (API.md 1.14).
Conditions.DAYLIGHT = { ready = true, started = true, usable = true, proc = true, buffUp = true,
                        buffDown = true, changed = true }
Conditions.SECRECY = { plain = true, outOfCombat = true }

local list, byKey = {}, {}
local effects = {}

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

-- The grammar field a condition's action compiles to.
function Conditions.Field(key, action) return "ez:" .. key .. ":" .. action end

local function problem(c)
    if type(c) ~= "table" or type(c.key) ~= "string" or c.key == "" then return "no key" end
    if byKey[c.key] then return "taken" end
    if type(c.moment) ~= "string" then return "no moment" end
    if type(c.actions) ~= "table" or next(c.actions) == nil then return "no actions" end
    for a, act in pairs(c.actions) do
        if type(a) ~= "string" or type(act) ~= "table" or type(act.effect) ~= "string" then return "bad action" end
    end
    if type(c.fits) ~= "function" or type(c.read) ~= "function" then return "no fits or read" end
    local ev = c.events
    if type(ev) ~= "table" or (type(ev.game) ~= "table" and type(ev.daylight) ~= "table") then return "no events" end
    for _, h in ipairs(ev.daylight or {}) do
        if not Conditions.DAYLIGHT[h] then return "bad handler" end
    end
    if not Conditions.SECRECY[c.secrecy] then return "bad secrecy" end
end

-- Adds a condition. Grammar takes its lines at once (Grammar.InstallCondition).
-- Returns true, or false and why.
function Conditions.Register(c)
    local why = problem(c)
    if not why and ns.Grammar and ns.Grammar.ConditionClash(c) then why = "taken" end
    if why then return false, why end
    c.priority = type(c.priority) == "number" and c.priority or 0
    c.order = #list + 1
    list[#list + 1] = c
    byKey[c.key] = c
    if ns.Grammar and ns.Grammar.InstallCondition then ns.Grammar.InstallCondition(c) end
    return true
end

function Conditions.Get(key) return byKey[key] end
function Conditions.List() return list end

function Conditions.RegisterEffect(e)
    if type(e) ~= "table" or type(e.key) ~= "string" or effects[e.key]
        or type(e.draw) ~= "function" or type(e.clear) ~= "function" then return false end
    effects[e.key] = e
    return true
end
function Conditions.Effect(key) return effects[key] end

-- Whether a condition's action fits a piece: the condition reads it and the effect
-- can draw on it. Any piece when kind is nil.
function Conditions.Fits(key, action, kind)
    local c = byKey[key]
    local act = c and c.actions[action]
    if not act then return false end
    if kind == nil then return true end
    local e = effects[act.effect]
    return c.fits(kind) == true and (e == nil or e.fits == nil or e.fits(kind) == true)
end

-- ---------------------------------------------------------------------
-- Saved rules
-- ---------------------------------------------------------------------

local function store()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.conditions) ~= "table" then EZCDMDB.conditions = {} end
    return EZCDMDB.conditions
end

-- A piece's rule as saved: registered conditions and actions only, or nil.
local function clean(v)
    if type(v) ~= "table" then return nil end
    local out
    for ck, acts in pairs(v) do
        local c = byKey[ck]
        if c and type(acts) == "table" then
            for a, on in pairs(acts) do
                if on == true and c.actions[a] then
                    out = out or {}
                    out[ck] = out[ck] or {}
                    out[ck][a] = true
                end
            end
        end
    end
    return out
end

-- A piece's rule on talent set g's profile (current when nil), or nil.
function Conditions.Rule(key, g)
    local profile = Bridge.ProfileOf(g)
    local saved = profile ~= nil and store()[profile]
    return type(saved) == "table" and clean(saved[key]) or nil
end

-- Sets or clears a piece's rule on talent set g's profile, made first if it has
-- none. Refused in combat and while EZ-CDM is off (Bridge write reasons).
function Conditions.SetRule(g, key, value)
    local profile, why = Bridge.SavedProfile(g)
    if not profile then return false, why end
    local all = store()
    all[profile] = all[profile] or {}
    all[profile][key] = clean(value)
    if next(all[profile]) == nil then all[profile] = nil end
    Conditions.Sync()
    return true
end

-- Before Grammar.Decompile: the rule in the grammar's fields (Conditions.Field).
function Conditions.Merge(key, fields, g)
    local v = Conditions.Rule(key, g)
    for _, c in ipairs(list) do
        for a in pairs(c.actions) do
            fields[Conditions.Field(c.key, a)] = v and v[c.key] and v[c.key][a] or nil
        end
    end
    return fields
end

-- After Grammar.Compile: takes the conditions' fields out, which Daylight UI never
-- sees. Returns the rule for Conditions.SetRule.
function Conditions.Split(fields)
    local v = {}
    for _, c in ipairs(list) do
        for a in pairs(c.actions) do
            local f = Conditions.Field(c.key, a)
            if fields[f] == true then
                v[c.key] = v[c.key] or {}
                v[c.key][a] = true
            end
            fields[f] = nil
        end
    end
    return clean(v)
end

-- ---------------------------------------------------------------------
-- The driver
-- ---------------------------------------------------------------------

-- Key as a string -> the piece's frame, from Daylight UI's frame events.
local frameOf = {}
local keyOf = setmetatable({}, weak)
-- Key as a string -> the current profile's rule.
local rules = {}
-- Key as a string -> the lit condition key per effect key.
local litNow = {}
-- Holder -> true while some effect drew on it.
local drawn = setmetatable({}, weak)
local listener

local function readOf(c, k)
    if c.secrecy == "outOfCombat" and InCombatLockdown() then return nil end
    local v = c.read(k)
    if type(v) ~= "boolean" then return nil end
    return v
end

local function tell(k, c, action, effect, on)
    if not listener then return end
    local e = { key = k, condition = c.key, action = action, effect = effect, on = on }
    if c.detail then
        for f, v in pairs(c.detail(k) or {}) do
            if e[f] == nil then e[f] = v end
        end
    end
    listener(e)
end

-- Reads a piece's conditions and draws each effect's winner; the rest are put out.
local function refresh(k)
    local rule = rules[k]
    local frame = frameOf[k]
    local holder = frame and API.Attach(frame) or nil
    local want = {}   -- effect key -> { c, action }
    local asked = {}  -- effect key -> { { c, action }, ... }
    for ck, acts in pairs(rule or {}) do
        local c = byKey[ck]
        local lit = holder ~= nil and readOf(c, k) == true
        for a in pairs(acts) do
            local ek = c.actions[a].effect
            local rec = { c = c, action = a }
            asked[ek] = asked[ek] or {}
            asked[ek][#asked[ek] + 1] = rec
            local w = want[ek]
            if lit and (not w or c.priority > w.c.priority or (c.priority == w.c.priority and c.order < w.c.order)) then
                want[ek] = rec
            end
        end
    end
    local was = litNow[k] or {}
    local now = {}
    for ek, all in pairs(asked) do
        local e = effects[ek]
        local w = want[ek]
        if e and holder then
            for _, r in ipairs(all) do
                if r ~= w then e.draw(holder, false, r.c.actions[r.action].opts or {}) end
            end
            if w then
                e.draw(holder, true, w.c.actions[w.action].opts or {})
                drawn[holder] = true
            end
        end
        now[ek] = w and w.c.key .. ":" .. w.action or nil
    end
    -- Effects no rule asks for now are cleared.
    for ek in pairs(was) do
        if asked[ek] == nil and effects[ek] and holder then effects[ek].clear(holder) end
    end
    for ek, v in pairs(was) do
        if now[ek] ~= v then
            local ck, a = v:match("^(.-):(.*)$")
            if byKey[ck] then tell(k, byKey[ck], a, ek, false) end
        end
    end
    for ek, v in pairs(now) do
        if was[ek] ~= v then
            local ck, a = v:match("^(.-):(.*)$")
            tell(k, byKey[ck], a, ek, true)
        end
    end
    litNow[k] = next(now) and now or nil
end

-- Reads every ruled piece once, two frames on, after Daylight UI's own re-read.
local queued = false
local function refreshAll()
    queued = false
    for k in pairs(rules) do refresh(k) end
end
local function soon()
    if queued then return end
    queued = true
    C_Timer.After(0, function() C_Timer.After(0, refreshAll) end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", soon)
-- "EVENT" or "EVENT@unit" -> true while registered.
local registered = {}

local function eventName(e)
    if type(e) == "table" then return e[1] .. "@" .. tostring(e[2]), e[1], e[2] end
    return e, e
end

local function listen(want)
    for id in pairs(registered) do
        if not want[id] then
            events:UnregisterEvent(id:match("^[^@]+"))
            registered[id] = nil
        end
    end
    for id, e in pairs(want) do
        if not registered[id] then
            local _, name, unit = eventName(e)
            if unit then events:RegisterUnitEvent(name, unit) else events:RegisterEvent(name) end
            registered[id] = true
        end
    end
end

-- Key as a string -> its WatchCooldown handle (false where Daylight UI gave none),
-- and the handler names it was made with.
local watches, watchedWith = {}, {}
local me

local function handlersFor(rule)
    local names = {}
    for ck in pairs(rule) do
        for _, h in ipairs(byKey[ck].events.daylight or {}) do names[h] = true end
    end
    local sorted = {}
    for h in pairs(names) do sorted[#sorted + 1] = h end
    table.sort(sorted)
    return sorted
end

local function sync()
    local profile = Bridge.ProfileOf()
    local saved = profile ~= nil and store()[profile]
    local now, want = {}, {}
    for key, v in pairs(type(saved) == "table" and saved or {}) do
        local r = clean(v)
        if r then
            local k = tostring(key)
            now[k] = r
            for ck in pairs(r) do
                for _, e in ipairs(byKey[ck].events.game or {}) do want[(eventName(e))] = e end
            end
        end
    end
    rules = now
    for k, h in pairs(watches) do
        local names = now[k] and table.concat(handlersFor(now[k]), " ")
        if names ~= watchedWith[k] then
            if h then API.Off(h) end
            watches[k], watchedWith[k] = nil, nil
        end
    end
    for k, r in pairs(now) do
        local names = handlersFor(r)
        if watches[k] == nil and #names > 0 then
            me = me or API.For(addonName)
            local handlers = {}
            for _, h in ipairs(names) do handlers[h] = function() refresh(k) end end
            watches[k] = me.WatchCooldown(k, handlers) or false
            watchedWith[k] = table.concat(names, " ")
        end
    end
    listen(want)
    for k in pairs(litNow) do
        if not now[k] then refresh(k) end
    end
    for k in pairs(now) do refresh(k) end
end

-- Matches watches, events and effects to the current profile's rules.
function Conditions.Sync()
    if not (type(API) == "table" and Bridge.ApiFits()) then return end
    sync()
end

local function putOut(k, frame)
    local holder = frame and API.Attach(frame)
    if holder and drawn[holder] then
        for _, e in pairs(effects) do e.clear(holder) end
        drawn[holder] = nil
    end
    local was = litNow[k]
    litNow[k] = nil
    for ek, v in pairs(was or {}) do
        local ck, a = v:match("^(.-):(.*)$")
        if byKey[ck] then tell(k, byKey[ck], a, ek, false) end
    end
end

-- A piece's frame, made or showing another piece now.
local function place(kind, frame, unit, isPreview)
    if kind ~= "cdmpiece" or isPreview or unit == nil then return end
    local k = tostring(unit)
    local old = keyOf[frame]
    if old ~= nil and old ~= k and frameOf[old] == frame then
        putOut(old, frame)
        frameOf[old] = nil
    end
    frameOf[k], keyOf[frame] = frame, k
    if rules[k] then refresh(k) end
end

local function drop(kind, frame, _, isPreview)
    if kind ~= "cdmpiece" or isPreview then return end
    local k = keyOf[frame]
    keyOf[frame] = nil
    if k ~= nil and frameOf[k] == frame then
        putOut(k, frame)
        frameOf[k] = nil
    end
end

-- ---------------------------------------------------------------------
-- For tests, Report and the dev addon
-- ---------------------------------------------------------------------

-- What a piece shows now: effect key -> "condition:action", or nil for nothing.
function Conditions.Lit(key)
    local t = litNow[tostring(key)]
    if not t then return nil end
    local out = {}
    for ek, v in pairs(t) do out[ek] = v end
    return out
end
-- The piece's frame, from Daylight UI's frame events.
function Conditions.FrameOf(key) return frameOf[tostring(key)] end
-- Reads a piece now, as an event would (tests and a scenario driver).
function Conditions.Refresh(key) refresh(tostring(key)) end
-- How many pieces Daylight UI watches for EZ-CDM's conditions.
function Conditions.Watching()
    local n = 0
    for _, h in pairs(watches) do
        if h then n = n + 1 end
    end
    return n
end
-- The game events registered now, sorted ("EVENT" or "EVENT@unit").
function Conditions.Listening()
    local out = {}
    for id in pairs(registered) do out[#out + 1] = id end
    table.sort(out)
    return out
end
-- fn({ key, condition, action, effect, on, ...detail }) on each change, or nil to stop.
function Conditions.Listen(fn) listener = fn end

-- ---------------------------------------------------------------------
-- Built-in conditions: Daylight UI's plain castable state (API.CooldownState)
-- ---------------------------------------------------------------------

local USABLE_EVENTS = {
    -- The game's usability signals. Daylight UI re-reads usable and noPower on the
    -- next frame (CdmEffects.lua:1558-1561); its watch moments never fire on them.
    game = { "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN" },
    daylight = { "changed" },
}

local function usableDetail(k)
    local usable, noPower = Bridge.UsableState(k)
    return { usable = usable, noPower = noPower }
end

-- Can't be cast for a reason other than power, as Daylight UI's own Not usable.
Conditions.Register({
    key = "cantCast", moment = "unusable",
    actions = { gray = { effect = "wash", opts = { id = "gray", color = "OFF" } } },
    fits = function(kind) return kind.cooldown == true end,
    read = function(k)
        local usable, noPower = Bridge.UsableState(k)
        if usable == nil or noPower == nil then return nil end
        return usable == false and noPower == false
    end,
    detail = usableDetail,
    events = USABLE_EVENTS, secrecy = "plain",
    recipes = { { key = "canCast", action = "gray", after = "dimCooling" } },
})

-- Only short of power (mana, rage, energy).
Conditions.Register({
    key = "noMana", moment = "short",
    actions = { blue = { effect = "wash", opts = { id = "blue", color = "mana" } } },
    fits = function(kind) return kind.cooldown == true end,
    read = function(k)
        local _, noPower = Bridge.UsableState(k)
        return noPower
    end,
    detail = usableDetail,
    events = USABLE_EVENTS, secrecy = "plain", priority = 1,
    recipes = { { key = "manaCheck", action = "blue", after = "canCast" } },
})

-- ---------------------------------------------------------------------
-- Wiring
-- ---------------------------------------------------------------------

if type(API) == "table" and type(API.On) == "function" and Bridge.ApiFits() then
    API.On("FrameMade", place, addonName)
    API.On("FrameUnitChanged", place, addonName)
    API.On("FrameRemoved", drop, addonName)
    API.On("Login", function()
        Conditions.Sync()
        if Bridge.Ready() then Bridge.HookEditor("Draw", Conditions.Sync) end
    end, addonName)
end

-- Another profile: a talent set switch, or one picked in the editor (its Draw).
local profiles = CreateFrame("Frame")
profiles:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
profiles:SetScript("OnEvent", function() Conditions.Sync() end)
