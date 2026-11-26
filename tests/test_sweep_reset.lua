local SW = require("sweep_lib")

-- The reset sweep (docs/tasks/w1-reset.md): every class's tray placed, each piece read
-- under each What it shows pick. "When its cooldown resets" shows only on a piece whose
-- spell is a reset spell of that class in AuraLinks.resets (Daylight UI's Proc Alerts
-- list), and its clause the same.

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local offered = {}

local function grounded(B, key, class)
    local r = SW.Links().resets[B.SpellOf(key)]
    return r ~= nil and r.class == class
end

for _, class in ipairs(CLASSES) do
    T.test("sweep reset: " .. class .. " offers When its cooldown resets only on its reset spells", function()
        local c = SW.Class(class)
        T.truthy(c, class .. " is in the catalogue")
        local _, ns, AB = SW.World(c, { hidden = true })
        local placed = SW.PlaceTray(AB, false)
        local G, B, C = ns.Grammar, ns.Bridge, ns.Conditions
        local bad = {}
        for _, p in ipairs(placed) do
            local want = grounded(B, p.key, class)
            local picks = { false }
            if G.Kind(p.key).trackRow then picks = { false, "both", "cooldown", "buff" } end
            for _, pick in ipairs(picks) do
                local kind = G.Kind(p.key, nil, pick or nil)
                local tag = p.name .. " (" .. tostring(p.key) .. ", " .. tostring(pick or "saved") .. ")"
                local has = false
                for _, w in ipairs(G.Words(kind, { more = true })) do has = has or w.moment == "reset" end
                if has ~= want then bad[#bad + 1] = tag .. (has and ": offered" or ": missing") end
                if C.FitsKind("cooldownReset", kind) ~= want then bad[#bad + 1] = tag .. ": clause" end
                if has then offered[#offered + 1] = class .. " " .. p.name end
            end
        end
        T.truthy(#placed >= 50, "pieces placed: " .. #placed)
        T.eq(#bad, 0, #bad .. " wrong:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 30)))
    end)
end

T.test("sweep reset: the sweep met Stormstrike, and nothing else", function()
    local seen = {}
    for _, o in ipairs(offered) do seen[o] = true end
    local list = {}
    for o in pairs(seen) do list[#list + 1] = o end
    table.sort(list)
    T.eq(table.concat(list, ", "), "SHAMAN Stormstrike")
end)
