local addonName, ns = ...

-- A bug report as one line of text a player copies out and pastes into an issue:
-- "EZCDM1:" and then Base64 of a small serialized table. Reading one back never
-- runs code; Report.Parse walks the text by hand.
--
-- What it holds: the versions (EZ-CDM, Daylight UI and its API, the client), the
-- class, the spec and talent set, the current layout's pieces with their keys,
-- spells and Daylight UI options, what draws each one, which of their spells the
-- player knows, and every EZ-CDM rule table saved for the current profile.
-- What it leaves out: names (character, realm, guild, profile), chat, and screen
-- positions. A piece keeps only where it hangs off another.
--
-- Used offline by tools/repro.py, which builds the same class and layout in the
-- test world.

local Bridge = ns.Bridge

local Report = {}
ns.Report = Report

Report.PREFIX = "EZCDM1:"
Report.VERSION = 1

-- Piece fields that place it on the screen. Dropped; the rest of a piece is kept.
Report.SKIP = { x = true, y = true }

-- Parse refuses text longer than this, or nested deeper.
local MAX_TEXT, MAX_DEPTH = 200000, 16

-- ---------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------

local function secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end

-- v as a plain value, or nil when the game made it secret.
local function plain(v)
    if secret(v) then return nil end
    return v
end

-- A copy holding only numbers, strings, booleans and tables keyed by numbers or strings.
local function copy(v, depth)
    depth = depth or 0
    local t = type(v)
    if secret(v) then return nil end
    if t == "number" or t == "string" or t == "boolean" then return v end
    if t ~= "table" or depth > MAX_DEPTH then return nil end
    local out = {}
    for k, x in pairs(v) do
        local kt = type(k)
        if (kt == "number" or kt == "string") and not secret(k) then out[k] = copy(x, depth + 1) end
    end
    return out
end

-- fn's answers with any secret one as nil, or nil when the client has no fn.
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local a, b, c, d = fn(...)
    return plain(a), plain(b), plain(c), plain(d)
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    return keys
end

-- ---------------------------------------------------------------------
-- Text: serialize and read back
-- ---------------------------------------------------------------------

-- T true, F false, N<number>; a number, S<length>:<bytes> a string,
-- [ value value ... ] a list (keys 1 to n), { key value key value ... } any
-- other table, keys in sorted order.
local function number(v)
    if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
    local s = string.format("%.6g", v)
    if tonumber(s) ~= v then s = string.format("%.17g", v) end
    return s
end

local function write(v, out)
    local t = type(v)
    if t == "boolean" then
        out[#out + 1] = v and "T" or "F"
    elseif t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then v = 0 end
        out[#out + 1] = "N" .. number(v) .. ";"
    elseif t == "string" then
        out[#out + 1] = "S" .. #v .. ":" .. v
    elseif t == "table" then
        local n, count = #v, 0
        for _ in pairs(v) do count = count + 1 end
        if n > 0 and n == count then
            out[#out + 1] = "["
            for i = 1, n do write(v[i], out) end
            out[#out + 1] = "]"
            return
        end
        out[#out + 1] = "{"
        for _, k in ipairs(sortedKeys(v)) do
            write(k, out)
            write(v[k], out)
        end
        out[#out + 1] = "}"
    end
end

function Report.Serialize(v)
    local out = {}
    write(v, out)
    return table.concat(out)
end

-- The value at text's position i, and the position after it; nil when damaged.
local function read(text, i, depth)
    local c = string.sub(text, i, i)
    if c == "T" then return true, i + 1 end
    if c == "F" then return false, i + 1 end
    if c == "N" then
        local s, e = string.match(text, "^([%d%.eE+-]+);()", i + 1)
        local n = tonumber(s)
        if not n then return nil end
        return n, e
    end
    if c == "S" then
        local len, e = string.match(text, "^(%d+):()", i + 1)
        len = tonumber(len)
        if not len or e + len - 1 > #text then return nil end
        return string.sub(text, e, e + len - 1), e + len
    end
    if c == "[" then
        if depth >= MAX_DEPTH then return nil end
        local t = {}
        i = i + 1
        while true do
            if string.sub(text, i, i) == "]" then return t, i + 1 end
            local v
            v, i = read(text, i, depth + 1)
            if v == nil then return nil end
            t[#t + 1] = v
        end
    end
    if c == "{" then
        if depth >= MAX_DEPTH then return nil end
        local t = {}
        i = i + 1
        while true do
            if string.sub(text, i, i) == "}" then return t, i + 1 end
            local k, v
            k, i = read(text, i, depth + 1)
            if (type(k) ~= "number" and type(k) ~= "string") or not i then return nil end
            v, i = read(text, i, depth + 1)
            if v == nil then return nil end
            t[k] = v
        end
    end
    return nil
end

function Report.Deserialize(text)
    if type(text) ~= "string" then return nil end
    local v, e = read(text, 1, 0)
    if type(v) ~= "table" or e ~= #text + 1 then return nil end
    return v
end

-- Base64, the standard alphabet, padded.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_AT = {}
for i = 1, 64 do B64_AT[string.sub(B64, i, i)] = i - 1 end

function Report.Encode64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = string.byte(s, i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local c1, c2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
        local c3, c4 = math.floor(n / 64) % 64, n % 64
        out[#out + 1] = string.sub(B64, c1 + 1, c1 + 1) .. string.sub(B64, c2 + 1, c2 + 1)
            .. (b and string.sub(B64, c3 + 1, c3 + 1) or "=") .. (c and string.sub(B64, c4 + 1, c4 + 1) or "=")
    end
    return table.concat(out)
end

-- The bytes back, or nil when s isn't Base64.
function Report.Decode64(s)
    s = string.gsub(s, "=+$", "")
    if string.find(s, "[^%w%+/]") or #s % 4 == 1 then return nil end
    local out = {}
    for i = 1, #s, 4 do
        local n, count = 0, 0
        for j = i, math.min(i + 3, #s) do
            n = n * 64 + B64_AT[string.sub(s, j, j)]
            count = count + 1
        end
        for _ = count + 1, 4 do n = n * 64 end
        local a, b, c = math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256
        out[#out + 1] = string.char(a)
        if count > 2 then out[#out + 1] = string.char(b) end
        if count > 3 then out[#out + 1] = string.char(c) end
    end
    return table.concat(out)
end

-- ---------------------------------------------------------------------
-- The report
-- ---------------------------------------------------------------------

-- Every spell id a placed piece answers to, its aura links' sources too.
local function askedIds(pieces)
    local ids = {}
    local byAura = type(ns.AuraLinks) == "table" and ns.AuraLinks.byAura or {}
    for key in pairs(pieces) do
        local sid = Bridge.SpellOf(key)
        if type(sid) == "number" then ids[sid] = true end
        local all = Bridge.SpellIDs(key)
        for id in pairs(type(all) == "table" and all or {}) do
            if type(id) == "number" then ids[id] = true end
        end
    end
    for id in pairs(ids) do
        for _, s in ipairs(byAura[id] or {}) do ids[s] = true end
    end
    return ids
end

-- Each of the game's buff viewers set to Hidden in Edit Mode, by name.
local function hiddenViewers()
    local E = Enum and Enum.CooldownViewerVisibleSetting
    local out = {}
    for _, name in ipairs({ "BuffIconCooldownViewer", "BuffBarCooldownViewer" }) do
        local v = _G[name]
        if E and type(v) == "table" and plain(v.visibleSetting) == E.Hidden then out[name] = true end
    end
    return out
end

-- Every EZ-CDM rule table saved for profile, whole, by store name (upGlow, fallOff,
-- glowStyle, overlay, and any store added later under the same shape).
local function rules(profile)
    local out = {}
    if profile == nil or type(EZCDMDB) ~= "table" then return out end
    for name, store in pairs(EZCDMDB) do
        if type(name) == "string" and type(store) == "table" and type(store[profile]) == "table" then
            out[name] = copy(store[profile])
        end
    end
    return out
end

-- The report as a table (Report.Build packs it).
function Report.Collect()
    local A = C_AddOns or {}
    local layout = Bridge.Layout()
    local srcPieces = type(layout) == "table" and type(layout.pieces) == "table" and layout.pieces or {}
    local pieces, spells = {}, {}
    for key, p in pairs(srcPieces) do
        local out = {}
        for k, v in pairs(type(p) == "table" and p or {}) do
            if not Report.SKIP[k] then out[k] = copy(v) end
        end
        pieces[key] = out
        local ids, all = {}, Bridge.SpellIDs(key)
        for id in pairs(type(all) == "table" and all or {}) do
            if type(id) == "number" then ids[#ids + 1] = id end
        end
        table.sort(ids)
        spells[key] = { id = plain(Bridge.SpellOf(key)), ids = ids, drawn = plain(Bridge.DrawnBy(key)),
                        shows = plain(Bridge.Shows(key, p)), custom = Bridge.IsCustom(key) or nil }
    end
    local known, passive = {}, {}
    local S = type(C_Spell) == "table" and C_Spell or {}
    for _, id in ipairs(sortedKeys(askedIds(srcPieces))) do
        local k = call(IsPlayerSpell, id)
        if k ~= nil then known[#known + 1] = k and id or -id end
        if call(S.IsSpellPassive, id) == true then passive[#passive + 1] = id end
    end
    local version, build, _, interface = call(GetBuildInfo)
    local major, minor = Bridge.ApiVersion()
    local SI = type(C_SpecializationInfo) == "table" and C_SpecializationInfo or {}
    local _, class = call(UnitClass, "player")
    return {
        v = Report.VERSION,
        ez = call(A.GetAddOnMetadata, addonName, "Version"),
        dui = call(A.GetAddOnMetadata, "DaylightUI", "Version"),
        api = major and { major, minor } or nil,
        game = { version, build, interface },
        class = class,
        spec = call(SI.GetSpecialization),
        set = plain(Bridge.CurrentIndex()),
        hidden = hiddenViewers(),
        pieces = pieces,
        chains = copy(type(layout) == "table" and layout.chains or nil) or {},
        spells = spells,
        known = known,
        passive = passive,
        rules = rules(Bridge.ProfileOf()),
        -- The rules' saved form (Conditions.VERSION), so a rebuild reads them as saved.
        rulesVersion = type(EZCDMDB) == "table" and type(EZCDMDB.conditionsVersion) == "number"
            and EZCDMDB.conditionsVersion or nil,
    }
end

-- The report as one line of text to copy.
function Report.Build()
    return Report.PREFIX .. Report.Encode64(Report.Serialize(Report.Collect()))
end

-- A report's table back from text. The text may sit inside other text (an issue,
-- a chat paste); the report runs from its prefix to the first character Base64
-- doesn't use. Returns the table, or nil and a reason: "empty", "prefix" (no
-- report in it), "damaged" or "newer".
function Report.Parse(text)
    if type(text) ~= "string" or string.find(text, "^%s*$") then return nil, "empty" end
    if #text > MAX_TEXT then return nil, "damaged" end
    local at = string.find(text, Report.PREFIX, 1, true)
    if not at then return nil, "prefix" end
    local body = string.match(string.sub(text, at + #Report.PREFIX), "^[%w%+/]*=*")
    local raw = Report.Decode64(body)
    local t = raw and Report.Deserialize(raw)
    if type(t) ~= "table" or type(t.v) ~= "number" then return nil, "damaged" end
    if t.v > Report.VERSION then return nil, "newer" end
    if type(t.pieces) ~= "table" or type(t.rules) ~= "table" then return nil, "damaged" end
    return t
end
