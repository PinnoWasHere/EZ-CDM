local _, ns = ...

-- Sentences to Daylight UI's CDM fields and back. Pure: it reads plain tables and
-- Daylight UI's answers through ns.Bridge read calls, and never writes a layout.
--
-- A line is { moment = ..., action = ..., value = ... }; a glow line may add
-- style, its own glow style. A spell's rules are
-- { lines = { ... }, group = { combat = true, where = "instance", ... },
--   forms = { "Bear", ... }, shows = "both" | "cooldown" | "buff", style = "comet" }.
-- shows is the card's What it shows, nil while the piece has no pick saved; style
-- is the glow style of the spell's glows with none of their own, nil for Daylight
-- UI's default.
-- Fields are a piece's spell options, with its group's options under fields.chain
-- and its own look keys under fields.look.

local Bridge, Effects = ns.Bridge, ns.Effects

local Grammar = {}
ns.Grammar = Grammar

-- Debug handle for an in-game check.
EZCDM_Grammar = Grammar

Grammar.MOMENTS = { "always", "ready", "cooldown", "almost", "unusable", "short", "usable", "up", "ends", "missing", "recast" }
Grammar.ACTIONS = { "show", "fade", "hide", "glow", "gray", "color", "sound", "nosweep", "nogcd", "tint", "flash", "numbers" }
-- What it shows, in the card's order (CdmCard.lua:621-627). Daylight UI's own piece
-- saves "aura" for "buff" (CdmCard.lua:341-351).
Grammar.SHOWS = { "both", "cooldown", "buff" }
-- Group words in their canonical order: true turns one on, and where takes
-- "instance" or "world". false and "any" are Daylight UI's defaults. keep is the
-- group's Slide over turned off (chain collapse = false, CdmCard.lua:709-710).
Grammar.GROUP = { "combat", "target", "group", "mounted", "where", "keep" }
Grammar.WHERE = { "instance", "world" }
-- Each group word's chain field, where it isn't the word itself, and the chain
-- fields in word order.
Grammar.GROUP_FIELD = { keep = "collapse" }
Grammar.CHAIN = {}
for i, word in ipairs(Grammar.GROUP) do Grammar.CHAIN[i] = Grammar.GROUP_FIELD[word] or word end

-- A group word's value as its chain field's, and back.
local function toChain(word, v)
    if word == "keep" then return not v end
    return v
end
local function fromChain(word, v)
    if word == "keep" then return v == false end
    return v
end

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
--   paint          the line's value is that color field, alpha kept (nil = the accent)
--   look           a look key set true (fields.look); lookColor takes the line's value,
--                  at the line's seconds (line.at)
--   slot           lines sharing a slot set one choice (CdmCard.lua:313-333, Buff missing)
--   all            "always show": every show rule
--   lead           the line's seconds (line.at) are EZ-CDM's fall-off lead (ezLead),
--                  one per piece (Effects)
--   style          a glow line: its own style (line.style) is EZ-CDM's, by moment
--                  (ezStyles, Effects)
local MAP = {
    always = { show = { all = SHOW_RULES, value = "show" } },
    ready = showRule("onReady"),
    cooldown = showRule("onCd"),
    unusable = showRule("onUnusable"),
    short = showRule("onShort"),
    usable = {
        glow = { field = "usableGlow", value = true, color = "usableGlowColor", style = true },
        sound = { field = "usableSound", sound = true },
    },
    up = {
        show = { field = "hideActive", value = false },
        hide = { field = "hideActive", value = true },
        glow = { field = "upGlow", value = true, color = "upGlowColor", style = true },
        sound = { field = "buffSound", sound = true },
        -- The sweep while the buff is up: off (Look tab, CdmCard.lua:505-506), or its
        -- color (Highlight color, CdmCard.lua:686-688).
        nosweep = { field = "noDurationSwipe", value = true },
        tint = { paint = "activeColor" },
    },
    ends = { sound = { field = "buffEndSound", sound = true } },
    missing = {
        show = { field = "missing", value = true, slot = "buffDown" },
        hide = { field = "hideMissing", value = true, slot = "buffDown" },
        glow = { field = "missingGlow", value = true, color = "missingGlowColor", style = true },
        -- The empty bar pulses (CdmCard.lua:698-700). It needs "show it" here too.
        flash = { field = "inactiveFlash", value = true },
    },
    -- The glow is Daylight UI's; the lead and the sound are EZ-CDM's (Effects).
    recast = {
        glow = { field = "clipGlow", value = true, color = "clipGlowColor", lead = true, style = true },
        sound = { field = "ezSound", sound = true, lead = true },
    },
}
MAP.ready.glow = { field = "readyGlow", value = true, color = "readyGlowColor", style = true }
MAP.ready.sound = { field = "readySound", sound = true }
-- desat tracks cooldown state only (CdmEffects.lua:1099-1108), so gray goes with
-- cooldown alone.
MAP.cooldown.gray = { field = "desat", value = "grey" }
MAP.cooldown.color = { field = "desat", value = "color" }
-- The cooldown's sweep: off, or off only for the global cooldown (CdmCard.lua:497-501).
MAP.cooldown.nosweep = { field = "noSwipe", value = true }
MAP.cooldown.nogcd = { field = "noGcd", value = true }
-- The numbers' color for the cooldown's last seconds (CdmCard.lua:513-520).
MAP.almost = { numbers = { look = "low", lookColor = "lowColor", at = "lowAt" } }
Grammar.MAP = MAP

-- Every spell field the grammar writes, so a caller can clear the ones a draft drops.
Grammar.FIELDS = {
    "onReady", "onCd", "onUnusable", "onShort", "cdAlpha", "desat",
    "readyGlow", "readyGlowColor", "usableGlow", "usableGlowColor", "upGlow", "upGlowColor",
    "missingGlow", "missingGlowColor", "clipGlow", "clipGlowColor",
    "readySound", "usableSound", "buffSound", "buffEndSound",
    "hideActive", "missing", "hideMissing",
    "noDurationSwipe", "activeColor", "inactiveFlash", "noSwipe", "noGcd", "glowStyle",
}
-- Every look key the grammar writes (fields.look), through Data.SetLook.
Grammar.LOOK_FIELDS = { "low", "lowAt", "lowColor" }
-- The fields EZ-CDM keeps itself (Effects.SplitFallOff, Effects.SplitStyles),
-- never Daylight UI's.
Grammar.EZ_FIELDS = { "ezLead", "ezSound", "ezStyles" }
-- The fall-off lead's choices, in seconds.
Grammar.LEADS = { 2, 3, 4, 5, 8, 10 }
-- A proc's fall-off ring needs a lead; a new line there starts with this one.
Grammar.PROC_LEAD = 5

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

-- A color with its alpha, when it has one.
local function copyColor(c)
    local out = copyRGB(c)
    if type(c[4]) == "number" then out[4] = c[4] end
    return out
end

local function sameRGB(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end

-- A glow style the card's Style row offers.
local function styleKnown(key)
    for _, st in ipairs(Bridge.GlowStyles() or {}) do
        if st.key == key then return true end
    end
    return false
end

-- A fall-off lead: whole seconds, 1 to the longest choice.
local function isLead(n)
    return type(n) == "number" and n >= 1 and n <= Grammar.LEADS[#Grammar.LEADS] and n % 1 == 0
end

local function isColor(c)
    return isRGB(c) and (c[4] == nil or (type(c[4]) == "number" and c[4] >= 0 and c[4] <= 1))
end

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

-- A game answer, or nil when it is secret.
local function plain(v)
    if type(issecretvalue) == "function" and issecretvalue(v) then return nil end
    return v
end

-- Whether the player casts spell id: false for a passive spell or one the player
-- doesn't have, true for one the player has, nil when the game won't say. This is
-- the one place the recast signal lives. On Forever, Improved Stormstrike's talent
-- (1223031) is known and passive, and its buff (1238931) is not passive.
function Grammar.Casts(id)
    local S = type(C_Spell) == "table" and C_Spell or {}
    if type(S.IsSpellPassive) == "function" and plain(S.IsSpellPassive(id)) == true then return false end
    if type(IsPlayerSpell) ~= "function" then return nil end
    local known = plain(IsPlayerSpell(id))
    if known == nil then return nil end
    return known == true
end

-- The class spells that put up any of auraIds under another id, from the client's
-- own spell tables (AuraLinks.lua): Clearcasting 12536 gives Arcane Concentration
-- 11213. auraIds is an id, a list of ids or a set { [id] = true }. Returns the
-- sources in id order, or nil when the table names none.
function Grammar.ProcSource(auraIds)
    local byAura = type(ns.AuraLinks) == "table" and ns.AuraLinks.byAura
    if type(byAura) ~= "table" then return nil end
    local seen, out = {}, {}
    local function add(id)
        for _, s in ipairs(byAura[id] or {}) do
            if not seen[s] then seen[s] = true; out[#out + 1] = s end
        end
    end
    if type(auraIds) == "number" then add(auraIds) end
    for k, v in pairs(type(auraIds) == "table" and auraIds or {}) do
        if type(v) == "number" then add(v) elseif v == true then add(k) end
    end
    if #out == 0 then return nil end
    table.sort(out)
    return out
end

-- Whether a piece is your own proc by the aura links. Its ids give links both
-- ways: an aura of the piece another spell puts up (Clearcasting <- Arcane
-- Concentration), or the piece's own spell putting up an aura under another id
-- (Improved Stormstrike -> 1238931, the game's entry naming the talent). With a
-- spell you know on one of them: true, with that spell, when it procs the aura
-- (Arcane Concentration, Aspect of the Hawk's Quick Shots) and you cast none of
-- the piece's ids; false when it only puts the aura up as its cast (Moonkin Form's
-- Moonkin Aura). nil when the links name no spell you know.
local function linkedProc(key, cast)
    local links = ns.AuraLinks
    if type(links) ~= "table" or type(links.byAura) ~= "table" or type(links.bySource) ~= "table"
        or type(IsPlayerSpell) ~= "function" then
        return nil
    end
    local ids, held = {}, Bridge.SpellIDs(key)
    for id in pairs(type(held) == "table" and held or {}) do ids[#ids + 1] = id end
    local sid = Bridge.SpellOf(key)
    if type(sid) == "number" and not (type(held) == "table" and held[sid]) then ids[#ids + 1] = sid end
    table.sort(ids)
    local onCast = type(links.onCast) == "table" and links.onCast or {}
    local function castOnly(source, aura)
        for _, s in ipairs(onCast[aura] or {}) do
            if s == source then return true end
        end
        return false
    end
    local known, proc
    local function weigh(source, aura)
        if plain(IsPlayerSpell(source)) ~= true then return end
        known = true
        if proc == nil and not castOnly(source, aura) then proc = source end
    end
    for _, id in ipairs(ids) do
        for _, s in ipairs(Grammar.ProcSource(id) or {}) do weigh(s, id) end
        for _, a in ipairs(links.bySource[id] or {}) do weigh(id, a) end
    end
    if not known then return nil end
    if cast or proc == nil then return false end
    return true, proc
end

-- Whether a piece's recast moment can ever fire: the clock starts only on a cast of
-- one of its own ids (CdmAuras.lua:1194-1211), so a piece whose every id is passive
-- or not the player's never gets one. A weapon enchant has no spell at all.
-- Daylight UI's card offers the row on any spell (CdmCard.lua:413-415).
local function castable(key)
    if Bridge.SpellOf(key) == nil then return false end
    local ids = Bridge.SpellIDs(key)
    if type(ids) ~= "table" or next(ids) == nil then return true end
    for id in pairs(ids) do
        if Grammar.Casts(id) ~= false then return true end
    end
    return false
end

-- Whether a piece's spell, or any aura id it holds, is cast on an enemy: true,
-- false, or nil when it has no spell or the game won't say. Daylight UI holds a
-- debuff such as Polymorph under ids beyond the spell, so each id is asked.
local function harmful(key)
    local sid = Bridge.SpellOf(key)
    local S = type(C_Spell) == "table" and C_Spell or {}
    if sid == nil or type(S.IsSpellHarmful) ~= "function" then return nil end
    local ids, held = { sid }, Bridge.SpellIDs(key)
    for id in pairs(type(held) == "table" and held or {}) do
        if id ~= sid then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local answered
    for _, id in ipairs(ids) do
        local v = plain(S.IsSpellHarmful(id))
        if v == true then return true end
        if v ~= nil then answered = true end
    end
    if not answered then return nil end
    return false
end

-- Whether a piece's aura never falls off: true when its spell and every id it holds
-- are untimed auras by the client's tables (AuraLinks.untimed), as Ghost Wolf,
-- Shadowform and Moonkin Aura. nil when any of them is timed or not in the table.
local function untimed(key)
    local set = type(ns.AuraLinks) == "table" and ns.AuraLinks.untimed
    local sid = Bridge.SpellOf(key)
    if type(set) ~= "table" or sid == nil or not set[sid] then return nil end
    local held = Bridge.SpellIDs(key)
    for id in pairs(type(held) == "table" and held or {}) do
        if not set[id] then return nil end
    end
    return true
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
--   cast             CdmCard.lua:413-415, less a spell never cast (castable)
--   trackRow         What it shows: "game" (gameSpell, CdmCard.lua:253-256) or "own"
--                    (canTrack, :337-340); nil for a totem, which has rows of its own
--   highlight        the buff's sweep is on (activeGlow, CdmCard.lua:686)
--   missingShown     Buff missing is set to Show (the Flash row, CdmCard.lua:698)
--   ezGlow           EZ-CDM draws its up glow inside the client's button (Effects),
--                    which needs no told state
--   procLasts        a proc's length in seconds (Effects.ProcLasts): one EZ-CDM
--                    draws, nil when no one knows it. Only your own procs: put up
--                    by a talent you have (aura links), else a buff you never
--                    cast; never a weapon enchant (no spell) or another class's
--                    buff (groupBuff)
--   procSource       the talent that puts the proc up, by the aura links
--                    (Grammar.ProcSource); nil when they name none
--   procLead         EZ-CDM draws its fall-off glow inside the client's button too:
--                    such a proc with a known length (Effects)
--   drawnBy          what draws it since the last pass (Bridge.DrawnBy), or nil
--   harmful          its spell is cast on an enemy, so its aura is a debuff on the
--                    target (C_Spell.IsSpellHarmful); nil when the game won't say
--   groupBuff        another class's buff on you, the tray's Group buffs
--                    (CdmCustom.IsGroup)
--   untimed          its aura never falls off (AuraLinks.untimed: Ghost Wolf,
--                    Shadowform); nil when any id is timed or unknown
-- Form rows show for cooldowns of a class with forms (CdmCard.lua:806).
-- Totems take no case of their own. Bridge.Shows (CdmOwn.Track) says "totem" for a
-- totem with no buff and "both" for a Shaman element piece (CdmOwn.lua:108-130), and
-- the card reads that same answer. test_grammar checks Words against the card's rows.
-- shows, when given, is a What it shows pick not saved yet: the piece reads as the
-- card would after that pick, Buff missing cleared for any pick but "buff"
-- (CdmCard.lua:369-374).
function Grammar.Kind(key, piece, shows)
    local layout = Bridge.Layout()
    local pieces = type(layout) == "table" and type(layout.pieces) == "table" and layout.pieces or {}
    if piece == nil then piece = pieces[key] end
    local custom = Bridge.IsCustom(key)
    if shows ~= nil and not custom then
        local p = {}
        for k, v in pairs(type(piece) == "table" and piece or {}) do p[k] = v end
        p.track = shows
        if shows ~= "buff" then p.missing, p.hideMissing = nil, nil end
        piece = p
    end
    local known = Bridge.Entry(key)
    local aura = known and known.aura
    local now = Bridge.Shows(key, piece)
    -- Daylight UI's own piece reads its pick from the saved layout (CdmCustom.Track).
    if shows ~= nil and custom then
        now = shows == "both" and "both" or nil
        aura = shows == "buff"
    end
    local cooldown
    if now then
        cooldown = now ~= "buff"
    else
        cooldown = not aura
    end
    local hasBuff = now ~= "totem" and (now ~= nil or not cooldown)
    local trackRow
    if not Bridge.IsTotem(key) then
        if not custom and known ~= nil then trackRow = "game"
        elseif Bridge.CanTrack(key) then trackRow = "own" end
    end
    local kind = {
        key = key,
        shape = type(piece) == "table" and piece.shape == "bar" and "bar" or "icon",
        custom = custom,
        shows = now,
        cooldown = cooldown,
        buff = hasBuff,
        buffOnly = hasBuff and not cooldown,
        showsBuff = hasBuff and now ~= "cooldown",
        tracked = Bridge.Tracked(key) ~= false,
        cast = castable(key),
        trackRow = trackRow,
        highlight = Bridge.Option(piece, "activeGlow") ~= false,
        missingShown = Bridge.Option(piece, "missing") == true,
        numbers = Bridge.PieceLook(key, "cdNumbers") ~= false,
        ezGlow = Effects.Drawn(key),
        drawnBy = Bridge.DrawnBy(key),
        harmful = harmful(key),
        groupBuff = Bridge.IsGroup(key),
        untimed = untimed(key),
    }
    -- A proc is your own: a buff with a spell (a weapon enchant has none, so the card
    -- hides its recast row, CdmCard.lua:411-415) that no other class puts on you. The
    -- aura links decide where they name a spell you know; elsewhere, any buff you
    -- never cast.
    -- A debuff on the target is never your proc, whichever rule would say so.
    if kind.ezGlow and hasBuff and Bridge.SpellOf(key) ~= nil and not kind.groupBuff
        and kind.harmful ~= true then
        local own, source = linkedProc(key, kind.cast)
        if own == nil then own = not kind.cast end
        if own then
            kind.procLasts = Effects.ProcLasts(key)
            kind.procSource = source
        end
    end
    kind.procLead = kind.procLasts ~= nil
    -- What the card's What it shows reads now (CdmCard.lua:358-365), in the grammar's words.
    if trackRow then
        kind.showing = (now == "both" or now == "cooldown" or now == "buff") and now
            or (aura and "buff" or "cooldown")
    end
    local forms = cooldown and (Bridge.Forms() or {})[Bridge.MyClass() or ""]
    if forms then
        kind.forms = {}
        for i, f in ipairs(forms) do kind.forms[i] = f.key end
    end
    return kind
end

-- Whether a glow moment's glow is always EZ-CDM's combat ring on a piece, so it
-- takes no style: "While it's active" where EZ-CDM draws the up glow.
function Grammar.RingOnly(kind, moment)
    if type(kind) ~= "table" then return false end
    if moment == "up" then return kind.ezGlow == true end
    if moment == "recast" then return kind.procLead == true end
    return false
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
        -- Gray out and the sweep are icon rows (CdmCard.lua:497-501, 648).
        if action == "gray" or action == "color" or action == "nosweep" or action == "nogcd" then
            return kind.cooldown and kind.shape == "icon"
        end
        return kind.cooldown
    elseif moment == "almost" then
        -- The card offers this on any icon with numbers (CdmCard.lua:513-515), but it
        -- only colors a spell cooldown's numbers (Cooldowns.lua:336-350), so a buff
        -- alone doesn't take it.
        return kind.cooldown and kind.shape == "icon" and kind.numbers
    elseif moment == "up" then
        if action == "show" or action == "hide" then return kind.buff and told end
        -- The sweep rows need no told state (CdmCard.lua:505, 683-688).
        if action == "nosweep" then return kind.shape == "icon" and kind.buff end
        if action == "tint" then return kind.shape == "icon" and kind.buff and kind.highlight end
        if action == "glow" then return kind.showsBuff and (told or kind.ezGlow == true) end
        return kind.showsBuff and told
    elseif moment == "ends" then
        -- An aura with no timer is on or off; it never wears off.
        if kind.untimed then return false end
        return kind.showsBuff and told
    elseif moment == "missing" then
        -- The card shows this glow on a Buff only piece once something shows while the
        -- buff is down (CdmCard.lua:276-285, 693). A missing glow keeps the icon itself,
        -- so it's offered there too; Hide (Buff missing) makes it a "hidden" problem.
        if action == "glow" then return kind.buff and told end
        -- Flash is a bar row, once Buff missing shows (CdmCard.lua:698-700).
        if action == "flash" then return kind.shape == "bar" and kind.buffOnly and kind.missingShown end
        return kind.buffOnly
    elseif moment == "recast" then
        -- An aura that never falls off has no moment before it does.
        if kind.untimed then return false end
        -- A proc EZ-CDM draws takes the glow as its own ring, timed from its length.
        -- The lead must fit inside that length, so the proc outlasts the shortest one.
        if action == "glow" and kind.procLead == true then
            return type(kind.procLasts) == "number" and kind.procLasts > Grammar.LEADS[1]
        end
        return kind.showsBuff and kind.cast
    end
    return false
end

-- Whole-spell words, each a sentence of its own: shows is What it shows, style the
-- glow style (CdmCard.lua:490-495), which every piece takes.
Grammar.EXTRAS = { "shows", "style" }

-- The whole-spell words that fit a piece, in Grammar.EXTRAS order.
function Grammar.Extras(kind)
    local out = {}
    for _, e in ipairs(Grammar.EXTRAS) do
        if e ~= "shows" or kind == nil or kind.trackRow then out[#out + 1] = e end
    end
    return out
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
-- light (CdmEffects.lua:491-500). With no sweep while the buff is up, its color has
-- nothing to color, and the card hides that row (CdmCard.lua:686-688).
local HIDDEN_BY = {
    { glow = "upGlow", hide = "hideActive" },
    { glow = "missingGlow", hide = "hideMissing" },
    { glow = "clipGlow", hide = "hideActive" },
    { glow = "activeColor", hide = "noDurationSwipe" },
    { glow = "noGcd", hide = "noSwipe" },
}

-- Group and form words into fields.chain and hideIn<Key>.
local function compileGroup(rules, kind, fields, problem)
    local chain = {}
    fields.chain = chain
    local group = type(rules.group) == "table" and rules.group or {}
    for i, word in ipairs(Grammar.GROUP) do
        local v = group[word]
        if v ~= nil then
            local ok
            if word == "where" then ok = v == "any" or indexOf(Grammar.WHERE, v) ~= nil
            else ok = type(v) == "boolean" end
            if ok then chain[Grammar.CHAIN[i]] = toChain(word, v) else problem({ group = word, code = "value" }) end
        end
    end
    local unknown = {}
    for word in pairs(group) do
        if not indexOf(Grammar.GROUP, word) then unknown[#unknown + 1] = tostring(word) end
    end
    table.sort(unknown)
    for _, word in ipairs(unknown) do problem({ group = word, code = "pair" }) end
    for _, f in ipairs(Grammar.CHAIN) do
        if chain[f] == Bridge.ChainDefault(f) then chain[f] = nil end
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
-- { form = key } / { shows = pick }. Codes:
--   "blank"   a line with its moment or action not picked yet
--   "pair"    no such moment and action
--   "kind"    the piece doesn't take it (Grammar.Fits)
--   "value"   a bad color, sound, fade amount or group value
--   "twice"   an earlier line set the same thing; the later line wins
--   "hidden"  a glow that a hide line keeps from showing
--   "needs"   "flash it" with no "show it" while it's not active (CdmCard.lua:698)
-- A bad glow style is { style = key, code = "value" }.
-- flags:
--   keepBuffOnly   "missing show" needs the piece kept Buff only: the card sets track
--                  to buff (or aura for Daylight UI's own piece) with it (CdmCard.lua:326-329)
function Grammar.Compile(rules, kind)
    rules = type(rules) == "table" and rules or {}
    local fields, problems, flags = {}, {}, {}
    local look = {}
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
    -- "Flash it" fits once Buff missing shows, and a "show it" line here counts.
    local flashKind = kind
    for _, line in ipairs(rules.lines or {}) do
        if kind and type(line) == "table" and line.moment == "missing" and line.action == "show" then
            flashKind = setmetatable({ missingShown = true }, { __index = kind })
        end
    end
    for i, line in ipairs(rules.lines or {}) do
        local entry = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
        if type(line) == "table" and (line.moment == nil or line.action == nil) then
            problem({ line = i, code = "blank" })
        elseif not entry then
            problem({ line = i, code = "pair" })
        elseif not Grammar.Fits(line.action == "flash" and flashKind or kind, line.moment, line.action) then
            problem({ line = i, code = "kind" })
        elseif entry.all then
            always = entry
        elseif entry.color and line.value ~= nil and not isRGB(line.value) then
            problem({ line = i, code = "value" })
        elseif entry.paint and line.value ~= nil and not isColor(line.value) then
            problem({ line = i, code = "value" })
        elseif entry.look and ((line.value ~= nil and not isRGB(line.value)) or (line.at ~= nil
            and not (type(line.at) == "number" and line.at >= 1 and line.at <= 10 and line.at % 1 == 0))) then
            problem({ line = i, code = "value" })
        elseif entry.sound and not isSound(line.value) then
            problem({ line = i, code = "value" })
        elseif entry.lead and line.at ~= nil and not isLead(line.at) then
            problem({ line = i, code = "value" })
        elseif entry.lead and line.action == "glow" and kind and kind.procLead
            and (line.at == nil or line.at >= kind.procLasts) then
            -- A proc's ring has no Daylight UI timing: it needs a lead inside its length.
            problem({ line = i, code = "value" })
        elseif line.style ~= nil and not (entry.style and styleKnown(line.style)) then
            problem({ line = i, code = "value" })
        elseif line.style ~= nil and Grammar.RingOnly(kind, line.moment) then
            problem({ line = i, code = "kind" })
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
            if entry.paint then
                set(i, entry.paint, line.value ~= nil and copyColor(line.value) or nil)
            elseif entry.look then
                if setBy[entry.look] then problem({ line = setBy[entry.look], code = "twice" }) end
                setBy[entry.look] = i
                look[entry.look] = true
                look[entry.lookColor] = line.value and copyRGB(line.value) or nil
                look[entry.at] = line.at
            else
                set(i, entry.field, entry.sound and line.value or entry.value)
            end
            if entry.color then
                fields[entry.color] = line.value and copyRGB(line.value) or nil
            end
            if entry.alpha and line.value ~= nil then set(i, "cdAlpha", line.value) end
            if entry.lead and line.at ~= nil then set(i, "ezLead", line.at) end
            if entry.style and line.style ~= nil then
                fields.ezStyles = fields.ezStyles or {}
                fields.ezStyles[line.moment] = line.style
            end
        end
    end
    -- "always show" sets every show rule no line names.
    if always then
        for _, f in ipairs(always.all) do
            if not setBy[f] then fields[f] = always.value end
        end
    end
    for _, h in ipairs(HIDDEN_BY) do
        if setBy[h.glow] and fields[h.glow] ~= false and fields[h.hide] == true then
            problem({ line = setBy[h.glow], code = "hidden" })
            fields[h.glow], fields[h.glow .. "Color"] = nil, nil
        end
    end
    if fields.inactiveFlash == true and fields.missing ~= true then
        problem({ line = setBy.inactiveFlash, code = "needs" })
        fields.inactiveFlash = nil
    end
    if fields.missing == true then flags.keepBuffOnly = true end
    -- What it shows, in the piece's own words: "aura" for Daylight UI's own piece.
    local shows = rules.shows
    if shows ~= nil then
        if not indexOf(Grammar.SHOWS, shows) then
            problem({ shows = shows, code = "value" })
        elseif kind and not kind.trackRow then
            problem({ shows = shows, code = "kind" })
        else
            fields.track = kind and kind.trackRow == "own" and shows == "buff" and "aura" or shows
        end
    end
    -- The glow style, one for the whole spell.
    if rules.style ~= nil then
        if styleKnown(rules.style) then fields.glowStyle = rules.style
        else problem({ style = rules.style, code = "value" }) end
    end
    -- Values equal to Daylight UI's default are left out, as its setters do.
    for _, f in ipairs(Grammar.FIELDS) do
        if fields[f] ~= nil and fields[f] == spellDefault(f) then fields[f] = nil end
    end
    for _, f in ipairs(Grammar.LOOK_FIELDS) do
        local d = Bridge.LookDefault(f)
        if look[f] ~= nil and (look[f] == d or (isRGB(d) and isRGB(look[f]) and sameRGB(look[f], d))) then
            look[f] = nil
        end
    end
    if next(look) then fields.look = look end
    compileGroup(rules, kind, fields, problem)
    -- By line, group and form words last; ties keep the order they were found in.
    table.sort(problems, function(a, b)
        local la, lb = a.line or math.huge, b.line or math.huge
        if la ~= lb then return la < lb end
        return a.seq < b.seq
    end)
    for _, p in ipairs(problems) do p.seq = nil end
    return fields, problems, flags
end

-- Whether a finished line asks only for what Daylight UI does anyway ("Always show
-- it."): it fits kind and sets no field away from its default.
function Grammar.IsDefault(line, kind)
    if type(line) ~= "table" or line.moment == nil or line.action == nil then return false end
    local fields, problems = Grammar.Compile({ lines = { line } }, kind)
    if #problems > 0 then return false end
    for f in pairs(fields) do
        if f ~= "chain" then return false end
    end
    return next(fields.chain) == nil
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
                local v = entry.field and fields[entry.field]
                local line
                if entry.paint then
                    local c = fields[entry.paint]
                    if isColor(c) then line = { moment = m, action = a, value = copyColor(c) } end
                elseif entry.look then
                    local look = type(fields.look) == "table" and fields.look or {}
                    if look[entry.look] == true then
                        line = { moment = m, action = a }
                        local c, d = look[entry.lookColor], Bridge.LookDefault(entry.lookColor)
                        if isRGB(c) and not (isRGB(d) and sameRGB(c, d)) then line.value = copyRGB(c) end
                        local at = look[entry.at]
                        if type(at) == "number" and at ~= Bridge.LookDefault(entry.at) then line.at = at end
                    end
                elseif entry.sound then
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
                if line and entry.lead and isLead(fields.ezLead) then line.at = fields.ezLead end
                local styles = fields.ezStyles
                if line and entry.style and type(styles) == "table" and type(styles[m]) == "string" then
                    line.style = styles[m]
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
    for i, word in ipairs(Grammar.GROUP) do
        local f = Grammar.CHAIN[i]
        local v = chain[f]
        if v ~= nil and v ~= Bridge.ChainDefault(f) then group[word] = fromChain(word, v) end
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
    -- A saved What it shows pick, in the grammar's words. A totem's track is its own
    -- rows' (CdmCard.lua:379-389), so it makes no word.
    local shows = fields.track == "aura" and "buff" or fields.track
    if not indexOf(Grammar.SHOWS, shows) or (kind and not kind.trackRow) then shows = nil end
    local style = fields.glowStyle
    if style == spellDefault("glowStyle") then style = nil end
    return { lines = lines, group = group, forms = forms, shows = shows, style = style }, problems
end

-- ---------------------------------------------------------------------
-- Plain words
-- ---------------------------------------------------------------------

-- Every word the player reads, in one table (the spec's "Player wording"). Describe,
-- Draft's notes, the drawer and the start block all read it, so a sentence and its
-- chips say the same words. The keys stay the grammar's own.
--   moments   each moment as one phrase, a sentence's start; %s is the power name
--   noComma   moments the action follows with no comma ("Always show it.")
--   actions   the word for each action
--   group     each group word, on and off
--   where     each "where" value
--   form      hiding in a form; %s is the form's name
--   shows     each What it shows pick, a sentence of its own
Grammar.WORDING = {
    moments = {
        always = "Always",
        ready = "When it's ready",
        cooldown = "While it's cooling down",
        almost = "When it's almost ready",
        unusable = "When I can't cast it",
        short = "When I don't have enough %s",
        usable = "When it becomes castable",
        up = "While it's active",
        ends = "When it wears off",
        missing = "While it's not active",
        recast = "When it's about to fall off",
    },
    noComma = { always = true },
    actions = {
        show = "show it", fade = "make it see-through", hide = "hide it", glow = "glow",
        gray = "turn it gray", color = "keep its color", sound = "play a sound",
        nosweep = "hide the sweep", nogcd = "hide the global cooldown sweep", tint = "color the sweep",
        flash = "flash it", numbers = "color the numbers",
    },
    shows = { both = "show its buff and its cooldown", cooldown = "show its cooldown", buff = "show its buff" },
    group = {
        combat = { on = "only show it in combat", off = "in or out of combat" },
        target = { on = "only when I have a target", off = "with or without a target" },
        group = { on = "only in a group", off = "in a group or not" },
        mounted = { on = "hide it while mounted", off = "mounted or not" },
        keep = { on = "keep every spell in place when a buff drops", off = "slide the others over when a buff drops" },
    },
    where = { any = "anywhere", instance = "only in dungeons and raids", world = "only in the open world" },
    form = "hide it while I'm in %s",
    -- The one see-through amount a spell has (cdAlpha), as a percent.
    amount = "when see-through, show it at %s",
    -- A new line's blanks before a word is picked.
    chooseMoment = "choose a moment",
    chooseWhat = "choose what happens",
    accent = "the accent color",
    picked = "the color you picked",
    -- Notes on a write: %s is the line "flash it" needs; the spell and its color.
    needs = "needs \"%s\" too",
    sweepAccent = "%s: Daylight UI can't set the sweep back to the accent color, so it stays %s.",
    -- The drawer's strip heading for each kind of word.
    headings = {
        moment = "Choose a moment:", action = "Choose what happens:", color = "Choose a color:",
        sound = "Choose a sound:", fade = "Choose how much shows:", group = "Choose for the whole group:",
        form = "Choose a form:", shows = "Choose what it shows:", style = "Choose a glow style:",
        seconds = "Choose how many seconds:",
    },
    -- The glow style of the spell's glows with none of their own (%s is the style's
    -- name, the card's label).
    style = "Other glows use %s",
    -- A glow line's own style after "glow": "with a Comet" (%s is its name), or with
    -- none, "with the spell's style" (%s is pieceStyle).
    lineStyle = "with a %s",
    lineStyleNone = "with %s",
    pieceStyle = "the spell's style",
    -- The almost-ready numbers: their seconds, and Daylight UI's own color on its chip.
    lastSeconds = "for the last",
    seconds = { one = "%d second", other = "%d seconds" },
    daylightColor = "Daylight's color",
    -- Under a finished line that asks for what Daylight UI does anyway.
    default = "Daylight already does this.",
    -- Under "While it's active, glow" on a piece EZ-CDM draws that glow for, and
    -- while that glow waits for a /reload (Effects.Pending).
    ezGlow = "Ring style; drawn by EZ so it works in combat.",
    ezGlowReload = "It lights after your next /reload.",
    -- The fall-off lead after "When it's about to fall off" (%s is its seconds), and
    -- with no lead, when Daylight UI's own timing stands (%s is daylightTiming).
    lead = "(%s before)",
    leadNone = "(%s)",
    daylightTiming = "Daylight's timing",
    -- Under the first "When it's about to fall off" line: own on every piece, early
    -- where Daylight UI's aura holder draws it or EZ-CDM has a rule (a lead or a
    -- sound), target on a debuff you cast. On a proc EZ-CDM rings, ezGlow and proc
    -- instead, or procFrom when the aura links name the talent behind it (%s).
    fallOff = {
        own = "Counts from your own cast.",
        early = "In a fight it can't tell if it falls off early.",
        target = "One timer per spell, not per target.",
        proc = "Counts from when it lands; a new proc while it's up isn't seen.",
        procFrom = "Counts from when %s puts it up; a new proc while it's up isn't seen.",
    },
    -- In place of the glow style line on such a piece, and under it when another
    -- style is saved (%s is that style's name), which Daylight UI keeps for the rest.
    ezRingStyle = "Its combat glow is always a ring.",
    ezRingOther = "Its other glows still use %s.",
    -- Over the group words: every spell in the group (%s), or the spell alone.
    wholeGroup = "For its whole group: %s",
    thisSpell = "For this spell:",
    -- The drawer's add links.
    addLine = "+ add a line",
    addGroup = "+ a rule for its whole group",
    addForm = "+ hide it in a form …",
    -- The start block beside the editor's tray.
    start = {
        blank = "EZ-Start Blank", load = "EZ-Load Layout",
        name = "Name your layout", create = "Create", noName = "Give the layout a name first.",
    },
}
local WORDING = Grammar.WORDING

-- The player's power, as the game names it ("rage"), else "power".
function Grammar.PowerName()
    local token = type(UnitPowerType) == "function" and select(2, UnitPowerType("player"))
    local name = type(token) == "string" and _G[token]
    if type(name) == "string" and name ~= "" then return name:lower() end
    return "power"
end

-- A moment's phrase and what joins it to the action (", " or " "). A moment not
-- picked yet reads as its blank.
function Grammar.MomentWords(moment)
    if moment == nil then return WORDING.chooseMoment, ", " end
    local phrase = WORDING.moments[moment]
    if not phrase then return tostring(moment), " " end
    if phrase:find("%s", 1, true) then phrase = phrase:format(Grammar.PowerName()) end
    return phrase, WORDING.noComma[moment] and " " or ", "
end

-- A group word's words: on (true, or a "where" value) or off.
function Grammar.GroupWords(word, v)
    if word == "where" then return WORDING.where[v or "any"] or tostring(v) end
    local w = WORDING.group[word]
    if not w then return tostring(word) end
    return v and w.on or w.off
end

function Grammar.FormWords(name) return WORDING.form:format(name) end

-- A count of seconds in words: "1 second", "3 seconds".
function Grammar.Seconds(n)
    return (n == 1 and WORDING.seconds.one or WORDING.seconds.other):format(n)
end

-- The glow style line as a sentence: "Other glows use Comet."
function Grammar.StyleWords(label)
    local w = WORDING.style:format(label)
    return w:sub(1, 1):upper() .. w:sub(2) .. "."
end

-- What it shows as a sentence: "Show its buff."
function Grammar.ShowsWords(shows)
    local w = WORDING.shows[shows] or tostring(shows)
    return w:sub(1, 1):upper() .. w:sub(2) .. "."
end

local function percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

-- A sound key's name in Daylight UI's list, or the key.
local function soundName(key)
    local values = Bridge.SoundChoices()
    local name = type(values) == "table" and values[key]
    return type(name) == "string" and name or tostring(key)
end

-- A glow style key's name, the card's label, or the key.
local function styleName(key)
    for _, st in ipairs(Bridge.GlowStyles() or {}) do
        if st.key == key then return st.label end
    end
    return tostring(key)
end
Grammar.StyleName = styleName

local function actionWords(line)
    local a = line.action
    if a == nil then return WORDING.chooseWhat end
    if a == "glow" and line.style ~= nil then
        local out = WORDING.actions.glow .. " " .. WORDING.lineStyle:format(styleName(line.style))
        if line.value then out = out .. " in " .. WORDING.picked end
        return out
    end
    if a == "fade" and type(line.value) == "number" then
        return string.format("%s (%s visible)", WORDING.actions.fade, percent(line.value))
    end
    if (a == "glow" or a == "tint") and line.value then return WORDING.actions[a] .. " in " .. WORDING.picked end
    if a == "numbers" then
        local out = WORDING.actions.numbers
        if line.value then out = out .. " in " .. WORDING.picked end
        if line.at then out = out .. " " .. WORDING.lastSeconds .. " " .. Grammar.Seconds(line.at) end
        return out
    end
    if a == "sound" then return string.format("play \"%s\"", soundName(line.value)) end
    return WORDING.actions[a] or tostring(a)
end

-- The fall-off lead as words: "(5 seconds before)".
function Grammar.LeadWords(n) return WORDING.lead:format(Grammar.Seconds(n)) end

-- The line as one sentence, in US English.
function Grammar.Describe(line)
    if type(line) ~= "table" then return "" end
    local phrase, joint = Grammar.MomentWords(line.moment)
    local entry = MAP[line.moment] and MAP[line.moment][line.action]
    if entry and entry.lead and line.at ~= nil then phrase = phrase .. " " .. Grammar.LeadWords(line.at) end
    return phrase:sub(1, 1):upper() .. phrase:sub(2) .. joint .. actionWords(line) .. "."
end

-- Whether lines hold an EZ-CDM fall-off rule: a fall-off line with a lead or a sound.
local function fallOffRuled(lines)
    for _, line in ipairs(type(lines) == "table" and lines or {}) do
        if type(line) == "table" and line.moment == "recast" and (line.at ~= nil or line.action == "sound") then
            return true
        end
    end
    return false
end

-- The limit notes on a piece's fall-off moment, each { code, text }: own always,
-- early where Daylight UI's aura holder draws it or the piece's lines hold an
-- EZ-CDM rule (its clock is trusted over the game's "down"), target on a debuff
-- you cast on an enemy. A proc EZ-CDM rings gets ring and proc instead.
function Grammar.FallOffNotes(kind, lines)
    if type(kind) == "table" and kind.procLead == true then
        local S = type(C_Spell) == "table" and C_Spell or {}
        local name = kind.procSource and type(S.GetSpellName) == "function" and plain(S.GetSpellName(kind.procSource))
        local text = type(name) == "string" and name ~= "" and WORDING.fallOff.procFrom:format(name)
            or WORDING.fallOff.proc
        return { { code = "ring", text = WORDING.ezGlow }, { code = "proc", text = text } }
    end
    local out = { { code = "own", text = WORDING.fallOff.own } }
    local by = type(kind) == "table" and kind.drawnBy
    if (type(by) == "string" and by:find("^aura")) or fallOffRuled(lines) then
        out[#out + 1] = { code = "early", text = WORDING.fallOff.early }
    end
    if type(kind) == "table" and kind.harmful == true then
        out[#out + 1] = { code = "target", text = WORDING.fallOff.target }
    end
    return out
end

-- The glow a moment lights, in plain words: "the glow when it's ready".
local function glowName(moment)
    local phrase = Grammar.MomentWords(moment)
    return "the glow " .. phrase:sub(1, 1):lower() .. phrase:sub(2)
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
                        text = string.format("Only one glow shows at a time. When both apply, %s shows instead of %s.",
                            glowName(win), glowName(lose)) }
                end
            end
        end
    end
    return notes
end
