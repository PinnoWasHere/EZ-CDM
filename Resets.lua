local _, ns = ...

-- "When its cooldown resets": a talent resets a spell's cooldown (Improved Stormstrike
-- resets Stormstrike on a dodge or parry). The server scripts the reset and the client
-- has no effect for it, so it is seen as Daylight UI's Proc Alerts sees it
-- (DaylightUI_Procs/Engine.lua, mode reset): after your own cast, the cooldown ends
-- well before its usual length. EZ-CDM watches on its own, so the moment works with
-- Proc Alerts or its alert off.
--
-- Which spells: AuraLinks.resets, baked from Daylight UI's Proc Alerts list with the
-- client's cooldown length (tools/make_aura_links.py). Only for your class.
--
-- The reads: UNIT_SPELLCAST_SUCCEEDED for the player is plain, and C_Spell.GetSpellCooldown's
-- isActive and isOnGCD are NeverSecret (SpellSharedDocumentation). Its duration is
-- secret in a fight; a plain one is the length with gear and talents, so it replaces
-- the client's.
--
-- The moment holds the reset's hold (Daylight UI's dur) for held looks, until the
-- spell is cast again, or until the fight ends. One-shot looks fire as it lights.

local Bridge, Conditions = ns.Bridge, ns.Conditions

local Resets = {}
ns.Resets = Resets

-- Debug handle for an in-game check.
EZCDM_Resets = Resets

-- Seconds after the cast before a cooldown's end counts: it is still being set up.
Resets.FROM = 1
-- Seconds before the usual end from which an end is the usual one.
Resets.MARGIN = 0.6
-- The poll's beat, only while a cast is armed or a reset holds, and only while a
-- rule uses the moment: an early end the cooldown event missed.
Resets.POLL = 0.2

local function secret(v) return type(issecretvalue) == "function" and issecretvalue(v) == true end

local function plainNumber(v)
    if secret(v) or type(v) ~= "number" then return nil end
    return v
end

-- Reset key -> { armedAt, litAt, why }. Reset key -> a plain length seen, in seconds.
local state, seen = {}, {}
-- Piece key (string) -> reset key, for pieces whose rules use the moment.
local pieces = {}
local listener

local function tell(what, fields)
    if not listener then return end
    local e = { event = what }
    for k, v in pairs(fields or {}) do e[k] = v end
    listener(e)
end

-- The reset entry of a spell, for your class: { key, class, talent, cd, hold }, or nil.
function Resets.Of(sid)
    local L = ns.AuraLinks
    local r = type(sid) == "number" and type(L) == "table" and type(L.resets) == "table" and L.resets[sid]
    if type(r) ~= "table" or r.class ~= Bridge.MyClass() then return nil end
    return r
end

-- The lowest reset spell id a talent of your class resets, or nil. The talent's own
-- piece shows a buff of the same name (Improved Stormstrike's mana buff), never the reset.
function Resets.ForTalent(sid)
    local L = ns.AuraLinks
    local found
    for id, r in pairs(type(L) == "table" and type(L.resets) == "table" and L.resets or {}) do
        if r.talent == sid and r.class == Bridge.MyClass() and (not found or id < found) then found = id end
    end
    return found
end

local function pieceSpell(k) return Bridge.SpellOf(tonumber(k) or k) end

local function entryOf(k) return Resets.Of(pieceSpell(k)) end

-- The usual length in seconds, and where it came from: "seen" or "client".
function Resets.Length(sid)
    local r = Resets.Of(sid)
    if not r then return nil end
    if seen[r.key] then return seen[r.key], "seen" end
    return r.cd / 1000, "client"
end

-- isActive and isOnGCD of a spell's cooldown, and its plain duration or nil.
local function cooldown(sid)
    local info = C_Spell.GetSpellCooldown(sid)
    if type(info) ~= "table" or secret(info.isActive) or info.isActive == nil then return nil end
    local gcd = not secret(info.isOnGCD) and info.isOnGCD == true
    return info.isActive == true, gcd, plainNumber(info.duration)
end

-- A plain duration of its own cooldown (not the global one) is its length now.
local function learn(r, sid)
    local active, gcd, dur = cooldown(sid)
    if active and not gcd and dur and dur > 0 and seen[r.key] ~= dur then
        seen[r.key] = dur
        tell("length", { spell = sid, length = dur })
    end
end

local function inCombat() return InCombatLockdown() == true end

-- The spell's ranks: every resets id sharing its key.
local function spellsOf(rkey)
    local out = {}
    local L = ns.AuraLinks
    for sid, r in pairs(type(L) == "table" and L.resets or {}) do
        if r.key == rkey then out[#out + 1] = sid end
    end
    table.sort(out)
    return out
end

-- The rank a piece of this reset shows, for the cooldown read.
local function spellFor(rkey)
    for k, key in pairs(pieces) do
        if key == rkey then
            local sid = pieceSpell(k)
            if type(sid) == "number" then return sid end
        end
    end
    return spellsOf(rkey)[1]
end

local function redraw(rkey)
    for k, key in pairs(pieces) do
        if key == rkey then Conditions.Refresh(k) end
    end
end

local poll
local function setPoll()
    local want = false
    for _, g in pairs(state) do
        if g.armedAt or g.litAt then want = true end
    end
    if want and not poll then
        poll = C_Timer.NewTicker(Resets.POLL, function() Resets.Check(false) end)
    elseif not want and poll then
        poll:Cancel()
        poll = nil
    end
end

local function holdOf(rkey)
    local sid = spellsOf(rkey)[1]
    local r = sid and Resets.Of(sid)
    return r and r.hold or 0
end

local function lightOut(rkey, g, why)
    g.litAt = nil
    tell("out", { reset = rkey, why = why })
    redraw(rkey)
end

-- Checks every armed or lit reset. atEvent: right after SPELL_UPDATE_COOLDOWN, the only
-- moment isOnGCD is trusted, so active and on the GCD means its own cooldown is over.
function Resets.Check(atEvent)
    local now = GetTime()
    for rkey, g in pairs(state) do
        if g.litAt then
            if not inCombat() then
                lightOut(rkey, g, "combat")
            elseif now - g.litAt >= holdOf(rkey) then
                lightOut(rkey, g, "hold")
            end
        elseif g.armedAt then
            local sid = spellFor(rkey)
            local length = Resets.Length(sid)
            local since = now - g.armedAt
            if not length or since >= length - Resets.MARGIN then
                g.armedAt = nil
                tell("usual", { reset = rkey, since = since })
            elseif since >= Resets.FROM and inCombat() then
                local active, gcd = cooldown(sid)
                if active == false or (atEvent and active and gcd) then
                    g.armedAt, g.litAt = nil, now
                    tell("reset", { reset = rkey, spell = sid, since = since, onGCD = active == true })
                    redraw(rkey)
                end
            end
        end
    end
    setPoll()
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(_, event, unit, _, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        if secret(unit) or unit ~= "player" then return end
        local sid = plainNumber(spellID)
        local r = sid and Resets.Of(sid)
        if not r then return end
        local g = state[r.key] or {}
        state[r.key] = g
        local was = g.litAt
        g.armedAt, g.litAt = GetTime(), nil
        tell("armed", { reset = r.key, spell = sid, inCombat = inCombat() })
        if was then redraw(r.key) end
        -- The cooldown starts with the cast; a plain read of it is its length.
        learn(r, sid)
        setPoll()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        for rkey, g in pairs(state) do
            if g.armedAt then
                local sid = spellFor(rkey)
                local r = Resets.Of(sid)
                if r then learn(r, sid) end
            end
        end
        Resets.Check(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        Resets.Check(false)
    end
end)

local listening = false
local function listen(on)
    if on == listening then return end
    listening = on
    if on then
        frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    else
        frame:UnregisterAllEvents()
        for k in pairs(state) do state[k] = nil end
        setPoll()
    end
end

-- Whether a reset holds for a piece now, in a fight and within its hold.
local function litFor(k)
    local r = entryOf(k)
    local g = r and state[r.key]
    if not (g and g.litAt) then return false end
    return inCombat() and GetTime() - g.litAt < r.hold
end

function Resets.Watching() return listening end
function Resets.Polling() return poll ~= nil end
-- fn(event table) on each arm, reset, usual end, hold end and length seen, or nil.
function Resets.Listen(fn) listener = fn end

Conditions.Register({
    key = "cooldownReset", moment = "reset", actions = { glow = { effect = "glow" } },
    fits = function(kind) return kind.resets == true end,
    read = function(k)
        if not entryOf(k) then return nil end
        return litFor(k)
    end,
    time = function(k)
        local r = entryOf(k)
        local g = r and state[r.key]
        if not (g and g.litAt and litFor(k)) then return nil end
        return r.hold - (GetTime() - g.litAt), r.hold
    end,
    detail = function(k)
        local sid = pieceSpell(k)
        local r = Resets.Of(sid)
        if not r then return { spell = sid } end
        local g = state[r.key] or {}
        local active, gcd = cooldown(sid)
        local length, from = Resets.Length(sid)
        local now = GetTime()
        return { spell = sid, isActive = active, isOnGCD = gcd, length = length, lengthFrom = from,
                 armed = g.armedAt and now - g.armedAt or nil, lit = g.litAt and now - g.litAt or nil,
                 inCombat = inCombat() }
    end,
    using = function(keys)
        for k in pairs(pieces) do pieces[k] = nil end
        for k in pairs(keys) do
            local r = entryOf(k)
            if r then pieces[k] = r.key end
        end
        listen(next(pieces) ~= nil)
    end,
    events = { game = { { "UNIT_SPELLCAST_SUCCEEDED", "player" }, "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED" } },
    -- The reset is about the spell, so it draws on either face of a piece that shows
    -- its debuff, then its cooldown (Stormstrike's debuff outlasts a reset).
    secrecy = "plain", layer = "any", excludes = {},
    words = { moment = "When its cooldown resets", clause = "its cooldown just reset" },
})
