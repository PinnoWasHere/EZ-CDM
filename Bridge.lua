local _, ns = ...

-- The one file that touches Daylight UI's internals (anything not in API.md).
-- docs/reference/daylight-internals.md lists each one, row for row with NEEDS.
-- If an update drops one, EZ-CDM switches itself off with one chat line.

local Bridge = {}
ns.Bridge = Bridge

-- Debug handle for an in-game check (/run print(EZCDM_Bridge.Ready())).
EZCDM_Bridge = Bridge

-- Every internal EZ-CDM calls, as "<root>.<path>". The root "DaylightUI" is the
-- core table; any other root is that module's ns (DaylightUI:GetModule(root).ns).
Bridge.NEEDS = {
    "ActionBars.Cooldowns",
    -- Reads
    "ActionBars.CdmData.SETS",
    "ActionBars.CdmData.CurrentIndex",
    "ActionBars.CdmData.Get",
    "ActionBars.CdmData.Profiles",
    "ActionBars.CdmData.Profile",
    "ActionBars.CdmData.Use",
    "ActionBars.CdmData.MyClass",
    "ActionBars.CdmData.Info",
    "ActionBars.CdmData.SPELL_FIELDS",
    "ActionBars.CdmData.CHAIN_FIELDS",
    "ActionBars.CdmEditor.KeyForID",
    "ActionBars.CdmEditor.Spells",
    "ActionBars.CdmRows.Tracked",
    "ActionBars.CdmCustom.Is",
    "ActionBars.CdmEffects.Get",
    "ActionBars.CdmEffects.FORMS",
    "DaylightUI.Motion.GLOW_STYLES",
    "DaylightUI.Sound.AlertChoices",
    -- Writes
    "ActionBars.CdmData.Ensure",
    "ActionBars.CdmData.AddPiece",
    "ActionBars.CdmData.Hook",
    "ActionBars.CdmData.LOOK",
    "ActionBars.CdmEditor.FreeSpot",
    "ActionBars.CdmData.SetSpellValue",
    "ActionBars.CdmData.SetTrack",
    "ActionBars.CdmData.SetChainValue",
    "ActionBars.CdmData.CopyProfile",
    "ActionBars.CdmData.Assign",
    "ActionBars.CdmData.Changed",
    "ActionBars.CdmRows.Refresh",
    -- Preview and sharing
    "DaylightUI.Style.Shell",
    "DaylightUI.Style.CropIcon",
    "ActionBars.CdmEffects.PreviewGlow",
    "DaylightUI.Sound.Alert",
    "DaylightUI.Profiles.Pack",
    "DaylightUI.Profiles.Unpack",
}

-- The table a root name stands for, or nil.
local function rootOf(name)
    local DUI = _G.DaylightUI
    if type(DUI) ~= "table" then return nil end
    if name == "DaylightUI" then return DUI end
    if type(DUI.GetModule) ~= "function" then return nil end
    local mod = DUI:GetModule(name)
    return type(mod) == "table" and mod.ns or nil
end

local function isValueName(part) return part:match("^[%u_]+$") ~= nil end

-- The value at a dotted path, or nil when any part is missing.
function Bridge.Resolve(path)
    local cur
    for part in string.gmatch(path, "[^%.]+") do
        if cur == nil then
            cur = rootOf(part)
        elseif type(cur) == "table" then
            cur = cur[part]
        else
            return nil
        end
        if cur == nil then return nil end
    end
    return cur
end

-- Whether a path resolves to what its form promises: "<root>.<Part>" is a table,
-- a last part in capitals is a value, and anything else is a function.
local function present(path)
    local v = Bridge.Resolve(path)
    local _, dots = path:gsub("%.", "")
    if dots == 1 then return type(v) == "table" end
    if isValueName(path:match("([^%.]+)$")) then return v ~= nil end
    return type(v) == "function"
end

-- Every NEEDS entry this Daylight UI lacks, in NEEDS order.
function Bridge.Missing()
    local out = {}
    for _, path in ipairs(Bridge.NEEDS) do
        if not present(path) then out[#out + 1] = path end
    end
    return out
end

-- Whether Daylight UI's Cooldown Manager is running (set at its login).
function Bridge.CdmOn()
    local CD = Bridge.Resolve("ActionBars.Cooldowns")
    return type(CD) == "table" and CD.enabled == true
end

-- True when every internal is there and the Cooldown Manager is on.
function Bridge.Ready()
    return #Bridge.Missing() == 0 and Bridge.CdmOn()
end

-- The one chat line, or nil when ready.
function Bridge.OffLine()
    local missing = Bridge.Missing()
    if #missing > 0 then
        local more = #missing > 1 and string.format(" (and %d more)", #missing - 1) or ""
        return string.format("EZ-CDM is off: this Daylight UI has no %s%s.", missing[1], more)
    end
    if not Bridge.CdmOn() then
        return "EZ-CDM is off: Daylight UI's Cooldown Manager is off."
    end
end

-- Checked once Daylight UI has finished loading, so its Cooldown Manager has started.
function Bridge.Check()
    local line = Bridge.OffLine()
    Bridge.off = line ~= nil
    if line and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) end
    return not Bridge.off
end

-- ---------------------------------------------------------------------
-- Reads. Each returns Daylight UI's own answer, or nil when that internal is gone.
-- ---------------------------------------------------------------------

local function call(path, ...)
    local fn = Bridge.Resolve(path)
    if type(fn) ~= "function" then return nil end
    return fn(...)
end

-- The talent set shown now (1 or 2), and how many there are.
function Bridge.CurrentIndex() return call("ActionBars.CdmData.CurrentIndex") end
function Bridge.SetCount() return Bridge.Resolve("ActionBars.CdmData.SETS") end

-- Talent set g's layout (current when nil). Read only: with no profile picked it is
-- an unsaved scratch set, so writes go through the calls below.
function Bridge.Layout(g) return call("ActionBars.CdmData.Get", g or Bridge.CurrentIndex()) end

-- The class's profiles by name, { { id, name } } (the player's class when nil).
function Bridge.Profiles(class) return call("ActionBars.CdmData.Profiles", class) end
-- A profile { name, class, set }, or nil.
function Bridge.Profile(id) return call("ActionBars.CdmData.Profile", id) end
-- The profile id talent set g uses (current when nil), or nil.
function Bridge.ProfileOf(g) return call("ActionBars.CdmData.Use", g or Bridge.CurrentIndex()) end
-- The player's class token, or nil before it is known.
function Bridge.MyClass() return call("ActionBars.CdmData.MyClass") end

-- The piece key a typed spell or item id stands for ("spell" or "item"), or nil
-- and Daylight UI's reason ("number", "spell", "item", "use", "wait").
function Bridge.KeyFor(kind, text) return call("ActionBars.CdmEditor.KeyForID", kind, text) end
-- The editor's spell tray for the current talent set: { id, kind, aura, name,
-- placed, unlearned, custom }.
function Bridge.Spells() return call("ActionBars.CdmEditor.Spells") end
-- The game's info for a cooldown id (shared, read only), or nil.
function Bridge.Info(id) return call("ActionBars.CdmData.Info", id) end
-- Whether a placed piece's buff can be told up or down: true, false, or nil when
-- the last pass didn't draw it.
function Bridge.Tracked(id) return call("ActionBars.CdmRows.Tracked", id) end
-- Whether a key is Daylight UI's own piece ("s<id>", "i<id>", named families). Its
-- track values differ from a game piece's (Bridge.SetTrack against Bridge.SetSpellValue).
function Bridge.IsCustom(key) return call("ActionBars.CdmCustom.Is", key) and true or false end
-- A piece's option, or its default.
function Bridge.Option(piece, field) return call("ActionBars.CdmEffects.Get", piece, field) end

-- The valid-value tables. Shared with Daylight UI: read only.
function Bridge.SpellFields() return Bridge.Resolve("ActionBars.CdmData.SPELL_FIELDS") end
function Bridge.ChainFields() return Bridge.Resolve("ActionBars.CdmData.CHAIN_FIELDS") end
-- Forms, stances and stealth by class token ({ key, name, ... }, saved as hideIn<key>).
function Bridge.Forms() return Bridge.Resolve("ActionBars.CdmEffects.FORMS") end
-- The animated glow styles by key; "ring" (the game's proc ring) is valid too.
function Bridge.GlowStyles() return Bridge.Resolve("DaylightUI.Motion.GLOW_STYLES") end
-- The sound list: values, order, titles (headings in order are "head:" keys).
function Bridge.SoundChoices() return call("DaylightUI.Sound.AlertChoices") end

-- ---------------------------------------------------------------------
-- Writes. Each refuses in combat and while switched off, and returns true (or
-- the new thing) on success, else false and a reason:
--   "combat"    in combat
--   "off"       an internal is missing or the Cooldown Manager is off
--   "set"       not a talent set number
--   "unsaved"   no profile could be saved (the class isn't known yet)
--   "rejected"  Daylight UI refused it (no such piece, a bad value, or an option
--               the piece's shape doesn't take)
-- g is the talent set (current when nil). Nothing shows until Bridge.Apply().
-- ---------------------------------------------------------------------

local function canWrite()
    if InCombatLockdown() then return false, "combat" end
    if not Bridge.Ready() then return false, "off" end
    return true
end

-- Talent set g's saved layout, made a profile first if it has none.
local function savedSet(g)
    local ok, why = canWrite()
    if not ok then return nil, why end
    g = g or Bridge.CurrentIndex()
    if type(g) ~= "number" or g < 1 or g > Bridge.SetCount() or g % 1 ~= 0 then return nil, "set" end
    local set = call("ActionBars.CdmData.Ensure", g)
    if not Bridge.ProfileOf(g) then return nil, "unsaved" end
    return set
end

local function answer(done)
    if done then return true end
    return false, "rejected"
end

-- Saves talent set g's layout as a profile when it has none (Daylight UI's editor
-- does this before any change). Returns the set.
function Bridge.Ensure(g)
    local set, why = savedSet(g)
    if not set then return false, why end
    return set
end

-- A free spot for a new piece of this shape ("icon" or "bar") on the current talent
-- set's layout: x, y of its top-left.
function Bridge.FreeSpot(shape)
    local look = Bridge.Resolve("ActionBars.CdmData.LOOK")
    if type(look) ~= "table" then return nil end
    local w, h = look.size, look.size
    if shape == "bar" then w, h = look.width, look.height end
    return call("ActionBars.CdmEditor.FreeSpot", w, h)
end

-- Places key as a free piece with its top-left at x, y (a free spot when nil).
-- A piece already placed keeps its options and is freed and moved there.
function Bridge.AddPiece(g, key, shape, x, y)
    local set, why = savedSet(g)
    if not set then return false, why end
    if key == nil then return false, "rejected" end
    if x == nil or y == nil then x, y = Bridge.FreeSpot(shape) end
    return answer(call("ActionBars.CdmData.AddPiece", set, key, shape, x, y) ~= nil)
end

-- Hangs a placed key (and what hangs off it) on side ("right", "down", "left",
-- "up") of parent, at the end of that run. align: "start", "center" or "end".
function Bridge.Hook(g, key, parent, side, align)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.Hook", set, key, parent, side, align))
end

-- One spell option (Bridge.SpellFields). A value equal to the default is removed.
-- For a game piece "track" is both / cooldown / buff / totem.
function Bridge.SetSpellValue(g, key, field, value)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetSpellValue", set, key, field, value))
end

-- What Daylight UI's own piece (Bridge.IsCustom) shows: cooldown, aura or both.
function Bridge.SetTrack(g, key, track)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetTrack", set, key, track))
end

-- One group option (Bridge.ChainFields), set from any piece in the group.
function Bridge.SetChainValue(g, key, field, value)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetChainValue", set, key, field, value))
end

-- Copies the profile talent set g uses into a new one (named name, or the old
-- name made unique) and picks the copy for g. The old profile is left as it was.
-- Returns the new profile's id.
function Bridge.CopyAndAssign(g, name)
    g = g or Bridge.CurrentIndex()
    local set, why = savedSet(g)
    if not set then return false, why end
    local id = call("ActionBars.CdmData.CopyProfile", Bridge.ProfileOf(g), name)
    if not id then return false, "rejected" end
    if not call("ActionBars.CdmData.Assign", g, id) then return false, "rejected" end
    return id
end

-- Shows what was written: Daylight UI's layout pass runs on the next frame.
function Bridge.Apply()
    local ok, why = canWrite()
    if not ok then return false, why end
    call("ActionBars.CdmData.Changed")
    call("ActionBars.CdmRows.Refresh")
    return true
end

-- ---------------------------------------------------------------------
-- Preview and sharing. Daylight UI's own looks and codec, passed straight through.
-- ---------------------------------------------------------------------

-- Daylight UI's frame shell on frame (the editor's preview pieces wear it).
function Bridge.Shell(frame, opts) return call("DaylightUI.Style.Shell", frame, opts) end
-- Daylight UI's crop for a square spell icon texture.
function Bridge.CropIcon(tex) return call("DaylightUI.Style.CropIcon", tex) end
-- A glow style ("ring" or a Bridge.GlowStyles key) shown for a moment on frame, in
-- the color of the first glow piece has on (the accent when none).
function Bridge.PreviewGlow(frame, style, piece)
    return call("ActionBars.CdmEffects.PreviewGlow", frame, style, piece)
end
-- Plays a sound choice ("dui:<name>", "kit:<id>", "file:<id>", "lsm:<name>") the way
-- the Cooldown Manager does. Returns the sound's handle, or nil.
function Bridge.PlaySound(key) return call("DaylightUI.Sound.Alert", key) end
-- Any table packed into text starting with prefix (CBOR, compressed, Base64), or
-- nil and a reason.
function Bridge.Pack(t, prefix) return call("DaylightUI.Profiles.Pack", t, prefix) end
-- Pack's table back from text, or nil and a reason ("empty", "prefix", "client",
-- "damaged").
function Bridge.Unpack(text, prefix) return call("DaylightUI.Profiles.Unpack", text, prefix) end

local API = _G.DaylightUI and _G.DaylightUI.API
if type(API) == "table" and type(API.On) == "function" then
    API.On("Login", Bridge.Check, "EZ-CDM")
end
