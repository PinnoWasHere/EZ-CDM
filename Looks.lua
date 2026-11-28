local addonName, ns = ...

-- EZ-CDM's looks: actions every condition's lines may end in (Conditions.RegisterLook),
-- each drawn with Daylight UI's own builders, art and measures on the piece's
-- API.Attach holder, or on a line's layer when a client part drives it.
--
-- Once, as the line turns on (edge). They move, so they are plain lines only, and
-- motion off in Daylight UI keeps them away, as it keeps its own:
--   flash    the wash texture in the line's color from the ready ping's brightness
--            (Ping.FLASH_ALPHA), played by Motion.Flash
--   sparkle  API.GlowAround's twinkle for one lap (Widgets.GLOW_LAP), at the
--            Cooldown Manager's glow size (CdmEffects.GLOW_SCALE)
--   screen   Daylight UI's vignette art (portrait-vignette.png, as InstallerScreen.lua
--            lays it) over the whole screen in the color, in with API.Fade FAST, out SLOW
--
-- Once, and gone as the line turns off (hides). Plain lines only:
--   flare    Daylight UI's Proc Alerts flare around the character (API 1.16,
--            me.AddProcAlert / ShowProcAlert / HideProcAlert), one alert per line,
--            in the line's design, animation and sound. Daylight UI draws it, so
--            its own motion switch and Proc Alerts' settings rule it. Offered only
--            on a Daylight UI with Proc Alerts' calls
--
-- Held while the line is on. They are alpha only, so a client part may drive them:
--   pulse    the wash texture breathing on Daylight UI's own pulse driver
--            (CdmEffects.Flash, the empty bar's "flash it"); still with motion off
--   border   a lean Style.Shell outline, lit as the action bars' Border color does:
--            Style.LightShell in the accent, Style.SetShellColors in a color
--   halo     Style.AURA_HALO behind the piece, placed by Style.PlaceAuraHalo, the
--            light behind an aura button
--   text     the line's words in API.Text, in the accent, at the Cooldown Manager's
--            cooldown number size (Skin.COOLDOWN_SIZE)
--   swap     a copy of the icon showing the picked icon in its place
--   fill     a number on the icon: a tint stood up over it, or Daylight UI's thin bar
--            under it, in the line's color (below, "the progress fill")
--
-- Pulse, border, halo, text and the fill sit on the piece's holder, which lies over
-- whichever face the piece shows, so they show on its buff's face too (anyFace).
-- Swap lies on the cooldown icon, under the buff's button, so it waits for the
-- cooldown face.
--
-- A color look's value is its color (nil = the accent). No look runs an OnUpdate of
-- its own: Motion's shared tween driver, the glow's and the pulse's are Daylight UI's.

local Bridge, Conditions, Overlay, Effects = ns.Bridge, ns.Conditions, ns.Overlay, ns.Effects

local Looks = {}
ns.Looks = Looks

-- Debug handle for an in-game check.
EZCDM_Looks = Looks

local API = _G.DaylightUI and _G.DaylightUI.API

-- The glow style the sparkle plays once.
Looks.SPARKLE_STYLE = "twinkle"
-- The vignette Daylight UI lays over the screen (InstallerScreen.lua).
Looks.VIGNETTE = "portrait-vignette.png" -- look-ok: Daylight UI's own media, read through API.Media

local weak = { __mode = "k" }

-- Piece key -> effect -> { at = GetTime(), n = how many so far, shown = what it
-- drew }: the last one-shot.
local fired = {}

local function speed(name) return API.Speed and API.Speed[name] or nil end

-- The line's color, or the accent.
local function colorOf(opts)
    local c = type(opts.value) == "table" and opts.value or nil
    if c then return c[1], c[2], c[3] end
    return API.Accent()
end

local function note(key, effect, shown)
    if key == nil then return end
    local k = tostring(key)
    fired[k] = fired[k] or {}
    local was = fired[k][effect]
    fired[k][effect] = { at = GetTime(), n = (was and was.n or 0) + 1, shown = shown }
end

-- One frame of ours per target and name, over the target.
local frames = setmetatable({}, weak)
local function frameOn(target, name)
    local set = frames[target]
    if not set then
        set = {}
        frames[target] = set
    end
    local f = set[name]
    if not f then
        f = CreateFrame("Frame", nil, target)
        f:SetAllPoints(target)
        set[name] = f
    end
    return f
end
local function frameIf(target, name) return frames[target] and frames[target][name] or nil end

-- The wash texture on f, in r, g, b at alpha (Daylight UI's wash strength when nil).
local function wash(f, r, g, b, alpha)
    local t = f.wash
    if not t then
        t = f:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(f)
        f.wash = t
    end
    t:SetColorTexture(r, g, b, alpha or Bridge.WashAlpha() or 0)
    return t
end

-- The piece's size, read off its own frame: the holder and a layer lie over it.
local function sizeOf(key)
    local piece = Conditions.FrameOf(key)
    if not piece then return nil end
    return piece:GetWidth(), piece:GetHeight()
end

local function icons(kind) return kind.shape == "icon" end
local function motionNote() return not Bridge.MotionOn() and "motionOff" or nil end
local function any() return true end

-- ---------------------------------------------------------------------
-- Once, as the line turns on
-- ---------------------------------------------------------------------

local function flash(target, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local f = frameOn(target, "flash")
    local r, g, b = colorOf(opts)
    local t = wash(f, r, g, b, Bridge.FlashAlpha())
    Bridge.Flash(t, speed("SLOW"))
    note(opts.key, "flash", t)
end

local function sparkle(target, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local f = frameOn(target, "sparkle")
    f.gen = (f.gen or 0) + 1
    local gen = f.gen
    local r, g, b = colorOf(opts)
    local size, thick = Bridge.GlowShape(f, sizeOf(opts.key))
    API.GlowAround(f, true, { style = Looks.SPARKLE_STYLE, r = r, g = g, b = b, size = size, thick = thick })
    C_Timer.After(Bridge.GlowLap(Looks.SPARKLE_STYLE) or speed("SLOW"), function()
        if f.gen == gen then API.GlowAround(f, false) end
    end)
    note(opts.key, "sparkle", f)
end

-- The one screen edge, over the whole screen and under every window.
local edge
local function screenEdge()
    if edge then return edge end
    edge = CreateFrame("Frame", nil, UIParent)
    edge:SetAllPoints(UIParent)
    edge:SetFrameStrata("BACKGROUND")
    edge:EnableMouse(false)
    edge:SetAlpha(0)
    edge.tex = edge:CreateTexture(nil, "OVERLAY")
    edge.tex:SetTexture(API.Media(Looks.VIGNETTE))
    edge.tex:SetAllPoints(edge)
    return edge
end

local function screen(_, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local f = screenEdge()
    f.tex:SetVertexColor(colorOf(opts))
    f.gen = (f.gen or 0) + 1
    local gen = f.gen
    API.Fade(f, 1, "FAST")
    C_Timer.After(speed("FAST") or 0, function()
        if f.gen == gen then API.Fade(f, 0, "SLOW") end
    end)
    note(opts.key, "screen", f)
end

-- ---------------------------------------------------------------------
-- Once, gone as the line turns off: the flare
-- ---------------------------------------------------------------------

-- Proc Alerts' designs and animations (API.md, Proc Alerts), in its own order, and
-- the ones AddProcAlert takes with none picked.
Looks.FLARE_DESIGNS = { "wings", "talons", "pillars", "shards", "flames", "bolt", "comet", "crown", "sigil",
                        "sun", "ring", "wave" }
Looks.FLARE_ANIMS = { "breathe", "pulse", "impact", "flash", "still" }
Looks.FLARE_DESIGN, Looks.FLARE_ANIM = "sun", "pulse"

local function setOf(list)
    local out = {}
    for _, v in ipairs(list) do out[v] = true end
    return out
end
local DESIGNS, ANIMS = setOf(Looks.FLARE_DESIGNS), setOf(Looks.FLARE_ANIMS)

-- A flare line's value as saved: { design, anim, sound }, each left out at Proc
-- Alerts' own. sound is a key of Daylight UI's alert list (Sound.AlertChoices),
-- "none" included, as Proc Alerts' own Sound row saves it. nil for none or a bad one.
local function cleanFlare(v)
    if type(v) ~= "table" then return nil end
    local out = {}
    if v.design ~= nil then
        if not DESIGNS[v.design] then return nil end
        out.design = v.design
    end
    if v.anim ~= nil then
        if not ANIMS[v.anim] then return nil end
        out.anim = v.anim
    end
    if v.sound ~= nil then
        local ok = type(v.sound) == "string" and v.sound ~= "" and not v.sound:find("|", 1, true)
            and not v.sound:find("^head:")
        if not ok then return nil end
        out.sound = v.sound
    end
    return next(out) and out or nil
end

local me
local function plugin()
    me = me or API.For(addonName)
    return me
end

-- A line's alert key, the same for as long as the line exists. Daylight UI shows
-- it to others as "EZ-CDM:<key>".
local function alertKey(opts) return tostring(opts.key) .. ":" .. tostring(opts.line) end
function Looks.FlareKey(key, line) return alertKey({ key = key, line = line }) end

-- Holder -> line id -> alert key: the flares up for its lines.
local flares = setmetatable({}, weak)

local function hideFlare(target, id)
    local set = flares[target]
    local k = set and set[id]
    if not k then return end
    set[id] = nil
    plugin().HideProcAlert(k)
end

-- Proc Alerts' sound plays as the flare lands, once. Daylight UI never hides it, so
-- it goes as the line turns off. The alert is added again at each show, so a look
-- picked since, and Proc Alerts turned on since, both take.
local function flare(target, on, opts)
    if not on then return hideFlare(target, opts.line) end
    local v = type(opts.value) == "table" and opts.value or {}
    local k = alertKey(opts)
    local spec = { name = Bridge.SpellName(tonumber(opts.key) or opts.key), design = v.design or Looks.FLARE_DESIGN,
                   anim = v.anim or Looks.FLARE_ANIM, sound = v.sound }
    if not plugin().AddProcAlert(k, spec) then return end
    if not plugin().ShowProcAlert(k, { left = opts.left, dur = opts.dur }) then return end
    flares[target] = flares[target] or {}
    flares[target][opts.line] = k
    note(opts.key, "flare", k)
end

-- ---------------------------------------------------------------------
-- Held while the line is on
-- ---------------------------------------------------------------------

local function pulse(target, on, opts)
    local f = on and frameOn(target, "pulse") or frameIf(target, "pulse")
    if not f then return end
    if not on then
        if f.wash then Bridge.Pulse(f, f.wash, false) end
        f:Hide()
        return
    end
    local t = wash(f, colorOf(opts))
    t:SetAlpha(1)
    f:Show()
    if Bridge.MotionOn() then Bridge.Pulse(f, t, true) end
end

local function border(target, on, opts)
    local f = on and frameOn(target, "border") or frameIf(target, "border")
    if not f then return end
    if not on then return f:Hide() end
    local s = f.shell or Bridge.Shell(f, { lean = true, shadowAlpha = 0 })
    f.shell = s
    if s then
        if type(opts.value) == "table" then
            Bridge.ShellColor(s, { opts.value[1], opts.value[2], opts.value[3] })
        else
            Bridge.LightShell(s)
        end
    end
    f:Show()
end

local function halo(target, on, opts)
    local f = on and frameOn(target, "halo") or frameIf(target, "halo")
    if not f then return end
    if not on then return f:Hide() end
    Bridge.HaloBehind(f, Conditions.FrameOf(opts.key)):SetVertexColor(colorOf(opts))
    f:Show()
end

local function text(target, on, opts)
    local f = on and frameOn(target, "text") or frameIf(target, "text")
    if not f then return end
    if not on or type(opts.value) ~= "string" then return f:Hide() end
    if not f.words then
        f.words = API.Text(f, "small", "CENTER")
        f.words:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.words:SetPoint("RIGHT", f, "RIGHT", 0, 0)
        f.words:SetWordWrap(false)
        Bridge.CooldownTextSize(f.words)
    end
    f.words:SetText(opts.value)
    f.words:SetTextColor(API.Accent())
    f:Show()
end

local function swap(target, on, opts)
    if not on then
        local c = Overlay.CopyOn(target, "swap")
        if c then c.frame:SetAlpha(0) end
        return
    end
    local c = opts.value ~= nil and Overlay.IconCopy(target, "swap", opts.key, opts.value)
    if c then c.frame:SetAlpha(1) end
end

-- ---------------------------------------------------------------------
-- Held while the line is on: the progress fill
-- ---------------------------------------------------------------------

-- The game fills the bar and EZ-CDM never reads the number, so a secret goes in
-- whole. A power percent (UnitPowerPercent) always goes through a curve
-- the game evaluates: straight for "drains", flipped for "rises". Time left is a
-- duration object the bar runs itself (SetTimerDuration): a real cooldown's, a
-- totem's, or a span on Daylight UI's clock of your own buff. One event frame keeps
-- power current, listening only while a power fill is lit;
-- time left is taken again on the fill's watch (Conditions' effect watch).

-- A fill's picks, in the drawer's order, and the ones a value leaves out.
Looks.FILL_SOURCES = { "power", "time" }
Looks.FILL_SHAPES = { "tint", "bar" }
Looks.FILL_DIRS = { "drain", "rise" }
Looks.FILL_SOURCE, Looks.FILL_SHAPE, Looks.FILL_DIR = "time", "tint", "drain"

-- The thin bar's gap under the icon's border, in pixels (owner, 2026-11-27).
Looks.FILL_GAP = 2

local SOURCES, SHAPES, DIRS = setOf(Looks.FILL_SOURCES), setOf(Looks.FILL_SHAPES), setOf(Looks.FILL_DIRS)

-- A fill line's value as saved: { source, shape, dir, color }, each left out at its
-- default (the first source that fits, the tint, drains, the accent). nil for none or a bad one.
local function cleanFill(v)
    if type(v) ~= "table" then return nil end
    local out = {}
    for field, set in pairs({ source = SOURCES, shape = SHAPES, dir = DIRS }) do
        if v[field] ~= nil then
            if not set[v[field]] then return nil end
            out[field] = v[field]
        end
    end
    if v.color ~= nil then
        out.color = Conditions.CleanValue("color", v.color)
        if out.color == nil then return nil end
    end
    return next(out) and out or nil
end

-- A fill value's source, shape, direction and color (nil for the accent). A value
-- with no source fills with the first one that fits kind's line about layer.
function Looks.FillPicks(v, kind, layer)
    v = type(v) == "table" and v or {}
    local source = v.source
    if source == nil and kind and ns.Grammar then source = (ns.Grammar.FillSourcesAt(kind, layer or "any"))[1] end
    return source or Looks.FILL_SOURCE, v.shape or Looks.FILL_SHAPE, v.dir or Looks.FILL_DIR, v.color
end

local function secret(v) return type(issecretvalue) == "function" and issecretvalue(v) == true end
local function pieceKey(k) return tonumber(k) or k end

-- Direction -> the curve a percent goes through, or false where the game has none.
local fillCurves = {}
local function fillCurve(dir)
    local made = fillCurves[dir]
    if made ~= nil then return made or nil end
    made = false
    if C_CurveUtil and C_CurveUtil.CreateCurve then
        local c = C_CurveUtil.CreateCurve()
        if c then
            if Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Linear) end
            if dir == "rise" then
                c:AddPoint(0, 1)
                c:AddPoint(1, 0)
            else
                c:AddPoint(0, 0)
                c:AddPoint(1, 1)
            end
            made = c
        end
    end
    fillCurves[dir] = made
    return made or nil
end

-- The spell's power percent through dir's curve, as the game gives it; 0 with no
-- answer.
local function percentOf(_, key, dir)
    local curve = type(UnitPowerPercent) == "function" and fillCurve(dir)
    local t = curve and Conditions.PowerOf(key)
    if not t then return 0 end
    local ok, v = Bridge.SafeReturn(UnitPowerPercent, "player", t, false, curve)
    if ok and (secret(v) or type(v) == "number") then return v end
    return 0
end

-- Which clock a time-left fill runs on for a line about layer: "buff", "totem",
-- "cooldown", or nil. A piece showing its buff and its cooldown in turn follows the
-- face it shows.
local function timeFace(key, kind, layer)
    if kind.clocked and layer ~= "cooldown"
        and (layer == "buff" or kind.buffOnly or Bridge.BuffState(key) == true) then return "buff" end
    if layer == "buff" then return nil end
    if kind.totemTime then return "totem" end
    if kind.cooldownReady then return "cooldown" end
    if kind.clocked then return "buff" end
    return nil
end

-- The duration object face's clock runs on now, or nil when it has no time left. A
-- real cooldown's never counts the global cooldown, as Daylight UI's own cooldown
-- bars take it (CdmBars.lua). A buff's is a span of f's own, as Daylight UI's aura
-- bars lay one (CdmBars.lua SetTime).
local function durationOf(f, key, face)
    local sid = Bridge.SpellOf(pieceKey(key))
    if sid == nil then return nil end
    if face == "cooldown" then
        local info = C_Spell.GetSpellCooldown(sid)
        if type(info) ~= "table" or secret(info.isActive) or secret(info.isOnGCD) then return nil end
        if info.isActive ~= true or info.isOnGCD == true then return nil end
        if type(C_Spell.GetSpellCooldownDuration) ~= "function" then return nil end
        local ok, d = Bridge.SafeReturn(C_Spell.GetSpellCooldownDuration, sid, true)
        if ok and type(d) ~= "nil" then return d end
    elseif face == "totem" then
        return Bridge.TotemDuration(sid)
    elseif face == "buff" then
        local ends, lasts = Effects.BuffClock(key)
        if not ends or not (C_DurationUtil and C_DurationUtil.CreateDuration) then return nil end
        f.span = f.span or C_DurationUtil.CreateDuration()
        f.span:SetTimeFromStart(ends - lasts, lasts)
        return f.span
    end
    return nil
end

-- The bar runs d, or with none sits where no time left is: empty for "drains", full
-- for "rises".
local function runTime(bar, d, dir)
    local E = type(Enum) == "table" and Enum or {}
    local D, I = E.StatusBarTimerDirection, E.StatusBarInterpolation
    if type(d) ~= "nil" and D and I and type(bar.SetTimerDuration) == "function" then
        local how = dir == "rise" and D.ElapsedTime or D.RemainingTime
        if Bridge.SafeCall(bar.SetTimerDuration, bar, d, I.Immediate, how) then return end
    end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(dir == "rise" and 1 or 0)
end

-- The events that move each percent source, as { event, unit }.
local FILL_EVENTS = {
    power = { { "UNIT_POWER_FREQUENT", "player" }, { "UNIT_MAXPOWER", "player" }, { "UNIT_DISPLAYPOWER", "player" } },
}
-- Source -> fill frame -> true, for each fill of a percent source lit now.
local fillsBy = { power = setmetatable({}, weak) }
-- Event -> the units it is registered for now, sorted and joined ("" for any unit).
local fillHeard = {}

local function barOf(f) return f.shape == "bar" and f.bar or f.tint end

local function setPercent(f)
    local bar = barOf(f)
    if not bar then return end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(percentOf(f.source, f.key, f.dir))
end

local fillEvents = CreateFrame("Frame")
fillEvents:SetScript("OnEvent", function(_, event, unit)
    for source, set in pairs(fillsBy) do
        for _, e in ipairs(FILL_EVENTS[source]) do
            if e[1] == event and (e[2] == nil or e[2] == unit) then
                for f in pairs(set) do setPercent(f) end
                break
            end
        end
    end
end)

-- Registers each event a lit fill needs, for its units only, and drops the rest.
local function listenFills()
    local want = {}
    for source, set in pairs(fillsBy) do
        if next(set) then
            for _, e in ipairs(FILL_EVENTS[source]) do
                want[e[1]] = want[e[1]] or {}
                want[e[1]][e[2] or ""] = true
            end
        end
    end
    for name in pairs(fillHeard) do
        if not want[name] then
            fillEvents:UnregisterEvent(name)
            fillHeard[name] = nil
        end
    end
    for name, units in pairs(want) do
        local list = {}
        for u in pairs(units) do list[#list + 1] = u end
        table.sort(list)
        local id = table.concat(list, ",")
        if fillHeard[name] ~= id then
            if fillHeard[name] then fillEvents:UnregisterEvent(name) end
            if units[""] then
                fillEvents:RegisterEvent(name)
            else
                fillEvents:RegisterUnitEvent(name, unpack(list))
            end
            fillHeard[name] = id
        end
    end
end

-- The tint's frame level: the icon's own, as the gray copy sits (Overlay.lua), so the
-- swipe, the numbers and the border stay on top.
local function iconLevel(bar, key)
    local piece = Conditions.FrameOf(key)
    local icon = piece and Bridge.PieceIcon(piece)
    local owner = icon and icon:GetParent()
    if not owner then return end
    bar:SetFrameStrata(owner:GetFrameStrata())
    local level = owner:GetFrameLevel()
    if type(level) == "number" and not secret(level) then bar:SetFrameLevel(level) end
end

-- f's bar for shape, made once: the tint over the target, or the thin bar under it.
local function fillBar(f, target, shape, key)
    if shape == "bar" then
        if not f.bar then
            f.bar = API.Bar(f)
            f.bar:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -Looks.FILL_GAP)
            f.bar:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 0, -Looks.FILL_GAP)
            f.bar:SetHeight(Bridge.BarHeight())
        end
        return f.bar
    end
    if not f.tint then
        local t = CreateFrame("StatusBar", nil, f)
        t:SetAllPoints(f)
        t:SetOrientation("VERTICAL")
        Bridge.TrackBar(t)
        t:SetMinMaxValues(0, 1)
        f.tint = t
    end
    iconLevel(f.tint, key)
    return f.tint
end

-- An icon with something to fill with: a power the spell costs, or a clock.
local function fillFits(kind)
    return icons(kind) and ns.Grammar ~= nil and (ns.Grammar.FillSourcesAt(kind, "any"))[1] ~= nil
end

local function putOutFill(f)
    f.lit, f.kind = nil, nil
    for _, set in pairs(fillsBy) do set[f] = nil end
    listenFills()
    f:Hide()
end

local function fill(target, on, opts)
    local f = on and frameOn(target, "fill") or frameIf(target, "fill")
    if not f then return end
    if not on then return putOutFill(f) end
    f.kind = f.lit and f.kind or (ns.Grammar and ns.Grammar.Kind(pieceKey(opts.key))) or {}
    local source, shape, dir, color = Looks.FillPicks(opts.value, f.kind, opts.layer)
    local bar = fillBar(f, target, shape, opts.key)
    local other = shape == "bar" and f.tint or f.bar
    if other then other:Hide() end
    bar:Show()
    if shape == "bar" then
        local painted = color and table.concat(color, ",") or "accent"
        if f.painted ~= painted then
            Bridge.BarColor(bar, color)
            f.painted = painted
        end
    else
        local r, g, b
        if color then r, g, b = color[1], color[2], color[3] else r, g, b = API.Accent() end
        bar:SetStatusBarColor(r, g, b, Bridge.WashAlpha() or 0)
    end
    f.lit, f.key, f.source, f.shape, f.dir = true, opts.key, source, shape, dir
    for s, set in pairs(fillsBy) do set[f] = s == source or nil end
    listenFills()
    if source == "time" then
        runTime(bar, durationOf(f, opts.key, timeFace(opts.key, f.kind, opts.layer)), dir)
    else
        setPercent(f)
    end
    f:Show()
end

-- What may change a time-left fill: a cooldown starting or ending, a buff landing or
-- going, a totem, your own recast.
local FILL_WATCH = {
    daylight = { "ready", "started", "buffUp", "buffDown", "changed" },
    game = { "SPELL_UPDATE_COOLDOWN", "PLAYER_TOTEM_UPDATE", { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
    late = true,
}

-- The fill's events registered now, sorted ("EVENT@unit", or "EVENT" for any unit).
function Looks.FillEvents()
    local out = {}
    for name, id in pairs(fillHeard) do
        for u in (id .. ","):gmatch("([^,]*),") do out[#out + 1] = u == "" and name or name .. "@" .. u end
    end
    table.sort(out)
    return out
end

-- What a held look drew on target, for Conditions.Visible.
local function shownFrame(name)
    return function(target)
        local f = frameIf(target, name)
        return f and f:IsShown() and f or nil
    end
end

local function clearFrame(name, also)
    return function(target)
        local f = frameIf(target, name)
        if f then
            if also then also(f) end
            f:Hide()
        end
    end
end

-- ---------------------------------------------------------------------
-- For tests and the dev suite
-- ---------------------------------------------------------------------

-- The last one-shot of effect on a piece: { at, n, shown }, or nil.
function Looks.Fired(key, effect)
    local t = fired[tostring(key)]
    return t and t[effect] or nil
end

-- EZ-CDM's frame named name on target (a holder or a layer), or nil.
function Looks.Frame(target, name) return frameIf(target, name) end

-- The screen edge's frame, once made.
function Looks.Edge() return edge end

-- What a fill drew on target (a holder or a layer), for the dev suite: { shape,
-- source, dir, value, timer, level, iconLevel }, value Conditions.SECRET while the
-- game keeps it; nil with no fill on show.
function Looks.FillState(target)
    local f = frameIf(target, "fill")
    local bar = f and f:IsShown() and barOf(f)
    if not bar then return nil end
    local v = bar:GetValue()
    if secret(v) then v = Conditions.SECRET end
    local piece = Conditions.FrameOf(f.key)
    local icon = piece and Bridge.PieceIcon(piece)
    local owner = icon and icon:GetParent()
    local d = type(bar.GetTimerDuration) == "function" and bar:GetTimerDuration() or nil
    return { shape = f.shape, source = f.source, dir = f.dir, value = v, timer = d ~= nil,
             level = bar:GetFrameLevel(), iconLevel = owner and owner:GetFrameLevel() or nil }
end

-- ---------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------

-- In the drawer's order: { action, effect fields }.
Looks.LIST = {
    { action = "flash", effect = { key = "flash", edge = true, value = "color", fits = icons, draw = flash,
        clear = clearFrame("flash"), offNote = motionNote } },
    { action = "sparkle", effect = { key = "sparkle", edge = true, value = "color", fits = any, draw = sparkle,
        offNote = motionNote,
        clear = function(target)
            local f = frameIf(target, "sparkle")
            if f then
                f.gen = (f.gen or 0) + 1
                API.GlowAround(f, false)
            end
        end } },
    { action = "screen", effect = { key = "screen", edge = true, value = "color", fits = any, draw = screen,
        clear = function() end, offNote = motionNote } },
    { action = "flare", needs = Bridge.ProcAlertsFit, value = { "flare", cleanFlare },
      effect = { key = "flare", edge = true, hides = true, value = "flare", fits = any, draw = flare,
        clear = function(target, id)
            if id then return hideFlare(target, id) end
            for line in pairs(flares[target] or {}) do hideFlare(target, line) end
        end,
        shown = function(_, opts)
            local up = API.ProcState(addonName .. ":" .. alertKey(opts))
            return up and API.GetFrame("procs") or nil
        end,
        offNote = function() return not Bridge.ProcAlertsOn() and "procAlertsOff" or nil end } },
    { action = "pulse", effect = { key = "pulse", client = true, anyFace = true, value = "color", fits = icons, draw = pulse,
        clear = clearFrame("pulse", function(f) if f.wash then Bridge.Pulse(f, f.wash, false) end end),
        shown = shownFrame("pulse") } },
    { action = "border", effect = { key = "border", client = true, anyFace = true, value = "color", fits = any, draw = border,
        clear = clearFrame("border"), shown = shownFrame("border") } },
    { action = "halo", effect = { key = "halo", client = true, anyFace = true, value = "color", fits = icons, draw = halo,
        clear = clearFrame("halo"), shown = shownFrame("halo") } },
    { action = "text", effect = { key = "text", client = true, anyFace = true, value = "text", fits = any, draw = text,
        clear = clearFrame("text"), shown = shownFrame("text") } },
    { action = "swap", effect = { key = "swap", client = true, value = "icon", fits = icons, draw = swap,
        clear = function(target)
            local c = Overlay.CopyOn(target, "swap")
            if c then c.frame:SetAlpha(0) end
        end,
        shown = function(target)
            local c = Overlay.CopyOn(target, "swap")
            return c and c.frame:GetAlpha() > 0 and c.frame or nil
        end } },
    { action = "fill", value = { "fill", cleanFill },
      effect = { key = "fill", client = true, anyFace = true, value = "fill", fits = fillFits, draw = fill,
        watch = FILL_WATCH, clear = clearFrame("fill", putOutFill),
        shown = function(target)
            local f = frameIf(target, "fill")
            local bar = f and f:IsShown() and barOf(f)
            return bar and bar:IsShown() and bar or nil
        end } },
}

if type(API) == "table" then
    for _, l in ipairs(Looks.LIST) do
        if not l.needs or l.needs() then
            if l.value then Conditions.RegisterValue(l.value[1], l.value[2]) end
            if Conditions.RegisterEffect(l.effect) then Conditions.RegisterLook(l.action, l.effect.key) end
        end
    end
end
