local _, ns = ...

-- "While it's active, glow" for a piece Daylight UI's aura icon holder draws. In a
-- fight nothing tells addon code the buff is up, but the client shows its aura
-- button then. So EZ-CDM builds Daylight UI's ring inside that button while the
-- client makes it, and hands the ring's loop to the button (AddAuraShownAnimation).
-- The client then shows and plays it with the buff, and no addon code runs.
--
-- The rule lives in EZCDMDB.upGlow[profile][key]: true for the accent, or a color.
-- Daylight UI's own upGlow stays off on such a piece, so the two never stack. A
-- piece the game's item draws keeps Daylight UI's upGlow. Draft reads and writes
-- the rule through Effects.Merge and Effects.Split.
--
-- The client takes a button's animations only while it makes the button, and then
-- the button and its children answer secrets (IsShown, IsVisible, GetWidth,
-- GetHeight, IsPlaying), so Daylight UI's own SetGlow can't run there. EZ-CDM
-- builds the ring itself from Daylight UI's art and measures, setting only. A ring
-- is built once, in the color the rule has then, and only turned off later. A new
-- or recolored rule lights from the next /reload (Effects.Pending).

local Bridge = ns.Bridge

local Effects = {}
ns.Effects = Effects

-- Debug handle for an in-game check.
EZCDM_Effects = Effects

-- What draws a piece whose up glow EZ-CDM builds (Bridge.DrawnBy).
Effects.DRAWN = { ["aura icon"] = true, ["aura and cooldown icon"] = true }

local weak = { __mode = "k" }
-- Client button -> { key, frame, tex, anim, color } for each ring handed over and still on.
local rings = setmetatable({}, weak)
-- Buttons the hook has seen since load.
local seen = 0

-- ---------------------------------------------------------------------
-- The rule
-- ---------------------------------------------------------------------

local function isRGB(c)
    return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number"
end

-- The rule's value as saved: true for the accent, or a copy of the color.
local function clean(v)
    if isRGB(v) then return { v[1], v[2], v[3] } end
    if v == true then return true end
    return nil
end

local function store()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.upGlow) ~= "table" then EZCDMDB.upGlow = {} end
    return EZCDMDB.upGlow
end

-- A piece's rule on talent set g's profile (current when nil): true, a color, or nil.
function Effects.Get(key, g)
    local profile = Bridge.ProfileOf(g)
    local byKey = profile ~= nil and store()[profile]
    return type(byKey) == "table" and clean(byKey[key]) or nil
end

-- Sets or clears a piece's rule on talent set g's profile, made first if it has
-- none. Refused in combat and while EZ-CDM is off (Bridge write reasons).
function Effects.Set(g, key, value)
    local profile, why = Bridge.SavedProfile(g)
    if not profile then return false, why end
    local all = store()
    all[profile] = all[profile] or {}
    all[profile][key] = clean(value)
    if next(all[profile]) == nil then all[profile] = nil end
    Effects.Sync()
    return true
end

-- Whether EZ-CDM draws the piece's up glow: an aura icon holder draws it.
function Effects.Drawn(key) return Effects.DRAWN[Bridge.DrawnBy(key) or ""] == true end

local function sameColor(a, b)
    if a == true or b == true then return a == b end
    return isRGB(a) and isRGB(b) and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- ---------------------------------------------------------------------
-- Draft's one place
-- ---------------------------------------------------------------------

-- Before Grammar.Decompile: a piece's saved fields with EZ-CDM's rule in
-- Daylight UI's words (upGlow, upGlowColor), so it reads back as one line.
function Effects.Merge(key, fields, g)
    local v = Effects.Get(key, g)
    if v == nil then return fields end
    fields.upGlow = true
    fields.upGlowColor = isRGB(v) and { v[1], v[2], v[3] } or nil
    return fields
end

-- After Grammar.Compile: takes "glow while active" out of fields for a piece
-- EZ-CDM draws, so Daylight UI's upGlow is written off. Returns the rule's new
-- value for Effects.Set (nil clears it). A game-drawn piece keeps its fields and
-- gets nil, so a rule left from an earlier shape is cleared.
function Effects.Split(key, fields)
    if not Effects.Drawn(key) then return nil end
    local v
    if fields.upGlow == true then v = isRGB(fields.upGlowColor) and clean(fields.upGlowColor) or true end
    fields.upGlow, fields.upGlowColor = nil, nil
    return v
end

-- ---------------------------------------------------------------------
-- The ring inside the client's button
-- ---------------------------------------------------------------------

-- Daylight UI's ring on a square icon (CdmEffects.lua:199-274): the game's proc
-- loop art, gray so the color tints true, reaching past each edge by pad times
-- the side, turned by a looping flipbook. size is the button's side as Daylight UI
-- set it, so nothing here asks the button. The texture sits two frames deep, as
-- Daylight UI's does, so it draws over the button's cooldown.
local function buildRing(btn, size, color)
    local art = Bridge.RingArt()
    if not art then return nil end
    local pad = size * art.pad
    local frame = CreateFrame("Frame", nil, btn)
    frame:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
    frame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(holder)
    tex:SetAtlas(art.atlas)
    tex:SetDesaturated(true)
    if color then
        tex:SetVertexColor(color[1], color[2], color[3], 1)
    else
        Bridge.PaintAccent(tex)
    end
    local anim = frame:CreateAnimationGroup()   -- look-ok: Daylight UI's ring flipbook, its constants via the Bridge
    anim:SetLooping("REPEAT")
    local fb = anim:CreateAnimation("FlipBook")
    fb:SetTarget(tex)
    fb:SetDuration(art.loop)
    fb:SetFlipBookRows(art.rows)
    fb:SetFlipBookColumns(art.columns)
    fb:SetFlipBookFrames(art.frames)
    fb:SetFlipBookFrameWidth(0)
    fb:SetFlipBookFrameHeight(0)
    return { frame = frame, tex = tex, anim = anim }
end

-- Inside initializeFrame (Bridge.HookAuraButtons). It only makes and sets things,
-- and tests nothing the button or its children report. A holder made under
-- restrictions waits for a /reload out of a fight, since its button locks as soon
-- as this returns.
local function onButton(btn, key, size)
    seen = seen + 1
    local want = Effects.Get(key)
    if want == nil or size == nil or Bridge.Restricted() then return end
    if type(btn.AddAuraShownAnimation) ~= "function" then return end
    local r = buildRing(btn, size, isRGB(want) and want or nil)
    if not r then return end
    btn:AddAuraShownAnimation(r.anim)
    r.key, r.color = key, want
    rings[btn] = r
end

-- Takes a ring out of its button: hidden, stopped and out of the client's list,
-- so it never plays again. Out of restrictions only.
local function unhand(btn, r)
    rings[btn] = nil
    r.frame:Hide()
    r.anim:Stop()
    btn:RemoveAuraShownAnimation(r.anim)
end

local function sync()
    for btn, r in pairs(rings) do
        if Effects.Get(r.key) == nil then unhand(btn, r) end
    end
end

-- Turns off every ring whose rule is gone (a removed line, another profile).
-- Waits for restrictions to lift.
function Effects.Sync() Bridge.AfterRestrictions(sync, "ezcdm:effects:sync") end

-- Whether a ring for the piece is in a client button now, and in which color.
function Effects.Lit(key)
    for _, r in pairs(rings) do
        if r.key == key then return true, r.color end
    end
    return false
end

-- Whether the piece's rule has no ring in that color yet: it lights after /reload.
function Effects.Pending(key)
    local want = Effects.Get(key)
    if want == nil or not Effects.Drawn(key) then return false end
    local lit, color = Effects.Lit(key)
    return not (lit and sameColor(color, want))
end

-- For tests: client buttons the hook has seen, and the ring on btn ({ key, frame,
-- tex, anim, color }) or nil.
function Effects.Seen() return seen end
function Effects.Ring(btn) return rings[btn] end

-- In place before Daylight UI makes any holder button: its modules start at
-- PLAYER_LOGIN, and the .toc's OptionalDeps loads its action bars first.
Effects.hooked = Bridge.HookAuraButtons(onButton) and true or false

-- Another profile (a talent set switch, or one picked in the editor) takes the
-- old one's rings off.
local events = CreateFrame("Frame")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:SetScript("OnEvent", function() Effects.Sync() end)

local API = _G.DaylightUI and _G.DaylightUI.API
if type(API) == "table" and type(API.On) == "function" then
    API.On("Login", function()
        if Bridge.Ready() then Bridge.HookEditor("Draw", function() Effects.Sync() end) end
    end, "EZ-CDM")
end
