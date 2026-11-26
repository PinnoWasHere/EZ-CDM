local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- Each look as strong as Daylight UI's own most visible use of the same thing
-- (docs/tasks/w1-intensity.md), and an EZ glow on either face of a piece.
--   ring     Daylight UI's own ring (the Cooldown Manager's glow), never a light
--   lights   sized by the Cooldown Manager's GLOW_SCALE, as its glows on a piece
--   flash    the ready ping's FLASH_ALPHA, Daylight UI's flash over an icon
--   sparkle  the twinkle at the Cooldown Manager's GLOW_SCALE
--   text     the Cooldown Manager's cooldown number size

local CLAP, SHOUT, REND, EXECUTE = 6343, 6673, 772, 5308
local FLAME = 8050
local ESSENTIAL = 0
local GOLD = { 1, 0.8, 0.2 }
local PINK = { 1, 0, 0.86 }

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function L(moment, action, value, style)
    return { moment = moment, action = action, value = value, style = style }
end
local function pass(AB) AB.CdmData.Changed(); AB.CdmRows.Refresh(); stub.RunTimers() end

local function usable(can, noPower)
    C_Spell.IsSpellUsable = function() return can, noPower end
end

local function gameSaysUsable()
    stub.FireEvent("SPELL_UPDATE_USABLE")
    stub.RunTimers()
end

-- Thunder Clap placed as an icon, logged in. motion: Daylight UI's motion switch.
local function world(lines, motion)
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, CLAP }, showAll = true })
        stub.spells[CLAP] = { name = "Thunder Clap" }
        stub.spells[REND] = { name = "Rend" }
    end })
    stub.RunTimers()
    DUI.DB.General().motion = motion ~= false
    usable(true, false)
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
local function block() usable(false, false); gameSaysUsable() end
local function unblock() usable(true, false); gameSaysUsable() end

-- Every API.GlowAround call that turns a glow on, by frame.
local function spyGlowAround(DUI)
    local asked = {}
    local keep = DUI.API.GlowAround
    DUI.API.GlowAround = function(frame, on, opts)
        if on ~= false then asked[#asked + 1] = { frame = frame, opts = opts or {} } end
        return keep(frame, on, opts)
    end
    return asked, function() DUI.API.GlowAround = keep end
end

-- The light size and strip width the Cooldown Manager gives a glow on the piece
-- (CdmEffects.GLOW_SCALE on its short side, the strip never under 2 px).
local function cdmShape(DUI, AB, frame, piece)
    local short = math.min(piece:GetWidth(), piece:GetHeight())
    T.truthy(short > 0, "the piece has a size")
    local sc = AB.CdmEffects.GLOW_SCALE
    return short * sc.size, math.max(DUI.Pixel.Px(frame, 2), short * sc.thick)
end

-- ---------------------------------------------------------------------
-- Glow on either face
-- ---------------------------------------------------------------------

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

local function castIt(w, key)
    local info = w.AB.CdmRows.pieceInfo[w.ns.Conditions.FrameOf(key)]
    local id = info and info.item and w.AB.CdmEffects.SpellOf(info.item) or FLAME
    w.NewTarget()
    w.Cast(id)
    w.Cooldown(id, 6)
    w.BuffUp(FLAME, { unit = "target" })
    return id
end

T.test("intensity faces: an EZ glow lights while Flame Shock's debuff shows and its cooldown runs", function()
    local w, key = flameShock({ L("blocked", "glow", PINK) })
    local C = w.ns.Conditions
    T.truthy(C.AnyFace("cantCast", "glow"), "the glow decorates the whole piece")
    castIt(w, key)
    T.eq((w.ns.Bridge.BuffState(key)), true, "its debuff face shows")
    local v = C.Visible(key, "cantCast:glow")
    T.truthy(v.lit, "lit on the debuff face")
    T.truthy(v.shown, "on show")
    T.falsy(v.covered, "nothing covers it")
    w.BuffDown(FLAME)
    T.truthy(C.Visible(key, "cantCast:glow").lit, "still lit on the cooldown face")
    noErrors()
end)

T.test("intensity faces: the drawer gives a glow line no hidden note", function()
    local w, key = flameShock({ L("blocked", "glow", PINK) })
    local G = w.ns.Grammar
    local kind = G.Kind(key)
    T.eq(kind.shows, "both")
    T.isnil(G.HiddenNote(kind, L("blocked", "glow")), "it shows on either face")
    T.eq((G.HiddenNote(kind, L("blocked", "gray")) or {}).text, "Hidden while its debuff shows.",
        "the gray still waits for the cooldown face")
    noErrors()
end)

T.test("intensity faces: a glow on a client line still hangs under its driven layer", function()
    local w, key = flameShock({ L("targetLow", "glow", PINK) })
    castIt(w, key)
    w.EnterCombat()
    w.Health("target", 0.1, "secret")
    local v = w.ns.Conditions.Visible(key, "targetLow:glow")
    T.truthy(v.lit, "lit")
    T.eq(v.alpha, w.ns.Conditions.SECRET, "the game's secret")
    T.truthy(v.layered, "under the driven layer")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The ring
-- ---------------------------------------------------------------------

T.test("intensity ring: a Ring glow line is Daylight UI's ring round the piece, never a light", function()
    local DUI, ns, AB, key = world({ L("unusable", "glow", GOLD, "ring") })
    local asked, undo = spyGlowAround(DUI)
    block()
    undo()
    local holder = holderOf(DUI, ns, key)
    T.eq(#asked, 0, "no API.GlowAround light")
    T.truthy(AB.CdmEffects.GlowShown(holder), "Daylight UI's ring on the piece's holder (API.Glow)")
    local g = AB.CdmEffects.GlowFrame(holder)
    T.truthy(g and g:IsShown(), "its frame shows")
    T.truthy(ns.Conditions.Visible(key, "notUsable:glow").shown, "Visible sees it")
    unblock()
    T.falsy(AB.CdmEffects.GlowShown(holder), "off with the line")
    noErrors()
end)

T.test("intensity ring: a glow line with no style takes the piece's style, Ring by default", function()
    local DUI, ns, AB, key = world({ L("unusable", "glow") })
    local asked, undo = spyGlowAround(DUI)
    block()
    undo()
    T.eq(#asked, 0, "no light")
    T.truthy(AB.CdmEffects.GlowShown(holderOf(DUI, ns, key)), "the ring")
    noErrors()
end)

T.test("intensity ring: motion off gives the ring, as Daylight UI's own glow does", function()
    local DUI, ns, AB, key = world({ L("unusable", "glow", GOLD, "comet") }, false)
    local asked, undo = spyGlowAround(DUI)
    block()
    undo()
    T.eq(#asked, 0, "no light with motion off")
    T.truthy(AB.CdmEffects.GlowShown(holderOf(DUI, ns, key)), "the ring")
    noErrors()
end)

T.test("intensity ring: a Ring glow on a client line is Daylight UI's ring on its layer", function()
    local w = W.Build("WARRIOR")
    local key = CW.ID(EXECUTE, W.ESSENTIAL)
    local D = w.AB.CdmData
    if not D.Get(1).pieces[key] then D.AddPiece(D.Ensure(1), key, "icon", 0, 0) end
    w.Pass()
    T.truthy(w.ns.Draft.Write(key, { lines = { L("targetLow", "glow", GOLD, "ring") } }))
    w.Pass()
    w.NewTarget()
    w.Health("target", 0.1)
    local layer = w.ns.Conditions.Layer(key, "targetLow:glow")
    T.truthy(layer, "the line's layer")
    T.truthy(w.AB.CdmEffects.GlowShown(layer), "the ring on the layer")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Lights at the Cooldown Manager's size
-- ---------------------------------------------------------------------

T.test("intensity lights: a Comet glow line is sized as the Cooldown Manager sizes its glow", function()
    local DUI, ns, AB, key = world({ L("unusable", "glow", GOLD, "comet") })
    local asked, undo = spyGlowAround(DUI)
    block()
    undo()
    local holder = holderOf(DUI, ns, key)
    T.eq(#asked, 1, "one light")
    local o = asked[1] and asked[1].opts or {}
    T.eq(o.style, "comet")
    local size, thick = cdmShape(DUI, AB, holder, ns.Conditions.FrameOf(key))
    T.near(o.size, size, 0.001, "light size: GLOW_SCALE.size of the short side")
    T.near(o.thick, thick, 0.001, "strip width: GLOW_SCALE.thick of the short side")
    T.truthy(o.size > DUI.Widgets.GLOW.size, "bigger than the main buttons' light")
    noErrors()
end)

T.test("intensity sparkle: the twinkle at the Cooldown Manager's size", function()
    local DUI, ns, AB, key = world({ L("unusable", "sparkle", GOLD) })
    local asked, undo = spyGlowAround(DUI)
    block()
    undo()
    T.eq(#asked, 1, "one twinkle")
    local o = asked[1] and asked[1].opts or {}
    T.eq(o.style, "twinkle")
    local size, thick = cdmShape(DUI, AB, asked[1].frame, ns.Conditions.FrameOf(key))
    T.near(o.size, size, 0.001, "light size")
    T.near(o.thick, thick, 0.001, "strip width")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Flash and text
-- ---------------------------------------------------------------------

T.test("intensity flash: starts at the ready ping's brightness", function()
    local _, ns, AB, key = world({ L("unusable", "flash", GOLD) })
    block()
    local tex = ns.Looks.Fired(key, "flash").shown
    local _, _, _, a = tex:GetVertexColor()
    if tex.__color then a = tex.__color[4] end
    T.eq(a, AB.Ping.FLASH_ALPHA, "Ping.FLASH_ALPHA")
    T.truthy(a > AB.Skin.FLASH_ALPHA, "stronger than the auto attack wash")
    noErrors()
end)

T.test("intensity text: the words at the Cooldown Manager's cooldown number size", function()
    local DUI, ns, AB, key = world({ L("unusable", "text", "Kick!") })
    block()
    local words = ns.Looks.Frame(holderOf(DUI, ns, key), "text").words
    local probe = DUI.API.Text(UIParent, "small")
    DUI.Style.SetTextSize(probe, AB.Skin.COOLDOWN_SIZE)
    T.eq(select(2, words:GetFont()), select(2, probe:GetFont()), "Skin.COOLDOWN_SIZE through Style.SetTextSize")
    T.truthy(AB.Skin.COOLDOWN_SIZE > DUI.Style.SIZE.small, "bigger than before")
    noErrors()
end)
