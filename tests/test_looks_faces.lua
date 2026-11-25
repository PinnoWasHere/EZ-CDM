local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Looks on a piece that shows its debuff, then its cooldown (docs/tasks/w1-effects-fixes.md).
-- Daylight UI reports one piece frame whichever face it shows, and API.Attach's holder
-- sits over both faces. So a look that decorates the piece shows whenever its line is
-- true, while a look that only means something on the cooldown icon waits for it.
-- Also pop and shake, timed and sized by Daylight UI's own ready ping and talent shake.

local FLAME = 8050
local PINK = { 1, 0, 0.86 }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function L(moment, action, value) return { moment = moment, action = action, value = value } end

-- A Shaman with Flame Shock placed as an icon showing its debuff, then its cooldown.
local function flameShock(lines)
    local w = W.Build("SHAMAN")
    local D = w.AB.CdmData
    local r = w.Row(FLAME)
    local key = CW.ID(r.spell, r.category)
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, "icon", 0, 0) end
    w.Pass()
    local ok, why = w.ns.Draft.Write(key, { lines = lines, shows = "both" })
    T.truthy(ok, tostring(why))
    w.Pass()
    return w, key
end

-- The spell Daylight UI's item for the piece casts (the rank the player knows).
local function spellOf(w, key)
    local info = w.AB.CdmRows.pieceInfo[w.ns.Conditions.FrameOf(key)]
    return info and info.item and w.AB.CdmEffects.SpellOf(info.item)
end

-- Cast on a fresh target: its debuff lands and its cooldown runs.
local function castIt(w, key)
    local id = spellOf(w, key) or FLAME
    w.NewTarget()
    w.Cast(id)
    w.Cooldown(id, 6)
    w.BuffUp(FLAME, { unit = "target" })
    return id
end

-- ---------------------------------------------------------------------
-- Faces
-- ---------------------------------------------------------------------

T.test("faces: Flame Shock's halo and pulse show while its debuff shows and its cooldown runs", function()
    local w, key = flameShock({ L("blocked", "halo", PINK), L("blocked", "pulse") })
    local C, B = w.ns.Conditions, w.ns.Bridge
    T.eq(B.Shows(key), "both", "shows its debuff, then its cooldown")
    castIt(w, key)
    T.eq((B.BuffState(key)), true, "its debuff face shows")
    T.eq(C.Get("cantCast").read(tostring(key)), true, "can't cast it: its cooldown runs")
    for _, id in ipairs({ "cantCast:halo", "cantCast:pulse" }) do
        local v = C.Visible(key, id)
        T.truthy(v.lit, id .. ": lit on the debuff face")
        T.truthy(v.shown and v.alpha ~= 0, id .. ": on show")
        T.falsy(v.covered, id .. ": nothing covers it")
    end
    -- Both looks sit on the piece's own holder, which lies over either face.
    local holder = w.DUI.API.Attach(C.FrameOf(key))
    T.truthy(w.ns.Looks.Frame(holder, "halo"):IsShown(), "the halo on the piece's holder")
    T.truthy(w.ns.Looks.Frame(holder, "pulse"):IsShown(), "the pulse on the piece's holder")
    -- The debuff goes and the cooldown face shows: still on while it can't be cast.
    local id = spellOf(w, key) or FLAME
    w.BuffDown(FLAME)
    T.eq((B.BuffState(key)), false, "its cooldown face shows")
    T.truthy(C.Visible(key, "cantCast:halo").lit, "halo still on")
    T.truthy(C.Visible(key, "cantCast:pulse").lit, "pulse still on")
    w.Ready(id)
    w.Usable(true, false)
    T.falsy(C.Visible(key, "cantCast:halo").lit, "ready: halo gone")
    T.falsy(C.Visible(key, "cantCast:pulse").lit, "ready: pulse gone")
    noErrors()
end)

T.test("faces: border and words show on the debuff face too; gray and the swap wait for the cooldown face", function()
    local w, key = flameShock({ L("blocked", "border", PINK), L("blocked", "text", "Wait"),
        L("blocked", "gray"), L("blocked", "swap", 136048) })
    local C = w.ns.Conditions
    castIt(w, key)
    T.truthy(C.Visible(key, "cantCast:border").lit, "border on the debuff face")
    T.truthy(C.Visible(key, "cantCast:text").lit, "words on the debuff face")
    T.falsy(C.Visible(key, "cantCast:gray").lit, "the gray is the cooldown icon's")
    T.truthy(C.Visible(key, "cantCast:gray").covered)
    T.falsy(C.Visible(key, "cantCast:swap").lit, "the swap lies on the cooldown icon")
    w.BuffDown(FLAME)
    T.truthy(C.Visible(key, "cantCast:gray").lit, "gray on the cooldown face")
    T.truthy(C.Visible(key, "cantCast:swap").lit, "swap on the cooldown face")
    noErrors()
end)

T.test("faces: the drawer notes only the lines that still wait for the cooldown face", function()
    local w, key = flameShock({ L("blocked", "halo", PINK) })
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.shows, "both")
    for _, a in ipairs({ "halo", "pulse", "border", "text" }) do
        T.isnil(G.HiddenNote(kind, L("blocked", a)), a .. ": no note, it shows on either face")
    end
    for _, a in ipairs({ "gray", "swap", "pop" }) do
        local note = G.HiddenNote(kind, L("blocked", a))
        T.eq(note and note.text, "Hidden while its debuff shows.", a .. ": still waits")
    end
    noErrors()
end)

T.test("faces: a held look on a client line keeps hanging under its layer on a both piece", function()
    local w, key = flameShock({ L("targetLow", "halo", PINK) })
    castIt(w, key)
    w.EnterCombat()
    w.Health("target", 0.1, "secret")
    local v = w.ns.Conditions.Visible(key, "targetLow:halo")
    T.truthy(v.lit, "lit")
    T.eq(v.alpha, w.ns.Conditions.SECRET, "the game's secret")
    T.truthy(v.layered, "under the driven layer")
    noErrors()
end)

