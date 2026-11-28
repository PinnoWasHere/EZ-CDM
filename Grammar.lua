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
--   valued         an EZ-CDM look line whose value its effect takes: "color" (nil = the
--                  accent), "text" or "icon" (nil = not picked yet)
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
-- A glow needs a span, and the one that starts when a buff wears off is Daylight UI's
-- glow while it's not active (missingGlow). The pick writes that line
-- (Grammar.Canonical).
MAP.ends.glow = { alias = { moment = "missing", action = "glow" } }
MAP.ready.glow = { field = "readyGlow", value = true, color = "readyGlowColor", style = true }
MAP.ready.sound = { field = "readySound", sound = true }
-- An owned line: Daylight UI's line until it takes an "and" clause, then the EZ-CDM
-- line owns lists, on pieces whose kind flag says that EZ-CDM moment is this one
-- (Ready.lua turns Daylight UI's own off for the piece). owns is { moment, action, flag }.
local READY_OWNS = { offCooldown = "cooldownReady", totemDown = "totemTime" }
for _, a in ipairs({ "glow", "sound" }) do
    MAP.ready[a].owns = {}
    for _, m in ipairs({ "offCooldown", "totemDown" }) do
        MAP.ready[a].owns[#MAP.ready[a].owns + 1] = { moment = m, action = a, flag = READY_OWNS[m] }
    end
end
-- desat tracks cooldown state only (CdmEffects.lua:1142-1151), so gray goes with
-- cooldown alone.
MAP.cooldown.gray = { field = "desat", value = "grey" }
MAP.cooldown.color = { field = "desat", value = "color" }
-- The cooldown's sweep: off, or off only for the global cooldown (CdmCard.lua:506-510).
MAP.cooldown.nosweep = { field = "noSwipe", value = true }
MAP.cooldown.nogcd = { field = "noGcd", value = true }
-- The numbers' color for the cooldown's last seconds (CdmCard.lua:522-529).
MAP.almost = { numbers = { look = "low", lookColor = "lowColor", at = "lowAt" } }
-- A merged moment's line: one of Daylight UI's moments shows an EZ-CDM moment's
-- action on pieces whose kind flag says they mean the same, each line still written
-- to the EZ-CDM moment's own field. merges lists { moment, action, flag }; the flags
-- of one action's merges never hold together on a piece.
-- On a totem showing its own time (kind.totemTime), Daylight UI's cooling down is the
-- totem standing, the state EZ-CDM's totemUp reads: one "While my totem is up" takes
-- Daylight UI's rows above and totemUp's glow and sound (InstallCondition adds its looks).
MAP.cooldown.glow = { merges = { { moment = "totemUp", action = "glow", flag = "totemTime" } } }
MAP.cooldown.sound = { merges = { { moment = "totemUp", action = "sound", flag = "totemTime" } } }
Grammar.MAP = MAP

-- A moment whose lines another moment shows on some pieces: its moment there, and
-- the kind flag that says so. Daylight UI's ready keeps its own glow and sound, and
-- takes the EZ-CDM moment's looks: offCooldown where ready is the real cooldown's end
-- (kind.cooldownReady), totemDown where it is the totem gone (kind.totemTime).
-- Daylight UI's cooling down and active take the fill as EZ-CDM's cooling
-- (kind.cooldownReady) and active (kind.clocked).
Grammar.MERGED = {
    totemUp = { into = "cooldown", flag = "totemTime" },
    offCooldown = { into = "ready", flag = "cooldownReady" },
    totemDown = { into = "ready", flag = "totemTime" },
    cooling = { into = "cooldown", flag = "cooldownReady" },
    active = { into = "up", flag = "clocked" },
}

-- The merge a merged entry takes on kind ({ moment, action, flag }), or nil where kind
-- merges none of them. With no kind, the first: every merge of one action is the
-- same look, so what it holds and draws is the same.
local function mergeOf(entry, kind)
    for _, m in ipairs(entry.merges) do
        if kind == nil or (type(kind) == "table" and kind[m.flag] == true) then return m end
    end
end

-- The EZ-CDM line an owned entry becomes on kind ({ moment, action, flag }), or nil
-- where kind takes none. With no kind, the first.
local function ownedOf(entry, kind)
    for _, m in ipairs(entry.owns) do
        if kind == nil or (type(kind) == "table" and kind[m.flag] == true) then return m end
    end
end

local function hasClauses(line) return type(line.clauses) == "table" and #line.clauses > 0 end

-- An entry as it writes on kind: a merged one's EZ-CDM entry (nil where kind merges
-- none), any other entry itself.
local function resolved(entry, kind)
    if not (entry and entry.merges) then return entry end
    local m = mergeOf(entry, kind)
    return m and MAP[m.moment][m.action] or nil
end

-- The moment a piece shows moment's lines under, where it merges into another, else nil.
function Grammar.MergedInto(kind, moment)
    local m = Grammar.MERGED[moment]
    if m and type(kind) == "table" and kind[m.flag] == true then return m.into end
    return nil
end

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

-- Which glow shows when several could (CdmEffects.lua:511-536): proc, then missing,
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
-- the one place the recast signal lives. On Forever, a proc talent such as Improved
-- Stormstrike is known and passive, and its buff is not passive.
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
-- one of its own ids (CdmAuras.lua:1237-1254), so a piece whose every id is passive
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

-- The client's letters for a spell id (AuraLinks.spells), or nil for an id it
-- doesn't list.
local function letters(id)
    local t = type(ns.AuraLinks) == "table" and ns.AuraLinks.spells
    local v = type(t) == "table" and t[id]
    return type(v) == "string" and v or nil
end

-- Whether a piece's spell has a real cooldown by the client's tables: false for one
-- with none (Lesser Healing Wave), nil when the tables don't list its spell.
local function realCooldown(key)
    local v = letters(Bridge.SpellOf(key))
    if v == nil then return nil end
    return v:find("c", 1, true) ~= nil
end

-- Whether the client's tables give a piece's spell a letter (AuraLinks.spells): true,
-- else nil.
local function lettered(key, ch)
    local v = letters(Bridge.SpellOf(key))
    return v ~= nil and v:find(ch, 1, true) ~= nil or nil
end

-- What a piece's casts cost by the client's SpellPower rows (AuraLinks.costs), over its
-- spell and every id it holds, since a totem piece's spell may be its buff (Windfury
-- Totem 200485 holds the casts 8512, 10613, 10614 beside the buff 10612): true and the
-- powers as words ("rage", "energy or rage"); false when the tables list every id and
-- none costs (Charge); nil when they don't list one. Combo points are named only alone:
-- beside energy or rage the cast's own power is what runs short.
local function costOf(key)
    local sid = Bridge.SpellOf(key)
    if letters(sid) == nil then return nil, nil end
    local ids, held = { sid }, Bridge.SpellIDs(key)
    for id in pairs(type(held) == "table" and held or {}) do
        if id ~= sid then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local t = type(ns.AuraLinks) == "table" and type(ns.AuraLinks.costs) == "table" and ns.AuraLinks.costs or {}
    local list, seen, listed = {}, {}, true
    for _, id in ipairs(ids) do
        if letters(id) == nil then listed = false end
        for _, w in ipairs(type(t[id]) == "table" and t[id] or {}) do
            if not seen[w] then seen[w] = true; list[#list + 1] = w end
        end
    end
    if #list == 0 then
        if listed then return false, nil end
        return nil, nil
    end
    local words = {}
    for _, w in ipairs(list) do
        if w ~= "combo points" or #list == 1 then words[#words + 1] = w end
    end
    return true, table.concat(words, " or ")
end

-- The powers a "below #%" word can name: a bar the player holds as a percent.
local PERCENT = { mana = true, rage = true, energy = true, focus = true }

-- The powers a piece's casts cost that your class's player has (AuraLinks.classPowers)
-- and that read as a percent, as a list ({ "energy", "rage" }). nil when any of them
-- isn't one (combo points alone, health, a pet's focus, another class's energy) or the
-- piece costs nothing.
function Grammar.LowPowers(key)
    local cost, words = costOf(key)
    if cost ~= true then return nil end
    local L = type(ns.AuraLinks) == "table" and type(ns.AuraLinks.classPowers) == "table" and ns.AuraLinks.classPowers or {}
    local mine = {}
    for _, w in ipairs(L[Bridge.MyClass() or ""] or {}) do mine[w] = true end
    local out = {}
    for w in (words .. " or "):gmatch("(.-) or ") do
        if not (PERCENT[w] and mine[w]) then return nil end
        out[#out + 1] = w
    end
    return #out > 0 and out or nil
end

-- The enchant ids a piece's weapon buff cast puts on a weapon, any rank's, as a set
-- (AuraLinks.imbues), or nil for a piece that casts none.
function Grammar.Imbues(key)
    local t = type(ns.AuraLinks) == "table" and ns.AuraLinks.imbues
    local list = type(t) == "table" and t[Bridge.SpellOf(key)]
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, id in ipairs(list) do out[id] = true end
    return out
end

-- Whether a piece's spell checks range to a target: the game's own answer, nil when
-- it won't say.
local function ranged(key)
    local sid = Bridge.SpellOf(key)
    local S = type(C_Spell) == "table" and C_Spell or {}
    if sid == nil or type(S.SpellHasRange) ~= "function" then return nil end
    return plain(S.SpellHasRange(sid)) == true or nil
end

-- Every id a piece answers to: its spell, the ids it holds, and the auras the client's
-- links say they put up under other ids (Arcane Concentration -> Clearcasting).
local function auraIds(key)
    local ids, seen = {}, {}
    local function add(id)
        if type(id) == "number" and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    add(Bridge.SpellOf(key))
    local held = Bridge.SpellIDs(key)
    for id in pairs(type(held) == "table" and held or {}) do add(id) end
    local by = type(ns.AuraLinks) == "table" and ns.AuraLinks.bySource or {}
    for i = 1, #ids do
        for _, a in ipairs(by[ids[i]] or {}) do add(a) end
    end
    table.sort(ids)
    return ids
end

-- The aura a piece shows by the client's tables, "debuff" or "buff": a debuff when
-- its spell or any id it holds puts one on an enemy, else a buff when one puts one
-- up. Second, true when it can never show an aura, nil when the tables can't tell:
--   the game's piece  its item shows only an aura under the row's own or linked ids
--                     (CooldownViewerItemData.lua:327-356), so none of those putting
--                     one up is enough (Earth Shock)
--   Daylight UI's own its piece also learns an aura seen after a cast (CdmOwn.AuraOf),
--                     so each id the tables list needs the letter "n": every effect is
--                     one that puts up no aura (Lightning Bolt). A dummy effect (Last
--                     Stand 12975, whose buff the server puts up) can't tell
-- A totem is never "no aura": its buff is its creature's spell, which the tables don't
-- link. Neither is a spell the tables don't list.
local function auraOf(key)
    local buff
    local custom = Bridge.IsCustom(key)
    local none = letters(Bridge.SpellOf(key)) ~= nil and not Bridge.IsTotem(key)
    for _, id in ipairs(auraIds(key)) do
        local v = letters(id)
        if custom and v and not v:find("n", 1, true) then none = false end
        v = v or ""
        if v:find("d", 1, true) then return "debuff", nil end
        if v:find("b", 1, true) then buff = true end
    end
    if buff then return "buff", nil end
    return nil, none or nil
end

-- The most charges any aura of a piece comes with (AuraLinks.charges), and whether
-- the game never keeps each of those auras secret (C_Secrets.GetSpellAuraSecrecy),
-- so their count reads in a fight. Both nil when none has charges.
local function chargesOf(key)
    local t = type(ns.AuraLinks) == "table" and ns.AuraLinks.charges or {}
    local most, ids = nil, {}
    for _, id in ipairs(auraIds(key)) do
        local n = t[id]
        if n then
            ids[#ids + 1] = id
            if not most or n > most then most = n end
        end
    end
    if not most then return nil, nil end
    local S = type(C_Secrets) == "table" and C_Secrets or {}
    local levels = type(Enum) == "table" and Enum.SecrecyLevel
    local never = type(levels) == "table" and levels.NeverSecret or nil
    if type(S.GetSpellAuraSecrecy) ~= "function" or never == nil then return most, nil end
    for _, id in ipairs(ids) do
        if plain(S.GetSpellAuraSecrecy(id)) ~= never then return most, nil end
    end
    return most, true
end

-- The ids of a piece's auras that come with charges, in id order.
function Grammar.ChargedAuras(key)
    local t = type(ns.AuraLinks) == "table" and ns.AuraLinks.charges or {}
    local out = {}
    for _, id in ipairs(auraIds(key)) do
        if t[id] then out[#out + 1] = id end
    end
    return out
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
--   noCooldown       the client's tables give its spell no real cooldown
--                    (AuraLinks.spells), and it is no totem (whose time Daylight UI
--                    shows as one): no almost or cooling down words but the sweep's
--   realCooldown     the client's tables give its spell a real cooldown: true or
--                    false, nil when they don't list it
--   noAura           the client's tables list its spell and none of its ids puts up
--                    an aura (Lightning Bolt): no buff or debuff words, and What it
--                    shows offers only its cooldown
--   aura             "debuff" or "buff", the aura its words name: the client's
--                    tables, else a harmful spell's debuff, else a buff; nil with
--                    noAura
--   targeted         its spell is cast at a unit you pick (AuraLinks.spells "t"),
--                    so the target words fit it
--   totemTime        a totem showing its own time, which Daylight UI times as its
--                    cooldown (CdmEffects Fx.OnCooldown): its cooldown words are the
--                    totem's
--   cooldownReady    a cooldown face whose spell has a real cooldown and is no totem,
--                    so Daylight UI's ready is that cooldown's end, as offCooldown reads
--   cost             its spell costs power to cast (AuraLinks.costs, SpellPower): true
--                    or false, nil when the tables don't list it. No short words on a
--                    free spell
--   power            the powers its cast costs, as words ("rage"); nil names the
--                    player's own (Grammar.PowerName)
--   lowPower         every power it costs is one your class's player has as a
--                    percent (Grammar.LowPowers), so "my [power] is below #%" fits
--   charges          the most charges its aura comes with (AuraLinks.charges)
--   chargesSeen      the game never keeps those auras secret, so their count reads
--                    in a fight (C_Secrets.GetSpellAuraSecrecy NeverSecret)
--   ranged           its spell checks range to a target (C_Spell.SpellHasRange)
--   interrupt        its spell interrupts a cast (AuraLinks.spells "i")
--   gcd              the global cooldown touches its spell (AuraLinks.spells "g")
--   imbue            its spell puts a buff on a weapon (AuraLinks.imbues)
--   totem            its spell is a timed totem (Bridge.IsTotem)
--   procAlert        Daylight UI's Proc Alerts lists its spell (Bridge.ProcAlertListed).
--                    The flare covers the proc, so no Proc pop, and the drawer notes it
--   clocked          Daylight UI clocks its own buff from your cast or its buff moments,
--                    so its time left reads in a fight: a buff you cast that wears off
--                    (the recast moment's pieces), never a proc or a debuff
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
    local auraWord, noAura = auraOf(key)
    -- No aura by the client's tables: whatever Daylight UI shows, there is no buff.
    if noAura then hasBuff = false end
    -- A spell with neither a cooldown nor a buff: its castable words only. The client's
    -- tables answer for a spell they list.
    local button = Bridge.SpellButton(key, function()
        local v = letters(Bridge.SpellOf(key))
        if v == nil then return nil end
        return noAura == true and not v:find("c", 1, true)
    end) == true
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
        noCooldown = realCooldown(key) == false and not Bridge.IsTotem(key) or nil,
        realCooldown = realCooldown(key),
        noAura = noAura,
        targeted = lettered(key, "t"),
        totemTime = Bridge.IsTotem(key) and now == "totem" or nil,
        ranged = ranged(key),
        interrupt = lettered(key, "i"),
        gcd = lettered(key, "g"),
        imbue = Grammar.Imbues(key) ~= nil or nil,
        totem = Bridge.IsTotem(key) or nil,
        procAlert = Bridge.ProcAlertListed(key) or nil,
    }
    -- A harmful spell's aura is a debuff only where the tables don't list the spell at
    -- all; where they list it and can't tell, the words keep Daylight UI's "buff".
    local unlisted = letters(Bridge.SpellOf(key)) == nil
    if not noAura then kind.aura = auraWord or (unlisted and kind.harmful == true and "debuff") or "buff" end
    kind.charges, kind.chargesSeen = chargesOf(key)
    kind.cost, kind.power = costOf(key)
    -- Daylight UI times any totem by its totem, not its spell's cooldown (Fx.OnCooldown).
    kind.cooldownReady = (kind.cooldown and kind.realCooldown == true and not kind.totem) or nil
    kind.lowPower = Grammar.LowPowers(key) ~= nil or nil
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
    kind.clocked = (kind.showsBuff and kind.cast and not kind.untimed and not kind.proc
        and kind.aura ~= "debuff") or nil
    -- What the card's What it shows reads now (CdmCard.lua:367-374), in the grammar's words.
    if trackRow then
        kind.showing = (now == "both" or now == "cooldown" or now == "buff") and now
            or (aura and "buff" or "cooldown")
        -- Daylight UI waits for a buff the spell never puts up: hidden until it shows
        -- its cooldown.
        if noAura and kind.showing == "buff" then kind.buttonHidden = true end
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

-- A line in the words that write it: an alias's (Grammar.ALIASES) the line it stands
-- for, a copy; any other line itself.
-- A merged moment's line stands for the EZ-CDM line kind merges.
function Grammar.Canonical(line, kind)
    local entry = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
    local to = entry and (entry.alias or (entry.merges and mergeOf(entry, kind))
        or (entry.owns and hasClauses(line) and ownedOf(entry, kind)))
    if not to then return line end
    local out = {}
    for k, v in pairs(line) do out[k] = v end
    out.moment, out.action = to.moment, to.action
    return out
end

-- Whether a moment and action fit a piece, as the card offers them.
local fits
function Grammar.Fits(kind, moment, action) return fits(kind, moment, action) end
fits = function(kind, moment, action)
    local entry = MAP[moment] and MAP[moment][action]
    if not entry then return false end
    if entry.merges then
        -- A merged moment's line fits where the piece merges and the line it writes fits.
        if kind == nil then return true end
        local m = mergeOf(entry, kind)
        return m ~= nil and fits(kind, m.moment, m.action)
    end
    if entry.alias then
        -- The piece has the moment (its own row, the wears-off sound) and the line the
        -- alias writes.
        return fits(kind, moment, "sound") and fits(kind, entry.alias.moment, entry.alias.action)
    end
    if kind == nil then return true end
    -- No aura by the client's tables: no buff moment at all, whatever Daylight UI shows.
    if kind.noAura and (moment == "up" or moment == "ends" or moment == "missing" or moment == "recast") then
        return false
    end
    local told = kind.tracked
    -- A spell with no real cooldown only runs the global cooldown: its sweep is all
    -- the cooling down it has, and it is never almost ready.
    if kind.noCooldown and (moment == "almost"
        or (moment == "cooldown" and action ~= "nosweep" and action ~= "nogcd")) then
        return false
    end
    if entry.cond then
        return Conditions.Fits(entry.cond, action, kind)
    elseif moment == "short" then
        -- Short of power never happens to a spell that costs none.
        return (kind.cooldown or kind.button == true) and kind.cost ~= false
    elseif moment == "always" or moment == "unusable" or moment == "usable" then
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

-- The What it shows picks that fit a piece, in Grammar.SHOWS order: only its cooldown
-- for a spell the client's tables give no aura (kind.noAura).
function Grammar.ShowsChoices(kind)
    if type(kind) == "table" and kind.noAura then return { "cooldown" } end
    local out = {}
    for i, s in ipairs(Grammar.SHOWS) do out[i] = s end
    return out
end

-- Whether a piece takes the What it shows sentence: the card's row is there, and
-- there is a choice to make, or its pick now is one that doesn't fit.
local function takesShows(kind)
    if kind == nil then return true end
    if not kind.trackRow then return false end
    local choices = Grammar.ShowsChoices(kind)
    return #choices > 1 or not indexOf(choices, kind.showing)
end
Grammar.TakesShows = takesShows

-- The whole-spell words that fit a piece, in Grammar.EXTRAS order.
function Grammar.Extras(kind)
    local out = {}
    for _, e in ipairs(Grammar.EXTRAS) do
        if e ~= "shows" or takesShows(kind) then out[#out + 1] = e end
    end
    return out
end

-- Whether the drawer offers an EZ-CDM condition: never one that is unknown in a
-- fight, and an advanced one only with more. An alone one is never an "and" part.
local function offered(c, opts, asClause)
    if c.clauseOnly and not asClause then return false end
    if c.alone and asClause then return false end
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
        for _, a in ipairs(Grammar.MergedInto(kind, m) and {} or Grammar.ACTIONS) do
            local e = resolved(MAP[m] and MAP[m][a], kind)
            local c = e and e.cond and Conditions.Get(e.cond)
            if Grammar.Fits(kind, m, a) and (not c or offered(c, opts)) then actions[#actions + 1] = a end
        end
        if #actions > 0 then out[#out + 1] = { moment = m, actions = actions } end
    end
    return out
end

-- What a look line's value holds ("color", "text", "icon"), through a merged
-- moment's merge; nil for any other line.
function Grammar.ValueKind(moment, action)
    local e = resolved(MAP[moment] and MAP[moment][action])
    return e and e.valued or nil
end

-- The EZ-CDM condition a line starts with on kind, or nil. Without kind a merged
-- moment's line reads as its first merge's.
function Grammar.LineCondition(line, kind)
    local e = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
    if e and e.owns then
        local m = hasClauses(line) and ownedOf(e, kind)
        return m and MAP[m.moment][m.action].cond or nil
    end
    e = resolved(e, kind)
    return e and e.cond or nil
end

-- The EZ-CDM condition a line's "and" clauses follow on kind: its LineCondition, or
-- for Daylight UI's own ready glow and sound the EZ-CDM line it becomes with a clause.
function Grammar.ClauseRoot(line, kind)
    local ck = Grammar.LineCondition(line, kind)
    if ck then return ck end
    local e = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
    local m = e and e.owns and kind ~= nil and ownedOf(e, kind)
    return m and MAP[m.moment][m.action].cond or nil
end

-- The EZ-CDM condition that is Daylight UI's ready on kind (offCooldown or
-- totemDown), or nil.
function Grammar.ReadyCondition(kind)
    local m = type(kind) == "table" and ownedOf(MAP.ready.glow, kind)
    return m and m.moment or nil
end

-- The conditions a line may take as its next "and" clause, in registry order: an
-- EZ-CDM line whose parts are all plain so far, each condition once, fitting the
-- piece. A client one only where the line's effect is alpha-safe, and never on a
-- sound. opts as Grammar.Words.
-- The parts a line holds, in order, or nil when it can take no more (an unknown
-- part, or a client one).
local function partsSoFar(line, kind)
    local ck = Grammar.ClauseRoot(line, kind)
    local root = ck and Conditions.Get(ck)
    if not root or root.secrecy == "client" or root.alone then return nil end
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
    local parts = partsSoFar(line, kind)
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

-- Whether a line can take another "and" part at all on kind: an EZ-CDM line with no
-- client part yet.
function Grammar.TakesClauses(line, kind) return partsSoFar(line, kind) ~= nil end

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
        if p.clash then out[#out + 1] = { cond = p.cond, why = Grammar.NeverWords(p.clash, p.cond, kind) } end
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
--   buff     a cooldown line on a piece that shows its buff in its place, unless
--            its look decorates the whole piece (Conditions.AnyFace)
function Grammar.HiddenNote(kind, line)
    local W = Grammar.WORDING
    if type(kind) ~= "table" or type(line) ~= "table" then return nil end
    if kind.buttonHidden then
        return { code = "button", text = W.hiddenButton, fixes = kind.trackRow and { "shows" } or {} }
    end
    local ck = Grammar.LineCondition(line, kind)
    if not ck or kind.shows ~= "both" then return nil end
    if Conditions.LineLayer(ck, { clauses = line.clauses }) ~= "cooldown" then return nil end
    -- A look on the whole piece shows on its buff's face too.
    if Conditions.AnyFace(ck, line.action) then return nil end
    for _, cl in ipairs(type(line.clauses) == "table" and line.clauses or {}) do
        if type(cl) == "table" and cl.cond == "noBuff" then return nil end
    end
    local fixes = {}
    if kind.trackRow then fixes[#fixes + 1] = "shows" end
    if Conditions.Get("noBuff") and Conditions.FitsKind("noBuff", kind) then fixes[#fixes + 1] = "clause" end
    return { code = "buff", text = Grammar.ForKind(W.hiddenByBuff, kind), fixes = fixes }
end

-- The note under Daylight UI's own Gray out line ("While it's cooling down, turn it
-- gray" or "keep its color") while an EZ-CDM gray line owns the piece's gray
-- (Gray.lua), or nil.
function Grammar.GrayOwnedNote(line, lines)
    if type(line) ~= "table" or line.moment ~= "cooldown" then return nil end
    if line.action ~= "gray" and line.action ~= "color" then return nil end
    for _, l in ipairs(type(lines) == "table" and lines or {}) do
        local ck = type(l) == "table" and Grammar.LineCondition(l)
        if ck and Conditions.Grays(ck, l.action) then
            local W = Grammar.WORDING
            return line.action == "gray" and W.grayOwned or W.colorOwned
        end
    end
    return nil
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
        -- Proc Alerts already flares a proc it lists (kind.procAlert).
        local fits = not (r.key == "procPop" and type(kind) == "table" and kind.procAlert)
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
    -- The looks join the action words in their own order (Looks.LIST).
    for _, l in ipairs(Conditions.Looks()) do
        if c.actions[l.action] and not indexOf(Grammar.ACTIONS, l.action) then
            Grammar.ACTIONS[#Grammar.ACTIONS + 1] = l.action
        end
    end
    local actions = {}
    for a in pairs(c.actions) do actions[#actions + 1] = a end
    table.sort(actions)
    for _, a in ipairs(actions) do
        local field = Conditions.Field(c.key, a)
        local effect = c.actions[a].effect
        MAP[c.moment][a] = { field = field, value = true, cond = c.key, sound = effect == "sound" or nil,
                             glow = effect == "glow" or nil, valued = Conditions.ValueKind(c.key, a) }
        if not indexOf(Grammar.ACTIONS, a) then Grammar.ACTIONS[#Grammar.ACTIONS + 1] = a end
        if not indexOf(Grammar.EZ_FIELDS, field) then Grammar.EZ_FIELDS[#Grammar.EZ_FIELDS + 1] = field end
        -- A moment merged into another shows its actions there too, where that moment
        -- has no action of its own by that word.
        local merged = Grammar.MERGED[c.moment]
        local into = merged and MAP[merged.into][a]
        if merged and into == nil then
            MAP[merged.into][a] = { merges = { { moment = c.moment, action = a, flag = merged.flag } } }
        elseif merged and into.merges then
            local have = false
            for _, m in ipairs(into.merges) do have = have or m.moment == c.moment end
            if not have then into.merges[#into.merges + 1] = { moment = c.moment, action = a, flag = merged.flag } end
        end
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
    line = Grammar.Canonical(line)
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
-- light (CdmEffects.lua:500-509). With no sweep while the buff is up, its color has
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
    if parts[1].alone and clauses ~= nil and #clauses > 0 then return nil, "pair" end
    for _, cl in ipairs(clauses or {}) do
        local c = type(cl) == "table" and Conditions.Get(cl.cond)
        if not c or c.alone then return nil, "pair" end
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
    local spec = Conditions.Spec(ck, line.action, { n = line.n,
        value = (entry.sound or entry.glow or entry.valued) and line.value or nil,
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
        if Grammar.Fits(kind, type(line) == "table" and line.moment, type(line) == "table" and line.action) then
            line = Grammar.Canonical(line, kind)
        end
        local entry = type(line) == "table" and MAP[line.moment] and MAP[line.moment][line.action]
        local spec, condCode
        if entry and entry.cond then spec, condCode = condSpec(line, entry, kind) end
        if type(line) == "table" and (line.moment == nil or line.action == nil) then
            problem({ line = i, code = "blank" })
        elseif entry and (entry.valued == "text" or entry.valued == "icon") and line.value == nil then
            -- Its words or its icon aren't picked yet.
            problem({ line = i, code = "blank" })
        elseif entry and entry.valued and line.value ~= nil
            and Conditions.CleanValue(entry.valued, line.value) == nil then
            problem({ line = i, code = "value" })
        elseif not entry or (line.clauses ~= nil and not entry.cond) then
            problem({ line = i, code = "pair" })
        elseif line.n ~= nil and not entry.cond then
            problem({ line = i, code = "value" })
        elseif not Grammar.Fits(line.action == "flash" and flashKind or kind, line.moment, line.action) then
            problem({ line = i, code = "kind" })
        elseif entry.valued == "fill" and kind
            and not indexOf((Grammar.FillSources(kind, line)), (Grammar.FillPicks(line.value, kind, line))) then
            -- What it fills with doesn't fit the piece (time left on a proc).
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
        elseif kind and (not kind.trackRow or not indexOf(Grammar.ShowsChoices(kind), shows)) then
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
-- name the lines that don't fit kind, kept so a save never drops them unseen. A
-- merged moment's fields (Grammar.MERGED) read as lines of the moment kind shows
-- them under, so a rule saved as "While my totem stands" reads "While my totem is up".
-- An EZ-CDM condition's line from its saved spec v, as moment m and action a, or nil.
local function condLine(m, a, entry, v)
    if v ~= true and type(v) ~= "table" then return nil end
    local line = { moment = m, action = a }
    if type(v) == "table" then
        line.n = v.n
        if entry.sound then line.value = v.value end
        if entry.glow then line.value, line.style = v.value, v.style end
        if entry.valued then line.value = v.value end
        if type(v.clauses) == "table" then
            line.clauses = {}
            for j, cl in ipairs(v.clauses) do line.clauses[j] = { cond = cl.cond, n = cl.n } end
        end
    end
    return line
end

function Grammar.Decompile(fields, kind)
    fields = type(fields) == "table" and fields or {}
    local lines, problems = {}, {}
    local alphaTaken = false
    for _, m in ipairs(Grammar.MOMENTS) do
        for _, a in ipairs(Grammar.ACTIONS) do
            local entry = MAP[m][a]
            if entry and entry.merges then
                entry = kind and resolved(entry, kind) or nil
            elseif Grammar.MergedInto(kind, m) then
                entry = nil
            end
            if entry and not entry.all then
                local v = entry.field and fields[entry.field]
                local line
                if entry.cond then
                    line = condLine(m, a, entry, v)
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
                -- The EZ-CDM line an owned entry became, under Daylight UI's own.
                local o = entry.owns and kind and ownedOf(entry, kind)
                local oe = o and MAP[o.moment][o.action]
                line = oe and condLine(m, a, oe, fields[oe.field])
                if line then lines[#lines + 1] = line end
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
    -- A pick that doesn't fit (its buff on a spell with none) reads as no pick: the
    -- hidden note and its fix say what to do with it.
    if shows and kind and not indexOf(Grammar.ShowsChoices(kind), shows) then shows = nil end
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
    -- A moment's words for a spell with no real cooldown (kind.noCooldown).
    momentsPlain = { cooldown = "While the global cooldown runs" },
    -- A totem's moments while it shows its own time, which Daylight UI times as its
    -- cooldown (kind.totemTime).
    momentsTotem = { ready = "When my totem is down", cooldown = "While my totem is up",
                     almost = "When my totem is almost gone" },
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
        -- EZ-CDM's looks (Looks.lua).
        sparkle = "sparkle", screen = "flash the screen's edge",
        pulse = "pulse it", border = "color its border", halo = "light a halo behind it",
        text = "show words on it", swap = "swap its icon", flare = "flare around me",
        fill = "fill it with",
    },
    -- A fill line's picks (Looks.lua): what it fills with (%s is the power name), its
    -- shape and which way it fills, in brackets after the number. fillNever is why time
    -- left isn't offered: a buff whose timer the game hides, one that never wears off,
    -- or a debuff on your target, which Daylight UI times once per spell.
    fillSources = { power = "my %s", time = "time left" },
    fillShapes = { bar = "thin bar" },
    fillDirs = { drain = "drains", rise = "rises" },
    -- A fill's color that shifts with the amount (Looks.FILL_SHIFT): Daylight UI's health
    -- gradient, green with much left and red with little.
    fillShift = "a color that shifts with the amount",
    fillNever = { hidden = "the game hides this buff's timer in a fight", untimed = "it never wears off",
                  target = "its timer is one per spell, not per target" },
    -- A flare line's picks, in brackets after its action: Daylight UI's Proc Alerts
    -- names for its designs and animations (DaylightUI_Procs/Data.lua), and the sound
    -- it plays with none picked.
    flareDesigns = { wings = "Wings", talons = "Talons", pillars = "Pillars", shards = "Shards", flames = "Flames",
        bolt = "Lightning", comet = "Comets", crown = "Crown", sigil = "Sigil", sun = "Sunrise", ring = "Rune ring",
        wave = "Shockwave" },
    flareAnims = { strike = "Strike", breathe = "Breathe", pulse = "Pulse", impact = "Impact", flash = "Flash",
        still = "Still" },
    flareSound = "Proc Alerts' sound",
    -- A flash line's pick after "flash it": once as the line turns on, or on each beat
    -- while it holds.
    flashRepeats = { once = "once", again = "again and again" },
    -- A text look's words in a line ("show \"Kick!\" on it"), and its blank.
    textShown = "show \"%s\" on it",
    chooseText = "type…",
    -- An icon look's blank and its picked word.
    chooseIcon = "pick…",
    iconPicked = "the icon you picked",
    -- An action's word at one moment, where it differs (an alias's, Grammar.Canonical).
    actionsAt = { ends = { glow = "glow until it's back" } },
    shows = { both = "show its buff, then its cooldown", cooldown = "show its cooldown", buff = "show only its buff" },
    -- The same picks for a spell with no real cooldown (kind.noCooldown).
    showsPlain = { both = "show it, with its buff while it lasts", cooldown = "show it", buff = "show only its buff" },
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
    layerClashPlain = "can't both be true: one is about the spell, the other about its buff",
    -- Under a line its piece can't show (Grammar.HiddenNote), and the one-click fixes.
    hiddenByBuff = "Hidden while its buff shows.",
    hiddenButton = "Hidden: Daylight shows this spell only while a buff is up, and it has none.",
    fixShows = "Show its cooldown",
    fixShowsPlain = "Show it",
    fixClause = "Add \"and its buff isn't active\"",
    -- Under Daylight UI's own Gray out line while an EZ-CDM gray line owns the gray.
    grayOwned = "EZ-CDM draws this gray, along with its own gray lines.",
    colorOwned = "EZ-CDM's gray lines decide when it turns gray.",
    andWord = "and",
    -- The "and …" blank, a clause's strip chip that takes it out, and the strip's
    -- chip for advanced words (Settings "more"). addAction is the blank after a line's
    -- last action, which adds another.
    addClause = "and …",
    addAction = "and …",
    -- Why an action can't join a line (Grammar.LineActions), after neverPart's
    -- 'Not "%s": '. neverAction: %s is an action the line has, then the one refused.
    -- neverSecret: %s is the line's part the game hides in a fight. neverOther: %s is
    -- an action whose line can't take that part.
    neverAction = "it can't %s and %s at once",
    neverClauses = "it can't take this line's \"and\" parts",
    neverSecret = "the game hides \"%s\" in a fight, so only looks that stay on can follow it",
    neverTaken = "another line already does it at this moment, and only one can",
    neverOther = "\"%s\" can't follow a part the game hides in a fight",
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
        text = "Type a few words:", icon = "Choose an icon:",
        design = "Choose a flare:", anim = "Choose how it moves:", flareSound = "Choose a sound:",
        fillSource = "Choose what it fills with:", fillShape = "Choose a shape:", fillDir = "Choose which way it fills:",
        also = "Choose what else happens:",
    },
    -- Under a one-shot look's line while Daylight UI's motion is off.
    motionOff = "Daylight UI's motion is off, so this doesn't show.",
    -- Under a flare line while Daylight UI's Proc Alerts is off.
    procAlertsOff = "Daylight UI's Proc Alerts is off, so this doesn't show.",
    -- On a piece Daylight UI's Proc Alerts lists (kind.procAlert).
    procAlertNote = "This talent's proc shows in Daylight UI's Proc Alerts.",
    -- Under the words' box: how many letters they may have (%d).
    textRange = "Up to %d letters.",
    -- Daylight UI's icon picker's title.
    iconTitle = "An icon for this line",
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
        { version = "1.3.0", lines = {
            "A flash can go again and again, every 1.2 seconds while its line is true.",
            "A fill's color can shift with the amount: green with much left, red with little.",
            "\"While it's cooling down\" and \"While it's active\" take \"and\" now.",
            "Fills show as a thin bar under the icon. Tint fills become thin bars.",
            "Flares can use Daylight UI 2.4.1's Strike animation.",
        } },
        { version = "1.2.0", lines = {
            "Fill an icon with your power or its time left.",
            "Pick a tint over the icon or a thin bar under it, draining or rising.",
            "\"Always\", \"While it's cooling down\" and \"While it's active\" can fill it.",
            "It works in a fight: the game draws the number.",
        } },
        { version = "1.1.0", lines = {
            "One line can do several things: \"When I can't cast it, glow and pulse it.\"",
            "Click \"and …\" after what happens to add up to three actions.",
            "Lines with the same moment now read as one sentence. They work as before.",
            "Right-click one action to take just that one away.",
        } },
        { version = "1.0.0", lines = {
            "Join conditions with \"and\": \"When it's ready and I'm in combat, glow.\"",
            "New conditions: target, range, health, power, forms, totems, weapon buffs.",
            "Nine new looks, from a pulse or a halo to a flare around you.",
            "Every condition but health and power can play a sound.",
            "\"When I can't cast it\" now means any reason. Old lines read \"not usable\".",
            "Comet and Shine glows become Circling and Ring. Glows are bigger and brighter.",
            "Right-click a chosen word to clear it.",
        } },
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

-- A phrase with its power name (%s) and number (#) put in: the powers a piece's spell
-- costs (kind.power), else the player's own. A "%" after the number stays as it is.
local function fill(phrase, n, kind)
    if phrase:find("%s", 1, true) then
        local power = type(kind) == "table" and kind.power or Grammar.PowerName()
        phrase = phrase:gsub("%%s", (power:gsub("%%", "%%%%")))
    end
    return (phrase:gsub(Grammar.NUMBER_MARK, n ~= nil and tostring(n) or "N"))
end

-- A phrase in a piece's own words: "buff" reads "debuff" on a piece whose aura is a
-- debuff on an enemy (kind.aura). kind nil keeps the phrase.
local function forKind(phrase, kind)
    if type(kind) == "table" and kind.aura == "debuff" then
        return (phrase:gsub("%f[%a]buff%f[%A]", "debuff"))
    end
    return phrase
end
Grammar.ForKind = forKind

-- A moment's phrase and what joins it to the action (", " or " "). A moment not
-- picked yet reads as its blank. n is a typed number, "N" on a chip when nil.
function Grammar.MomentWords(moment, n, kind)
    if moment == nil then return WORDING.chooseMoment, ", " end
    local plain = type(kind) == "table" and kind.noCooldown and WORDING.momentsPlain[moment]
    local totem = type(kind) == "table" and kind.totemTime and WORDING.momentsTotem[moment]
    local phrase = totem or plain or WORDING.moments[moment]
    if not phrase then return tostring(moment), " " end
    return forKind(fill(phrase, n, kind), kind), WORDING.noComma[moment] and " " or ", "
end

-- An action's word at a moment: "glow", or "glow until it's back" when a buff wears off.
function Grammar.ActionWords(moment, action)
    local at = WORDING.actionsAt[moment]
    return at and at[action] or WORDING.actions[action] or tostring(action)
end

-- Every action's word at a moment, by action key.
function Grammar.ActionNames(moment)
    local out = {}
    for a in pairs(WORDING.actions) do out[a] = Grammar.ActionWords(moment, a) end
    return out
end

-- A condition's clause phrase ("my target is a boss"), n as in MomentWords.
function Grammar.ClauseWords(key, n, kind)
    local phrase = WORDING.clauses[key]
    if not phrase then return tostring(key) end
    return forKind(fill(phrase, n, kind), kind)
end

-- Why conditions a and b can never both be true, as words: their own reason, or
-- the layer clash; nil when they can.
function Grammar.NeverWords(a, b, kind)
    if not Conditions.Excludes(a, b) then return nil end
    local why = (WORDING.never[a] or {})[b] or (WORDING.never[b] or {})[a]
    if not why then
        local plain = type(kind) == "table" and kind.noCooldown
        return forKind(plain and WORDING.layerClashPlain or WORDING.layerClash, kind)
    end
    return WORDING.neverBoth:format(fill(why, nil, kind))
end

-- The note on a piece Daylight UI's Proc Alerts lists; nil on any other.
function Grammar.ProcAlertNote(kind)
    if type(kind) == "table" and kind.procAlert then return WORDING.procAlertNote end
    return nil
end

-- A one-click fix's words (Grammar.HiddenNote) for a piece.
function Grammar.FixText(fix, kind)
    if fix == "shows" then
        return type(kind) == "table" and kind.noCooldown and WORDING.fixShowsPlain or WORDING.fixShows
    end
    if fix == "clause" then return forKind(WORDING.fixClause, kind) end
    return tostring(fix)
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

-- What it shows as a phrase for a piece: cooldown words only where it has one.
function Grammar.ShowsPhrase(shows, kind)
    local t = type(kind) == "table" and kind.noCooldown and WORDING.showsPlain or WORDING.shows
    return forKind(t[shows] or tostring(shows), kind)
end

-- What it shows as a sentence: "Show its buff."
function Grammar.ShowsWords(shows, kind)
    local w = Grammar.ShowsPhrase(shows, kind)
    return w:sub(1, 1):upper() .. w:sub(2) .. "."
end

local function percent(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end

-- A sound key's name in Daylight UI's list, or the key.
local function soundName(key)
    local values = Bridge.SoundChoices()
    local name = type(values) == "table" and values[key]
    return type(name) == "string" and name or tostring(key)
end

-- A flash line's color (nil for the accent) and whether it repeats.
function Grammar.FlashPicks(v)
    local L = ns.Looks
    if L and L.FlashPicks then return L.FlashPicks(v) end
    return nil, false
end

-- A flare line's design, animation and sound: its own, else Proc Alerts' (sound nil).
function Grammar.FlarePicks(v)
    local L = ns.Looks
    v = type(v) == "table" and v or {}
    return v.design or L.FLARE_DESIGN, v.anim or L.FLARE_ANIM, v.sound
end

-- A fill line's source, shape, direction and color: its own, else the defaults
-- (Looks.FillPicks).
function Grammar.FillPicks(v, kind, line)
    local L = ns.Looks
    if L and L.FillPicks then
        local ck = kind and type(line) == "table" and Grammar.LineCondition(line, kind)
        return L.FillPicks(v, kind, ck and Conditions.LineLayer(ck, { clauses = line.clauses }) or "any")
    end
    v = type(v) == "table" and v or {}
    return v.source, v.shape, v.dir, v.color
end

-- A fill source's words on a piece: "my health", "my mana".
function Grammar.FillSourceWords(source, kind)
    local w = WORDING.fillSources[source]
    if not w then return tostring(source) end
    return fill(w, nil, kind)
end

-- Whether a line about layer has a clock time left can run on: a buff Daylight UI
-- clocks, a totem's own time, or a real cooldown (Looks.lua's faces).
local function timeFits(kind, layer)
    if layer ~= "cooldown" and kind.clocked then return true end
    if layer ~= "buff" and (kind.totemTime or kind.cooldownReady) then return true end
    return false
end

-- What a fill line may fill with on kind, in Looks.FILL_SOURCES order, and those left
-- out with why ({ { key, why } }, for the strip): my power where the spell costs a bar your class has, time left
-- where a clock runs for the line's icon. A buff with no clock in a fight (a proc,
-- or one you never cast), one that never wears off and a debuff say why.
function Grammar.FillSources(kind, line)
    kind = type(kind) == "table" and kind or {}
    local ck = type(line) == "table" and Grammar.LineCondition(line, kind)
    return Grammar.FillSourcesAt(kind, ck and Conditions.LineLayer(ck, { clauses = line.clauses }) or "any")
end

-- The same for a line about layer ("cooldown", "buff" or "any").
function Grammar.FillSourcesAt(kind, layer)
    local keys, refused = {}, {}
    local L = ns.Looks
    kind = type(kind) == "table" and kind or {}
    for _, src in ipairs(L and L.FILL_SOURCES or {}) do
        local fits = true
        if src == "power" then fits = kind.lowPower == true
        elseif src == "time" then
            fits = timeFits(kind, layer)
            if not fits and layer ~= "cooldown" and kind.showsBuff then
                local why = (kind.untimed and WORDING.fillNever.untimed)
                    or (kind.aura == "debuff" and WORDING.fillNever.target) or WORDING.fillNever.hidden
                refused[#refused + 1] = { key = src, why = why }
            end
        end
        if fits then keys[#keys + 1] = src end
    end
    return keys, refused
end

-- A glow style key's name, the card's label, or the key.
local function styleName(key)
    for _, st in ipairs(Bridge.GlowStyles() or {}) do
        if st.key == key then return st.label end
    end
    return tostring(key)
end
Grammar.StyleName = styleName

local function actionWords(line, kind)
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
    local valued = Grammar.ValueKind(line.moment, a)
    if valued == "color" and line.value then return Grammar.ActionWords(line.moment, a) .. " in " .. WORDING.picked end
    if valued == "text" and type(line.value) == "string" then return WORDING.textShown:format(line.value) end
    if valued == "icon" and line.value ~= nil then return Grammar.ActionWords(line.moment, a) .. " for " .. WORDING.iconPicked end
    if valued == "flash" then
        local color, again = Grammar.FlashPicks(line.value)
        local out = Grammar.ActionWords(line.moment, a)
        if again then out = out .. " " .. WORDING.flashRepeats.again end
        if color then out = out .. " in " .. WORDING.picked end
        return out
    end
    if valued == "fill" then
        local source, shape, dir, color = Grammar.FillPicks(line.value, kind, line)
        local out = string.format("%s %s (%s, %s)", Grammar.ActionWords(line.moment, a),
            Grammar.FillSourceWords(source, kind), WORDING.fillShapes[shape] or shape, WORDING.fillDirs[dir] or dir)
        if color == "shift" then
            out = out .. " in " .. WORDING.fillShift
        elseif color then
            out = out .. " in " .. WORDING.picked
        end
        return out
    end
    if valued == "flare" then
        local d, anim, sound = Grammar.FlarePicks(line.value)
        return string.format("%s (%s, %s, %s)", Grammar.ActionWords(line.moment, a), WORDING.flareDesigns[d] or d,
            WORDING.flareAnims[anim] or anim, sound and soundName(sound) or WORDING.flareSound)
    end
    if a == "numbers" then
        local out = WORDING.actions.numbers
        if line.value then out = out .. " in " .. WORDING.picked end
        if line.at then out = out .. " " .. WORDING.lastSeconds .. " " .. Grammar.Seconds(line.at) end
        return out
    end
    if a == "sound" then return string.format("play \"%s\"", soundName(line.value)) end
    return Grammar.ActionWords(line.moment, a)
end

-- The fall-off lead as words: "(5 seconds before)".
function Grammar.LeadWords(n) return WORDING.lead:format(Grammar.Seconds(n)) end

-- A line's moment, lead and clauses as words, capitalized, and its joint.
local function momentPart(line, kind)
    local ck = Grammar.LineCondition(line, kind)
    local phrase, joint = Grammar.MomentWords(line.moment, ck and Conditions.NumberOf(ck, line.n), kind)
    local entry = MAP[line.moment] and MAP[line.moment][line.action]
    if entry and entry.lead and line.at ~= nil then phrase = phrase .. " " .. Grammar.LeadWords(line.at) end
    for _, cl in ipairs(ck and type(line.clauses) == "table" and line.clauses or {}) do
        local key = type(cl) == "table" and cl.cond
        phrase = phrase .. " " .. WORDING.andWord .. " " .. Grammar.ClauseWords(key, Conditions.NumberOf(key, cl.n), kind)
    end
    return phrase:sub(1, 1):upper() .. phrase:sub(2), joint
end

-- "A", "A and B", "A, B, and C".
local function listOf(words)
    if #words <= 2 then return table.concat(words, " " .. WORDING.andWord .. " ") end
    return table.concat(words, ", ", 1, #words - 1) .. ", " .. WORDING.andWord .. " " .. words[#words]
end
Grammar.ListWords = listOf

-- The line as one sentence, in US English, in a piece's own words when kind is given.
function Grammar.Describe(line, kind)
    if type(line) ~= "table" then return "" end
    local phrase, joint = momentPart(line, kind)
    return phrase .. joint .. actionWords(line, kind) .. "."
end

-- ---------------------------------------------------------------------
-- Several actions on one line: "When I can't cast it, pulse it and glow."
-- ---------------------------------------------------------------------

-- A line with several actions is the lines that share its moment, number and
-- clauses, one per action, each with its own picks. They save and compile as lines
-- of one action each, so Daylight UI's own actions (show, fade, hide, its glow and
-- sound) keep their fields and EZ-CDM's keep theirs. Grammar.Rows joins them for
-- the drawer and the sentence; Grammar.LineActions says what may join one.

-- The most actions one line holds.
Grammar.MAX_ACTIONS = 3

-- Two actions that can't both show on one line though they set different things:
-- the gray and the icon swap each lay a copy over the icon (Overlay.lua).
Grammar.NEVER_ACTIONS = { { "gray", "swap" } }

-- Actions that show off the piece, so "hide it" leaves them be: a sound, the screen's
-- edge, the flare around the character.
Grammar.OFF_PIECE = { sound = true, screen = true, flare = true }

-- The spell field a line sets, or nil.
local function fieldOf(line)
    local c = Grammar.Canonical(line)
    local e = MAP[c.moment] and MAP[c.moment][c.action]
    return e and (e.field or e.paint) or nil
end

-- A part's number as it reads: its own, else its condition's default.
local function partNumber(key, n)
    if Conditions.Get(key) and Conditions.Get(key).param then return Conditions.NumberOf(key, n) end
    return n
end

-- What a line shares with the other actions of its line: moment, number and
-- clauses, as text. nil for a line with no action yet, which stands alone.
function Grammar.RowKey(line)
    if type(line) ~= "table" or line.action == nil then return nil end
    local mk = Grammar.MomentCondition(line.moment)
    local out = { tostring(line.moment), tostring(mk and partNumber(mk, line.n) or line.n) }
    for _, cl in ipairs(type(line.clauses) == "table" and line.clauses or {}) do
        local c = type(cl) == "table" and cl.cond
        out[#out + 1] = tostring(c) .. "=" .. tostring(c and partNumber(c, cl.n))
    end
    return table.concat(out, "|")
end

-- Where an action reads in its line: the action words' order, a sound last.
local function actionRank(a)
    if a == "sound" then return #Grammar.ACTIONS + 1 end
    return indexOf(Grammar.ACTIONS, a) or #Grammar.ACTIONS
end

-- lines in rows, each the indexes of one line's actions in reading order, rows in
-- the order of their first line. A line kind can't show stands alone.
function Grammar.Rows(lines, kind)
    local rows, byKey = {}, {}
    for i, l in ipairs(type(lines) == "table" and lines or {}) do
        local key = Grammar.RowKey(l)
        if key and kind ~= nil and not fits(kind, l.moment, l.action) then key = nil end
        local row = key and byKey[key]
        if row then
            row[#row + 1] = i
        else
            row = { i }
            rows[#rows + 1] = row
            if key then byKey[key] = row end
        end
    end
    for _, row in ipairs(rows) do
        table.sort(row, function(a, b)
            local ra, rb = actionRank(lines[a].action), actionRank(lines[b].action)
            if ra ~= rb then return ra < rb end
            return a < b
        end)
    end
    return rows
end

-- The line of several actions as one sentence: "When it's ready, glow and pulse it."
function Grammar.DescribeRow(lines, kind)
    if type(lines) ~= "table" or #lines == 0 then return "" end
    local phrase, joint = momentPart(lines[1], kind)
    local said = {}
    for i, l in ipairs(lines) do said[i] = actionWords(l, kind) end
    return phrase .. joint .. listOf(said) .. "."
end

-- Whether two actions can never both show on one line: they set the same thing
-- (show and hide, gray and keep its color), or Grammar.NEVER_ACTIONS pairs them.
local function actionsClash(a, b)
    if a.action == b.action then return true end
    local fa, fb = family(a), family(b)
    if fa ~= nil and fa == fb then return true end
    -- Hidden, the piece shows nothing drawn on it.
    local off = Grammar.OFF_PIECE
    if (a.action == "hide" and not off[b.action]) or (b.action == "hide" and not off[a.action]) then return true end
    -- One hides the other's look (HIDDEN_BY: the sweep's color with no sweep).
    local ea, eb = fieldOf(a), fieldOf(b)
    for _, h in ipairs(HIDDEN_BY) do
        if (ea == h.glow and eb == h.hide) or (eb == h.glow and ea == h.hide) then return true end
    end
    for _, p in ipairs(Grammar.NEVER_ACTIONS) do
        if (p[1] == a.action and p[2] == b.action) or (p[1] == b.action and p[2] == a.action) then return true end
    end
    return false
end
Grammar.ActionsClash = actionsClash

-- The line's client part, or nil: a client condition as its moment or its last clause.
local function clientPart(line, kind)
    local ck = Grammar.ClauseRoot(line, kind) or Grammar.MomentCondition(line.moment)
    local c = ck and Conditions.Get(ck)
    if c and c.secrecy == "client" then return ck, nil end
    local cls = type(line.clauses) == "table" and line.clauses or {}
    local last = cls[#cls]
    c = type(last) == "table" and Conditions.Get(last.cond)
    if c and c.secrecy == "client" then return last.cond, last.n end
end

-- The actions that may join a line, row (its lines, in reading order), on kind, in
-- action order, and those left out with why: { { action, why } }. Each fits the
-- moment, isn't on the line yet, can both show with every action on it, takes the
-- line's clauses, can follow its client part, and no other line in all (the piece's
-- lines) does it at this moment. None once the line holds MAX_ACTIONS.
function Grammar.LineActions(kind, row, all)
    local keys, refused = {}, {}
    local first = type(row) == "table" and row[1]
    if type(first) ~= "table" or first.moment == nil or #row >= Grammar.MAX_ACTIONS then return keys, refused end
    local mine = {}
    for _, l in ipairs(row) do mine[l] = true end
    local clauses = type(first.clauses) == "table" and #first.clauses > 0
    local ck, cn = clientPart(first, kind)
    for _, a in ipairs(Grammar.ACTIONS) do
        local here = false
        for _, l in ipairs(row) do here = here or l.action == a end
        if not here and fits(kind, first.moment, a) then
            local probe = { moment = first.moment, action = a, n = first.n, clauses = first.clauses }
            local why
            for _, l in ipairs(row) do
                if not why and actionsClash(l, probe) then
                    why = WORDING.neverAction:format(Grammar.ActionWords(l.moment, l.action),
                        Grammar.ActionWords(probe.moment, a))
                end
            end
            local root = Grammar.ClauseRoot(probe, kind)
            if not why and clauses and not root then why = WORDING.neverClauses end
            if not why and ck and not (root and Conditions.ClientSafe(root, a)) then
                why = WORDING.neverSecret:format(Grammar.ClauseWords(ck, Conditions.NumberOf(ck, cn), kind))
            end
            if not why then
                local fam = family(Grammar.Canonical(probe, kind))
                for _, l in ipairs(type(all) == "table" and all or {}) do
                    if not why and not mine[l] and type(l) == "table" and l.moment ~= nil and l.action ~= nil
                        and family(Grammar.Canonical(l, kind)) == fam then
                        why = WORDING.neverTaken
                    end
                end
            end
            if why then refused[#refused + 1] = { action = a, why = why } else keys[#keys + 1] = a end
        end
    end
    return keys, refused
end

-- Whether a line of several actions can take an "and" part: each of its actions can.
function Grammar.RowTakesClauses(row, kind)
    if type(row) ~= "table" or #row == 0 then return false end
    for _, l in ipairs(row) do
        if not Grammar.TakesClauses(l, kind) then return false end
    end
    return true
end

-- The conditions a line of several actions may take as its next "and" part: those
-- every action's line may take (Grammar.Clauses). Refused: the never-both ones, and
-- a client one some action can't follow, with why.
function Grammar.RowClauses(kind, row, opts)
    if not Grammar.RowTakesClauses(row, kind) then return {}, {} end
    local each, any = {}, {}
    for i, l in ipairs(row) do
        each[i] = {}
        for _, k in ipairs(Grammar.Clauses(kind, l, opts)) do
            each[i][k] = true
            any[k] = true
        end
    end
    local keys, refused = {}, Grammar.ClauseRefusals(kind, row[1], opts)
    for _, c in ipairs(Conditions.List()) do
        if any[c.key] then
            local out
            for i, l in ipairs(row) do
                if not out and not each[i][c.key] then out = l end
            end
            if out then
                refused[#refused + 1] = { cond = c.key,
                    why = WORDING.neverOther:format(Grammar.ActionWords(out.moment, out.action)) }
            else
                keys[#keys + 1] = c.key
            end
        end
    end
    return keys, refused
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
-- and recast never lights on a known "missing" (CdmEffects.lua:512-517).
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
