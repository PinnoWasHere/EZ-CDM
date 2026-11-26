local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")

-- The glow styles EZ-CDM offers, after the owner's in-game feedback of 2026-11-25
-- (docs/tasks/w1-glow-styles.md):
--   offer      Shine and Comet are gone from EZ's strips; the rest keep the card's order
--   migrate    saved Comet lines become Circle, saved Shine lines Ring
--   circle     its light at the nameplate's circling light (Plate.CIRCLE_SCALE.size)
--   breathe    one breath in Daylight UI's breath (Chat's Feel.BREATH), on EZ's glows only
--   steady     a lit glow is never put out or restarted while its line stays on

local SHOUT, REND, CLAP = 6673, 772, 6343
local ESSENTIAL = 0
local GOLD = { 1, 0.8, 0.2 }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end
local function usable(can) C_Spell.IsSpellUsable = function() return can, false end end
local function gameSaysUsable() stub.FireEvent("SPELL_UPDATE_USABLE"); stub.RunTimers() end
local function block() usable(false); gameSaysUsable() end

-- Thunder Clap placed as an icon, logged in, with lines.
local function world(lines)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[CLAP] = { name = "Thunder Clap" }
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = true
    usable(true)
    local AB = stub.actionbars
    local key = CW.ID(CLAP, ESSENTIAL)
    AB.CdmData.AddPiece(AB.CdmData.Ensure(1), key, "icon", 0, 0)
    pass(AB)
    if lines then
        local ok, why = ns.Draft.Write(key, { lines = lines })
        T.truthy(ok, tostring(why))
        pass(AB)
    end
    return DUI, ns, AB, key
end

local function holderOf(DUI, ns, key) return DUI.API.Attach(ns.Conditions.FrameOf(key)) end

-- Daylight UI's shared tween driver run to the end.
local function finishTweens(DUI)
    local d = DUI.Motion.Driver()
    for _ = 1, 200 do
        if d then stub.RunOnUpdate(d, 0.05) end
    end
end

-- Every Widgets.GlowAround call round target: { host, on, style }.
local function spyHosts(DUI, target)
    local seen, keep = {}, DUI.Widgets.GlowAround
    DUI.Widgets.GlowAround = function(host, on, shape)
        if type(shape) ~= "table" or shape.frame == target or shape.parent == target or host == target then
            seen[#seen + 1] = { host = host, on = on, style = shape and shape.style }
        end
        return keep(host, on, shape)
    end
    return seen, function() DUI.Widgets.GlowAround = keep end
end

-- A number Daylight UI's file sets, read from the pinned checkout.
local function daylightNumber(file, pattern)
    local f = assert(io.open(stub.DUI_ROOT .. file, "r"))
    local text = f:read("*a")
    f:close()
    return tonumber(text:match(pattern))
end

-- ---------------------------------------------------------------------
-- What EZ offers
-- ---------------------------------------------------------------------

T.test("glow styles offer: Ring, Circling, Breathing, Twinkle; no Shine, no Comet", function()
    local DUI, ns = world()
    local B = ns.Bridge
    T.deq(B.GLOW_MOVED, { comet = "circle", shine = "ring" }, "owner, 2026-11-25")
    local keys = {}
    for _, st in ipairs(B.OfferedStyles()) do keys[#keys + 1] = st.key end
    local want = { "ring" }
    for _, st in ipairs(DUI.API.GlowStyles()) do
        if not B.GLOW_MOVED[st.key] then want[#want + 1] = st.key end
    end
    T.eq(table.concat(keys, " "), table.concat(want, " "), "the card's order, less the dropped")
    T.eq(table.concat(keys, " "), "ring circle breathe twinkle")
    -- The card still knows them, so a piece's own Daylight UI style keeps its name.
    T.eq(ns.Grammar.StyleName("comet"), "Comet")
    T.eq(ns.Grammar.StyleName("shine"), "Shine")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Saved Comet and Shine lines
-- ---------------------------------------------------------------------

T.test("glow styles migrate: saved Comet glow lines become Circle, Shine Ring (Conditions.VERSION 5)", function()
    local _, ns, _, key = world()
    ns.Conditions.Rule("none")
    local profile = ns.Bridge.ProfileOf()
    EZCDMDB.conditionsVersion = 4
    EZCDMDB.conditions[profile] = {
        [key] = { notUsable = { glow = { value = GOLD, style = "comet" } }, cantCast = { glow = { style = "shine" } } },
        other = { notUsable = { glow = { style = "twinkle" }, flash = { value = GOLD } } },
    }
    local rules = EZCDMDB.conditions[profile]
    T.deq(ns.Conditions.Rule(key), { notUsable = { glow = { value = GOLD, style = "circle" } },
                                     cantCast = { glow = { style = "ring" } } })
    T.eq(ns.Conditions.VERSION, 5)
    T.eq(EZCDMDB.conditionsVersion, 5)
    T.eq(rules[key].notUsable.glow.style, "circle", "as saved")
    T.deq(rules.other, { notUsable = { glow = { style = "twinkle" }, flash = { value = GOLD } } }, "the rest as it was")
    noErrors()
end)

T.test("glow styles migrate: saved per-moment Comet and Shine become Circle and Ring", function()
    local _, ns, _, key = world()
    local profile = ns.Bridge.ProfileOf()
    EZCDMDB.glowStyle = { [profile] = { [key] = { ready = "comet", usable = "shine", up = "breathe" } } }
    EZCDMDB.glowStyleVersion = nil
    T.deq(ns.Effects.Styles(key), { ready = "circle", usable = "ring", up = "breathe" })
    T.deq(EZCDMDB.glowStyle[profile][key], { ready = "circle", usable = "ring", up = "breathe" }, "as saved")
    T.eq(EZCDMDB.glowStyleVersion, 2)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Circle: a bigger light
-- ---------------------------------------------------------------------

T.test("glow styles circle: its light is the nameplate's circling light; other styles keep the CDM's", function()
    local plate = daylightNumber("DaylightUI_Nameplates/Plate.lua", "Plate%.CIRCLE_SCALE%s*=%s*{%s*size%s*=%s*([%d%.]+)")
    T.eq(plate, 0.9, "Daylight UI's own")
    local DUI, ns, AB, key = world({ { moment = "unusable", action = "glow", style = "circle" } })
    local B = ns.Bridge
    T.eq(B.CircleLight(), plate, "read live, or Daylight UI's number while nameplates are off")
    local frame = ns.Conditions.FrameOf(key)
    local short = math.min(frame:GetWidth(), frame:GetHeight())
    local asked, keep = {}, DUI.API.GlowAround
    DUI.API.GlowAround = function(f, on, opts)
        if on ~= false then asked[#asked + 1] = opts end
        return keep(f, on, opts)
    end
    block()
    DUI.API.GlowAround = keep
    T.eq(asked[1] and asked[1].style, "circle")
    T.eq(asked[1] and asked[1].size, short * plate, "0.9 of the short side")
    local size = B.GlowShape(frame, short, short, "twinkle")
    T.eq(size, short * AB.CdmEffects.GLOW_SCALE.size, "Twinkle stays at the CDM's 0.7")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Breathing: Daylight UI's breath
-- ---------------------------------------------------------------------

T.test("glow styles breathe: an EZ Breathing glow takes one breath in Daylight UI's breath", function()
    local breath = daylightNumber("DaylightUI_Chat/Feel.lua", "Feel%.BREATH%s*=%s*([%d%.]+)")
    T.eq(breath, 2.4, "Chat's unread tab")
    local DUI, ns, _, key = world({ { moment = "unusable", action = "glow", style = "breathe" } })
    T.eq(ns.Bridge.Breath(), breath)
    local holder = holderOf(DUI, ns, key)
    local seen, unspy = spyHosts(DUI, holder)
    block()
    unspy()
    local host = seen[1] and seen[1].host
    T.truthy(host and host.glowDriver, "a glow host EZ-CDM keeps")
    T.eq(host.glowStyle, "breathe")
    host.glowAt = 0
    stub.RunOnUpdate(host.glowDriver, 0.6)
    T.near(host.glowAt, 0.6 / breath, 1e-6, "a quarter breath in 0.6 s")
    T.eq(DUI.Widgets.GLOW_LAP.breathe, 2.8, "Daylight UI's own Breathing glows keep their speed")
    noErrors()
end)

T.test("glow styles breathe: switching a lit glow to another style puts the Breathing one out", function()
    local DUI, ns, AB, key = world({ { moment = "unusable", action = "glow", style = "breathe" } })
    local holder = holderOf(DUI, ns, key)
    local seen, unspy = spyHosts(DUI, holder)
    block()
    local paced = seen[1].host
    T.truthy(ns.Draft.Write(key, { lines = { { moment = "unusable", action = "glow", style = "twinkle" } } }))
    pass(AB)
    finishTweens(DUI)
    unspy()
    T.falsy(paced.glowDriver:IsShown(), "the Breathing glow is out")
    local lit = 0
    for _, s in ipairs(seen) do if s.on and s.style == "twinkle" then lit = lit + 1 end end
    T.truthy(lit > 0, "the Twinkle lit")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- A lit glow is never restarted while its line stays on
-- ---------------------------------------------------------------------

for _, style in ipairs({ "twinkle", "circle", "breathe" }) do
    T.test("glow styles steady: a lit " .. style .. " glow stays on and keeps its clock through refreshes, "
        .. "beside another glow line", function()
        local DUI, ns, AB, key = world({ { moment = "unusable", action = "glow", style = style },
            { moment = "short", action = "glow" } })
        local holder = holderOf(DUI, ns, key)
        local seen, unspy = spyHosts(DUI, holder)
        block()
        finishTweens(DUI)
        local host = seen[1] and seen[1].host
        T.truthy(host, "lit")
        stub.RunOnUpdate(host.glowDriver, 0.5)
        local at = host.glowAt
        T.truthy(at > 0, "its clock runs")
        for _ = 1, 3 do
            pass(AB)
            gameSaysUsable()
            ns.Conditions.Refresh(key)
        end
        finishTweens(DUI)
        unspy()
        for _, s in ipairs(seen) do T.truthy(s.on, "never put out while its line stays on") end
        T.truthy(host.glowDriver:IsShown(), "still on")
        T.eq(host.glowFade, 1, "at full")
        T.truthy(host.glowAt >= at, "its clock carries on, never back to the start")
        noErrors()
    end)
end
