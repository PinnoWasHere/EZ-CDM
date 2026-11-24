local stub = require("stub")
local R = require("repro_world")

-- The bug report (EZ-CDM/Report.lua) and its offline repro (tests/repro_world.lua):
-- the text round-trips, holds nothing personal, refuses garbage, and a Mage's and a
-- Druid's reports rebuild into worlds that show what EZ-CDM does.

local function noErrors()
    T.eq(#stub.errors, 0, "errors: " .. table.concat(stub.errors, " | "))
end

local CLEARCASTING, ARCANE_CONCENTRATION, MOONFIRE = 12536, 11213, 9835

-- ---------------------------------------------------------------------
-- The text
-- ---------------------------------------------------------------------

T.test("report: serialize round-trips every kind of value, keys and lists", function()
    local Report = R.Report()
    local t = { 1, 2.5, -3, "a", true, false,
                nested = { list = { 10, 20, { deep = "x" } }, [7] = "seven", [-2] = 0.125 },
                tricky = "with } and ] and S5: and N1; and\nlines and \0 nul", empty = {},
                color = { 0.2, 0.4, 0.6 }, pi = math.pi, big = 2 ^ 40 }
    local text = Report.Serialize(t)
    T.deq(Report.Deserialize(text), t, "round trip")
    T.deq(Report.Deserialize(Report.Serialize({})), {}, "an empty table")
    T.isnil(Report.Deserialize(text .. "x"), "trailing text refused")
    T.isnil(Report.Deserialize("N1;"), "a top level that's no table refused")
end)

T.test("report: base64 matches the standard vectors and reads its own back", function()
    local Report = R.Report()
    local vectors = { [""] = "", f = "Zg==", fo = "Zm8=", foo = "Zm9v", foob = "Zm9vYg==", fooba = "Zm9vYmE=",
                      foobar = "Zm9vYmFy" }
    for plain, coded in pairs(vectors) do
        T.eq(Report.Encode64(plain), coded, plain)
        T.eq(Report.Decode64(coded), plain, coded)
    end
    local all = {}
    for i = 0, 255 do all[#all + 1] = string.char(i) end
    T.eq(Report.Decode64(Report.Encode64(table.concat(all))), table.concat(all), "every byte")
    T.isnil(Report.Decode64("Zm9v!"), "a character Base64 doesn't use")
end)

T.test("report: Parse refuses garbage with a reason", function()
    local Report = R.Report()
    local P = Report.PREFIX
    local cases = {
        { nil, "empty" }, { "", "empty" }, { "   \n", "empty" },
        { "a bug: my glow is gone", "prefix" },
        { P, "damaged" },
        { P .. "!!!!", "damaged" },
        { P .. "Zm9vYmFy", "damaged" },
        { P .. Report.Encode64("{S1:vN1;"), "damaged" },
        { P .. Report.Encode64("{S1:vN1;}"), "damaged" },
        { P .. Report.Encode64(Report.Serialize({ v = 99, pieces = {}, rules = {} })), "newer" },
        { P .. Report.Encode64(string.rep("{S1:a", 40) .. string.rep("}", 40)), "damaged" },
        { P .. string.rep("A", 300000), "damaged" },
    }
    for i, c in ipairs(cases) do
        local t, why = Report.Parse(c[1])
        T.isnil(t, "case " .. i)
        T.eq(why, c[2], "case " .. i)
    end
    local ok = Report.Parse("pasted: " .. P .. Report.Encode64(Report.Serialize({ v = 1, pieces = {}, rules = {} }))
        .. " thanks!")
    T.truthy(ok, "a report inside other text")
end)

-- ---------------------------------------------------------------------
-- A Mage's report
-- ---------------------------------------------------------------------

local MAGE = {
    { "Arcane Concentration", { { moment = "up", action = "glow" } } },
    { "Fire Blast", { { moment = "ready", action = "glow" }, { moment = "cooldown", action = "fade", value = 0.25 } } },
    { "Frost Nova", { { moment = "recast", action = "glow", at = 4 } } },
}

-- Every key anywhere in t, as "path".
local function keysIn(t, path, out)
    out = out or {}
    for k, v in pairs(t) do
        local p = (path and path .. "." or "") .. tostring(k)
        out[#out + 1] = { key = k, path = p }
        if type(v) == "table" then keysIn(v, p, out) end
    end
    return out
end

T.test("report: a Mage's report holds the class, layout, spells and EZ-CDM's rules", function()
    local text, w = R.Sample("MAGE", MAGE)
    noErrors()
    local Report = w.ns.Report
    T.eq(text:sub(1, #Report.PREFIX), Report.PREFIX)
    T.truthy(text:find("^EZCDM1:[%w%+/]+=*$"), "one line of Base64")
    T.truthy(#text < 4000, "a few pieces fit a chat message: " .. #text)
    local t = assert(Report.Parse(text))
    T.eq(t.class, "MAGE")
    T.eq(t.v, 1)
    T.eq(t.ez, "0.1.0", "EZ-CDM's version from its .toc")
    T.deq(t.api, { 1, 14 })
    T.deq(t.game, { "1.60.1", "71037", 16001 })
    T.eq(t.spec, 1)
    T.eq(t.set, 1)
    T.truthy(t.hidden.BuffIconCooldownViewer, "the buff viewers' Edit Mode setting")
    local B = w.ns.Bridge
    local set = w.AB.CdmData.Get(1)
    local n = 0
    for key, p in pairs(set.pieces) do
        n = n + 1
        T.truthy(t.pieces[key], "piece " .. tostring(key))
        T.eq(t.pieces[key].shape, p.shape)
        T.eq(t.spells[key].id, B.SpellOf(key))
        T.eq(t.spells[key].drawn, B.DrawnBy(key))
    end
    T.eq(n, 3)
    T.eq(T.count(t.pieces), 3)
    local profile = B.ProfileOf(1)
    T.deq(t.rules.upGlow, EZCDMDB.upGlow[profile], "the up glow rules, whole")
    T.deq(t.rules.fallOff, EZCDMDB.fallOff[profile], "the fall-off rules, whole")
    local known = {}
    for _, id in ipairs(t.known) do known[id] = true end
    T.truthy(known[ARCANE_CONCENTRATION], "the talent is known")
    T.truthy(known[-CLEARCASTING], "its proc's aura is no spell of the player's")
end)

T.test("report: an EZ-CDM rule table nobody has listed yet goes in whole", function()
    local text, w = R.Sample("MAGE", { MAGE[1] })
    local profile = w.ns.Bridge.ProfileOf(1)
    EZCDMDB.futureThing = { [profile] = { anything = { 1, 2 } }, [profile .. "x"] = { other = true } }
    EZCDMDB.drawer = { open = true }
    local t = assert(w.ns.Report.Parse(w.ns.Report.Build()))
    T.deq(t.rules.futureThing, { anything = { 1, 2 } }, "this profile's part only")
    T.isnil(t.rules.drawer, "a table with no profile part stays out")
    T.truthy(text ~= nil)
end)

T.test("report: nothing personal is in the text", function()
    local _, w = R.Sample("MAGE", MAGE)
    local B = w.ns.Bridge
    local id = B.ProfileOf(1)
    w.AB.CdmData.Profile(id).name = "Zarvokk's raid set"
    stub.units.player.name, stub.units.target.name = "Zarvokk", "Gnarlhide"
    local text = w.ns.Report.Build()
    local raw = w.ns.Report.Decode64(text:sub(#w.ns.Report.PREFIX + 1))
    T.eq(B.Profile(id).name, "Zarvokk's raid set", "the profile is named")
    local names = { "Zarvokk", "Gnarlhide", stub.playerName, stub.PLAYER_GUID, tostring(id) }
    for _, name in ipairs(names) do
        if type(name) == "string" and name ~= "" then
            T.falsy(raw:find(name, 1, true), "the text holds " .. name)
        end
    end
    T.isnil(w.ns.Report.Parse(text).profile, "no profile id or name")
    for _, k in ipairs(keysIn(w.ns.Report.Parse(text))) do
        T.falsy(k.key == "x" or k.key == "y", "a screen position at " .. k.path)
        T.falsy(k.key == "name" or k.key == "realm" or k.key == "guild", "a name at " .. k.path)
    end
end)

-- ---------------------------------------------------------------------
-- The repro
-- ---------------------------------------------------------------------

-- The trace's lines for one piece's rows, by step: { [step] = line }.
local function rows(trace)
    local out, stepName = {}, nil
    for line in trace:gmatch("[^\n]+") do
        local s = line:match("^%s*%d+ (%S.-)%s*$")
        if s and not line:find("shown") and not line:find("hidden") then
            stepName = s
        elseif stepName then
            out[#out + 1] = { step = stepName, line = line }
        end
    end
    return out
end

local function find(list, stepName, nth)
    local seen = 0
    for _, r in ipairs(list) do
        if r.step == stepName then
            seen = seen + 1
            if seen == (nth or 1) then return r.line end
        end
    end
    error("no step " .. stepName)
end

T.test("repro: a Mage's report rebuilds; Clearcasting's ring comes and goes with the proc", function()
    local text = R.Sample("MAGE", MAGE)
    local w, report, missed = R.Build(text)
    T.eq(#missed, 0, "every piece placed")
    T.eq(#R.Keys(w, report), 3)
    local key = R.Keys(w, report, CLEARCASTING)[1]
    T.truthy(key, "Clearcasting finds the Arcane Concentration piece")
    local about = table.concat(R.Describe(w, report, key), "\n")
    T.truthy(about:find("While it's active, glow.", 1, true), about)
    T.truthy(about:find("proc=true", 1, true), about)
    T.truthy(about:find("ez       upGlow=true", 1, true), about)
    local list = rows(R.Trace(text, { spell = CLEARCASTING, script = "proc" }))
    T.truthy(find(list, "idle"):find("ring=0/"), find(list, "idle"))
    T.truthy(find(list, "proc up"):find("ring=1/"), "out of a fight: " .. find(list, "proc up"))
    T.truthy(find(list, "proc down"):find("ring=0/"), find(list, "proc down"))
    T.truthy(find(list, "proc up", 2):find("ring=1/"), "in a fight: " .. find(list, "proc up", 2))
    T.truthy(find(list, "proc down", 2):find("ring=0/"), find(list, "proc down", 2))
    noErrors()
end)

T.test("repro: a Druid's Moonfire glows ready, up, then about to fall off, and a dead target clears it", function()
    local text = R.Sample("DRUID", {
        { "Moonfire", { { moment = "ready", action = "glow" }, { moment = "up", action = "glow" },
                        { moment = "recast", action = "glow", at = 5 } } },
        { "Omen of Clarity", { { moment = "up", action = "glow" } } },
    })
    local list = rows(R.Trace(text, { spell = MOONFIRE, script = "falloff" }))
    local want = {
        { "idle", "glow=y(ready)" }, { "buff up", "glow=y(up)" }, { "fall-off lead", "glow=y(recast)" },
        { "recast", "glow=y(up)" }, { "target dies", "up=n glow=y(ready)" },
    }
    for _, wnt in ipairs(want) do
        T.truthy(find(list, wnt[1]):find(wnt[2], 1, true), wnt[1] .. ": " .. find(list, wnt[1]))
    end
    T.truthy(find(list, "fall-off lead", 2):find("glow=y(recast)", 1, true), "lit again after the recast")
    noErrors()
end)

T.test("repro: the usable script drives EZ-CDM's conditions from the game's state", function()
    local text = R.Sample("MAGE", { MAGE[2] })
    local list = rows(R.Trace(text, { script = "usable" }))
    T.truthy(find(list, "can't cast"):find("usable=n noPower=n", 1, true), find(list, "can't cast"))
    T.truthy(find(list, "short of power"):find("noPower=y", 1, true), find(list, "short of power"))
    T.truthy(find(list, "usable"):find("usable=y", 1, true), find(list, "usable"))
    noErrors()
end)

T.test("repro: a repro test's text holds the report and today's trace", function()
    local text = R.Sample("MAGE", { MAGE[1] })
    local body = R.TestText("sample", text, { spell = CLEARCASTING, script = "proc" })
    T.truthy(body:find(text, 1, true), "the report string")
    T.truthy(body:find("spell = 12536", 1, true))
    local chunk = assert(loadstring(body))
    local tests = {}
    local keep = T.test
    T.test = function(name, fn) tests[#tests + 1] = { name = name, fn = fn } end
    chunk()
    T.test = keep
    T.eq(#tests, 1)
    T.noerror(tests[1].fn, "passes on the code it was made from")
    T.errors(function() R.Check("a\nb\n", "a\nc\n") end, "a changed line fails")
end)
