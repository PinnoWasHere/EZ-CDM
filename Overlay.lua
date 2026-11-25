local _, ns = ...

-- The "wash" effect for EZ-CDM's conditions (Conditions.lua), on Daylight UI's
-- API.Attach holder of the piece's frame, or on a line's layer when a client part
-- drives it. opts = { id, color } or { id, look = "desat" }: one look per id.
--   tint   a color laid over the icon at Daylight UI's wash strength, in and out
--          with API.Fade at its FAST speed. mana is Daylight UI's mana blue
--          (Style.PowerColor("MANA")).
--   desat  the gray: a desaturated copy of the piece's own icon (Bridge.PieceIcon)
--          with its texture, crop, color and masks, and Daylight UI's shade over
--          it. It sits at the icon's own frame level, so the swipe, the numbers
--          and the border stay on top. It shows and goes at once, as the game's
--          own gray does, and follows the icon as it swaps (SPELL_UPDATE_ICON).
-- The "glow" effect runs Daylight UI's glow (API.GlowAround) round the holder, or
-- round a line's layer, whose alpha a client part sets. Motion off keeps it away,
-- as Daylight UI's own glows.
-- The "sound" effect plays a sound line once as it turns on.

local Bridge, Conditions = ns.Bridge, ns.Conditions

local Overlay = {}
ns.Overlay = Overlay

-- Debug handle for an in-game check.
EZCDM_Overlay = Overlay

local API = _G.DaylightUI and _G.DaylightUI.API

-- Holder -> { [id] = texture }.
local washes = setmetatable({}, { __mode = "k" })

-- A color name -> r, g, b from Daylight UI, or nil.
Overlay.COLORS = {
    mana = function() return Bridge.ManaColor() end,
}

-- Target -> { [id] = { frame, tex, shade, masks, key } }: the gray copies.
local copies = setmetatable({}, { __mode = "k" })

local function secret(v) return type(issecretvalue) == "function" and issecretvalue(v) end

-- One mask of ours per mask on the icon: its file, laid where the icon's is.
local function copyMasks(c, icon)
    local n = type(icon.GetNumMaskTextures) == "function" and icon:GetNumMaskTextures() or 0
    if secret(n) then return end
    for i = 1, n do
        local m = icon:GetMaskTexture(i)
        local mine = c.masks[i]
        if not mine then
            mine = c.frame:CreateMaskTexture()
            c.masks[i] = mine
            c.tex:AddMaskTexture(mine)
            c.shade:AddMaskTexture(mine)
        end
        local file = m and m:GetTexture()
        if file ~= nil and not secret(file) then
            mine:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        end
        mine:ClearAllPoints()
        mine:SetAllPoints(m or icon)
    end
    for i = #c.masks, n + 1, -1 do
        c.tex:RemoveMaskTexture(c.masks[i])
        c.shade:RemoveMaskTexture(c.masks[i])
        c.masks[i] = nil
    end
end

-- Lays the copy on the piece's icon as it is now. Plain values only, so a secret
-- texture or crop keeps the last one. False when the piece has no icon.
local function follow(c)
    local frame = Conditions.FrameOf(c.key)
    local icon = frame and Bridge.PieceIcon(frame)
    if not icon then return false end
    local owner = icon:GetParent()
    if owner then
        c.frame:SetFrameStrata(owner:GetFrameStrata())
        local level = owner:GetFrameLevel()
        if type(level) == "number" and not secret(level) then c.frame:SetFrameLevel(level) end
    end
    c.tex:ClearAllPoints()
    c.tex:SetAllPoints(icon)
    local file = icon:GetTexture()
    if file ~= nil and not secret(file) then c.tex:SetTexture(file) end
    local coords = { icon:GetTexCoord() }
    if #coords > 0 and not secret(coords[1]) then c.tex:SetTexCoord(unpack(coords)) end
    local r, g, b, a = icon:GetVertexColor()
    if r ~= nil and not secret(r) then c.tex:SetVertexColor(r, g, b, a) end
    c.tex:SetDesaturated(true)
    copyMasks(c, icon)
    return true
end

-- The game's item swaps its icon on these (CooldownViewer.lua RefreshSpellTexture).
-- Each copy follows a frame later, once the item has.
local swaps = CreateFrame("Frame")
local listening = false
swaps:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        for _, set in pairs(copies) do
            for _, c in pairs(set) do follow(c) end
        end
    end)
end)

local function copyFor(target, id, key)
    local set = copies[target]
    if not set then
        set = {}
        copies[target] = set
    end
    local c = set[id]
    if not c then
        local f = CreateFrame("Frame", nil, target)
        f:SetAllPoints(target)
        f:SetAlpha(0)
        local tex = f:CreateTexture(nil, "ARTWORK")
        local shade = f:CreateTexture(nil, "ARTWORK", nil, 3)
        shade:SetAllPoints(tex)
        local file, alpha = Bridge.IconShade()
        if file then shade:SetTexture(file) end
        shade:SetVertexColor(0, 0, 0, alpha or 0)
        c = { frame = f, tex = tex, shade = shade, masks = {} }
        set[id] = c
        if not listening then
            listening = true
            swaps:RegisterEvent("SPELL_UPDATE_ICON")
            swaps:RegisterEvent("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED")
        end
    end
    c.key = key
    return c
end

-- The gray copy at full strength, or gone, at once, as the game's own gray.
local function gray(target, on, opts)
    local id = opts.id
    local c = on and opts.key ~= nil and copyFor(target, id, opts.key) or (copies[target] and copies[target][id])
    if not c then return end
    if on and not follow(c) then on = false end
    API.Fade(c.frame, on and 1 or 0, 0)
end

local function textureFor(holder, id)
    local set = washes[holder]
    if not set then
        set = {}
        washes[holder] = set
    end
    local t = set[id]
    if not t then
        t = holder:CreateTexture(nil, "OVERLAY")
        t:SetAllPoints(holder)
        t:SetAlpha(0)
        set[id] = t
    end
    return t
end

local function draw(holder, on, opts)
    local id = opts.id or opts.color
    if id == nil then return end
    if opts.look == "desat" then return gray(holder, on, opts) end
    local t = on and textureFor(holder, id) or (washes[holder] and washes[holder][id])
    if not t then return end
    if on then
        local color = Overlay.COLORS[opts.color]
        local r, g, b
        if color then r, g, b = color() end
        if r then t:SetColorTexture(r, g, b, 1) end
    end
    API.Fade(t, on and (Bridge.WashAlpha() or 0) or 0, "FAST")
end

local function clear(holder)
    for _, t in pairs(washes[holder] or {}) do API.Fade(t, 0, "FAST") end
    for _, c in pairs(copies[holder] or {}) do API.Fade(c.frame, 0, 0) end
end

-- For tests: a piece's wash textures by id, once drawn.
function Overlay.Washes(key)
    local frame = Conditions.FrameOf(key)
    local holder = frame and API.Attach(frame)
    return holder and washes[holder] or nil
end

-- For tests: a piece's gray copy on its holder ({ frame, tex, shade, masks }), once drawn.
function Overlay.Copy(key, id)
    local frame = Conditions.FrameOf(key)
    local holder = frame and API.Attach(frame)
    return holder and copies[holder] and copies[holder][id] or nil
end

-- What the gray shows on target, out of a fight (Conditions.Visible), or nil for a
-- tint:
--   copy  the copy is desaturated and on show
--   same  its texture and crop are the icon's
--   game  the piece's own icon is grayed by the game or Daylight UI
local function grayCheck(target, opts)
    if opts.look ~= "desat" then return nil end
    local c = copies[target] and copies[target][opts.id]
    local frame = Conditions.FrameOf(opts.key)
    local icon = frame and Bridge.PieceIcon(frame)
    local out = { copy = false, same = false }
    if icon then
        local d = icon:IsDesaturated()
        if not secret(d) then out.game = d == true end
    end
    if not c then return out end
    local a = c.frame:GetAlpha()
    out.copy = c.tex:IsDesaturated() == true and c.frame:IsVisible() == true and not secret(a) and a > 0
    if icon then
        local x, y = { c.tex:GetTexCoord() }, { icon:GetTexCoord() }
        local same = c.tex:GetTexture() == icon:GetTexture() and #x == #y
        for i = 1, #x do same = same and x[i] == y[i] end
        out.same = same
    end
    return out
end

if type(API) == "table" then
    Conditions.RegisterEffect({
        key = "wash",
        -- A wash covers an icon. It is alpha only, so a client part may drive it.
        fits = function(kind) return kind.shape == "icon" end,
        client = true,
        draw = draw,
        clear = clear,
        shown = function(target, opts)
            local id = opts.id or opts.color
            if opts.look == "desat" then
                local c = copies[target] and copies[target][id]
                return c and c.frame or nil
            end
            return washes[target] and washes[target][id] or nil
        end,
        check = grayCheck,
    })
    -- A glow round the icon in the line's color (the accent when none) and style (the
    -- piece's when none). Alpha only, so a client part may drive it.
    local glowing = setmetatable({}, { __mode = "k" })
    Conditions.RegisterEffect({
        key = "glow",
        client = true,
        draw = function(target, on, opts)
            local c = on and type(opts.value) == "table" and opts.value or nil
            API.GlowAround(target, on, { style = opts.style, r = c and c[1], g = c and c[2], b = c and c[3] })
            glowing[target] = on and true or nil
        end,
        clear = function(target)
            if glowing[target] then
                API.GlowAround(target, false)
                glowing[target] = nil
            end
        end,
        shown = function(target) return glowing[target] and target or nil end,
    })
    -- A sound line: Daylight UI's alert (opts.value, a Sound.AlertChoices key),
    -- played once as the line turns on.
    Conditions.RegisterEffect({
        key = "sound",
        edge = true,
        draw = function(_, on, opts)
            if on and type(opts.value) == "string" then Bridge.PlayAlert(opts.value) end
        end,
        clear = function() end,
    })
end
