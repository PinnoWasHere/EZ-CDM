local SW = require("sweep_lib")

-- The universality sweep (tests/sweep_lib.lua), class group a, and the
-- sweep's own check that it finds every class.

T.test("sweep: the catalogue's nine classes, each variant in one group", function()
    local found, sets = {}, {}
    for _, c in ipairs(SW.Classes()) do
        T.isnil(found[c.class], c.class .. " has one set")
        T.isnil(sets[c.set], "set " .. c.set .. " has one class")
        T.truthy(c.shared >= 10, c.class .. " shares " .. c.shared .. " spells with Daylight UI's list")
        found[c.class], sets[c.set] = true, true
    end
    -- Each class's variants run once, across the groups.
    local grouped = {}
    for _, list in pairs(SW.GROUPS) do
        for _, entry in ipairs(list) do
            local name, variants = SW.Entry(entry)
            T.truthy(found[name], name .. " is a catalogue class")
            for _, v in ipairs(variants) do
                local id = name .. " " .. v
                T.isnil(grouped[id], id .. " is in one group")
                grouped[id] = true
            end
        end
    end
    for name in pairs(found) do
        for _, v in ipairs(SW.VARIANT_ORDER) do T.truthy(grouped[name .. " " .. v], name .. " " .. v .. " is in a group") end
    end
    T.eq(T.count(found), 9)
end)

-- Your own proc, by the aura links (EZ-CDM/AuraLinks.lua) and the spellbook
-- stand-ins (tests/spell_facts.lua), with the game's buff viewers hidden.
T.test("sweep procs: forms and cast auras are no procs, talent procs are", function()
    local function procs(class, yes, no)
        local kinds = SW.Kinds(class)
        for _, name in ipairs(yes) do
            local k = kinds[name]
            T.truthy(k, class .. " " .. name .. " is placed")
            T.truthy(k and k.proc, class .. " " .. name .. " is a proc")
        end
        for _, name in ipairs(no) do
            local k = kinds[name]
            T.truthy(k, class .. " " .. name .. " is placed")
            T.falsy(k and k.proc, class .. " " .. name .. " is no proc")
        end
        return kinds
    end
    procs("SHAMAN", { "Improved Stormstrike", "Elemental Focus", "Flurry" }, { "Ghost Wolf" })
    procs("PRIEST", { "Spirit Tap", "Inspiration" }, { "Shadowform" })
    procs("DRUID", { "Omen of Clarity", "Nature's Grace" }, { "Moonkin Aura" })
    local mage = procs("MAGE", { "Arcane Concentration", "Heating Up" }, { "Polymorph" })
    T.truthy(mage["Polymorph"].harmful, "the game calls Polymorph harmful")
    procs("ROGUE", {}, { "Sap" })
    procs("WARLOCK", {}, { "Fear", "Banish" })
    procs("WARRIOR", { "Flurry", "Enrage", "Victorious" }, {})
    procs("HUNTER", { "Deadly Aspects" }, {})
end)

-- The class world's C_Spell.IsSpellHarmful comes from the client's SpellEffect targets
-- (tests/spell_facts.lua), so a heal or buff cast on a friend reads as not harmful.

T.test("harmful flag: the game's answer for debuffs and for friendly casts", function()
    local function check(class, yes, no)
        local kinds = SW.Kinds(class)
        for _, name in ipairs(yes) do
            T.truthy(kinds[name], class .. " " .. name .. " is placed")
            T.truthy(kinds[name] and kinds[name].harmful, class .. " " .. name .. " is harmful")
        end
        for _, name in ipairs(no) do
            T.truthy(kinds[name], class .. " " .. name .. " is placed")
            T.falsy(kinds[name] and kinds[name].harmful, class .. " " .. name .. " is not harmful")
        end
    end
    check("MAGE", { "Polymorph" }, {})
    check("ROGUE", { "Sap" }, {})
    check("WARLOCK", { "Fear", "Banish" }, {})
    check("SHAMAN", { "Flame Shock" }, {})
    check("DRUID", { "Moonfire" }, { "Rejuvenation", "Mark of the Wild" })
    check("PRIEST", {}, { "Renew", "Power Word: Fortitude" })
end)

SW.UntimedTests("a")
SW.Tests("a")
