local _, ns = ...

-- A board of spells and their sentences. Nothing touches Daylight UI's layout until
-- Save, and Save writes only through ns.Bridge: placing, group words, track and the
-- spell fields the grammar owns (Grammar.FIELDS and hideIn<Key>).
--
-- A place is { next = key }, { own = true } or nil. nil keeps a placed spell where it
-- is and puts a new one at the end of the main group. "On its own" is met by a spell
-- that starts its group; "next to X" by one in X's group.

local Bridge, Grammar = ns.Bridge, ns.Grammar

local Draft = {}
ns.Draft = Draft

-- Debug handle for an in-game check.
EZCDM_Draft = Draft

-- { g, profile, spells = { [key] = entry }, order = { key, ... } }
local board
local place   -- Save's placing write, below

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

-- Daylight UI sorts piece keys numbers first, each kind on its own (CdmData.ByKey).
local function byKey(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta == "number" end
    return a < b
end

-- Each color field and the glow it colors, from the grammar's map.
local GLOW_OF = {}
for _, row in pairs(Grammar.MAP) do
    for _, e in pairs(row) do
        if e.color then GLOW_OF[e.color] = e.field end
    end
end

local SHOW_RULES = { onReady = true, onCd = true, onUnusable = true, onShort = true }

-- ---------------------------------------------------------------------
-- The live layout
-- ---------------------------------------------------------------------

local function layout()
    local set = Bridge.Layout(board.g)
    local pieces = type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}
    local chains = type(set) == "table" and type(set.chains) == "table" and set.chains or {}
    return pieces, chains
end

local function rootOf(key) return Bridge.Root(key, board.g) end

local function groupSize(key)
    local list = Bridge.Subtree(rootOf(key), board.g)
    return type(list) == "table" and #list or 0
end

-- The pieces hanging off key, in Daylight UI's side order.
local function kidsOf(key)
    local out = {}
    for _, side in ipairs(Bridge.Sides() or {}) do
        local c = Bridge.Child(key, side, board.g)
        if c ~= nil then out[#out + 1] = c end
    end
    return out
end

-- The main group's first piece: the group with the most pieces, ties going to the
-- first in Daylight UI's order. nil when nothing is placed.
local function mainRoot()
    local pieces = layout()
    local count, roots = {}, {}
    for key in pairs(pieces) do
        local r = rootOf(key)
        if r ~= nil then
            if not count[r] then roots[#roots + 1] = r end
            count[r] = (count[r] or 0) + 1
        end
    end
    table.sort(roots, byKey)
    local best
    for _, r in ipairs(roots) do
        if best == nil or count[r] > count[best] then best = r end
    end
    return best
end

-- The side a group runs on from x: the side x hangs by, else the side of its first
-- child, else right for an icon and down for a bar (CdmData.AddChain).
local function runSide(x)
    local pieces = layout()
    local p = pieces[x]
    if p.parent ~= nil and pieces[p.parent] and p.side then return p.side end
    for _, side in ipairs(Bridge.Sides() or {}) do
        if Bridge.Child(x, side, board.g) ~= nil then return side end
    end
    return p.shape == "bar" and "down" or "right"
end

-- How a piece of shape aligns on side of a host (CdmEditor.lua:366-370).
local function alignOn(hostShape, shape, side)
    if hostShape == shape then return "center" end
    return (side == "up" or side == "down") and "start" or "center"
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

-- A color's everyday name, or "the accent color" for none.
local function colorName(c)
    if not isRGB(c) then return "the accent color" end
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

local function soundName(key)
    local values = Bridge.SoundChoices()
    local name = type(values) == "table" and values[key]
    return type(name) == "string" and name or tostring(key)
end

local function formName(key)
    for _, list in pairs(Bridge.Forms() or {}) do
        for _, f in ipairs(list) do
            if f.key == key then return f.name or key end
        end
    end
    return key
end

-- The line that sets field to value, or nil.
local function lineFor(field, value)
    for _, m in ipairs(Grammar.MOMENTS) do
        for _, a in ipairs(Grammar.ACTIONS) do
            local e = Grammar.MAP[m][a]
            if e and not e.all and e.field == field and (e.sound or e.value == value) then
                return { moment = m, action = a, value = e.sound and value or nil }
            end
        end
    end
end

-- A line as a clause: "when it's ready, glow".
local function said(line)
    local s = Grammar.Describe(line):gsub("%.$", "")
    return s:sub(1, 1):lower() .. s:sub(2)
end

local ACTION_WORDS = { show = "show it", fade = "fade it", hide = "hide it" }

local function percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

-- One spell field's change in plain words, after "<name>: ".
local function fieldWords(field, old, new)
    local form = field:match("^hideIn(%u%w*)$")
    if form then
        if new then return "hide it in " .. formName(form) end
        return "show it in " .. formName(form) .. " again"
    end
    if GLOW_OF[field] then
        return string.format("%s in %s (was %s)", said(lineFor(GLOW_OF[field], true)), colorName(new), colorName(old))
    end
    if field == "cdAlpha" then
        return string.format("fade to %s (was %s)", percent(new or default(field)), percent(old or default(field)))
    end
    local value = new
    if value == nil then value = default(field) end
    local line = lineFor(field, value)
    local sound = line ~= nil and line.action == "sound"
    if sound and value == "none" then line = nil end
    if line then
        local s = said(line)
        if SHOW_RULES[field] then
            s = s .. " (was " .. ACTION_WORDS[old or default(field)] .. ")"
        elseif sound and old ~= nil then
            s = s .. string.format(" (was \"%s\")", soundName(old))
        end
        return s
    end
    local was = lineFor(field, old)
    return was and string.format("drop \"%s\"", said(was)) or field
end

local GROUP_ON = { combat = "only in combat", target = "only with a target", group = "only in a group",
    mounted = "not when mounted" }
local GROUP_OFF = { combat = "in or out of combat", target = "with or without a target",
    group = "in a group or not", mounted = "mounted or not" }
local WHERE_WORDS = { any = "anywhere", instance = "only in instances", world = "only in the open world" }

local function groupWord(word, v)
    if word == "where" then return WHERE_WORDS[v or "any"] or tostring(v) end
    return v and GROUP_ON[word] or GROUP_OFF[word]
end

local PROBLEM_WORDS = {
    pair = "isn't a sentence EZ-CDM knows",
    kind = "doesn't fit this spell",
    value = "has a color, sound or amount Daylight UI doesn't take",
    twice = "sets the same thing as another line, and the later line wins",
    hidden = "never shows, because a hide line hides the spell then",
}
-- Problems Save can't write past: the line would be dropped.
local BLOCKING = { pair = true, kind = true, value = true }

local function problemWords(name, rules, p)
    local what
    if p.line then
        local line = rules.lines and rules.lines[p.line]
        what = type(line) == "table" and string.format("\"%s\"", Grammar.Describe(line)) or ("line " .. p.line)
    elseif p.group then
        what = string.format("the group word \"%s\"", tostring(p.group))
    else
        what = string.format("\"hide in %s\"", formName(tostring(p.form)))
    end
    return string.format("%s: %s %s.", name, what, PROBLEM_WORDS[p.code] or p.code)
end

-- ---------------------------------------------------------------------
-- The plan: changes, notes and the writes behind them
-- ---------------------------------------------------------------------

-- Where a spell ends up: { stay = true }, { next = key } or { own = true }.
-- ctx.fresh plans an empty layout, where the default starts the main group with
-- ctx.main, the first spell on the board with no place.
local function target(entry, live, pieces, ctx)
    local key, place = entry.key, entry.place
    if place and place.next ~= nil then
        if live and pieces[place.next] and rootOf(key) == rootOf(place.next) then return { stay = true } end
        return { next = place.next }
    elseif place and place.own then
        -- A spell that starts its group already sits on its own.
        if live and rootOf(key) == key then return { stay = true } end
        return { own = true }
    elseif live then
        return { stay = true }
    end
    if ctx.fresh then
        if ctx.main == key then return { own = true, default = true } end
        return { next = ctx.main, default = true }
    end
    local m = mainRoot()
    if m ~= nil then return { next = m, default = true } end
    return { own = true, default = true }
end

-- The piece's kind where it ends up, with the group options it lands in as
-- kind.chain (a copy of its old group's when it leaves one, Data.Unhook).
local function kindFor(entry, live, tgt, chains)
    local key = entry.key
    local piece = copy(live) or { shape = entry.shape }
    piece.parent, piece.side, piece.x, piece.y = nil, nil, nil, nil
    if tgt.stay then return Grammar.Kind(key) end
    if tgt.next ~= nil then
        piece.parent = tgt.next
        local kind = Grammar.Kind(key, piece)
        kind.alone = false
        local host = board.spells[tgt.next]
        if host then kind.chain = Grammar.Compile(host.rules).chain end
        return kind
    end
    local kind = Grammar.Kind(key, piece)
    kind.alone = true
    kind.chain = live and chains[rootOf(key)] or chains[key] or {}
    return kind
end

-- The spell fields to compare: the grammar's, plus every form the piece could hide in.
local function fieldList(kind, live, fields)
    local out, forms, seen = {}, {}, {}
    for _, f in ipairs(Grammar.FIELDS) do out[#out + 1] = f end
    local function form(f)
        if not seen[f] then seen[f] = true; forms[#forms + 1] = f end
    end
    for _, k in ipairs(kind.forms or {}) do form("hideIn" .. k) end
    for f in pairs(live or {}) do
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

-- One spell's plan: { changes, notes, ops }. Each op is { stage, change, run }.
-- Stages: 1 place, 2 group, 3 track, 4 spell fields.
local function planFor(entry, pieces, chains, ctx)
    local key, name = entry.key, nameOf(entry.key)
    local live = pieces[key]
    local shape = live and (live.shape == "bar" and "bar" or "icon") or entry.shape
    local plan = { key = key, changes = {}, notes = {}, ops = {} }
    local function note(code, words, blocking)
        plan.notes[#plan.notes + 1] = { key = key, code = code, words = words, blocking = blocking or false }
    end
    local function change(kind, field, old, new, words)
        local c = { key = key, kind = kind, field = field, old = copy(old), new = copy(new), words = words }
        plan.changes[#plan.changes + 1] = c
        return c
    end
    local function op(stage, c, run)
        plan.ops[#plan.ops + 1] = { stage = stage, change = c, run = run, key = key }
    end

    local tgt = target(entry, live, pieces, ctx)
    local kind = kindFor(entry, live, tgt, chains)
    local fields, problems, flags = Grammar.Compile(entry.rules, kind)
    plan.fields = fields
    if flags.needsOwnGroup and live and groupSize(key) == 1 then
        -- Already in a group of its own.
        tgt = { stay = true }
        kind.alone = true
        kind.chain = chains[key] or {}
    elseif flags.needsOwnGroup and not tgt.own then
        tgt = { own = true, forced = true }
        kind.alone = true
        kind.chain = live and chains[rootOf(key)] or chains[key] or {}
        note("ownGroup", string.format("%s: its group words differ from the group it would share, so it gets its own group.", name))
    end
    plan.target, plan.shape = tgt, shape

    for _, p in ipairs(problems) do
        note(p.code, problemWords(name, entry.rules, p), BLOCKING[p.code])
    end
    for _, n in ipairs(Grammar.Notes(entry.rules)) do note("glow", name .. ": " .. n.text) end

    -- Placing.
    if not tgt.stay then
        local words
        local why = tgt.forced and " (its group words differ from the group's)" or ""
        if tgt.next ~= nil then
            words = string.format("%s %s next to %s", live and "Move" or "Add", name, nameOf(tgt.next))
        elseif live then
            words = string.format("Move %s to its own group%s", name, why)
        else
            words = string.format("Add %s on its own%s", name, why)
        end
        local c = change(live and "place" or "add", "place", live and { root = rootOf(key) } or nil, tgt, words)
        plan.placing = c
        op(1, c, function() return place(key, tgt, shape) end)
    end

    -- Group words, on the group the spell lands in.
    local chain = fields.chain or {}
    for _, word in ipairs(Grammar.GROUP) do
        local old = kind.chain[word]
        if old == Bridge.ChainDefault(word) then old = nil end
        local new = chain[word]
        if old ~= new then
            local c = change("group", word, old, new, string.format("%s's group: %s (was %s)", name,
                groupWord(word, new), groupWord(word, old)))
            local value = new
            if value == nil then value = Bridge.ChainDefault(word) end
            op(2, c, function() return Bridge.SetChainValue(board.g, key, word, value) end)
        end
    end

    -- Track: "missing show" keeps the piece on Buff only, as the card writes it
    -- (CdmCard.lua:326-329).
    local p = live or {}
    if flags.keepBuffOnly then
        local words = string.format("%s: show only its buff, so it can show while the buff is missing", name)
        if Bridge.CanTrack(key) then
            if p.track ~= "aura" then
                local c = change("track", "track", p.track, "aura", words)
                op(3, c, function() return Bridge.SetTrack(board.g, key, "aura") end)
            end
        elseif Bridge.Shows(key, live or { shape = shape }) ~= nil and p.track ~= "buff" then
            local c = change("track", "track", p.track, "buff", words)
            op(3, c, function() return Bridge.SetSpellValue(board.g, key, "track", "buff") end)
        end
    end

    -- Spell fields. A value back at its default is written as the default, which
    -- Daylight UI's setter drops.
    local fading = fades(fields)
    for _, f in ipairs(fieldList(kind, live, fields)) do
        local old, new = norm(f, p[f]), fields[f]
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
                local c = change("set", f, old, new, name .. ": " .. fieldWords(f, old, new))
                op(4, c, function() return Bridge.SetSpellValue(board.g, key, f, new) end)
            end
        elseif f == "cdAlpha" and not fading then
            -- The fade amount does nothing without a fade line.
        elseif not same(old, new) then
            local c = change(new == nil and "clear" or "set", f, old, new, name .. ": " .. fieldWords(f, old, new))
            local value = new
            if value == nil then value = default(f) end
            op(4, c, function() return Bridge.SetSpellValue(board.g, key, f, value) end)
        end
    end
    return plan
end

-- Every spell's plan, in board order, and the notes for places that can't be met.
-- fresh plans against an empty layout: every board spell is new there.
local function build(fresh)
    local pieces, chains = layout()
    local ctx = {}
    if fresh then
        pieces, chains = {}, {}
        ctx.fresh = true
        for _, key in ipairs(board.order) do
            if board.spells[key].place == nil then ctx.main = key; break end
        end
    end
    local plans, changes, notes, ops = {}, {}, {}, {}
    for _, key in ipairs(board.order) do
        plans[#plans + 1] = planFor(board.spells[key], pieces, chains, ctx)
    end
    -- A "next to" spell must be placed, or on the board and placed first.
    local pending = {}
    for _, plan in ipairs(plans) do
        if not pieces[plan.key] and not plan.target.stay then pending[plan.key] = plan.target end
    end
    for _, plan in ipairs(plans) do
        local x = plan.target.next
        if x ~= nil and not pieces[x] then
            local seen, cur, bad = {}, x, nil
            while cur ~= nil and not pieces[cur] do
                if not pending[cur] then bad = "missing"; break end
                if seen[cur] or cur == plan.key then bad = "loop"; break end
                seen[cur] = true
                cur = pending[cur].next
            end
            if bad then
                local words = bad == "loop"
                    and string.format("%s: \"next to %s\" goes round in a circle.", nameOf(plan.key), nameOf(x))
                    or string.format("%s: \"next to %s\" names a spell that isn't %s.", nameOf(plan.key), nameOf(x),
                        fresh and "on the board" or "placed or on the board")
                plan.notes[#plan.notes + 1] = { key = plan.key, code = "next", words = words, blocking = true }
            end
        end
    end
    for _, plan in ipairs(plans) do
        for _, c in ipairs(plan.changes) do changes[#changes + 1] = c end
        for _, n in ipairs(plan.notes) do notes[#notes + 1] = n end
        for _, o in ipairs(plan.ops) do ops[#ops + 1] = o end
    end
    return changes, notes, ops, plans
end

-- A fresh layout's change list: "New layout <name> with N spells", then one entry
-- per spell, its placing followed by what it gets there. Each spell's entry keeps
-- its own changes as parts.
local function freshList(plans, name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    local n = #plans
    local out = { { kind = "layout", field = "profile", old = board.profile, new = name ~= "" and name or nil,
        words = string.format("New layout%s with %d spell%s", name ~= "" and string.format(" \"%s\"", name) or "",
            n, n == 1 and "" or "s") } }
    for _, plan in ipairs(plans) do
        local entry, fields = board.spells[plan.key], plan.fields
        local parts = {}
        for _, line in ipairs(entry.rules.lines or {}) do
            local e = type(line) == "table" and Grammar.MAP[line.moment] and Grammar.MAP[line.moment][line.action]
            if e and e.color and isRGB(line.value) then
                parts[#parts + 1] = said({ moment = line.moment, action = line.action }) .. " in " .. colorName(line.value)
            elseif e then
                parts[#parts + 1] = said(line)
            end
        end
        local chain = fields.chain or {}
        for _, word in ipairs(Grammar.GROUP) do
            if chain[word] ~= nil then parts[#parts + 1] = "its group " .. groupWord(word, chain[word]) end
        end
        for _, f in ipairs(fieldList({}, nil, fields)) do
            if f:match("^hideIn") and fields[f] then parts[#parts + 1] = fieldWords(f, nil, true) end
        end
        for _, c in ipairs(plan.changes) do
            if c.kind == "track" then parts[#parts + 1] = c.words:sub(#nameOf(plan.key) + 3) end
        end
        local c = plan.placing
        out[#out + 1] = { key = plan.key, kind = "add", field = "place", new = copy(c.new),
            words = c.words .. (#parts > 0 and ": " .. table.concat(parts, "; ") or ""), parts = plan.changes }
    end
    return out
end

-- ---------------------------------------------------------------------
-- Placing (Save's stage 1)
-- ---------------------------------------------------------------------

-- Puts key where tgt says. A placed spell leaving its spot first frees what hangs
-- off it, where it is now, as Data.RemovePiece does (CdmData.lua:1137-1158): the
-- rest of the group stays on screen as it was.
function place(key, tgt, shape)
    local g = board.g
    local pieces = layout()
    local live = pieces[key]
    if live then
        local kids = kidsOf(key)
        local boxes = #kids > 0 and Bridge.Boxes(g) or {}
        for _, kid in ipairs(kids) do
            local b = boxes[kid]
            local ok, why = Bridge.Unhook(g, kid, b and b.x, b and b.y)
            if not ok then return false, why end
        end
    end
    if tgt.own then
        local x, y = Bridge.FreeSpot(shape)
        return Bridge.AddPiece(g, key, shape, x, y)
    end
    if not live then
        local ok, why = Bridge.AddPiece(g, key, shape)
        if not ok then return false, why end
    end
    local side = runSide(tgt.next)
    local host = layout()[tgt.next]
    return Bridge.Hook(g, key, tgt.next, side, alignOn(host.shape == "bar" and "bar" or "icon", shape, side))
end

-- Stage 1 order: placed spells leaving their group, placed spells moving next to
-- another, then new spells. A spell going next to one not placed yet waits for it.
local function placeOrder(ops, pieces)
    local rank = {}
    for i, o in ipairs(ops) do
        local live = pieces[o.key] ~= nil
        rank[o] = (live and o.change.new.own and 0 or live and 1 or 2) * 10000 + i
    end
    table.sort(ops, function(a, b) return rank[a] < rank[b] end)
end

-- ---------------------------------------------------------------------
-- The board
-- ---------------------------------------------------------------------

-- Starts an empty board on the current talent set. false and a reason ("combat",
-- "off") when it can't.
function Draft.Open()
    if InCombatLockdown() then return false, "combat" end
    if not Bridge.Ready() then return false, "off" end
    local g = Bridge.CurrentIndex()
    board = { g = g, profile = Bridge.ProfileOf(g), spells = {}, order = {} }
    return true
end

function Draft.IsOpen() return board ~= nil end

-- The talent set and profile id the board opened on.
function Draft.Target()
    if board then return board.g, board.profile end
end

local function view(entry)
    local pieces = layout()
    return { key = entry.key, name = nameOf(entry.key), rules = copy(entry.rules), place = copy(entry.place),
        shape = entry.shape, placed = pieces[entry.key] ~= nil }
end

-- Puts a spell on the board. A placed one comes in with its current settings as
-- rules; a new one with none, as shape ("icon" or "bar"). Returns the spell as
-- Draft.Spells lists it, or nil and a reason ("closed", "unknown").
function Draft.Add(key, shape)
    if not board then return nil, "closed" end
    if key == nil then return nil, "unknown" end
    local entry = board.spells[key]
    if entry then return view(entry) end
    local pieces, chains = layout()
    local live = pieces[key]
    local rules
    if live then
        local fields = copy(live)
        fields.chain = copy(chains[rootOf(key)] or {})
        rules = Grammar.Decompile(fields, Grammar.Kind(key))
        shape = live.shape
    else
        if Bridge.Entry(key) == nil and not Bridge.IsCustom(key) then return nil, "unknown" end
        rules = { lines = {}, group = {}, forms = {} }
    end
    entry = { key = key, rules = rules, shape = shape == "bar" and "bar" or "icon" }
    board.spells[key] = entry
    board.order[#board.order + 1] = key
    return view(entry)
end

-- Takes a spell off the board. Save leaves it alone.
function Draft.Drop(key)
    if not (board and board.spells[key]) then return false end
    board.spells[key] = nil
    for i, k in ipairs(board.order) do
        if k == key then table.remove(board.order, i); break end
    end
    return true
end

-- Replaces a spell's rules ({ lines, group, forms }).
function Draft.SetRules(key, rules)
    local entry = board and board.spells[key]
    if not entry or type(rules) ~= "table" then return false end
    entry.rules = copy(rules)
    if type(entry.rules.lines) ~= "table" then entry.rules.lines = {} end
    if type(entry.rules.group) ~= "table" then entry.rules.group = {} end
    if type(entry.rules.forms) ~= "table" then entry.rules.forms = {} end
    return true
end

-- Sets where a spell goes: { next = key }, { own = true } or nil.
function Draft.SetPlace(key, place)
    local entry = board and board.spells[key]
    if not entry then return false end
    if place ~= nil then
        local ok = type(place) == "table" and (place.own == true and place.next == nil
            or place.own == nil and place.next ~= nil and place.next ~= key)
        if not ok then return false end
        place = place.own and { own = true } or { next = place.next }
    end
    entry.place = place
    return true
end

-- The board's spells in the order they were added.
function Draft.Spells()
    local out = {}
    if not board then return out end
    for i, key in ipairs(board.order) do out[i] = view(board.spells[key]) end
    return out
end

-- ---------------------------------------------------------------------
-- Changes and Save
-- ---------------------------------------------------------------------

-- What Save(mode, name) would write, as ordered entries { key, kind, field, old, new,
-- words } (kinds: add, set, clear, place, group, track), spell by spell in board
-- order. "update" and "new" (or nil) give the same list. "fresh" gives a "layout"
-- entry, then one "add" entry per spell with its changes as parts.
-- Second value: notes { key, code, words, blocking }. A blocking note stops Save.
function Draft.Changes(mode, name)
    if not board then return {}, {} end
    local changes, notes, _, plans = build(mode == "fresh")
    if mode == "fresh" then changes = freshList(plans, name) end
    return changes, notes
end

local function canSave()
    if not board then return false, "closed" end
    if InCombatLockdown() then return false, "combat" end
    if not Bridge.Ready() then return false, "off" end
    if Bridge.CurrentIndex() ~= board.g or Bridge.ProfileOf(board.g) ~= board.profile then
        return false, "talents"
    end
    return true
end

-- Writes the board. mode "update" writes the layout in use; "new" copies it into a
-- new profile (named name), switches the talent set to the copy and writes that;
-- "fresh" makes a new empty profile (named name), switches the talent set to it and
-- writes only the board's spells there. The old layout is left as it was.
-- Everything is checked before the first write. Returns true and a report
-- { changes, wrote, profile }, or false, a reason and the report:
--   "closed" "combat" "off"   no board, in combat, EZ-CDM is off
--   "talents"                 the talent set or its profile changed since Open
--   "problems"                a blocking note (Draft.Changes)
--   "mode"                    not "update", "new" or "fresh"
--   a Bridge reason           a write was refused part way; wrote lists what landed
-- Writes go place, group, track, spell fields. Each stage leaves a working layout,
-- and the next Save picks up what's left, since changes come from the live layout.
function Draft.Save(mode, name)
    local report = { changes = 0, wrote = {} }
    if mode ~= "update" and mode ~= "new" and mode ~= "fresh" then return false, "mode", report end
    local ok, why = canSave()
    if not ok then return false, why, report end
    local changes, notes, ops, plans = build(mode == "fresh")
    if mode == "fresh" then changes = freshList(plans, name) end
    for _, n in ipairs(notes) do
        if n.blocking then return false, "problems", report end
    end
    report.changes = #changes
    if mode == "new" then
        local id, err = Bridge.CopyAndAssign(board.g, name)
        if not id then return false, err, report end
        board.profile = id
    elseif mode == "fresh" then
        local id, err = Bridge.NewAndAssign(board.g, name)
        if not id then return false, err, report end
        board.profile = id
    end
    local stages = { {}, {}, {}, {} }
    for _, o in ipairs(ops) do table.insert(stages[o.stage], o) end
    placeOrder(stages[1], layout())
    local failed
    local function landed(c) report.wrote[#report.wrote + 1] = c.words end
    -- A place waits while the spell it goes next to isn't placed yet.
    local waiting = stages[1]
    while #waiting > 0 and not failed do
        local later = {}
        for _, o in ipairs(waiting) do
            local x = o.change.new.next
            if x ~= nil and not layout()[x] then
                later[#later + 1] = o
            else
                local done, err = o.run()
                if not done then failed = err or "rejected"; break end
                landed(o.change)
            end
        end
        if not failed and #later == #waiting then failed = "rejected" end
        waiting = later
    end
    for s = 2, 4 do
        if failed then break end
        for _, o in ipairs(stages[s]) do
            local done, err = o.run()
            if not done then failed = err or "rejected"; break end
            landed(o.change)
        end
    end
    board.profile = Bridge.ProfileOf(board.g)
    report.profile = board.profile
    if #report.wrote > 0 or mode ~= "update" then Bridge.Apply() end
    if failed then return false, failed, report end
    return true, report
end
