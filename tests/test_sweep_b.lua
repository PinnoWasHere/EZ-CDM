local SW = require("sweep_lib")

-- The universality sweep (tests/sweep_lib.lua), class group b, and the
-- check that each of its checks fails when it should.

-- A warrior's Thunder Clap and Battle Shout, with EZ-CDM broken six ways on
-- purpose: each check must report it.
T.test("sweep: each check fails when EZ-CDM is broken on purpose", function()
    local shout
    local function patch(ns)
        local G, B, E = ns.Grammar, ns.Bridge, ns.Effects
        -- A glow's own style is lost on the way back.
        local decompile = G.Decompile
        G.Decompile = function(...)
            local rules, problems = decompile(...)
            for _, l in ipairs(rules.lines) do l.style = nil end
            return rules, problems
        end
        -- A word the card doesn't offer.
        local fits = G.Fits
        G.Fits = function(kind, m, a)
            if m == "ends" and a == "sound" then return true end
            return fits(kind, m, a)
        end
        -- A write that moves the piece.
        local set = B.SetSpellValue
        B.SetSpellValue = function(g, key, field, value)
            local ok, why = set(g, key, field, value)
            if field == "readySound" then
                local p = B.Layout(g).pieces[key]
                p.x = (p.x or 0) + 1
            end
            return ok, why
        end
        -- The up ring never reaches a button.
        E.Get = function() return nil end
        -- A recipe with a line no piece takes.
        local apply = G.ApplyRecipe
        G.ApplyRecipe = function(rules, key)
            apply(rules, key)
            if key == "readyAlert" then rules.lines[#rules.lines + 1] = { moment = "ready", action = "tint" } end
            return rules
        end
        -- An error on one piece.
        local extras = G.Extras
        G.Extras = function(kind)
            if kind and kind.key == shout then error("broken on purpose") end
            return extras(kind)
        end
    end
    local res = SW.Run(SW.Class("WARRIOR"), "hidden", { patch = patch, only = function(p)
        if p.name == "Battle Shout" then shout = p.key end
        return p.name == "Thunder Clap" or p.name == "Battle Shout"
    end })
    T.eq(#res.placed, 2, "both pieces placed")
    local function has(check, text)
        for _, f in ipairs(res.fails[check]) do
            if f.text:find(text, 1, true) then return true end
        end
        return false
    end
    T.truthy(has("words", "glow, style"), "words: a lost style")
    T.truthy(has("card", "ends(sound)"), "card: a word the card lacks")
    T.truthy(has("place", "moved a piece"), "place: a moved piece")
    T.truthy(has("effects", "the up ring is offered and saved, but no button has it"), "effects: a lost ring")
    T.truthy(has("kind", "broken on purpose"), "kind: an error")
    T.truthy(has("recipes", "recipe readyAlert: compiles with pair"), "recipes: a recipe that doesn't compile")
    T.eq(#res.fails.world, 0, "the world itself still loads")
end)
SW.UntimedTests("b")
SW.Tests("b")
