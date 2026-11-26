local stub = require("stub")
local SW = require("sweep_lib")

-- The looks sweep (docs/tasks/w1-effects.md): every class's tray, the game's buff
-- viewers hidden, Daylight UI's motion on. For each piece, every look it is offered
-- is written on the first plain moment and the first client moment that offer it.
-- Then every condition on the piece reads on (a client one drives its layer to 1)
-- and each look must draw:
--   once  fired (Looks.Fired), on a plain line only
--   held  lit and on show (Conditions.Visible), under the layer on a client line
-- and no look is offered where it can't draw: a one-shot look on a client moment,
-- an icon look on a bar.

local LS = {}

local totals = { pieces = 0, lines = 0, once = 0, held = 0, client = 0, covered = 0, bars = 0, flares = 0 }
LS.totals = totals

-- Each look line a piece is offered: { moment, action, cond, client }.
local function offered(G, C, kind)
    local out, seen = {}, {}
    local looks = {}
    for _, l in ipairs(C.Looks()) do looks[l.action] = l.effect end
    for _, w in ipairs(G.Words(kind, { more = true })) do
        for _, a in ipairs(w.actions) do
            local e = G.MAP[w.moment][a]
            local ck = looks[a] and G.LineCondition({ moment = w.moment, action = a }, kind)
            local c = ck and C.Get(ck)
            if c then
                local client = c.secrecy == "client"
                local id = a .. (client and ":client" or ":plain")
                if not seen[id] then
                    seen[id] = true
                    out[#out + 1] = { moment = w.moment, action = a, cond = ck, client = client,
                                      valued = G.ValueKind(w.moment, a), merged = e.merges ~= nil }
                end
            end
        end
    end
    return out
end

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

local function check(ns, key, name, class, bad)
    local G, C, D, Looks = ns.Grammar, ns.Conditions, ns.Draft, ns.Looks
    local kind = G.Kind(key)
    local tag = class .. " " .. name .. " (" .. tostring(key) .. ", " .. tostring(kind.shape) .. ")"
    local lines = offered(G, C, kind)
    if #lines == 0 then return end
    totals.pieces = totals.pieces + 1
    if kind.shape == "bar" then totals.bars = totals.bars + 1 end
    local rules = {}
    for _, l in ipairs(lines) do
        local e = C.Effect(C.Get(l.cond).actions[l.action].effect)
        if l.client and e.edge then bad[#bad + 1] = tag .. ": " .. l.moment .. " offers " .. l.action .. " once, on a client line" end
        if kind.shape ~= "icon" and e.fits and e.fits(kind) ~= true then
            bad[#bad + 1] = tag .. ": " .. l.action .. " offered where it can't draw"
        end
        rules[#rules + 1] = { moment = l.moment, action = l.action,
                              value = l.valued and SW.LOOK_VALUES[l.valued] or nil }
    end
    local ok, why, report = D.Write(key, { lines = rules })
    if not ok then
        local p = report and report.notes and report.notes[1]
        bad[#bad + 1] = tag .. ": looks refused: " .. tostring(why) .. " " .. tostring(p and p.words)
        return
    end
    -- An armed part fires a one-shot look only as it turns true (Conditions armed).
    local undo = allOn(C, true)
    C.Refresh(key)
    undo()
    undo = allOn(C)
    C.Refresh(key)
    stub.RunTimers()
    if not C.FrameOf(key) then
        undo()
        return
    end
    for _, l in ipairs(lines) do
        totals.lines = totals.lines + 1
        local id = l.cond .. ":" .. l.action
        local e = C.Effect(C.Get(l.cond).actions[l.action].effect)
        local v = C.Visible(key, id)
        if v.covered then
            totals.covered = totals.covered + 1
        elseif e.edge then
            totals.once = totals.once + 1
            if not Looks.Fired(key, e.key) then bad[#bad + 1] = tag .. ": " .. l.moment .. " " .. l.action .. " never fired" end
            if e.hides then
                -- A flare must be up in Daylight UI's Proc Alerts, as EZ-CDM's own.
                totals.flares = totals.flares + 1
                if not (v.lit and v.shown) then bad[#bad + 1] = tag .. ": " .. id .. " isn't up in Proc Alerts" end
            end
        else
            totals.held = totals.held + 1
            if l.client then totals.client = totals.client + 1 end
            if not (v.lit and v.shown) then
                bad[#bad + 1] = string.format("%s: %s %s doesn't draw (lit %s, shown %s)", tag, l.moment, l.action,
                    tostring(v.lit), tostring(v.shown))
            elseif l.client and not v.layered then
                bad[#bad + 1] = tag .. ": " .. id .. " isn't under its layer"
            end
        end
    end
    undo()
    D.Write(key, { lines = {} })
end

local function report(bad)
    return #bad .. " looks out of place:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

-- classes: the trays to sweep as icons; bars: those to sweep again as bars.
function LS.Tests(classes, bars)
    local runs = {}
    for _, class in ipairs(classes) do runs[#runs + 1] = { class = class } end
    for _, class in ipairs(bars or {}) do runs[#runs + 1] = { class = class, bars = true } end
    for _, run in ipairs(runs) do
        local class = run.class
        T.test("sweep looks: " .. class .. "'s tray" .. (run.bars and " as bars" or "")
            .. " draws every look it offers, and only those", function()
            local DUI, ns, AB = SW.World(SW.Class(class), { hidden = true, procs = true })
            DUI.DB.General().motion = true
            local placed = SW.PlaceTray(AB, run.bars == true)
            local bad = {}
            for _, p in ipairs(placed) do check(ns, p.key, p.name, class, bad) end
            T.eq(#bad, 0, report(bad))
            T.eq(#stub.errors, 0, tostring(stub.errors[1]))
        end)
    end
    T.test("sweep looks: the sweep drew looks once, held and on client lines", function()
        print(string.format("looks sweep: %d pieces (%d bars), %d lines; %d once (%d flares), %d held (%d client), %d covered",
            totals.pieces, totals.bars, totals.lines, totals.once, totals.flares, totals.held, totals.client, totals.covered))
        if bars then T.truthy(totals.bars >= 20, "bars: " .. totals.bars) end
        T.truthy(totals.pieces >= 40, "pieces: " .. totals.pieces)
        T.truthy(totals.once >= 40, "once: " .. totals.once)
        T.truthy(totals.flares >= 40, "flares: " .. totals.flares)
        T.truthy(totals.held >= 40, "held: " .. totals.held)
        T.truthy(totals.client >= 5, "client: " .. totals.client)
    end)
end

return LS
