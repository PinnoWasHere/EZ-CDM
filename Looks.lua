local _, ns = ...

-- EZ-CDM's looks: actions every condition's lines may end in (Conditions.RegisterLook),
-- each drawn with Daylight UI's own builders, art and measures on the piece's
-- API.Attach holder, or on a line's layer when a client part drives it.
--
-- Once, as the line turns on (edge). They move, so they are plain lines only, and
-- motion off in Daylight UI keeps them away, as it keeps its own:
--   flash    the wash texture (Skin.FLASH_ALPHA, the auto attack wash) in the line's
--            color, played by Motion.Flash
--   pop      a copy of the icon nudged by Motion.Bump at its own measures
--   shake    the same copy moved side to side on Motion.Tween, as Talents.Shake moves
--            a talent tile (Book/Talents.lua:412): SHAKE_PX, SHAKE_SWINGS, SLOW
--   sparkle  API.GlowAround's twinkle for one lap (Widgets.GLOW_LAP)
--   screen   Daylight UI's vignette art (portrait-vignette.png, as InstallerScreen.lua
--            lays it) over the whole screen in the color, in with API.Fade FAST, out SLOW
--
-- Held while the line is on. They are alpha only, so a client part may drive them:
--   pulse    the wash texture breathing on Daylight UI's own pulse driver
--            (CdmEffects.Flash, the empty bar's "flash it"); still with motion off
--   border   a lean Style.Shell outline, lit as the action bars' Border color does:
--            Style.LightShell in the accent, Style.SetShellColors in a color
--   halo     Style.AURA_HALO behind the piece, placed by Style.PlaceAuraHalo, the
--            light behind an aura button
--   text     the line's words in API.Text "small", in the accent (the look sheet's
--            "Count, badge, tag" row)
--   swap     a copy of the icon showing the picked icon in its place
--
-- A color look's value is its color (nil = the accent). No look runs an OnUpdate of
-- its own: Motion's shared tween driver, the glow's and the pulse's are Daylight UI's.

local Bridge, Conditions, Overlay = ns.Bridge, ns.Conditions, ns.Overlay

local Looks = {}
ns.Looks = Looks

-- Debug handle for an in-game check.
EZCDM_Looks = Looks

local API = _G.DaylightUI and _G.DaylightUI.API

-- Talents.Shake's sway: px at the start, half swings over its time.
Looks.SHAKE_PX = 3
Looks.SHAKE_SWINGS = 5
-- The glow style the sparkle plays once.
Looks.SPARKLE_STYLE = "twinkle"
-- The vignette Daylight UI lays over the screen (InstallerScreen.lua).
Looks.VIGNETTE = "portrait-vignette.png" -- look-ok: Daylight UI's own media, read through API.Media

local weak = { __mode = "k" }
local function secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end

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

-- The wash texture on f, in r, g, b at Daylight UI's wash strength.
local function wash(f, r, g, b)
    local t = f.wash
    if not t then
        t = f:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(f)
        f.wash = t
    end
    t:SetColorTexture(r, g, b, Bridge.WashAlpha() or 0)
    return t
end

local function icons(kind) return kind.shape == "icon" end
local function any() return true end

-- ---------------------------------------------------------------------
-- Once, as the line turns on
-- ---------------------------------------------------------------------

local function flash(target, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local f = frameOn(target, "flash")
    local t = wash(f, colorOf(opts))
    Bridge.Flash(t, speed("SLOW"))
    note(opts.key, "flash", t)
end

-- A copy of the piece's icon shown on target for dur seconds, then hidden.
local function copyFor(target, name, opts, dur)
    local c = Overlay.IconCopy(target, name, opts.key)
    if not c then return nil end
    c.gen = (c.gen or 0) + 1
    local gen = c.gen
    c.frame:SetAlpha(1)
    C_Timer.After(dur, function()
        if c.gen == gen then c.frame:SetAlpha(0) end
    end)
    return c
end

local function pop(target, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local c = copyFor(target, "pop", opts, speed("FAST"))
    if not c then return end
    Bridge.Bump(c.frame)
    note(opts.key, "pop", c.frame)
end

local function shake(target, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local c = copyFor(target, "shake", opts, speed("SLOW"))
    if not c then return end
    -- What the copy lies over: the icon, or its own frame where it stands in.
    local icon = c.over or c.frame
    local tex = c.tex
    local function at(dx)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", icon, "TOPLEFT", dx, 0)
        tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", dx, 0)
    end
    c.shakeKey = c.shakeKey or {}
    Bridge.Tween(c.shakeKey, 0, 1, speed("SLOW"), function(p)
        at(math.sin(p * math.pi * Looks.SHAKE_SWINGS) * Looks.SHAKE_PX * (1 - p))
    end, function() at(0) end)
    note(opts.key, "shake", c.frame)
end

local function sparkle(target, on, opts)
    if not on or not Bridge.MotionOn() then return end
    local f = frameOn(target, "sparkle")
    f.gen = (f.gen or 0) + 1
    local gen = f.gen
    local r, g, b = colorOf(opts)
    API.GlowAround(f, true, { style = Looks.SPARKLE_STYLE, r = r, g = g, b = b })
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
    local piece = Conditions.FrameOf(opts.key)
    if not f.tex then
        f.tex = f:CreateTexture(nil, "BACKGROUND", nil, -8)
        f.tex:SetBlendMode("ADD")
    end
    f.tex:SetTexture(Bridge.HaloArt())
    f.tex:SetVertexColor(colorOf(opts))
    if piece then
        -- Behind the piece, as the aura buttons' halo sits behind its button.
        local level = piece:GetFrameLevel()
        if type(level) == "number" and not secret(level) then f:SetFrameLevel(math.max(0, level - 1)) end
        local w = piece:GetWidth()
        if type(w) == "number" and not secret(w) and w > 0 then
            Bridge.PlaceHalo(f.tex, f, w)
        elseif not f.tex:GetPoint(1) then
            f.tex:SetAllPoints(f)
        end
    end
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

-- ---------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------

-- In the drawer's order: { action, effect fields }.
Looks.LIST = {
    { action = "flash", effect = { key = "flash", edge = true, value = "color", fits = icons, draw = flash,
        clear = clearFrame("flash") } },
    { action = "pop", effect = { key = "pop", edge = true, fits = icons, draw = pop,
        clear = function(target)
            local c = Overlay.CopyOn(target, "pop")
            if c then c.frame:SetAlpha(0) end
        end } },
    { action = "shake", effect = { key = "shake", edge = true, fits = icons, draw = shake,
        clear = function(target)
            local c = Overlay.CopyOn(target, "shake")
            if c then c.frame:SetAlpha(0) end
        end } },
    { action = "sparkle", effect = { key = "sparkle", edge = true, value = "color", fits = any, draw = sparkle,
        clear = function(target)
            local f = frameIf(target, "sparkle")
            if f then
                f.gen = (f.gen or 0) + 1
                API.GlowAround(f, false)
            end
        end } },
    { action = "screen", effect = { key = "screen", edge = true, value = "color", fits = any, draw = screen,
        clear = function() end } },
    { action = "pulse", effect = { key = "pulse", client = true, value = "color", fits = icons, draw = pulse,
        clear = clearFrame("pulse", function(f) if f.wash then Bridge.Pulse(f, f.wash, false) end end),
        shown = shownFrame("pulse") } },
    { action = "border", effect = { key = "border", client = true, value = "color", fits = any, draw = border,
        clear = clearFrame("border"), shown = shownFrame("border") } },
    { action = "halo", effect = { key = "halo", client = true, value = "color", fits = icons, draw = halo,
        clear = clearFrame("halo"), shown = shownFrame("halo") } },
    { action = "text", effect = { key = "text", client = true, value = "text", fits = any, draw = text,
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
}

if type(API) == "table" then
    for _, l in ipairs(Looks.LIST) do
        if Conditions.RegisterEffect(l.effect) then Conditions.RegisterLook(l.action, l.effect.key) end
    end
end
