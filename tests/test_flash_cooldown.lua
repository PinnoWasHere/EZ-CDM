local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Earth Shock's "When I can't cast it, flash it" through a real cast and cooldown
-- (docs/tasks/r130-looks.md, Notes): once flashes as the cooldown starts, again and
-- again flashes then too and every half Twinkle lap while it cools, in a fight too,
-- and both stop at ready. The owner's in-game check lines (Notes) run here as written.

local EARTH_SHOCK = 8042

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end

-- A Shaman with Earth Shock placed as an icon, lines written, usable, and the rank
-- the piece casts.
local function earthShock(lines)
    local w = W.Build("SHAMAN")
    local D = w.AB.CdmData
    local r = assert(w.Row(EARTH_SHOCK), "Earth Shock row")
    local key = CW.ID(r.spell, r.category)
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, "icon", 0, 0) end
    w.Pass()
    local ok, why = w.ns.Draft.Write(key, { lines = lines })
    T.truthy(ok, tostring(why))
    w.Pass()
    w.Usable(true, false)
    local info = w.AB.CdmRows.pieceInfo[w.ns.Conditions.FrameOf(key)]
    local id = info and info.item and w.AB.CdmEffects.SpellOf(info.item) or EARTH_SHOCK
    return w, key, id
end

local function flashes(w, key)
    local f = w.ns.Looks.Fired(key, "flash")
    return f and f.n or 0
end

local function holderOf(w, key) return w.DUI.API.Attach(w.ns.Conditions.FrameOf(key)) end

-- The flash's frame on show over the piece, above the game's item and its swipe.
local function onTop(w, key)
    local f = w.ns.Looks.Frame(holderOf(w, key), "flash")
    T.truthy(f and f:IsShown(), "the flash's frame shows")
    local item = w.AB.CdmRows.pieceInfo[w.ns.Conditions.FrameOf(key)].item
    T.truthy(f:GetFrameLevel() > item.Cooldown:GetFrameLevel(), "over the game's swipe")
end

for _, fight in ipairs({ false, true }) do
    local where = fight and " in a fight" or ""

    T.test("flash cooldown: once flashes as Earth Shock's cooldown starts" .. where, function()
        local w, key, id = earthShock({ L("blocked", "flash") })
        if fight then w.NewTarget(); w.EnterCombat() end
        T.eq(flashes(w, key), 0, "castable: no flash")
        w.Cast(id)
        w.Cooldown(id, 6)
        T.eq(w.ns.Conditions.Get("cantCast").read(tostring(key)), true, "can't cast it while it cools")
        T.eq(flashes(w, key), 1, "one flash")
        onTop(w, key)
        w.Ready(id)
        w.Usable(true, false)
        T.falsy(w.ns.Conditions.Visible(key, "cantCast:flash").lit, "ready: off")
        T.eq(flashes(w, key), 1, "still one")
        noErrors()
    end)

    T.test("flash cooldown: again and again beats while Earth Shock cools" .. where, function()
        local w, key, id = earthShock({ L("blocked", "flash", { again = true }),
            L("cooling", "fill", { source = "time", shape = "bar", dir = "rise" }) })
        if fight then w.NewTarget(); w.EnterCombat() end
        w.Cast(id)
        w.Cooldown(id, 6)
        local holder = holderOf(w, key)
        T.truthy(w.ns.Looks.Beating(holder, "cantCast:flash"), "beating")
        local n = flashes(w, key)
        T.truthy(n >= 1, "flashed as it turned on")
        stub.RunTimersOnce()
        T.eq(flashes(w, key), n + 1, "one more each beat")
        onTop(w, key)
        w.Ready(id)
        w.Usable(true, false)
        T.falsy(w.ns.Looks.Beating(holder, "cantCast:flash"), "ready: the beat ends")
        local m = flashes(w, key)
        stub.RunTimers()
        T.eq(flashes(w, key), m, "no flash after")
        noErrors()
    end)
end

-- A C_Timer that keeps time: each callback runs once its delay is up, as the game's
-- does. frame(dt) moves the clock one frame on.
local function clock()
    local queue, keep = {}, C_Timer.After
    C_Timer.After = function(d, fn) queue[#queue + 1] = { due = GetTime() + (d or 0), fn = fn } end
    local function frame(dt)
        stub.Advance(dt)
        local due, rest = {}, {}
        for _, e in ipairs(queue) do
            if e.due <= GetTime() + 1e-9 then due[#due + 1] = e else rest[#rest + 1] = e end
        end
        queue = rest
        for _, e in ipairs(due) do e.fn() end
    end
    return frame, function() C_Timer.After = keep end
end

local FRAME = 1 / 60

-- Each flash's time after t0, and what showed as it played: its frame visible, its
-- texture shown at full alpha, its fade playing.
local function watchFlashes(w)
    local B, out = w.ns.Bridge, {}
    local keep = B.Flash
    B.Flash = function(tex, dur)
        keep(tex, dur)
        local g = tex.__duiFlash
        out[#out + 1] = { at = GetTime(), seen = tex:GetParent():IsVisible() and tex:IsShown()
            and tex:GetAlpha() == 1 and g ~= nil and g:IsPlaying() }
    end
    return out, function() B.Flash = keep end
end

for _, fight in ipairs({ false, true }) do
    for _, gcdFirst in ipairs({ false, true }) do
        local where = (fight and " in a fight" or "") .. (gcdFirst and ", the GCD showing first" or "")
        T.test("flash cooldown: again and again flashes as the cooldown starts, then every 1.2 s" .. where, function()
            local w, key, id = earthShock({ L("blocked", "flash", { again = true }) })
            if fight then w.NewTarget(); w.EnterCombat() end
            local frame, undoClock = clock()
            local got, undoFlash = watchFlashes(w)
            stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", id)
            -- The game's first read after a cast can be the GCD alone (dev log,
            -- 2026-11-25: isOnGCD true for 0.23 s, then the real cooldown).
            if gcdFirst then
                w.gcd[id] = true
                CW.Cooldown(id, 1.5, true)
                for _ = 1, 14 do frame(FRAME) end
                T.eq(#got, 0, "the GCD alone: no flash")
                w.gcd[id] = nil
            end
            local t0 = GetTime()
            CW.Cooldown(id, 6)
            for _ = 1, 3 * 60 do frame(FRAME) end
            undoFlash()
            undoClock()
            T.truthy(#got >= 3, "flashes: " .. #got)
            T.truthy(got[1].at - t0 <= 2 * FRAME + 1e-6,
                string.format("the first flash comes as the cooldown starts, not a beat on: %.2f s", got[1].at - t0))
            T.truthy(got[1].seen, "the first flash plays on a shown frame at full alpha")
            local every = w.DUI.Widgets.GLOW_LAP.twinkle / 2
            for i = 2, #got do
                T.truthy(math.abs(got[i].at - got[i - 1].at - every) <= FRAME + 1e-6,
                    string.format("flash %d %.2f s after the one before", i, got[i].at - got[i - 1].at))
                T.truthy(got[i].seen, "flash " .. i .. " shows")
            end
            noErrors()
        end)
    end
end

-- The owner's /run lines (r130-looks.md Notes), with the game's key for Earth Shock.
local PROBE = 'local C,L,k=EZCDM_Conditions,EZCDM_Looks,"%s" local F,f=L.Fired(k,"flash"),'
    .. 'L.Frame(DaylightUI.API.Attach(C.FrameOf(k)),"flash") print(F and F.n or 0,'
    .. 'C.Visible(k,"cantCast:flash").lit,EZCDM_Bridge.MotionOn(),f and f:IsVisible())'
local FORCE = 'local C=EZCDM_Conditions C.Effect("flash").draw(DaylightUI.API.Attach(C.FrameOf("%s")),'
    .. 'true,{key="%s",line="probe"})'

T.test("flash cooldown: the in-game probe lines fit and report", function()
    local w, key, id = earthShock({ L("blocked", "flash", { again = true }) })
    T.eq(tostring(key), "200323", "the key the owner's saved rules use")
    local probe, force = PROBE:format(key), FORCE:format(key, key)
    T.truthy(#("/run " .. probe) <= 255, "probe fits a /run")
    T.truthy(#("/run " .. force) <= 255, "force fits a /run")
    local said = {}
    local keep = print
    print = function(...)
        local out = {}
        for i = 1, 4 do out[i] = tostring((select(i, ...))) end
        said[#said + 1] = table.concat(out, " ")
    end
    assert(loadstring(probe))()
    w.Cast(id)
    w.Cooldown(id, 6)
    assert(loadstring(probe))()
    print = keep
    T.eq(said[1], "0 false true nil", "before: no flash, not lit")
    T.truthy(said[2]:match("^%d+ true true true$"), "after: flashes, lit, motion on, frame visible: " .. said[2])
    w.Ready(id)
    w.Usable(true, false)
    local n = flashes(w, key)
    assert(loadstring(force))()
    T.eq(flashes(w, key), n + 1, "the forced flash draws once")
    noErrors()
end)
