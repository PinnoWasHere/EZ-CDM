local stub = require("stub")
local CW = require("cdmworld")

-- One class logged in, built from the game's data: the Cooldown Manager catalogue
-- (tests/cooldown_sets.lua), Daylight UI's class spell lists (CdmSpells.lua), the
-- client's spell flags (tests/spell_facts.lua) and EZ-CDM's aura links
-- (EZ-CDM/AuraLinks.lua). The every-class sweep (sweep_lib) and the bug
-- report repro (tests/repro_world.lua) both stand on it.
--
--     local W = require("classworld")
--     local w = W.Build("MAGE", { hidden = true })
--     w.Cast(12051); w.Advance(2); w.BuffUp(12536); w.EnterCombat()
--
-- W.World is the bare login. W.Build adds the drivers a test or a repro acts with.

local W = {}

W.ESSENTIAL, W.UTILITY, W.BUFFS, W.BARS = 0, 1, 2, 3
-- A stand-in item with a use (Healthstone) and a spell on no class list (Mana Spring),
-- added the way the tray's Add by ID adds them.
W.ITEM, W.ITEM_SPELL = 5512, 6262
W.ADDED_SPELL = 5677

-- The power each class's "short" word names (Grammar.PowerName).
W.POWER = {
    WARRIOR = { 1, "RAGE", "Rage" }, ROGUE = { 3, "ENERGY", "Energy" },
}
-- Classes with a pet piece (CdmCustom.PETS).
W.PET = { HUNTER = true, WARLOCK = true }

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end
W.copy = copy

function W.pass(AB)
    AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
end

-- ---------------------------------------------------------------------
-- The game's data
-- ---------------------------------------------------------------------

-- Daylight UI's class spell lists (CdmSpells.lua), with each family's name from
-- its comment: { CLASS = { { ids = {...}, name = "..." } } }.
local families
function W.Families()
    if families then return families end
    families = {}
    local fh = assert(io.open(stub.DUI_ROOT .. "DaylightUI_ActionBars/CdmSpells.lua", "rb"))
    local text = fh:read("*a")
    fh:close()
    local cur
    for line in text:gmatch("[^\n]+") do
        local head = line:match("^    (%u+) = {%s*$")
        if head then
            cur = head
            families[cur] = {}
        elseif line:match("^}") or line:match("^S%.") then
            cur = nil
        elseif cur then
            local body, name = line:match("^%s+{%s*(.-)%s*},%s*%-%-%s*(.-)%s*$")
            if body then
                local ids = {}
                for tok in body:gmatch("[^,]+") do
                    local n = tok:match("^%s*(%d+)%s*$")
                    if n then ids[#ids + 1] = tonumber(n) end
                end
                if #ids > 0 then families[cur][#families[cur] + 1] = { ids = ids, name = name } end
            end
        end
    end
    return families
end

-- The catalogue's class sets: { { set, class, rows, shared } }, one per set of 20
-- rows or more (the race sets hold a few each), its class the one whose Daylight UI
-- list shares the most spells with it. Sorted by class.
local classes
function W.Classes()
    if classes then return classes end
    local bySet = {}
    for _, r in ipairs(CW.Catalogue()) do
        bySet[r.set] = bySet[r.set] or {}
        table.insert(bySet[r.set], r)
    end
    local fam = W.Families()
    classes = {}
    for set, rows in pairs(bySet) do
        if #rows >= 20 then
            local spells = {}
            for _, r in ipairs(rows) do
                spells[r.spell] = true
                for _, id in ipairs(r.links) do spells[id] = true end
            end
            local best, bestN = nil, 0
            for class, list in pairs(fam) do
                if class ~= "GROUP" then
                    local n = 0
                    for _, f in ipairs(list) do
                        for _, id in ipairs(f.ids) do if spells[id] then n = n + 1 end end
                    end
                    if n > bestN then best, bestN = class, n end
                end
            end
            classes[#classes + 1] = { set = set, class = best, rows = rows, shared = bestN }
        end
    end
    table.sort(classes, function(a, b) return a.class < b.class end)
    return classes
end

function W.Class(name)
    for _, c in ipairs(W.Classes()) do
        if c.class == name then return c end
    end
end

-- EZ-CDM's shipped aura links (EZ-CDM/AuraLinks.lua), read outside the game.
local links
function W.Links()
    if links then return links end
    local ns = {}
    assert(loadfile((stub.PLUGIN_TOC:match("^(.*/)") or "") .. "AuraLinks.lua"))("EZ-CDM", ns)
    links = ns.AuraLinks
    return links
end

-- What the client's tables say of each catalogue spell and linked spell:
-- { [id] = { passive, book, harmful } } (tests/spell_facts.lua, made with the links).
local facts
function W.Facts()
    facts = facts or dofile(require("ez_harness").TESTS .. "spell_facts.lua")
    return facts
end

-- ---------------------------------------------------------------------
-- The login
-- ---------------------------------------------------------------------

-- One class logged in with every catalogue spell and every Daylight UI class spell
-- known. c is a W.Class entry. Returns DUI, EZ-CDM's ns, the action bars' ns.
--   opts.hidden   hides the game's buff viewers
--   opts.db       { dui, ez }: the saved variables of an earlier session (a /reload)
--   opts.patch    fn(ns), run once EZ-CDM loads, before login
--   opts.known    { [id] = true or false }: the game's IsPlayerSpell for these ids,
--                 over the stand-in below (a bug report's answers)
--   opts.passive  { [id] = true }: more ids IsSpellPassive says yes to
function W.World(c, opts)
    opts = opts or {}
    local fam = W.Families()
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        -- No form and out of stealth until w.Form; no spell checks range until w.HasRange.
        _G.GetShapeshiftFormInfo = function() return nil end
        _G.IsStealthed = function() return false end
        C_Spell.SpellHasRange = function() return false end
        C_Spell.EnableSpellRangeCheck = function() end
        local power = W.POWER[c.class] or { 0, "MANA", "Mana" }
        _G[power[2]] = power[3]
        stub.SetUnits({ player = { name = "Me", class = c.class, friend = true, powerType = power[1],
                                   powerToken = power[2] },
                        target = { name = "Boar", reaction = 2 },
                        pet = W.PET[c.class] and { name = "Fang" } or nil })
        local known, seen = {}, {}
        local function know(id)
            if not seen[id] then seen[id] = true; known[#known + 1] = id end
        end
        for _, r in ipairs(c.rows) do
            know(r.spell)
            for _, id in ipairs(r.links) do know(id) end
        end
        CW.Install({ set = c.set, known = known, showAll = true })
        -- The game's recast answers, as on Forever (Grammar.Casts), approximated from
        -- the client's spell tables, since the fake game has no spellbook.
        --   IsSpellPassive  SpellMisc's passive flag (tests/spell_facts.lua)
        --   IsPlayerSpell   any known spell but a proc's aura: one SkillLineAbility
        --                   doesn't list, one the aura links say a known spell puts
        --                   up, or one of a buff row whose own spell is passive, as
        --                   Improved Stormstrike's buff (test_effects). A passive
        --                   spell stays known.
        for _, r in ipairs(c.rows) do
            for _, id in ipairs({ r.spell, unpack(r.links) }) do
                stub.knownSpells[id] = true
                stub.spells[id] = stub.spells[id] or { name = r.name }
            end
            for _, id in ipairs(r.linkAuras) do stub.spells[id] = stub.spells[id] or { name = r.name } end
        end
        for _, f in ipairs(fam[c.class] or {}) do
            for _, id in ipairs(f.ids) do
                stub.knownSpells[id] = true
                stub.spells[id] = stub.spells[id] or { name = f.name }
            end
        end
        local info, passive, notMine = W.Facts(), {}, {}
        for id, f in pairs(info) do
            passive[id] = f.passive or nil
            if not f.book then notMine[id] = true end
        end
        for id in pairs(opts.passive or {}) do passive[id] = true end
        for id, sources in pairs(W.Links().byAura) do
            for _, s in ipairs(sources) do
                if stub.knownSpells[s] then notMine[id] = true end
            end
        end
        for _, r in ipairs(c.rows) do
            if (r.category == W.BUFFS or r.category == W.BARS) and passive[r.spell] then
                for _, id in ipairs(r.links) do notMine[id] = true end
                for _, id in ipairs(r.linkAuras) do notMine[id] = true end
            end
        end
        -- IsSpellHarmful: the client's own answer, from the SpellEffect targets
        -- (tests/spell_facts.lua), asked of each id the way the game is.
        local harmfulIds = {}
        for id, f in pairs(info) do harmfulIds[id] = f.harmful or nil end
        -- Ids the client has no effects for (Daylight UI's aura ids for Polymorph) take
        -- the answer of the spell the row casts.
        for _, r in ipairs(c.rows) do
            if harmfulIds[r.spell] then
                for _, id in ipairs(r.links) do harmfulIds[id] = true end
                for _, id in ipairs(r.linkAuras) do harmfulIds[id] = true end
            end
        end
        local passiveKeep, playerKeep = C_Spell.IsSpellPassive, rawget(_G, "IsPlayerSpell")
        local harmfulKeep = C_Spell.IsSpellHarmful
        local told = opts.known or {}
        C_Spell.IsSpellHarmful = function(id) return harmfulIds[id] == true end
        C_Spell.IsSpellPassive = function(id) return passive[id] == true end
        _G.IsPlayerSpell = function(id)
            if told[id] ~= nil then return told[id] end
            return stub.knownSpells[id] == true and (passive[id] == true or not notMine[id])
        end
        stub.onReset = stub.onReset or {}
        stub.onReset[#stub.onReset + 1] = function()
            C_Spell.IsSpellPassive, _G.IsPlayerSpell = passiveKeep, playerKeep
            C_Spell.IsSpellHarmful = harmfulKeep
        end
        for _, f in ipairs(fam.GROUP or {}) do
            for _, id in ipairs(f.ids) do stub.spells[id] = stub.spells[id] or { name = f.name } end
        end
        -- The game has these; the fake game leaves them to each test.
        local spellKeep = C_Spell.GetSpellTexture
        C_Spell.GetSpellTexture = spellKeep or function(id) return id end
        stub.onReset[#stub.onReset + 1] = function()
            C_Spell.GetSpellTexture = spellKeep
            C_Item.GetItemSpell, C_Item.GetItemNameByID, C_Item.IsItemDataCachedByID, C_Item.IsUsableItem = nil, nil, nil, nil
        end
        -- An enchant on the main hand, none on the off hand.
        stub.weaponEnchants = { { slot = 0, timeLeft = 1800000, enchantID = 19 } }
        stub.spells[W.ITEM_SPELL] = { name = "Healthstone" }
        stub.spells[W.ADDED_SPELL] = { name = "Mana Spring" }
        -- The item's game answers, as the client gives them once its data is in.
        stub.SetItems({ [W.ITEM] = { id = W.ITEM, icon = 135230, class = 0 } })
        C_Item.GetItemSpell = function(item) if item == W.ITEM then return "Healthstone", W.ITEM_SPELL end end
        C_Item.GetItemNameByID = function(item) if item == W.ITEM then return "Healthstone" end end
        C_Item.IsItemDataCachedByID = function() return true end
        C_Item.IsUsableItem = function() return true, false end
        if opts.db then
            DaylightUIDB = copy(opts.db.dui)
            EZCDMDB = copy(opts.db.ez)
        end
    end })
    if opts.patch then opts.patch(ns) end
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    DUI.DB.General().motion = true
    local AB = stub.actionbars
    if opts.hidden then
        CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    end
    W.pass(AB)
    return DUI, ns, AB
end

-- ---------------------------------------------------------------------
-- The world with drivers
-- ---------------------------------------------------------------------

-- The client's build and spec answers a bug report reads (Report.Collect). The
-- fake game has neither; they go in after login, so no load-time check sees them.
local function client(spec)
    local buildKeep, specKeep = rawget(_G, "GetBuildInfo"), rawget(_G, "C_SpecializationInfo")
    _G.GetBuildInfo = function() return "1.60.1", "71037", "Nov 1 2026", 16001 end
    _G.C_SpecializationInfo = { GetSpecialization = function() return spec end }
    stub.onReset[#stub.onReset + 1] = function()
        _G.GetBuildInfo, _G.C_SpecializationInfo = buildKeep, specKeep
    end
end

-- class is a token ("MAGE") or a W.Class entry. opts as W.World, plus
-- opts.spec, the spec index the client reports (1 when nil). Returns a world:
--   w.DUI, w.ns, w.AB, w.c       what W.World made, and the class entry
--   w.Pass()                     Daylight UI's placement pass
--   w.Cast(id)                   your cast succeeds
--   w.Cooldown(id, s) / w.Ready(id)   the spell goes on cooldown for s seconds / off it
--   w.BuffUp(id, o) / w.BuffDown(id)  its aura lands (o.unit, o.duration) / is gone;
--                                the holders that answer to id show it in a button
--   w.Proc(id, s)                a proc's aura lands on you for s seconds
--   w.Refresh(id)                a recast while the aura is up: cast, aura again
--   w.KillTarget() / w.NewTarget()    the target dies and is cleared / a fresh one
--   w.Usable(can, noPower)       the game's IsSpellUsable for every spell, then its event
--   w.Unit(unit, fields)         sets a unit's fields (pct, boss, casting, dead...) and
--                                fires what a condition on it hears; a value may be
--                                stub.Secret(v), as in a fight
--   w.Tick(n)                    the shared ticker's beat n times (Conditions.Tick)
--   w.EnterCombat() / w.LeaveCombat()
--   w.Advance(s)                 time passes; timers and a pass run
--   w.Reload(opts)               a /reload with this session's saved variables
--   w.Row(id)                    the catalogue row of a spell, or nil
-- What fires each game event a condition hears, and each Daylight UI watch moment,
-- in a world from W.Build. Every registered condition's events need one here
-- (test_w1fixes coverage).
W.EVENT_DRIVERS = {
    SPELL_UPDATE_USABLE = function(w) w.Usable(true, false) end,
    SPELL_UPDATE_COOLDOWN = function(w)
        local id = w.c.rows[1] and w.c.rows[1].spell
        w.Cooldown(id, 8)
        w.Ready(id)
    end,
    PLAYER_TARGET_CHANGED = function(w) w.NewTarget() end,
    UNIT_HEALTH = function(w) w.Unit("player", {}) end,
    UNIT_POWER_UPDATE = function(w) w.Unit("player", {}) end,
    UNIT_FLAGS = function(w) w.Unit("target", {}) end,
    UNIT_FACTION = function(w) w.Unit("target", {}) end,
    UNIT_CLASSIFICATION_CHANGED = function(w) w.Unit("target", {}) end,
    SPELL_RANGE_CHECK_UPDATE = function(w) w.Range(true) end,
    UNIT_SPELLCAST_START = function(w) w.TargetCasts("cast") end,
    UNIT_SPELLCAST_STOP = function(w) w.TargetCasts(nil) end,
    UNIT_SPELLCAST_FAILED = function(w) w.TargetCasts(nil, "FAILED") end,
    UNIT_SPELLCAST_INTERRUPTED = function(w) w.TargetCasts(nil, "INTERRUPTED") end,
    UNIT_SPELLCAST_CHANNEL_START = function(w) w.TargetCasts("channel") end,
    UNIT_SPELLCAST_CHANNEL_STOP = function(w) w.TargetCasts(nil, "CHANNEL_STOP") end,
    UNIT_SPELLCAST_SUCCEEDED = function(w) w.Cast(w.c.rows[1].spell) end,
    UPDATE_SHAPESHIFT_FORM = function(w) w.Form(nil) end,
    UPDATE_SHAPESHIFT_FORMS = function(w) w.Form(nil) end,
    UPDATE_STEALTH = function(w) w.Form(nil) end,
    PLAYER_TOTEM_UPDATE = function(w) w.Totem(1, nil) end,
    UNIT_AURA = function(w) w.BuffUp(w.c.rows[1].spell, { unit = "player" }) end,
    WEAPON_ENCHANT_CHANGED = function(w) w.Enchant({}) end,
    PLAYER_EQUIPMENT_CHANGED = function(w) w.Enchant({}) end,
    UNIT_INVENTORY_CHANGED = function(w) w.Enchant({}) end,
    PLAYER_REGEN_DISABLED = function(w) w.EnterCombat() end,
    PLAYER_REGEN_ENABLED = function(w) w.EnterCombat(); w.LeaveCombat() end,
    GROUP_ROSTER_UPDATE = function(w) w.Group(false) end,
    PLAYER_ENTERING_WORLD = function(w) w.Instance(nil) end,
    ZONE_CHANGED_NEW_AREA = function(w) w.Instance(nil) end,
}
W.HANDLER_DRIVERS = {
    changed = function(w) w.Usable(true, false) end,
    ready = function(w) local id = w.c.rows[1].spell; w.Cooldown(id, 8); w.Ready(id) end,
    started = function(w) w.Cooldown(w.c.rows[1].spell, 8) end,
    usable = function(w) w.Usable(false, false); w.Usable(true, false) end,
    buffUp = function(w, id) w.BuffUp(id) end,
    buffDown = function(w, id) w.BuffDown(id) end,
    proc = function(w, id) w.Proc(id) end,
}

function W.Build(class, opts)
    opts = opts or {}
    local c = type(class) == "table" and class or assert(W.Class(class), tostring(class))
    local w = { c = c }
    local function login(o)
        w.DUI, w.ns, w.AB = W.World(c, o)
        client(opts.spec or 1)
        -- The range checks EZ-CDM turns on, and the spells only the GCD holds (w.Gcd).
        w.rangeChecks, w.gcd = {}, {}
        C_Spell.EnableSpellRangeCheck = function(id, on) w.rangeChecks[id] = on end
        local cooldown = C_Spell.GetSpellCooldown
        C_Spell.GetSpellCooldown = function(id)
            local info = cooldown(id)
            if not w.gcd[id] then return info end
            local out = {}
            for k, v in pairs(type(info) == "table" and info or {}) do out[k] = v end
            out.isActive, out.isOnGCD = true, true
            return out
        end
    end
    login(opts)
    local casts = 0
    local function run() for _ = 1, 3 do stub.RunTimers() end end
    function w.Pass() W.pass(w.AB) end
    function w.Row(id)
        for _, r in ipairs(c.rows) do
            if r.spell == id then return r end
            for _, x in ipairs(r.links) do if x == id then return r end end
            for _, x in ipairs(r.linkAuras) do if x == id then return r end end
        end
    end
    function w.Cast(id)
        casts = casts + 1
        stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-" .. casts, id)
        run()
    end
    function w.Cooldown(id, s) CW.Cooldown(id, s or 8); run() end
    function w.Ready(id) CW.Cooldown(id, nil); run() end
    -- The client's aura buttons don't follow auras in the fake game: the first
    -- button of each placed holder that answers to id takes it, as the client would.
    local assigned = {}
    local function assign(id, on)
        if not on then
            for _, btn in ipairs(assigned[id] or {}) do stub.AuraAssign(btn, false) end
            assigned[id] = nil
            return
        end
        local B = w.ns.Bridge
        for key in pairs(w.AB.CdmData.Get(1).pieces) do
            local ids = B.SpellIDs(key)
            local h = type(ids) == "table" and ids[id] and w.AB.CdmAuras.Frame(key)
            local btn = h and h.buttons and h.buttons[1]
            if btn then
                stub.AuraAssign(btn, true)
                assigned[id] = assigned[id] or {}
                table.insert(assigned[id], btn)
            end
        end
    end
    function w.BuffUp(id, o)
        o = o or {}
        local r = w.Row(id)
        local unit = o.unit or ((r and r.aura and not r.selfAura) and "target" or "player")
        CW.Aura(unit, id, { harmful = unit == "target", duration = o.duration or 12, applications = o.applications })
        run()
        assign(id, true)
    end
    function w.BuffDown(id)
        CW.Unaura("player", id); CW.Unaura("target", id)
        assign(id, false)
        run()
    end
    function w.Proc(id, s) w.BuffUp(id, { unit = "player", duration = s or 15 }) end
    function w.Refresh(id)
        local onTarget = false
        for _, a in ipairs(stub.auras.target and stub.auras.target.HARMFUL or {}) do
            if a.spellId == id then onTarget = true end
        end
        w.Cast(id)
        w.BuffDown(id)
        w.BuffUp(id, { unit = onTarget and "target" or nil })
    end
    function w.KillTarget()
        local t = stub.units.target
        if t then t.dead = true end
        local gone = {}
        for _, kind in ipairs({ "HELPFUL", "HARMFUL" }) do
            for _, a in ipairs(stub.auras.target and stub.auras.target[kind] or {}) do gone[#gone + 1] = a.spellId end
        end
        for _, id in ipairs(gone) do CW.Unaura("target", id) end
        run()
        stub.units.target = nil
        stub.FireEvent("PLAYER_TARGET_CHANGED")
        run()
    end
    function w.NewTarget()
        stub.units.target = { name = "Boar", reaction = 2 }
        stub.FireEvent("PLAYER_TARGET_CHANGED")
        run()
    end
    function w.Usable(can, noPower)
        C_Spell.IsSpellUsable = function() return can, noPower end
        stub.FireEvent("SPELL_UPDATE_USABLE")
        run()
    end
    function w.Unit(unit, fields)
        stub.units[unit] = stub.units[unit] or {}
        for k, v in pairs(fields or {}) do stub.units[unit][k] = v end
        if unit == "target" then stub.FireEvent("PLAYER_TARGET_CHANGED") end
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_POWER_UPDATE", "UNIT_FLAGS", "UNIT_FACTION", "UNIT_CLASSIFICATION_CHANGED" }) do
            stub.FireEvent(e, unit)
        end
        run()
    end
    function w.Tick(n)
        for _ = 1, n or 1 do w.ns.Conditions.Tick() end
        run()
    end
    -- Batch A's drivers (Conditions.lua): each sets the fake game's answer, then sends
    -- the event the client sends.

    -- ids = { [spell id] = true }: the spells whose range the game checks.
    function w.HasRange(ids)
        C_Spell.SpellHasRange = function(id) return ids[id] == true end
    end
    -- The target in range (true), out of it (false) or no answer (nil); a secret too.
    function w.Range(v)
        C_Spell.IsSpellInRange = function(_, u)
            if u == "target" and stub.units.target then return v end
        end
        stub.FireEvent("SPELL_RANGE_CHECK_UPDATE", 0, v, true)
        run()
    end
    -- The target casts ("cast"), channels ("channel") or stops (nil). ending names how
    -- a cast ends: "STOP" (the default), "FAILED", "INTERRUPTED" or "CHANNEL_STOP".
    function w.TargetCasts(kind, ending)
        local t = stub.units.target
        if not t then return end
        t.cast = kind == "cast" and { name = "Fireball" } or nil
        t.channel = kind == "channel" and { name = "Drain Life" } or nil
        local e = kind == "cast" and "START" or kind == "channel" and "CHANNEL_START" or ending or "STOP"
        stub.FireEvent("UNIT_SPELLCAST_" .. e, "target")
        run()
    end
    -- Only the global cooldown holds spell id (on), or nothing does.
    function w.Gcd(id, on)
        w.gcd[id] = on and true or nil
        stub.FireEvent("SPELL_UPDATE_COOLDOWN")
        run()
    end
    -- In the class's form key (Daylight UI's CdmEffects.FORMS), or none for nil. A
    -- form's answer is secret with o.secret.
    function w.Form(key, o)
        local forms = (w.ns.Bridge.Forms() or {})[c.class] or {}
        local bar = {}
        for _, f in ipairs(forms) do
            if f.spells and not f.stealth then bar[#bar + 1] = f end
        end
        stub.forms = #bar
        _G.GetShapeshiftFormInfo = function(i)
            local f = bar[i]
            if not f then return nil end
            local on = f.key == key
            if o and o.secret then on = stub.Secret(on) end
            return "icon", on, true, f.spells[1]
        end
        _G.IsStealthed = function()
            for _, f in ipairs(forms) do
                if f.stealth and f.key == key then return true end
            end
            return false
        end
        stub.FireEvent("UPDATE_SHAPESHIFT_FORMS")
        stub.FireEvent("UPDATE_SHAPESHIFT_FORM")
        stub.FireEvent("UPDATE_STEALTH")
        run()
    end
    -- Totem spell id stands in slot after your cast of it; nil empties the slot.
    function w.Totem(slot, id)
        stub.totems[slot] = id and { spell = id, duration = stub.Duration(30) } or nil
        if id then w.Cast(id) end
        stub.FireEvent("PLAYER_TOTEM_UPDATE", slot)
        run()
    end
    -- The weapons' enchants: { { slot = Enum.WeaponSlot, enchantID } }.
    function w.Enchant(list)
        stub.SetWeaponEnchants(list)
        stub.FireEvent("PLAYER_EQUIPMENT_CHANGED")
        stub.FireEvent("WEAPON_ENCHANT_CHANGED")
        stub.FireEvent("UNIT_INVENTORY_CHANGED", "player")
        run()
    end
    function w.Group(on)
        -- In a group EZ-CDM tells its version over the game's addon messages.
        _G.C_ChatInfo = _G.C_ChatInfo or {
            SendAddonMessage = function() return 0 end,
            InChatMessagingLockdown = function() return false end,
            AreOutgoingAddonChatMessagesRestricted = function() return false end,
        }
        stub.inGroup = on and true or false
        stub.FireEvent("GROUP_ROSTER_UPDATE")
        run()
    end
    -- Where you are: "party", "raid", "pvp", "arena", or nil for the open world. The
    -- client sends both after the loading screen.
    function w.Instance(kind)
        stub.SetInstance(kind)
        stub.FireEvent("PLAYER_ENTERING_WORLD")
        stub.FireEvent("ZONE_CHANGED_NEW_AREA")
        run()
    end
    function w.EnterCombat() stub.EnterCombat(); run() end
    function w.LeaveCombat() stub.LeaveCombat(); run(); w.Pass() end
    function w.Advance(s)
        stub.Advance(s)
        run()
        w.Pass()
    end
    function w.Reload(o)
        local db = { dui = copy(DaylightUIDB), ez = copy(EZCDMDB) }
        local merged = {}
        for k, v in pairs(opts) do merged[k] = v end
        for k, v in pairs(o or {}) do merged[k] = v end
        merged.db = db
        login(merged)
    end
    return w
end

return W
