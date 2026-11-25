local addonName, ns = ...

-- EZ-CDM's own conditions: things Daylight UI's card has no row for, each one line
-- in the grammar ("When I can't cast it, turn it gray"), drawn by an EZ-CDM effect
-- on Daylight UI's API.Attach holder of the piece's frame, never inside the game's
-- icon. Adding one is a Conditions.Register call, its words, and tests
-- (docs/specs/conditions-waves.md).
--
-- A condition:
--   key        its name, as saved ("cantCast")
--   moment     the grammar moment its lines start with (Grammar.MOMENTS; a new one
--              joins the end)
--   actions    action word -> { effect = effect key, opts = what the effect draws }.
--              A plain one also gets "sound" (Grammar.InstallCondition)
--   fits(kind) whether a piece has the state it reads (Grammar.Kind)
--   secrecy    its tier: "plain" (answers in a fight), "outOfCombat" (unknown in a
--              fight; never offered in the drawer) or "client" (secret in a fight, but
--              a secret-safe setter takes it whole)
--   read(key, n)  plain and outOfCombat: true, false, or nil when unknown
--   drive(holder, layer, opts)  client: hands the game's secret answer to layer's
--              alpha through a secret-safe setter (a curve into SetAlpha,
--              SetAlphaFromBoolean). It never compares it. opts = { key, n }; holder
--              is nil when the dev suite samples it
--   param      optional { min, max, default, unit }: it takes a typed whole number n
--   advanced   optional: offered only behind the drawer's "more…"
--   ticker     optional, client only: re-driven on the shared ticker
--   words      optional { moment, clause, never }: its phrases, put in
--              Grammar.WORDING unless set there; "#" marks the number, "%s" the
--              power name. never[key] is why it can't hold with that condition
--   noSound    optional: no sound action
--   layer      the icon it is about: "cooldown", "buff" or "any". On a piece that
--              shows its buff and its cooldown, a line draws only while its icon shows
--   excludes   { condition key, ... }: parts it can never be true with, read both
--              ways. Its words.never[key] says why. A "cooldown" and a "buff" part
--              never hold together either
--   clauseOnly optional: offered only after "and", never as a line's moment
--   detail(key)  optional: plain fields for the dev log
--   events     { game = { "EVENT" or { "EVENT", unit } }, daylight = { WatchCooldown
--              handler names } }: what may change it
--   priority   optional: on one effect, the higher lit condition wins (default 0)
--   recipes    optional: { { key, action, after = recipe key } }, ready-made lines
--
-- An effect (Conditions.RegisterEffect):
--   key, fits(kind) optional, draw(target, on, opts), clear(target)
--   shown(target, opts)  optional: what it drew on target, for Conditions.Visible
--   client     draws only alpha-safe looks, so a line with a client part may use it
--   edge       fires once as its line turns on (a sound)
--   stack      each line has a slot of its own instead of one priority winner
--
-- A line is its condition (the moment), optional "and" clauses, and an action. Its
-- plain parts are ANDed here. A client part may only come last, once: the effect
-- then draws on a layer, a child frame of the holder, and the client part sets the
-- layer's alpha.
--
-- The driver reads each ruled piece on its parts' events, two frames on (after
-- Daylight UI's own re-read on the next frame), on its Daylight UI watch handlers,
-- and as Daylight UI's frame events bring its frame. Watches and events run only
-- while a rule exists. No per-frame driver: the one exception is a shared
-- C_Timer ticker (Conditions.TICK), on only while a rule uses a ticker condition.
--
-- Rules live in EZCDMDB.conditions[profile][key] = { [condition] = { [action] = spec } },
-- spec true or { n, value, style, clauses = { { cond, n } } } (Conditions.Spec): value
-- is a sound's key or a glow's color, style a glow's own style. Draft reads
-- and writes them through Conditions.Merge and Conditions.Split.

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
Conditions.SECRECY = { plain = true, outOfCombat = true, client = true }
Conditions.LAYERS = { cooldown = true, buff = true, any = true }
-- The saved rules' form. 2: "cantCast" is any reason; the old one is "notUsable".
Conditions.VERSION = 2
-- The shared ticker's beat, in seconds.
Conditions.TICK = 0.2
-- What the dev suite logs for a value the game keeps secret.
Conditions.SECRET = "<secret>"

local list, byKey = {}, {}
local effects = {}

-- ---------------------------------------------------------------------
-- The registry
-- ---------------------------------------------------------------------

-- The grammar field a condition's action compiles to.
function Conditions.Field(key, action) return "ez:" .. key .. ":" .. action end

local function whole(n) return type(n) == "number" and n % 1 == 0 end

local function badParam(p)
    if p == nil then return false end
    if type(p) ~= "table" or not (whole(p.min) and whole(p.max) and whole(p.default)) then return true end
    return p.min > p.max or p.default < p.min or p.default > p.max
end

local function problem(c)
    if type(c) ~= "table" or type(c.key) ~= "string" or c.key == "" then return "no key" end
    if byKey[c.key] then return "taken" end
    if type(c.moment) ~= "string" then return "no moment" end
    if type(c.actions) ~= "table" or next(c.actions) == nil then return "no actions" end
    for a, act in pairs(c.actions) do
        if type(a) ~= "string" or type(act) ~= "table" or type(act.effect) ~= "string" then return "bad action" end
    end
    if not Conditions.SECRECY[c.secrecy] then return "bad secrecy" end
    if type(c.fits) ~= "function" then return "no fits or read" end
    if c.secrecy == "client" then
        if type(c.drive) ~= "function" then return "no drive" end
    elseif type(c.read) ~= "function" then
        return "no fits or read"
    end
    local ev = c.events
    if type(ev) ~= "table" or (type(ev.game) ~= "table" and type(ev.daylight) ~= "table") then return "no events" end
    for _, h in ipairs(ev.daylight or {}) do
        if not Conditions.DAYLIGHT[h] then return "bad handler" end
    end
    if badParam(c.param) then return "bad param" end
    if c.ticker and c.secrecy ~= "client" then return "bad ticker" end
    if not Conditions.LAYERS[c.layer] then return "bad layer" end
    if c.excludes ~= nil then
        if type(c.excludes) ~= "table" then return "bad excludes" end
        for _, k in ipairs(c.excludes) do
            if type(k) ~= "string" then return "bad excludes" end
        end
    end
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

-- Whether a condition reads on a piece of kind (any piece when kind is nil).
function Conditions.FitsKind(key, kind)
    local c = byKey[key]
    if not c then return false end
    return kind == nil or c.fits(kind) == true
end

-- Whether an action's effect can draw a client part.
function Conditions.ClientSafe(key, action)
    local c = byKey[key]
    local act = c and c.actions[action]
    local e = act and effects[act.effect]
    return e ~= nil and e.client == true
end

-- Whether a condition's action is a gray: the wash's desaturated copy (Overlay.lua).
function Conditions.Grays(key, action)
    local c = byKey[key]
    local act = c and c.actions[action]
    return act ~= nil and act.effect == "wash" and type(act.opts) == "table" and act.opts.look == "desat"
end

-- Whether two conditions can never be true at once: either names the other in its
-- excludes, or one is about the cooldown icon and the other the buff icon.
function Conditions.Excludes(a, b)
    local ca, cb = byKey[a], byKey[b]
    if not (ca and cb) then return false end
    for _, k in ipairs(ca.excludes or {}) do
        if k == b then return true end
    end
    for _, k in ipairs(cb.excludes or {}) do
        if k == a then return true end
    end
    local la, lb = ca.layer, cb.layer
    return (la == "cooldown" and lb == "buff") or (la == "buff" and lb == "cooldown")
end

-- The icon a line is about: its first part that names one, else "any".
function Conditions.LineLayer(ck, spec)
    local c = byKey[ck]
    if c and c.layer ~= "any" then return c.layer end
    for _, cl in ipairs(type(spec) == "table" and type(spec.clauses) == "table" and spec.clauses or {}) do
        local x = type(cl) == "table" and byKey[cl.cond]
        if x and x.layer ~= "any" then return x.layer end
    end
    return "any"
end

-- Whether any advanced condition the drawer could offer is registered.
function Conditions.AnyAdvanced()
    for _, c in ipairs(list) do
        if c.advanced and c.secrecy ~= "outOfCombat" then return true end
    end
    return false
end

-- Whether a condition's action fits a piece: the condition reads it and the effect
-- can draw on it, and a client condition's effect draws alpha-safe looks. Any piece
-- when kind is nil.
function Conditions.Fits(key, action, kind)
    local c = byKey[key]
    local act = c and c.actions[action]
    if not act or c.clauseOnly then return false end
    if c.secrecy == "client" and not Conditions.ClientSafe(key, action) then return false end
    if kind == nil then return true end
    local e = effects[act.effect]
    return c.fits(kind) == true and (e == nil or e.fits == nil or e.fits(kind) == true)
end

-- Whether n is a number condition key takes, within its range.
function Conditions.NumberFits(key, n)
    local c = byKey[key]
    local p = c and c.param
    return p ~= nil and whole(n) and n >= p.min and n <= p.max
end

-- The number a part reads with: its own, else its condition's default; nil for a
-- condition that takes none.
function Conditions.NumberOf(key, n)
    local c = byKey[key]
    local p = c and c.param
    if not p then return nil end
    if Conditions.NumberFits(key, n) then return n end
    return p.default
end

-- ---------------------------------------------------------------------
-- Saved rules
-- ---------------------------------------------------------------------

-- Rules saved before VERSION 2 meant Daylight UI's Not usable by "cantCast". They
-- move to "notUsable", which keeps what the player sees; "cantCast" now counts a
-- cooldown and short power too.
local function migrate(all)
    for _, pieces in pairs(all) do
        for _, rule in pairs(type(pieces) == "table" and pieces or {}) do
            if type(rule) == "table" then
                for _, acts in pairs(rule) do
                    for _, spec in pairs(type(acts) == "table" and acts or {}) do
                        for _, cl in ipairs(type(spec) == "table" and type(spec.clauses) == "table" and spec.clauses or {}) do
                            if type(cl) == "table" and cl.cond == "cantCast" then cl.cond = "notUsable" end
                        end
                    end
                end
                if rule.cantCast ~= nil and rule.notUsable == nil then
                    rule.notUsable, rule.cantCast = rule.cantCast, nil
                end
            end
        end
    end
end

local function store()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.conditions) ~= "table" then EZCDMDB.conditions = {} end
    if EZCDMDB.conditionsVersion ~= Conditions.VERSION then
        migrate(EZCDMDB.conditions)
        EZCDMDB.conditionsVersion = Conditions.VERSION
    end
    return EZCDMDB.conditions
end

-- A part's number as saved: nil for none, a bad one, or the default.
local function savedNumber(key, n)
    if not Conditions.NumberFits(key, n) then return nil end
    if n == byKey[key].param.default then return nil end
    return n
end

-- A line's spec as saved: registered parts only, the default number left out.
-- true when it has nothing beyond the line itself; nil when it isn't one.
function Conditions.Spec(ck, action, spec)
    local c = byKey[ck]
    local act = c and c.actions[action]
    if not act then return nil end
    if spec == true then return true end
    if type(spec) ~= "table" then return nil end
    local out = {}
    out.n = savedNumber(ck, spec.n)
    if act.effect == "sound" and type(spec.value) == "string" then out.value = spec.value end
    if act.effect == "glow" then
        local v = spec.value
        if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number" then
            out.value = { v[1], v[2], v[3] }
        end
        if type(spec.style) == "string" then out.style = spec.style end
    end
    local clauses = {}
    for _, cl in ipairs(type(spec.clauses) == "table" and spec.clauses or {}) do
        if type(cl) == "table" and byKey[cl.cond] then
            clauses[#clauses + 1] = { cond = cl.cond, n = savedNumber(cl.cond, cl.n) }
        end
    end
    if #clauses > 0 then out.clauses = clauses end
    if next(out) == nil then return true end
    return out
end

-- A piece's rule as saved: registered conditions and actions only, or nil.
local function clean(v)
    if type(v) ~= "table" then return nil end
    local out
    for ck, acts in pairs(v) do
        if byKey[ck] and type(acts) == "table" then
            for a, spec in pairs(acts) do
                local s = Conditions.Spec(ck, a, spec)
                if s ~= nil then
                    out = out or {}
                    out[ck] = out[ck] or {}
                    out[ck][a] = s
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
            if fields[f] ~= nil then
                v[c.key] = v[c.key] or {}
                v[c.key][a] = fields[f]
            end
            fields[f] = nil
        end
    end
    return clean(v)
end

-- ---------------------------------------------------------------------
-- A line's parts
-- ---------------------------------------------------------------------

-- A line's parts in order, { { c, n }, ... } (n as saved, nil for the default),
-- its plain parts, and its client part (the last one), or nil when a client part
-- isn't last or comes twice.
local function partsOf(ck, spec)
    local s = type(spec) == "table" and spec or {}
    local parts = { { c = byKey[ck], n = s.n } }
    for _, cl in ipairs(s.clauses or {}) do parts[#parts + 1] = { c = byKey[cl.cond], n = cl.n } end
    local plain, client = {}, nil
    for i, p in ipairs(parts) do
        if not p.c then return nil end
        if p.c.secrecy == "client" then
            if i ~= #parts then return nil end
            client = p
        else
            plain[#plain + 1] = p
        end
    end
    return parts, plain, client
end

local function numberOf(p) return Conditions.NumberOf(p.c.key, p.n) end

-- ---------------------------------------------------------------------
-- The driver
-- ---------------------------------------------------------------------

-- Key as a string -> the piece's frame, from Daylight UI's frame events.
local frameOf = {}
local keyOf = setmetatable({}, weak)
-- Key as a string -> the current profile's rule.
local rules = {}
-- Key as a string -> slot -> the lit line's id ("condition:action").
local litNow = {}
-- Holder -> true while some effect drew on it.
local drawn = setmetatable({}, weak)
-- Holder -> line id -> its layer.
local layers = setmetatable({}, weak)
-- Key as a string -> line id -> { c, holder, layer, n }: lit lines on the ticker.
local ticking = {}
-- Key as a string -> true for a piece that shows its buff and its cooldown in turn.
local both = {}
local ticker
local listener

local function readOf(c, k, n)
    if c.secrecy == "outOfCombat" and InCombatLockdown() then return nil end
    local v = c.read(k, n)
    if type(v) ~= "boolean" then return nil end
    return v
end

local function layerFor(holder, id)
    local set = layers[holder]
    if not set then
        set = {}
        layers[holder] = set
    end
    local f = set[id]
    if not f then
        f = CreateFrame("Frame", nil, holder)
        f:SetAllPoints(holder)
        f:Hide()
        set[id] = f
    end
    return f
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

local function idParts(id) return id:match("^(.-):(.*)$") end

-- Whether the icon a line is about shows on a piece now. A piece that shows its
-- buff and its cooldown shows the buff while it is up, else the cooldown.
local function layerShows(k, layer)
    if layer == "any" or not both[k] then return true end
    local up = Bridge.BuffState(k)
    if layer == "cooldown" then return up ~= true end
    return up == true
end
local function effectOf(slot) return slot:match("^[^|]+") end

-- Key as a string -> the piece's own glow style (Daylight UI's glowStyle).
local styleOf = {}

-- What an effect draws for a line: the action's opts with the piece's key, the
-- line's sound or color, number and glow style (the piece's own when it has none).
local function optsFor(act, spec, k)
    local out = { key = k }
    for f, v in pairs(act.opts or {}) do out[f] = v end
    if type(spec) == "table" then out.value, out.n, out.style = spec.value, spec.n, spec.style end
    if act.effect == "glow" and out.style == nil and k then out.style = styleOf[k] end
    return out
end

local function off(holder, r)
    local e = effects[r.ek]
    if r.client then
        local f = layers[holder] and layers[holder][r.id]
        if f then
            e.draw(f, false, r.opts)
            f:Hide()
        end
    elseif not e.edge then
        e.draw(holder, false, r.opts)
    end
end

-- Reads a piece's lines and draws each slot's winner; the rest are put out.
local function refresh(k)
    local rule = rules[k]
    local frame = frameOf[k]
    local holder = frame and API.Attach(frame) or nil
    local want = {}   -- slot -> line record
    local asked = {}  -- slot -> { line record, ... }
    for ck, acts in pairs(rule or {}) do
        local c = byKey[ck]
        for a, spec in pairs(acts) do
            local act = c.actions[a]
            local e = effects[act.effect]
            local _, plain, client = partsOf(ck, spec)
            local lit = holder ~= nil and plain ~= nil and layerShows(k, Conditions.LineLayer(ck, spec))
            for _, p in ipairs(lit and plain or {}) do
                if readOf(p.c, k, numberOf(p)) ~= true then
                    lit = false
                    break
                end
            end
            local id = ck .. ":" .. a
            local own = client ~= nil or (e ~= nil and (e.stack or e.edge))
            local slot = own and (act.effect .. "|" .. id) or act.effect
            local rec = { c = c, action = a, id = id, ek = act.effect, client = client, opts = optsFor(act, spec, k) }
            asked[slot] = asked[slot] or {}
            asked[slot][#asked[slot] + 1] = rec
            local w = want[slot]
            if lit and (not w or c.priority > w.c.priority or (c.priority == w.c.priority and c.order < w.c.order)) then
                want[slot] = rec
            end
        end
    end
    local was = litNow[k] or {}
    local now = {}
    local ticks = {}
    for slot, all in pairs(asked) do
        local w = want[slot]
        local e = effects[all[1].ek]
        if e and holder then
            for _, r in ipairs(all) do
                if r ~= w then off(holder, r) end
            end
            if w and w.client then
                local f = layerFor(holder, w.id)
                f:Show()
                e.draw(f, true, w.opts)
                local n = numberOf(w.client)
                w.client.c.drive(holder, f, { key = k, n = n })
                if w.client.c.ticker then ticks[w.id] = { c = w.client.c, holder = holder, layer = f, n = n } end
                drawn[holder] = true
            elseif w and (not e.edge or was[slot] ~= w.id) then
                e.draw(holder, true, w.opts)
                drawn[holder] = true
            end
        end
        now[slot] = w and w.id or nil
    end
    ticking[k] = next(ticks) and ticks or nil
    -- Slots no rule asks for now are cleared.
    for slot in pairs(was) do
        local ek = effectOf(slot)
        if asked[slot] == nil and effects[ek] and holder then
            local id = slot:match("|(.+)$")
            local f = id and layers[holder] and layers[holder][id]
            if f then
                effects[ek].clear(f)
                f:Hide()
            elseif not id then
                effects[ek].clear(holder)
            end
        end
    end
    for slot, id in pairs(was) do
        if now[slot] ~= id then
            local ck, a = idParts(id)
            if byKey[ck] then tell(k, byKey[ck], a, effectOf(slot), false) end
        end
    end
    for slot, id in pairs(now) do
        if was[slot] ~= id then
            local ck, a = idParts(id)
            tell(k, byKey[ck], a, effectOf(slot), true)
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

-- The shared ticker: re-drives each lit line whose client part is a ticker one.
local function tick()
    for k, lines in pairs(ticking) do
        for _, t in pairs(lines) do t.c.drive(t.holder, t.layer, { key = k, n = t.n }) end
    end
end

local function setTicker(on)
    if on and not ticker then
        ticker = C_Timer.NewTicker(Conditions.TICK, tick)
    elseif not on and ticker then
        ticker:Cancel()
        ticker = nil
        ticking = {}
    end
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

-- Every condition a rule's lines use, clauses included: key -> condition.
local function usedBy(rule)
    local out = {}
    for ck, acts in pairs(rule) do
        out[ck] = byKey[ck]
        for _, spec in pairs(acts) do
            for _, cl in ipairs(type(spec) == "table" and spec.clauses or {}) do out[cl.cond] = byKey[cl.cond] end
        end
    end
    return out
end

-- Key as a string -> its WatchCooldown handle (false where Daylight UI gave none),
-- and the handler names it was made with.
local watches, watchedWith = {}, {}
local me

local function handlersFor(rule, k)
    local names = {}
    for _, c in pairs(usedBy(rule)) do
        for _, h in ipairs(c.events.daylight or {}) do names[h] = true end
        -- Its icon comes and goes with the buff.
        if both[k] and c.layer ~= "any" then names.buffUp, names.buffDown = true, true end
    end
    local sorted = {}
    for h in pairs(names) do sorted[#sorted + 1] = h end
    table.sort(sorted)
    return sorted
end

-- Each placed piece that shows its buff and its cooldown in turn, and each one's
-- glow style.
local function readPieces()
    local layout = Bridge.Layout()
    local two, styles = {}, {}
    for key, p in pairs(type(layout) == "table" and type(layout.pieces) == "table" and layout.pieces or {}) do
        local k = tostring(key)
        if Bridge.Shows(key, p) == "both" then two[k] = true end
        local st = Bridge.Option(p, "glowStyle")
        if type(st) == "string" then styles[k] = st end
    end
    return two, styles
end

local function sync()
    if ns.Gray then ns.Gray.Reconcile() end
    local profile = Bridge.ProfileOf()
    local saved = profile ~= nil and store()[profile]
    both, styleOf = readPieces()
    local now, want = {}, {}
    local ticks = false
    for key, v in pairs(type(saved) == "table" and saved or {}) do
        local r = clean(v)
        if r and ns.Gray and ns.Gray.Cooling(key) then r[Conditions.COOLING] = { gray = true } end
        if r then
            local k = tostring(key)
            now[k] = r
            for _, c in pairs(usedBy(r)) do
                for _, e in ipairs(c.events.game or {}) do want[(eventName(e))] = e end
                ticks = ticks or c.ticker == true
            end
        end
    end
    rules = now
    for k, h in pairs(watches) do
        local names = now[k] and table.concat(handlersFor(now[k], k), " ")
        if names ~= watchedWith[k] then
            if h then API.Off(h) end
            watches[k], watchedWith[k] = nil, nil
        end
    end
    for k, r in pairs(now) do
        local names = handlersFor(r, k)
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
    setTicker(ticks)
end

-- Matches watches, events, the ticker and effects to the current profile's rules.
function Conditions.Sync()
    if not (type(API) == "table" and Bridge.ApiFits()) then return end
    sync()
end

local function putOut(k, frame)
    local holder = frame and API.Attach(frame)
    if holder and drawn[holder] then
        for _, e in pairs(effects) do e.clear(holder) end
        for _, f in pairs(layers[holder] or {}) do
            for _, e in pairs(effects) do e.clear(f) end
            f:Hide()
        end
        drawn[holder] = nil
    end
    ticking[k] = nil
    local was = litNow[k]
    litNow[k] = nil
    for slot, id in pairs(was or {}) do
        local ck, a = idParts(id)
        if byKey[ck] then tell(k, byKey[ck], a, effectOf(slot), false) end
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

-- What a piece shows now: slot -> "condition:action", or nil for nothing. A slot is
-- the effect's key, or "effect|condition:action" for a line with a slot of its own.
function Conditions.Lit(key)
    local t = litNow[tostring(key)]
    if not t then return nil end
    local out = {}
    for slot, v in pairs(t) do out[slot] = v end
    return out
end
-- The piece's frame, from Daylight UI's frame events.
function Conditions.FrameOf(key) return frameOf[tostring(key)] end
-- A line's layer on the piece's holder (id "condition:action"), once drawn.
function Conditions.Layer(key, id)
    local frame = frameOf[tostring(key)]
    local holder = frame and API.Attach(frame)
    return holder and layers[holder] and layers[holder][id] or nil
end
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
-- Whether the shared ticker runs, and one beat of it now (the class world's clock).
function Conditions.Ticking() return ticker ~= nil end
function Conditions.Tick() tick() end
-- fn({ key, condition, action, effect, on, ...detail }) on each change, or nil to stop.
function Conditions.Listen(fn) listener = fn end

-- A piece's lines in id order: { id, condition, action, parts = { { cond, n } } },
-- n as saved (nil for the default).
function Conditions.Lines(key)
    local out = {}
    for ck, acts in pairs(Conditions.Rule(key) or {}) do
        for a, spec in pairs(acts) do
            local parts = {}
            for _, p in ipairs((partsOf(ck, spec)) or {}) do parts[#parts + 1] = { cond = p.c.key, n = p.n } end
            out[#out + 1] = { id = ck .. ":" .. a, condition = ck, action = a, parts = parts }
        end
    end
    table.sort(out, function(x, y) return x.id < y.id end)
    return out
end

-- Whether a line's effect can be seen on a piece now: { lit, shown, alpha, covered,
-- gray, layered }. lit: the driver lights it. shown: the piece's frame and what the effect
-- drew are on show. alpha: what the effect drew, Conditions.SECRET while the client
-- keeps it. covered: the icon its condition is about doesn't show now
-- (Conditions.LineLayer). gray: what a gray line's copy shows, out of a fight
-- (Overlay's check: copy, same, game). layered: a client line's effect hangs under
-- the layer its condition drives.
function Conditions.Visible(key, id)
    local k = tostring(key)
    local out = { lit = false, shown = false, alpha = 0, covered = false }
    local ck = idParts(id)
    local rule = rules[k]
    local a = select(2, idParts(id))
    local spec = rule and rule[ck] and rule[ck][a]
    if spec ~= nil then out.covered = not layerShows(k, Conditions.LineLayer(ck, spec)) end
    for slot, v in pairs(litNow[k] or {}) do
        if v == id then out.lit = true; out.slot = slot end
    end
    local frame = frameOf[k]
    local c = byKey[ck]
    local act = c and c.actions[a]
    local e = act and effects[act.effect]
    local holder = frame and API.Attach(frame)
    local target = holder and layers[holder] and layers[holder][id]
    if holder and e and e.check and not InCombatLockdown() then
        out.gray = e.check(target or holder, optsFor(act, spec, k))
    end
    if not (out.lit and frame and frame:IsVisible() and e) then return out end
    local drawn = target or holder
    if e.shown then
        local obj = e.shown(drawn, optsFor(act, spec, k))
        if not obj then return out end
        drawn = obj
    end
    local alpha = drawn:GetAlpha()
    if target then
        local la = target:GetAlpha()
        if issecretvalue(la) then alpha = Conditions.SECRET
        elseif not issecretvalue(alpha) then alpha = alpha * la end
    end
    if issecretvalue(alpha) then alpha = Conditions.SECRET end
    out.shown = drawn:IsVisible() == true
    out.alpha = alpha
    if target then
        -- What a client part drives is the layer, so the effect must hang under it.
        local f = drawn
        while f and f ~= target do f = f:GetParent() end
        out.layered = f == target
    end
    return out
end

-- A scratch frame a client condition drives when sampled.
local scratch

-- One condition's live value on a piece: true, false or nil for a plain one;
-- for a client one, what its drive set: true or false while the game answers
-- plainly, Conditions.SECRET while it keeps the answer secret.
function Conditions.Sample(ck, key, n)
    local c = byKey[ck]
    if not c then return nil end
    n = Conditions.NumberOf(ck, n)
    if c.secrecy ~= "client" then return readOf(c, tostring(key), n) end
    scratch = scratch or CreateFrame("Frame")
    scratch:SetAlpha(0)
    c.drive(nil, scratch, { key = tostring(key), n = n })
    local a = scratch:GetAlpha()
    if issecretvalue(a) then return Conditions.SECRET end
    return type(a) == "number" and a > 0
end

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
    local usable, noPower, onCooldown = Bridge.UsableState(k)
    return { usable = usable, noPower = noPower, onCooldown = onCooldown }
end

-- A piece the castable words read: a cooldown, or a spell button (Grammar.Kind).
local function castable(kind) return kind.cooldown == true or kind.button == true end

local WASH_GRAY = { effect = "wash", opts = { id = "gray", look = "desat" } }
local GLOW = { effect = "glow" }

-- Can't be cast now, for any reason: on cooldown, short of power, or not usable.
Conditions.Register({
    key = "cantCast", moment = "blocked",
    actions = { gray = WASH_GRAY, glow = GLOW },
    fits = castable,
    read = function(k)
        local usable, _, onCooldown = Bridge.UsableState(k)
        if usable == false or onCooldown == true then return true end
        if usable == nil or onCooldown == nil then return nil end
        return false
    end,
    detail = usableDetail,
    events = { game = USABLE_EVENTS.game, daylight = { "changed", "ready", "started" } },
    secrecy = "plain", layer = "cooldown", excludes = {},
    words = { moment = "When I can't cast it", clause = "I can't cast it" },
    recipes = { { key = "canCast", action = "gray", after = "dimCooling" } },
})

-- Can't be cast for a reason other than power or a cooldown (a stance, no target,
-- the wrong weapon), as Daylight UI's own Not usable.
Conditions.Register({
    key = "notUsable", moment = "unusable",
    actions = { gray = WASH_GRAY, glow = GLOW },
    fits = castable,
    read = function(k)
        local usable, noPower = Bridge.UsableState(k)
        if usable == nil or noPower == nil then return nil end
        return usable == false and noPower == false
    end,
    detail = usableDetail,
    events = USABLE_EVENTS, secrecy = "plain", layer = "cooldown", excludes = { "noMana" },
    words = { moment = "When it's not usable", clause = "it's not usable",
              never = { noMana = "not usable never counts %s" } },
})

-- Only short of power (mana, rage, energy).
Conditions.Register({
    key = "noMana", moment = "short",
    actions = { blue = { effect = "wash", opts = { id = "blue", color = "mana" } }, glow = GLOW },
    fits = castable,
    read = function(k)
        local _, noPower = Bridge.UsableState(k)
        return noPower
    end,
    detail = usableDetail,
    events = USABLE_EVENTS, secrecy = "plain", layer = "cooldown", excludes = { "notUsable" }, priority = 1,
    words = { moment = "When I don't have enough %s", clause = "I don't have enough %s" },
    recipes = { { key = "manaCheck", action = "blue", after = "canCast" } },
})

-- Its buff isn't up, as Daylight UI's own item says. Only after "and": on a piece
-- that shows its buff and its cooldown, it keeps a line to the cooldown icon.
Conditions.Register({
    key = "noBuff", moment = "noBuff", clauseOnly = true, noSound = true,
    actions = { gray = WASH_GRAY },
    fits = function(kind) return kind.buff == true end,
    read = function(k)
        local up = Bridge.BuffState(k)
        if up == nil then return nil end
        return not up
    end,
    events = { daylight = { "buffUp", "buffDown", "changed" } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "While its buff isn't active", clause = "its buff isn't active" },
})

-- Daylight UI's own "While it's cooling down, turn it gray" (Gray out at Gray), drawn
-- by EZ-CDM while it owns the piece's gray (Gray.lua). Never registered, so it is
-- never offered or saved: the driver adds its line to a piece whose kept Gray out
-- is Gray (Gray.Cooling). It reads a real cooldown, never the global one, as
-- Daylight UI's Gray does (CdmEffects.lua wantGrey).
Conditions.COOLING = "daylightCooling"
byKey[Conditions.COOLING] = {
    key = Conditions.COOLING, moment = "cooldown", order = 0, priority = 0,
    actions = { gray = WASH_GRAY },
    fits = castable,
    read = function(k)
        local _, _, onCooldown = Bridge.UsableState(k)
        return onCooldown
    end,
    detail = usableDetail,
    events = { game = { "SPELL_UPDATE_COOLDOWN" }, daylight = { "changed", "ready", "started" } },
    secrecy = "plain", layer = "cooldown", excludes = {},
}

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
