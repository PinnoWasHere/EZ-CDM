local _, ns = ...

-- Who draws a piece's ready glow and plays its ready sound. "When it's ready, glow"
-- is Daylight UI's own line (readyGlow) until it takes an "and" clause; then it is
-- EZ-CDM's offCooldown (or totemDown, on a totem showing its time) line with those
-- clauses (Grammar's owned entries). While a piece has such a line, Daylight UI's
-- ready glow for it is off, so the two never show at once, and the player's own
-- value is kept here. It goes back when the last such line goes. The ready sound
-- works the same way, on its own.
--
-- The kept values live in EZCDMDB.readyOwned[profile][key] = { glow = readyGlow,
-- sound = readySound }, one field per part EZ-CDM owns, and survive a /reload.
-- While EZ-CDM owns a part:
--   - the drawer reads the player's own value (Ready.Merge), so a plain line stays
--     theirs, and EZ-CDM draws it (Ready.Drawn, Conditions.KEPT_READY)
--   - a value the player turns on in Daylight UI's card becomes the kept value, and
--     the part goes back off (Ready.Reconcile)
-- Draft writes the part and the kept value with a piece's other fields (Ready.Split).
-- Ready.Reconcile catches the rest, as Gray.Reconcile does, out of a fight only.

local Bridge, Conditions = ns.Bridge, ns.Conditions

local Ready = {}
ns.Ready = Ready

-- Debug handle for an in-game check.
EZCDM_Ready = Ready

-- Each part: Daylight UI's field and EZ-CDM's action.
Ready.PARTS = { glow = "readyGlow", sound = "readySound" }
local ORDER = { "glow", "sound" }

local function off(part) return Bridge.Option({}, Ready.PARTS[part]) end

local function store()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.readyOwned) ~= "table" then EZCDMDB.readyOwned = {} end
    return EZCDMDB.readyOwned
end

local function clean(rec)
    if type(rec) ~= "table" then return nil end
    local out
    if type(rec.glow) == "boolean" then out = { glow = rec.glow } end
    if type(rec.sound) == "string" then
        out = out or {}
        out.sound = rec.sound
    end
    return out
end

local function put(profile, key, rec)
    local all = store()
    all[profile] = all[profile] or {}
    all[profile][key] = clean(rec)
    if next(all[profile]) == nil then all[profile] = nil end
    if next(all) == nil then EZCDMDB.readyOwned = nil end
end

-- A piece's kept values on talent set g's profile (current when nil), or nil.
function Ready.Record(key, g)
    local profile = Bridge.ProfileOf(g)
    local all = type(EZCDMDB) == "table" and type(EZCDMDB.readyOwned) == "table" and EZCDMDB.readyOwned
    local byKey = profile ~= nil and all and all[profile]
    return type(byKey) == "table" and clean(byKey[key]) or nil
end

-- Sets or clears a piece's kept values, as Gray.Set does.
function Ready.Set(g, key, rec)
    local profile, why = Bridge.SavedProfile(g)
    if not profile then return false, why end
    put(profile, key, rec)
    return true
end

-- Whether a rule (Conditions' saved form) has an EZ-CDM ready line for part on a
-- piece of kind: its ready condition's line by that action.
function Ready.Owns(rule, kind, part)
    local ck = ns.Grammar.ReadyCondition(kind)
    return ck ~= nil and type(rule) == "table" and type(rule[ck]) == "table" and rule[ck][part] ~= nil
end

-- The player's own value for a part whose saved value is live: the kept one while
-- EZ-CDM owns it, else live. A live value other than off is a pick made in the card
-- since, and it wins.
local function intent(rec, part, live)
    if rec and rec[part] ~= nil and (live == nil or live == off(part)) then return rec[part] end
    return live
end

-- Before Grammar.Decompile: each owned part in the player's own words.
function Ready.Merge(key, fields, g)
    local rec = Ready.Record(key, g)
    if not rec then return fields end
    for _, part in ipairs(ORDER) do
        if rec[part] ~= nil then
            local f = Ready.PARTS[part]
            local was = intent(rec, part, fields[f])
            if was == off(part) then was = nil end
            fields[f] = was
        end
    end
    return fields
end

-- After Grammar.Compile and Conditions.Split: each part an EZ-CDM ready line in rule
-- owns is written off and the player's own returned for Ready.Set; nil when it owns
-- neither.
function Ready.Split(fields, rule, kind)
    local rec
    for _, part in ipairs(ORDER) do
        if Ready.Owns(rule, kind, part) then
            local f = Ready.PARTS[part]
            local was = fields[f]
            if was == nil then was = off(part) end
            fields[f] = nil
            rec = rec or {}
            rec[part] = was
        end
    end
    return rec
end

-- ---------------------------------------------------------------------
-- What EZ-CDM draws for an owned part
-- ---------------------------------------------------------------------

local function copySpec(spec)
    local out = {}
    for k, v in pairs(type(spec) == "table" and spec or {}) do out[k] = v end
    return out
end

-- Before a glow line's own clauses: Daylight UI's other glows come first on the piece.
local function quiet(spec)
    local clauses = { { cond = Conditions.QUIET } }
    for _, cl in ipairs(spec.clauses or {}) do clauses[#clauses + 1] = cl end
    spec.clauses = clauses
end

-- A piece's rule r (Conditions' cleaned form) as the driver draws it: each owned
-- line drawn as Daylight UI's own (spec.ready), a glow giving way to Daylight UI's
-- other glows, and the player's own plain line, kept while EZ-CDM owns the part,
-- added as Conditions.KEPT_READY's line. Returns r.
function Ready.Drawn(key, r)
    local rec = Ready.Record(key)
    if not rec then return r end
    local kind = ns.Grammar.Kind(key)
    local ck = ns.Grammar.ReadyCondition(kind)
    local kept = ck and Conditions.KEPT_READY[ck]
    if not kept then return r end
    for _, part in ipairs(ORDER) do
        if rec[part] ~= nil and Ready.Owns(r, kind, part) then
            local spec = copySpec(r[ck][part])
            spec.ready = true
            if part == "glow" then quiet(spec) end
            r[ck][part] = spec
            local was = rec[part]
            if part == "glow" and was == true then
                local layout = Bridge.Layout()
                local p = type(layout) == "table" and type(layout.pieces) == "table" and layout.pieces[key] or nil
                local c = Bridge.Option(p, "readyGlowColor")
                local styles = ns.Effects.Styles(key)
                local k = { ready = true, daylight = true,
                            value = type(c) == "table" and { c[1], c[2], c[3] } or nil,
                            style = styles and styles.ready or nil }
                quiet(k)
                r[kept] = r[kept] or {}
                r[kept].glow = k
            elseif part == "sound" and type(was) == "string" and was ~= off("sound") then
                r[kept] = r[kept] or {}
                r[kept].sound = { ready = true, daylight = true, value = was }
            end
        end
    end
    return r
end

-- ---------------------------------------------------------------------
-- Keeping Daylight UI's fields in step
-- ---------------------------------------------------------------------

local function write(g, key, part, value)
    return Bridge.SetSpellValue(g, key, Ready.PARTS[part], value) == true
end

-- One talent set's placed pieces. Returns whether it wrote anything.
local function settle(g, profile)
    local set = Bridge.Layout(g)
    local pieces = type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}
    local all = type(EZCDMDB) == "table" and type(EZCDMDB.readyOwned) == "table" and EZCDMDB.readyOwned or {}
    local keptAll = all[profile] or {}
    local wrote = false
    for key, p in pairs(pieces) do
        local rule = Conditions.Rule(key, g)
        local rec = clean(keptAll[key])
        if rec or (rule and (rule.offCooldown or rule.totemDown)) then
            local kind = ns.Grammar.Kind(key, p)
            local now = rec and copySpec(rec) or {}
            for _, part in ipairs(ORDER) do
                local live = Bridge.Option(p, Ready.PARTS[part])
                if Ready.Owns(rule, kind, part) then
                    if live ~= off(part) then
                        -- A pick made in the card, or a line saved before EZ-CDM owned it.
                        if write(g, key, part, off(part)) then
                            now[part] = live
                            wrote = true
                        end
                    elseif now[part] == nil then
                        now[part] = live
                    end
                elseif now[part] ~= nil then
                    -- The last owned line went another way. A pick made in the card since stands.
                    if live == off(part) and now[part] ~= off(part) then
                        if write(g, key, part, now[part]) then
                            now[part] = nil
                            wrote = true
                        end
                    else
                        now[part] = nil
                    end
                end
            end
            if next(now) ~= nil or rec then put(profile, key, now) end
        end
    end
    for key in pairs(all[profile] or {}) do
        if pieces[key] == nil then put(profile, key, nil) end
    end
    return wrote
end

local busy, due = false, false

-- Matches each owned part on every talent set's profile to who owns it. In a fight
-- it waits for the fight's end. An open editor redraws after a write.
function Ready.Reconcile()
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
-- original, so Reconcile puts the player's own back on the copy.
Bridge.AfterCopy(function(from, id)
    local all = type(EZCDMDB) == "table" and type(EZCDMDB.readyOwned) == "table" and EZCDMDB.readyOwned
    local kept = all and all[from]
    if type(kept) ~= "table" then return end
    for key, rec in pairs(kept) do put(id, key, rec) end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if due then Conditions.Sync() end
end)
