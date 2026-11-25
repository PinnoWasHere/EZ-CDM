local stub = require("stub")
local SW = require("sweep_lib")

-- The fits sweep (docs/tasks/w1-batch-a-fixes.md): every class's tray, and every
-- class spell a player can add by its id, each word checked against the client's own
-- tables (EZ-CDM/AuraLinks.lua), read here straight from the table:
--   no aura      no spell id of the piece, nor an aura the links say they put up, has
--                "b" or "d", and on Daylight UI's own piece (which learns an aura seen
--                after a cast) each id the tables list has "n": no buff moment, What it
--                shows offers only the spell, and no word says buff or debuff. A totem
--                is out: its buff is its creature's spell, which the tables don't link
--   a debuff     the words say debuff only where an id has "d"
--   a target     the target words only on a spell cast at a unit ("t")
--   only the GCD only on a spell with a real cooldown ("c") the GCD touches ("g")

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local TARGET_WORDS = { hasTarget = true, targetEnemy = true, targetBoss = true }
local BUFF_MOMENTS = { up = true, ends = true, missing = true, recast = true }

local function letters(id) return SW.Links().spells[id] end

-- What the client's tables say of a piece.
local function factsOf(B, key)
    local L = SW.Links()
    local sid = B.SpellOf(key)
    local own = sid and letters(sid)
    if not own then return nil end
    local ids, seen = {}, {}
    local function add(id) if not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
    add(sid)
    for id in pairs(B.SpellIDs(key) or {}) do add(id) end
    for i = 1, #ids do
        for _, a in ipairs(L.bySource[ids[i]] or {}) do add(a) end
    end
    local aura, debuff, none = false, false, not B.IsTotem(key)
    local custom = B.IsCustom(key)
    for _, id in ipairs(ids) do
        local v = letters(id)
        if custom and v and not v:find("n", 1, true) then none = false end
        v = v or ""
        if v:find("[bd]") then aura = true end
        if v:find("d", 1, true) then debuff = true end
    end
    return { noAura = none and not aura, debuff = debuff, target = own:find("t", 1, true) ~= nil,
             cooldown = own:find("c", 1, true) ~= nil, gcd = own:find("g", 1, true) ~= nil }
end

local function saysAura(text) return tostring(text):find("%f[%a]de?buff%f[%A]") ~= nil end

-- Every phrase a piece offers: its moments with their actions, its clauses and its
-- What it shows picks.
local function offered(G, C, kind)
    local out = {}
    for _, w in ipairs(G.Words(kind, { more = true })) do
        for _, a in ipairs(w.actions) do out[#out + 1] = G.Describe({ moment = w.moment, action = a }, kind) end
    end
    for _, c in ipairs(C.List()) do
        if C.FitsKind(c.key, kind) then out[#out + 1] = G.ClauseWords(c.key, nil, kind) end
    end
    if G.TakesShows(kind) then
        for _, s in ipairs(G.ShowsChoices(kind)) do out[#out + 1] = G.ShowsPhrase(s, kind) end
    end
    return out
end

-- The wrong words on one piece, as lines.
local function check(G, C, B, key, name, bad, totals)
    local f = factsOf(B, key)
    if not f then return end
    totals.pieces = totals.pieces + 1
    local kind = G.Kind(key)
    local tag = name .. " (" .. tostring(key) .. ")"
    local moments = {}
    for _, w in ipairs(G.Words(kind, { more = true })) do moments[w.moment] = true end
    if f.noAura then
        totals.noAura = totals.noAura + 1
        for m in pairs(BUFF_MOMENTS) do
            if moments[m] then bad[#bad + 1] = tag .. ": no aura, offers " .. m end
        end
        if G.TakesShows(kind) and #G.ShowsChoices(kind) > 1 then bad[#bad + 1] = tag .. ": no aura, offers a buff pick" end
        for _, text in ipairs(offered(G, C, kind)) do
            if saysAura(text) then bad[#bad + 1] = tag .. ": no aura, says \"" .. text .. "\"" end
        end
    elseif not f.debuff then
        for _, text in ipairs(offered(G, C, kind)) do
            if text:find("%f[%a]debuff%f[%A]") then bad[#bad + 1] = tag .. ": no debuff, says \"" .. text .. "\"" end
        end
    end
    if not f.target then
        for m in pairs(TARGET_WORDS) do
            if moments[m] then bad[#bad + 1] = tag .. ": cast at no unit, offers " .. m end
        end
    else
        totals.target = totals.target + 1
    end
    if moments.onlyGcd and not (f.cooldown and f.gcd) then bad[#bad + 1] = tag .. ": no real cooldown, offers onlyGcd" end
end

local totals = { pieces = 0, noAura = 0, target = 0 }

local function report(bad)
    return #bad .. " wrong words:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

for _, class in ipairs(CLASSES) do
    T.test("sweep fits: " .. class .. "'s tray offers only words its spells' data allow", function()
        local _, ns, AB = SW.World(SW.Class(class), { hidden = true })
        local placed = SW.PlaceTray(AB, false)
        local bad = {}
        for _, p in ipairs(placed) do check(ns.Grammar, ns.Conditions, ns.Bridge, p.key, p.name, bad, totals) end
        T.eq(#bad, 0, report(bad))
    end)
end

-- Every class spell a player learns (SkillLineAbility), not passive, one rank per name,
-- added by its id as the editor adds one (Lightning Bolt was).
T.test("sweep fits: every class spell added by its id offers only words its data allow", function()
    local _, ns, AB = SW.World(SW.Class("SHAMAN"), { hidden = true })
    local facts = require("classworld").Facts()
    local names, ids = {}, {}
    for line in io.lines((tostring(stub.PLUGIN_TOC):match("^(.*[/\\])") or "") .. "AuraLinks.lua") do
        local id, name = line:match("^        %[(%d+)%] = \"[a-z]*\", %-%- (.*)$")
        if id then names[tonumber(id)] = name end
    end
    local seen = {}
    local all = {}
    for id in pairs(SW.Links().spells) do all[#all + 1] = id end
    table.sort(all)
    for _, id in ipairs(all) do
        local f, name = facts[id], names[id]
        if f and f.book and not f.passive and name and not seen[name] then
            seen[name] = true
            ids[#ids + 1] = id
        end
    end
    local Ed, D = AB.CdmEditor, AB.CdmData
    local set = D.Ensure(1)
    local bad, added = {}, 0
    for _, id in ipairs(ids) do
        stub.knownSpells[id] = true
        stub.spells[id] = stub.spells[id] or { name = names[id] }
        local key = Ed.KeyForID("spell", tostring(id))
        if key and not set.pieces[key] then
            D.AddPiece(set, key, "icon", 0, 0)
            if set.pieces[key] then
                added = added + 1
                check(ns.Grammar, ns.Conditions, ns.Bridge, key, names[id], bad, totals)
                D.RemovePiece(set, key)
            end
        end
    end
    T.truthy(added >= 400, "spells added by id: " .. added)
    T.eq(#bad, 0, report(bad))
end)

T.test("sweep fits: the sweep met spells with no aura and spells cast at a target", function()
    T.truthy(totals.pieces >= 500, "pieces read: " .. totals.pieces)
    print(string.format("fits sweep: %d pieces, %d with no aura, %d cast at a target", totals.pieces, totals.noAura,
        totals.target))
    T.truthy(totals.noAura >= 100, "with no aura: " .. totals.noAura)
    T.truthy(totals.target >= 100, "cast at a target: " .. totals.target)
end)
