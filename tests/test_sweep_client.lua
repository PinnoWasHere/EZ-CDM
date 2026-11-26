local stub = require("stub")
local SW = require("sweep_lib")

-- The client tier sweep (docs/tasks/w1-batch-b.md): every class's tray, and every
-- class spell a player can add by its id, as a Shaman, a Druid and a Hunter. Each
-- batch B word is checked against the client's tables (EZ-CDM/AuraLinks.lua), read
-- here straight from them:
--   targetLow            only on a spell cast at a unit you pick (letter t)
--   powerLow             only where every power the piece's casts cost is a bar the
--                        class's player has as a percent (classPowers; mana, rage,
--                        energy, focus), and its words name those powers
--   playerLow, powerLow  only on a piece you can cast (a cooldown or a spell button)
--   all three            no sound: a client part has no edge to play one on

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local PERCENT = { mana = true, rage = true, energy = true, focus = true }
local BATCH = { targetLow = true, playerLow = true, powerLow = true }

local totals = { pieces = 0 }
for k in pairs(BATCH) do totals[k] = 0 end

-- Every id a piece's casts come from: its spell and every id it holds. nil when one
-- isn't in the client's tables.
local function idsOf(B, key)
    local L = SW.Links()
    local sid = B.SpellOf(key)
    if not (sid and L.spells[sid]) then return nil end
    local ids = { sid }
    for id in pairs(B.SpellIDs(key) or {}) do if id ~= sid then ids[#ids + 1] = id end end
    table.sort(ids)
    for _, id in ipairs(ids) do
        if not L.spells[id] then return nil end
    end
    return ids, sid
end

-- The powers those casts cost, first seen first, combo points dropped beside another.
local function costsOf(ids)
    local L, out, seen = SW.Links(), {}, {}
    for _, id in ipairs(ids) do
        for _, w in ipairs(L.costs[id] or {}) do
            if not seen[w] then seen[w] = true; out[#out + 1] = w end
        end
    end
    local words = {}
    for _, w in ipairs(out) do
        if w ~= "combo points" or #out == 1 then words[#words + 1] = w end
    end
    return words
end

local function check(G, C, B, key, name, class, bad)
    local ids, sid = idsOf(B, key)
    if not ids then return end
    totals.pieces = totals.pieces + 1
    local kind = G.Kind(key)
    local tag = class .. " " .. name .. " (" .. tostring(key) .. ")"
    local L = SW.Links()
    local letters = L.spells[sid]
    local offered = {}
    for _, w in ipairs(G.Words(kind, { more = true })) do
        if BATCH[w.moment] then
            offered[w.moment] = true
            for _, a in ipairs(w.actions) do
                if a == "sound" then bad[#bad + 1] = tag .. ": " .. w.moment .. " offers a sound" end
            end
        end
    end
    for k in pairs(BATCH) do
        if C.FitsKind(k, kind) then offered[k] = true end
    end
    for k in pairs(offered) do totals[k] = totals[k] + 1 end
    local castable = kind.cooldown == true or kind.button == true
    if offered.targetLow and not letters:find("t", 1, true) then
        bad[#bad + 1] = tag .. ": target health on a spell cast at no unit (" .. letters .. ")"
    end
    if (offered.playerLow or offered.powerLow) and not castable then
        bad[#bad + 1] = tag .. ": castable words on a piece you can't cast"
    end
    local words = costsOf(ids)
    local mine = {}
    for _, w in ipairs(L.classPowers[class] or {}) do mine[w] = true end
    local fit = #words > 0
    for _, w in ipairs(words) do fit = fit and PERCENT[w] == true and mine[w] == true end
    if offered.powerLow then
        if not fit then
            bad[#bad + 1] = tag .. ": power words on a cost the class has no bar for (" .. table.concat(words, ", ") .. ")"
        else
            local said = G.MomentWords("powerLow", 30, kind)
            local want = "When my " .. table.concat(words, " or ") .. " is below 30%"
            if said ~= want then bad[#bad + 1] = tag .. ": says \"" .. said .. "\", costs " .. table.concat(words, ", ") end
        end
    elseif fit and castable then
        bad[#bad + 1] = tag .. ": costs " .. table.concat(words, ", ") .. " but has no power words"
    end
    if castable and not offered.playerLow then bad[#bad + 1] = tag .. ": castable without health words" end
end

local function report(bad)
    return #bad .. " misplaced words:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

for _, class in ipairs(CLASSES) do
    T.test("sweep client: " .. class .. "'s tray offers batch B words only where they fit", function()
        local _, ns, AB = SW.World(SW.Class(class), { hidden = true })
        local placed = SW.PlaceTray(AB, false)
        local bad = {}
        for _, p in ipairs(placed) do check(ns.Grammar, ns.Conditions, ns.Bridge, p.key, p.name, class, bad) end
        T.eq(#bad, 0, report(bad))
    end)
end

-- Every class spell a player learns (SkillLineAbility), not passive, one rank per name,
-- added by its id as the editor adds one: as a Shaman (mana alone), a Druid (mana,
-- rage and energy) and a Hunter (mana; its pet spells cost focus).
for _, class in ipairs({ "SHAMAN", "DRUID", "HUNTER" }) do
    T.test("sweep client: every class spell added by id, as a " .. class, function()
        local _, ns, AB = SW.World(SW.Class(class), { hidden = true })
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
                    check(ns.Grammar, ns.Conditions, ns.Bridge, key, names[id], class, bad)
                    D.RemovePiece(set, key)
                end
            end
        end
        T.truthy(added >= 400, "spells added by id: " .. added)
        T.eq(#bad, 0, report(bad))
    end)
end

T.test("sweep client: the sweep met each batch B word and pieces where each doesn't fit", function()
    print(string.format("client sweep: %d pieces; targetLow %d, playerLow %d, powerLow %d",
        totals.pieces, totals.targetLow, totals.playerLow, totals.powerLow))
    T.truthy(totals.pieces >= 1000, "pieces read: " .. totals.pieces)
    for k in pairs(BATCH) do
        T.truthy(totals[k] >= 20, k .. " offered: " .. totals[k])
        T.truthy(totals[k] < totals.pieces, k .. " not offered everywhere")
    end
end)
