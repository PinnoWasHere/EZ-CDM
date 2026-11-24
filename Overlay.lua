local _, ns = ...

-- The "wash" effect for EZ-CDM's conditions (Conditions.lua): a color laid over the
-- piece's icon on Daylight UI's API.Attach holder, at Daylight UI's wash strength,
-- fading with API.Fade at Daylight UI's FAST speed. Colors come from Daylight UI:
--   OFF    API.Colors().OFF, its "truly unavailable" gray
--   mana   its mana blue (Style.PowerColor("MANA"))
-- opts = { id, color }: one texture per id on each holder.

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
    OFF = function()
        local c = API.Colors().OFF
        if c then return c[1], c[2], c[3] end
    end,
    mana = function() return Bridge.ManaColor() end,
}

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
end

-- For tests: a piece's wash textures by id, once drawn.
function Overlay.Washes(key)
    local frame = Conditions.FrameOf(key)
    local holder = frame and API.Attach(frame)
    return holder and washes[holder] or nil
end

if type(API) == "table" then
    Conditions.RegisterEffect({
        key = "wash",
        -- A wash covers an icon.
        fits = function(kind) return kind.shape == "icon" end,
        draw = draw,
        clear = clear,
    })
end
