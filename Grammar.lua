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

local Bridge, Effects, Conditions = ns.Bridge, ns.Effects, ns.Conditions

local Grammar = {}
ns.Grammar = Grammar

-- Debug handle for an in-game check.
EZCDM_Grammar = Grammar

-- "blocked" is EZ-CDM's "When I can't cast it" (Conditions.lua), placed beside the
-- castable words.
Grammar.MOMENTS = { "always", "ready", "cooldown", "almost", "blocked", "unusable", "short", "usable", "up", "ends",
                    "missing", "recast" }
Grammar.ACTIONS = { "show", "fade", "hide", "glow", "gray", "color", "sound", "nosweep", "nogcd", "tint", "flash", "numbers" }
-- What it shows, in the card's order (CdmCard.lua:630-636). Daylight UI's own piece
-- saves "aura" for "buff" (CdmCard.lua:350-360).
Grammar.SHOWS = { "both", "cooldown", "buff" }
-- Group words in their canonical order: true turns one on, and where takes
-- "instance" or "world". false and "any" are Daylight UI's defaults. keep is the
-- group's Slide over turned off (chain collapse = false, CdmCard.lua:720-721).
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

-- moment -> action -> what it sets. Card rows: CdmCard.lua:637-709.
--   field, value   one spell option
--   alpha          the line's value is the fade amount (cdAlpha)
--   color          the line's value is the glow color (nil = the accent)
--   sound          the line's value is a Daylight UI sound key
--   paint          the line's value is that color field, alpha kept (nil = the accent)
--   look           a look key set true (fields.look); lookColor takes the line's value,
--                  at the line's seconds (line.at)
--   slot           lines sharing a slot set one choice (CdmCard.lua:322-342, Buff missing)
--   all            "always show": every show rule
--   lead           the line's seconds (line.at) are EZ-CDM's fall-off lead (ezLead),
--                  one per piece (Effects)
--   style          a glow line: its own style (line.style) is EZ-CDM's, by moment
--                  (ezStyles, Effects)
--   cond           an EZ-CDM condition's line (Conditions.Register, InstallCondition)
--   glow           an EZ-CDM glow line: the line's value is its color, its style its own
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
        -- The sweep while the buff is up: off (Look tab, CdmCard.lua:514-515), or its
        -- color (Highlight color, CdmCard.lua:695-697).
        nosweep = { field = "noDurationSwipe", value = true },
        tint = { paint = "activeColor" },
    },
    ends = { sound = { field = "buffEndSound", sound = true } },
    missing = {
        show = { field = "missing", value = true, slot = "buffDown" },
        hide = { field = "hideMissing", value = true, slot = "buffDown" },
        glow = { field = "missingGlow", value = true, color = "missingGlowColor", style = true },
        -- The empty bar pulses (CdmCard.lua:709-711). It needs "show it" here too.
        flash = { field = "inactiveFlash", value = true },
    },
    -- The glow is Daylight UI's; the lead and the sound are EZ-CDM's (Effects).
    recast = {
        glow = { field = "clipGlow", value = true, color = "clipGlowColor", lead = true, style = true },
        sound = { field = "ezSound", sound = true, lead = true },
    },
}
-- EZ-CDM's own moment; its lines come with its condition (InstallCondition).
MAP.blocked = {}
MAP.ready.glow = { field = "readyGlow", value = true, color = "readyGlowColor", style = true }
MAP.ready.sound = { field = "readySound", sound = true }
-- desat tracks cooldown state only (CdmEffects.lua:1133-1142), so gray goes with
-- cooldown alone.
MAP.cooldown.gray = { field = "desat", value = "grey" }
MAP.cooldown.color = { field = "desat", value = "color" }
-- The cooldown's sweep: off, or off only for the global cooldown (CdmCard.lua:506-510).
MAP.cooldown.nosweep = { field = "noSwipe", value = true }
MAP.cooldown.nogcd = { field = "noGcd", value = true }
-- The numbers' color for the cooldown's last seconds (CdmCard.lua:522-529).
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
-- The fields EZ-CDM keeps itself (Effects.SplitFallOff, Effects.SplitStyles,
-- Conditions.Split), never Daylight UI's. Each condition's fields join as it installs.
Grammar.EZ_FIELDS = { "ezLead", "ezSound", "ezStyles" }
-- The fall-off lead's choices, in seconds.
Grammar.LEADS = { 2, 3, 4, 5, 8, 10 }

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
-- spell you know on one of them: true when it procs the aura
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
    return true
end

-- Whether a piece's recast moment can ever fire: the clock starts only on a cast of
-- one of its own ids (CdmAuras.lua:1194-1211), so a piece whose every id is passive
-- or not the player's never gets one. A weapon enchant has no spell at all.
-- Daylight UI's card offers the row on any spell (CdmCard.lua:422-424).
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
--   isIcon / isBar   CdmCard.lua:236-237
--   isBuff           CdmCard.lua:245
--   isCooldown       CdmCard.lua:267-273
--   hasBuff          CdmCard.lua:275-278
--   buffOnly         CdmCard.lua:281
--   tellsState       CdmCard.lua:297-299
--   showsBuff        CdmCard.lua:416-419
--   cast             CdmCard.lua:422-424, less a spell never cast (castable)
--   trackRow         What it shows: "game" (gameSpell, CdmCard.lua:262-265) or "own"
--                    (canTrack, :337-340); nil for a totem, which has rows of its own
--   highlight        the buff's sweep is on (activeGlow, CdmCard.lua:695)
--   missingShown     Buff missing is set to Show (the Flash row, CdmCard.lua:709)
--   ezGlow           EZ-CDM draws its up glow inside the client's button (Effects),
--                    which needs no told state
--   proc             your own proc that EZ-CDM draws (ezGlow): put up by a talent
--                    you have (aura links), else a buff you never cast; never a
--                    weapon enchant (no spell), another class's buff (groupBuff) or
--                    a debuff on the target. Its aura can't be read in a fight, so
--                    it has no fall-off moment
--   drawnBy          what draws it since the last pass (Bridge.DrawnBy), or nil
--   harmful          its spell is cast on an enemy, so its aura is a debuff on the
--                    target (C_Spell.IsSpellHarmful); nil when the game won't say
--   groupBuff        another class's buff on you, the tray's Group buffs
--                    (CdmCustom.IsGroup)
--   untimed          its aura never falls off (AuraLinks.untimed: Ghost Wolf,
--                    Shadowform); nil when any id is timed or unknown
--   buffEvents       Daylight UI's buff moments time its fall-off: one came for it,
--                    or its state reads up or down (Effects.Covered)
--   button           a spell with no cooldown and no buff (Bridge.SpellButton): no
--                    cooldown or buff words, only the castable ones and EZ-CDM's
--   buttonHidden     a spell button Daylight UI shows as a buff, so never on show
-- Form rows show for cooldowns of a class with forms (CdmCard.lua:817).
-- Totems take no case of their own. Bridge.Shows (CdmOwn.Track) says "totem" for a
-- totem with no buff and "both" for a Shaman element piece (CdmOwn.lua:108-130), and
-- the card reads that same answer. test_grammar checks Words against the card's rows.
-- shows, when given, is a What it shows pick not saved yet: the piece reads as the
-- card would after that pick, Buff missing cleared for any pick but "buff"
-- (CdmCard.lua:378-383).
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
    -- A spell with neither a cooldown nor a buff: its castable words only.
    local button = Bridge.SpellButton(key) == true
    if button then cooldown, hasBuff = false, false end
    local trackRow
    if not Bridge.IsTotem(key) then
        if not custom and known ~= nil then trackRow = "game"
        elseif Bridge.CanTrack(key) then trackRow = "own" end
    end
    local kind = {
        key = key,
        button = button,
        -- Daylight UI shows it only while a buff is up, which a spell button never has.
        buttonHidden = button and aura == true or nil,
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
        buffEvents = Effects.Covered(key),
    }
    -- A proc is your own: a buff with a spell (a weapon enchant has none, so the card
    -- hides its recast row, CdmCard.lua:420-424) that no other class puts on you. The
    -- aura links decide where they name a spell you know; elsewhere, any buff you
    -- never cast.
    -- A debuff on the target is never your proc, whichever rule would say so.
    if kind.ezGlow and hasBuff and Bridge.SpellOf(key) ~= nil and not kind.groupBuff
        and kind.harmful ~= true then
        local own = linkedProc(key, kind.cast)
        if own == nil then own = not kind.cast end
        kind.proc = own == true
    end
    -- What the card's What it shows reads now (CdmCard.lua:367-374), in the grammar's words.
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
    return false
end

-- Whether a moment and action fit a piece, as the card offers them.
function Grammar.Fits(kind, moment, action)
    local entry = MAP[moment] and MAP[moment][action]
    if not entry then return false end
    if kind == nil then return true end
    local told = kind.tracked
    if entry.cond then
        return Conditions.Fits(entry.cond, action, kind)
    elseif moment == "always" or moment == "unusable" or moment == "short" or moment == "usable" then
        return kind.cooldown or kind.button == true
    elseif moment == "ready" then
        return kind.cooldown
    elseif moment == "cooldown" then
        -- Gray out and the sweep are icon rows (CdmCard.lua:506-510, 657).
        if action == "gray" or action == "color" or action == "nosweep" or action == "nogcd" then
            return kind.cooldown and kind.shape == "icon"
        end
        return kind.cooldown
    elseif moment == "almost" then
        -- The card offers this on any icon with numbers (CdmCard.lua:522-524), but it
        -- only colors a spell cooldown's numbers (Cooldowns.lua:336-350), so a buff
        -- alone doesn't take it.
        return kind.cooldown and kind.shape == "icon" and kind.numbers
    elseif moment == "up" then
        if action == "show" or action == "hide" then return kind.buff and told end
        -- The sweep rows need no told state (CdmCard.lua:514, 692-697).
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
        -- buff is down (CdmCard.lua:285-294, 704). A missing glow keeps the icon itself,
        -- so it's offered there too; Hide (Buff missing) makes it a "hidden" problem.
        if action == "glow" then return kind.buff and told end
        -- Flash is a bar row, once Buff missing shows (CdmCard.lua:709-711).
        if action == "flash" then return kind.shape == "bar" and kind.buffOnly and kind.missingShown end
        return kind.buffOnly
    elseif moment == "recast" then
        -- An aura that never falls off has no moment before it does, and nothing can
        -- time a proc EZ-CDM draws in a fight.
        if kind.untimed or kind.proc then return false end
        return kind.showsBuff and kind.cast
    end
    return false
end

-- Whole-spell words, each a sentence of its own: shows is What it shows, style the
-- glow style (CdmCard.lua:499-504), which every piece takes.
Grammar.EXTRAS = { "shows", "style" }

-- The whole-spell words that fit a piece, in Grammar.EXTRAS order.
function Grammar.Extras(kind)
    local out = {}
    for _, e in ipairs(Grammar.EXTRAS) do
        if e ~= "shows" or kind == nil or kind.trackRow then out[#out + 1] = e end
    end
    return out
end

-- Whether the drawer offers an EZ-CDM condition: never one that is unknown in a
-- fight, and an advanced one only with more.
local function offered(c, opts, asClause)
    if c.clauseOnly and not asClause then return false end
    if not (opts and opts.drawer) then return true end
    if c.secrecy == "outOfCombat" then return false end
    return not c.advanced or opts.more == true
end

-- The moments that fit a piece, each with its actions, in canonical order:
-- { { moment = "ready", actions = { "show", "fade", ... } }, ... }. opts.drawer
-- gives the drawer's view (offered); opts.more shows advanced conditions there.
function Grammar.Words(kind, opts)
    local out = {}
    for _, m in ipairs(Grammar.MOMENTS) do
        local actions = {}
        for _, a in ipairs(Grammar.ACTIONS) do
            local e = MAP[m] and MAP[m][a]
            local c = e and e.cond and Conditions.Get(e.cond)
            if Grammar.Fits(kind, m, a) and (not c or offered(c, opts)) then actions[#actions + 1] = a end
        end
        if #actions > 0 then out[#out + 1] = { moment = m, actions = actions } end
    end
    return out
end

-- The EZ-CDM condition a line starts with, or nil.
function Grammar.LineCondition(line)
    local e = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
    return e and e.cond or nil
end

-- The conditions a line may take as its next "and" clause, in registry order: an
-- EZ-CDM line whose parts are all plain so far, each condition once, fitting the
-- piece. A client one only where the line's effect is alpha-safe, and never on a
-- sound. opts as Grammar.Words.
-- The parts a line holds, in order, or nil when it can take no more (an unknown
-- part, or a client one).
local function partsSoFar(line)
    local ck = Grammar.LineCondition(line)
    if not ck or Conditions.Get(ck).secrecy == "client" then return nil end
    local parts = { ck }
    for _, cl in ipairs(type(line.clauses) == "table" and line.clauses or {}) do
        local c = type(cl) == "table" and Conditions.Get(cl.cond)
        if not c or c.secrecy == "client" then return nil end
        parts[#parts + 1] = cl.cond
    end
    return parts
end

-- The first part of parts that key can never be true with, or nil.
local function clashWith(key, parts)
    for _, p in ipairs(parts) do
        if Conditions.Excludes(key, p) then return p end
    end
end

-- Each condition the line could take next, and the part it clashes with (nil for
-- none).
local function nextParts(kind, line, opts)
    local out = {}
    local parts = partsSoFar(line)
    if not parts then return out end
    local used = {}
    for _, p in ipairs(parts) do used[p] = true end
    local safe = Conditions.ClientSafe(parts[1], line.action)
    for _, c in ipairs(Conditions.List()) do
        if not used[c.key] and offered(c, opts, true) and Conditions.FitsKind(c.key, kind)
            and (c.secrecy ~= "client" or safe) then
            out[#out + 1] = { cond = c.key, clash = clashWith(c.key, parts) }
        end
    end
    return out
end

-- Whether a line can take another "and" part at all: an EZ-CDM line with no client
-- part yet.
function Grammar.TakesClauses(line) return partsSoFar(line) ~= nil end

function Grammar.Clauses(kind, line, opts)
    local out = {}
    for _, p in ipairs(nextParts(kind, line, opts)) do
        if not p.clash then out[#out + 1] = p.cond end
    end
    return out
end

-- The conditions Clauses leaves out because they can never be true with a part the
-- line holds: { { cond, why } }, why as Grammar.NeverWords.
function Grammar.ClauseRefusals(kind, line, opts)
    local out = {}
    for _, p in ipairs(nextParts(kind, line, opts)) do
        if p.clash then out[#out + 1] = { cond = p.cond, why = Grammar.NeverWords(p.clash, p.cond) } end
    end
    return out
end

-- The EZ-CDM condition whose moment this is, or nil.
function Grammar.MomentCondition(moment)
    for _, e in pairs(MAP[moment] or {}) do
        if e.cond then return e.cond end
    end
end

-- A note on a line its piece can't show: { code, text, fixes }, or nil. fixes name
-- one-click repairs: "shows" (What it shows: its cooldown), "clause" (and its buff
-- isn't active).
--   button   a spell button Daylight UI shows only while a buff is up
--   buff     a cooldown line on a piece that shows its buff in its place
function Grammar.HiddenNote(kind, line)
    local W = Grammar.WORDING
    if type(kind) ~= "table" or type(line) ~= "table" then return nil end
    if kind.buttonHidden then
        return { code = "button", text = W.hiddenButton, fixes = kind.trackRow and { "shows" } or {} }
    end
    local ck = Grammar.LineCondition(line)
    if not ck or kind.shows ~= "both" then return nil end
    if Conditions.LineLayer(ck, { clauses = line.clauses }) ~= "cooldown" then return nil end
    for _, cl in ipairs(type(line.clauses) == "table" and line.clauses or {}) do
        if type(cl) == "table" and cl.cond == "noBuff" then return nil end
    end
    local fixes = {}
    if kind.trackRow then fixes[#fixes + 1] = "shows" end
    if Conditions.Get("noBuff") and Conditions.FitsKind("noBuff", kind) then fixes[#fixes + 1] = "clause" end
    return { code = "buff", text = W.hiddenByBuff, fixes = fixes }
end

-- ---------------------------------------------------------------------
-- Recipes: ready-made lines a click adds to a spell (docs/specs/recipes.md)
-- ---------------------------------------------------------------------

-- Each recipe is lines with no value, or group words. A glow takes the accent, a
-- sound RECIPE_SOUND, a fall-off line RECIPE_LEAD seconds.
Grammar.RECIPES = {
    { key = "readyAlert", lines = { { moment = "ready", action = "glow" }, { moment = "ready", action = "sound" } } },
    { key = "outOfWay", lines = { { moment = "cooldown", action = "hide" } } },
    { key = "dimCooling", lines = { { moment = "cooldown", action = "fade" } } },
    { key = "almostThere", lines = { { moment = "almost", action = "numbers" } } },
    { key = "nowUsable", lines = { { moment = "usable", action = "glow" } } },
    { key = "procPop", lines = { { moment = "up", action = "glow" } } },
    { key = "missingReminder", lines = { { moment = "missing", action = "glow" } } },
    { key = "refreshWarning", lines = { { moment = "recast", action = "glow" }, { moment = "recast", action = "sound" } } },
    { key = "endedPing", lines = { { moment = "ends", action = "sound" } } },
    { key = "fightOnly", group = { combat = true } },
}
Grammar.RECIPE_SOUND = "Proc"
Grammar.RECIPE_LEAD = 5

local function recipeOf(key)
    for _, r in ipairs(Grammar.RECIPES) do
        if r.key == key then return r end
    end
end

-- The sound named RECIPE_SOUND in Daylight UI's list, else its first sound.
local function recipeSound()
    local values, order = Bridge.SoundChoices()
    if type(values) ~= "table" then return nil end
    local first
    for _, k in ipairs(type(order) == "table" and order or {}) do
        if k ~= "none" and not tostring(k):find("^head:") then
            if values[k] == Grammar.RECIPE_SOUND then return k end
            first = first or k
        end
    end
    return first
end

-- A recipe's lines with their values, or nil for no such recipe.
function Grammar.RecipeLines(key)
    local r = recipeOf(key)
    if not r then return nil end
    local out = {}
    for i, l in ipairs(r.lines or {}) do
        local line = { moment = l.moment, action = l.action }
        if l.action == "sound" then line.value = recipeSound() end
        if MAP[l.moment][l.action].lead then line.at = Grammar.RECIPE_LEAD end
        out[i] = line
    end
    return out
end

-- The recipes that fit a piece, in Grammar.RECIPES order: every line fits. Group
-- words fit any piece.
function Grammar.Recipes(kind)
    local out = {}
    for _, r in ipairs(Grammar.RECIPES) do
        local fits = true
        for _, l in ipairs(r.lines or {}) do
            fits = fits and Grammar.Fits(kind, l.moment, l.action)
        end
        if fits then out[#out + 1] = r.key end
    end
    return out
end

-- ---------------------------------------------------------------------
-- EZ-CDM's conditions (Conditions.lua)
-- ---------------------------------------------------------------------

-- Whether a condition's moment and action are taken already.
function Grammar.ConditionClash(c)
    for a in pairs(c.actions) do
        if MAP[c.moment] and MAP[c.moment][a] then return true end
    end
    return false
end

-- A condition's words, into Grammar.WORDING unless set there already.
local function installWords(c)
    local W = Grammar.WORDING
    local words = type(c.words) == "table" and c.words or {}
    if not W then return end
    if type(words.moment) == "string" and W.moments[c.moment] == nil then W.moments[c.moment] = words.moment end
    if type(words.clause) == "string" and W.clauses[c.key] == nil then W.clauses[c.key] = words.clause end
    for other, why in pairs(type(words.never) == "table" and words.never or {}) do
        W.never[c.key] = W.never[c.key] or {}
        if W.never[c.key][other] == nil then W.never[c.key][other] = why end
    end
end

-- A condition's lines: its moment (a new one joins the end), each action as a
-- field of EZ-CDM's own, and its recipes after the one each names. A condition
-- that isn't client tier also gets a sound line where its moment has none.
function Grammar.InstallCondition(c)
    if not indexOf(Grammar.MOMENTS, c.moment) then Grammar.MOMENTS[#Grammar.MOMENTS + 1] = c.moment end
    MAP[c.moment] = MAP[c.moment] or {}
    if c.secrecy ~= "client" and not c.noSound and c.actions.sound == nil and MAP[c.moment].sound == nil then
        c.actions.sound = { effect = "sound" }
    end
    installWords(c)
    local actions = {}
    for a in pairs(c.actions) do actions[#actions + 1] = a end
    table.sort(actions)
    for _, a in ipairs(actions) do
        local field = Conditions.Field(c.key, a)
        local effect = c.actions[a].effect
        MAP[c.moment][a] = { field = field, value = true, cond = c.key, sound = effect == "sound" or nil,
                             glow = effect == "glow" or nil }
        if not indexOf(Grammar.ACTIONS, a) then Grammar.ACTIONS[#Grammar.ACTIONS + 1] = a end
        if not indexOf(Grammar.EZ_FIELDS, field) then Grammar.EZ_FIELDS[#Grammar.EZ_FIELDS + 1] = field end
    end
    for _, r in ipairs(c.recipes or {}) do
        if not recipeOf(r.key) and c.actions[r.action] then
            local at = #Grammar.RECIPES + 1
            for i, old in ipairs(Grammar.RECIPES) do
                if old.key == r.after then at = i + 1 end
                if old.key == "fightOnly" and at > i then at = i end
            end
            table.insert(Grammar.RECIPES, at, { key = r.key, lines = { { moment = c.moment, action = r.action } } })
        end
    end
end

for _, c in ipairs(Conditions.List()) do Grammar.InstallCondition(c) end

-- What a line sets, so two lines that set the same thing are one family: Buff
-- missing's show and hide share a slot, the show rules a field.
local function family(line)
    local e = MAP[line.moment] and MAP[line.moment][line.action]
    if not e then return nil end
    return line.moment .. ":" .. tostring(e.slot or e.field or e.paint or e.look or "all")
end

-- Adds recipe key's lines to rules. A finished line of the same moment and family is
-- replaced in place, never doubled; every fall-off line takes the recipe's lead,
-- which is one per piece. Returns rules.
function Grammar.ApplyRecipe(rules, key)
    if type(rules.lines) ~= "table" then rules.lines = {} end
    if type(rules.group) ~= "table" then rules.group = {} end
    if type(rules.forms) ~= "table" then rules.forms = {} end
    local r = recipeOf(key)
    if not r then return rules end
    local lead
    for _, line in ipairs(Grammar.RecipeLines(key)) do
        local fam, at = family(line), nil
        for i, old in ipairs(rules.lines) do
            if old.moment ~= nil and old.action ~= nil and family(old) == fam then
                at = i
                break
            end
        end
        if at then rules.lines[at] = line else rules.lines[#rules.lines + 1] = line end
        lead = lead or line.at
    end
    if lead then
        for _, l in ipairs(rules.lines) do
            if l.moment == "recast" then l.at = lead end
        end
    end
    for word, v in pairs(r.group or {}) do rules.group[word] = v end
    return rules
end

-- ---------------------------------------------------------------------
-- Compile
-- ---------------------------------------------------------------------

-- Hide (Buff up) and Hide (Buff missing) show nothing then, so these glows never
-- light (CdmEffects.lua:491-500). With no sweep while the buff is up, its color has
-- nothing to color, and the card hides that row (CdmCard.lua:695-697).
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

-- An EZ-CDM line's spec (Conditions.Spec) and its problem code, or nil and the code:
-- "pair" an unknown clause, "twice" a condition twice, "kind" a clause the piece
-- doesn't take, "value" a bad number, "order" a client part not last or twice,
-- "secret" a client part under an effect that isn't alpha-safe, "never" two parts
-- that can never both be true (Conditions.Excludes).
local function condSpec(line, entry, kind)
    local ck = entry.cond
    if line.n ~= nil and not Conditions.NumberFits(ck, line.n) then return nil, "value" end
    local clauses = line.clauses
    if clauses ~= nil and type(clauses) ~= "table" then return nil, "pair" end
    local seen, client, parts = { [ck] = true }, 0, { Conditions.Get(ck) }
    for _, cl in ipairs(clauses or {}) do
        local c = type(cl) == "table" and Conditions.Get(cl.cond)
        if not c then return nil, "pair" end
        if seen[cl.cond] then return nil, "twice" end
        seen[cl.cond] = true
        if kind and not Conditions.FitsKind(cl.cond, kind) then return nil, "kind" end
        if cl.n ~= nil and not Conditions.NumberFits(cl.cond, cl.n) then return nil, "value" end
        parts[#parts + 1] = c
    end
    for i = 1, #parts do
        for j = i + 1, #parts do
            if Conditions.Excludes(parts[i].key, parts[j].key) then return nil, "never" end
        end
    end
    for i, c in ipairs(parts) do
        if c.secrecy == "client" then
            client = client + 1
            if i ~= #parts or client > 1 then return nil, "order" end
            if not Conditions.ClientSafe(ck, line.action) then return nil, "secret" end
        end
    end
    local spec = Conditions.Spec(ck, line.action, { n = line.n, value = (entry.sound or entry.glow) and line.value or nil,
        style = entry.glow and line.style or nil, clauses = clauses })
    return spec
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
--   "needs"   "flash it" with no "show it" while it's not active (CdmCard.lua:709)
--   "never"   an EZ-CDM line with two parts that can never both be true
-- A bad glow style is { style = key, code = "value" }.
-- flags:
--   keepBuffOnly   "missing show" needs the piece kept Buff only: the card sets track
--                  to buff (or aura for Daylight UI's own piece) with it (CdmCard.lua:335-338)
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
        local spec, condCode
        if entry and entry.cond then spec, condCode = condSpec(line, entry, kind) end
        if type(line) == "table" and (line.moment == nil or line.action == nil) then
            problem({ line = i, code = "blank" })
        elseif not entry or (line.clauses ~= nil and not entry.cond) then
            problem({ line = i, code = "pair" })
        elseif line.n ~= nil and not entry.cond then
            problem({ line = i, code = "value" })
        elseif not Grammar.Fits(line.action == "flash" and flashKind or kind, line.moment, line.action) then
            problem({ line = i, code = "kind" })
        elseif entry.all then
            always = entry
        elseif (entry.color or entry.glow) and line.value ~= nil and not isRGB(line.value) then
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
        elseif line.style ~= nil and not ((entry.style or entry.glow) and styleKnown(line.style)) then
            problem({ line = i, code = "value" })
        elseif line.style ~= nil and Grammar.RingOnly(kind, line.moment) then
            problem({ line = i, code = "kind" })
        elseif entry.alpha and line.value ~= nil
            and not (type(line.value) == "number" and line.value >= 0 and line.value <= 1) then
            problem({ line = i, code = "value" })
        elseif condCode then
            problem({ line = i, code = condCode })
        elseif entry.cond then
            set(i, entry.field, spec)
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
                if entry.cond then
                    if v == true or type(v) == "table" then
                        line = { moment = m, action = a }
                        if type(v) == "table" then
                            line.n = v.n
                            if entry.sound then line.value = v.value end
                            if entry.glow then line.value, line.style = v.value, v.style end
                            if type(v.clauses) == "table" then
                                line.clauses = {}
                                for j, cl in ipairs(v.clauses) do line.clauses[j] = { cond = cl.cond, n = cl.n } end
                            end
                        end
                    end
                elseif entry.paint then
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
    -- rows' (CdmCard.lua:388-398), so it makes no word.
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
        unusable = "When it's not usable",
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
        gray = "turn it gray", blue = "tint it blue", color = "keep its color", sound = "play a sound",
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
    -- Each EZ-CDM condition as an "and" clause, after "and"; %s is the power name
    -- and # the condition's number.
    clauses = {},
    -- Why two conditions can never both be true: never[a][b], from the registry's
    -- words.never; %s is the power name. As words: neverBoth (%s is the why); in a
    -- clause strip, neverPart (the clause's words, then those words).
    never = {},
    neverBoth = "can't both be true: %s",
    neverPart = "Not \"%s\": %s.",
    layerClash = "can't both be true: one is about its cooldown, the other about its buff",
    -- Under a line its piece can't show (Grammar.HiddenNote), and the one-click fixes.
    hiddenByBuff = "Hidden while its buff shows.",
    hiddenButton = "Hidden: Daylight shows this spell only while a buff is up, and it has none.",
    fixShows = "Show its cooldown",
    fixClause = "Add \"and its buff isn't active\"",
    andWord = "and",
    -- The "and …" blank, a clause's strip chip that takes it out, and the strip's
    -- chip for advanced words (Settings "more").
    addClause = "and …",
    dropClause = "remove this part",
    more = "more…",
    fewer = "fewer",
    -- Under the number box: its range (%d to %d).
    range = "A whole number from %d to %d.",
    -- A new line's blanks before a word is picked.
    chooseMoment = "choose a moment",
    chooseWhat = "choose what happens",
    accent = "the accent color",
    picked = "the color you picked",
    -- Notes on a write: %s is the line "flash it" needs; the spell and its color.
    needs = "needs \"%s\" too",
    sweepAccent = "%s: Daylight UI can't set the sweep back to the accent color, so it stays %s.",
    -- Before Daylight UI 2.2.6 (API 1.15) only: the spell and its glow's color.
    glowAccent = "%s: Daylight UI can't set a glow back to the accent color, so it stays %s.",
    -- The drawer's strip heading for each kind of word.
    headings = {
        moment = "Choose a moment:", action = "Choose what happens:", color = "Choose a color:",
        sound = "Choose a sound:", fade = "Choose how much shows:", group = "Choose for the whole group:",
        form = "Choose a form:", shows = "Choose what it shows:", style = "Choose a glow style:",
        seconds = "Choose how many seconds:", recipe = "Choose a recipe:",
        clause = "Choose another condition:", number = "Type a number:",
    },
    -- Each recipe's name on its chip (Grammar.RECIPES).
    recipes = {
        readyAlert = "Ready alert", outOfWay = "Hidden", dimCooling = "Dim while cooling",
        canCast = "Can't cast", manaCheck = "Mana check", almostThere = "Almost there", nowUsable = "Now usable", procPop = "Proc pop",
        missingReminder = "Missing reminder", refreshWarning = "Refresh warning", endedPing = "Ended ping",
        fightOnly = "Fight only",
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
    -- while the client won't take that glow until a /reload (Effects.Pending).
    ezGlow = "Ring style; drawn by EZ so it works in combat.",
    ezGlowReload = "It lights after a /reload. EZ asks for one as the editor closes.",
    -- The question as the editor closes with such a glow waiting (Effects.AskReload),
    -- and its buttons where the game has no words of its own (RELOADUI, LATER).
    reloadAsk = "EZ-CDM: /reload to light the new glow.",
    reloadYes = "Reload",
    reloadLater = "Later",
    -- The fall-off lead after "When it's about to fall off" (%s is its seconds), and
    -- with no lead, when Daylight UI's own timing stands (%s is daylightTiming).
    lead = "(%s before)",
    leadNone = "(%s)",
    daylightTiming = "Daylight's timing",
    -- Under the first "When it's about to fall off" line: own on every piece, early
    -- where Daylight UI's aura holder draws it or EZ-CDM has a rule (a lead or a
    -- sound), target on a debuff you cast. lands in place of own and early where
    -- Daylight UI's buff moments time an EZ-CDM rule. hidden on a proc EZ-CDM draws
    -- (kind.proc), which has no fall-off moment.
    fallOff = {
        own = "Counts from your own cast.",
        lands = "Counts from when it lands, and stops if it falls off early.",
        early = "In a fight it can't tell if it falls off early.",
        target = "One timer per spell, not per target.",
        hidden = "The game hides this buff's timer in a fight, so EZ can't time its end.",
    },
    -- In place of the glow style line on such a piece, and under it when another
    -- style is saved (%s is that style's name), which Daylight UI keeps for the rest.
    ezRingOther = "Its other glows still use %s.",
    -- Over the group words: every spell in the group (%s), or the spell alone.
    wholeGroup = "For its whole group: %s",
    thisSpell = "For this spell:",
    -- The drawer's add links.
    addLine = "+ add a line",
    addGroup = "+ a rule for its whole group",
    addForm = "+ hide it in a form …",
    addRecipe = "+ a recipe",
    -- The drawer's last link: Daylight UI's copy box holding a bug report.
    copyReport = "Copy report",
    copyReportTitle = "EZ-CDM report",
    copyReportHint = "Ctrl+C to copy, then paste it into a GitHub issue or the DaylightUI Discord. "
        .. "It holds your layout and EZ-CDM's settings, no names.",
    -- The start block beside the editor's tray.
    start = {
        blank = "EZ-Start Blank", load = "EZ-Load Layout",
        name = "Name your layout", create = "Create", noName = "Give the layout a name first.",
    },
    -- EZ-CDM's page in its own section under /dui's Plugins (Settings.lua). Labels
    -- stay 4 words or fewer, tips 8 or fewer (tests/test_settings.lua).
    settings = {
        page = "Settings", pageDesc = "The editor, its sounds, and news of updates.",
        editor = "EZ Editor", updates = "Updates",
        startBlock = "Show Start Block", startBlockTip = "The cards beside the spell tray.",
        drawer = "Drawer Starts", drawerTip = "Each time the editor opens.",
        drawerLast = "As Left", drawerOpen = "Open", drawerClosed = "Closed",
        sounds = "Play Sounds", soundsTip = "Fall-off sounds and sound previews.",
        updateCheck = "Newer Version Notice", updateCheckTip = "Swaps versions with guild, group and friends.",
        whatsNew = "Show What's New", whatsNewTip = "Once after each update.",
        more = "More Condition Choices", moreTip = "Advanced conditions in the drawer's word rows.",
        news = "What's New", newsShow = "Show",
        -- What's New in Daylight UI's window (News.lua), and its one button.
        newsTitle = "What's New in EZ-CDM", okay = "Okay",
        -- A newer version heard (%s), in the same window.
        newerTitle = "EZ-CDM", newer = "EZ-CDM %s is out. Get it on CurseForge or WowUp.",
    },
    -- What's New, newest first, from CHANGELOG.md.
    news = {
        { version = "0.3.0", lines = {
            "Settings have their own EZ-CDM page under Plugins in /dui.",
            "A short tour the first time /cdm opens. Replay Tour shows it again.",
            "A sound chip plays its sound as you pick it.",
            "The row of choices stays open after a pick, so you can try a few.",
            "What's New shows in its own window, once after each update.",
            "A newer version notice from your guild, group and Battle.net friends.",
        } },
        { version = "0.2.0", lines = {
            "Recipes: \"+ a recipe\" adds a ready-made set of lines in one click.",
            "\"Turn it gray\" when you can't cast, \"tint it blue\" when short on power.",
            "A glow can follow your accent color again (Daylight UI 2.2.6).",
            "\"Copy report\" at the drawer's bottom, for bug reports.",
        } },
    },
    -- The first-run tour's steps (Tour.lua). Each %s is a name in the tour's accent.
    tour = {
        start = { title = "Start here",
            text = "%s makes a new empty layout. %s picks one of your class's layouts." },
        pick = { title = "Pick a spell",
            text = "Click a spell in your layout. EZ-CDM shows what it does in plain sentences.",
            -- With the tour's demo spell (%s), which goes when the tour ends.
            demo = "The tour put %s in your layout to try things on. It goes when the tour ends. "
                .. "Click it, and EZ-CDM shows what it does in plain sentences." },
        drawer = { title = "The drawer",
            text = "The sentences live in this drawer. The %s tab folds it away and back." },
        word = { title = "Change a word",
            text = "Click a colored word to change it. Pick a new one in the row at the bottom. It saves at once." },
        line = { title = "Add a line",
            text = "%s starts a new sentence. Choose a moment, then what happens." },
        recipe = { title = "Use a recipe",
            text = "%s adds ready-made lines, like %s.",
            -- With the demo spell: the link, the recipe the tour put on it.
            demo = "%s adds ready-made lines. The tour just added %s, so its lines appeared above." },
        group = { title = "Rules for the group",
            text = "%s sets a rule for every spell in the group, like %s." },
        report = { title = "Something wrong?",
            text = "%s puts your layout in a box to copy. Paste it into a bug report." },
        -- The skipped line: the settings row (%s) and EZ-CDM's section under
        -- Plugins in /dui (%s).
        skipped = "Tour skipped. %s under %s in /dui shows it again.",
        -- The settings row that runs it again, and its button.
        replay = "Replay Tour", replayShow = "Show",
    },
}
local WORDING = Grammar.WORDING
for _, c in ipairs(Conditions.List()) do installWords(c) end

-- The player's power, as the game names it ("rage"), else "power".
function Grammar.PowerName()
    local token = type(UnitPowerType) == "function" and select(2, UnitPowerType("player"))
    local name = type(token) == "string" and _G[token]
    if type(name) == "string" and name ~= "" then return name:lower() end
    return "power"
end

-- The number a typed-number word shows: n, else "N" where it is a chip's name.
Grammar.NUMBER_MARK = "#"

-- A phrase with its power name (%s) and number (#) put in. A "%" after the number
-- stays as it is.
local function fill(phrase, n)
    if phrase:find("%s", 1, true) then phrase = phrase:gsub("%%s", (Grammar.PowerName():gsub("%%", "%%%%"))) end
    return (phrase:gsub(Grammar.NUMBER_MARK, n ~= nil and tostring(n) or "N"))
end

-- A moment's phrase and what joins it to the action (", " or " "). A moment not
-- picked yet reads as its blank. n is a typed number, "N" on a chip when nil.
function Grammar.MomentWords(moment, n)
    if moment == nil then return WORDING.chooseMoment, ", " end
    local phrase = WORDING.moments[moment]
    if not phrase then return tostring(moment), " " end
    return fill(phrase, n), WORDING.noComma[moment] and " " or ", "
end

-- A condition's clause phrase ("my target is a boss"), n as in MomentWords.
function Grammar.ClauseWords(key, n)
    local phrase = WORDING.clauses[key]
    if not phrase then return tostring(key) end
    return fill(phrase, n)
end

-- Why conditions a and b can never both be true, as words: their own reason, or
-- the layer clash; nil when they can.
function Grammar.NeverWords(a, b)
    if not Conditions.Excludes(a, b) then return nil end
    local why = (WORDING.never[a] or {})[b] or (WORDING.never[b] or {})[a]
    if not why then return WORDING.layerClash end
    return WORDING.neverBoth:format(fill(why))
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
    local ck = Grammar.LineCondition(line)
    local phrase, joint = Grammar.MomentWords(line.moment, ck and Conditions.NumberOf(ck, line.n))
    local entry = MAP[line.moment] and MAP[line.moment][line.action]
    if entry and entry.lead and line.at ~= nil then phrase = phrase .. " " .. Grammar.LeadWords(line.at) end
    for _, cl in ipairs(ck and type(line.clauses) == "table" and line.clauses or {}) do
        local key = type(cl) == "table" and cl.cond
        phrase = phrase .. " " .. WORDING.andWord .. " " .. Grammar.ClauseWords(key, Conditions.NumberOf(key, cl.n))
    end
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
-- you cast on an enemy. An EZ-CDM rule on a piece Daylight UI's buff moments
-- cover gets lands in place of own and early.
function Grammar.FallOffNotes(kind, lines)
    local ruled = fallOffRuled(lines)
    local out
    if ruled and type(kind) == "table" and kind.buffEvents == true then
        out = { { code = "lands", text = WORDING.fallOff.lands } }
        if kind.harmful == true then out[#out + 1] = { code = "target", text = WORDING.fallOff.target } end
        return out
    end
    out = { { code = "own", text = WORDING.fallOff.own } }
    local by = type(kind) == "table" and kind.drawnBy
    if (type(by) == "string" and by:find("^aura")) or ruled then
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
