local SW = require("sweep_lib")

-- The wording sweep: every class's tray placed, each piece read under each What it
-- shows pick. The client's spell facts (EZ-CDM/AuraLinks.lua spells), read here
-- straight from the table, say what the words may name:
--   no real cooldown  no almost-ready moment, the cooling down moment only for the
--                     global cooldown's sweep, and no "its cooldown" or "cooling down"
--                     in any word (a totem's time is its cooldown, so totems are out)
--   a debuff          no "buff" in any word the piece reads in
-- An EZ-CDM condition's moment and clause words count only on a piece it fits: elsewhere
-- the piece never reads them ("When its cooldown resets" fits only a spell a talent resets).

local function saysBuff(text) return tostring(text):find("%f[%a]buff%f[%A]") ~= nil end

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local SWEEP = { nosweep = true, nogcd = true }
local function saysCooldown(text) return text:find("its cooldown", 1, true) or text:find("cooling down", 1, true) end

-- What the facts say of a piece: no real cooldown, an aura on an enemy.
local function factsOf(B, key)
    local spells = SW.Links().spells
    local sid = B.SpellOf(key)
    local own = sid and spells[sid]
    local noCd = own ~= nil and not own:find("c", 1, true) and not B.IsTotem(key)
    local debuff = false
    local ids = { sid }
    for id in pairs(B.SpellIDs(key) or {}) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do
        if (spells[id] or ""):find("d", 1, true) then debuff = true end
    end
    return noCd, debuff
end

-- Every phrase a piece reads in under kind.
local function phrases(G, C, kind)
    local out = {}
    local fits, unfit = {}, {}
    for _, c in ipairs(C.List()) do
        if C.FitsKind(c.key, kind) then fits[c.moment] = true else unfit[c.moment] = true end
    end
    for _, s in ipairs(G.SHOWS) do out[#out + 1] = G.ShowsPhrase(s, kind) end
    out[#out + 1] = G.FixText("shows", kind)
    out[#out + 1] = G.FixText("clause", kind)
    for m in pairs(G.WORDING.moments) do
        if fits[m] or not unfit[m] then out[#out + 1] = (G.MomentWords(m, nil, kind)) end
    end
    for _, c in ipairs(C.List()) do
        if C.FitsKind(c.key, kind) then out[#out + 1] = G.ClauseWords(c.key, nil, kind) end
    end
    for _, w in ipairs(G.Words(kind)) do
        for _, a in ipairs(w.actions) do out[#out + 1] = G.Describe({ moment = w.moment, action = a }, kind) end
    end
    local hidden = G.HiddenNote(kind, { moment = "blocked", action = "gray" })
    if hidden then out[#out + 1] = hidden.text end
    local why = G.NeverWords("cantCast", "noBuff", kind)
    if why then out[#out + 1] = why end
    return out
end

local totals = { noCd = 0, debuff = 0 }

for _, class in ipairs(CLASSES) do
    T.test("sweep words: " .. class .. " pieces name a cooldown or a buff only where the data has one", function()
        local c = SW.Class(class)
        T.truthy(c, class .. " is in the catalogue")
        local _, ns, AB = SW.World(c, { hidden = true })
        local placed = SW.PlaceTray(AB, false)
        local G, B, C = ns.Grammar, ns.Bridge, ns.Conditions
        local bad = {}
        for _, p in ipairs(placed) do
            local noCd, debuff = factsOf(B, p.key)
            if noCd then totals.noCd = totals.noCd + 1 end
            if debuff then totals.debuff = totals.debuff + 1 end
            local picks = { false }
            if G.Kind(p.key).trackRow then picks = { false, "both", "cooldown", "buff" } end
            for _, pick in ipairs(picks) do
                local kind = G.Kind(p.key, nil, pick or nil)
                local tag = p.name .. " (" .. tostring(p.key) .. ", " .. tostring(pick or "saved") .. ")"
                if noCd then
                    for _, w in ipairs(G.Words(kind)) do
                        for _, a in ipairs(w.actions) do
                            if w.moment == "almost" or (w.moment == "cooldown" and not SWEEP[a]) then
                                bad[#bad + 1] = tag .. ": offers " .. w.moment .. " " .. a
                            end
                        end
                    end
                    for _, text in ipairs(phrases(G, C, kind)) do
                        if saysCooldown(text) then bad[#bad + 1] = tag .. ": \"" .. text .. "\"" end
                    end
                end
                if debuff then
                    for _, text in ipairs(phrases(G, C, kind)) do
                        if saysBuff(text) then bad[#bad + 1] = tag .. ": \"" .. text .. "\"" end
                    end
                end
            end
        end
        T.truthy(#placed >= 50, "pieces placed: " .. #placed)
        T.eq(#bad, 0, #bad .. " wrong words:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 30)))
    end)
end

T.test("sweep words: the sweep met spells with no cooldown and debuffs", function()
    T.truthy(totals.noCd >= 20, "pieces with no real cooldown: " .. totals.noCd)
    T.truthy(totals.debuff >= 30, "debuff pieces: " .. totals.debuff)
end)
