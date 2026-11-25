local stub = require("stub")
local SW = require("sweep_lib")

-- The cost sweep (docs/tasks/w1-totem-mana.md): every class's tray, and every class
-- spell a player can add by its id, each cost word checked against the client's
-- SpellPower rows (EZ-CDM/AuraLinks.lua costs), read here straight from the table:
--   free       no cast the piece holds has a cost row: no "short" moment, no "When I don't
--              have enough" condition or clause, no Mana check recipe
--   a cost     every "enough" phrase names the spell's own powers ("rage", "energy or
--              rage"), never the player's bar

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

-- The powers a spell's words name: its cost rows' powers, combo points left out
-- beside another power.
local function powerWords(list)
    local out = {}
    for _, w in ipairs(list) do
        if w ~= "combo points" or #list == 1 then out[#out + 1] = w end
    end
    return table.concat(out, " or ")
end

-- Every phrase a piece offers that could name a cost: its moments with their
-- actions, its clauses, and its recipes.
local function offered(G, C, kind)
    local out = {}
    for _, w in ipairs(G.Words(kind, { more = true })) do
        for _, a in ipairs(w.actions) do
            out[#out + 1] = { what = w.moment, text = G.Describe({ moment = w.moment, action = a }, kind) }
        end
    end
    for _, c in ipairs(C.List()) do
        if C.FitsKind(c.key, kind) then out[#out + 1] = { what = c.key, text = G.ClauseWords(c.key, nil, kind) } end
    end
    for _, r in ipairs(G.Recipes(kind)) do out[#out + 1] = { what = r, text = r } end
    return out
end

local COST_WORDS = { short = true, noMana = true, manaCheck = true }

-- The powers a piece's casts cost: over its spell and every id it holds (a totem
-- piece's spell may be its buff), first seen first. nil when one id isn't listed.
local function costsOf(B, key)
    local L = SW.Links()
    local sid = B.SpellOf(key)
    if not (sid and L.spells[sid]) then return nil end
    local ids = { sid }
    for id in pairs(B.SpellIDs(key) or {}) do if id ~= sid then ids[#ids + 1] = id end end
    table.sort(ids)
    local out, seen = {}, {}
    for _, id in ipairs(ids) do
        if not L.spells[id] then return nil end
        for _, w in ipairs((L.costs or {})[id] or {}) do
            if not seen[w] then seen[w] = true; out[#out + 1] = w end
        end
    end
    return out
end

local function check(G, C, B, key, name, bad, totals)
    local costs = costsOf(B, key)
    if not costs then return end
    totals.pieces = totals.pieces + 1
    local kind = G.Kind(key)
    local tag = name .. " (" .. tostring(key) .. ")"
    if #costs == 0 then
        totals.free = totals.free + 1
        for _, o in ipairs(offered(G, C, kind)) do
            if COST_WORDS[o.what] or o.text:find("enough", 1, true) then
                bad[#bad + 1] = tag .. ": costs nothing, offers \"" .. o.text .. "\""
            end
        end
        return
    end
    local want = powerWords(costs)
    if want ~= "mana" then totals.other = totals.other + 1 end
    for _, o in ipairs(offered(G, C, kind)) do
        local said = o.text:match("enough (.-)[,.]") or o.text:match("enough (.*)$")
        if said and said ~= want then
            bad[#bad + 1] = tag .. ": costs " .. want .. ", says \"" .. o.text .. "\""
        end
    end
end

local totals = { pieces = 0, free = 0, other = 0 }

local function report(bad)
    return #bad .. " wrong cost words:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

for _, class in ipairs(CLASSES) do
    T.test("sweep cost: " .. class .. "'s tray offers cost words only on spells that cost", function()
        local _, ns, AB = SW.World(SW.Class(class), { hidden = true })
        local placed = SW.PlaceTray(AB, false)
        local bad = {}
        for _, p in ipairs(placed) do check(ns.Grammar, ns.Conditions, ns.Bridge, p.key, p.name, bad, totals) end
        T.eq(#bad, 0, report(bad))
    end)
end

-- Every class spell a player learns (SkillLineAbility), not passive, one rank per name,
-- added by its id as the editor adds one. The player is a Shaman, whose bar is mana, so
-- a rage or energy spell's words must come from its own cost.
T.test("sweep cost: every class spell added by its id names only its own cost", function()
    local _, ns, AB = SW.World(SW.Class("SHAMAN"), { hidden = true })
    local facts = require("classworld").Facts()
    local names, ids = {}, {}
    for line in io.lines((tostring(stub.PLUGIN_TOC):match("^(.*[/\\])") or "") .. "AuraLinks.lua") do
        local id, name = line:match("^        %[(%d+)%] = \"[a-z]*\", %-%- (.*)$")
        if id then names[tonumber(id)] = name end
    end
    local seen, all = {}, {}
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

T.test("sweep cost: the sweep met free spells and spells that cost other than mana", function()
    T.truthy(totals.pieces >= 500, "pieces read: " .. totals.pieces)
    print(string.format("cost sweep: %d pieces, %d free, %d costing other than mana", totals.pieces, totals.free,
        totals.other))
    T.truthy(totals.free >= 50, "free: " .. totals.free)
    T.truthy(totals.other >= 50, "other than mana: " .. totals.other)
end)
