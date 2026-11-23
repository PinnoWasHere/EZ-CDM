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
-- Daylight UI draws on its own face, with no client button (Effects.Drawn). Draft
-- reads and writes the rule through Effects.Merge and Effects.Split.
--
-- The client takes a button's animations only while it makes the button, and then
-- the button and its children answer secrets (IsShown, IsVisible, GetWidth,
-- GetHeight, IsPlaying), so Daylight UI's own SetGlow can't run there. EZ-CDM
-- builds the ring itself from Daylight UI's art and measures, setting only. A ring
-- is built once, in the color the rule has then, and only turned off later. A new
-- or recolored rule lights from the next /reload (Effects.Pending).
--
-- The fall-off lead and its sound ride on Daylight UI's recast clock (below). A
-- proc's fall-off glow is a second ring in the same button, held hidden for the
-- proc's length less the lead, and the up ring hides as it shows (below). A glow style per moment rides on Daylight
-- UI's own glows (below).

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
-- Client button -> { key, frame, tex, anim, hold, fade, color, lead, lasts } for each
-- fall-off ring handed over and still on.
local leads = setmetatable({}, weak)
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
    if fo and fo.ring then
        fields.clipGlow = true
        fields.clipGlowColor = isRGB(fo.ring) and { fo.ring[1], fo.ring[2], fo.ring[3] } or nil
    end
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

-- Daylight UI's ring on a square icon (CdmEffects.lua:199-274): the game's proc
-- loop art, gray so the color tints true, reaching past each edge by pad times
-- the side, turned by a looping flipbook. size is the button's side as Daylight UI
-- set it, so nothing here asks the button. The texture sits two frames deep, as
-- Daylight UI's does, so it draws over the button's cooldown. above puts it one
-- frame deeper. Frame nesting sets no draw order between sibling frames, so two
-- rings on one button share a holder and differ by draw-layer sublevel (handPair).
local function ringFrames(btn, size, art, above)
    local pad = size * art.pad
    local frame = CreateFrame("Frame", nil, btn)
    frame:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
    frame:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetAllPoints(frame)
    if above then
        holder = CreateFrame("Frame", nil, holder)
        holder:SetAllPoints(frame)
    end
    return frame, holder
end

-- The ring's texture on holder and its looping flipbook on frame. sub, when given,
-- is the texture's OVERLAY sublevel.
local function ringArt(frame, holder, art, color, sub)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    if sub then tex:SetDrawLayer("OVERLAY", sub) end
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
    return tex, anim
end

local function buildRing(btn, size, color, above)
    local art = Bridge.RingArt()
    if not art then return nil end
    local frame, holder = ringFrames(btn, size, art, above)
    local tex, anim = ringArt(frame, holder, art, color)
    return { frame = frame, tex = tex, anim = anim }
end

-- A group on frame that holds target (frame itself when nil) at alpha a for d
-- seconds from when the client plays it. Then target's own alpha comes back.
local function holdAt(frame, target, a, d)
    local hold = frame:CreateAnimationGroup()   -- look-ok: holds Daylight UI's ring at a set alpha until the lead
    local fade = hold:CreateAnimation("Alpha")
    if target then fade:SetTarget(target) end
    fade:SetFromAlpha(a)
    fade:SetToAlpha(a)
    fade:SetDuration(d)
    return hold, fade
end

-- The fall-off rule and the proc's length when the piece gets a fall-off ring.
local function leadFor(key)
    local rule = Effects.FallOff(key)
    if not (rule and rule.ring and rule.lead) then return nil end
    local lasts = Effects.ProcLasts(key)
    if not lasts or lasts <= rule.lead then return nil end
    return rule, lasts
end

local function colorOf(v) return isRGB(v) and v or nil end

-- Fall-off ring over the up ring, by draw layer under one holder.
local UP_SUB, LEAD_SUB = 6, 7

-- Inside initializeFrame (Bridge.HookAuraButtons). It only makes and sets things,
-- and tests nothing the button or its children report. A holder made under
-- restrictions waits for a /reload out of a fight, since its button locks as soon
-- as this returns.
-- The fall-off ring alone: the ring, one frame deeper, and a second group that
-- holds its frame at alpha 0 for the proc's length less the lead. The client plays both as
-- the button comes up with the proc, so the ring shows lead seconds before the end.
-- Once the hold is done the frame's own alpha (1) comes back.
local function handLead(btn, key, size, rule, lasts)
    local r = buildRing(btn, size, colorOf(rule.ring), true)
    if not r then return end
    local hold, fade = holdAt(r.frame, nil, 0, lasts - rule.lead)
    btn:AddAuraShownAnimation(r.anim)
    btn:AddAuraShownAnimation(hold)
    r.key, r.color, r.lead, r.lasts, r.hold, r.fade = key, rule.ring, rule.lead, lasts, hold, fade
    leads[btn] = r
end

-- Both rings on one button: one frame and holder, the fall-off ring a draw-layer
-- sublevel over the up ring. The up ring's own alpha is 0, and its hold keeps it
-- at 1 for the proc's length less the lead. The fall-off ring's hold keeps it at 0
-- for the same time. So the up ring shows until the lead, then the fall-off ring
-- alone. Both holds are timed from EZ-CDM's own length and lead only.
local function handPair(btn, key, size, want, rule, lasts)
    local art = Bridge.RingArt()
    if not art then return end
    local frame, holder = ringFrames(btn, size, art)
    local shown = lasts - rule.lead
    local up = { frame = frame, shared = true, key = key, color = want }
    up.tex, up.anim = ringArt(frame, holder, art, colorOf(want), UP_SUB)
    up.tex:SetAlpha(0)
    up.hold, up.fade = holdAt(frame, up.tex, 1, shown)
    local lead = { frame = frame, shared = true, key = key, color = rule.ring, lead = rule.lead, lasts = lasts }
    lead.tex, lead.anim = ringArt(frame, holder, art, colorOf(rule.ring), LEAD_SUB)
    lead.hold, lead.fade = holdAt(frame, lead.tex, 0, shown)
    btn:AddAuraShownAnimation(up.anim)
    btn:AddAuraShownAnimation(up.hold)
    btn:AddAuraShownAnimation(lead.anim)
    btn:AddAuraShownAnimation(lead.hold)
    rings[btn], leads[btn] = up, lead
end

local function onButton(btn, key, size)
    seen = seen + 1
    if size == nil or Bridge.Restricted() then return end
    if type(btn.AddAuraShownAnimation) ~= "function" then return end
    local want = Effects.Get(key)
    local rule, lasts = leadFor(key)
    if want ~= nil and rule then
        handPair(btn, key, size, want, rule, lasts)
        return
    end
    if want ~= nil then
        local r = buildRing(btn, size, colorOf(want))
        if r then
            btn:AddAuraShownAnimation(r.anim)
            r.key, r.color = key, want
            rings[btn] = r
        end
    end
    if rule then handLead(btn, key, size, rule, lasts) end
end

local function dropHold(btn, r)
    r.hold:Stop()
    btn:RemoveAuraShownAnimation(r.hold)
end

-- Takes a ring out of its button: hidden, stopped and out of the client's list,
-- so it never plays again. A ring sharing its frame hides only its texture. Out of
-- restrictions only.
local function unhand(btn, r)
    if r.shared then r.tex:Hide() else r.frame:Hide() end
    r.anim:Stop()
    btn:RemoveAuraShownAnimation(r.anim)
    if r.hold then dropHold(btn, r) end
end

local function sync()
    for btn, r in pairs(rings) do
        if Effects.Get(r.key) == nil then
            rings[btn] = nil
            unhand(btn, r)
        end
    end
    for btn, r in pairs(leads) do
        local rule = Effects.FallOff(r.key)
        if not (rule and rule.ring and rule.lead) then
            leads[btn] = nil
            unhand(btn, r)

            -- The up ring left alone shows for the whole proc again.
            local up = rings[btn]
            if up and up.hold then
                dropHold(btn, up)
                up.hold, up.fade = nil, nil
                up.tex:SetAlpha(1)
            end
        end
    end
end

-- Turns off every ring whose rule is gone (a removed line, another profile).
-- Waits for restrictions to lift.
function Effects.Sync() Bridge.AfterRestrictions(sync, "ezcdm:effects:sync") end

-- Whether a face piece's rule waits to go back to Daylight UI (Effects.MoveBack).
local moveDue = true

-- An up glow rule on a piece Daylight UI draws on its own face goes back to
-- Daylight UI's upGlow, in its color, and EZ-CDM's rule is cleared. Only the
-- current profile's placed pieces; one whose holder can't say yet waits for a
-- later pass. Out of restrictions only, since it writes the layout.
function Effects.MoveBack()
    if Bridge.Restricted() then return end
    local g = Bridge.CurrentIndex()
    local profile = Bridge.ProfileOf(g)
    local byKey = profile ~= nil and store()[profile]
    local set = Bridge.Layout(g)
    local pieces = type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}
    local waiting = false
    for key, v in pairs(type(byKey) == "table" and byKey or {}) do
        if pieces[key] ~= nil and Effects.DRAWN[Bridge.DrawnBy(key) or ""] then
            local client = Bridge.ClientButtons(key)
            if client == false then
                local color = clean(v)
                local ok = Bridge.SetSpellValue(g, key, "upGlow", true)
                if ok and isRGB(color) then ok = Bridge.SetSpellValue(g, key, "upGlowColor", color) end
                if ok then Effects.Set(g, key, nil) else waiting = true end
            elseif client == nil then
                waiting = true
            end
        end
    end
    moveDue = waiting
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

-- For tests: client buttons the hook has seen, and the ring on btn ({ key, frame,
-- tex, anim, color }) or nil.
function Effects.Seen() return seen end
function Effects.Ring(btn) return rings[btn] end

-- ---------------------------------------------------------------------
-- A proc's fall-off ring
-- ---------------------------------------------------------------------

-- "When it's about to fall off (N seconds before), glow" on a proc Daylight UI's aura
-- icon holder draws (Improved Stormstrike). Nothing tells addon code in a fight when
-- the proc lands, but the client shows its aura button then and plays what it was
-- handed. So the ring and its hold go into the button inside initializeFrame, like
-- the up glow's ring, and run from when the proc lands. A new proc while the old
-- one is up keeps the button shown, so nothing replays.
--
-- The length is Daylight UI's: the one its holder last read (h.auraLasts, plain),
-- else the game's data (FACTS). A holder that can't tell up or down never reads, so
-- out of a fight, as the player's auras change, EZ-CDM asks each aura icon holder
-- with no length yet to read (CdmAuras.Read). Holders forget theirs on a /reload, so
-- EZ-CDM keeps the last one read in EZCDMDB.procLasts[key] for the next login's
-- buttons.
--
-- The rule is the fall-off rule with ring = true or a color, the glow line's.
-- Daylight UI's clipGlow stays off on such a piece (Effects.SplitFallOff).

local function lastsStore()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.procLasts) ~= "table" then EZCDMDB.procLasts = {} end
    return EZCDMDB.procLasts
end

-- How long a piece's proc lasts in seconds, or nil when no one knows yet.
function Effects.ProcLasts(key)
    if key == nil then return nil end
    local read = Bridge.AuraLasts(key)
    if read then
        lastsStore()[key] = read
        return read
    end
    local kept = lastsStore()[key]
    if type(kept) == "number" and kept > 0 then return kept end
    return Bridge.FactLasts(key)
end

-- Out of a fight: each aura icon holder whose length no one knows reads its aura,
-- and a length it learns is kept.
local function learnLengths()
    if Bridge.Restricted() then return end
    local set = Bridge.Layout()
    for key in pairs(type(set) == "table" and type(set.pieces) == "table" and set.pieces or {}) do
        if lastsStore()[key] == nil and Effects.Drawn(key) and Effects.ProcLasts(key) == nil then
            Bridge.ReadAura(key)
            Effects.ProcLasts(key)
        end
    end
end
Effects.LearnLengths = learnLengths

-- For tests: the fall-off ring on btn ({ key, frame, tex, anim, hold, fade, color,
-- lead, lasts }) or nil.
function Effects.Lead(btn) return leads[btn] end

-- Whether a fall-off ring for the piece is in a client button now, with which lead,
-- length and color.
function Effects.LeadLit(key)
    for _, r in pairs(leads) do
        if r.key == key then return true, r.lead, r.lasts, r.color end
    end
    return false
end

-- Whether the piece's proc fall-off rule has no ring like it yet: it lights after
-- the next /reload.
function Effects.LeadPending(key)
    local rule = Effects.FallOff(key)
    if not (rule and rule.ring and rule.lead) then return false end
    local lit, lead, lasts, color = Effects.LeadLit(key)
    return not (lit and lead == rule.lead and lasts == Effects.ProcLasts(key) and sameColor(color, rule.ring))
end

-- ---------------------------------------------------------------------
-- The fall-off lead and its sound
-- ---------------------------------------------------------------------

-- "When it's about to fall off (N seconds before)" on Daylight UI's recast clock.
-- The clock runs from your own cast (CdmAuras.lua:1194-1211) and keeps the end in
-- h.endsAt, a plain number. A wrap on ClipDue moves its due moment to N seconds
-- before that end, so Daylight UI lights its own recast glow then, in its own
-- color, style and priority, and its own timer wakes for it. A wrap on Clip hears
-- the moment come and plays the sound once. A wrap on ClipGlows keeps the clock
-- running for a sound with no glow; Daylight UI's glow checks its own clipGlow, so
-- none shows. A wrap on Told trusts the clock over the game's "down" until its end,
-- and the SetDown wrap hands that on. No frame, timer or driver of EZ-CDM's own.
--
-- The rule lives in EZCDMDB.fallOff[profile][key] = { lead = N, sound = key }, and
-- ring = true or a color on a proc's (above). Without one, Daylight UI's own timing
-- stands. Draft reads and writes it through Effects.Merge and Effects.SplitFallOff.

local function fallOffStore()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.fallOff) ~= "table" then EZCDMDB.fallOff = {} end
    return EZCDMDB.fallOff
end

-- The rule as saved: a positive lead, a sound key other than "none", a ring, or nil.
local function cleanFallOff(v)
    if type(v) ~= "table" then return nil end
    local lead = type(v.lead) == "number" and v.lead > 0 and v.lead or nil
    local sound = type(v.sound) == "string" and v.sound ~= "none" and v.sound or nil
    local ring = clean(v.ring)
    if lead == nil and sound == nil and ring == nil then return nil end
    return { lead = lead, sound = sound, ring = ring }
end

-- A piece's fall-off rule on talent set g's profile (current when nil):
-- { lead, sound, ring }, any of them nil, or nil for none.
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
-- fields, which Daylight UI never sees. On a proc EZ-CDM rings (kind.procLead,
-- Grammar.Kind) the glow (clipGlow and its color) comes out too, so Daylight UI's
-- clipGlow is written off. Returns the rule for Effects.SetFallOff.
function Effects.SplitFallOff(fields, kind)
    local ring
    if type(kind) == "table" and kind.procLead == true then
        if fields.clipGlow == true then ring = isRGB(fields.clipGlowColor) and clean(fields.clipGlowColor) or true end
        fields.clipGlow, fields.clipGlowColor = nil, nil
    end
    local rule = cleanFallOff({ lead = fields.ezLead, sound = fields.ezSound, ring = ring })
    fields.ezLead, fields.ezSound = nil, nil
    return rule
end

-- The current profile's rule for a holder or watch the clock passes in. A proc's
-- ring rule is the client's to run, not the clock's.
local function ruleOf(h)
    local key = type(h) == "table" and h.id or nil
    if key == nil then return nil end
    local rule = Effects.FallOff(key)
    if rule and rule.ring then return nil end
    return rule
end

-- Around CdmAuras.ClipDue. Daylight UI's own "due" stands, and so does a "not due"
-- with no time (no clock, or the recast already being cast). Otherwise the moment
-- comes N seconds before the end, or Daylight UI's own when that is sooner.
local function clipDue(orig, h, sid)
    local due, at = orig(h, sid)
    if due or not at then return due, at end
    local rule = ruleOf(h)
    local ends = h.endsAt
    if not (rule and rule.lead) or type(ends) ~= "number" then return due, at end
    local soon = ends - rule.lead
    if soon <= GetTime() then return true end
    return false, math.min(at, soon)
end

-- piece key -> the end its sound last played for. One end, one sound: a pass that
-- asks again, or a second holder of the same piece, plays nothing more. A recast
-- moves the end later and re-arms it. An end that moves a second or less is the
-- same cast, read again (Daylight UI's own test for a new application,
-- CdmAuras.lua:1017).
local heardFor = {}

-- Around CdmAuras.Clip: the pass's answer, unchanged.
local function clip(orig, h, sid)
    local due = orig(h, sid)
    if due ~= true then return due end
    local rule = ruleOf(h)
    local ends = h.endsAt
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

-- Around CdmAuras.Told. In a fight the game's item says "down" while the aura is
-- still up: before your debuff lands, and mid-debuff as the item looks again (seen
-- after another spell's global cooldown). Daylight UI drops the clock on a "down"
-- (CdmAuras.lua:1370) and the pass skips Clip (CdmRows.lua:624, 883), so the moment
-- never comes. On a piece with a fall-off rule, the clock is trusted: until its end
-- a "down" is told as "can't tell", and the clock is asked as the pass would.
-- Your recast still moves the end. After the end, the "down" stands.
local function told(orig, h, up)
    if type(h) ~= "table" or up ~= false then return orig(h, up) end
    local ends = h.endsAt
    if type(ends) ~= "number" or ends <= GetTime() or ruleOf(h) == nil then return orig(h, up) end
    orig(h, nil)
    heldNow[h.id] = { due = Bridge.Clip(h, Bridge.SpellOf(h.id)) == true }
end

-- For tests: the end a piece's sound last played for, or nil.
function Effects.Heard(key) return heardFor[key] end

-- ---------------------------------------------------------------------
-- A glow style per moment
-- ---------------------------------------------------------------------

-- Daylight UI asks GlowStyle once as it lights a glow (CdmEffects.lua:377), with
-- the piece's saved table and never the moment. A wrap on SetDown keeps what each
-- pass tells an item, and SetDown lights the item's glow before it returns. A wrap
-- on EndPass forgets the items a pass didn't tell, as Daylight UI does. The style
-- wrap rebuilds the moment from those in Daylight UI's order (wantsGlow,
-- CdmEffects.lua:516-530) and asks Daylight UI's own rule about that moment's
-- style, so motion off still gives the ring. A moment with no style of its own
-- keeps the piece's.
--
-- The styles live in EZCDMDB.glowStyle[profile][key] = { [moment] = style }.

-- The moments a glow line names (Grammar.GLOW_ORDER).
Effects.STYLE_MOMENTS = { ready = true, usable = true, up = true, missing = true, recast = true }

local function styleStore()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    if type(EZCDMDB.glowStyle) ~= "table" then EZCDMDB.glowStyle = {} end
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
-- from what the pass told (buffGlow, CdmEffects.lua:505-510), then castable or
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

-- Another profile (a talent set switch, or one picked in the editor) takes the
-- old one's rings off. The player's auras changing out of a fight lets holders
-- learn their lengths. At logout each ringed proc keeps its length for the next
-- login's buttons.
local events = CreateFrame("Frame")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:RegisterEvent("PLAYER_LOGOUT")
events:RegisterUnitEvent("UNIT_AURA", "player")
events:SetScript("OnEvent", function(_, event)
    if event == "UNIT_AURA" then return learnLengths() end
    if event ~= "PLAYER_LOGOUT" then
        moveDue = true
        return Effects.Sync()
    end
    local profile = Bridge.ProfileOf()
    local byKey = profile ~= nil and fallOffStore()[profile]
    for key, rule in pairs(type(byKey) == "table" and byKey or {}) do
        if type(rule) == "table" and rule.ring then Effects.ProcLasts(key) end
    end
end)

local API = _G.DaylightUI and _G.DaylightUI.API
if type(API) == "table" and type(API.On) == "function" then
    API.On("Login", function()
        if Bridge.Ready() then
            Bridge.HookEditor("Draw", function()
                moveDue = true
                Effects.Sync()
            end)
        end
    end, "EZ-CDM")
end
