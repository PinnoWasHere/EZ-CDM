local stub = require("stub")
local SW = require("sweep_lib")
local W = require("classworld")

-- The fill sweep (docs/tasks/w2-fill.md): every class's tray as icons. On each piece,
-- each of Always, "While it's cooling down" and "While it's active" that takes the fill
-- gets one line per source the drawer offers there, the shapes and directions taken
-- in turn. Every line then reads on, and each fill must draw with no error: lit, on
-- show, and its bar set by the game (a percent, or a duration, or the no-time value).
-- Offers must fit: my power only where the cast costs a bar the class has as a
-- percent, time left only where a clock runs for the line's icon, never on a proc,
-- and no fill where neither fits.

local CLASSES = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
local MOMENTS = { "always", "cooldown", "up" }

local totals = { pieces = 0, lines = 0, hidden = 0, time = 0, power = 0, refused = 0 }

-- Every condition reads on, a client one drives its layer to 1. Returns the undo.
local function allOn(C)
    local undo = {}
    for _, c in ipairs(C.List()) do
        if c.secrecy == "client" then
            local keep = c.drive
            c.drive = function(_, layer) layer:SetAlpha(1) end
            undo[#undo + 1] = function() c.drive = keep end
        else
            local keep = c.read
            c.read = function() return true end
            undo[#undo + 1] = function() c.read = keep end
        end
    end
    return function() for _, f in ipairs(undo) do f() end end
end

local function check(DUI, ns, p, class, bad, n)
    local G, C, D, L = ns.Grammar, ns.Conditions, ns.Draft, ns.Looks
    local kind = G.Kind(p.key)
    local tag = class .. " " .. p.name .. " (" .. tostring(p.key) .. ")"
    local function say(why) bad[#bad + 1] = tag .. ": " .. why end
    local offers = {}
    for _, w in ipairs(G.Words(kind, { more = true })) do
        for _, a in ipairs(w.actions) do
            if a == "fill" then offers[w.moment] = true end
        end
    end
    local lines = {}
    for _, m in ipairs(MOMENTS) do
        if offers[m] then
            local line = { moment = m, action = "fill" }
            local keys, refused = G.FillSources(kind, line)
            totals.refused = totals.refused + #refused
            if #keys == 0 then say(m .. ": the fill offered with nothing to fill with") end
            for _, src in ipairs(keys) do
                if src == "power" and not kind.lowPower then say("my power on a spell that costs none of it") end
                if src == "time" and kind.proc then say("time left on a proc") end
                n = n + 1
                lines[#lines + 1] = { moment = m, action = "fill", value = { source = src,
                    shape = L.FILL_SHAPES[n % 2 + 1], dir = L.FILL_DIRS[math.floor(n / 2) % 2 + 1] } }
            end
            for _, r in ipairs(refused) do
                if r.key ~= "time" or type(r.why) ~= "string" then say("a refusal with no reason") end
            end
        end
    end
    if #lines == 0 then return n end
    totals.pieces = totals.pieces + 1
    -- One line per moment can hold the fill at once, so each is written and drawn alone.
    for _, line in ipairs(lines) do
        local ok, why, report = D.Write(p.key, { lines = { line } })
        if not ok then
            local q = report and report.notes and report.notes[1]
            say(line.moment .. " " .. line.value.source .. " refused: " .. tostring(why) .. " " .. tostring(q and q.words))
        else
            local undo = allOn(C)
            C.Refresh(p.key)
            stub.RunTimers()
            undo()
            local ck = G.LineCondition(line, kind)
            local v = C.Visible(p.key, ck .. ":fill")
            local frame = C.FrameOf(p.key)
            totals.lines = totals.lines + 1
            if v.covered or not (frame and frame:IsVisible()) then
                -- Its icon isn't on show now (a buff of another class's, down).
                totals.hidden = totals.hidden + 1
            elseif not (v.lit and v.shown) then
                say(string.format("%s %s doesn't draw (lit %s, shown %s)", line.moment, line.value.source,
                    tostring(v.lit), tostring(v.shown)))
            else
                local f = L.Frame(DUI.API.Attach(C.FrameOf(p.key)), "fill")
                local bar = f and (line.value.shape == "bar" and f.bar or f.tint)
                if not bar or (bar.__value == nil and bar.__timer == nil) then
                    say(line.moment .. " " .. line.value.source .. ": the bar was never set")
                end
                if line.value.source == "time" then
                    totals.time = totals.time + 1
                elseif line.value.source == "power" then
                    totals.power = totals.power + 1
                end
            end
        end
    end
    D.Write(p.key, { lines = {} })
    return n
end

local function report(bad)
    return #bad .. " fills out of place:\n  " .. table.concat(bad, "\n  ", 1, math.min(#bad, 40))
end

for _, class in ipairs(CLASSES) do
    T.test("sweep fill: " .. class .. "'s tray draws every fill it offers, and only fitting ones", function()
        local DUI, ns, AB = SW.World(SW.Class(class), { hidden = true })
        W.ClientTier()
        local placed = SW.PlaceTray(AB, false)
        local bad, n = {}, 0
        for _, p in ipairs(placed) do n = check(DUI, ns, p, class, bad, n) end
        T.eq(#bad, 0, report(bad))
        T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    end)
end

T.test("sweep fill: the sweep drew fills of every source", function()
    print(string.format("fill sweep: %d pieces, %d lines (%d not on show); %d time left, %d power, "
        .. "%d time left refusals", totals.pieces, totals.lines, totals.hidden, totals.time, totals.power,
        totals.refused))
    T.truthy(totals.pieces >= 300, "pieces: " .. totals.pieces)
    T.truthy(totals.time >= 100, "time left: " .. totals.time)
    T.truthy(totals.power >= 100, "power: " .. totals.power)
    T.truthy(totals.refused >= 10, "time left refusals: " .. totals.refused)
end)
