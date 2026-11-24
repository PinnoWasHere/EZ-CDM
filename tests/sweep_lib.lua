local stub = require("stub")
local CW = require("cdmworld")
local W = require("classworld")

-- The universality sweep: EZ-CDM over every class in the game's Cooldown Manager
-- catalogue (tests/cooldown_sets.lua). Each class gets one world with every
-- catalogue spell and every Daylight UI class spell known. Every piece the
-- editor's tray offers is placed, plus an item and a spell added by ID. Then each
-- piece is checked:
--   kind     Grammar.Kind, Words and Extras run with no error
--   card     Words match the card oracle on all three tabs, less the named departures
--   words    every offered word compiles, writes live through Draft and reads back
--   effects  every EZ effect offered on, then Daylight UI's passes in and out of a
--            fight raise no error, no refused call and no secret test
--   place    no write moves a piece
-- Each class runs twice: the game's buff viewers shown (the game's items draw
-- buffs), then hidden (Daylight UI's aura holders draw them, so EZ-CDM's rings).
--
-- A failure reads "<CLASS> <variant> / <piece> (<key>, <shape>) / <check>: <what>".
-- KNOWN lists the failures the sweep has found and nobody has fixed yet, by
-- "<CLASS> <variant>|<key>|<check>", each with a reason. A known failure is left out
-- of its class's test and gets a test of its own that it still happens.

local SW = {}

local ESSENTIAL, UTILITY, BUFFS, BARS = W.ESSENTIAL, W.UTILITY, W.BUFFS, W.BARS
local COLOR = { 0.2, 0.4, 0.6 }
local TINT = { 0.2, 0.4, 0.6, 0.5 }
local LEAD = 5
local ITEM, ADDED_SPELL = W.ITEM, W.ADDED_SPELL

-- The catalogue's classes and the class world (tests/classworld.lua).
SW.Classes, SW.Class = W.Classes, W.Class

-- ---------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------

local copy = W.copy

local function dump(v)
    if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = "[" .. dump(k) .. "]=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end
SW.dump = dump

-- Puts t's contents back to snap's, in place, so every holder of t sees it.
local function restore(t, snap)
    for k in pairs(t) do t[k] = nil end
    for k, v in pairs(copy(snap)) do t[k] = v end
end

local pass = W.pass
SW.pass = pass

-- ---------------------------------------------------------------------
-- The world
-- ---------------------------------------------------------------------

SW.Links, SW.Facts = W.Links, W.Facts

-- One class logged in with every catalogue spell and every Daylight UI class spell
-- known (W.World). opts.hidden hides the game's buff viewers; opts.db = { dui, ez }
-- is the saved variables of an earlier session (a /reload); opts.patch(ns) runs once
-- EZ-CDM loads, before login.
SW.World = W.World

-- Places every piece the editor's tray offers (Other talents and Group buffs on),
-- each in the tray's shape (every one a bar with bars set), plus the item and the
-- spell added by ID. Returns the placed list { { key, shape, name } } in tray order.
function SW.PlaceTray(AB, bars)
    local Ed, D = AB.CdmEditor, AB.CdmData
    Ed.SetShowGroup(true)
    Ed.SetShowUnlearned(true)
    local set = D.Ensure(1)
    local placed = {}
    local function place(key, shape, name)
        if set.pieces[key] then return end
        local i = #placed
        D.AddPiece(set, key, shape, (i % 12) * 60, -math.floor(i / 12) * 60)
        if set.pieces[key] then
            local C = AB.CdmCustom
            placed[#placed + 1] = { key = key, shape = shape, name = name,
                                    group = C.IsGroup(key) or nil, weapon = C.Weapon(key) ~= nil or nil }
        end
    end
    for _, e in ipairs(Ed.Spells()) do
        place(e.id, (bars or e.kind == "bar") and "bar" or "icon", e.name)
    end
    local item = Ed.KeyForID("item", tostring(ITEM))
    if item then place(item, bars and "bar" or "icon", "Healthstone (added item)") end
    local spell = Ed.KeyForID("spell", tostring(ADDED_SPELL))
    if spell then place(spell, bars and "bar" or "icon", "Mana Spring (added spell)") end
    pass(AB)
    return placed, item, spell
end

-- ---------------------------------------------------------------------
-- The card oracle (test_grammar's, all three tabs)
-- ---------------------------------------------------------------------

local CARD_WORDS = {
    onReady = { ready = { "show", "fade", "hide" } },
    readyGlow = { ready = { "glow" } },
    readySound = { ready = { "sound" } },
    onCd = { cooldown = { "show", "fade", "hide" } },
    desat = { cooldown = { "gray", "color" } },
    onUnusable = { unusable = { "show", "fade", "hide" } },
    onShort = { short = { "show", "fade", "hide" } },
    usableGlow = { usable = { "glow" } },
    usableSound = { usable = { "sound" } },
    buffUp = { up = { "show", "hide" } },
    upGlow = { up = { "glow" } },
    buffSound = { up = { "sound" } },
    activeColor = { up = { "tint" } },
    noDurationSwipe = { up = { "nosweep" } },
    clipGlow = { recast = { "glow", "sound" } },
    buffEndSound = { ends = { "sound" } },
    buffDown = { missing = { "show", "hide" } },
    missingGlow = { missing = { "glow" } },
    inactiveFlash = { missing = { "flash" } },
    noSwipe = { cooldown = { "nosweep" } },
    noGcd = { cooldown = { "nogcd" } },
    low = { almost = { "numbers" } },
}
local CARD_EXTRAS = { track = "shows", ownTrack = "shows", glowStyle = "style" }
local CARD_OTHER = {
    readyGlowColor = true, usableGlowColor = true, upGlowColor = true, clipGlowColor = true,
    missingGlowColor = true, cdAlpha = true, lowAt = true, lowColor = true,
}
local LEFT = {
    activeGlow = true, totemTrack = true, buffTotemTrack = true,
    size = true, ["chain.size"] = true, width = true, height = true, ["chain.width"] = true, ["chain.height"] = true,
    reverse = true, shieldAmount = true, fillBy = true,
    cdNumbers = true, cdSize = true, cdColor = true, countSize = true, countColor = true, countSpot = true,
    keyShown = true, keySize = true, keySpot = true,
    showName = true, nameAlign = true, nameSize = true, nameColor = true, time = true, timeSize = true,
    timeColor = true, ["chain.text"] = true, ["chain.time"] = true, icon = true, ["chain.icon"] = true,
    chargeLines = true, barMode = true, barColor = true, barGradient = true, backMode = true, backColor = true,
    backGradient = true, ["chain.color"] = true, ["chain.back"] = true, ["chain.backColor"] = true,
    ["chain.backGradient"] = true,
    fxStyle = true, fxSpeed = true, fxStrength = true, fxColors = true, fxColorA = true, fxColorB = true,
    ["chain.spacing"] = true, ["chain.grow"] = true, back = true, forward = true,
    alignAcross = true, alignDown = true, gap = true, unhook = true, ["chain.tether"] = true,
}
local function left(key)
    return LEFT[key] or key:find("^barStops%.") ~= nil or key:find("^chain%.barStops%.") ~= nil
end
local ALWAYS_ROWS = { "onReady", "onCd", "onUnusable", "onShort" }

-- The departures test_grammar names.
SW.DEPARTURES = {
    missing = "missing glow (CdmCard.lua:285-294, 702)",
    recast = "recast glow on a spell you never cast (CdmCard.lua:422-424)",
    untimed = "recast glow on an aura that never falls off (CdmCard.lua:422-424)",
    untimedEnds = "wears-off sound on an aura that is only on or off",
    low = "almost-ready color on a buff alone (CdmCard.lua:522-524)",
    ezGlow = "up glow EZ-CDM draws in the client's button (Effects.lua)",
}

local function cardRows(G, AB, id)
    local group = {}
    for i, word in ipairs(G.GROUP) do group[G.CHAIN[i]] = word end
    local Ed = AB.CdmEditor
    Ed.Select(id)
    if Ed.Selected() ~= id then error("the editor won't pick " .. tostring(id)) end
    local set = Ed.Set()
    local p = set.pieces[id]
    local on = {}
    for _, tab in ipairs(AB.CdmCard.TABS) do
        for _, row in ipairs(AB.CdmCard.ROWS[tab]) do
            if row.item and row.show(set, id, p) then
                local key = row.item.key:gsub("^cdm%.card%.", "")
                local g = key:match("^chain%.(.+)$")
                if (g and group[g]) or CARD_WORDS[key] or CARD_EXTRAS[key] or CARD_OTHER[key] or key:find("^hideIn") then
                    on[key] = true
                elseif not left(key) then
                    error("a " .. tab .. " row with no grammar mapping and no reason: " .. key)
                end
            end
        end
    end
    return on
end

local function exceptions(G, AB, id, on, kind)
    local out = {}
    -- EZ-CDM's conditions (Conditions.lua) have no card row: every one that fits.
    on.ezConditions = {}
    for _, m in ipairs(G.MOMENTS) do
        for _, a in ipairs(G.ACTIONS) do
            local e = G.MAP[m] and G.MAP[m][a]
            if e and e.cond and G.Fits(kind, m, a) then
                on.ezConditions[m] = on.ezConditions[m] or {}
                table.insert(on.ezConditions[m], a)
            end
        end
    end
    if not on.upGlow and kind.ezGlow and not kind.tracked then
        on.upGlow = true
        out[#out + 1] = SW.DEPARTURES.ezGlow
    end
    if on.clipGlow and not kind.cast then
        on.clipGlow, on.clipGlowColor = nil, nil
        out[#out + 1] = SW.DEPARTURES.recast
    end
    if on.clipGlow and kind.untimed then
        on.clipGlow, on.clipGlowColor = nil, nil
        out[#out + 1] = SW.DEPARTURES.untimed
    end
    if on.buffEndSound and kind.untimed then
        on.buffEndSound = nil
        out[#out + 1] = SW.DEPARTURES.untimedEnds
    end
    if on.low and not kind.cooldown then
        on.low, on.lowAt, on.lowColor = nil, nil, nil
        out[#out + 1] = SW.DEPARTURES.low
    end
    if not on.buffDown or on.missingGlow then return out end
    local p = AB.CdmEditor.Set().pieces[id]
    local had = p.missing
    p.missing = true
    local ok, with = pcall(cardRows, G, AB, id)
    p.missing = had
    if ok and with.missingGlow then
        on.missingGlow = true
        out[#out + 1] = SW.DEPARTURES.missing
    end
    return out
end

local function wordsOf(G, kind)
    local out = {}
    for _, e in ipairs(G.Words(kind)) do out[#out + 1] = e.moment .. "(" .. table.concat(e.actions, ",") .. ")" end
    return table.concat(out, " ")
end

-- The words in a CardAndGrammar line, one token each ("ready glow", "+style",
-- "group combat").
local function tokens(line)
    local out = {}
    for m, acts in line:gmatch("(%a+)%(([%a,]*)%)") do
        for a in acts:gmatch("%a+") do out[m .. " " .. a] = true end
    end
    for e in line:gmatch("%+(%a+)") do out["+" .. e] = true end
    return out
end

-- The grammar's words the card lacks, and the card's the grammar lacks, sorted.
function SW.WordDiff(card, mine)
    local c, g = tokens(card), tokens(mine)
    local extra, missing = {}, {}
    for t in pairs(g) do if not c[t] then extra[#extra + 1] = t end end
    for t in pairs(c) do if not g[t] then missing[#missing + 1] = t end end
    table.sort(extra)
    table.sort(missing)
    return extra, missing
end

-- The card's words and the grammar's for a piece, as text, and the departures taken.
function SW.CardAndGrammar(G, AB, id)
    local kind = G.Kind(id)
    local on = cardRows(G, AB, id)
    local why = exceptions(G, AB, id, on, kind)
    local offered = {}
    for key in pairs(on) do
        for m, actions in pairs(CARD_WORDS[key] or (type(on[key]) == "table" and on[key]) or {}) do
            offered[m] = offered[m] or {}
            for _, a in ipairs(actions) do offered[m][a] = true end
        end
    end
    local all = true
    for _, key in ipairs(ALWAYS_ROWS) do all = all and on[key] == true end
    if all then offered.always = { show = true } end
    local card = {}
    for _, m in ipairs(G.MOMENTS) do
        local acts = {}
        for _, a in ipairs(G.ACTIONS) do
            if offered[m] and offered[m][a] then acts[#acts + 1] = a end
        end
        if #acts > 0 then card[#card + 1] = m .. "(" .. table.concat(acts, ",") .. ")" end
    end
    local extras = {}
    for _, e in ipairs(G.EXTRAS) do
        for key, x in pairs(CARD_EXTRAS) do
            if x == e and on[key] then extras[#extras + 1] = e; break end
        end
    end
    if #extras > 0 then card[#card + 1] = "+" .. table.concat(extras, "+") end
    local group = {}
    for i, word in ipairs(G.GROUP) do
        if on["chain." .. G.CHAIN[i]] then group[#group + 1] = word end
    end
    if #group > 0 then card[#card + 1] = "group(" .. table.concat(group, ",") .. ")" end
    local mine = { wordsOf(G, kind) }
    if mine[1] == "" then mine = {} end
    local ex = G.Extras(kind)
    if #ex > 0 then mine[#mine + 1] = "+" .. table.concat(ex, "+") end
    mine[#mine + 1] = "group(" .. table.concat(G.GROUP, ",") .. ")"
    return table.concat(card, " "), table.concat(mine, " "), why
end

-- ---------------------------------------------------------------------
-- The words a piece offers, as lines to write
-- ---------------------------------------------------------------------

local function aSound(B)
    local values, order = B.SoundChoices()
    for _, k in ipairs(order or {}) do
        if not tostring(k):find("^head:") and k ~= "none" and values[k] then return k end
    end
end

-- A style other than Daylight UI's default (the ring), and a second one.
local function styles(B)
    local out = {}
    for _, st in ipairs(B.GlowStyles() or {}) do
        if st.key ~= B.Option({}, "glowStyle") then out[#out + 1] = st.key end
    end
    return out
end

-- One line per offered moment and action, with a sample value; extra cases for a
-- fall-off lead, each glow's own style and flash. Each is { what, rules }.
function SW.Cases(G, B, kind)
    local sound, st = aSound(B), styles(B)
    local out = {}
    local function add(what, lines, extra)
        local rules = { lines = lines, group = {}, forms = {} }
        for k, v in pairs(extra or {}) do rules[k] = v end
        out[#out + 1] = { what = what, rules = rules }
    end
    for _, w in ipairs(G.Words(kind)) do
        for _, a in ipairs(w.actions) do
            local line = { moment = w.moment, action = a }
            if a == "glow" or a == "tint" or a == "numbers" then line.value = a == "tint" and TINT or COLOR end
            if a == "sound" then line.value = sound end
            if a == "fade" then line.value = 0.25 end
            if w.moment == "recast" or (w.moment == "almost" and a == "numbers") then line.at = LEAD end
            if a == "flash" then
                add("missing show + flash", { { moment = "missing", action = "show" }, line })
            else
                add(w.moment .. " " .. a, { line })
            end
            if a == "glow" and st[1] and not G.RingOnly(kind, w.moment) then
                local styled = copy(line)
                styled.style = st[1]
                add(w.moment .. " glow, style " .. st[1], { styled })
            end
        end
    end
    -- Flash shows once Buff missing shows, with "show it" in the same rules.
    local flashKind = setmetatable({ missingShown = true }, { __index = kind })
    if G.Fits(flashKind, "missing", "flash") and not G.Fits(kind, "missing", "flash") then
        add("missing show + flash", { { moment = "missing", action = "show" }, { moment = "missing", action = "flash" } })
    end
    for _, word in ipairs(G.GROUP) do
        if word == "where" then
            for _, x in ipairs(G.WHERE) do add("group where " .. x, {}, { group = { where = x } }) end
        else
            add("group " .. word, {}, { group = { [word] = true } })
        end
    end
    for _, f in ipairs(kind.forms or {}) do add("form " .. f, {}, { forms = { f } }) end
    -- Every recipe the drawer shows on the piece, on a spell with no lines yet.
    for _, key in ipairs(G.Recipes(kind)) do
        out[#out + 1] = { what = "recipe " .. key, check = "recipes",
                          rules = G.ApplyRecipe({ lines = {}, group = {}, forms = {} }, key) }
    end
    for _, e in ipairs(G.Extras(kind)) do
        if e == "shows" then
            for _, x in ipairs(G.SHOWS) do add("shows " .. x, {}, { shows = x }) end
        elseif e == "style" and st[1] then
            add("style " .. st[1], {}, { style = st[1] })
        end
    end
    return out
end

-- Every EZ effect the piece is offered, as one set of lines: the up ring (an up glow
-- EZ-CDM draws), the fall-off lead and sound, and each glow moment's own style.
-- Returns the lines and the names of the effects in them.
function SW.Effects(G, B, kind)
    local sound, st = aSound(B), styles(B)
    local lines, names = {}, {}
    local lead = LEAD
    local n = 0
    for _, m in ipairs(G.MOMENTS) do
        if G.Fits(kind, m, "glow") and (m ~= "recast" or lead) then
            local line = { moment = m, action = "glow", value = COLOR }
            if m == "recast" then line.at = lead end
            if not G.RingOnly(kind, m) and #st > 0 then
                n = n + 1
                line.style = st[(n - 1) % #st + 1]
                names[#names + 1] = "style " .. m
            end
            if m == "up" and kind.ezGlow then names[#names + 1] = "up ring" end
            if m == "recast" then names[#names + 1] = "fall-off lead" end
            lines[#lines + 1] = line
        end
    end
    if lead and G.Fits(kind, "recast", "sound") then
        lines[#lines + 1] = { moment = "recast", action = "sound", value = sound, at = lead }
        names[#names + 1] = "fall-off sound"
    end
    return lines, names
end

-- ---------------------------------------------------------------------
-- The sweep
-- ---------------------------------------------------------------------

-- Where every piece sits, as a flat list in key order, and whether two lists match.
-- A group's first piece follows from the parents, so it isn't listed.
local SPOT = { "x", "y", "parent", "side", "align", "gap" }
local function places(AB)
    local D = AB.CdmData
    local set = D.Get(1)
    local keys = {}
    for key in pairs(set.pieces) do keys[#keys + 1] = key end
    table.sort(keys, D.ByKey)
    local out = {}
    for _, key in ipairs(keys) do
        local p = set.pieces[key]
        out[#out + 1] = key
        for _, f in ipairs(SPOT) do out[#out + 1] = p[f] == nil and false or p[f] end
    end
    return out
end
local function moved(a, b)
    if #a ~= #b then return true end
    for i = 1, #a do
        if a[i] ~= b[i] then return true end
    end
    return false
end

local function lineText(l)
    if type(l) ~= "table" then return tostring(l) end
    return dump(l)
end

-- Lines as text, so two lists compare.
local function linesText(lines)
    local out = {}
    for i, l in ipairs(lines or {}) do out[i] = lineText(l) end
    return table.concat(out, " ")
end

-- What a write should read back: its lines less those Daylight UI does anyway.
local function expected(G, kind, rules)
    local out = {}
    for _, l in ipairs(rules.lines) do
        if not G.IsDefault(l, kind) then out[#out + 1] = l end
    end
    return out
end

local function newErrors(from)
    local out = {}
    for i = from + 1, #stub.errors do out[#out + 1] = tostring(stub.errors[i]):gsub("\n.*", "") end
    return table.concat(out, " | ")
end

-- Every buff lands once out of a fight, so the holders read their lengths, as in
-- play.
local function landBuffs(AB, c)
    for _, r in ipairs(c.rows) do
        if r.aura and (r.category == BUFFS or r.category == BARS) then
            local unit = r.selfAura and "player" or "target"
            local ids = { r.spell, unpack(r.linkAuras) }
            for _, id in ipairs(ids) do CW.Aura(unit, id, { harmful = unit == "target", duration = 12 }) end
        end
    end
    pass(AB)
    for _, r in ipairs(c.rows) do
        for _, id in ipairs({ r.spell, unpack(r.linkAuras) }) do
            CW.Unaura("player", id); CW.Unaura("target", id)
        end
    end
    pass(AB)
end

-- One class's tray placed with the buff viewers hidden, each buff landed once:
-- { [piece name] = Grammar.Kind } for every placed piece.
function SW.Kinds(class)
    local c = assert(SW.Class(class), class)
    local _, ns, AB = SW.World(c, { hidden = true })
    local placed = SW.PlaceTray(AB, false)
    landBuffs(AB, c)
    local out = {}
    for _, p in ipairs(placed) do out[p.name] = ns.Grammar.Kind(p.key) end
    return out
end

-- Every placed piece whose spell and held ids are all untimed by the aura links
-- (EZ-CDM/AuraLinks.lua), worked out here from the table, not from kind.untimed:
-- { { name, key, cast, recast } }, recast true when the grammar offers the moment.
function SW.Untimed(class)
    local c = assert(SW.Class(class), class)
    local _, ns, AB = SW.World(c, { hidden = true })
    local placed = SW.PlaceTray(AB, false)
    landBuffs(AB, c)
    local U, B, G = SW.Links().untimed, ns.Bridge, ns.Grammar
    local out = {}
    for _, p in ipairs(placed) do
        local sid = B.SpellOf(p.key)
        local all = sid ~= nil and U[sid] == true
        for id in pairs(all and B.SpellIDs(p.key) or {}) do
            if not U[id] then all = false end
        end
        if all then
            local kind = G.Kind(p.key)
            out[#out + 1] = { name = p.name, key = p.key, cast = kind.cast,
                              recast = G.Fits(kind, "recast", "glow") or G.Fits(kind, "recast", "sound") }
        end
    end
    return out
end

-- One test per class of a group: no untimed piece offers "about to fall off", and
-- the class's named untimed pieces are among them.
SW.UNTIMED_NAMED = { SHAMAN = { "Ghost Wolf" }, PRIEST = { "Shadowform" }, DRUID = { "Moonkin Aura" } }
function SW.UntimedTests(group)
    for _, class in ipairs(SW.GROUPS[group]) do
        T.test("sweep untimed: " .. class .. " pieces that never fall off offer no recast", function()
            local seen = {}
            for _, u in ipairs(SW.Untimed(class)) do
                seen[u.name] = true
                T.falsy(u.recast, class .. " " .. u.name .. " (" .. tostring(u.key) .. ") offers the recast moment")
            end
            for _, name in ipairs(SW.UNTIMED_NAMED[class] or {}) do
                T.truthy(seen[name], class .. " " .. name .. " is placed and untimed")
            end
        end)
    end
end

-- The variants each class runs:
--   shown   the game's buff viewers shown; tray shapes
--   hidden  the buff viewers hidden, so Daylight UI's aura holders draw buffs; tray shapes
--   bars    hidden, and every piece a bar
SW.VARIANTS = { shown = {}, hidden = { hidden = true }, bars = { hidden = true, bars = true } }
SW.VARIANT_ORDER = { "shown", "hidden", "bars" }

-- Runs the sweep for one class and variant. Returns { counts, departures, fails =
-- { check = { { id, text } } } }, where id is "<CLASS> <variant>|<key>|<check>".
-- opts.only(p) limits the pieces checked; opts.patch(ns) runs once EZ-CDM loads.
function SW.Run(c, variant, opts)
    opts = opts or {}
    local v = SW.VARIANTS[variant]
    local hidden = v.hidden
    local tag = c.class .. " " .. variant
    local res = { counts = {}, fails = { world = {}, kind = {}, card = {}, words = {}, recipes = {}, effects = {}, place = {} },
                  departures = {} }
    local function fail(check, p, what, info)
        local key = p and tostring(p.key) or "-"
        local name = p and (tostring(p.name) .. " (" .. key .. ", " .. p.shape .. ")") or "-"
        local list = res.fails[check]
        list[#list + 1] = { id = tag .. "|" .. key .. "|" .. check, class = c.class, variant = variant, check = check,
                            p = p, piece = name, what = what, info = info or {},
                            text = tag .. " / " .. name .. " / " .. check .. ": " .. what }
    end

    res.time = {}
    local clock = os.clock()
    local function lap(name)
        res.time[name] = os.clock() - clock
        clock = os.clock()
    end
    local okWorld, err = pcall(function()
        local DUI, ns, AB = SW.World(c, { hidden = hidden, patch = opts.patch })
        local G, B, Draft = ns.Grammar, ns.Bridge, ns.Draft
        local placed, item, spell = SW.PlaceTray(AB, v.bars)
        res.counts.pieces = #placed
        if opts.only then
            local keep = {}
            for _, p in ipairs(placed) do if opts.only(p) then keep[#keep + 1] = p end end
            placed = keep
        end
        res.placed = placed
        res.counts.item, res.counts.spell = item, spell
        if #stub.errors > 0 then fail("world", nil, "placing the tray: " .. newErrors(0)) end
        local D = AB.CdmData
        local set = D.Get(1)
        landBuffs(AB, c)
        local start = places(AB)
        local custom, game, drawn, words, writes, recipes = 0, 0, {}, 0, 0, 0
        local kinds = {}

        -- kind and card
        for _, p in ipairs(placed) do
            local e0 = #stub.errors
            local ok, kind = pcall(G.Kind, p.key)
            if not ok then
                fail("kind", p, "Grammar.Kind: " .. tostring(kind))
            else
                local ok2, why = pcall(function() G.Words(kind); G.Extras(kind) end)
                if not ok2 then fail("kind", p, "Words or Extras: " .. tostring(why)) end
                kinds[p.key] = kind
                if kind.custom then custom = custom + 1 else game = game + 1 end
                -- A proc EZ-CDM draws can't be timed in a fight, so it has no fall-off moment.
                if kind.proc and (G.Fits(kind, "recast", "glow") or G.Fits(kind, "recast", "sound")) then
                    fail("kind", p, "a proc EZ-CDM draws offers a fall-off moment")
                end
                if kind.proc and not kind.custom then res.counts.procs = (res.counts.procs or 0) + 1 end
                if kind.cast == false then res.counts.neverCast = (res.counts.neverCast or 0) + 1 end
                local by = tostring(kind.drawnBy)
                drawn[by] = (drawn[by] or 0) + 1
            end
            if #stub.errors > e0 then fail("kind", p, "errors: " .. newErrors(e0)) end
            if kinds[p.key] then
                local okc, card, mine, why = pcall(SW.CardAndGrammar, G, AB, p.key)
                if not okc then
                    fail("card", p, tostring(card))
                elseif card ~= mine then
                    local extra, missing = SW.WordDiff(card, mine)
                    local k = kinds[p.key]
                    fail("card", p, "card: " .. card .. " | grammar: " .. mine, { extra = extra, missing = missing,
                        proc = k.proc, cast = k.cast })
                else
                    for _, w in ipairs(why) do res.departures[w] = (res.departures[w] or 0) + 1 end
                end
            end
        end
        res.counts.custom, res.counts.game, res.counts.drawn = custom, game, drawn
        lap("world, kind and card")
        res.kinds = {}
        for _, p in ipairs(placed) do
            local k = kinds[p.key]
            if k then
                res.kinds[#res.kinds + 1] = string.format("%s (%s, %s) drawn=%s custom=%s cd=%s buff=%s tracked=%s cast=%s ezGlow=%s proc=%s forms=%s | %s",
                    tostring(p.name), tostring(p.key), p.shape, tostring(k.drawnBy), tostring(k.custom), tostring(k.cooldown),
                    tostring(k.buff), tostring(k.tracked), tostring(k.cast), tostring(k.ezGlow), tostring(k.proc),
                    table.concat(k.forms or {}, ","), wordsOf(G, k))
            end
        end

        -- words
        local ezBase = copy(EZCDMDB)
        for _, p in ipairs(placed) do
            local kind = kinds[p.key]
            if kind then
                local live = set.pieces[p.key]
                local snap = copy(live)
                local chainSnap = copy(set.chains[p.key])
                local okCases, cases = pcall(SW.Cases, G, B, kind)
                if not okCases then
                    fail("words", p, "the cases: " .. tostring(cases))
                    cases = {}
                end
                for _, case in ipairs(cases) do
                    local e0 = #stub.errors
                    local before = places(AB)
                    local what = case.what
                    local check = case.check or "words"
                    if case.check == "recipes" then recipes = recipes + 1 end
                    local _, problems = G.Compile(case.rules, kind)
                    local bad = {}
                    for _, pr in ipairs(problems) do bad[#bad + 1] = tostring(pr.code) end
                    local info = { case = what, proc = kind.proc }
                    if #bad > 0 then fail(check, p, what .. ": compiles with " .. table.concat(bad, ","), info) end
                    local okW, done, why, report = pcall(Draft.Write, p.key, case.rules)
                    writes = writes + 1
                    if not okW then
                        fail(check, p, what .. ": Draft.Write errors: " .. tostring(done))
                    elseif not done then
                        local note = report and report.notes and report.notes[1] and report.notes[1].words
                        fail(check, p, what .. ": Draft.Write refused, " .. tostring(why) .. " " .. tostring(note), info)
                    else
                        local okR, back = pcall(Draft.Rules, p.key)
                        if not okR or type(back) ~= "table" then
                            fail(check, p, what .. ": Draft.Rules: " .. tostring(back))
                        else
                            local want = expected(G, kind, case.rules)
                            if linesText(back.lines) ~= linesText(want) then
                                fail(check, p, what .. ": wrote " .. linesText(want) .. ", read " .. linesText(back.lines))
                            end
                            if dump(back.group) ~= dump(case.rules.group) then
                                fail(check, p, what .. ": group " .. dump(case.rules.group) .. ", read " .. dump(back.group))
                            end
                            if dump(back.forms) ~= dump(case.rules.forms) then
                                fail(check, p, what .. ": forms " .. dump(case.rules.forms) .. ", read " .. dump(back.forms))
                            end
                            if case.rules.shows ~= nil and back.shows ~= case.rules.shows then
                                fail(check, p, what .. ": read shows " .. tostring(back.shows))
                            end
                            if case.rules.style ~= nil and back.style ~= case.rules.style then
                                fail(check, p, what .. ": read style " .. tostring(back.style))
                            end
                        end
                        local okC, cleared, why2 = pcall(Draft.Write, p.key, { lines = {}, group = {}, forms = {} })
                        writes = writes + 1
                        if not (okC and cleared) then
                            fail(check, p, what .. ": clearing it: " .. tostring(okC and why2 or cleared))
                        end
                    end
                    words = words + 1
                    if moved(places(AB), before) then fail("place", p, what .. " moved a piece") end
                    if #stub.errors > e0 then fail(check, p, what .. ": errors: " .. newErrors(e0)) end
                    restore(live, snap)
                    if chainSnap then
                        set.chains[p.key] = set.chains[p.key] or {}
                        restore(set.chains[p.key], chainSnap)
                    else
                        set.chains[p.key] = nil
                    end
                    EZCDMDB = copy(ezBase)
                end
            end
        end
        res.counts.words, res.counts.writes, res.counts.recipes = words, writes, recipes
        lap("words")
        pass(AB)

        -- effects: every EZ effect each piece is offered, all at once
        local effects = 0
        for _, p in ipairs(placed) do
            local kind = kinds[p.key]
            if kind then
                local lines, names = SW.Effects(G, B, kind)
                if #lines > 0 then
                    local e0 = #stub.errors
                    local okW, done, why, report = pcall(Draft.Write, p.key, { lines = lines })
                    if not okW then
                        fail("effects", p, "Draft.Write errors: " .. tostring(done))
                    elseif not done then
                        local note = report and report.notes and report.notes[1] and report.notes[1].words
                        fail("effects", p, table.concat(names, ", ") .. ": refused, " .. tostring(why) .. " " .. tostring(note))
                    else
                        effects = effects + #names
                        for _, n in ipairs(names) do
                            if n == "up ring" then p.ring = true end
                        end
                    end
                    if #stub.errors > e0 then fail("effects", p, "writing: " .. newErrors(e0)) end
                end
            end
        end
        res.counts.effects = effects
        if moved(places(AB), start) then fail("place", nil, "the words and effects left a piece moved") end

        lap("effects")
        -- A /reload, so the holders' buttons are made with EZ-CDM's rings in them.
        local db = { dui = copy(DaylightUIDB), ez = copy(EZCDMDB) }
        local e0 = #stub.errors
        DUI, ns, AB = SW.World(c, { hidden = hidden, db = db, patch = opts.patch })
        if #stub.errors > e0 then fail("effects", nil, "the /reload: " .. newErrors(e0)) end
        -- Each ring written is in the client's buttons after the /reload.
        res.counts.rings = 0
        for _, p in ipairs(placed) do
            local E = ns.Effects
            if p.ring then
                if not E.Lit(p.key) then
                    local h = AB.CdmAuras.Frame(p.key)
                    local n = #(h and h.buttons or {})
                    fail("effects", p, "the up ring is offered and saved, but no button has it after a /reload (drawn by "
                        .. tostring(ns.Bridge.DrawnBy(p.key)) .. ", " .. n
                        .. " client buttons, Daylight UI's upGlow " .. tostring(AB.CdmData.Get(1).pieces[p.key].upGlow) .. ")",
                        { buttons = n, ring = "up" })
                elseif E.Pending(p.key) then fail("effects", p, "the up ring still waits for a /reload after one")
                else res.counts.rings = res.counts.rings + 1 end
            end
        end
        SW.Fight(c, AB, ns, function(what, p) fail("effects", p, what) end, placed)
        lap("reload and fight")
    end)
    if not okWorld then fail("world", nil, tostring(err)) end
    return res
end

-- Daylight UI's passes out of a fight and in one: every catalogue spell cast, put
-- on cooldown and its aura landed (on you, or on the target for a debuff), every
-- holder button shown and hidden by the client, time passing. Reports each error,
-- refused call and secret test through bad(what).
function SW.Fight(c, AB, ns, bad, placed)
    local e0, lock0, init0 = #stub.errors, stub.lockErrors, stub.initSecretErrors
    local function check(when)
        if #stub.errors > e0 then bad(when .. ": " .. newErrors(e0)) end
        if stub.lockErrors > lock0 then bad(when .. ": " .. (stub.lockErrors - lock0) .. " calls the client refuses") end
        if stub.initSecretErrors > init0 then
            bad(when .. ": " .. (stub.initSecretErrors - init0) .. " tests on a secret inside initializeFrame")
        end
        e0, lock0, init0 = #stub.errors, stub.lockErrors, stub.initSecretErrors
    end
    local casts = 0
    local function castAll()
        for _, r in ipairs(c.rows) do
            casts = casts + 1
            stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "sweep-" .. casts, r.spell)
        end
        stub.RunTimers()
    end
    local function aurasOn()
        for _, r in ipairs(c.rows) do
            if r.aura then
                local unit = r.selfAura and "player" or "target"
                CW.Aura(unit, r.spell, { harmful = unit == "target", duration = 12 })
            end
        end
        stub.RunTimers()
    end
    local function aurasOff()
        for _, r in ipairs(c.rows) do
            if r.aura then CW.Unaura(r.selfAura and "player" or "target", r.spell) end
        end
        stub.RunTimers()
    end
    local function cooldownsOn()
        for _, r in ipairs(c.rows) do
            if r.category == ESSENTIAL or r.category == UTILITY then CW.Cooldown(r.spell, 8) end
        end
        stub.RunTimers()
    end
    local function buttons(on)
        local set = AB.CdmData.Get(1)
        for key in pairs(set.pieces) do
            local h = AB.CdmAuras.Frame(key)
            for _, btn in ipairs(h and h.buttons or {}) do stub.AuraAssign(btn, on) end
        end
    end
    local function wait(s)
        stub.Advance(s)
        for _ = 1, 3 do stub.RunTimers() end
        pass(AB)
    end
    pass(AB)
    castAll(); cooldownsOn(); aurasOn(); pass(AB)
    wait(4); wait(5)
    aurasOff(); pass(AB)
    check("out of a fight")
    stub.EnterCombat(); stub.RunTimers()
    castAll(); cooldownsOn(); aurasOn(); buttons(true); pass(AB)
    -- The client plays each handed-over ring as its button shows.
    for _, p in ipairs(placed or {}) do
        local h = p.ring and AB.CdmAuras.Frame(p.key)
        local list = h and h.buttons or {}
        local still = 0
        for _, btn in ipairs(list) do
            local r = ns.Effects.Ring(btn)
            if not (r and r.anim:IsPlaying()) then still = still + 1 end
        end
        if still > 0 then bad("in a fight, " .. still .. " of " .. #list .. " buttons shown play no up ring", p) end
    end
    wait(4); wait(4)
    AB.CdmEffects.UpdateAll()
    wait(4)
    buttons(false); aurasOff(); pass(AB)
    check("in a fight")
    stub.LeaveCombat(); stub.RunTimers(); pass(AB)
    check("after the fight")
end

-- ---------------------------------------------------------------------
-- Known failures
-- ---------------------------------------------------------------------

-- The failures the sweep has found and nobody has fixed yet, each a rule over a
-- failure record ({ class, variant, check, p, info }) with a one-line reason:
--   { name, why, check, classes = { CLASS, ... } or nil, match = function(f) ... end }
-- classes names where a rule is seen, when not every class. The six the sweep first
-- found are fixed (docs/tasks/done/sweep.md, steps 5 to 9), so the sweep asserts them.
SW.KNOWN = {}

function SW.KnownOf(f)
    for _, k in ipairs(SW.KNOWN) do
        if k.check == f.check and k.match(f) then return k end
    end
end

-- ---------------------------------------------------------------------
-- The tests
-- ---------------------------------------------------------------------

-- The class groups, one test file each (each fits the run's per-file CPU budget).
SW.GROUPS = {
    a = { "DRUID", "HUNTER" },
    b = { "PALADIN", "PRIEST", "MAGE" },
    c = { "SHAMAN", "WARLOCK" },
    d = { "ROGUE", "WARRIOR" },
}

SW.CHECKS = {
    { "world", "the world loads and the tray's pieces place" },
    { "kind", "Grammar.Kind, Words and Extras run on every piece" },
    { "card", "every piece offers the card's words on all three tabs" },
    { "words", "every offered word compiles, writes through Draft and reads back" },
    { "recipes", "every recipe shown on a piece compiles, writes through Draft and reads back" },
    { "effects", "every EZ effect on, then passes in and out of a fight" },
    { "place", "no word or effect moves a piece" },
}

-- Runs the group's classes now, one world per class and variant, and registers
-- tests from what they found:
--   sweep <CLASS> <variant>: <check>                    fails on any new failure
--   sweep <CLASS> <variant>: covers every kind of piece the counts it covered
--   sweep <CLASS> <variant> / <piece> / <check>         a new failure, failing
--   sweep known: <CLASS> <variant> / <piece> / <check>  a known one, with its reason
--   sweep known rule still seen: <name>                 fails once a rule meets nothing
function SW.Tests(group)
    local seenRule = {}
    for _, name in ipairs(SW.GROUPS[group]) do
        local c = SW.Class(name)
        for _, variant in ipairs(SW.VARIANT_ORDER) do
            local tag = name .. " " .. variant
            local res = c and SW.Run(c, variant) or { counts = {}, fails = {} }
            for _, check in ipairs(SW.CHECKS) do
                local new, byPiece, order = {}, {}, {}
                for _, f in ipairs(res.fails[check[1]] or {}) do
                    local k = SW.KnownOf(f)
                    local id = f.piece .. " / " .. f.check
                    if k then
                        seenRule[k] = true
                        id = id .. ": " .. k.name
                    else
                        new[#new + 1] = f.text
                    end
                    if not byPiece[id] then
                        byPiece[id] = { k = k, what = {} }
                        order[#order + 1] = id
                    end
                    table.insert(byPiece[id].what, f.what)
                end
                T.test("sweep " .. tag .. ": " .. check[2], function()
                    T.truthy(c, name .. " is in the catalogue")
                    T.eq(#new, 0, #new .. " new failures:\n  " .. table.concat(new, "\n  "))
                end)
                for _, id in ipairs(order) do
                    local e = byPiece[id]
                    if e.k then
                        T.test("sweep known: " .. tag .. " / " .. id, function() T.truthy(e.k.why ~= "", e.k.name) end)
                    else
                        T.test("sweep " .. tag .. " / " .. id, function() error(table.concat(e.what, "\n"), 0) end)
                    end
                end
            end
            T.test("sweep " .. tag .. ": covers every kind of piece", function()
                local n = res.counts
                T.truthy((n.pieces or 0) >= 50, "pieces placed: " .. tostring(n.pieces))
                T.truthy((n.game or 0) >= 25 and (n.custom or 0) >= 20,
                    "game pieces " .. tostring(n.game) .. ", Daylight UI's own " .. tostring(n.custom))
                T.eq(n.item, "i" .. ITEM, "the item added by ID")
                T.eq(n.spell, "s" .. ADDED_SPELL, "the spell added by ID")
                T.truthy((n.words or 0) >= 1000, "words written and read back: " .. tostring(n.words))
                T.truthy((n.effects or 0) >= 100, "EZ effects turned on: " .. tostring(n.effects))
                T.truthy((n.recipes or 0) >= 200, "recipes written and read back: " .. tostring(n.recipes))
                T.truthy((n.neverCast or 0) >= 5, "pieces you never cast: " .. tostring(n.neverCast))
                if variant == "bars" then
                    T.eq(n.rings, 0, "an aura bar holder gets no ring")
                else
                    T.truthy((n.rings or 0) >= 20, "rings in the client's buttons: " .. tostring(n.rings))
                end
                -- A talent's proc is the game's item to draw while its buff rows show, and
                -- a group buff or weapon enchant is no proc of yours, so only hidden has
                -- one. A spell added by ID that you never cast is Daylight UI's own piece.
                if variant == "hidden" then
                    T.truthy((n.procs or 0) >= 1, "talent procs EZ-CDM draws: " .. tostring(n.procs))
                else
                    T.eq(n.procs, nil, "no talent proc EZ-CDM draws while the game's items draw procs")
                end
            end)
        end
    end
    for _, k in ipairs(SW.KNOWN) do
        local here = k.classes == nil
        for _, cl in ipairs(k.classes or {}) do
            for _, name in ipairs(SW.GROUPS[group]) do here = here or cl == name end
        end
        if here then
            T.test("sweep known rule still seen: " .. k.name, function()
                T.truthy(seenRule[k], "nothing in group " .. group .. " fails this way any more, so take it out of SW.KNOWN")
            end)
        end
    end
end

return SW
