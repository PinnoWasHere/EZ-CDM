local stub = require("stub")
local SW = require("sweep_lib")

-- The ready sweep (docs/tasks/w1-ready-totemdown.md): every class's tray, and every class
-- spell added by its id. Each piece's offers are checked against the client's own tables
-- (AuraLinks.spells letter c, a real cooldown) and Daylight UI's totem answers:
--   real cooldown, no totem   "When it's ready" takes every EZ look (offCooldown merged);
--                             no chip of offCooldown's own
--   real cooldown, a totem    offCooldown is its own chip, "When it's off cooldown"
--   no real cooldown          offCooldown nowhere, as a moment or a clause
--   a totem showing its time  "When my totem is down" takes every EZ look (totemDown merged)
--   any other totem           totemDown is its own chip
--   no totem                  totemDown nowhere
-- And the ready glow and sound with an "and" clause (docs/tasks/w1-ready-owned.md): EZ-CDM's
-- line where "When it's ready" merges offCooldown or totemDown, written to that condition's
-- field and read back as written; refused anywhere else.
-- And the fill (docs/tasks/w2-fill.md): "While it's cooling down" takes it where "When it's
-- ready" takes the looks (cooling or totemUp merged), "While it's active" where a recast
-- moment shows Daylight UI clocks the buff (active merged), never on a debuff; cooling and
-- active never get a chip of their own.

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local function chips(G, kind)
    local out = {}
    for _, w in ipairs(G.Words(kind, { more = true })) do
        out[w.moment] = {}
        for _, a in ipairs(w.actions) do out[w.moment][a] = true end
    end
    return out
end

local function check(G, C, B, key, name, bad, totals)
    local L = SW.Links()
    local sid = B.SpellOf(key)
    local letters = sid and L.spells[sid]
    if type(letters) ~= "string" then return end
    totals.pieces = totals.pieces + 1
    local kind = G.Kind(key)
    local real = letters:find("c", 1, true) ~= nil
    local totem = B.IsTotem(key) == true
    local totemTime = totem and B.Shows(key) == "totem"
    local m = chips(G, kind)
    -- Daylight UI's ready rows show on a piece with a cooldown face.
    local readyFace = m.ready ~= nil and m.ready.show == true
    local looks = m.ready ~= nil and m.ready.flash == true and m.ready.flare == true
    local tag = name .. " (" .. tostring(key) .. ")"
    local function say(why) bad[#bad + 1] = tag .. ": " .. why end
    local wantLooks = readyFace and ((real and not totem) or totemTime)
    if looks ~= wantLooks then
        say(wantLooks and "When it's ready lacks EZ-CDM's looks" or "When it's ready offers EZ-CDM's looks")
    end
    local ownCd = real and totem and readyFace
    if (m.offCooldown ~= nil) ~= ownCd then
        say(ownCd and "no When it's off cooldown chip" or "a When it's off cooldown chip")
    end
    if C.FitsKind("offCooldown", kind) ~= (real and readyFace) then say("offCooldown fits wrongly") end
    if (m.totemDown ~= nil) ~= (totem and not totemTime) then
        say(m.totemDown and "a When my totem is down chip" or "no When my totem is down chip")
    end
    if C.FitsKind("totemDown", kind) ~= totem then say("totemDown fits wrongly") end
    local coolingFill = m.cooldown ~= nil and m.cooldown.fill == true
    if coolingFill ~= wantLooks then
        say(wantLooks and "While it's cooling down lacks the fill" or "While it's cooling down offers the fill")
    end
    if C.FitsKind("cooling", kind) ~= (readyFace and real and not totem) then say("cooling fits wrongly") end
    -- Active needs the buff told up or down, as Daylight UI's own "While it's active" rows.
    local wantActive = m.recast ~= nil and kind.aura ~= "debuff" and kind.tracked == true
    if (m.up ~= nil and m.up.fill == true) ~= wantActive then
        say(wantActive and "While it's active lacks the fill" or "While it's active offers the fill")
    end
    if m.cooling or m.active then say("a chip of cooling's or active's own") end
    if coolingFill then totals.cooling = totals.cooling + 1 end
    if wantActive then totals.active = totals.active + 1 end
    local wantOwn = readyFace and ((real and not totem) or totemTime)
    for _, a in ipairs({ "glow", "sound" }) do
        if m.ready and m.ready[a] then
            local l = { moment = "ready", action = a, clauses = { { cond = "inCombat" } } }
            if a == "sound" then l.value = "dui:quest" end
            if G.TakesClauses({ moment = "ready", action = a }, kind) ~= wantOwn then
                say("ready " .. a .. " takes and wrongly")
            end
            local fields, problems = G.Compile({ lines = { l } }, kind)
            if wantOwn then
                local ck = G.ReadyCondition(kind)
                local f = ck and fields["ez:" .. ck .. ":" .. a]
                local back = G.Decompile(fields, kind).lines[1]
                if #problems > 0 or not f or fields.readyGlow ~= nil or fields.readySound ~= nil then
                    say("ready " .. a .. " with a clause doesn't compile to EZ-CDM's line")
                elseif not (back and back.moment == "ready" and back.action == a and back.clauses
                    and back.clauses[1].cond == "inCombat") then
                    say("ready " .. a .. " with a clause doesn't read back")
                end
                if a == "glow" then totals.owned = totals.owned + 1 end
            elseif not (problems[1] and problems[1].code == "pair") then
                say("ready " .. a .. " with a clause isn't refused")
            end
        end
    end
    if real and readyFace then totals.real = totals.real + 1 end
    if totem then totals.totems = totals.totems + 1 end
    if ownCd then totals.own = totals.own + 1 end
end

local totals = { pieces = 0, real = 0, totems = 0, own = 0, owned = 0, cooling = 0, active = 0 }

local function report(bad)
    return #bad .. " wrong offers:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

for _, class in ipairs(CLASSES) do
    T.test("sweep ready: " .. class .. "'s tray offers each moment only where it fits", function()
        local _, ns, AB = SW.World(SW.Class(class), { hidden = true })
        local placed = SW.PlaceTray(AB, false)
        local bad = {}
        for _, p in ipairs(placed) do check(ns.Grammar, ns.Conditions, ns.Bridge, p.key, p.name, bad, totals) end
        T.eq(#bad, 0, report(bad))
    end)
end

-- Every class spell a player learns, one rank per name, added by its id on a Shaman, as
-- the cost sweep adds them.
T.test("sweep ready: every class spell added by its id offers each moment only where it fits", function()
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

-- No Daylight UI totem on Forever has a real cooldown (Grounding Totem and the like are
-- catalogue cooldowns), so the own chip is counted, not required; test_w1_ready_totemdown
-- covers it on a made kind.
T.test("sweep ready: the sweep met real cooldowns and totems", function()
    print(string.format("ready sweep: %d pieces, %d real cooldowns, %d totems, %d own off-cooldown chips, "
        .. "%d ready glows that take and, %d cooling down fills, %d active fills", totals.pieces, totals.real,
        totals.totems, totals.own, totals.owned, totals.cooling, totals.active))
    T.truthy(totals.cooling >= 100, "cooling down fills: " .. totals.cooling)
    T.truthy(totals.active >= 20, "active fills: " .. totals.active)
    T.truthy(totals.owned >= 100, "ready glows that take and: " .. totals.owned)
    T.truthy(totals.pieces >= 500, "pieces: " .. totals.pieces)
    T.truthy(totals.real >= 100, "real cooldowns: " .. totals.real)
    T.truthy(totals.totems >= 5, "totems: " .. totals.totems)
end)
