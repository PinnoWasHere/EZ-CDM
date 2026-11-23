local addonName, ns = ...

-- The start block beside Daylight UI's CDM editor tray, shown whenever the editor
-- is open, at the tray's height. "EZ-Start Blank" asks for a name, then makes a new
-- empty layout. "EZ-Load Layout" turns the block into the class's layouts, picked
-- on a copy while "Work on a copy" is on. The open editor shows the new layout at
-- once. /ezcdm (or /dui ezcdm) opens Daylight UI's editor. Every look is Daylight
-- UI's: the setup guide's choice cards, its window parts and API.md calls, through
-- ns.Bridge. The words are Grammar.WORDING's.

local Bridge = ns.Bridge
local API = DaylightUI.API
local WORDS = ns.Grammar.WORDING.start

local Start = {}
ns.Start = Start

-- Debug handle for an in-game check.
EZCDM_Start = Start

Start.W = 240
Start.COMBAT_LINE = "EZ-CDM: you're in combat. Open it after the fight."
Start.REFUSED_LINE = "EZ-CDM: Daylight UI didn't take that layout."

Start.CARDS = { "blank", "load" }
Start.LABELS = { blank = WORDS.blank, load = WORDS.load }
Start.SUBS = {
    blank = "A new empty layout for this talent set.",
    load = "Pick one of your class's layouts.",
}
Start.BACK = "Back"
Start.COPY = "Work on a copy"
Start.EMPTY = "Your class has no layouts yet."
Start.IN_USE = "In use"

-- A card's height: compact, under the setup guide's own 64.
Start.CARD_H = 32

local blk          -- the block, built on the editor's first open
local on = false   -- attached to an open editor
local parts = {}   -- picker, list, back, copy, copyText, stack, name, input, create, nameBack, noName
local mode         -- "load" while the layout list shows, "name" while a new layout waits for its name
local copy = true  -- "Work on a copy"
local unnamed      -- the last Create had no name

local function pad() return Bridge.Gap() or 0 end

local function say(text)
    if text and DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(text) end
end

-- One chat line for a refusal.
local function refuse(why)
    if why == "combat" then say(Start.COMBAT_LINE)
    elseif why == "off" then say(Bridge.OffLine())
    else say(Start.REFUSED_LINE) end
    return false, why
end

-- ---------------------------------------------------------------------
-- What the choices do
-- ---------------------------------------------------------------------

-- Shows talent set g's new layout in the editor, and the cards again.
local function edit(g)
    mode = nil
    Bridge.OpenEditor(g)
    Start.Refresh()
    return true
end

-- A click here puts EZ-CDM's frames above Daylight UI's card.
local function lift() ns.Drawer.Lift() end

-- A new empty layout named name for the talent set shown. Daylight UI makes the
-- name unique. An empty name is refused, and the block says so.
function Start.Blank(name)
    name = type(name) == "string" and name:match("^%s*(.-)%s*$") or ""
    if name == "" then
        unnamed = true
        Start.Refresh()
        return false, "name"
    end
    local g = Bridge.CurrentIndex()
    local id, why = Bridge.NewAndAssign(g, name)
    if not id then return refuse(why) end
    return edit(g)
end

-- Layout id for the talent set shown, as a copy while "Work on a copy" is on.
function Start.Load(id)
    local g = Bridge.CurrentIndex()
    local done, why
    if copy then done, why = Bridge.CopyAndAssign(g, id) else done, why = Bridge.Assign(g, id) end
    if not done then return refuse(why) end
    return edit(g)
end

function Start.Copy() return copy end
function Start.SetCopy(onOff)
    copy = onOff and true or false
    if parts.copy then parts.copy.SetOn(copy) end
end

-- "cards", "load" or "name".
function Start.Mode() return mode or "cards" end

-- Turns the block into the layout list, or back to the cards.
function Start.ShowLoad(show)
    mode = show ~= false and "load" or nil
    Start.Refresh()
end

-- Turns the block into the name box for a new layout, or back to the cards.
function Start.ShowName(show)
    mode = show ~= false and "name" or nil
    unnamed = nil
    if parts.input then parts.input:SetText("") end
    Start.Refresh()
    if mode == "name" and parts.input then parts.input:SetFocus() end
end

-- ---------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------

-- A page over the whole block.
local function page()
    local f = CreateFrame("Frame", nil, blk)
    f:SetAllPoints(blk)
    return f
end

local function buildList()
    local list = page()
    local edge = Bridge.Edge()
    local back = API.Button(list, Start.BACK, nil)
    back.FitWidth()
    back:SetPoint("TOPLEFT", list, "TOPLEFT", edge, -pad())
    back:SetScript("OnClick", function()
        lift()
        Start.ShowLoad(false)
    end)
    -- "Work on a copy" on its own row: Daylight UI's switch, its words beside it,
    -- held inside the block's sides.
    local sw = API.Switch(list)
    sw:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -pad())
    sw:SetScript("OnClick", function()
        lift()
        Start.SetCopy(not copy)
    end)
    local text = API.Text(list, "body", "LEFT")
    text:SetPoint("LEFT", sw, "RIGHT", pad(), 0)
    text:SetPoint("RIGHT", list, "RIGHT", -edge, 0)
    text:SetText(Start.COPY)
    local ink = API.Colors().TEXT
    text:SetTextColor(ink[1], ink[2], ink[3])
    local top = pad() + (back:GetHeight() or 0) + pad() + (sw:GetHeight() or 0) + pad()
    parts.list, parts.back, parts.copy, parts.copyText = list, back, sw, text
    parts.stack = Bridge.Stack(list, { top = top, bottom = pad() })
end

-- The name box: Daylight UI's input, Back and Create under it, and the refusal.
local function buildName()
    local f = page()
    local edge = Bridge.Edge()
    local input = API.Input(f, { hint = WORDS.name })
    input:SetPoint("TOPLEFT", f, "TOPLEFT", edge, -pad())
    input:SetPoint("TOPRIGHT", f, "TOPRIGHT", -edge, -pad())
    input:HookScript("OnEnterPressed", function() Start.Blank(input:GetText()) end)
    local back = API.Button(f, Start.BACK, nil)
    back.FitWidth()
    back:SetPoint("TOPLEFT", input, "BOTTOMLEFT", 0, -pad())
    back:SetScript("OnClick", function()
        lift()
        Start.ShowName(false)
    end)
    local create = API.Button(f, WORDS.create, nil)
    create.FitWidth()
    create:SetPoint("TOPRIGHT", input, "BOTTOMRIGHT", 0, -pad())
    create:SetScript("OnClick", function()
        lift()
        Start.Blank(input:GetText())
    end)
    local note = API.Text(f, "small", "LEFT")
    note:SetPoint("TOPLEFT", back, "BOTTOMLEFT", 0, -pad())
    note:SetPoint("RIGHT", f, "RIGHT", -edge, 0)
    note:SetText(WORDS.noName)
    local bad = API.Colors().BAD
    note:SetTextColor(bad[1], bad[2], bad[3])
    parts.name, parts.input, parts.create, parts.nameBack, parts.noName = f, input, create, back, note
end

local function build()
    if blk then return blk end
    local o, tray = Bridge.EditorOverlay(), Bridge.EditorTray()
    if not (o and tray) then return nil end
    blk = CreateFrame("Frame", nil, o)
    -- The tray's own level, as the drawer.
    blk:SetFrameLevel(tray:GetFrameLevel())
    -- A click here never reaches the overlay, where it would clear the pick.
    blk:EnableMouse(true)
    blk:SetWidth(Start.W)
    Bridge.Shell(blk, {})
    local edge = Bridge.Edge()
    -- The cards at their own compact height, stacked at the block's top.
    parts.picker = Bridge.Picker(blk, {
        keys = Start.CARDS, width = Start.W - 2 * edge, cols = 1, height = Start.CARD_H,
        label = function(k) return Start.LABELS[k] end,
        get = function() return nil end,
        set = function(k)
            lift()
            if k == "blank" then Start.ShowName(true) else Start.ShowLoad(true) end
        end,
    })
    parts.picker:SetPoint("TOPLEFT", blk, "TOPLEFT", edge, -pad())
    -- The card's tooltip says what each one does.
    for _, k in ipairs(Start.CARDS) do parts.picker.cards[k].tooltip = { Start.LABELS[k], Start.SUBS[k] } end
    buildList()
    buildName()
    blk:Hide()
    return blk
end

-- ---------------------------------------------------------------------
-- Placing: right of the tray, or left of it when the screen has no room there
-- ---------------------------------------------------------------------

local function place()
    local tray, o = Bridge.EditorTray(), Bridge.EditorOverlay()
    local gap = pad()
    local tl, tr, ol, oright = tray:GetLeft(), tray:GetRight(), o:GetLeft(), o:GetRight()
    local right = true
    if type(tl) == "number" and type(tr) == "number" and type(ol) == "number" and type(oright) == "number" then
        right = tr + gap + Start.W <= oright or tl - gap - Start.W < ol
    end
    blk:ClearAllPoints()
    if right then
        blk:SetPoint("TOPLEFT", tray, "TOPRIGHT", gap, 0)
        blk:SetPoint("BOTTOMLEFT", tray, "BOTTOMRIGHT", gap, 0)
    else
        blk:SetPoint("TOPRIGHT", tray, "TOPLEFT", -gap, 0)
        blk:SetPoint("BOTTOMRIGHT", tray, "BOTTOMLEFT", -gap, 0)
    end
    Start.side = right and "right" or "left"
end

local function fillList()
    local s = parts.stack
    parts.copy.SetOn(copy)
    s:Begin()
    local using = Bridge.ProfileOf(Bridge.CurrentIndex())
    local list = Bridge.Profiles() or {}
    if #list == 0 then s:Text(Start.EMPTY, { color = API.Colors().LABEL }) end
    for _, p in ipairs(list) do
        s:Row({ id = "layout:" .. tostring(p.id), text = p.name,
            tag = p.id == using and { text = Start.IN_USE } or nil,
            onClick = function()
                lift()
                Start.Load(p.id)
            end })
    end
    s:End()
end

-- ---------------------------------------------------------------------
-- Following the editor
-- ---------------------------------------------------------------------

-- Places and fills the block for the open editor.
function Start.Refresh()
    if not (on and blk) then return end
    if not Bridge.EditorOpen() then return Start.Detach() end
    blk:SetHeight(Bridge.EditorTray():GetHeight() or 0)
    place()
    parts.picker:SetShown(mode == nil)
    parts.list:SetShown(mode == "load")
    parts.name:SetShown(mode == "name")
    parts.noName:SetShown(mode == "name" and unnamed == true)
    if mode ~= "name" then parts.input:ClearFocus() end
    if mode == "load" then fillList() end
end

-- Shows the block on the open editor, on its cards.
-- Daylight UI's Open on an editor already open only shows another layout.
function Start.Attach()
    if not Bridge.EditorOpen() then return end
    if on then return Start.Refresh() end
    if not build() then return end
    on, mode, copy, unnamed = true, nil, true, nil
    blk:Show()
    Start.Refresh()
end

-- Hides it with the editor, a fight's close included.
function Start.Detach()
    on, mode, unnamed = false, nil, nil
    if blk then
        parts.input:ClearFocus()
        blk:Hide()
    end
end

function Start.Frame() return blk end
-- The block's parts once built: picker, list, back, copy, copyText, stack, and
-- the name box's name, input, create, nameBack, noName.
function Start.Parts() return parts end
function Start.Shown() return on and blk ~= nil and blk:IsShown() end

-- /ezcdm: Daylight UI's editor, with the block beside it. Refuses in combat and
-- while EZ-CDM is off, with one chat line.
function Start.Open()
    if InCombatLockdown() then return refuse("combat") end
    if not Bridge.Ready() then return refuse("off") end
    return Bridge.OpenEditor()
end

SLASH_EZCDM1 = "/ezcdm"
SlashCmdList.EZCDM = function() Start.Open() end
API.For(addonName).RegisterCommand("ezcdm", function() Start.Open() end, "Start a cooldown layout in EZ mode.")

-- Hooks go on once Daylight UI has started its modules and the Bridge is ready.
local function hookEditor()
    if not Bridge.Ready() then return end
    Bridge.HookEditor("Open", function() Start.Attach() end)
    Bridge.HookEditor("Close", function() Start.Detach() end)
    Bridge.HookEditor("Draw", function() Start.Refresh() end)
    Bridge.HookEditor("EndTrayMove", function() Start.Refresh() end)
end

API.On("Login", hookEditor, "EZ-CDM")
