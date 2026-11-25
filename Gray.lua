local _, ns = ...

-- Who draws a piece's gray. A piece with an EZ-CDM gray line ("When I can't cast it,
-- turn it gray") has its gray drawn by EZ-CDM alone, as a desaturated copy of its
-- icon (Overlay.lua). Daylight UI's Gray out for it is set to Stay colored, so the
-- game's gray and EZ-CDM's never stack, and the player's own Gray out is kept here.
-- It goes back when the last EZ-CDM gray line goes.
--
-- The kept value lives in EZCDMDB.grayOwned[profile][key] = { was = Gray out } and
-- survives a /reload. While EZ-CDM owns the gray:
--   - the drawer reads the player's own Gray out (Gray.Merge), so their Daylight
--     line "While it's cooling down, turn it gray" stays theirs, and EZ-CDM draws
--     that gray too (Gray.Cooling, Conditions.COOLING)
--   - a Gray out the player picks in Daylight UI's card becomes the kept value,
--     and Gray out goes back to Stay colored (Gray.Reconcile). Their pick is what
--     comes back when the last gray line goes, never an older one
-- Draft writes Gray out and the kept value with a piece's other fields (Gray.Split).
-- Gray.Reconcile catches the rest: a line saved by an earlier build, a rule gone
-- another way, a profile copy, a card change. It writes out of a fight only.

local Bridge, Conditions = ns.Bridge, ns.Conditions

local Gray = {}
ns.Gray = Gray

-- Debug handle for an in-game check.
EZCDM_Gray = Gray

-- Daylight UI's Gray out field and the value EZ-CDM keeps while it owns the gray.
Gray.FIELD = "desat"
Gray.COLORED = "color"
-- The kept value that makes EZ-CDM draw Daylight UI's own cooling gray.
Gray.COOLING = "grey"

local function default() return Bridge.Option({}, Gray.FIELD) end

local function store()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.grayOwned) ~= "table" then EZCDMDB.grayOwned = {} end
    return EZCDMDB.grayOwned
end

local function clean(rec)
    if type(rec) ~= "table" or type(rec.was) ~= "string" then return nil end
    return { was = rec.was }
end

local function put(profile, key, rec)
    local all = store()
    all[profile] = all[profile] or {}
    all[profile][key] = clean(rec)
    if next(all[profile]) == nil then all[profile] = nil end
end

-- A piece's kept Gray out on talent set g's profile (current when nil), or nil.
function Gray.Record(key, g)
    local profile = Bridge.ProfileOf(g)
    local byKey = profile ~= nil and store()[profile]
    return type(byKey) == "table" and clean(byKey[key]) or nil
end

-- Sets or clears a piece's kept Gray out, as Effects.Set does the up glow's.
function Gray.Set(g, key, rec)
    local profile, why = Bridge.SavedProfile(g)
    if not profile then return false, why end
    put(profile, key, rec)
    return true
end

-- Whether a rule (Conditions' saved form) has an EZ-CDM gray line.
function Gray.Owns(rule)
    for ck, acts in pairs(type(rule) == "table" and rule or {}) do
        for a in pairs(type(acts) == "table" and acts or {}) do
            if Conditions.Grays(ck, a) then return true end
        end
    end
    return false
end

-- The player's own Gray out for a piece whose saved Gray out is live: the kept
-- value while EZ-CDM owns it, else live. A live value other than Stay colored is a
-- pick made in the card since, and it wins.
function Gray.Intent(key, live, g)
    local rec = Gray.Record(key, g)
    if rec and (live or default()) == Gray.COLORED then return rec.was end
    return live
end

-- Before Grammar.Decompile: Gray out in the player's own words (Gray.Intent).
function Gray.Merge(key, fields, g)
    if not Gray.Record(key, g) then return fields end
    local was = Gray.Intent(key, fields[Gray.FIELD], g)
    if was == default() then was = nil end
    fields[Gray.FIELD] = was
    return fields
end

-- After Grammar.Compile and Conditions.Split: with a gray line in rule, Gray out is
-- written Stay colored and the player's own is returned for Gray.Set; without one,
-- the player's own stands and nil clears the kept value.
function Gray.Split(fields, rule)
    if not Gray.Owns(rule) then return nil end
    local was = fields[Gray.FIELD]
    if was == nil then was = default() end
    fields[Gray.FIELD] = Gray.COLORED
    return { was = was }
end

-- Whether EZ-CDM draws Daylight UI's own cooling gray on a piece of the current
-- profile: it owns the gray and the player's own Gray out is Gray.
function Gray.Cooling(key)
    local rec = Gray.Record(key)
    return rec ~= nil and rec.was == Gray.COOLING and Gray.Owns(Conditions.Rule(key))
end

-- ---------------------------------------------------------------------
-- Keeping Daylight UI's field in step
-- ---------------------------------------------------------------------

local function write(g, key, value) return Bridge.SetSpellValue(g, key, Gray.FIELD, value) == true end

-- One talent set's placed pieces. Returns whether it wrote anything.
local function settle(g, profile)
    local set = Bridge.Layout(g)
    local pieces = type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}
    local kept = store()[profile] or {}
    local wrote = false
    for key, p in pairs(pieces) do
        local rec = clean(kept[key])
        local live = Bridge.Option(p, Gray.FIELD)
        if Gray.Owns(Conditions.Rule(key, g)) then
            if live ~= Gray.COLORED then
                -- A line saved by an earlier build, or a pick made in the card.
                if write(g, key, Gray.COLORED) then
                    put(profile, key, { was = live })
                    wrote = true
                end
            elseif not rec then
                put(profile, key, { was = live })
            end
        elseif rec then
            -- The last gray line went another way. A pick made in the card since stands.
            if live == Gray.COLORED and rec.was ~= Gray.COLORED then
                if write(g, key, rec.was) then
                    put(profile, key, nil)
                    wrote = true
                end
            else
                put(profile, key, nil)
            end
        end
    end
    for key in pairs(store()[profile] or {}) do
        if pieces[key] == nil then put(profile, key, nil) end
    end
    return wrote
end

local busy, due = false, false

-- Matches Gray out on every talent set's profile to who owns each piece's gray.
-- In a fight it waits for the fight's end. An open editor redraws after a write.
function Gray.Reconcile()
    if busy then return end
    if InCombatLockdown() or not Bridge.Ready() then
        due = true
        return
    end
    busy, due = true, false
    local wrote = false
    for g = 1, Bridge.SetCount() or 0 do
        local profile = Bridge.ProfileOf(g)
        if profile ~= nil and settle(g, profile) then wrote = true end
    end
    busy = false
    if wrote and Bridge.EditorOpen() then C_Timer.After(0, Bridge.EditorChanged) end
end

-- A profile copy takes the kept values with it. EZ-CDM's lines stay with the
-- original, so Reconcile puts the player's own Gray out back on the copy.
Bridge.AfterCopy(function(from, id)
    local kept = store()[from]
    if type(kept) ~= "table" then return end
    for key, rec in pairs(kept) do put(id, key, rec) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if due then Conditions.Sync() end
end)
