local _, ns = ...

-- "While it's active, glow" for a piece Daylight UI's aura icon holder draws. In a
-- fight nothing tells addon code the buff is up, but the client shows its aura
-- button then. So EZ-CDM builds Daylight UI's ring inside that button while the
-- client makes it, and hands the ring's loop to the button (AddAuraShownAnimation).
-- The client then shows and plays it with the buff, and no addon code runs.
--
-- The rule lives in EZCDMDB.upGlow[profile][key]: true for the accent, or a color.
-- Daylight UI's own upGlow stays off on such a piece, so the two never stack. A
-- piece the game's item draws keeps Daylight UI's upGlow, and so does a piece
-- Daylight UI draws on its own face, with no client button (Effects.Drawn). When
-- what draws a piece changes, Effects.MoveBack hands the rule over. Draft reads
-- and writes the rule through Effects.Merge and Effects.Split.
--
-- While the client makes a button, the button and its children answer secrets
-- (IsShown, IsVisible, GetWidth, GetHeight, IsPlaying), so Daylight UI's own
-- SetGlow can't run there. EZ-CDM builds the ring itself from Daylight UI's art and
-- measures, setting only. Later the client locks the button only while auras are
-- secret (DenyTaintedAccessWhenAurasAreSecret), so out of that a new rule builds
-- and hands over a ring on each button the hook has seen, and a new color repaints
-- the ring in place. A rule the client still won't take waits for a /reload
-- (Effects.Pending), and the editor asks for one as it closes (Effects.AskReload).
--
-- The fall-off lead and its sound ride on Daylight UI's recast clock (below). A
-- proc the aura icon holder draws gets no fall-off lead, since its aura can't be
-- read in a fight. A glow style per moment rides on Daylight UI's own glows (below).

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
-- Piece key -> { [client button] = its side in px } for every button the hook has seen.
local buttonsOf = {}
-- Client buttons that refused a ring handed over later. Tried again after a /reload.
local refused = setmetatable({}, weak)
-- Whether a rule changed since the rings last matched every rule (Effects.ReloadDue).
local changed = false

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
    changed = true
    Effects.Sync()
    return true
end

-- Whether EZ-CDM draws the piece's up glow: an aura icon holder draws it in the
-- client's own buttons. The pet, a weapon enchant, a summon and a debuff on you are
-- on Daylight UI's own face, so their up glow stays Daylight UI's.
function Effects.Drawn(key)
    return Effects.DRAWN[Bridge.DrawnBy(key) or ""] == true and Bridge.ClientButtons(key) == true
end

local function sameColor(a, b)
    if a == true or b == true then return a == b end
    return isRGB(a) and isRGB(b) and a[1] == b[1] and a[2] == b[2] and a[3] == b[3]
end

-- ---------------------------------------------------------------------
-- Draft's one place
-- ---------------------------------------------------------------------

-- Before Grammar.Decompile: a piece's saved fields with EZ-CDM's rules in the
-- grammar's words (upGlow and upGlowColor, ezLead and ezSound, ezStyles), so each
-- reads back as its line.
function Effects.Merge(key, fields, g)
    local fo = Effects.FallOff(key, g)
    if fo then fields.ezLead, fields.ezSound = fo.lead, fo.sound end
    fields.ezStyles = Effects.Styles(key, g)
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

-- Daylight UI's ring on a square icon (CdmEffects.lua:208-283): the game's proc
-- loop art, gray so the color tints true, reaching past each edge by pad times
-- the side, turned by a looping flipbook. size is the button's side as Daylight UI
-- set it, so nothing here asks the button. The texture sits two frames deep, as
-- Daylight UI's does, so it draws over the button's cooldown.
local function ringFrames(btn, size, art)
    local pad = size * art.pad
    local frame = CreateFrame("Frame", nil, btn)
    frame:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
    frame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    return frame, holder
end

-- The rule's color, or the accent as Daylight UI paints its ring (paintGlow,
-- CdmEffects.lua:287-304).
local function paint(tex, color)
    if color then
        tex:SetVertexColor(color[1], color[2], color[3], 1)
    else
        Bridge.PaintAccent(tex)
    end
end

-- The ring's texture on holder and its looping flipbook on frame.
local function ringArt(frame, holder, art, color)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(holder)
    tex:SetAtlas(art.atlas)
    tex:SetDesaturated(true)
    paint(tex, color)
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
    return tex, anim
end

local function buildRing(btn, size, color)
    local art = Bridge.RingArt()
    if not art then return nil end
    local frame, holder = ringFrames(btn, size, art)
    local tex, anim = ringArt(frame, holder, art, color)
    return { frame = frame, tex = tex, anim = anim }
end

local function colorOf(v) return isRGB(v) and v or nil end

-- Inside initializeFrame (Bridge.HookAuraButtons). It only makes and sets things,
-- and tests nothing the button or its children report. A button made under
-- restrictions locks as soon as this returns, so it gets its ring once they lift.
local function onButton(btn, key, size)
    seen = seen + 1
    if size == nil then return end
    buttonsOf[key] = buttonsOf[key] or setmetatable({}, weak)
    buttonsOf[key][btn] = size
    if Bridge.Restricted() then
        Effects.Sync()
        return
    end
    if type(btn.AddAuraShownAnimation) ~= "function" then return end
    local want = Effects.Get(key)
    if want == nil then return end
    local r = buildRing(btn, size, colorOf(want))
    if not r then return end
    btn:AddAuraShownAnimation(r.anim)
    r.key, r.color = key, want
    rings[btn] = r
end

-- Takes a ring out of its button: hidden, stopped and out of the client's list,
-- so it never plays again. Out of restrictions only.
local function unhand(btn, r)
    r.frame:Hide()
    r.anim:Stop()
    btn:RemoveAuraShownAnimation(r.anim)
end

-- A ring on a button the client made earlier, handed over out of restrictions.
-- The loop starts at once, since a button already up plays no shown moment until
-- its next aura; on a hidden button nothing shows. A button that refuses keeps
-- the rule waiting for a /reload, and its frame stays hidden.
local function handLate(btn, key, size, want)
    local r = buildRing(btn, size, colorOf(want))
    if not r then return end
    if not Bridge.SafeCall(btn.AddAuraShownAnimation, btn, r.anim) then
        r.frame:Hide()
        refused[btn] = true
        return
    end
    r.anim:Play()
    r.key, r.color = key, want
    rings[btn] = r
end

local function sync()
    for btn, r in pairs(rings) do
        if Effects.Get(r.key) == nil then
            rings[btn] = nil
            unhand(btn, r)
        end
    end
    if Bridge.AurasSecret() then return end
    for _, r in pairs(rings) do
        local want = Effects.Get(r.key)
        if not sameColor(r.color, want) then
            paint(r.tex, colorOf(want))
            r.color = want
        end
    end
    for key, set in pairs(buttonsOf) do
        local want = Effects.Get(key)
        if want ~= nil and Effects.Drawn(key) then
            for btn, size in pairs(set) do
                if rings[btn] == nil and not refused[btn] then handLate(btn, key, size, want) end
            end
        end
    end
end

-- Matches every ring to its rule: off where the rule is gone (a removed line,
-- another profile), repainted in a new color, and built on a button that has none.
-- Waits for restrictions to lift.
function Effects.Sync() Bridge.AfterRestrictions(sync, "ezcdm:effects:sync") end

-- Whether a rule's up glow may need to change hands (Effects.MoveBack).
local moveDue = true

-- Writes Daylight UI's upGlow for a piece: on in the rule's color, or off. An accent
-- rule clears an old color where the setter takes nil (API 1.15).
local function daylightGlow(g, p, key, v)
    if v == nil then
        if p.upGlow ~= true then return true end
        return Bridge.SetSpellValue(g, key, "upGlow", false)
    end
    local ok = p.upGlow == true or Bridge.SetSpellValue(g, key, "upGlow", true)
    if ok and isRGB(v) and not sameColor(p.upGlowColor, v) then
        ok = Bridge.SetSpellValue(g, key, "upGlowColor", { v[1], v[2], v[3] })
    elseif ok and not isRGB(v) and p.upGlowColor ~= nil and Bridge.GlowResets() then
        ok = Bridge.SetSpellValue(g, key, "upGlowColor", nil)
    end
    return ok
end

-- Hands each up glow rule to whatever draws its piece now. A client aura button
-- takes EZ-CDM's ring, and Daylight UI's upGlow stays off. On Daylight UI's own
-- face the rule goes to its upGlow, in its color, and EZ-CDM's rule is cleared.
-- Anything else (the game's item, a stand-in, a bar) lights Daylight UI's upGlow
-- and keeps the rule, so the ring comes back if a holder draws the piece again.
-- The game's item can draw a piece only for a moment, as at login before a
-- viewer hides. Only the current profile's placed pieces; a piece the last pass
-- didn't draw stays, and a holder that can't say yet waits for a later pass.
-- Out of restrictions only, since it writes the layout.
function Effects.MoveBack()
    if Bridge.Restricted() then return end
    local g = Bridge.CurrentIndex()
    local profile = Bridge.ProfileOf(g)
    local byKey = profile ~= nil and store()[profile]
    local set = Bridge.Layout(g)
    local pieces = type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}
    local due = false
    for key, v in pairs(type(byKey) == "table" and byKey or {}) do
        local p = pieces[key]
        local by = p ~= nil and Bridge.DrawnBy(key) or nil
        if by ~= nil then
            local client
            if Effects.DRAWN[by] then client = Bridge.ClientButtons(key) end
            if client == true then
                daylightGlow(g, p, key, nil)
                due = true
            elseif client == false then
                if daylightGlow(g, p, key, clean(v)) then Effects.Set(g, key, nil) else due = true end
            elseif Effects.DRAWN[by] then
                due = true
            else
                daylightGlow(g, p, key, clean(v))
                due = true
            end
        end
    end
    moveDue = due
end

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

-- Whether a rule changed since the rings last matched, and some rule of the current
-- profile still waits for a /reload. Cheap while nothing changed.
function Effects.ReloadDue()
    if not changed then return false end
    local profile = Bridge.ProfileOf()
    local byKey = profile ~= nil and store()[profile]
    for key in pairs(type(byKey) == "table" and byKey or {}) do
        if Effects.Pending(key) then return true end
    end
    changed = false
    return false
end

-- Asks for a /reload in Daylight UI's question box when a ring waits for one.
-- Out of restrictions only. "Later" keeps quiet until another rule changes.
-- Returns whether it asked.
function Effects.AskReload()
    if Bridge.Restricted() or not Effects.ReloadDue() then return false end
    local W = ns.Grammar and ns.Grammar.WORDING or {}
    Bridge.AskReload("ezcdm:reload", W.reloadAsk, _G.RELOADUI or W.reloadYes, _G.LATER or W.reloadLater,
        function() changed = false end)
    return true
end

-- For tests: client buttons the hook has seen, and the ring on btn ({ key, frame,
-- tex, anim, color }) or nil.
function Effects.Seen() return seen end
function Effects.Ring(btn) return rings[btn] end

-- ---------------------------------------------------------------------
-- The fall-off lead and its sound
-- ---------------------------------------------------------------------

-- "When it's about to fall off (N seconds before)" on Daylight UI's recast clock.
-- The end comes from Daylight UI's buff moments where they come (below: the buff
-- landing), else from your own cast (CdmAuras.lua:1237-1254), which Daylight UI
-- keeps in h.endsAt, a plain number. A wrap on ClipDue moves its due moment to N
-- seconds before that end, so Daylight UI lights its own recast glow then, in its
-- own color, style and priority, and its own timer wakes for it. A wrap on Clip
-- hears the moment come and plays the sound once. A wrap on ClipGlows keeps the
-- clock running for a sound with no glow; Daylight UI's glow checks its own
-- clipGlow, so none shows. A wrap on Told holds the game's "down" while the clock
-- is trusted, and the SetDown wrap hands that on. No per-frame driver of EZ-CDM's
-- own; a drop's grace is one timer.
--
-- The rule lives in EZCDMDB.fallOff[profile][key] = { lead = N, sound = key }.
-- Without one, Daylight UI's own timing stands. Draft reads and writes it through
-- Effects.Merge and Effects.SplitFallOff.

local function fallOffStore()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.fallOff) ~= "table" then EZCDMDB.fallOff = {} end
    return EZCDMDB.fallOff
end

-- The rule as saved: a positive lead, a sound key other than "none", or nil. A
-- rule with a ring is an earlier build's proc fall-off ring, which is gone.
local function cleanFallOff(v)
    if type(v) ~= "table" or v.ring ~= nil then return nil end
    local lead = type(v.lead) == "number" and v.lead > 0 and v.lead or nil
    local sound = type(v.sound) == "string" and v.sound ~= "none" and v.sound or nil
    if lead == nil and sound == nil then return nil end
    return { lead = lead, sound = sound }
end

-- Drops the rules an earlier build saved for a proc's fall-off ring, and the proc
-- lengths it kept for them. Daylight UI's clipGlow stays as it is.
local function dropProcRings()
    if type(EZCDMDB) ~= "table" then return end
    EZCDMDB.procLasts = nil
    if type(EZCDMDB.fallOff) ~= "table" then return end
    for profile, byKey in pairs(EZCDMDB.fallOff) do
        if type(byKey) == "table" then
            for key, rule in pairs(byKey) do
                if type(rule) == "table" and rule.ring ~= nil then byKey[key] = nil end
            end
            if next(byKey) == nil then EZCDMDB.fallOff[profile] = nil end
        end
    end
end

-- A piece's fall-off rule on talent set g's profile (current when nil):
-- { lead, sound }, either of them nil, or nil for none.
function Effects.FallOff(key, g)
    local profile = Bridge.ProfileOf(g)
    local byKey = profile ~= nil and fallOffStore()[profile]
    return type(byKey) == "table" and cleanFallOff(byKey[key]) or nil
end

-- Sets or clears a piece's fall-off rule, as Effects.Set does the up glow's.
function Effects.SetFallOff(g, key, rule)
    local profile, why = Bridge.SavedProfile(g)
    if not profile then return false, why end
    local all = fallOffStore()
    all[profile] = all[profile] or {}
    all[profile][key] = cleanFallOff(rule)
    if next(all[profile]) == nil then all[profile] = nil end
    Effects.Sync()
    return true
end

-- After Grammar.Compile: takes the lead and the sound (ezLead, ezSound) out of
-- fields, which Daylight UI never sees. Returns the rule for Effects.SetFallOff.
function Effects.SplitFallOff(fields)
    local rule = cleanFallOff({ lead = fields.ezLead, sound = fields.ezSound })
    fields.ezLead, fields.ezSound = nil, nil
    return rule
end

-- The current profile's rule for a holder or watch the clock passes in.
local function ruleOf(h)
    local key = type(h) == "table" and h.id or nil
    if key == nil then return nil end
    return Effects.FallOff(key)
end

-- ---------------------------------------------------------------------
-- The fall-off clock on Daylight UI's buff moments (API 1.14)
-- ---------------------------------------------------------------------

-- Daylight UI fires CooldownBuffUp and CooldownBuffDown after a pass in which a
-- piece's plain "down" changed (Fx.BuffMoment). It is the same "down" the pass hands
-- Told, so the events add the moment it changed. A piece they come for times its
-- fall-off from when the buff lands, not from your cast:
--   up      the clock runs from now for the buff's length
--   down    with no up inside DOWN_GRACE, the clock stops and a pass puts the glow out
--   recast  up stays up and nothing fires, so Daylight UI's cast clock moving later
--           is the refresh
-- An up inside the grace is the same buff read again and keeps its end. An up just
-- after a target change is a debuff seen again, so it starts no clock of its own.
-- A piece no event comes for keeps the cast clock.

-- Seconds a "down" waits for an up before the clock stops.
Effects.DOWN_GRACE = 1
-- Seconds after a target change in which an up is the old debuff seen again
-- (Daylight UI's END_QUIET, CdmEffects.lua:726 at 2.2.4).
Effects.SWAP_QUIET = 0.5

-- Piece key as a string -> { up, ends, upAt, downAt, token }. ends is set only by an
-- up that started a clock.
local moments = {}
-- Piece key as a string -> the watch or holder the clock last passed in.
local clockOf = setmetatable({}, { __mode = "v" })
local targetAt = -math.huge

local function remember(h) clockOf[tostring(h.id)] = h end

-- The layout's own key for a key as a string.
local function keyFrom(k)
    local h = clockOf[k]
    if h then return h.id end
    local set = Bridge.Layout()
    for key in pairs(type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}) do
        if tostring(key) == k then return key end
    end
end

local function plainSeconds(v)
    if type(v) ~= "number" or (type(issecretvalue) == "function" and issecretvalue(v)) then return nil end
    return v > 0 and v or nil
end

-- The buff's length, as Daylight UI's cast clock takes it (CdmAuras.lua:1168-1173):
-- the length the watch or holder last read, else the holder's, else the game's data.
local function lengthOf(key, h)
    return plainSeconds(type(h) == "table" and h.auraLasts or nil) or Bridge.AuraLasts(key) or Bridge.FactLasts(key)
end

-- The end the fall-off times from, and which route set it: "events" when an up
-- started the clock, else "cast" (Daylight UI's own clock, h.endsAt).
local function endOf(h)
    local m = moments[tostring(h.id)]
    if m and m.ends then
        local cast = h.endsAt
        if type(cast) == "number" and cast > m.ends + 1 then m.ends = cast end
        return m.ends, "events"
    end
    return h.endsAt, "cast"
end

local function momentFor(k)
    local m = moments[k]
    if not m then
        m = { token = 0 }
        moments[k] = m
    end
    return m
end

local function ruledKey(k)
    local key = keyFrom(k)
    return key ~= nil and Effects.FallOff(key) ~= nil
end

local function onUp(_, key)
    if key == nil then return end
    local k = tostring(key)
    local m = momentFor(k)
    local now = GetTime()
    local blip = m.downAt ~= nil and now - m.downAt < Effects.DOWN_GRACE and m.ends ~= nil and m.ends > now
    m.up, m.downAt, m.token = true, nil, m.token + 1
    if not blip then
        local lasts = now - targetAt >= Effects.SWAP_QUIET and lengthOf(keyFrom(k), clockOf[k]) or nil
        m.ends = lasts and now + lasts or nil
        m.upAt = now
    end
    if ruledKey(k) then Bridge.Refresh() end
end

local function onDown(_, key)
    if key == nil then return end
    local k = tostring(key)
    local m = momentFor(k)
    m.up, m.downAt, m.token = false, GetTime(), m.token + 1
    local token = m.token
    local function stop()
        if m.token ~= token or m.up then return end
        local left = m.downAt + Effects.DOWN_GRACE - GetTime()
        if left > 0.01 then
            C_Timer.After(left, stop)
            return
        end
        m.ends, m.upAt, m.downAt = nil, nil, nil
        if ruledKey(k) then Bridge.Refresh() end
    end
    C_Timer.After(Effects.DOWN_GRACE, stop)
end

-- Whether Daylight UI's buff moments time this piece's fall-off: one came for it this
-- session, or its state reads up or down now (API.CooldownState).
function Effects.Covered(key)
    if key == nil then return false end
    if moments[tostring(key)] ~= nil then return true end
    return Bridge.BuffState(key) ~= nil
end

-- Which clock times the piece's fall-off now: "events" or "cast".
function Effects.Route(key)
    local m = key ~= nil and moments[tostring(key)] or nil
    return m and m.ends and "events" or "cast"
end

-- For tests and the dev addon: the end the events route keeps for a piece, or nil.
function Effects.EventEnds(key)
    local m = key ~= nil and moments[tostring(key)] or nil
    return m and m.ends or nil
end

-- When a piece's own buff ends and how long it lasts, both plain, or nil while it
-- isn't clocked: the end Daylight UI's buff moments started (a later recast moves it,
-- as the fall-off clock reads it), else the end Daylight UI's own cast clock keeps on
-- the piece's holder or watch (h.endsAt). The fill's time left (Looks.lua).
function Effects.BuffClock(key)
    if key == nil then return nil end
    local k = tostring(key)
    local now = GetTime()
    local h = clockOf[k] or Bridge.AuraHolder(key)
    local m = moments[k]
    local ends
    if m and m.up and m.ends then
        ends = m.ends
        local cast = type(h) == "table" and plainSeconds(h.endsAt) or nil
        if cast and cast > ends + 1 then ends = cast end
    elseif type(h) == "table" then
        ends = plainSeconds(h.endsAt)
    end
    if not ends or ends <= now then return nil end
    local lasts = lengthOf(keyFrom(k) or key, h)
    if not lasts then return nil end
    return ends, lasts
end

Effects.heard = Bridge.OnBuff(onUp, onDown)

-- Around CdmAuras.ClipDue. Daylight UI's own "due" stands. On the cast clock, so
-- does a "not due" with no time (no clock, or the recast already being cast).
-- Otherwise the moment comes N seconds before the end, or Daylight UI's own when
-- that is sooner. On the events route a "not due" with no time is the recast
-- being cast only while Daylight UI's own clock runs.
local function clipDue(orig, h, sid)
    local due, at = orig(h, sid)
    if due then return due, at end
    local rule = ruleOf(h)
    if not (rule and rule.lead) then return due, at end
    remember(h)
    local ends, route = endOf(h)
    if type(ends) ~= "number" then return due, at end
    local now = GetTime()
    if route == "events" then
        if not at and type(h.endsAt) == "number" and h.endsAt > now then return due, at end
        if ends <= now then return false end
    elseif not at then
        return due, at
    end
    local soon = ends - rule.lead
    if soon <= now then return true end
    return false, at and math.min(at, soon) or soon
end

-- piece key -> the end its sound last played for. One end, one sound: a pass that
-- asks again, or a second holder of the same piece, plays nothing more. A recast
-- moves the end later and re-arms it. An end that moves a second or less is the
-- same cast, read again (Daylight UI's own test for a new application,
-- CdmAuras.lua:1054).
local heardFor = {}

-- Around CdmAuras.Clip: the pass's answer, unchanged.
local function clip(orig, h, sid)
    local due = orig(h, sid)
    if due ~= true then return due end
    local rule = ruleOf(h)
    local ends = type(h) == "table" and endOf(h) or nil
    if not (rule and rule.sound) or type(ends) ~= "number" then return due end
    local was = heardFor[h.id]
    if was == nil or ends > was + 1 then
        heardFor[h.id] = ends
        Bridge.PlayAlert(rule.sound)
    end
    return due
end

-- Saved piece table -> its key, for ClipGlows, which gets only the table.
local keyOf = setmetatable({}, weak)

local function pieceKey(p)
    local k = keyOf[p]
    if k ~= nil then return k end
    local set = Bridge.Layout()
    for key, t in pairs(type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}) do
        if type(t) == "table" then keyOf[t] = key end
    end
    return keyOf[p]
end

-- Around CdmEffects.ClipGlows: also true for a piece with a fall-off sound.
local function clipGlows(orig, p)
    local on = orig(p)
    if on or type(p) ~= "table" then return on end
    local key = pieceKey(p)
    local rule = key ~= nil and Effects.FallOff(key) or nil
    if rule and rule.sound then return true end
    return on
end

-- Piece key -> { due } for each "down" this pass held: the clock's answer, which
-- the SetDown wrap hands on. Emptied as the pass ends.
local heldNow = {}

-- Around CdmAuras.Told. Daylight UI drops the clock on a "down" (CdmAuras.lua:1413)
-- and the pass skips Clip (CdmRows.lua:628, 887), so a held "down" is told as
-- "can't tell" and the clock is asked as the pass would. On a piece with a fall-off
-- rule:
--   events route  a "down" is held while the buff moments say up, or for the grace
--                 after their down. The pass tells the down before the moment fires.
--   cast route    the game's item says "down" while the aura is up before your
--                 debuff lands, so a "down" is held until the cast clock's end.
-- Your recast still moves the end. After the end, the "down" stands.
local function told(orig, h, up)
    if type(h) ~= "table" or up ~= false or ruleOf(h) == nil then return orig(h, up) end
    remember(h)
    local now = GetTime()
    local m = moments[tostring(h.id)]
    if m and not (m.up or (m.downAt and now - m.downAt < Effects.DOWN_GRACE)) then return orig(h, up) end
    local ends = endOf(h)
    if type(ends) ~= "number" or ends <= now then return orig(h, up) end
    orig(h, nil)
    heldNow[h.id] = { due = Bridge.Clip(h, Bridge.SpellOf(h.id)) == true }
end

-- For tests: the end a piece's sound last played for, or nil.
function Effects.Heard(key) return heardFor[key] end

-- ---------------------------------------------------------------------
-- A glow style per moment
-- ---------------------------------------------------------------------

-- Daylight UI asks GlowStyle once as it lights a glow (CdmEffects.lua:386), with
-- the piece's saved table and never the moment. A wrap on SetDown keeps what each
-- pass tells an item, and SetDown lights the item's glow before it returns. A wrap
-- on EndPass forgets the items a pass didn't tell, as Daylight UI does. The style
-- wrap rebuilds the moment from those in Daylight UI's order (wantsGlow,
-- CdmEffects.lua:525-539) and asks Daylight UI's own rule about that moment's
-- style, so motion off still gives the ring. A moment with no style of its own
-- keeps the piece's.
--
-- The styles live in EZCDMDB.glowStyle[profile][key] = { [moment] = style }.

-- The moments a glow line names (Grammar.GLOW_ORDER).
Effects.STYLE_MOMENTS = { ready = true, usable = true, up = true, missing = true, recast = true }

-- The store's form. 2: Comet and Shine move to Circling and Ring (Bridge.GLOW_MOVED).
Effects.STYLE_VERSION = 2

-- Brings saved styles to STYLE_VERSION: as the saved variables load, and before any read.
-- An empty store has nothing to move and stays unmarked, so a read writes nothing.
local function moveStyles()
    if type(EZCDMDB) ~= "table" or type(EZCDMDB.glowStyle) ~= "table" then return end
    if EZCDMDB.glowStyleVersion == Effects.STYLE_VERSION or next(EZCDMDB.glowStyle) == nil then return end
    local moved = Bridge.GLOW_MOVED
    for _, byKey in pairs(EZCDMDB.glowStyle) do
        for _, styles in pairs(type(byKey) == "table" and byKey or {}) do
            if type(styles) == "table" then
                for m, s in pairs(styles) do
                    if moved[s] then styles[m] = moved[s] end
                end
            end
        end
    end
    EZCDMDB.glowStyleVersion = Effects.STYLE_VERSION
end

local function styleStore()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.glowStyle) ~= "table" then EZCDMDB.glowStyle = {} end
    moveStyles()
    return EZCDMDB.glowStyle
end

-- The styles as saved: moment -> style key, or nil for none.
local function cleanStyles(v)
    if type(v) ~= "table" then return nil end
    local out
    for m, s in pairs(v) do
        if Effects.STYLE_MOMENTS[m] and type(s) == "string" and s ~= "" then
            out = out or {}
            out[m] = s
        end
    end
    return out
end

-- The saved table itself, not a copy, for the wrap.
local function stylesOf(key, g)
    local profile = Bridge.ProfileOf(g)
    local byKey = profile ~= nil and styleStore()[profile]
    local t = type(byKey) == "table" and byKey[key]
    return type(t) == "table" and t or nil
end

-- A piece's styles per moment on talent set g's profile (current when nil), or nil.
function Effects.Styles(key, g) return cleanStyles(stylesOf(key, g)) end

-- Sets or clears a piece's styles, as Effects.Set does the up glow's.
function Effects.SetStyles(g, key, styles)
    local profile, why = Bridge.SavedProfile(g)
    if not profile then return false, why end
    local all = styleStore()
    EZCDMDB.glowStyleVersion = Effects.STYLE_VERSION
    all[profile] = all[profile] or {}
    all[profile][key] = cleanStyles(styles)
    if next(all[profile]) == nil then all[profile] = nil end
    return true
end

-- After Grammar.Compile: takes the glow lines' styles (ezStyles) out of fields,
-- which Daylight UI never sees. Returns them for Effects.SetStyles.
function Effects.SplitStyles(fields)
    local styles = cleanStyles(fields.ezStyles)
    fields.ezStyles = nil
    return styles
end

-- item -> { piece, down, due }: what the last pass told it.
local toldItem = setmetatable({}, weak)
-- Saved piece table -> the record of the item told last.
local byPiece = setmetatable({}, weak)
-- The record of the item SetDown is lighting now.
local lighting

-- Around CdmEffects.SetDown: keeps what the pass tells the item, then lets it light.
-- A piece whose "down" the Told wrap held gets "can't tell" and the clock's answer.
local function setDown(orig, item, piece, isDown, isDue)
    local key = next(heldNow) ~= nil and type(piece) == "table" and pieceKey(piece) or nil
    local held = key ~= nil and heldNow[key] or nil
    if held then isDown, isDue = nil, held.due end
    local r = toldItem[item]
    if not r then
        r = {}
        toldItem[item] = r
    end
    r.piece, r.down, r.due = piece, isDown, isDue
    if type(piece) == "table" then byPiece[piece] = r end
    lighting = r
    orig(item, piece, isDown, isDue)
    lighting = nil
end

-- Around CdmEffects.EndPass: forgets the items the pass didn't tell, before
-- Daylight UI refreshes them.
local function endPass(orig, told)
    for item, r in pairs(toldItem) do
        if type(told) ~= "table" or not told[item] then
            toldItem[item] = nil
            if byPiece[r.piece] == r then byPiece[r.piece] = nil end
        end
    end
    lighting = nil
    wipe(heldNow)
    local r = orig(told)
    -- The pass has made its holders, so a face piece's rule can go back now.
    if moveDue then Effects.MoveBack() end
    return r
end

local function isOn(p, field) return Bridge.Option(p, field) == true end

-- Whether the game says the piece's spell can be cast now (plain true only).
local function castableNow(key)
    local sid = Bridge.SpellOf(key)
    local S = type(C_Spell) == "table" and C_Spell or {}
    if sid == nil or type(S.IsSpellUsable) ~= "function" then return false end
    local can = S.IsSpellUsable(sid)
    if type(issecretvalue) == "function" and issecretvalue(can) then return false end
    return can == true
end

-- The moment a lit glow stands for, in Daylight UI's order: missing, recast and up
-- from what the pass told (buffGlow, CdmEffects.lua:514-519), then castable or
-- ready. r is nil for an item no pass told.
local function momentOf(p, r, key)
    local isDown, isDue = r and r.down, r and r.due
    if isDown == true and isOn(p, "missingGlow") and not isOn(p, "hideMissing") then return "missing" end
    if isDown ~= true and isDue == true and isOn(p, "clipGlow") and not isOn(p, "hideActive") then return "recast" end
    if isDown == false and isOn(p, "upGlow") and not isOn(p, "hideActive") then return "up" end
    local usable, ready = isOn(p, "usableGlow"), isOn(p, "readyGlow")
    if usable and ready then return castableNow(key) and "usable" or "ready" end
    if usable then return "usable" end
    if ready then return "ready" end
end

-- One options table per style, handed to Daylight UI's own rule.
local asStyle = {}

-- Around CdmEffects.GlowStyle: the moment's own style, through Daylight UI's rule.
local function glowStyle(orig, button)
    local r
    if button ~= nil then r = byPiece[button] else r = lighting end
    local p = button
    if p == nil and r then p = r.piece end
    if type(p) ~= "table" then return orig(button) end
    local key = pieceKey(p)
    local styles = key ~= nil and stylesOf(key) or nil
    if not styles then return orig(button) end
    local m = momentOf(p, r, key)
    local s = m and styles[m]
    if type(s) ~= "string" then return orig(button) end
    local opts = asStyle[s]
    if not opts then
        opts = { glowStyle = s }
        asStyle[s] = opts
    end
    return orig(opts)
end

-- For tests: the moment the style wrap would read for an item now, or nil.
function Effects.MomentOf(item)
    local r = toldItem[item]
    local p = r and r.piece
    if type(p) ~= "table" then return nil end
    return momentOf(p, r, pieceKey(p))
end

-- In place before Daylight UI makes any holder button: its modules start at
-- PLAYER_LOGIN, and the .toc's OptionalDeps loads its action bars first.
Effects.hooked = Bridge.HookAuraButtons(onButton) and true or false

-- The clock wraps, in place before the first pass for the same reason.
Effects.wrapped = (Bridge.WrapClock("ClipDue", clipDue) and Bridge.WrapClock("Clip", clip)
    and Bridge.WrapClock("ClipGlows", clipGlows) and Bridge.WrapClock("Told", told)) and true or false

-- The glow style wraps, in place before the first pass too.
Effects.styled = (Bridge.WrapGlow("SetDown", setDown) and Bridge.WrapGlow("EndPass", endPass)
    and Bridge.WrapGlow("GlowStyle", glowStyle)) and true or false

-- EZ-CDM's saved variables loading drops an earlier build's proc fall-off rings.
-- Another profile (a talent set switch, or one picked in the editor) takes the old
-- one's rings off. A target change marks the buff moments' swap quiet.
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("PLAYER_TARGET_CHANGED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == "EZ-CDM" then
            dropProcRings()
            moveStyles()
        end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" then
        targetAt = GetTime()
        return
    end
    moveDue = true
    Effects.Sync()
end)

local API = _G.DaylightUI and _G.DaylightUI.API
if type(API) == "table" and type(API.On) == "function" then
    API.On("Login", function()
        if Bridge.Ready() then
            Bridge.HookEditor("Draw", function()
                moveDue = true
                Effects.Sync()
            end)
            Bridge.HookEditor("Close", function() Effects.AskReload() end)
        end
    end, "EZ-CDM")
end
