local _, ns = ...

-- One placed spell's sentences, read from and written live to the layout Daylight
-- UI's editor shows. A write goes only through ns.Bridge, in stages: group words
-- on the spell's group, what it shows (track), the spell fields the grammar owns
-- (Grammar.FIELDS and hideIn<Key>), its look keys (Grammar.LOOK_FIELDS), then
-- EZ-CDM's own rules (Effects): the up glow, the fall-off lead and sound, and the
-- glow lines' own styles.
-- Only fields that change are written, and no piece ever moves.

local Bridge, Grammar, Effects = ns.Bridge, ns.Grammar, ns.Effects

local Draft = {}
ns.Draft = Draft

-- Debug handle for an in-game check.
EZCDM_Draft = Draft

-- ---------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

local function isRGB(c)
    return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number"
end

-- Daylight UI's default for a spell field.
local function default(field) return Bridge.Option({}, field) end

-- A saved value, nil when it equals the default.
local function norm(field, v)
    if v == default(field) then return nil end
    return v
end

-- Each color field and the glow it colors, from the grammar's map, and the color
-- fields a line sets whole (the sweep's).
local GLOW_OF, PAINT = {}, {}
for _, row in pairs(Grammar.MAP) do
    for _, e in pairs(row) do
        if e.color then GLOW_OF[e.color] = e.field end
        if e.paint then PAINT[e.paint] = true end
    end
end

local SHOW_RULES = { onReady = true, onCd = true, onUnusable = true, onShort = true }

local function tidy(rules)
    rules = copy(type(rules) == "table" and rules or {})
    if type(rules.lines) ~= "table" then rules.lines = {} end
    if type(rules.group) ~= "table" then rules.group = {} end
    if type(rules.forms) ~= "table" then rules.forms = {} end
    return rules
end

-- ---------------------------------------------------------------------
-- The live layout: talent set g's (the one the editor shows)
-- ---------------------------------------------------------------------

local function layout(g)
    local set = Bridge.Layout(g)
    local pieces = type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}
    local chains = type(set) == "table" and type(set.chains) == "table" and set.chains or {}
    return pieces, chains
end

-- The other pieces in key's group, in Daylight UI's order.
local function matesOf(key, g)
    local out = {}
    local list = Bridge.Subtree(Bridge.Root(key, g), g)
    for _, k in ipairs(type(list) == "table" and list or {}) do
        if k ~= key then out[#out + 1] = k end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Plain words
-- ---------------------------------------------------------------------

local function nameOf(key)
    local n = Bridge.SpellName(key)
    if type(n) == "string" and n ~= "" then return n end
    return tostring(key)
end

-- Hue bands in degrees, each with the name it ends.
local HUES = { { 15, "red" }, { 40, "orange" }, { 55, "gold" }, { 70, "yellow" }, { 160, "green" },
    { 195, "teal" }, { 255, "blue" }, { 290, "purple" }, { 335, "pink" }, { 360, "red" } }

-- A color's everyday name, or the accent's words for none.
local function colorName(c)
    if not isRGB(c) then return Grammar.WORDING.accent end
    local r, g, b = c[1], c[2], c[3]
    local hi, lo = math.max(r, g, b), math.min(r, g, b)
    if hi - lo < 0.12 then
        local light = (hi + lo) / 2
        if light > 0.8 then return "white" end
        if light < 0.2 then return "black" end
        return "gray"
    end
    local d, h = hi - lo, 0
    if hi == r then h = 60 * (((g - b) / d) % 6)
    elseif hi == g then h = 60 * ((b - r) / d + 2)
    else h = 60 * ((r - g) / d + 4) end
    for _, band in ipairs(HUES) do
        if h < band[1] then return band[2] end
    end
    return "red"
end

-- The same names for the drawer's color word.
Draft.ColorName = colorName

local function formName(key)
    for _, list in pairs(Bridge.Forms() or {}) do
        for _, f in ipairs(list) do
            if f.key == key then return f.name or key end
        end
    end
    return key
end

-- "A", "A and B", "A, B, and C".
local function listWords(names)
    if #names <= 2 then return table.concat(names, " and ") end
    return table.concat(names, ", ", 1, #names - 1) .. ", and " .. names[#names]
end

Draft.SHARED = "Also applies to %s (same group)."

-- The note group words on key carry while others share its group, or nil.
local function sharedNote(key, g)
    local names = {}
    for _, k in ipairs(matesOf(key, g)) do names[#names + 1] = nameOf(k) end
    if #names == 0 then return nil end
    return Draft.SHARED:format(listWords(names))
end

-- The same, on the layout the editor shows.
function Draft.GroupNote(key) return sharedNote(key, Bridge.CurrentIndex()) end

-- The names of every spell in key's group on the layout the editor shows, key
-- included, in Daylight UI's order.
function Draft.GroupNames(key)
    local g = Bridge.CurrentIndex()
    local list = Bridge.Subtree(Bridge.Root(key, g), g)
    local names = {}
    for _, k in ipairs(type(list) == "table" and list or { key }) do names[#names + 1] = nameOf(k) end
    return names
end

local PROBLEM_WORDS = {
    blank = "has a blank to fill in",
    pair = "isn't a sentence EZ-CDM knows",
    kind = "doesn't fit this spell",
    value = "has a color, sound or amount Daylight UI doesn't take",
    twice = "sets the same thing as another line, and the later line wins",
    hidden = "never shows, because a hide line hides the spell then",
    needs = Grammar.WORDING.needs:format(Grammar.Describe({ moment = "missing", action = "show" })),
}
-- Problems a write can't go past: the line would be dropped.
local BLOCKING = { blank = true, pair = true, kind = true, value = true, needs = true }

local function problemWords(name, rules, p)
    local what
    if p.line then
        local line = rules.lines and rules.lines[p.line]
        what = type(line) == "table" and string.format("\"%s\"", Grammar.Describe(line)) or ("line " .. p.line)
    elseif p.group then
        what = string.format("the group word \"%s\"", tostring(p.group))
    elseif p.shows then
        what = string.format("\"%s\"", Grammar.ShowsWords(p.shows))
    elseif p.style then
        what = string.format("\"%s\"", Grammar.StyleWords(tostring(p.style)))
    else
        what = string.format("\"%s\"", Grammar.FormWords(formName(tostring(p.form))))
    end
    return string.format("%s: %s %s.", name, what, PROBLEM_WORDS[p.code] or p.code)
end

-- ---------------------------------------------------------------------
-- The plan: what a write changes, its notes and the writes behind them
-- ---------------------------------------------------------------------

-- The spell fields to compare: the grammar's, plus every form the piece could hide in.
local function fieldList(kind, live, fields)
    local out, forms, seen = {}, {}, {}
    for _, f in ipairs(Grammar.FIELDS) do out[#out + 1] = f end
    local function form(f)
        if not seen[f] then seen[f] = true; forms[#forms + 1] = f end
    end
    for _, k in ipairs(kind.forms or {}) do form("hideIn" .. k) end
    for f in pairs(live) do
        if type(f) == "string" and f:match("^hideIn%u") then form(f) end
    end
    for f in pairs(fields) do
        if type(f) == "string" and f:match("^hideIn%u") then form(f) end
    end
    table.sort(forms)
    for _, f in ipairs(forms) do out[#out + 1] = f end
    return out
end

local function fades(fields)
    for f in pairs(SHOW_RULES) do
        if fields[f] == "fade" then return true end
    end
    return false
end

-- key's plan on talent set g: { changes, notes, ops }. Each change is { key, kind,
-- field, old, new } (kinds: group, track, set, clear, ez), each op { stage, change,
-- run }. Stages: 1 group words, 2 track, 3 spell fields, 4 look keys, 5 EZ-CDM's
-- own rules.
local function planFor(key, rules, g)
    local name = nameOf(key)
    local pieces, chains = layout(g)
    local live = pieces[key]
    local plan = { changes = {}, notes = {}, ops = {} }
    local function note(code, words, blocking)
        plan.notes[#plan.notes + 1] = { key = key, code = code, words = words, blocking = blocking or false }
    end
    local function op(stage, kind, field, old, new, run)
        local c = { key = key, kind = kind, field = field, old = copy(old), new = copy(new) }
        plan.changes[#plan.changes + 1] = c
        plan.ops[#plan.ops + 1] = { stage = stage, change = c, run = run, n = #plan.ops + 1 }
    end

    -- The piece as it reads after its What it shows pick.
    local kind = Grammar.Kind(key, nil, rules.shows)
    local fields, problems, flags = Grammar.Compile(rules, kind)
    for _, p in ipairs(problems) do
        note(p.code, problemWords(name, rules, p), BLOCKING[p.code])
    end

    -- "Glow while active" on a piece an aura icon holder draws is EZ-CDM's own, and
    -- Daylight UI's upGlow goes off (Effects.Split).
    local ezOld, ezNew = Effects.Get(key, g), Effects.Split(key, fields)
    if not same(ezOld, ezNew) then
        op(5, "ez", "upGlow", ezOld, ezNew, function() return Effects.Set(g, key, ezNew) end)
    end
    -- The fall-off lead and its sound are EZ-CDM's own on every piece
    -- (Effects.SplitFallOff).
    local foOld, foNew = Effects.FallOff(key, g), Effects.SplitFallOff(fields)
    if not same(foOld, foNew) then
        op(5, "ez", "fallOff", foOld, foNew, function() return Effects.SetFallOff(g, key, foNew) end)
    end
    -- So are the glow lines' own styles.
    local stOld, stNew = Effects.Styles(key, g), Effects.SplitStyles(fields)
    if not same(stOld, stNew) then
        op(5, "ez", "glowStyles", stOld, stNew, function() return Effects.SetStyles(g, key, stNew) end)
    end

    -- Group words, on the spell's group, as Daylight UI's Group tab writes them
    -- (Data.SetChainValue from any piece in it). Everyone in the group shares them.
    local chain = chains[Bridge.Root(key, g)] or {}
    local want = fields.chain or {}
    local grouped = false
    for _, f in ipairs(Grammar.CHAIN) do
        local old = chain[f]
        if old == Bridge.ChainDefault(f) then old = nil end
        local new = want[f]
        if old ~= new then
            local value = new
            if value == nil then value = Bridge.ChainDefault(f) end
            op(1, "group", f, old, new, function() return Bridge.SetChainValue(g, key, f, value) end)
            grouped = true
        end
    end
    local shared = grouped and sharedNote(key, g)
    if shared then note("shared", shared) end

    -- Track: the What it shows pick, in the piece's own words (CdmCard.lua:341-376).
    -- Daylight UI's setters take no "unset", so a pick stays until another replaces it.
    -- Without one, "missing show" keeps the piece on Buff only, as the card writes it
    -- (CdmCard.lua:326-329).
    if fields.track ~= nil then
        local t = fields.track
        if live.track ~= t then
            if kind.trackRow == "own" then
                op(2, "track", "track", live.track, t, function() return Bridge.SetTrack(g, key, t) end)
            else
                op(2, "track", "track", live.track, t, function() return Bridge.SetSpellValue(g, key, "track", t) end)
            end
        end
    elseif flags.keepBuffOnly then
        if Bridge.CanTrack(key) then
            if live.track ~= "aura" then
                op(2, "track", "track", live.track, "aura", function() return Bridge.SetTrack(g, key, "aura") end)
            end
        elseif Bridge.Shows(key, live) ~= nil and live.track ~= "buff" then
            op(2, "track", "track", live.track, "buff",
                function() return Bridge.SetSpellValue(g, key, "track", "buff") end)
        end
    end

    -- Spell fields. A value back at its default is written as the default, which
    -- Daylight UI's setter drops.
    local fading = fades(fields)
    for _, f in ipairs(fieldList(kind, live, fields)) do
        local old, new = norm(f, live[f]), fields[f]
        local glow = GLOW_OF[f]
        if glow then
            -- Daylight UI's setter takes no "none" for a color, so an unset color
            -- can't be written back. Only a lit glow shows it.
            if new == nil then
                if old ~= nil and fields[glow] == true then
                    note("accent", string.format("%s: Daylight UI can't set a glow back to the accent color, so it stays %s.",
                        name, colorName(old)))
                end
            elseif not same(old, new) then
                op(3, "set", f, old, new, function() return Bridge.SetSpellValue(g, key, f, new) end)
            end
        elseif PAINT[f] and new == nil then
            -- The same for the sweep's color, lit whenever the buff is up.
            if old ~= nil then note("accent", Grammar.WORDING.sweepAccent:format(name, colorName(old))) end
        elseif f == "cdAlpha" and not fading then
            -- The fade amount does nothing without a fade line.
        elseif not same(old, new) then
            local value = new
            if value == nil then value = default(f) end
            op(3, new == nil and "clear" or "set", f, old, new,
                function() return Bridge.SetSpellValue(g, key, f, value) end)
        end
    end
    -- Look keys, the piece's own, as the card's Look tab writes them. Daylight UI keeps
    -- a value even at its fallback, so a dropped key is written as the fallback.
    local liveLook = type(live.look) == "table" and live.look or {}
    local wantLook = fields.look or {}
    for _, f in ipairs(Grammar.LOOK_FIELDS) do
        local d = Bridge.LookDefault(f)
        local old, new = liveLook[f], wantLook[f]
        if same(old, d) then old = nil end
        if not same(old, new) then
            local value = new
            if value == nil then value = d end
            op(4, new == nil and "clear" or "set", f, old, new, function() return Bridge.SetLook(g, key, f, value) end)
        end
    end
    return plan
end

-- Runs a plan's writes by stage, in order within each. Stops at the first refusal
-- and returns its reason; report.changed gets each change that landed.
local function runStages(ops, report)
    table.sort(ops, function(a, b)
        if a.stage ~= b.stage then return a.stage < b.stage end
        return a.n < b.n
    end)
    for _, o in ipairs(ops) do
        local done, err = o.run()
        if not done then return err or "rejected" end
        report.changed[#report.changed + 1] = o.change
    end
end

-- ---------------------------------------------------------------------
-- Lines the layout holds that don't fit the piece
-- ---------------------------------------------------------------------

-- A line as text, so two lines compare.
local function signature(line)
    if type(line) ~= "table" then return "" end
    local v = line.value
    if isRGB(v) then v = string.format("%s,%s,%s,%s", v[1], v[2], v[3], tostring(v[4])) end
    return string.format("%s|%s|%s|%s|%s", tostring(line.moment), tostring(line.action), tostring(v),
        tostring(line.at), tostring(line.style))
end

-- The spell fields a line sets.
local function fieldsOf(line)
    local e = Grammar.MAP[line.moment] and Grammar.MAP[line.moment][line.action]
    if not e then return {} end
    if e.all then return e.all end
    if e.look then return { e.look, e.lookColor, e.at } end
    local out = { e.field or e.paint }
    if e.color then out[#out + 1] = e.color end
    if e.alpha then out[#out + 1] = "cdAlpha" end
    return out
end

-- ---------------------------------------------------------------------
-- Reading and writing one spell
-- ---------------------------------------------------------------------

-- A placed spell's rules, read from the layout the editor shows, and the problems
-- Grammar.Decompile found. nil when key isn't placed there.
function Draft.Rules(key)
    local g = Bridge.CurrentIndex()
    local pieces, chains = layout(g)
    local live = pieces[key]
    if not live then return nil end
    local fields = Effects.Merge(key, copy(live), g)
    fields.chain = copy(chains[Bridge.Root(key, g)] or {})
    return Grammar.Decompile(fields, Grammar.Kind(key))
end

-- A placed spell's piece kind (Grammar.Kind) as it reads after a What it shows pick
-- (nil = as saved).
function Draft.Kind(key, shows) return Grammar.Kind(key, nil, shows) end

-- Lines and forms in the layout that don't fit the piece: an option Daylight UI
-- keeps though its card no longer shows it (Gray out on a piece made a bar, which
-- its setter won't take back). While rules still hold them, a write leaves their
-- fields as they are. Returns rules without them, and those fields.
local function keepUnfit(key, rules)
    local live, problems = Draft.Rules(key)
    local unfit, protect = {}, {}
    for _, p in ipairs(problems or {}) do
        if p.code == "kind" and p.line then unfit[signature(live.lines[p.line])] = true end
        if p.code == "kind" and p.form then unfit["form:" .. p.form] = true end
    end
    local out = { lines = {}, group = rules.group, forms = {}, shows = rules.shows, style = rules.style }
    for _, l in ipairs(rules.lines) do
        if unfit[signature(l)] then
            for _, f in ipairs(fieldsOf(l)) do protect[f] = true end
        else
            out.lines[#out.lines + 1] = l
        end
    end
    for _, k in ipairs(rules.forms) do
        if unfit["form:" .. tostring(k)] then protect["hideIn" .. k] = true else out.forms[#out.forms + 1] = k end
    end
    return out, protect
end

-- Writes one placed spell's rules ({ lines, group, forms }) into the layout the
-- editor shows, at once. Only the fields that change are written; a line the
-- layout holds that doesn't fit the piece stays as it is while rules keep it.
-- Everything is checked before the first write. Returns true and a report
-- { changes, changed, notes }, or false, a reason and the report:
--   "combat" "off"   in combat, EZ-CDM is off
--   "unplaced"       key isn't placed in that layout
--   "problems"       a blocking note (report.notes)
--   a Bridge reason  a write was refused part way; changed lists what landed
-- The caller redraws Daylight UI's editor (Bridge.EditorChanged).
function Draft.Write(key, rules)
    local report = { changes = 0, changed = {}, notes = {} }
    if InCombatLockdown() then return false, "combat", report end
    if not Bridge.Ready() then return false, "off", report end
    local g = Bridge.CurrentIndex()
    if key == nil or not layout(g)[key] then return false, "unplaced", report end
    local protect
    rules, protect = keepUnfit(key, tidy(rules))
    local plan = planFor(key, rules, g)
    report.notes = plan.notes
    for _, n in ipairs(plan.notes) do
        if n.blocking then return false, "problems", report end
    end
    local ops = {}
    for _, o in ipairs(plan.ops) do
        if not (o.stage >= 3 and protect[o.change.field]) then ops[#ops + 1] = o end
    end
    report.changes = #ops
    local failed = runStages(ops, report)
    if failed then return false, failed, report end
    return true, report
end
