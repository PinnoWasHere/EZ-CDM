local _, ns = ...

-- Sentences to Daylight UI's CDM fields and back. Pure: it reads plain tables and
-- Daylight UI's answers through ns.Bridge read calls, and never writes a layout.
--
-- A line is { moment = ..., action = ..., value = ... }. A spell's rules are
-- { lines = { ... }, group = { combat = true, where = "instance", ... },
--   forms = { "Bear", ... } }.
-- Fields are a piece's spell options, with its group's options under fields.chain.

local Bridge = ns.Bridge

local Grammar = {}
ns.Grammar = Grammar

-- Debug handle for an in-game check.
EZCDM_Grammar = Grammar

Grammar.MOMENTS = { "always", "ready", "cooldown", "unusable", "short", "usable", "up", "ends", "missing", "recast" }
Grammar.ACTIONS = { "show", "fade", "hide", "glow", "gray", "color", "sound" }
-- Group words in their canonical order: true turns one on, and where takes
-- "instance" or "world". false and "any" are Daylight UI's defaults.
Grammar.GROUP = { "combat", "target", "group", "mounted", "where" }
Grammar.WHERE = { "instance", "world" }

-- The show rules every "always show" line sets to show.
local SHOW_RULES = { "onReady", "onCd", "onUnusable", "onShort" }

local function showRule(field)
    return {
        show = { field = field, value = "show" },
        fade = { field = field, value = "fade", alpha = true },
        hide = { field = field, value = "hide" },
    }
end

-- moment -> action -> what it sets. Card rows: CdmCard.lua:628-700.
--   field, value   one spell option
--   alpha          the line's value is the fade amount (cdAlpha)
--   color          the line's value is the glow color (nil = the accent)
--   sound          the line's value is a Daylight UI sound key
--   slot           lines sharing a slot set one choice (CdmCard.lua:313-333, Buff missing)
--   all            "always show": every show rule
local MAP = {
    always = { show = { all = SHOW_RULES, value = "show" } },
    ready = showRule("onReady"),
    cooldown = showRule("onCd"),
    unusable = showRule("onUnusable"),
    short = showRule("onShort"),
    usable = {
        glow = { field = "usableGlow", value = true, color = "usableGlowColor" },
        sound = { field = "usableSound", sound = true },
    },
    up = {
        show = { field = "hideActive", value = false },
        hide = { field = "hideActive", value = true },
        glow = { field = "upGlow", value = true, color = "upGlowColor" },
        sound = { field = "buffSound", sound = true },
    },
    ends = { sound = { field = "buffEndSound", sound = true } },
    missing = {
        show = { field = "missing", value = true, slot = "buffDown" },
        hide = { field = "hideMissing", value = true, slot = "buffDown" },
        glow = { field = "missingGlow", value = true, color = "missingGlowColor" },
    },
    recast = { glow = { field = "clipGlow", value = true, color = "clipGlowColor" } },
}
MAP.ready.glow = { field = "readyGlow", value = true, color = "readyGlowColor" }
MAP.ready.sound = { field = "readySound", sound = true }
-- desat tracks cooldown state only (CdmEffects.lua:1099-1108), so gray goes with
-- cooldown alone.
MAP.cooldown.gray = { field = "desat", value = "grey" }
MAP.cooldown.color = { field = "desat", value = "color" }
Grammar.MAP = MAP

-- Every spell field the grammar writes, so a caller can clear the ones a draft drops.
Grammar.FIELDS = {
    "onReady", "onCd", "onUnusable", "onShort", "cdAlpha", "desat",
    "readyGlow", "readyGlowColor", "usableGlow", "usableGlowColor", "upGlow", "upGlowColor",
    "missingGlow", "missingGlowColor", "clipGlow", "clipGlowColor",
    "readySound", "usableSound", "buffSound", "buffEndSound",
    "hideActive", "missing", "hideMissing",
}

-- Which glow shows when several could (CdmEffects.lua:502-527): proc, then missing,
-- recast, up, usable and ready. The game's proc glow has no word here.
Grammar.GLOW_ORDER = { "missing", "recast", "up", "usable", "ready" }

-- ---------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------

local function indexOf(list, v)
    for i, x in ipairs(list) do if x == v then return i end end
end

local function isRGB(c)
    return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number"
end

local function copyRGB(c) return { c[1], c[2], c[3] } end

-- Daylight UI's default for a spell field (CdmEffects Fx.DEFAULTS).
local function spellDefault(field) return Bridge.Option({}, field) end

-- A sound key Daylight UI offers (Sound.AlertChoices), headings left out.
local function isSound(key)
    if type(key) ~= "string" or key:find("^head:") then return false end
    local values = Bridge.SoundChoices()
    return type(values) == "table" and values[key] ~= nil
end

-- Every form key Daylight UI knows, for any class.
local function isForm(key)
    for _, list in pairs(Bridge.Forms() or {}) do
        for _, f in ipairs(list) do
            if f.key == key then return true end
        end
    end
    return false
end

-- ---------------------------------------------------------------------
-- Applicability
-- ---------------------------------------------------------------------

-- The key a piece hangs from at the top of its group.
local function rootOf(pieces, key, piece)
    local seen, p = {}, piece
    while type(p) == "table" and p.parent ~= nil and not seen[key] do
        seen[key] = true
        key = p.parent
        p = pieces[key]
    end
    return key
end

-- Describes a piece through Daylight UI's own answers. piece is its saved table or a
-- draft one (the layout's own when nil). Mirrors the card's predicates:
--   isIcon / isBar   CdmCard.lua:227-228
--   isBuff           CdmCard.lua:236
--   isCooldown       CdmCard.lua:258-264
--   hasBuff          CdmCard.lua:266-269
--   buffOnly         CdmCard.lua:272
--   tellsState       CdmCard.lua:288-290
--   showsBuff        CdmCard.lua:407-410
--   cast             CdmCard.lua:413-415
-- Form rows show for cooldowns of a class with forms (CdmCard.lua:806).
-- Totems take no case of their own. Bridge.Shows (CdmOwn.Track) says "totem" for a
-- totem with no buff and "both" for a Shaman element piece (CdmOwn.lua:108-130), and
-- the card reads that same answer. test_grammar checks Words against the card's rows.
function Grammar.Kind(key, piece)
    local layout = Bridge.Layout()
    local pieces = type(layout) == "table" and type(layout.pieces) == "table" and layout.pieces or {}
    if piece == nil then piece = pieces[key] end
    local shows = Bridge.Shows(key, piece)
    local cooldown
    if shows then
        cooldown = shows ~= "buff"
    else
        local known = Bridge.Entry(key)
        cooldown = not (known and known.aura)
    end
    local hasBuff = shows ~= "totem" and (shows ~= nil or not cooldown)
    local kind = {
        key = key,
        shape = type(piece) == "table" and piece.shape == "bar" and "bar" or "icon",
        custom = Bridge.IsCustom(key),
        shows = shows,
        cooldown = cooldown,
        buff = hasBuff,
        buffOnly = hasBuff and not cooldown,
        showsBuff = hasBuff and shows ~= "cooldown",
        tracked = Bridge.Tracked(key) ~= false,
        cast = Bridge.SpellOf(key) ~= nil,
    }
    local forms = cooldown and (Bridge.Forms() or {})[Bridge.MyClass() or ""]
    if forms then
        kind.forms = {}
        for i, f in ipairs(forms) do kind.forms[i] = f.key end
    end
    -- Its group: alone, or sharing the root's options with others.
    local root = rootOf(pieces, key, piece)
    local size = 0
    for k, p in pairs(pieces) do
        if k ~= key and rootOf(pieces, k, p) == root then size = size + 1 end
    end
    kind.alone = size == 0
    local chains = type(layout) == "table" and type(layout.chains) == "table" and layout.chains or {}
    kind.chain = type(chains[root]) == "table" and chains[root] or {}
    return kind
end

-- Whether a moment and action fit a piece, as the card offers them.
function Grammar.Fits(kind, moment, action)
    local entry = MAP[moment] and MAP[moment][action]
    if not entry then return false end
    if kind == nil then return true end
    local told = kind.tracked
    if moment == "always" or moment == "ready" or moment == "unusable" or moment == "short"
        or moment == "usable" then
        return kind.cooldown
    elseif moment == "cooldown" then
        -- Gray out is an icon row (CdmCard.lua:648).
        if action == "gray" or action == "color" then return kind.cooldown and kind.shape == "icon" end
        return kind.cooldown
    elseif moment == "up" then
        if action == "show" or action == "hide" then return kind.buff and told end
        return kind.showsBuff and told
    elseif moment == "ends" then
        return kind.showsBuff and told
    elseif moment == "missing" then
        -- The card shows this glow on a Buff only piece once something shows while the
        -- buff is down (CdmCard.lua:276-285, 693). A missing glow keeps the icon itself,
        -- so it's offered there too; Hide (Buff missing) makes it a "hidden" problem.
        if action == "glow" then return kind.buff and told end
        return kind.buffOnly
    elseif moment == "recast" then
        return kind.showsBuff and kind.cast
    end
    return false
end

-- The moments that fit a piece, each with its actions, in canonical order:
-- { { moment = "ready", actions = { "show", "fade", ... } }, ... }.
function Grammar.Words(kind)
    local out = {}
    for _, m in ipairs(Grammar.MOMENTS) do
        local actions = {}
        for _, a in ipairs(Grammar.ACTIONS) do
            if Grammar.Fits(kind, m, a) then actions[#actions + 1] = a end
        end
        if #actions > 0 then out[#out + 1] = { moment = m, actions = actions } end
    end
    return out
end

-- ---------------------------------------------------------------------
-- Compile
-- ---------------------------------------------------------------------

-- Hide (Buff up) and Hide (Buff missing) show nothing then, so these glows never
-- light (CdmEffects.lua:491-500).
local HIDDEN_BY = {
    { glow = "upGlow", hide = "hideActive" },
    { glow = "missingGlow", hide = "hideMissing" },
    { glow = "clipGlow", hide = "hideActive" },
}

-- Group and form words into fields.chain and hideIn<Key>.
local function compileGroup(rules, kind, fields, problem, flags)
    local chain = {}
    fields.chain = chain
    local group = type(rules.group) == "table" and rules.group or {}
    for _, word in ipairs(Grammar.GROUP) do
        local v = group[word]
        if v ~= nil then
            local ok
            if word == "where" then ok = v == "any" or indexOf(Grammar.WHERE, v) ~= nil
            else ok = type(v) == "boolean" end
            if ok then chain[word] = v else problem({ group = word, code = "value" }) end
        end
    end
    local unknown = {}
    for word in pairs(group) do
        if not indexOf(Grammar.GROUP, word) then unknown[#unknown + 1] = tostring(word) end
    end
    table.sort(unknown)
    for _, word in ipairs(unknown) do problem({ group = word, code = "pair" }) end
    for _, word in ipairs(Grammar.GROUP) do
        if chain[word] == Bridge.ChainDefault(word) then chain[word] = nil end
    end
    if kind and not kind.alone then
        for _, word in ipairs(Grammar.GROUP) do
            local now = kind.chain[word]
            if now == Bridge.ChainDefault(word) then now = nil end
            if chain[word] ~= now then flags.needsOwnGroup = true end
        end
    end
    for _, key in ipairs(type(rules.forms) == "table" and rules.forms or {}) do
        local fits = kind == nil and isForm(key) or (kind and kind.forms and indexOf(kind.forms, key))
        if fits then fields["hideIn" .. key] = true
        else problem({ form = key, code = kind and "kind" or "pair" }) end
    end
end

-- rules -> fields, problems, flags. kind (Grammar.Kind) is optional; without it
-- every mapped pair is taken.
-- problems: { line = i, code = ... } for a line left out, or { group = word } /
-- { form = key }. Codes:
--   "pair"    no such moment and action
--   "kind"    the piece doesn't take it (Grammar.Fits)
--   "value"   a bad color, sound, fade amount or group value
--   "twice"   an earlier line set the same thing; the later line wins
--   "hidden"  a glow that a hide line keeps from showing
-- flags:
--   needsOwnGroup  group words differ from the group the piece shares with others
--   keepBuffOnly   "missing show" needs the piece kept Buff only: the card sets track
--                  to buff (or aura for Daylight UI's own piece) with it (CdmCard.lua:326-329)
function Grammar.Compile(rules, kind)
    rules = type(rules) == "table" and rules or {}
    local fields, problems, flags = {}, {}, {}
    local setBy, slotBy = {}, {}
    local function problem(t)
        t.seq = #problems + 1
        problems[t.seq] = t
    end
    local function set(i, field, value)
        if setBy[field] and fields[field] ~= value then problem({ line = setBy[field], code = "twice" }) end
        fields[field], setBy[field] = value, i
    end
    local always
    for i, line in ipairs(rules.lines or {}) do
        local entry = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
        if not entry then
            problem({ line = i, code = "pair" })
        elseif not Grammar.Fits(kind, line.moment, line.action) then
            problem({ line = i, code = "kind" })
        elseif entry.all then
            always = entry
        elseif entry.color and line.value ~= nil and not isRGB(line.value) then
            problem({ line = i, code = "value" })
        elseif entry.sound and not isSound(line.value) then
            problem({ line = i, code = "value" })
        elseif entry.alpha and line.value ~= nil
            and not (type(line.value) == "number" and line.value >= 0 and line.value <= 1) then
            problem({ line = i, code = "value" })
        else
            if entry.slot then
                local had = slotBy[entry.slot]
                if had and had.field ~= entry.field then
                    problem({ line = had.line, code = "twice" })
                    fields[had.field], setBy[had.field] = nil, nil
                end
                slotBy[entry.slot] = { field = entry.field, line = i }
            end
            set(i, entry.field, entry.sound and line.value or entry.value)
            if entry.color then
                fields[entry.color] = line.value and copyRGB(line.value) or nil
            end
            if entry.alpha and line.value ~= nil then set(i, "cdAlpha", line.value) end
        end
    end
    -- "always show" sets every show rule no line names.
    if always then
        for _, f in ipairs(always.all) do
            if not setBy[f] then fields[f] = always.value end
        end
    end
    for _, h in ipairs(HIDDEN_BY) do
        if fields[h.glow] == true and fields[h.hide] == true then
            problem({ line = setBy[h.glow], code = "hidden" })
            fields[h.glow], fields[h.glow .. "Color"] = nil, nil
        end
    end
    if fields.missing == true then flags.keepBuffOnly = true end
    -- Values equal to Daylight UI's default are left out, as its setters do.
    for _, f in ipairs(Grammar.FIELDS) do
        if fields[f] ~= nil and fields[f] == spellDefault(f) then fields[f] = nil end
    end
    compileGroup(rules, kind, fields, problem, flags)
    -- By line, group and form words last; ties keep the order they were found in.
    table.sort(problems, function(a, b)
        local la, lb = a.line or math.huge, b.line or math.huge
        if la ~= lb then return la < lb end
        return a.seq < b.seq
    end)
    for _, p in ipairs(problems) do p.seq = nil end
    return fields, problems, flags
end

-- ---------------------------------------------------------------------
-- Decompile
-- ---------------------------------------------------------------------

-- fields -> rules, problems. Lines come in canonical order (Grammar.MOMENTS, then
-- Grammar.ACTIONS); values equal to Daylight UI's defaults make no line. problems
-- name the lines that don't fit kind, kept so a save never drops them unseen.
function Grammar.Decompile(fields, kind)
    fields = type(fields) == "table" and fields or {}
    local lines, problems = {}, {}
    local alphaTaken = false
    for _, m in ipairs(Grammar.MOMENTS) do
        for _, a in ipairs(Grammar.ACTIONS) do
            local entry = MAP[m][a]
            if entry and not entry.all then
                local v = fields[entry.field]
                local line
                if entry.sound then
                    if v ~= nil and v ~= spellDefault(entry.field) then
                        line = { moment = m, action = a, value = v }
                    end
                elseif v ~= nil and v == entry.value and v ~= spellDefault(entry.field) then
                    line = { moment = m, action = a }
                    if entry.color and isRGB(fields[entry.color]) then line.value = copyRGB(fields[entry.color]) end
                    if entry.alpha and not alphaTaken and fields.cdAlpha ~= nil
                        and fields.cdAlpha ~= spellDefault("cdAlpha") then
                        line.value, alphaTaken = fields.cdAlpha, true
                    end
                end
                if line then
                    lines[#lines + 1] = line
                    if not Grammar.Fits(kind, m, a) then problems[#problems + 1] = { line = #lines, code = "kind" } end
                end
            end
        end
    end
    local group = {}
    local chain = type(fields.chain) == "table" and fields.chain or {}
    for _, word in ipairs(Grammar.GROUP) do
        local v = chain[word]
        if v ~= nil and v ~= Bridge.ChainDefault(word) then group[word] = v end
    end
    local forms = {}
    for field, v in pairs(fields) do
        local key = type(field) == "string" and field:match("^hideIn(%u%w*)$")
        if key and v == true then forms[#forms + 1] = key end
    end
    table.sort(forms)
    for _, key in ipairs(forms) do
        if kind and not (kind.forms and indexOf(kind.forms, key)) then
            problems[#problems + 1] = { form = key, code = "kind" }
        end
    end
    return { lines = lines, group = group, forms = forms }, problems
end

-- ---------------------------------------------------------------------
-- Plain words
-- ---------------------------------------------------------------------

local MOMENT_WORDS = {
    ready = "When it's ready",
    cooldown = "When it's on cooldown",
    unusable = "When it's not usable",
    short = "When you're short of power",
    usable = "When it turns usable",
    up = "While its buff is up",
    ends = "When its buff ends",
    missing = "While its buff is missing",
    recast = "When it's due for recast",
}

local GLOW_NAMES = {
    missing = "the buff missing glow", recast = "the recast glow", up = "the buff up glow",
    usable = "the usable glow", ready = "the ready glow",
}

-- A sound key's name in Daylight UI's list, or the key.
local function soundName(key)
    local values = Bridge.SoundChoices()
    local name = type(values) == "table" and values[key]
    return type(name) == "string" and name or tostring(key)
end

local function actionWords(line)
    local a = line.action
    if a == "show" then return "show it" end
    if a == "hide" then return "hide it" end
    if a == "fade" then
        if type(line.value) == "number" then
            return string.format("fade it to %d%%", math.floor(line.value * 100 + 0.5))
        end
        return "fade it"
    end
    if a == "glow" then return line.value and "glow in the color you picked" or "glow" end
    if a == "gray" then return "gray it" end
    if a == "color" then return "keep its color" end
    if a == "sound" then return string.format("play \"%s\"", soundName(line.value)) end
    return tostring(a)
end

-- The line as one sentence, in US English.
function Grammar.Describe(line)
    if type(line) ~= "table" then return "" end
    if line.moment == "always" then return "Always " .. actionWords(line) .. "." end
    local m = MOMENT_WORDS[line.moment] or tostring(line.moment)
    return m .. ", " .. actionWords(line) .. "."
end

-- Two glow moments that can be true at once. Buff missing is never true with buff up,
-- and recast never lights on a known "missing" (CdmEffects.lua:503-508).
local function overlap(a, b)
    local pair = a < b and a .. "+" .. b or b .. "+" .. a
    return pair ~= "missing+up" and pair ~= "missing+recast"
end

-- Plain-word notes on rules, for a glow that another one hides. Each is
-- { winner = moment, loser = moment, text = ... }, winners first by priority.
function Grammar.Notes(rules)
    local on = {}
    for _, line in ipairs(type(rules) == "table" and rules.lines or {}) do
        if type(line) == "table" and line.action == "glow" and MAP[line.moment] and MAP[line.moment].glow then
            on[line.moment] = true
        end
    end
    local notes = {}
    for i, win in ipairs(Grammar.GLOW_ORDER) do
        if on[win] then
            for j = i + 1, #Grammar.GLOW_ORDER do
                local lose = Grammar.GLOW_ORDER[j]
                if on[lose] and overlap(win, lose) then
                    notes[#notes + 1] = { winner = win, loser = lose,
                        text = string.format("Only one glow shows at a time: when both apply, %s shows instead of %s.",
                            GLOW_NAMES[win], GLOW_NAMES[lose]) }
                end
            end
        end
    end
    return notes
end
