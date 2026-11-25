local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local W = require("classworld")
local R = require("repro_world")

-- The engine in the class world (tests/classworld.lua) and the repro tool
-- (tests/repro_world.lua): w.Unit and w.Tick drive an and-line whose last part is
-- client tier, and the repro trace prints every part's value, the client one as the
-- client sees it.

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

-- A warrior with its first tray spell placed, and two test conditions:
--   boss  plain: the target is a boss (UnitIsBossMob)
--   low   client: the target's health percent straight into the layer's alpha
--         (the fake game's UnitHealthPercent hands back the unit's pct as is)
local function build()
    local w = W.Build("WARRIOR")
    local Ed, D = w.AB.CdmEditor, w.AB.CdmData
    Ed.SetShowUnlearned(true)
    local e = Ed.Spells()[1]
    D.AddPiece(D.Ensure(1), e.id, "icon", 0, 0)
    w.Pass()
    local C = w.ns.Conditions
    local any = function() return true end
    local function wash() return { gray = { effect = "wash", opts = { id = "gray", color = "OFF" } } } end
    assert(C.Register({ key = "boss", moment = "boss", layer = "any", excludes = {}, secrecy = "plain", actions = wash(), fits = any,
        read = function() return UnitIsBossMob("target") end, events = { game = { "PLAYER_TARGET_CHANGED" } },
        words = { moment = "When my target is a boss", clause = "my target is a boss" } }))
    assert(C.Register({ key = "low", moment = "low", layer = "any", excludes = {}, secrecy = "client", actions = wash(), fits = any, ticker = true,
        param = { min = 1, max = 99, default = 20 },
        drive = function(_, layer) layer:SetAlpha(UnitHealthPercent("target", true, nil)) end,
        events = { game = { { "UNIT_HEALTH", "target" } } },
        words = { moment = "When my target is below #% health", clause = "my target is below #% health" } }))
    return w, e.id
end

T.test("engine world: w.Unit and w.Tick drive an and-line with a client part", function()
    local w, key = build()
    local line = { moment = "boss", action = "gray", clauses = { { cond = "low", n = 30 } } }
    T.truthy(w.ns.Draft.Write(key, { lines = { line } }))
    w.Pass()
    w.Unit("target", { boss = true, pct = 1 })
    local layer = w.ns.Conditions.Layer(key, "boss:gray")
    T.truthy(layer and layer:IsShown(), "the plain part is on")
    -- The piece's own frames may hold a client alpha, so read what landed with Plain.
    T.eq(stub.Plain(layer.__alpha), 1)
    w.Unit("target", { pct = stub.Secret(0) })
    T.truthy(issecretvalue(layer.__alpha), "a secret answer lands whole")
    T.eq(stub.Plain(layer.__alpha), 0)
    stub.units.target.pct = 1
    T.truthy(w.ns.Conditions.Ticking(), "ticking")
    w.Tick(1)
    T.eq(stub.Plain(layer.__alpha), 1, "the shared ticker re-drove it")
    w.Unit("target", { boss = false })
    T.falsy(layer:IsShown(), "the plain part off")
    noErrors()
end)

T.test("engine world: the repro trace prints each part, the client one as sampled", function()
    local w, key = build()
    T.truthy(w.ns.Draft.Write(key, { lines = { { moment = "boss", action = "gray",
        clauses = { { cond = "low", n = 30 } } } } }))
    w.Pass()
    local trace = table.concat(R.Run(w, { key }, "target"), "\n")
    T.truthy(trace:find("target is a boss", 1, true), "the script's steps")
    T.truthy(trace:find("reads boss=false low=<secret>", 1, true), "the client part reads <secret>:\n" .. trace)
    T.truthy(trace:find("reads boss=true low=<secret> lit {wash|boss:gray=boss:gray}", 1, true),
        "the line lit once the target is a boss")
    local lines = R.Describe(w, { spells = {} }, key)
    local found = false
    for _, l in ipairs(lines) do
        found = found or l:find("When my target is a boss and my target is below 30% health, turn it gray.", 1, true) ~= nil
    end
    T.truthy(found, "the rules print the and-part with its number")
    noErrors()
end)
