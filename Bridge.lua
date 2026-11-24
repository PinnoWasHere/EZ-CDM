local addonName, ns = ...

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
    "ActionBars.CdmData.CHAIN",
    "ActionBars.CdmRows.Tracked",
    "ActionBars.CdmCustom.Is",
    "ActionBars.CdmOwn.Track",
    "ActionBars.CdmOwn.Entry",
    "ActionBars.CdmOwn.SpellOf",
    "ActionBars.CdmEffects.Get",
    "ActionBars.CdmEffects.FORMS",
    "DaylightUI.Sound.AlertChoices",
    "ActionBars.CdmData.Root",
    "ActionBars.CdmData.Subtree",
    "ActionBars.CdmEditor.SpellName",
    "ActionBars.CdmCustom.CanTrack",
    "ActionBars.CdmAuras.SpellIDs",
    "ActionBars.CdmCustom.Totem",
    "ActionBars.CdmData.PieceLook",
    "ActionBars.CdmCard.Fallback",
    "ActionBars.CdmCard.ROWS",
    -- Writes
    "ActionBars.CdmData.Ensure",
    "ActionBars.CdmData.SetSpellValue",
    "ActionBars.CdmData.SetTrack",
    "ActionBars.CdmData.SetChainValue",
    "ActionBars.CdmData.SetLook",
    "ActionBars.CdmData.CopyProfile",
    "ActionBars.CdmData.NewProfile",
    "ActionBars.CdmData.Assign",
    -- Looks
    "DaylightUI.Style.Shell",
    "DaylightUI.Style.CropIcon",
    -- Window parts
    "DaylightUI.Win.EDGE",
    "DaylightUI.Win.Parts.Stack",
    "DaylightUI.Widgets.DeleteButton",
    "ActionBars.CdmEditor.SpellTexture",
    "DaylightUI.Widgets.OpenColorPicker",
    "DaylightUI.Win.Parts.Rule",
    "DaylightUI.Win.Parts.GAP",
    -- Start block
    "DaylightUI.InstallerCards.Picker",
    "ActionBars.CdmEditor.Open",
    -- Drawer: the editor functions EZ-CDM hooks (me.Hook), then what it reads
    "ActionBars.CdmEditor.Close",
    "ActionBars.CdmEditor.Select",
    "ActionBars.CdmEditor.Draw",
    "ActionBars.CdmEditor.EndTrayMove",
    "ActionBars.CdmEditor.IsOpen",
    "ActionBars.CdmEditor.Selected",
    "ActionBars.CdmEditor.Attach",
    "ActionBars.CdmEditor.Tray",
    "ActionBars.CdmEditor.Overlay",
    "ActionBars.CdmCard.TOP",
    -- Drawer: sentences, chips and live writes
    "ActionBars.CdmEditor.Changed",
    "DaylightUI.Widgets.Link",
    "DaylightUI.Widgets.Chip",
    "DaylightUI.Style.SIZE",
    -- Drawer: the fold tab and its slide
    "DaylightUI.Motion.Slider",
    "DaylightUI.Style.BorderPx",
    "DaylightUI.Pixel.Px",
    -- Effects: the up glow EZ-CDM builds inside a holder's client aura buttons
    "ActionBars.CdmEffects.MakeSlide",
    "ActionBars.CdmEffects.GLOW_ATLAS",
    "ActionBars.CdmEffects.GLOW_ROWS",
    "ActionBars.CdmEffects.GLOW_COLUMNS",
    "ActionBars.CdmEffects.GLOW_FRAMES",
    "ActionBars.CdmEffects.GLOW_LOOP",
    "ActionBars.CdmEffects.GLOW_PAD",
    "DaylightUI.Style.PaintAccent",
    "ActionBars.CdmAuras.Frame",
    "ActionBars.CdmRows.DrawnBy",
    "DaylightUI.Restricted",
    "DaylightUI.AfterRestrictions",
    "DaylightUI.SafeCall",
    -- Effects: the /reload question as the editor closes, Daylight UI's own question box
    "DaylightUI.Widgets.Ask",
    -- Effects: the fall-off lead and its sound on Daylight UI's recast clock (me.Wrap)
    "ActionBars.CdmAuras.ClipDue",
    "ActionBars.CdmAuras.Clip",
    "ActionBars.CdmEffects.ClipGlows",
    "DaylightUI.Sound.Alert",
    "ActionBars.CdmAuras.Told",
    -- Effects: a glow style per moment (me.Wrap)
    "ActionBars.CdmEffects.GlowStyle",
    "ActionBars.CdmEffects.SetDown",
    "ActionBars.CdmEffects.EndPass",
    -- Effects: an aura's length, for the fall-off clock on Daylight UI's buff moments
    "ActionBars.CdmCustom.Fact",
    -- Grammar: a buff another class puts on you is never your proc
    "ActionBars.CdmCustom.IsGroup",
    -- Effects: a pass once the fall-off clock stops on a buff's drop
    "ActionBars.CdmRows.Refresh",
}

-- Internals EZ-CDM uses when their module is loaded, as "<root>.<path>" like NEEDS.
-- One missing doesn't switch EZ-CDM off; the call behind it answers nil and the
-- drawer keeps its plain header. The info panel's fold tab (DaylightUI_InfoPanel,
-- an addon of its own a player can turn off) lends its look and slide.
Bridge.OPTIONAL = {
    "InfoPanel.Panel.TAB",
    "InfoPanel.Panel.ARROW",
    "InfoPanel.Panel.ARROW_COLOR",
    "InfoPanel.Panel.SLIDE",
    "InfoPanel.Panel.XP_BORDER",
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

-- Whether a path resolves to what its form promises: "<module>.<Part>" is a table,
-- a last part in capitals is a value, and anything else is a function.
local function present(path)
    local v = Bridge.Resolve(path)
    local _, dots = path:gsub("%.", "")
    if dots == 1 and path:match("^[^%.]+") ~= "DaylightUI" then return type(v) == "table" end
    if isValueName(path:match("([^%.]+)$")) then return v ~= nil end
    return type(v) == "function"
end

local function missingFrom(list)
    local out = {}
    for _, path in ipairs(list) do
        if not present(path) then out[#out + 1] = path end
    end
    return out
end

-- Every NEEDS entry this Daylight UI lacks, in NEEDS order.
function Bridge.Missing() return missingFrom(Bridge.NEEDS) end
-- Every OPTIONAL entry it lacks, in order.
function Bridge.MissingOptional() return missingFrom(Bridge.OPTIONAL) end

-- Whether Daylight UI's Cooldown Manager is running (set at its login).
function Bridge.CdmOn()
    local CD = Bridge.Resolve("ActionBars.Cooldowns")
    return type(CD) == "table" and CD.enabled == true
end

-- The public API version EZ-CDM is built on (EZ-CDM.lua's needs). 1.14 brings the
-- Cooldown Manager's buff moments and state.
Bridge.API_NEEDS = { 1, 14 }

-- The public API's version, major and minor, or nil without Daylight UI.
function Bridge.ApiVersion()
    local API = _G.DaylightUI and _G.DaylightUI.API
    if type(API) ~= "table" or type(API.major) ~= "number" or type(API.minor) ~= "number" then return nil end
    return API.major, API.minor
end

-- Whether the public API is the one EZ-CDM needs: same major, minor as new or newer.
function Bridge.ApiFits()
    local major, minor = Bridge.ApiVersion()
    return major == Bridge.API_NEEDS[1] and minor >= Bridge.API_NEEDS[2]
end

-- True when the API fits, every internal is there and the Cooldown Manager is on.
function Bridge.Ready()
    return Bridge.ApiFits() and #Bridge.Missing() == 0 and Bridge.CdmOn()
end

-- The one chat line, or nil when ready.
function Bridge.OffLine()
    if not Bridge.ApiFits() then
        local major, minor = Bridge.ApiVersion()
        return string.format("EZ-CDM is off: it needs Daylight UI's API %d.%d (this one is %s).",
            Bridge.API_NEEDS[1], Bridge.API_NEEDS[2], major and (major .. "." .. minor) or "unknown")
    end
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
-- An API too old gets no line of EZ-CDM's. Daylight UI printed its own "needs a
-- newer DaylightUI" as EZ-CDM registered (Plugins.Fits).
function Bridge.Check()
    local line = Bridge.OffLine()
    Bridge.off = line ~= nil
    if line and Bridge.ApiFits() and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) end
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

-- Whether a placed piece's buff can be told up or down: true, false, or nil when
-- the last pass didn't draw it.
function Bridge.Tracked(id) return call("ActionBars.CdmRows.Tracked", id) end
-- Whether a key is Daylight UI's own piece ("s<id>", "i<id>", named families). Its
-- track values differ from a game piece's (Bridge.SetTrack against Bridge.SetSpellValue).
function Bridge.IsCustom(key) return call("ActionBars.CdmCustom.Is", key) and true or false end
-- What a piece shows ("both", "cooldown", "buff", "totem"), or nil for a plain
-- cooldown. piece is its saved table (or a draft one), nil when not placed.
function Bridge.Shows(key, piece) return call("ActionBars.CdmOwn.Track", key, piece) end
-- The game's or Daylight UI's entry for a key ({ kind, aura, ... }), or nil when the
-- spell isn't known.
function Bridge.Entry(key) return call("ActionBars.CdmOwn.Entry", key) end
-- The spell a key casts, or nil (a weapon enchant has none).
function Bridge.SpellOf(key) return call("ActionBars.CdmOwn.SpellOf", key) end
-- A piece's option, or its default.
function Bridge.Option(piece, field) return call("ActionBars.CdmEffects.Get", piece, field) end

-- A group option's default, or nil.
function Bridge.ChainDefault(field)
    local t = Bridge.Resolve("ActionBars.CdmData.CHAIN")
    if type(t) == "table" then return t[field] end
end
-- Forms, stances and stealth by class token ({ key, name, ... }, saved as hideIn<key>).
function Bridge.Forms() return Bridge.Resolve("ActionBars.CdmEffects.FORMS") end
-- The sound list: values, order, titles (headings in order are "head:" keys).
function Bridge.SoundChoices() return call("DaylightUI.Sound.AlertChoices") end

-- The first piece of key's group on talent set g's layout (key itself when free).
function Bridge.Root(key, g)
    local set = Bridge.Layout(g)
    if type(set) == "table" then return call("ActionBars.CdmData.Root", set, key) end
end
-- key and every piece hanging off it, key first.
function Bridge.Subtree(key, g)
    local set = Bridge.Layout(g)
    if type(set) == "table" then return call("ActionBars.CdmData.Subtree", set, key) end
end
-- A piece's name as Daylight UI's editor shows it, or nil.
function Bridge.SpellName(key) return call("ActionBars.CdmEditor.SpellName", key) end
-- Whether Daylight UI's own piece picks what it shows (Bridge.SetTrack takes it).
function Bridge.CanTrack(key) return call("ActionBars.CdmCustom.CanTrack", key) == true end
-- Every spell id a piece answers to, { [id] = true }: its spell, ranks and linked
-- ids. A cast of one of them starts its recast clock (CdmAuras.lua:1194-1211).
function Bridge.SpellIDs(key) return call("ActionBars.CdmAuras.SpellIDs", key) end
-- Whether a piece is another class's buff on you: the tray's Group buffs
-- (CdmCustom.IsGroup). The player never casts it, so it is no proc of theirs.
function Bridge.IsGroup(key) return call("ActionBars.CdmCustom.IsGroup", key) == true end
-- Whether a piece's spell is a totem. A totem picks what it shows from its own rows,
-- not the card's What it shows (CdmCard.lua:242-256).
function Bridge.IsTotem(key)
    local sid = Bridge.SpellOf(key)
    return sid ~= nil and call("ActionBars.CdmCustom.Totem", sid) ~= nil
end

-- A look key's value for a placed piece as the card reads it (CdmCard.lua:219-225):
-- its own, its group's, else Daylight UI's fallback.
function Bridge.PieceLook(key, field)
    local set = Bridge.Layout()
    local v
    if type(set) == "table" and type(set.pieces) == "table" and set.pieces[key] then
        v = call("ActionBars.CdmData.PieceLook", set, key, field)
    end
    if v == nil then v = Bridge.LookDefault(field) end
    return v
end
-- What a look key shows before it's set (Card.Fallback): low false, lowAt 3 s,
-- lowColor Daylight UI's BAD ink...
function Bridge.LookDefault(field) return call("ActionBars.CdmCard.Fallback", field) end

-- The glow styles the card's Style row offers, { { key, label } }, in its order:
-- Ring, Daylight UI's default, then API.GlowStyles()'s (CdmCard.lua:490-495).
function Bridge.GlowStyles()
    local rows = Bridge.Resolve("ActionBars.CdmCard.ROWS")
    for _, row in ipairs(type(rows) == "table" and type(rows.look) == "table" and rows.look or {}) do
        local item = row.item
        if type(item) == "table" and item.key == "cdm.card.glowStyle" and type(item.choices) == "function" then
            local values, order = item.choices()
            local out = {}
            for _, k in ipairs(type(order) == "table" and order or {}) do
                out[#out + 1] = { key = k, label = values[k] or k }
            end
            return out
        end
    end
end

-- ---------------------------------------------------------------------
-- Writes. Each refuses in combat and while switched off, and returns true (or
-- the new thing) on success, else false and a reason:
--   "combat"    in combat
--   "off"       an internal is missing or the Cooldown Manager is off
--   "set"       not a talent set number
--   "unsaved"   no profile could be saved (the class isn't known yet)
--   "rejected"  Daylight UI refused it (no such piece, a bad value, or an option
--               the piece's shape doesn't take)
-- g is the talent set (current when nil). Nothing shows until the editor redraws
-- (Bridge.EditorChanged).
-- ---------------------------------------------------------------------

local function canWrite()
    if InCombatLockdown() then return false, "combat" end
    if not Bridge.Ready() then return false, "off" end
    return true
end

-- Whether g is a talent set number.
local function isSet(g)
    return type(g) == "number" and g >= 1 and g <= (Bridge.SetCount() or 0) and g % 1 == 0
end

-- Talent set g's saved layout, made a profile first if it has none (Daylight UI's
-- editor does this before any change).
local function savedSet(g)
    local ok, why = canWrite()
    if not ok then return nil, why end
    g = g or Bridge.CurrentIndex()
    if not isSet(g) then return nil, "set" end
    local set = call("ActionBars.CdmData.Ensure", g)
    if not Bridge.ProfileOf(g) then return nil, "unsaved" end
    return set
end

-- Talent set g's saved profile id, made first if it has none, as savedSet does
-- before a write. Returns nil and a reason when it can't be.
function Bridge.SavedProfile(g)
    local set, why = savedSet(g)
    if not set then return nil, why end
    return Bridge.ProfileOf(g)
end

local function answer(done)
    if done then return true end
    return false, "rejected"
end

-- One spell option (CdmData.SPELL_FIELDS). A value equal to the default is removed.
-- For a game piece "track" is both / cooldown / buff / totem.
function Bridge.SetSpellValue(g, key, field, value)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetSpellValue", set, key, field, value))
end

-- One look key of a piece, its own (CdmData.LOOK_FIELDS), as the card's Look tab
-- writes it (CdmCard.lua:157-160). Daylight UI keeps even a value equal to its
-- fallback, so a key goes back by writing Bridge.LookDefault.
function Bridge.SetLook(g, key, field, value)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetLook", set, key, field, value, false))
end

-- What Daylight UI's own piece (Bridge.IsCustom) shows: cooldown, aura or both.
function Bridge.SetTrack(g, key, track)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetTrack", set, key, track))
end

-- One group option (CdmData.CHAIN_FIELDS), set from any piece in the group onto the
-- group, as Daylight UI's Group tab does (CdmCard.lua:165-175).
function Bridge.SetChainValue(g, key, field, value)
    local set, why = savedSet(g)
    if not set then return false, why end
    return answer(call("ActionBars.CdmData.SetChainValue", set, key, field, value))
end

-- Copies profile from into a new one (named name, or its name made unique) and
-- picks the copy for talent set g. g's own layout isn't saved first, so a set with
-- none gets no extra profile. Every other profile is left as it was. Returns the
-- new profile's id.
function Bridge.CopyAndAssign(g, from, name)
    local ok, why = canWrite()
    if not ok then return false, why end
    g = g or Bridge.CurrentIndex()
    if not isSet(g) then return false, "set" end
    if not Bridge.Profile(from) then return false, "rejected" end
    local id = call("ActionBars.CdmData.CopyProfile", from, name)
    if not id then return false, "rejected" end
    if not call("ActionBars.CdmData.Assign", g, id) then return false, "rejected" end
    return id
end

-- Talent set g uses profile id from now on. Every profile is left as it was.
function Bridge.Assign(g, id)
    local ok, why = canWrite()
    if not ok then return false, why end
    g = g or Bridge.CurrentIndex()
    if not isSet(g) then return false, "set" end
    if not Bridge.Profile(id) then return false, "rejected" end
    return answer(call("ActionBars.CdmData.Assign", g, id))
end

-- Makes a new empty profile for the player's class (named name, made unique; Daylight
-- UI's own name when empty) and picks it for talent set g. Every other profile is
-- left as it was. Returns the new profile's id.
function Bridge.NewAndAssign(g, name)
    local ok, why = canWrite()
    if not ok then return false, why end
    g = g or Bridge.CurrentIndex()
    if not isSet(g) then return false, "set" end
    local class = Bridge.MyClass()
    if not class then return false, "unsaved" end
    local id = call("ActionBars.CdmData.NewProfile", name, class)
    if not id then return false, "rejected" end
    if not call("ActionBars.CdmData.Assign", g, id) then return false, "rejected" end
    return id
end

-- ---------------------------------------------------------------------
-- Looks, passed straight through.
-- ---------------------------------------------------------------------

-- Daylight UI's frame shell on frame (the editor's tray wears it).
function Bridge.Shell(frame, opts) return call("DaylightUI.Style.Shell", frame, opts) end
-- Daylight UI's crop for a square spell icon texture.
function Bridge.CropIcon(tex) return call("DaylightUI.Style.CropIcon", tex) end

-- ---------------------------------------------------------------------
-- Window parts (Windows/Frame.lua, Windows/Parts.lua), passed straight through.
-- ---------------------------------------------------------------------

-- The window kit's side margin in px.
function Bridge.Edge() return Bridge.Resolve("DaylightUI.Win.EDGE") end

-- Daylight UI's window content (Windows/Parts.lua): a scrolling column of blocks
-- wearing W.Scroll (s:Begin, s:Section, s:Line, s:Piece, s:End). inset: top,
-- bottom, side.
function Bridge.Stack(page, inset) return call("DaylightUI.Win.Parts.Stack", page, inset) end
-- The list's remove button: a small rounded box with an X that turns red on hover.
-- The caller places it and sets OnClick.
function Bridge.RemoveButton(parent) return call("DaylightUI.Widgets.DeleteButton", parent) end
-- A piece key's icon as Daylight UI's editor shows it (a question mark when unknown).
function Bridge.SpellTexture(key) return call("ActionBars.CdmEditor.SpellTexture", key) end
-- The game's color picker as Daylight UI opens it, starting at { r, g, b }.
-- onChange({ r, g, b }) runs on each pick (once on release for a drag), and with
-- the start color on Cancel. alpha adds the opacity bar, and colors come as
-- { r, g, b, a }, as the card's colors with alpha (CdmCard.lua:688).
function Bridge.PickColor(start, onChange, alpha)
    return call("DaylightUI.Widgets.OpenColorPicker", start, onChange, alpha == true)
end
-- The faint 1 px divider Daylight UI's windows draw between areas. The caller
-- anchors it.
function Bridge.Rule(parent, vertical) return call("DaylightUI.Win.Parts.Rule", parent, vertical) end
-- The window parts' gap between blocks in px.
function Bridge.Gap() return Bridge.Resolve("DaylightUI.Win.Parts.GAP") end

-- Daylight UI's choice cards, as its setup guide lays out one choice among several:
-- one card per key, the current one ticked. opts: keys, width, cols, height,
-- label(k), sub(k), get(), set(k). Returns a frame with .cards[k], .height and
-- Refresh().
function Bridge.Picker(parent, opts) return call("DaylightUI.InstallerCards.Picker", parent, opts) end

-- ---------------------------------------------------------------------
-- Daylight UI's CDM editor
-- ---------------------------------------------------------------------

-- Opens the editor on talent set g (current when nil). An open editor shows g's
-- layout again, as Daylight UI does after an import. Daylight UI refuses in combat
-- and while its Cooldown Manager is off, with its own chat line. Returns true when open.
function Bridge.OpenEditor(g)
    return call("ActionBars.CdmEditor.Open", g or Bridge.CurrentIndex()) == true
end

-- The editor functions EZ-CDM follows. after(...) runs after Daylight UI's own,
-- through Daylight UI's public hook (API.For(...).Hook); an error in it names
-- EZ-CDM. Returns the hook's handle, or false.
Bridge.EDITOR_HOOKS = { Open = true, Close = true, Select = true, Draw = true, EndTrayMove = true }
local me
function Bridge.HookEditor(name, after)
    local Ed = Bridge.Resolve("ActionBars.CdmEditor")
    if not (Bridge.EDITOR_HOOKS[name] and type(Ed) == "table") then return false end
    me = me or _G.DaylightUI.API.For(addonName)
    return me.Hook(Ed, name, after)
end

-- Whether the editor is open.
function Bridge.EditorOpen() return call("ActionBars.CdmEditor.IsOpen") == true end
-- The piece picked in the editor, or nil.
function Bridge.Selected() return call("ActionBars.CdmEditor.Selected") end
-- Whether a + on the picked piece waits for a spell (the card steps aside then).
function Bridge.EditorAttach() return call("ActionBars.CdmEditor.Attach") ~= nil end
-- The editor's spell tray and the full-screen frame it sits on, once built.
function Bridge.EditorTray() return call("ActionBars.CdmEditor.Tray") end
function Bridge.EditorOverlay() return call("ActionBars.CdmEditor.Overlay") end
-- The room the editor keeps clear at the screen's top for its title and banner.
function Bridge.EditorTop() return Bridge.Resolve("ActionBars.CdmCard.TOP") end
-- After a write: the live layout follows, then the editor and its card redraw, as
-- after a change on Daylight UI's own card.
function Bridge.EditorChanged() return call("ActionBars.CdmEditor.Changed") end

-- Daylight UI's text link at size ("small", "body"...): quiet text whose underline
-- grows from the left on hover. own keeps the caller's text color, a little dim at
-- rest. b.SetLabel(text) sizes it; the caller sets OnClick.
function Bridge.Link(parent, size, own)
    local sizes = Bridge.Resolve("DaylightUI.Style.SIZE")
    return call("DaylightUI.Widgets.Link", parent, type(sizes) == "table" and sizes[size] or nil,
        own and { own = true } or nil)
end
-- Daylight UI's chip: a small rounded pill that lights on hover and fills with
-- the accent while on (b.SetOn). b.FitWidth() sizes it; the caller sets OnClick.
function Bridge.Chip(parent, text) return call("DaylightUI.Widgets.Chip", parent, text) end

-- ---------------------------------------------------------------------
-- The info panel's fold tab and slide (DaylightUI_InfoPanel/Panel.lua)
-- ---------------------------------------------------------------------

-- The fold tab's measures, or nil while the info panel isn't loaded:
-- { tab = { thickness, length }, arrow = chevron px, color = { r, g, b },
--   slide = seconds, border = the tab's borderPx for API.Skin }.
function Bridge.FoldTab()
    if #Bridge.MissingOptional() > 0 then return nil end
    return {
        tab = Bridge.Resolve("InfoPanel.Panel.TAB"),
        arrow = Bridge.Resolve("InfoPanel.Panel.ARROW"),
        color = Bridge.Resolve("InfoPanel.Panel.ARROW_COLOR"),
        slide = Bridge.Resolve("InfoPanel.Panel.SLIDE"),
        border = Bridge.Resolve("InfoPanel.Panel.XP_BORDER"),
    }
end

-- Daylight UI's slide: s.p eases from 0 (in) to 1 (out) and apply(s) runs on each
-- step. s:To(goal) slides, s:Jump(goal) goes straight there. opts: p, dur.
function Bridge.Slider(apply, opts) return call("DaylightUI.Motion.Slider", apply, opts) end

-- A shelled frame's border in screen px, as the info panel tucks its tab behind one.
function Bridge.BorderPx(frame)
    local px = call("DaylightUI.Style.BorderPx", frame)
    if type(px) ~= "number" then return 0 end
    return call("DaylightUI.Pixel.Px", frame, px) or 0
end

-- ---------------------------------------------------------------------
-- The up glow inside a holder's client aura buttons (CdmAuras, CdmEffects)
-- ---------------------------------------------------------------------

-- What draws a placed piece since the last pass: "game", "aura icon", "aura and
-- cooldown icon", "aura bar" and so on, or nil.
function Bridge.DrawnBy(key) return call("ActionBars.CdmRows.DrawnBy", key) end

-- Whether a piece's aura icon holder shows its aura in the client's own buttons:
-- true when it made client containers (h.containers, CdmAuras.lua:385), false when
-- Daylight UI draws the piece on its own face instead (h.face, made at :414, 422,
-- 449 and 466 for the pet, a weapon enchant, a summon and a debuff on you, never
-- with a container). nil with no holder yet, or none of either (a holder still
-- waiting for a fight to end, CdmAuras.lua:398-406).
function Bridge.ClientButtons(key)
    local h = call("ActionBars.CdmAuras.Frame", key)
    if type(h) ~= "table" then return nil end
    if type(h.containers) == "table" and #h.containers > 0 then return true end
    if h.face ~= nil then return false end
    return nil
end

-- Whether the client has auras locked now: in combat or under its restrictions.
-- A client aura button and everything on it refuse addon code then.
function Bridge.Restricted() return call("DaylightUI.Restricted") == true end
-- Runs fn now, or once restrictions lift. A later call with the same key replaces
-- a waiting one.
function Bridge.AfterRestrictions(fn, key) return call("DaylightUI.AfterRestrictions", fn, key) end

-- Whether the game holds auras secret now (C_Secrets.ShouldAurasBeSecret). A client
-- aura button refuses addon code then (DenyTaintedAccessWhenAurasAreSecret), also
-- between fights in a PvP match.
function Bridge.AurasSecret()
    local S = _G.C_Secrets
    if type(S) ~= "table" or type(S.ShouldAurasBeSecret) ~= "function" then return false end
    local yes = S.ShouldAurasBeSecret()
    if type(issecretvalue) == "function" and issecretvalue(yes) then return true end
    return yes == true
end

-- Runs fn(...) through Daylight UI's SafeCall: an error goes to its bug report.
-- Returns whether it ran without one.
function Bridge.SafeCall(fn, ...) return call("DaylightUI.SafeCall", fn, ...) == true end

-- Daylight UI's own question box (Options/Widgets.lua W.Ask) asking for a /reload.
-- Its Reload is a secure /reload button, since addon code can't reload on this
-- client, and it waits out a fight. onLater runs on the other answer.
function Bridge.AskReload(key, text, yes, later, onLater)
    return call("DaylightUI.Widgets.Ask", { key = key, text = text, yes = yes, no = later, reload = true,
                                            onNo = onLater })
end

-- Daylight UI's ring glow, the game's proc loop it draws (CdmEffects.lua:184-189):
-- { atlas, rows, columns, frames, loop = seconds per turn, pad = how far it
-- reaches past each edge, as a share of the item's short side }. nil when any is gone.
function Bridge.RingArt()
    local art = {
        atlas = Bridge.Resolve("ActionBars.CdmEffects.GLOW_ATLAS"),
        rows = Bridge.Resolve("ActionBars.CdmEffects.GLOW_ROWS"),
        columns = Bridge.Resolve("ActionBars.CdmEffects.GLOW_COLUMNS"),
        frames = Bridge.Resolve("ActionBars.CdmEffects.GLOW_FRAMES"),
        loop = Bridge.Resolve("ActionBars.CdmEffects.GLOW_LOOP"),
        pad = Bridge.Resolve("ActionBars.CdmEffects.GLOW_PAD"),
    }
    if type(art.atlas) ~= "string" then return nil end
    for _, k in ipairs({ "rows", "columns", "frames", "loop", "pad" }) do
        if type(art[k]) ~= "number" then return nil end
    end
    return art
end

-- Paints a texture in the accent, as Daylight UI's ring takes it: a gradient
-- accent runs across it, else the one color.
function Bridge.PaintAccent(tex) return call("DaylightUI.Style.PaintAccent", tex, 1) end

-- fn(btn, key, size) runs inside the client's initializeFrame for each button an
-- aura icon holder (CdmAuras) is given, after Daylight UI dresses it, the one time
-- the button isn't locked under restrictions. key is the holder's piece and size
-- the button's side in px, as Daylight UI sets it (h.size), or nil. Hooked on
-- CdmEffects.MakeSlide, the last call of that dressing, through Daylight UI's
-- public hook. Aura bars (CdmBars) call it too and are skipped. Returns the hook's
-- handle, or false.
function Bridge.HookAuraButtons(fn)
    local Fx = Bridge.Resolve("ActionBars.CdmEffects")
    if type(Fx) ~= "table" or type(Fx.MakeSlide) ~= "function" then return false end
    me = me or _G.DaylightUI.API.For(addonName)
    return me.Hook(Fx, "MakeSlide", function(btn, h)
        local key = type(h) == "table" and h.id or nil
        if key ~= nil and call("ActionBars.CdmAuras.Frame", key) == h then
            local size = h.size
            fn(btn, key, type(size) == "number" and size or nil)
        end
    end)
end

-- ---------------------------------------------------------------------
-- The recast clock (CdmAuras, CdmEffects)
-- ---------------------------------------------------------------------

-- The clock functions EZ-CDM wraps, each by the table that holds it. Daylight UI
-- calls each by table lookup (CdmAuras.lua:1316, 1335; CdmRows.lua:620, 624, 856,
-- 883), so a wrap sees every call.
--   ClipDue(h, sid)  whether it's time to recast, and if not, when
--   Clip(h, sid)     the pass's answer for one holder or watch
--   ClipGlows(p)     whether a piece's pass runs the clock
--   Told(h, up)      what the game's item says, up or down; a down drops the clock
-- Bridge.Clip calls Clip as the pass does, for a pass that skips it on a "down".
-- h.id is the piece key and h.endsAt the end the clock keeps, both plain numbers
-- Daylight UI sets itself (CdmAuras.lua:518, 1128). h.watch is true on the watch of
-- a piece the game's item draws (:518).
Bridge.CLOCK_WRAPS = { ClipDue = "ActionBars.CdmAuras", Clip = "ActionBars.CdmAuras",
                       ClipGlows = "ActionBars.CdmEffects", Told = "ActionBars.CdmAuras" }

-- The clock's answer for holder or watch h now, as a pass asks it (CdmAuras.Clip,
-- wraps included): due, and when not, a wake for the moment it will be.
function Bridge.Clip(h, sid) return call("ActionBars.CdmAuras.Clip", h, sid) end

-- Wraps name, listed in list, with fn(original, ...) through Daylight UI's public
-- wrap (API.For(...).Wrap). A wrap that errors falls back to Daylight UI's own.
-- Returns the handle, or false.
local function wrapListed(list, name, fn)
    local path = list[name]
    local tbl = path and Bridge.Resolve(path)
    if type(tbl) ~= "table" or type(tbl[name]) ~= "function" or type(fn) ~= "function" then return false end
    me = me or _G.DaylightUI.API.For(addonName)
    return me.Wrap(tbl, name, fn)
end

-- Wraps one of the clock functions (Bridge.CLOCK_WRAPS).
function Bridge.WrapClock(name, fn) return wrapListed(Bridge.CLOCK_WRAPS, name, fn) end

-- Plays a sound key from Daylight UI's list (Bridge.SoundChoices), as its own
-- piece sounds do (CdmEffects.lua:727-734).
function Bridge.PlayAlert(key) return call("DaylightUI.Sound.Alert", key) end

-- ---------------------------------------------------------------------
-- A glow style per moment (CdmEffects)
-- ---------------------------------------------------------------------

-- The glow functions EZ-CDM wraps. Daylight UI calls each by table lookup
-- (CdmEffects.lua:377; CdmRows.lua:982, 987, 989), so a wrap sees every call.
--   GlowStyle(button)                    the style a lit glow takes; button is the
--                                        piece's saved table, nil on an aura holder
--   SetDown(item, piece, isDown, isDue)  what a pass tells an item; it lights the
--                                        item's glow before it returns
--   EndPass(told)                        after a pass; items not in told forget it
Bridge.GLOW_WRAPS = { GlowStyle = "ActionBars.CdmEffects", SetDown = "ActionBars.CdmEffects",
                      EndPass = "ActionBars.CdmEffects" }

-- Wraps one of the glow functions (Bridge.GLOW_WRAPS).
function Bridge.WrapGlow(name, fn) return wrapListed(Bridge.GLOW_WRAPS, name, fn) end

-- ---------------------------------------------------------------------
-- An aura's length (CdmAuras, CdmCustom)
-- ---------------------------------------------------------------------

local function seconds(v)
    if type(v) ~= "number" or (type(issecretvalue) == "function" and issecretvalue(v)) then return nil end
    return v > 0 and v or nil
end

-- How long a piece's aura lasts as its aura icon holder last read it (h.auraLasts,
-- set from a plain read, CdmAuras.lua:933), or nil before a read this session.
function Bridge.AuraLasts(key)
    local h = call("ActionBars.CdmAuras.Frame", key)
    return type(h) == "table" and seconds(h.auraLasts) or nil
end

-- How long a piece's aura lasts by the game's data (CdmSpells.FACTS through
-- CdmCustom.Fact), over every id it answers to, or nil when the data has none.
function Bridge.FactLasts(key)
    local ids = Bridge.SpellIDs(key)
    local list = {}
    for id in pairs(type(ids) == "table" and ids or {}) do
        if type(id) == "number" then list[#list + 1] = id end
    end
    table.sort(list)
    local sid = Bridge.SpellOf(key)
    if type(sid) == "number" then table.insert(list, 1, sid) end
    for _, id in ipairs(list) do
        local fact = call("ActionBars.CdmCustom.Fact", id)
        local n = type(fact) == "table" and seconds(fact.lasts) or nil
        if n then return n end
    end
end

-- ---------------------------------------------------------------------
-- The Cooldown Manager's buff moments (public, API.md 1.14)
-- ---------------------------------------------------------------------

-- up(spellID, key) on CooldownBuffUp and down(spellID, key) on CooldownBuffDown: a
-- piece's buff or debuff turns up or down, as the game's own item says, plain in a
-- fight. key is the piece's key as a string. Returns true when both are registered,
-- false on an API older than 1.14.
function Bridge.OnBuff(up, down)
    local API = _G.DaylightUI and _G.DaylightUI.API
    if not (Bridge.ApiFits() and type(API.On) == "function") then return false end
    local a = API.On("CooldownBuffUp", up, addonName)
    local b = API.On("CooldownBuffDown", down, addonName)
    return a ~= nil and b ~= nil
end

-- What a shown piece's buff reads now (API.CooldownState): true up, false down, or
-- nil when the piece isn't on show or the game won't say. Then what draws it.
function Bridge.BuffState(key)
    local API = _G.DaylightUI and _G.DaylightUI.API
    if key == nil or not (Bridge.ApiFits() and type(API.CooldownState) == "function") then return nil end
    local state = API.CooldownState(tostring(key))
    if type(state) ~= "table" then return nil end
    local up = state.buffUp
    if type(up) ~= "boolean" then up = nil end
    return up, state.drawnBy
end

-- Asks Daylight UI for a pass on the next frame (CdmRows.Refresh, coalesced).
function Bridge.Refresh() return call("ActionBars.CdmRows.Refresh") end

local API = _G.DaylightUI and _G.DaylightUI.API
if type(API) == "table" and type(API.On) == "function" then
    API.On("Login", Bridge.Check, "EZ-CDM")
end
