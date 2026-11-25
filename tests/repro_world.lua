-- A player's bug report (EZ-CDM/Report.lua) rebuilt offline: their class in the
-- class world (tests/classworld.lua) with Daylight UI's real code (tests/pin.lua),
-- their layout and EZ-CDM rules loaded through a /reload, then each piece shown
-- as EZ-CDM reads it and run through a scripted fight.
--
-- From the project root (tools/repro.py does this for you):
--   luajit tests/repro_world.lua --report-file F [--spell ID] [--script NAME] [--make-test NAME]
--
-- As a module (tests/repro/*.lua, test_report):
--   local R = require("repro_world")
--   local w, report = R.Build(text)       the world, with the layout placed
--   R.Trace(text, { spell, script })      the scripted run as text, one line per step

-- Run on its own (tools/repro.py): load the harness as tests/run.lua does, then run
-- this file again as test code, since the fake game tells test code by its chunk name.
if not package.loaded.ez_harness then
    local root = (arg and arg[0] or ""):gsub("\\", "/"):match("^(.-)tests/repro_world%.lua$") or ""
    _G.EZ_ROOT = rawget(_G, "EZ_ROOT") or root
    local path = root .. "tests/ez_harness.lua"
    local fh = assert(io.open(path, "rb"))
    local text = fh:read("*a")
    fh:close()
    local H = assert(load(text, path:find("^%.?/?tests/") and "@" .. path or "@tests/../" .. path))()
    H.install()
    return assert(H.loadTestFile(H.TESTS .. "repro_world.lua"))(...)
end

local stub = require("stub")
local W = require("classworld")

local R = {}

R.LEAD = 5

local copy = W.copy

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) == "number" end
        return a < b
    end)
    return keys
end

-- A value as short text: tables as {k=v,...} in key order, numbers to 2 places.
local function show(v)
    if type(v) == "number" then
        if v == math.floor(v) then return tostring(v) end
        return string.format("%.2f", v)
    end
    if type(v) ~= "table" then return tostring(v) end
    local out = {}
    for _, k in ipairs(sortedKeys(v)) do
        local key = type(k) == "number" and #out + 1 == k and "" or tostring(k) .. "="
        out[#out + 1] = key .. show(v[k])
    end
    return "{" .. table.concat(out, ",") .. "}"
end
R.show = show

-- ---------------------------------------------------------------------
-- The report
-- ---------------------------------------------------------------------

-- EZ-CDM's Report.lua, read outside the game.
local Report
function R.Report()
    if not Report then
        local ns = {}
        assert(loadfile((stub.PLUGIN_TOC:match("^(.*/)") or "") .. "Report.lua"))("EZ-CDM", ns)
        Report = ns.Report
    end
    return Report
end

function R.Parse(text)
    local t, why = R.Report().Parse(text)
    if not t then error("not a report: " .. tostring(why), 0) end
    return t
end

-- ---------------------------------------------------------------------
-- The world
-- ---------------------------------------------------------------------

-- Pieces in an order that places each one after the piece it hangs off.
local function placeOrder(pieces)
    local out, done = {}, {}
    local function add(key, depth)
        if done[key] or depth > 50 then return end
        local parent = pieces[key].parent
        if parent ~= nil and pieces[parent] then add(parent, depth + 1) end
        done[key] = true
        out[#out + 1] = key
    end
    for _, key in ipairs(sortedKeys(pieces)) do add(key, 0) end
    return out
end

-- The report's class logged in, its layout placed on talent set 1 and its EZ-CDM
-- rules saved under that set's profile, then a /reload so every piece is made the
-- way a login makes it. text is a report string or its parsed table. Returns the
-- world (W.Build), the report and the keys this world couldn't place.
function R.Build(text)
    local report = type(text) == "table" and text or R.Parse(text)
    local c = W.Class(tostring(report.class))
    if not c then error("no class world for " .. tostring(report.class), 0) end
    local known, passive = {}, {}
    for _, id in ipairs(report.known or {}) do
        if id > 0 then known[id] = true else known[-id] = false end
    end
    for _, id in ipairs(report.passive or {}) do passive[id] = true end
    local hidden = type(report.hidden) == "table" and next(report.hidden) ~= nil
    local opts = { hidden = hidden, known = known, passive = passive, spec = report.spec }
    local w = W.Build(c, opts)
    local ns, AB = w.ns, w.AB
    local D = AB.CdmData
    local profile = assert(ns.Bridge.SavedProfile(1), "no profile for talent set 1")
    local set = D.Get(1)
    local missed = {}
    for i, key in ipairs(placeOrder(report.pieces)) do
        local p = report.pieces[key]
        D.AddPiece(set, key, p.shape, ((i - 1) % 12) * 60, -math.floor((i - 1) / 12) * 60)
        local live = set.pieces[key]
        if live then
            for k, v in pairs(p) do live[k] = copy(v) end
        else
            missed[#missed + 1] = key
        end
    end
    set.chains = set.chains or {}
    for k, v in pairs(report.chains or {}) do set.chains[k] = copy(v) end
    EZCDMDB = type(EZCDMDB) == "table" and EZCDMDB or {}
    for store, byKey in pairs(report.rules or {}) do
        if type(EZCDMDB[store]) ~= "table" then EZCDMDB[store] = {} end
        EZCDMDB[store][profile] = copy(byKey)
    end
    w.Pass()
    w.Reload()
    w.Pass()
    w.profile = profile
    return w, report, missed
end

-- The placed keys for a spell id (the piece's key, its spell or any id it answers
-- to), or every placed key when id is nil.
function R.Keys(w, report, id)
    local B = w.ns.Bridge
    local out = {}
    for _, key in ipairs(sortedKeys(report.pieces)) do
        local hit = id == nil or key == id or tostring(key) == tostring(id) or B.SpellOf(key) == id
        if not hit then
            local ids = B.SpellIDs(key)
            hit = type(ids) == "table" and ids[id] == true
        end
        if hit and w.AB.CdmData.Get(1).pieces[key] then out[#out + 1] = key end
    end
    return out
end

-- ---------------------------------------------------------------------
-- What EZ-CDM offers on a piece
-- ---------------------------------------------------------------------

local KIND_FLAGS = { "drawnBy", "custom", "cooldown", "buff", "tracked", "cast", "ezGlow", "proc", "harmful",
                     "untimed", "groupBuff", "buffEvents" }

-- Lines describing one piece: kind, offered words and recipes, its rules as
-- sentences with their notes, Daylight UI's saved fields and EZ-CDM's rules.
function R.Describe(w, report, key)
    local ns = w.ns
    local G, B, Draft = ns.Grammar, ns.Bridge, ns.Draft
    local out = {}
    local function add(s) out[#out + 1] = s end
    local kind = G.Kind(key)
    local said = report.spells and report.spells[key] or {}
    add(string.format("== %s (key %s, %s, spell %s)", tostring(B.SpellName(key)), tostring(key), kind.shape,
        tostring(B.SpellOf(key))))
    if said.drawn ~= nil and said.drawn ~= kind.drawnBy then
        add(string.format("   ! drawn by %s here; the report says %s", tostring(kind.drawnBy), tostring(said.drawn)))
    end
    local flags = {}
    for _, f in ipairs(KIND_FLAGS) do flags[#flags + 1] = f .. "=" .. tostring(kind[f]) end
    add("   kind     " .. table.concat(flags, " "))
    local words = {}
    for _, e in ipairs(G.Words(kind)) do words[#words + 1] = e.moment .. "(" .. table.concat(e.actions, ",") .. ")" end
    add("   offers   " .. table.concat(words, " "))
    local extras = G.Extras(kind)
    if #extras > 0 then add("   extras   " .. table.concat(extras, ", ")) end
    add("   recipes  " .. table.concat(G.Recipes(kind), ", "))
    local rules, problems = Draft.Rules(key)
    if rules then
        if #rules.lines == 0 then add("   rules    (none)") end
        for i, l in ipairs(rules.lines) do
            add(string.format("   %s %s  %s", i == 1 and "rules   " or "        ", G.Describe(l), show(l)))
        end
        for k, v in pairs(rules.group or {}) do add("   group    " .. tostring(k) .. "=" .. show(v)) end
        if #(rules.forms or {}) > 0 then add("   forms    " .. table.concat(rules.forms, ", ")) end
        if rules.shows ~= nil then add("   shows    " .. tostring(rules.shows)) end
        if rules.style ~= nil then add("   style    " .. tostring(rules.style)) end
        for _, n in ipairs(G.Notes(rules) or {}) do
            add("   note     " .. tostring(type(n) == "table" and (n.words or n.text or show(n)) or n))
        end
        for _, n in ipairs(G.FallOffNotes(kind, rules.lines) or {}) do
            if G.Fits(kind, "recast", "glow") then add("   fall-off " .. n.code .. ": " .. tostring(n.text)) end
        end
    end
    for _, p in ipairs(problems or {}) do add("   problem  " .. show(p)) end
    local fields = {}
    local live = w.AB.CdmData.Get(1).pieces[key] or {}
    for _, k in ipairs(sortedKeys(live)) do
        if k ~= "x" and k ~= "y" then fields[#fields + 1] = k .. "=" .. show(live[k]) end
    end
    add("   daylight " .. table.concat(fields, " "))
    for _, store in ipairs(sortedKeys(type(EZCDMDB) == "table" and EZCDMDB or {})) do
        local byProfile = EZCDMDB[store]
        local mine = type(byProfile) == "table" and type(byProfile[w.profile]) == "table" and byProfile[w.profile][key]
        if mine ~= nil and mine ~= false then add("   ez       " .. store .. "=" .. show(mine)) end
    end
    return out
end

-- ---------------------------------------------------------------------
-- The scripted run
-- ---------------------------------------------------------------------

-- The aura a piece's buff lands as: the catalogue row's linked aura, an aura the
-- links say its spell puts up, else its spell. A passive talent never puts its own
-- id up, so a row that links only that id lands as the proc the links name, as in
-- game (Improved Stormstrike's 1238931).
local function auraOf(w, key)
    local sid = w.ns.Bridge.SpellOf(key)
    if sid == nil then return nil end
    local row = w.Row(sid)
    local from = W.Links().bySource[sid]
    local passive = C_Spell.IsSpellPassive and C_Spell.IsSpellPassive(sid) == true
    if passive and from and from[1] and row and #row.linkAuras == 1 and row.linkAuras[1] == sid then
        return from[1]
    end
    if row and #row.linkAuras > 0 then return row.linkAuras[1] end
    if from and from[1] then return from[1] end
    return sid
end

-- The fall-off lead EZ-CDM keeps for a piece, else R.LEAD.
local function leadOf(w, key)
    local f = w.ns.Effects.FallOff and w.ns.Effects.FallOff(key)
    return type(f) == "table" and f.lead or R.LEAD
end

local function cooldownOf(sid)
    local base = require("cdmworld").BaseCooldown(sid) / 1000
    return base > 0 and base or 8
end

-- The alpha the player sees on a piece. Daylight UI fades the item it draws the piece
-- with (CdmEffects setAlpha), never the piece frame, so this reads the item's effective
-- alpha, times the piece's when the item sits outside it.
local function seenAlpha(AB, f)
    local pa = f:GetEffectiveAlpha() or 1
    local info = AB.CdmRows.pieceInfo and AB.CdmRows.pieceInfo[f]
    local item = info and info.item
    if not (item and item.GetEffectiveAlpha) then return pa end
    local ia = item:GetEffectiveAlpha() or 1
    local p = item
    while p do
        if p == f then return ia end
        p = p.GetParent and p:GetParent()
    end
    return pa * ia
end

-- One piece's state now, as one line. EZ-CDM's conditions are read through their
-- registry (Conditions.List), so a new one shows with no change here: every one
-- with allReads, else only those the piece's rules use, so a repro test's trace
-- stays the same as conditions are added.
local function observe(w, key, allReads)
    local ns, AB = w.ns, w.AB
    local API = w.DUI.API
    local st = API.CooldownState(key)
    local parts = {}
    local f = API.GetCooldownPiece(key)
    if f and f:IsShown() then
        parts[#parts + 1] = string.format("shown a=%.2f", seenAlpha(AB, f))
    else
        parts[#parts + 1] = "hidden"
    end
    if st then
        local function b(v) return v == nil and "-" or (v and "y" or "n") end
        parts[#parts + 1] = string.format("ready=%s cd=%s usable=%s noPower=%s proc=%s up=%s glow=%s", b(st.ready),
            b(st.onCooldown), b(st.usable), b(st.noPower), b(st.proc), b(st.buffUp), b(st.glowing))
        -- Which glow lights: the moment EZ-CDM's style wrap reads for the piece's item.
        local info = f and AB.CdmRows.pieceInfo and AB.CdmRows.pieceInfo[f]
        local m = st.glowing and info and info.item and ns.Effects.MomentOf(info.item)
        if m then parts[#parts] = parts[#parts] .. "(" .. m .. ")" end
    else
        parts[#parts + 1] = "no state"
    end
    local h = AB.CdmAuras.Frame(key)
    local list = h and h.buttons or {}
    if #list > 0 then
        local lit = 0
        for _, btn in ipairs(list) do
            local r = ns.Effects.Ring(btn)
            if r and r.anim and r.anim:IsPlaying() then lit = lit + 1 end
        end
        parts[#parts + 1] = string.format("ring=%d/%d", lit, #list)
    end
    local C = ns.Conditions
    if type(C) == "table" and type(C.List) == "function" then
        local reads = {}
        -- Every condition the piece's lines use, clauses included; a client one
        -- reads as its sample (true, false or <secret>).
        local used = {}
        for _, l in ipairs(type(C.Lines) == "function" and C.Lines(key) or {}) do
            for _, p in ipairs(l.parts) do used[p.cond] = true end
        end
        for ck in pairs(type(C.Rule) == "function" and C.Rule(key) or {}) do used[ck] = true end
        for _, c in ipairs(C.List()) do
            if allReads or used[c.key] then
                local ok, v
                if type(C.Sample) == "function" then ok, v = pcall(C.Sample, c.key, key)
                else ok, v = pcall(c.read, key) end
                reads[#reads + 1] = c.key .. "=" .. (ok and tostring(v) or "error")
            end
        end
        if #reads > 0 then parts[#parts + 1] = "reads " .. table.concat(reads, " ") end
        local lit = type(C.Lit) == "function" and C.Lit(key)
        if lit then parts[#parts + 1] = "lit " .. show(lit) end
    end
    return table.concat(parts, " ")
end
R.Observe = observe

-- The steps. Each acts on the pieces in focus, ctx = { w, keys, sid, aura, lead, cd }.
local STEPS = {}
local function step(name, fn) STEPS[name] = fn end
local function each(ctx, fn)
    for _, key in ipairs(ctx.keys) do
        local p = ctx.by[key]
        if p.sid then fn(p, key) end
    end
end
step("idle", function() end)
step("cast", function(ctx) each(ctx, function(p) ctx.w.Cast(p.sid) end) end)
step("cooldown", function(ctx) each(ctx, function(p) ctx.w.Cooldown(p.sid, p.cd) end) end)
step("half the cooldown", function(ctx) ctx.w.Advance(2) end)
step("ready", function(ctx) each(ctx, function(p) ctx.w.Ready(p.sid) end); ctx.w.Advance(0.1) end)
step("buff up", function(ctx) each(ctx, function(p) ctx.w.BuffUp(p.aura, { duration = 12 }) end); ctx.w.Pass() end)
step("fall-off lead", function(ctx)
    local lead = R.LEAD
    each(ctx, function(p) lead = math.max(lead, p.lead) end)
    ctx.w.Advance(12 - lead + 0.1)
end)
step("recast", function(ctx) each(ctx, function(p) ctx.w.Refresh(p.aura) end); ctx.w.Pass() end)
step("buff down", function(ctx) each(ctx, function(p) ctx.w.BuffDown(p.aura) end); ctx.w.Pass() end)
step("proc up", function(ctx) each(ctx, function(p) ctx.w.Proc(p.aura, 15) end); ctx.w.Pass() end)
step("proc down", function(ctx) each(ctx, function(p) ctx.w.BuffDown(p.aura) end); ctx.w.Pass() end)
step("can't cast", function(ctx) ctx.w.Usable(false, false); ctx.w.Advance(0.1) end)
step("short of power", function(ctx) ctx.w.Usable(false, true); ctx.w.Advance(0.1) end)
step("usable", function(ctx) ctx.w.Usable(true, false); ctx.w.Advance(0.1) end)
step("enter combat", function(ctx) ctx.w.EnterCombat(); ctx.w.Pass() end)
step("target dies", function(ctx) ctx.w.KillTarget(); ctx.w.Advance(1.5) end)
step("new target", function(ctx) ctx.w.NewTarget(); ctx.w.Pass() end)
step("leave combat", function(ctx) ctx.w.LeaveCombat() end)
step("wait 4 s", function(ctx) ctx.w.Advance(4) end)
step("target at 10%", function(ctx) ctx.w.Unit("target", { pct = 0.1 }) end)
step("target at 90%", function(ctx) ctx.w.Unit("target", { pct = 0.9 }) end)
step("target is a boss", function(ctx) ctx.w.Unit("target", { boss = true }) end)
step("tick", function(ctx) ctx.w.Tick(1) end)

-- The named scripts, each a list of steps.
R.SCRIPTS = {
    cooldown = { "idle", "cast", "cooldown", "half the cooldown", "ready" },
    buff = { "idle", "buff up", "fall-off lead", "buff down" },
    proc = { "idle", "proc up", "proc down", "enter combat", "proc up", "wait 4 s", "proc down", "leave combat" },
    usable = { "idle", "can't cast", "short of power", "usable" },
    falloff = { "idle", "enter combat", "cast", "buff up", "fall-off lead", "recast", "fall-off lead", "target dies",
                "new target", "leave combat" },
    combat = { "idle", "enter combat", "cast", "cooldown", "buff up", "can't cast", "usable", "wait 4 s", "ready",
               "buff down", "leave combat" },
    -- Unit state the engine's conditions read (and-clauses, client parts, the ticker).
    target = { "idle", "new target", "target is a boss", "target at 90%", "target at 10%", "tick", "enter combat",
               "target at 90%", "tick", "leave combat" },
}
R.SCRIPTS.all = {}
for _, name in ipairs({ "cooldown", "buff", "proc", "usable", "falloff", "combat" }) do
    for i, s in ipairs(R.SCRIPTS[name]) do
        if i > 1 or #R.SCRIPTS.all == 0 then R.SCRIPTS.all[#R.SCRIPTS.all + 1] = s end
    end
end

-- Runs a script on the world. Returns its lines: per step, the sounds played, then
-- each piece in focus and what it shows.
function R.Run(w, keys, script, allReads)
    local list = R.SCRIPTS[script or "all"]
    if not list then error("no script " .. tostring(script) .. "; there are: " .. table.concat(sortedKeys(R.SCRIPTS), ", "), 0) end
    local B = w.ns.Bridge
    local ctx = { w = w, keys = keys, by = {} }
    for _, key in ipairs(keys) do
        local sid = B.SpellOf(key)
        local name = tostring(B.SpellName(key) or key):sub(1, 16)
        ctx.by[key] = { sid = sid, aura = auraOf(w, key), lead = leadOf(w, key), cd = sid and cooldownOf(sid),
                        label = name }
    end
    local sounds = {}
    local Sound = w.DUI.Sound
    local keep = Sound.Alert
    Sound.Alert = function(k, ...) sounds[#sounds + 1] = tostring(k); return keep(k, ...) end
    local errors0 = #stub.errors
    local out = {}
    for i, name in ipairs(list) do
        local heard = #sounds
        STEPS[name](ctx)
        local played = {}
        for j = heard + 1, #sounds do played[#played + 1] = sounds[j] end
        out[#out + 1] = string.format("%2d %s%s", i, name, #played > 0 and ("  sound " .. table.concat(played, ",")) or "")
        for _, key in ipairs(keys) do
            out[#out + 1] = string.format("     %-16s %s", ctx.by[key].label, observe(w, key, allReads))
        end
    end
    Sound.Alert = keep
    for j = errors0 + 1, #stub.errors do
        out[#out + 1] = "error: " .. tostring(stub.errors[j]):gsub("\n.*", "")
    end
    if stub.combat then stub.LeaveCombat() end
    return out
end

-- The scripted run for a report as one text: what a repro test compares.
function R.Trace(text, opts)
    opts = opts or {}
    local w, report = R.Build(text)
    local keys = R.Keys(w, report, opts.spell)
    if #keys == 0 then error("no placed piece for spell " .. tostring(opts.spell), 0) end
    return table.concat(R.Run(w, keys, opts.script), "\n") .. "\n"
end

-- ---------------------------------------------------------------------
-- A sample report, made in the class world
-- ---------------------------------------------------------------------

-- A report as a player of class would send one: each named tray spell placed as the
-- tray offers it, its lines written through Draft, the game's buff viewers hidden
-- unless opts.shown. pieces = { { name, lines } }. Returns the string and the world.
function R.Sample(class, pieces, opts)
    opts = opts or {}
    local w = W.Build(class, { hidden = not opts.shown })
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    Ed.SetShowUnlearned(true)
    local set = D.Ensure(1)
    local byName = {}
    for _, e in ipairs(Ed.Spells()) do byName[e.name] = byName[e.name] or e end
    for i, p in ipairs(pieces) do
        local e = assert(byName[p[1]], class .. " has no tray spell " .. tostring(p[1]))
        D.AddPiece(set, e.id, e.kind == "bar" and "bar" or "icon", (i - 1) * 60, 0)
    end
    w.Pass()
    for _, p in ipairs(pieces) do
        if p[2] then
            local ok, why = w.ns.Draft.Write(byName[p[1]].id, { lines = p[2] })
            assert(ok, tostring(p[1]) .. ": " .. tostring(why))
        end
    end
    w.Pass()
    return w.ns.Report.Build(), w
end

-- ---------------------------------------------------------------------
-- Writing a repro test
-- ---------------------------------------------------------------------

-- The text of tests/repro/<name>.lua: the report, the focus and the trace it gives now.
function R.TestText(name, text, opts)
    opts = opts or {}
    local report = R.Parse(text)
    local string1 = string.match(text, R.Report().PREFIX .. "[%w%+/]*=*")
    local trace = R.Trace(report, opts)
    local spell = type(opts.spell) == "string" and string.format("%q", opts.spell) or tostring(opts.spell)
    return table.concat({
        "local R = require(\"repro_world\")",
        "",
        "-- A bug report rebuilt in the class world (tools/repro.py --make-test " .. name .. ").",
        "-- " .. tostring(report.class) .. ", EZ-CDM " .. tostring(report.ez) .. ", Daylight UI "
            .. tostring(report.dui) .. ", script " .. tostring(opts.script or "all") .. ", spell " .. spell .. ".",
        "-- EXPECT is what EZ-CDM does now. To fix the bug, change EXPECT to what it should",
        "-- do (the test fails), then fix the code until it passes.",
        "",
        "local REPORT = \"" .. string1 .. "\"",
        "",
        "local EXPECT = [[",
        trace .. "]]",
        "",
        "T.test(\"repro " .. name .. "\", function()",
        "    R.Check(R.Trace(REPORT, { spell = " .. spell .. ", script = \"" .. tostring(opts.script or "all") .. "\" }), EXPECT)",
        "end)",
        "",
    }, "\n")
end

-- Fails with the first line that differs.
function R.Check(got, want)
    if got == want then return end
    local g, wl = {}, {}
    for l in (got .. "\n"):gmatch("(.-)\n") do g[#g + 1] = l end
    for l in (want .. "\n"):gmatch("(.-)\n") do wl[#wl + 1] = l end
    for i = 1, math.max(#g, #wl) do
        if g[i] ~= wl[i] then
            error(string.format("line %d differs\n  want: %s\n  got:  %s", i, tostring(wl[i]), tostring(g[i])), 2)
        end
    end
end

-- ---------------------------------------------------------------------
-- The command line
-- ---------------------------------------------------------------------

local function main(args)
    local file, spell, script, makeTest
    local i = 1
    while i <= #args do
        local a = args[i]
        if a == "--report-file" then file = args[i + 1]; i = i + 1
        elseif a == "--spell" then spell = tonumber(args[i + 1]) or args[i + 1]; i = i + 1
        elseif a == "--script" then script = args[i + 1]; i = i + 1
        elseif a == "--make-test" then makeTest = args[i + 1]; i = i + 1
        else error("unknown argument " .. tostring(a), 0) end
        i = i + 1
    end
    local fh = assert(io.open(assert(file, "--report-file is needed"), "rb"))
    local text = fh:read("*a")
    fh:close()
    if makeTest then
        -- Into the private project's tests when it runs the suite, else the repo's.
        local H = require("ez_harness")
        local path = (H.EXTRA_TESTS or H.TESTS) .. "repro/" .. makeTest .. ".lua"
        local body = R.TestText(makeTest, text, { spell = spell, script = script })
        local out = assert(io.open(path, "wb"))
        out:write(body)
        out:close()
        io.write("wrote ", path, "\n")
        return
    end
    local w, report, missed = R.Build(text)
    io.write(string.format("Report: %s spec %s set %s | EZ-CDM %s | Daylight UI %s (API %s) | client %s\n",
        tostring(report.class), tostring(report.spec), tostring(report.set), tostring(report.ez), tostring(report.dui),
        report.api and table.concat(report.api, ".") or "?", report.game and show(report.game) or "?"))
    local pinned = stub.ReadToc(stub.DUI_ROOT .. "DaylightUI.toc").Version
    io.write(string.format("World: Daylight UI %s from %s, buff viewers %s, %d pieces placed\n", tostring(pinned),
        stub.DUI_ROOT, next(report.hidden or {}) and "hidden" or "shown", #R.Keys(w, report)))
    if report.dui ~= nil and report.dui ~= pinned then
        io.write("! the report is from Daylight UI ", tostring(report.dui), "; this world runs ", tostring(pinned), "\n")
    end
    for _, key in ipairs(missed) do io.write("! not placed (no such piece in this world): ", tostring(key), "\n") end
    local keys = R.Keys(w, report, spell)
    if #keys == 0 then error("no placed piece for spell " .. tostring(spell), 0) end
    io.write("\n")
    for _, key in ipairs(keys) do
        for _, line in ipairs(R.Describe(w, report, key)) do io.write(line, "\n") end
    end
    io.write("\nScript ", script or "all", "\n")
    for _, line in ipairs(R.Run(w, keys, script, true)) do io.write(line, "\n") end
end

if arg and arg[0] and arg[0]:gsub("\\", "/"):find("repro_world%.lua$") then
    local ok, err = xpcall(function() main(arg) end, debug.traceback)
    if not ok then
        io.stderr:write(tostring(err), "\n")
        os.exit(1)
    end
    os.exit(0)
end

return R
