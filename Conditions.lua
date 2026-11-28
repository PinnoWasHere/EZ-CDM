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
--   detail(key)  optional: the game's answers it reads, for the dev log, each plain or
--              Conditions.SECRET
--   using(keys)  optional: told on each sync which pieces' rules use it ({ [key] =
--              true }, empty when none), so it can ask the game for the events it
--              needs (a spell's range check)
--   events     { game = { "EVENT" or { "EVENT", unit } }, daylight = { WatchCooldown
--              handler names } }: what may change it
--   priority   optional: on one effect, the higher lit condition wins (default 0)
--   recipes    optional: { { key, action, after = recipe key } }, ready-made lines
--   time(k, n) optional: while true, its seconds left and its whole length, both
--              plain, or nil when the game won't say (a hides effect shows them)
--   late       optional: it reads what Daylight UI drew, so each of its Daylight UI
--              handlers reads the piece again a frame on, after Daylight UI's pass
--   armed      optional, plain only: the moment is its turning true. A line holding it
--              fires an edge effect only as this part turns true from a plain false,
--              never on its first read or as another part turns true. Held effects
--              stay lit while it is true
--   looks      optional { look action, ... }: the only looks it takes. Its actions may
--              start empty, and the looks fill them
--   alone      optional: never an "and" part, and its lines take none
--
-- An effect (Conditions.RegisterEffect):
--   key, fits(kind) optional, draw(target, on, opts), clear(target)
--   shown(target, opts)  optional: what it drew on target, for Conditions.Visible
--   client     draws only alpha-safe looks, so a line with a client part may use it
--   edge       fires once as its line turns on (a sound, a flash)
--   hides      with edge: draw(target, false, opts) as its line turns off, and
--              clear(target, line id) when its line goes. opts.left and opts.dur
--              are the line's first part's time, when it has one
--   stack      each line has a slot of its own instead of one priority winner
--   value      optional: what a line's value holds for it, "color" ({ r, g, b }),
--              "text" (a few plain words), "icon" (a file id or name), or a kind
--              added by Conditions.RegisterValue
--   anyFace    decorates the whole piece on its holder, so on a piece that shows its
--              buff and its cooldown in turn it shows on either face. Without it a line
--              about one icon draws only while that icon shows
--   watch      optional { game, daylight, late }: what may change what it draws, as a
--              condition's events and late. A piece whose lines use it reads again on
--              them
--
-- A look (Conditions.RegisterLook) is an action every condition's lines may end in,
-- drawn by one effect: "flash it", "sparkle" (Looks.lua). Each registered condition
-- takes every look, unless it is clauseOnly. Fits keeps the ones its piece or its
-- client part can't draw.
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
-- 3: the pop and shake looks are gone. 4: the "cooldownReset" moment is gone.
-- 5: glow lines in Comet or Shine move to Circling or Ring (Bridge.GLOW_MOVED).
-- 6: the "targetInterruptible" condition is gone.
Conditions.VERSION = 6
-- Looks a saved rule may still hold from before they went (VERSION 3).
Conditions.GONE = { pop = true, shake = true }
-- Conditions a saved rule may still name from before they went (VERSION 4 and 6), as a
-- moment or as an "and" clause.
Conditions.GONE_CONDS = { cooldownReset = true, targetInterruptible = true }
-- The shared ticker's beat, in seconds.
Conditions.TICK = 0.2
-- What the dev suite logs for a value the game keeps secret.
Conditions.SECRET = "<secret>"
-- What a line's value may hold for an effect (the effect's value field).
-- Kind -> clean(v): the value as saved, or nil when it isn't one.
Conditions.VALUES = {}
-- The most letters a text look's words may have.
Conditions.TEXT_MAX = 12

local list, byKey = {}, {}
local effects = {}
-- The looks, in order: { action, effect }.
local looks = {}

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
    if c.looks ~= nil then
        if type(c.looks) ~= "table" then return "bad looks" end
        for _, a in ipairs(c.looks) do
            if type(a) ~= "string" then return "bad looks" end
        end
    end
    if type(c.actions) ~= "table" or (next(c.actions) == nil and c.looks == nil) then return "no actions" end
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
    if c.using ~= nil and type(c.using) ~= "function" then return "bad using" end
    if badParam(c.param) then return "bad param" end
    if c.ticker and c.secrecy ~= "client" then return "bad ticker" end
    if c.armed and c.secrecy ~= "plain" then return "bad armed" end
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
-- A look on a condition's lines, unless it is clauseOnly or has that action already.
-- A client condition takes only the alpha-safe ones.
local function takesLook(c, action)
    if c.looks == nil then return true end
    for _, a in ipairs(c.looks) do
        if a == action then return true end
    end
    return false
end

local function addLook(c, look)
    if c.clauseOnly or c.actions[look.action] ~= nil or not takesLook(c, look.action) then return end
    if c.secrecy == "client" and not effects[look.effect].client then return end
    c.actions[look.action] = { effect = look.effect }
end

function Conditions.Register(c)
    local why = problem(c)
    if not why and ns.Grammar and ns.Grammar.ConditionClash(c) then why = "taken" end
    if why then return false, why end
    for _, look in ipairs(looks) do addLook(c, look) end
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
        or type(e.draw) ~= "function" or type(e.clear) ~= "function"
        or (e.value ~= nil and not Conditions.VALUES[e.value])
        or (e.watch ~= nil and type(e.watch) ~= "table") then return false end
    for _, h in ipairs(type(e.watch) == "table" and e.watch.daylight or {}) do
        if not Conditions.DAYLIGHT[h] then return false end
    end
    effects[e.key] = e
    return true
end
function Conditions.Effect(key) return effects[key] end

-- Adds a look: action on every registered condition's lines, drawn by a registered
-- effect. Returns true, or false for an unknown effect or a taken action.
function Conditions.RegisterLook(action, effect)
    if type(action) ~= "string" or not effects[effect] then return false end
    for _, look in ipairs(looks) do
        if look.action == action then return false end
    end
    local look = { action = action, effect = effect }
    looks[#looks + 1] = look
    for _, c in ipairs(list) do
        addLook(c, look)
        if ns.Grammar and ns.Grammar.InstallCondition then ns.Grammar.InstallCondition(c) end
    end
    return true
end

-- The looks in order: { { action, effect }, ... }.
function Conditions.Looks()
    local out = {}
    for i, l in ipairs(looks) do out[i] = { action = l.action, effect = l.effect } end
    return out
end

-- What a line's value holds for its action's effect: "color", "text", "icon" or nil.
function Conditions.ValueKind(key, action)
    local c = byKey[key]
    local act = c and c.actions[action]
    local e = act and effects[act.effect]
    return e and e.value or nil
end

-- A text look's words, cleaned: trimmed, no escape codes, at most TEXT_MAX letters.
-- nil for none.
local function cleanText(v)
    if type(v) ~= "string" then return nil end
    v = v:gsub("|", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if v == "" then return nil end
    local n = 0
    for _ in v:gmatch("[^\128-\191]") do n = n + 1 end
    if n > Conditions.TEXT_MAX then return nil end
    return v
end

Conditions.VALUES.color = function(v)
    if type(v) == "table" and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number" then
        return { v[1], v[2], v[3] }
    end
end
Conditions.VALUES.text = cleanText
Conditions.VALUES.icon = function(v)
    if type(v) == "number" and v > 0 and v % 1 == 0 then return v end
    if type(v) == "string" and v ~= "" and not v:find("|", 1, true) then return v end
end

-- Adds a value kind: clean(v) gives the value as saved, or nil. False for a kind
-- already taken.
function Conditions.RegisterValue(kind, clean)
    if type(kind) ~= "string" or type(clean) ~= "function" or Conditions.VALUES[kind] then return false end
    Conditions.VALUES[kind] = clean
    return true
end

-- A value as saved for a value kind, or nil when it isn't one.
function Conditions.CleanValue(kind, v)
    local clean = Conditions.VALUES[kind]
    if not clean then return nil end
    return clean(v)
end

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

-- Whether an action's effect decorates the whole piece, so its lines show on either
-- face of a piece that shows its buff and its cooldown in turn.
function Conditions.AnyFace(key, action)
    local c = byKey[key]
    local act = c and c.actions[action]
    local e = act and effects[act.effect]
    return e ~= nil and e.anyFace == true
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
local function toNotUsable(all)
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

-- Rules saved before VERSION 3 may end lines in pop or shake. Those lines go, and
-- a condition, rule or profile left with no line goes with them. They don't become
-- another look: no other look nudges the icon, and a flare or a flash is bigger
-- than what the player picked.
local function dropGone(all)
    for profile, pieces in pairs(all) do
        if type(pieces) == "table" then
            for key, rule in pairs(pieces) do
                if type(rule) == "table" then
                    for ck, acts in pairs(rule) do
                        if type(acts) == "table" then
                            for a in pairs(Conditions.GONE) do acts[a] = nil end
                            if next(acts) == nil then rule[ck] = nil end
                        end
                    end
                    if next(rule) == nil then pieces[key] = nil end
                end
            end
            if next(pieces) == nil then all[profile] = nil end
        end
    end
end

-- Rules saved before VERSION 6 may use a condition that went, as its moment or in a
-- line's clauses. That moment, and any line with such a clause, goes; a condition,
-- rule or profile left with no line goes with it.
local function dropGoneConds(all)
    local gone = Conditions.GONE_CONDS
    for profile, pieces in pairs(all) do
        if type(pieces) == "table" then
            for key, rule in pairs(pieces) do
                if type(rule) == "table" then
                    for ck, acts in pairs(rule) do
                        if gone[ck] then
                            rule[ck] = nil
                        elseif type(acts) == "table" then
                            for a, spec in pairs(acts) do
                                for _, cl in ipairs(type(spec) == "table" and type(spec.clauses) == "table" and spec.clauses or {}) do
                                    if type(cl) == "table" and gone[cl.cond] then acts[a] = nil break end
                                end
                            end
                            if next(acts) == nil then rule[ck] = nil end
                        end
                    end
                    if next(rule) == nil then pieces[key] = nil end
                end
            end
            if next(pieces) == nil then all[profile] = nil end
        end
    end
end

-- Rules saved before VERSION 5 may hold a glow style EZ-CDM no longer offers. It
-- moves to the style Bridge.GLOW_MOVED names.
local function moveStyles(all)
    local moved = Bridge.GLOW_MOVED
    for _, pieces in pairs(all) do
        for _, rule in pairs(type(pieces) == "table" and pieces or {}) do
            for _, acts in pairs(type(rule) == "table" and rule or {}) do
                for _, spec in pairs(type(acts) == "table" and acts or {}) do
                    if type(spec) == "table" and moved[spec.style] then spec.style = moved[spec.style] end
                end
            end
        end
    end
end

local function store()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.conditions) ~= "table" then EZCDMDB.conditions = {} end
    local was = EZCDMDB.conditionsVersion
    if was ~= Conditions.VERSION then
        local v = type(was) == "number" and was or 1
        if v < 2 then toNotUsable(EZCDMDB.conditions) end
        if v < 3 then dropGone(EZCDMDB.conditions) end
        if v < 6 then dropGoneConds(EZCDMDB.conditions) end
        if v < 5 then moveStyles(EZCDMDB.conditions) end
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
    else
        local e = effects[act.effect]
        if e and e.value then out.value = Conditions.CleanValue(e.value, spec.value) end
    end
    local clauses = {}
    for _, cl in ipairs(not c.alone and type(spec.clauses) == "table" and spec.clauses or {}) do
        if type(cl) == "table" and byKey[cl.cond] and not byKey[cl.cond].alone then
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
-- Key as a string -> armed part ("condition:n") -> its last plain read.
local armedWas = {}
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
-- buff and its cooldown shows the buff while it is up, else the cooldown. An
-- anyFace effect shows on either.
local function layerShows(k, layer, e)
    if layer == "any" or not both[k] or (e and e.anyFace) then return true end
    local up = Bridge.BuffState(k)
    if layer == "cooldown" then return up ~= true end
    return up == true
end
local function effectOf(slot) return slot:match("^[^|]+") end

-- Key as a string -> the piece's own glow style (Daylight UI's glowStyle).
local styleOf = {}

-- What an effect draws for a line: the action's opts with the piece's key, the
-- line's sound or color, number and glow style (the piece's own when it has none).
local function optsFor(act, spec, k, id)
    local out = { key = k, line = id }
    for f, v in pairs(act.opts or {}) do out[f] = v end
    if type(spec) == "table" then
        out.value, out.n, out.style = spec.value, spec.n, spec.style
        -- An owned ready line (Ready.Drawn): drawn as Daylight UI's own; daylight is
        -- the player's own Daylight UI line.
        out.ready, out.daylight = spec.ready, spec.daylight
    end
    if act.effect == "glow" and out.style == nil and k then out.style = styleOf[k] end
    -- The icon the line is about, for an effect whose look depends on it (the fill).
    out.layer = Conditions.LineLayer(idParts(id), spec)
    return out
end

-- wasOn: the line was lit until now.
local function off(holder, r, wasOn)
    local e = effects[r.ek]
    if r.client then
        local f = layers[holder] and layers[holder][r.id]
        if f then
            e.draw(f, false, r.opts)
            f:Hide()
        end
    elseif not e.edge or (e.hides and wasOn) then
        e.draw(holder, false, r.opts)
    end
end

-- A lit line's time from its first part that tells one: left, dur, or nil.
local function timeOf(k, parts)
    for _, p in ipairs(parts or {}) do
        if p.c.time then
            local left, dur = p.c.time(k, numberOf(p))
            if not issecretvalue(left) and not issecretvalue(dur) and type(left) == "number"
                and type(dur) == "number" and dur > 0 then
                return math.max(0, math.min(left, dur)), dur
            end
            return nil
        end
    end
end

-- Reads a piece's lines and draws each slot's winner; the rest are put out.
local function refresh(k)
    local rule = rules[k]
    local frame = frameOf[k]
    local holder = frame and API.Attach(frame) or nil
    local want = {}   -- slot -> line record
    local asked = {}  -- slot -> { line record, ... }
    -- Each armed part's read now, and whether it turned true since the last refresh.
    local prev, armedNow, fresh = armedWas[k] or {}, {}, {}
    local function armedOf(parts)
        local any, turned = false, false
        for _, p in ipairs(parts or {}) do
            if p.c.armed then
                local id = p.c.key .. ":" .. tostring(numberOf(p))
                if armedNow[id] == nil then
                    local v = readOf(p.c, k, numberOf(p))
                    armedNow[id] = v == nil and "unknown" or v
                    fresh[id] = prev[id] == false and v == true
                end
                any, turned = true, turned or fresh[id]
            end
        end
        return any, turned
    end
    for ck, acts in pairs(rule or {}) do
        local c = byKey[ck]
        for a, spec in pairs(acts) do
            local act = c.actions[a]
            local e = effects[act.effect]
            local parts, plain, client = partsOf(ck, spec)
            local lit = holder ~= nil and plain ~= nil and layerShows(k, Conditions.LineLayer(ck, spec), e)
            for _, p in ipairs(lit and plain or {}) do
                if readOf(p.c, k, numberOf(p)) ~= true then
                    lit = false
                    break
                end
            end
            local id = ck .. ":" .. a
            local own = client ~= nil or (e ~= nil and (e.stack or e.edge))
            local slot = own and (act.effect .. "|" .. id) or act.effect
            local rec = { c = c, action = a, id = id, ek = act.effect, client = client, parts = parts,
                          opts = optsFor(act, spec, k, id) }
            rec.armed, rec.fresh = armedOf(parts)
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
                if r ~= w then off(holder, r, was[slot] == r.id) end
            end
            if w and w.client then
                local f = layerFor(holder, w.id)
                f:Show()
                e.draw(f, true, w.opts)
                local n = numberOf(w.client)
                w.client.c.drive(holder, f, { key = k, n = n })
                if w.client.c.ticker then ticks[w.id] = { c = w.client.c, holder = holder, layer = f, n = n } end
                drawn[holder] = true
            elseif w and (not e.edge or was[slot] ~= w.id) and not (e.edge and w.armed and not w.fresh) then
                if e.hides then w.opts.left, w.opts.dur = timeOf(k, w.parts) end
                e.draw(holder, true, w.opts)
                drawn[holder] = true
            end
        end
        now[slot] = w and w.id or nil
    end
    ticking[k] = next(ticks) and ticks or nil
    local keep = {}
    for id, v in pairs(armedNow) do
        if v ~= "unknown" then keep[id] = v end
    end
    armedWas[k] = next(keep) and keep or nil
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
            elseif effects[ek].hides then
                effects[ek].clear(holder, id)
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

-- Every effect with a watch a rule's lines draw: key -> its watch.
local function watchedBy(rule)
    local out = {}
    for ck, acts in pairs(rule) do
        local c = byKey[ck]
        for a in pairs(acts) do
            local act = c and c.actions[a]
            local e = act and effects[act.effect]
            if e and e.watch then out[e.key] = e.watch end
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
    for _, w in pairs(watchedBy(rule)) do
        for _, h in ipairs(w.daylight or {}) do names[h] = true end
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

-- Whether a rule uses a late condition (Conditions' late field).
local function usesLate(rule)
    for _, c in pairs(usedBy(rule)) do
        if c.late then return true end
    end
    for _, w in pairs(watchedBy(rule)) do
        if w.late then return true end
    end
    return false
end

local function sync()
    if ns.Gray then ns.Gray.Reconcile() end
    if ns.Ready then ns.Ready.Reconcile() end
    local profile = Bridge.ProfileOf()
    local saved = profile ~= nil and store()[profile]
    both, styleOf = readPieces()
    local now, want = {}, {}
    local ticks = false
    for key, v in pairs(type(saved) == "table" and saved or {}) do
        local r = clean(v)
        if r and ns.Gray and ns.Gray.Cooling(key) then r[Conditions.COOLING] = { gray = true } end
        if r and ns.Ready then r = ns.Ready.Drawn(key, r) end
        if r then
            local k = tostring(key)
            now[k] = r
            for _, c in pairs(usedBy(r)) do
                for _, e in ipairs(c.events.game or {}) do want[(eventName(e))] = e end
                ticks = ticks or c.ticker == true
            end
            for _, w in pairs(watchedBy(r)) do
                for _, e in ipairs(w.game or {}) do want[(eventName(e))] = e end
            end
        end
    end
    rules = now
    local users = {}
    for k, r in pairs(now) do
        for ck, c in pairs(usedBy(r)) do
            if c.using then
                users[ck] = users[ck] or {}
                users[ck][k] = true
            end
        end
    end
    for _, c in ipairs(list) do
        if c.using then c.using(users[c.key] or {}) end
    end
    local function watchName(r, k)
        return table.concat(handlersFor(r, k), " ") .. (usesLate(r) and " +late" or "")
    end
    for k, h in pairs(watches) do
        local names = now[k] and watchName(now[k], k)
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
            local late = usesLate(r)
            for _, h in ipairs(names) do
                handlers[h] = function()
                    refresh(k)
                    if late then C_Timer.After(0, function() refresh(k) end) end
                end
            end
            watches[k] = me.WatchCooldown(k, handlers) or false
            watchedWith[k] = watchName(r, k)
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
-- (Conditions.LineLayer), and its look shows on that icon only (not anyFace). gray:
-- what a gray line's copy shows, out of a fight (Overlay's check: copy, same, game).
-- layered: a client line's effect hangs under the layer its condition drives.
function Conditions.Visible(key, id)
    local k = tostring(key)
    local out = { lit = false, shown = false, alpha = 0, covered = false }
    local ck = idParts(id)
    local rule = rules[k]
    local a = select(2, idParts(id))
    local spec = rule and rule[ck] and rule[ck][a]
    local c = byKey[ck]
    local act = c and c.actions[a]
    local e = act and effects[act.effect]
    if spec ~= nil then out.covered = not layerShows(k, Conditions.LineLayer(ck, spec), e) end
    for slot, v in pairs(litNow[k] or {}) do
        if v == id then out.lit = true; out.slot = slot end
    end
    local frame = frameOf[k]
    local holder = frame and API.Attach(frame)
    local target = holder and layers[holder] and layers[holder][id]
    if holder and e and e.check and not InCombatLockdown() then
        out.gray = e.check(target or holder, optsFor(act, spec, k, id))
    end
    if not (out.lit and frame and frame:IsVisible() and e) then return out end
    local drawn = target or holder
    if e.shown then
        local obj = e.shown(drawn, optsFor(act, spec, k, id))
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
    -- next frame (CdmEffects.lua:1567-1570); its watch moments never fire on them.
    game = { "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN" },
    daylight = { "changed" },
}

local function usableDetail(k)
    local usable, noPower, onCooldown = Bridge.UsableState(k)
    return { usable = usable, noPower = noPower, onCooldown = onCooldown }
end

-- A piece the castable words read: a cooldown, or a spell button (Grammar.Kind).
local function castable(kind) return kind.cooldown == true or kind.button == true end

-- Whether a piece's "cooling down" is only its totem standing: a totem showing its own
-- time (Daylight UI's Fx.OnCooldown), whose spell the client's tables give no real
-- cooldown (Searing Totem).
local function standsForCooldown(k)
    local key = tonumber(k) or k
    if not Bridge.IsTotem(key) or Bridge.Shows(key) ~= "totem" then return false end
    local spells = type(ns.AuraLinks) == "table" and ns.AuraLinks.spells or {}
    local v = spells[Bridge.SpellOf(key)]
    return type(v) == "string" and not v:find("c", 1, true)
end

local WASH_GRAY = { effect = "wash", opts = { id = "gray", look = "desat" } }
local GLOW = { effect = "glow" }

-- Can't be cast now, for any reason: on cooldown, short of power, or not usable.
Conditions.Register({
    key = "cantCast", moment = "blocked",
    actions = { gray = WASH_GRAY, glow = GLOW },
    fits = castable,
    read = function(k)
        local usable, _, onCooldown = Bridge.UsableState(k)
        -- A totem showing its time reads as cooling down while it stands, but one with
        -- no real cooldown drops again at once.
        if onCooldown == true and standsForCooldown(k) then onCooldown = false end
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
    -- A spell that costs nothing (kind.cost, SpellPower) is never short.
    fits = function(kind) return castable(kind) and kind.cost ~= false end,
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

-- ---------------------------------------------------------------------
-- Wave 1, batch A: the game's plain answers (docs/specs/conditions-waves.md)
-- ---------------------------------------------------------------------

local function secret(v) return type(issecretvalue) == "function" and issecretvalue(v) == true end
local function secretTable(t) return type(issecrettable) == "function" and issecrettable(t) == true end

-- A game answer for the dev log: Conditions.SECRET while the game keeps it.
local function logged(v)
    if secret(v) then return Conditions.SECRET end
    return v
end

-- A piece's key as Daylight UI's calls take it: a game cooldown's id is a number.
local function pieceKey(k) return tonumber(k) or k end
local function spellOf(k) return Bridge.SpellOf(pieceKey(k)) end

-- A fresh actions table each, since Register adds a sound to a plain one's. Gray
-- stays with the cooldown icon's words, as Daylight UI's card keeps it.
local function grayOrGlow() return { gray = WASH_GRAY, glow = GLOW } end
local function glowOnly() return { glow = GLOW } end
local function anyPiece() return true end
-- A spell cast at a unit you pick (the client's letter "t"): the target words fit it.
local function atTarget(kind) return kind.targeted == true end

-- Whether you have a target: true or false, nil when the game won't say.
local function targetNow()
    local v = UnitExists("target")
    if secret(v) then return nil end
    return v and true or false
end

-- A question about the target: false with no target, else ask's answer, nil when
-- the game keeps it secret.
local function ofTarget(ask)
    local t = targetNow()
    if t ~= true then return t end
    local v = ask()
    if secret(v) then return nil end
    return v
end

Conditions.Register({
    key = "hasTarget", moment = "hasTarget", actions = glowOnly(), fits = atTarget,
    read = targetNow,
    detail = function() return { target = logged(UnitExists("target")) } end,
    events = { game = { "PLAYER_TARGET_CHANGED" } }, secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When I have a target", clause = "I have a target" },
})

Conditions.Register({
    key = "targetEnemy", moment = "targetEnemy", actions = glowOnly(), fits = atTarget,
    read = function()
        return ofTarget(function()
            local v = UnitCanAttack("player", "target")
            if secret(v) then return v end
            return v and true or false
        end)
    end,
    detail = function()
        return { target = logged(UnitExists("target")), canAttack = logged(UnitCanAttack("player", "target")) }
    end,
    events = { game = { "PLAYER_TARGET_CHANGED", { "UNIT_FLAGS", "target" }, { "UNIT_FACTION", "target" } } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When my target is an enemy", clause = "my target is an enemy" },
})

-- A boss as Daylight UI's nameplates tell one: a world boss, or the game's boss mob.
Conditions.Register({
    key = "targetBoss", moment = "targetBoss", actions = glowOnly(), fits = atTarget,
    read = function()
        return ofTarget(function()
            local class = UnitClassification("target")
            if secret(class) then return class end
            if class == "worldboss" then return true end
            local boss = UnitIsBossMob("target")
            if secret(boss) then return boss end
            return boss == true
        end)
    end,
    detail = function()
        return { target = logged(UnitExists("target")), classification = logged(UnitClassification("target")),
                 bossMob = logged(UnitIsBossMob("target")) }
    end,
    events = { game = { "PLAYER_TARGET_CHANGED", { "UNIT_CLASSIFICATION_CHANGED", "target" } } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When my target is a boss", clause = "my target is a boss" },
})

-- The target is out of this spell's range. The game sends SPELL_RANGE_CHECK_UPDATE
-- only for a spell whose check is on, so each ruled piece's spell has its check on
-- while a rule uses it.
local rangeChecked = {}
Conditions.Register({
    key = "outOfRange", moment = "outOfRange", actions = grayOrGlow(),
    fits = function(kind) return kind.ranged == true and castable(kind) end,
    read = function(k)
        local sid = spellOf(k)
        if type(sid) ~= "number" then return nil end
        -- No target is no range to be out of.
        local t = targetNow()
        if t ~= true then return t end
        local v = C_Spell.IsSpellInRange(sid, "target")
        if v == nil or secret(v) then return nil end
        return v == false
    end,
    detail = function(k)
        local sid = spellOf(k)
        return { spell = sid, target = logged(UnitExists("target")),
                 inRange = type(sid) == "number" and logged(C_Spell.IsSpellInRange(sid, "target")) or nil }
    end,
    using = function(keys)
        local want = {}
        for k in pairs(keys) do
            local sid = spellOf(k)
            if type(sid) == "number" then want[sid] = true end
        end
        for sid in pairs(rangeChecked) do
            if not want[sid] then
                C_Spell.EnableSpellRangeCheck(sid, false)
                rangeChecked[sid] = nil
            end
        end
        for sid in pairs(want) do
            if not rangeChecked[sid] then
                C_Spell.EnableSpellRangeCheck(sid, true)
                rangeChecked[sid] = true
            end
        end
    end,
    events = { game = { "PLAYER_TARGET_CHANGED", "SPELL_RANGE_CHECK_UPDATE" } },
    secrecy = "plain", layer = "cooldown", excludes = {},
    words = { moment = "When my target is out of range", clause = "my target is out of range" },
})

-- The target casts or channels. A cast's fields go secret in restricted fights, but
-- whether the call returned one is a plain type, as Daylight UI's cast bars read it
-- (CastBar.lua). Offered on interrupts.
local function castingNow()
    local cast = UnitCastingInfo("target")
    if type(cast) ~= "nil" then return true end
    local channel = UnitChannelInfo("target")
    return type(channel) ~= "nil"
end
Conditions.Register({
    key = "targetCasting", moment = "targetCasting", actions = grayOrGlow(),
    fits = function(kind) return kind.interrupt == true and castable(kind) end,
    read = function() return ofTarget(castingNow) end,
    detail = function()
        local cast, channel = UnitCastingInfo("target"), UnitChannelInfo("target")
        return { target = logged(UnitExists("target")), casting = type(cast) ~= "nil", channel = type(channel) ~= "nil" }
    end,
    events = { game = { "PLAYER_TARGET_CHANGED", { "UNIT_SPELLCAST_START", "target" },
                        { "UNIT_SPELLCAST_STOP", "target" }, { "UNIT_SPELLCAST_FAILED", "target" },
                        { "UNIT_SPELLCAST_INTERRUPTED", "target" }, { "UNIT_SPELLCAST_CHANNEL_START", "target" },
                        { "UNIT_SPELLCAST_CHANNEL_STOP", "target" } } },
    secrecy = "plain", layer = "cooldown", excludes = {},
    words = { moment = "When my target is casting", clause = "my target is casting" },
})

-- Only the global cooldown holds it. isOnGCD never goes secret
-- (SpellSharedDocumentation, NeverSecret) and is current on SPELL_UPDATE_COOLDOWN.
local function cooldownOf(k)
    local sid = spellOf(k)
    local info = type(sid) == "number" and C_Spell.GetSpellCooldown(sid) or nil
    return sid, type(info) == "table" and info or nil
end
Conditions.Register({
    key = "onlyGcd", moment = "onlyGcd", actions = grayOrGlow(),
    -- With no real cooldown the global one is all it ever has: "cooling down" says it.
    fits = function(kind) return kind.gcd == true and kind.realCooldown == true and castable(kind) end,
    read = function(k)
        local _, info = cooldownOf(k)
        if not info or secret(info.isOnGCD) then return nil end
        return info.isOnGCD == true
    end,
    detail = function(k)
        local sid, info = cooldownOf(k)
        return { spell = sid, isActive = info and logged(info.isActive), isOnGCD = info and logged(info.isOnGCD) }
    end,
    events = { game = { "SPELL_UPDATE_COOLDOWN" }, daylight = { "ready", "started" } },
    secrecy = "plain", layer = "cooldown", excludes = {},
    words = { moment = "When it's only on the global cooldown", clause = "it's only on the global cooldown" },
})

-- Its real cooldown is over: no cooldown, or only the global one, as Daylight UI's
-- ready reads it (CdmEffects Fx.OnCooldown). isActive and isOnGCD never go secret.
-- Where Daylight UI's "When it's ready" means the same, its looks show there
-- (Grammar.MERGED). Armed: a one-shot look fires as the cooldown ends.
local function offCooldownNow(k)
    local _, info = cooldownOf(k)
    if not info or secret(info.isActive) or secret(info.isOnGCD) then return nil end
    if type(info.isActive) ~= "boolean" then return nil end
    return info.isActive == false or info.isOnGCD == true
end
Conditions.Register({
    key = "offCooldown", moment = "offCooldown", actions = glowOnly(), armed = true,
    fits = function(kind) return kind.cooldown == true and kind.realCooldown == true end,
    read = offCooldownNow,
    detail = function(k)
        local sid, info = cooldownOf(k)
        return { spell = sid, isActive = info and logged(info.isActive), isOnGCD = info and logged(info.isOnGCD) }
    end,
    events = { game = { "SPELL_UPDATE_COOLDOWN" }, daylight = { "ready", "started" } },
    secrecy = "plain", layer = "cooldown", excludes = {},
    words = { moment = "When it's off cooldown", clause = "it's off cooldown" },
})

-- Your class's forms, stances and stealth, from Daylight UI's own list
-- (CdmEffects.FORMS), or nil for a class with none.
local function myForms()
    local all, class = Bridge.Forms(), Bridge.MyClass()
    return type(all) == "table" and class and all[class] or nil
end

-- The form you're in by its key, "" for none, nil when the game won't say.
local function formNow()
    local forms = myForms()
    if not forms then return nil end
    local bySpell = {}
    for _, f in ipairs(forms) do
        for _, sid in ipairs(f.spells or {}) do bySpell[sid] = f.key end
    end
    local n = GetNumShapeshiftForms()
    if secret(n) then return nil end
    for i = 1, n or 0 do
        local _, active, _, sid = GetShapeshiftFormInfo(i)
        if secret(active) or secret(sid) then return nil end
        if active and bySpell[sid] then return bySpell[sid] end
    end
    for _, f in ipairs(forms) do
        if f.stealth then
            local v = IsStealthed()
            if secret(v) then return nil end
            if v then return f.key end
        end
    end
    return ""
end

local FORM_EVENTS = { "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_FORMS", "UPDATE_STEALTH" }

-- One condition per form a class can be in, its "no form" left out, offered to that
-- class only. You're in one at a time.
local formClasses = {}
for class in pairs(Bridge.Forms() or {}) do formClasses[#formClasses + 1] = class end
table.sort(formClasses)
for _, class in ipairs(formClasses) do
    local forms = Bridge.Forms()[class]
    local mine = {}
    for _, f in ipairs(forms) do
        if not f.none then mine[#mine + 1] = f end
    end
    for _, f in ipairs(mine) do
        local fkey = f.key
        local others, never = {}, {}
        for _, o in ipairs(mine) do
            if o ~= f then
                others[#others + 1] = "form" .. o.key
                never["form" .. o.key] = "I'm in one at a time"
            end
        end
        Conditions.Register({
            key = "form" .. fkey, moment = "form" .. fkey, actions = glowOnly(),
            fits = function()
                for _, o in ipairs(myForms() or {}) do
                    if o.key == fkey then return true end
                end
                return false
            end,
            read = function()
                local now = formNow()
                if now == nil then return nil end
                return now == fkey
            end,
            detail = function()
                local now = formNow()
                return { form = now == "" and "none" or now, stealthed = logged(IsStealthed()) }
            end,
            events = { game = FORM_EVENTS }, secrecy = "plain", layer = "any", excludes = others,
            words = { moment = "When I'm in " .. f.name, clause = "I'm in " .. f.name, never = never },
        })
    end
end

-- This spell's totem stands (Bridge.TotemUp). On a totem showing its own time its
-- lines read under Daylight UI's "While my totem is up" (Grammar.MERGED).
Conditions.Register({
    key = "totemUp", moment = "totemUp", actions = glowOnly(),
    fits = function(kind) return kind.totem == true end,
    read = function(k) return Bridge.TotemUp(spellOf(k)) end,
    time = function(k) return Bridge.TotemTime(spellOf(k)) end,
    detail = function(k) return { spell = spellOf(k), up = Bridge.TotemUp(spellOf(k)) } end,
    events = { game = { "PLAYER_TOTEM_UPDATE", { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
               daylight = { "changed", "ready", "started" } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "While my totem is up", clause = "my totem is up" },
})

-- This spell's totem is gone, totemUp's opposite. On a totem showing its own time its
-- lines read under Daylight UI's "When my totem is down" (Grammar.MERGED).
Conditions.Register({
    key = "totemDown", moment = "totemDown", actions = glowOnly(),
    fits = function(kind) return kind.totem == true end,
    read = function(k)
        local up = Bridge.TotemUp(spellOf(k))
        if up == nil then return nil end
        return not up
    end,
    detail = function(k) return { spell = spellOf(k), up = Bridge.TotemUp(spellOf(k)) } end,
    events = { game = { "PLAYER_TOTEM_UPDATE", { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
               daylight = { "changed", "ready", "started" } },
    secrecy = "plain", layer = "any", excludes = { "totemUp" },
    words = { moment = "When my totem is down", clause = "my totem is down",
              never = { totemUp = "my totem is up or down" } },
})

-- Each weapon slot's enchant list, or nil when the client refuses the read. The
-- client answers weapon enchants plainly in a fight (Daylight UI's Weapons.lua).
local function weaponEnchants()
    local lists = {}
    local ok = Bridge.SafeCall(function()
        for _, slot in pairs(Enum.WeaponSlot) do lists[#lists + 1] = C_Item.GetWeaponEnchantInfo(slot) end
    end)
    if not ok then return nil end
    return lists
end

-- Whether a weapon holds one of the enchant ids in want: true or false, nil when the
-- game won't say.
local function enchanted(want)
    local lists = weaponEnchants()
    if not lists then return nil end
    local found = false
    for _, list in ipairs(lists) do
        if secretTable(list) then return nil end
        for _, e in ipairs(list) do
            if secretTable(e) or secret(e.hasEnchant) or secret(e.enchantID) then return nil end
            if e.hasEnchant and want[e.enchantID] then found = true end
        end
    end
    return found
end

-- No weapon holds this spell's weapon buff, any rank's (Grammar.Imbues).
Conditions.Register({
    key = "weaponBuffMissing", moment = "weaponBuffMissing", actions = glowOnly(),
    fits = function(kind) return kind.imbue == true end,
    read = function(k)
        local want = ns.Grammar and ns.Grammar.Imbues(pieceKey(k))
        if not want then return nil end
        local on = enchanted(want)
        if on == nil then return nil end
        return not on
    end,
    detail = function()
        local lists = weaponEnchants()
        if not lists then return { enchants = "refused" } end
        local ids = {}
        for _, list in ipairs(lists) do
            for _, e in ipairs(secretTable(list) and {} or list) do ids[#ids + 1] = tostring(logged(e.enchantID)) end
        end
        return { enchants = #ids > 0 and table.concat(ids, ",") or "none" }
    end,
    events = { game = { "WEAPON_ENCHANT_CHANGED", "PLAYER_EQUIPMENT_CHANGED", { "UNIT_INVENTORY_CHANGED", "player" } } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When my weapon buff is missing", clause = "my weapon buff is missing" },
})

-- The charges left on a piece's aura, which the client counts as its applications:
-- the first of its charged auras on you (Grammar.ChargedAuras), its count, or nil
-- when the game won't say.
local function chargesNow(k)
    local G = ns.Grammar
    for _, id in ipairs(G and G.ChargedAuras(pieceKey(k)) or {}) do
        local a = C_UnitAuras.GetUnitAuraBySpellID("player", id)
        if secretTable(a) then return nil, id end
        if type(a) == "table" then
            if secret(a.applications) then return nil, id end
            return a.applications, id, a
        end
    end
    return 0
end

-- The charged aura's seconds left and whole length, or nil for one with no timer.
local function chargesTime(k)
    local left, _, a = chargesNow(k)
    if not (left and a) or secret(a.expirationTime) or secret(a.duration) then return nil end
    if type(a.duration) ~= "number" or a.duration <= 0 or type(a.expirationTime) ~= "number" then return nil end
    return a.expirationTime - GetTime(), a.duration
end

-- Its aura is up with n charges or fewer left (Lightning Shield's 3, used up by hits).
-- Offered only where the game never keeps the aura secret (kind.chargesSeen), so the
-- count reads in a fight: for any other aura the count is out of reach there.
Conditions.Register({
    key = "chargesLeft", moment = "chargesLeft", actions = glowOnly(),
    param = { min = 1, max = 30, default = 1 },
    fits = function(kind) return kind.charges ~= nil and kind.chargesSeen == true and kind.buff == true end,
    read = function(k, n)
        local left = chargesNow(k)
        if left == nil then return nil end
        return left > 0 and left <= (n or 1)
    end,
    time = chargesTime,
    detail = function(k)
        local left, id = chargesNow(k)
        local secrecy = id and C_Secrets.GetSpellAuraSecrecy(id)
        return { aura = id, charges = left == nil and Conditions.SECRET or left, secrecy = logged(secrecy) }
    end,
    events = { game = { { "UNIT_AURA", "player" } }, daylight = { "buffUp", "buffDown", "changed" } },
    -- It reads the aura up itself, so it is true only while the buff shows. Layer "buff"
    -- would also ask Daylight UI's buff state, which can't tell on an aura-and-cooldown
    -- holder (Lightning Shield).
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When its charges are down to #", clause = "its charges are down to #" },
})

-- ---------------------------------------------------------------------
-- Wave 1, batch B: the client tier (docs/specs/conditions-waves.md)
-- ---------------------------------------------------------------------

-- Each drive hands the game's answer to the layer's alpha and never reads it. A
-- percent goes through a curve the game evaluates (UnitHealthPercent,
-- UnitPowerPercent: SecretWhenCurveSecret), as Daylight UI's low-health warning and
-- nameplate execute lights do (CombatText/Feed.lua, Plate.lua).

-- "health": zero is dead, not low (Daylight UI's Feed curve). "power": an empty bar
-- is low.
local curves = { health = {}, power = {} }

-- A curve that gives 1 below n% and 0 from n% up, linear with near-upright edges as
-- Daylight UI builds them; nil when the game has no curves.
local function belowCurve(what, n)
    local made = curves[what][n]
    if made ~= nil then return made or nil end
    made = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local c = C_CurveUtil.CreateCurve()
        if c then
            if Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Linear) end
            local at = n / 100
            if what == "health" then
                c:AddPoint(0, 0)
                c:AddPoint(0.001, 1)
            else
                c:AddPoint(0, 1)
            end
            c:AddPoint(at - 0.001, 1)
            c:AddPoint(at, 0)
            c:AddPoint(1, 0)
            made = c
        end
    end
    curves[what][n] = made
    return made or nil
end

-- Sets layer's alpha to the game's answer: a number or a secret goes in whole; no
-- answer leaves the layer dark.
local function alphaFrom(layer, v)
    if secret(v) or type(v) == "number" then
        layer:SetAlpha(v)
    else
        layer:SetAlpha(0)
    end
end

-- A game answer for the dev log: plain, Conditions.SECRET, or "nil" for none.
local function answer(v)
    if secret(v) then return Conditions.SECRET end
    if v == nil then return "nil" end
    return v
end

-- unit's health under n%, into layer. No target is no health to be low.
local function driveHealth(unit, layer, n)
    if unit == "target" and targetNow() ~= true then return layer:SetAlpha(0) end
    local curve = belowCurve("health", n)
    if not curve then return layer:SetAlpha(0) end
    alphaFrom(layer, UnitHealthPercent(unit, true, curve))
end

local function healthDetail(unit)
    local out = {}
    if unit == "target" then
        out.target = answer(UnitExists("target"))
        if targetNow() ~= true then return out end
    end
    out.pct = answer(UnitHealthPercent(unit, true))
    return out
end

-- The target's health is under n% (an execute window). Offered on a spell cast at a
-- unit you pick.
Conditions.Register({
    key = "targetLow", moment = "targetLow", actions = glowOnly(), fits = atTarget,
    param = { min = 1, max = 99, default = 20, unit = "%" },
    drive = function(_, layer, opts) driveHealth("target", layer, opts.n or 20) end,
    detail = function() return healthDetail("target") end,
    events = { game = { "PLAYER_TARGET_CHANGED", { "UNIT_HEALTH", "target" }, { "UNIT_MAXHEALTH", "target" } } },
    secrecy = "client", layer = "any", excludes = {},
    words = { moment = "When my target is below #% health", clause = "my target is below #% health" },
})

-- Your health is under n%: a reason to press a piece you can cast.
Conditions.Register({
    key = "playerLow", moment = "playerLow", actions = glowOnly(), fits = castable,
    param = { min = 1, max = 99, default = 30, unit = "%" },
    drive = function(_, layer, opts) driveHealth("player", layer, opts.n or 30) end,
    detail = function() return healthDetail("player") end,
    events = { game = { { "UNIT_HEALTH", "player" }, { "UNIT_MAXHEALTH", "player" } } },
    secrecy = "client", layer = "any", excludes = {},
    words = { moment = "When I'm below #% health", clause = "I'm below #% health" },
})

-- A power word's PowerType (PowerTypeConstants: Mana 0, Rage 1, Focus 2, Energy 3).
local POWER_TYPES = { mana = "Mana", rage = "Rage", focus = "Focus", energy = "Energy" }
local function powerType(word)
    local name = POWER_TYPES[word]
    return name and Enum.PowerType and Enum.PowerType[name] or nil
end

-- The power a piece's "below #%" reads: the one it costs, or of two (Skull Bash:
-- energy in Cat Form, rage in Bear Form) the one your bar shows now. nil for none.
local function lowPowerOf(k)
    local words = ns.Grammar and ns.Grammar.LowPowers(pieceKey(k))
    if not words then return nil end
    if #words == 1 then return powerType(words[1]) end
    local now = UnitPowerType("player")
    if secret(now) then return nil end
    for _, w in ipairs(words) do
        if powerType(w) == now then return now end
    end
    return nil
end
Conditions.PowerOf = lowPowerOf

-- Your power, the one the piece's cast costs, is under n%. Offered on a piece you can
-- cast whose cost is a bar your class's player has (Grammar.LowPowers).
Conditions.Register({
    key = "powerLow", moment = "powerLow", actions = glowOnly(),
    fits = function(kind) return kind.lowPower == true and castable(kind) end,
    param = { min = 1, max = 99, default = 30, unit = "%" },
    drive = function(_, layer, opts)
        local t = lowPowerOf(opts.key)
        local curve = belowCurve("power", opts.n or 30)
        if t == nil or not curve then return layer:SetAlpha(0) end
        alphaFrom(layer, UnitPowerPercent("player", t, false, curve))
    end,
    detail = function(k)
        local t = lowPowerOf(k)
        if t == nil then return { power = "none" } end
        local s = C_Secrets and C_Secrets.GetPowerTypeSecrecy and C_Secrets.GetPowerTypeSecrecy(t)
        return { power = t, pct = answer(UnitPowerPercent("player", t, false)), secrecy = answer(s) }
    end,
    events = { game = { { "UNIT_POWER_UPDATE", "player" }, { "UNIT_MAXPOWER", "player" },
                        { "UNIT_DISPLAYPOWER", "player" } } },
    secrecy = "client", layer = "any", excludes = {},
    words = { moment = "When my %s is below #%", clause = "my %s is below #%" },
})

-- What you're doing and where, per spell, as Daylight UI's group rules read them
-- (CdmRows.Now). Advanced, since they mostly follow "and".
local COMBAT_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }

Conditions.Register({
    key = "inCombat", moment = "inCombat", actions = glowOnly(), fits = anyPiece, advanced = true,
    read = function() return InCombatLockdown() == true end,
    detail = function() return { inCombat = InCombatLockdown() == true } end,
    events = { game = COMBAT_EVENTS }, secrecy = "plain", layer = "any", excludes = { "noCombat" },
    words = { moment = "When I'm in combat", clause = "I'm in combat",
              never = { noCombat = "I'm in combat or out of it" } },
})

Conditions.Register({
    key = "noCombat", moment = "noCombat", actions = glowOnly(), fits = anyPiece, advanced = true,
    read = function() return InCombatLockdown() ~= true end,
    detail = function() return { inCombat = InCombatLockdown() == true } end,
    events = { game = COMBAT_EVENTS }, secrecy = "plain", layer = "any", excludes = { "inCombat" },
    words = { moment = "When I'm out of combat", clause = "I'm out of combat" },
})

Conditions.Register({
    key = "inGroup", moment = "inGroup", actions = glowOnly(), fits = anyPiece, advanced = true,
    read = function()
        local v = IsInGroup()
        if secret(v) then return nil end
        return v == true
    end,
    detail = function() return { group = logged(IsInGroup()) } end,
    events = { game = { "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When I'm in a group", clause = "I'm in a group" },
})

-- Dungeons, raids, battlegrounds and arenas, as Daylight UI's Show in: Instances.
local INSTANCES = { party = true, raid = true, pvp = true, arena = true }
Conditions.Register({
    key = "inInstance", moment = "inInstance", actions = glowOnly(), fits = anyPiece, advanced = true,
    read = function()
        local _, kind = IsInInstance()
        if secret(kind) then return nil end
        return INSTANCES[kind] == true
    end,
    detail = function() return { instance = logged((select(2, IsInInstance()))) } end,
    events = { game = { "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA" } },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When I'm in an instance", clause = "I'm in an instance" },
})

-- ---------------------------------------------------------------------
-- Wave 2: the moments the progress fill takes (docs/specs/progress-fill.md)
-- ---------------------------------------------------------------------

-- Each takes the fill only (Looks.lua), never a sound, and is never an "and" part.
-- Always is Daylight UI's own "Always" moment, under every other line. Cooling and
-- active show under Daylight UI's "While it's cooling down" and "While it's active"
-- (Grammar.MERGED), so they fit only where those moments mean the same.
local FILL_ONLY = { "fill" }

Conditions.Register({
    key = "always", moment = "always", actions = {}, looks = FILL_ONLY, alone = true, noSound = true,
    priority = -1, fits = anyPiece,
    read = function() return true end,
    events = { game = {} },
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "Always", clause = "always" },
})

-- Its real cooldown runs: offCooldown's opposite. The global cooldown alone is no
-- cooldown here, as Daylight UI's own cooling down reads it.
Conditions.Register({
    key = "cooling", moment = "cooling", actions = {}, looks = FILL_ONLY, alone = true, noSound = true,
    fits = function(kind) return kind.cooldownReady == true end,
    read = function(k)
        local off = offCooldownNow(k)
        if off == nil then return nil end
        return not off
    end,
    detail = function(k)
        local sid, info = cooldownOf(k)
        return { spell = sid, isActive = info and logged(info.isActive), isOnGCD = info and logged(info.isOnGCD) }
    end,
    events = { game = { "SPELL_UPDATE_COOLDOWN" }, daylight = { "ready", "started" } },
    secrecy = "plain", layer = "cooldown", excludes = { "offCooldown" },
    words = { moment = "While it's on cooldown", clause = "it's on cooldown",
              never = { offCooldown = "it's on cooldown or off it" } },
})

-- Its own buff is up, on a piece whose buff Daylight UI clocks (Grammar.Kind clocked).
Conditions.Register({
    key = "active", moment = "active", actions = {}, looks = FILL_ONLY, alone = true, noSound = true,
    fits = function(kind) return kind.clocked == true end,
    read = function(k) return (Bridge.BuffState(k)) end,
    detail = function(k) return { up = (Bridge.BuffState(k)) } end,
    events = { daylight = { "buffUp", "buffDown", "changed" } },
    secrecy = "plain", layer = "buff", excludes = { "noBuff" },
    words = { moment = "While its buff is up", clause = "its buff is up",
              never = { noBuff = "its buff is active or not" } },
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

-- Daylight UI's own ready line ("When it's ready, glow", "play a sound"), drawn by
-- EZ-CDM while an EZ-CDM ready line owns that part of the piece (Ready.lua): a copy of
-- the ready condition under another key, below every other line. Never registered,
-- so never offered or saved; the driver adds its line (Ready.Drawn).
Conditions.KEPT_READY = { offCooldown = "daylightReady", totemDown = "daylightTotemDown" }
for from, key in pairs(Conditions.KEPT_READY) do
    local c = {}
    for f, v in pairs(byKey[from]) do c[f] = v end
    c.key, c.order, c.priority = key, 0, -1
    c.actions = { glow = GLOW, sound = { effect = "sound" } }
    byKey[key] = c
end

-- Daylight UI lights no glow of its own on the piece now. An owned ready glow takes
-- it first (Ready.Drawn), so it gives way to Daylight UI's proc, buff and castable
-- glows as Daylight UI's own ready glow does (CdmEffects wantsGlow). Never registered.
Conditions.QUIET = "daylightGlowQuiet"
byKey[Conditions.QUIET] = {
    key = Conditions.QUIET, moment = Conditions.QUIET, order = 0, priority = 0, late = true,
    actions = {},
    fits = anyPiece,
    read = function(k)
        local frame = frameOf[k]
        if not frame then return true end
        return not Bridge.DaylightGlowLit(frame)
    end,
    detail = function(k)
        local frame = frameOf[k]
        return { daylightGlow = frame and Bridge.DaylightGlowLit(frame) or false }
    end,
    events = { game = { "SPELL_UPDATE_USABLE", "SPELL_UPDATE_COOLDOWN" },
               daylight = { "ready", "started", "usable", "proc", "buffUp", "buffDown", "changed" } },
    secrecy = "plain", layer = "any", excludes = {},
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
