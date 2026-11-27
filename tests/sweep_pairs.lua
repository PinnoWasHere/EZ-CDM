local stub = require("stub")
local SW = require("sweep_lib")

-- The action pairs sweep (docs/tasks/w2-and-actions.md): every class's tray, the
-- game's buff viewers hidden, Daylight UI's motion on. For each piece and each moment
-- it is offered, every pair of actions the drawer lets share one line
-- (Grammar.LineActions) is written on one line and must hold together:
--   write  Draft writes it with no problem at all: no refusal, no "twice"
--   draw   with every condition on (a client one drives its layer to 1), each
--          EZ-CDM action draws: a held look lit and on show, a one-shot look fired
-- Pairs go in batches: each batch is actions that may all share a line, so every
-- pair the drawer offers is written together at least once.

local PS = {}

local totals = { pieces = 0, moments = 0, pairs = 0, batches = 0, drawn = 0, once = 0, daylight = 0 }
PS.totals = totals

-- Every condition reads on, a client one drives its layer to 1; with armedOff an armed
-- one reads off, so the next allOn is its turning true. Returns the undo.
local function allOn(C, armedOff)
    local undo = {}
    for _, c in ipairs(C.List()) do
        if c.secrecy == "client" then
            local keep = c.drive
            c.drive = function(_, layer) layer:SetAlpha(1) end
            undo[#undo + 1] = function() c.drive = keep end
        else
            local keep = c.read
            local v = not (armedOff and c.armed)
            c.read = function() return v end
            undo[#undo + 1] = function() c.read = keep end
        end
    end
    return function() for _, f in ipairs(undo) do f() end end
end

local function firstSound(B)
    local values, order = B.SoundChoices()
    for _, k in ipairs(type(order) == "table" and order or {}) do
        if k ~= "none" and not tostring(k):find("^head:") and values[k] then return k end
    end
end

-- A line of moment and action with a sample value where it needs one.
local function lineOf(G, B, moment, action)
    local l = { moment = moment, action = action }
    local valued = G.ValueKind(moment, action)
    if valued then l.value = SW.LOOK_VALUES[valued] end
    if action == "sound" then l.value = firstSound(B) end
    return l
end

-- Batches covering every offered pair: each a list of actions any two of which
-- the drawer lets share one line. joins: action -> action -> true.
local function batches(actions, joins)
    local left = {}
    local n = 0
    for _, a in ipairs(actions) do
        for _, b in ipairs(actions) do
            if a < b and joins[a] and joins[a][b] then
                left[a .. "+" .. b] = { a, b }
                n = n + 1
            end
        end
    end
    local out = {}
    while n > 0 do
        local seed
        for _, p in pairs(left) do
            if not seed or p[1] .. p[2] < seed[1] .. seed[2] then seed = p end
        end
        local batch = { seed[1], seed[2] }
        for _, c in ipairs(actions) do
            local fits = c ~= seed[1] and c ~= seed[2]
            for _, x in ipairs(batch) do fits = fits and joins[x] and joins[x][c] end
            if fits then batch[#batch + 1] = c end
        end
        for _, a in ipairs(batch) do
            for _, b in ipairs(batch) do
                local k = a .. "+" .. b
                if left[k] then
                    left[k] = nil
                    n = n - 1
                end
            end
        end
        out[#out + 1] = batch
    end
    return out
end

local function check(ns, key, name, class, bad)
    local G, C, D, B, Looks = ns.Grammar, ns.Conditions, ns.Draft, ns.Bridge, ns.Looks
    local kind = G.Kind(key)
    local tag = class .. " " .. name .. " (" .. tostring(key) .. ", " .. tostring(kind.shape) .. ")"
    local any = false
    for _, w in ipairs(G.Words(kind, { more = true, drawer = true })) do
        local joins = {}
        local offered = false
        for _, a in ipairs(w.actions) do
            local keys = G.LineActions(kind, { lineOf(G, B, w.moment, a) }, {})
            for _, b in ipairs(keys) do
                joins[a] = joins[a] or {}
                joins[b] = joins[b] or {}
                joins[a][b], joins[b][a] = true, true
                offered = true
            end
        end
        if offered then
            any = true
            totals.moments = totals.moments + 1
            for _, a in ipairs(w.actions) do
                for _, b in ipairs(w.actions) do
                    if a < b and joins[a] and joins[a][b] then totals.pairs = totals.pairs + 1 end
                end
            end
            for _, batch in ipairs(batches(w.actions, joins)) do
                totals.batches = totals.batches + 1
                local lines = {}
                for i, a in ipairs(batch) do lines[i] = lineOf(G, B, w.moment, a) end
                local what = tag .. ": " .. w.moment .. " " .. table.concat(batch, "+")
                local _, problems = G.Compile({ lines = lines }, kind)
                if #problems > 0 then
                    bad[#bad + 1] = what .. ": " .. tostring(problems[1].code)
                else
                    local ok, why, report = D.Write(key, { lines = lines })
                    if not ok then
                        local p = report and report.notes and report.notes[1]
                        bad[#bad + 1] = what .. ": refused " .. tostring(why) .. " " .. tostring(p and p.words)
                    else
                        local undo = allOn(C, true)
                        C.Refresh(key)
                        undo()
                        undo = allOn(C)
                        C.Refresh(key)
                        stub.RunTimers()
                        if C.FrameOf(key) then
                            for _, l in ipairs(lines) do
                                local ck = G.LineCondition(l, kind)
                                local act = ck and C.Get(ck).actions[l.action]
                                local e = act and C.Effect(act.effect)
                                if not e then
                                    totals.daylight = totals.daylight + 1
                                else
                                    local id = ck .. ":" .. l.action
                                    local v = C.Visible(key, id)
                                    if v.covered then
                                        -- The icon it is about doesn't show now.
                                    elseif e.edge then
                                        if e.key ~= "sound" then
                                            totals.once = totals.once + 1
                                            if not Looks.Fired(key, e.key) then
                                                bad[#bad + 1] = what .. ": " .. l.action .. " never fired"
                                            end
                                        end
                                    else
                                        totals.drawn = totals.drawn + 1
                                        if not (v.lit and v.shown) then
                                            bad[#bad + 1] = string.format("%s: %s doesn't draw (lit %s, shown %s)",
                                                what, l.action, tostring(v.lit), tostring(v.shown))
                                        end
                                    end
                                end
                            end
                        end
                        undo()
                    end
                end
            end
            D.Write(key, { lines = {} })
            C.Refresh(key)
        end
    end
    if any then totals.pieces = totals.pieces + 1 end
end

local function report(bad)
    return #bad .. " pairs that can't hold together:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

function PS.Tests(classes, last)
    for _, class in ipairs(classes) do
        T.test("sweep pairs: " .. class .. "'s tray holds every pair of actions it offers on one line", function()
            local DUI, ns, AB = SW.World(SW.Class(class), { hidden = true, procs = true })
            DUI.DB.General().motion = true
            local placed = SW.PlaceTray(AB, false)
            local bad = {}
            for _, p in ipairs(placed) do check(ns, p.key, p.name, class, bad) end
            T.eq(#bad, 0, report(bad))
            T.eq(#stub.errors, 0, tostring(stub.errors[1]))
        end)
    end
    if last then
        T.test("sweep pairs: the sweep wrote and drew pairs", function()
            print(string.format("pairs sweep: %d pieces, %d moments, %d pairs in %d batches; %d held drawn, "
                .. "%d once fired, %d Daylight UI actions", totals.pieces, totals.moments, totals.pairs,
                totals.batches, totals.drawn, totals.once, totals.daylight))
            T.truthy(totals.pieces >= 20, "pieces: " .. totals.pieces)
            T.truthy(totals.pairs >= 200, "pairs: " .. totals.pairs)
            T.truthy(totals.drawn >= 40, "drawn: " .. totals.drawn)
            T.truthy(totals.once >= 20, "once: " .. totals.once)
        end)
    end
end

return PS
