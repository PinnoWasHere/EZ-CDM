local _, ns = ...

-- EZ mode inside Daylight UI's own CDM editor: a drawer that slides out of the
-- editor's spell tray, the same width. A tab on the tray's edge, the info panel's
-- fold tab, opens and folds it. It follows the piece picked in the editor and shows
-- that spell's sentences. A chosen word is Daylight UI's link in the accent, a
-- blank is its chip. Clicking either fills the strip at the drawer's bottom with
-- chips for the words that fit, and a pick writes the spell at once (Draft.Write),
-- then the editor redraws. The strip stays open on its word, with the new pick lit,
-- until the word is clicked again, another word or spell is picked, a press lands on
-- empty space, or the drawer folds or the editor closes. The drawer comes and goes
-- with the editor (/cdm too),
-- through Daylight UI's public hook on the editor's Open, Close, Select, Draw and
-- EndTrayMove. Every look is Daylight UI's, through ns.Bridge and API.md calls.
-- Without the info panel loaded, a header row with Daylight UI's chevron folds it.

local Bridge, Grammar, Draft, Effects = ns.Bridge, ns.Grammar, ns.Draft, ns.Effects
local API = DaylightUI.API
local WORDING = Grammar.WORDING

local Drawer = {}
ns.Drawer = Drawer

-- Debug handle for an in-game check.
EZCDM_Drawer = Drawer

Drawer.HEAD = "EZ"
Drawer.TAB_LABEL = "EZ-CDM"
-- The strata EZ-CDM's frames take while clicked last, above Daylight UI's card and
-- under its menus (FULLSCREEN_DIALOG).
Drawer.LIFT = "FULLSCREEN"
Drawer.EMPTY = "Click a spell in your layout."
Drawer.HINT = "Click a word to change it."
Drawer.ADD_LINE = WORDING.addLine
Drawer.ADD_GROUP = WORDING.addGroup
Drawer.ADD_FORM = WORDING.addForm
Drawer.ADD_RECIPE = WORDING.addRecipe
Drawer.COPY_REPORT = WORDING.copyReport

-- The strip's heading per kind of word. "and" is the and … blank's strip.
Drawer.HEADINGS = setmetatable({ ["and"] = WORDING.headings.clause }, { __index = WORDING.headings })
Drawer.COLOR_WORDS = { accent = "accent", pick = "pick…" }
-- Strip keys of the drawer's own: the chip that shows or hides advanced words, and
-- the chip that takes a clause out.
Drawer.MORE = "\1more"
Drawer.DROP = "\1drop"
-- A flare's sound word for Proc Alerts' own sound.
Drawer.FLARE_SOUND = "\1procs"

-- Why a pick didn't write, in plain words.
Drawer.REFUSED = {
    combat = "You're in combat, so nothing changed.",
    unplaced = "That spell isn't in this layout any more.",
    problems = "Nothing changed. Fix the line below first.",
    other = "Daylight UI didn't take that change.",
}

-- API.md's text sizes in px, for a line's height before the client measures one.
local SIZE_PX = { small = 12, body = 13, head = 15 }
-- Stack:Text's line spacing (Parts.lua:423).
local SPACING = 3

local d            -- the drawer, built on the editor's first open
local clip         -- the slide's window, out of the tray's edge; d rides its far edge
local tab          -- the fold tab, while the info panel is loaded
local fold         -- the fold tab's measures (Bridge.FoldTab), or nil
local slider       -- the slide, 0 folded to 1 open
local placed       -- the slide has had its first layout since the editor opened
local fullH = 0    -- the drawer's height, open
local innerW       -- the stacks' width inside the drawer's sides
local front = false -- EZ-CDM's frames above Daylight UI's card
local on = false   -- attached to an open editor
local waiting      -- hidden while a + on the picked piece waits for a spell
local shown        -- the piece the drawer shows, or nil
local parts = {}   -- body, bodyStack, strip, stripStack, rule
local slot         -- the open strip: { id, kind, heading, keys, values, current, onPick, follow }
local pending = {} -- the shown spell's lines not finished yet, after its own
local kept = {}    -- the shown spell's finished lines that ask for Daylight UI's default
local refused      -- the last pick that didn't write: { why, text, notes }
local notices = {} -- what the last write couldn't do, in plain words
local openNext     -- a word id whose strip opens on the next draw
local drawn = {}   -- the word ids the body shows now; a strip lives only while its word does
local stripFor     -- the word id the strip was last drawn for, so its scroll is kept across picks
local badNumber    -- the number word whose last typed number was out of range
local focusedFor   -- the number word whose box took the keyboard as it opened

local function pad() return Bridge.Gap() or 0 end

-- A click on EZ-CDM's frames puts them on top (Drawer.Lift).
local function lift() Drawer.Lift() end

local function copy(v)
    if type(v) ~= "table" then return v end
    local c = {}
    for k, x in pairs(v) do c[k] = copy(x) end
    return c
end

local function upper(s) return s:sub(1, 1):upper() .. s:sub(2) end

-- ---------------------------------------------------------------------
-- Open state, saved in EZCDMDB.drawer (open unless collapsed)
-- ---------------------------------------------------------------------

local function savedVars()
    if type(EZCDMDB) ~= "table" then EZCDMDB = {} end
    return EZCDMDB
end

function Drawer.Expanded() return savedVars().drawer ~= false end

function Drawer.SetExpanded(open)
    savedVars().drawer = open and true or false
    Drawer.Refresh()
end

-- ---------------------------------------------------------------------
-- Measuring: hidden copies of each look, so a block's lines are known before
-- it is placed.
-- ---------------------------------------------------------------------

local meter
local function meterFrame()
    if not meter then
        meter = CreateFrame("Frame", nil, d)
        meter:Hide()
        meter.fs, meter.widgets = {}, {}
    end
    return meter
end

local function measure(text, size)
    local m = meterFrame()
    local fs = m.fs[size]
    if not fs then
        fs = API.Text(m, size, "LEFT")
        m.fs[size] = fs
    end
    fs:SetText(text)
    local w, h = fs:GetStringWidth(), fs:GetStringHeight()
    if type(w) ~= "number" then w = 0 end
    if type(h) ~= "number" or h <= 0 then h = SIZE_PX[size] end
    return w, math.ceil(h)
end

-- A word's look: "link" a chosen word, "add" a plain link, "chip" a blank.
local function newWidget(kind, parent)
    if kind == "chip" then return Bridge.Chip(parent, "") end
    return Bridge.Link(parent, kind == "add" and "small" or "body", kind == "link")
end

local function label(w, kind, text)
    if kind == "chip" then
        w.text:SetText(text)
        w.FitWidth()
    else
        w.SetLabel(text)
    end
end

local function widgetSize(kind, text)
    local m = meterFrame()
    local w = m.widgets[kind]
    if not w then
        w = newWidget(kind, m)
        m.widgets[kind] = w
    end
    label(w, kind, text)
    return math.ceil(w:GetWidth() or 0), math.ceil(w:GetHeight() or 0)
end

local removeW, removeH
local function removeSize()
    if not removeW then
        local r = Bridge.RemoveButton(meterFrame())
        removeW, removeH = r:GetWidth() or 0, r:GetHeight() or 0
        r:Hide()
    end
    return removeW, removeH
end

-- ---------------------------------------------------------------------
-- Flowing words. A piece is { text, size, color, kind, onClick, id, on }: kind
-- "link", "add" or "chip" is one of Daylight UI's controls and never breaks;
-- plain text breaks between words. Controls side by side get the parts' gap.
-- ---------------------------------------------------------------------

local function flow(pieces, width)
    local bits, x, line, lineH = {}, 0, 0, 0
    local lastControl = false
    for _, p in ipairs(pieces) do
        local size = p.size or "body"
        if p.kind then
            local w, h = widgetSize(p.kind, p.text)
            local before = lastControl and pad() or 0
            if x > 0 and x + before + w > width then x, line, before = 0, line + 1, 0 end
            x = x + before
            bits[#bits + 1] = { piece = p, x = x, line = line, w = w, h = h }
            x = x + w
            if h > lineH then lineH = h end
            lastControl = true
        elseif not p.text:find("%S") then
            -- A bare space between two controls is the font's own space.
            if x > 0 then
                local two = measure("x x", size)
                x = x + math.max(0, two - measure("xx", size))
            end
            lastControl = false
        else
            -- Words go in runs, one per line, each measured whole: a word's own
            -- width and its neighbor's never add up to a wider gap.
            local run, runW, runH = "", 0, 0
            local function emit()
                if run == "" then return end
                bits[#bits + 1] = { piece = p, text = run, x = x, line = line, w = runW, h = runH, size = size }
                x = x + runW
                if runH > lineH then lineH = runH end
                run, runW = "", 0
            end
            for text in string.gmatch(p.text, "%s*%S+%s*") do
                local w, h = measure(run .. text, size)
                if x + w > width and (run ~= "" or x > 0) then
                    emit()
                    x, line = 0, line + 1
                    text = text:gsub("^%s+", "")
                    w, h = measure(text, size)
                end
                run, runW, runH = run .. text, w, h
            end
            emit()
            lastControl = false
        end
    end
    return bits, lineH, line + 1
end

local function paint(fs, color)
    if color == "accent" then
        fs:SetTextColor(API.Accent())
        return
    end
    local ink = API.Colors()
    local c = ink[color or "TEXT"] or ink.TEXT
    fs:SetTextColor(c[1], c[2], c[3])
end

local function makeWords(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.pool = { small = {}, body = {}, link = {}, add = {}, chip = {} }
    b.remove = Bridge.RemoveButton(b)
    b.remove:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    b.remove:SetScript("OnClick", function()
        lift()
        if b.onRemove then b.onRemove() end
    end)
    return b
end

local function token(b, bit)
    local p = bit.piece
    local key = p.kind or bit.size
    local list = b.pool[key]
    b.n[key] = b.n[key] + 1
    local t = list[b.n[key]]
    if not t then
        if p.kind then
            t = newWidget(p.kind, b)
            t:SetScript("OnClick", function(self, button)
                lift()
                local piece = self.piece
                if button == "RightButton" then
                    if piece and piece.onClear then piece.onClear() end
                    return
                end
                if piece and piece.onClick then piece.onClick(self) end
            end)
        else
            t = CreateFrame("Frame", nil, b)
            t.text = API.Text(t, bit.size, "LEFT")
            t.text:SetPoint("LEFT", t, "LEFT", 0, 0)
            t.text:SetWordWrap(false)
        end
        list[b.n[key]] = t
    end
    return t
end

-- A block of flowing words on stack s. opts.onRemove adds Daylight UI's remove
-- button on its right; opts.gap is the space above it. Returns the block: b.said
-- is its text, b.tokens its words and controls, each with .piece.
local function words(s, pieces, opts)
    opts = opts or {}
    local width = innerW or s:Width()
    local rh = 0
    if opts.onRemove then
        local rw
        rw, rh = removeSize()
        width = width - rw - pad()
    end
    local bits, lineH, lines = flow(pieces, width)
    local h = math.max(lines * lineH + (lines - 1) * SPACING, rh)
    local b = s:Piece("words", makeWords, h, opts.gap)
    for _, list in pairs(b.pool) do
        for _, t in ipairs(list) do t:Hide(); t.piece = nil end
    end
    b.n = { small = 0, body = 0, link = 0, add = 0, chip = 0 }
    b.tokens = {}
    for _, bit in ipairs(bits) do
        local p = bit.piece
        local t = token(b, bit)
        if p.kind then
            label(t, p.kind, p.text)
            -- A chosen word that has a blank to go back to takes a right-click too.
            if p.onClear then t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            else t:RegisterForClicks("LeftButtonUp") end
            if p.kind == "chip" then
                t.SetOn(p.on == true)
            elseif p.kind == "link" then
                paint(t.text, p.color or "accent")
            end
        else
            t.text:SetText(bit.text)
            paint(t.text, p.color or "TEXT")
            t:SetSize(math.max(1, bit.w), lineH)
        end
        t.piece = p
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", b, "TOPLEFT", bit.x, -(bit.line * (lineH + SPACING) + math.floor((lineH - bit.h) / 2)))
        t:Show()
        b.tokens[#b.tokens + 1] = t
    end
    -- A control beside the sentence (aside) is not part of what it says.
    local said = {}
    for _, p in ipairs(pieces) do
        if not p.aside then said[#said + 1] = p.text end
    end
    b.said = table.concat(said)
    -- A pooled block forgets what it stood for last time.
    b.line, b.group, b.form, b.note, b.notice, b.refusal, b.adds, b.fade, b.shared, b.choices, b.hint, b.default,
        b.groupHead, b.shows, b.style, b.ezGlow, b.ezReload = nil, nil, nil, nil, nil, nil, nil, nil, nil,
        nil, nil, nil, nil, nil, nil, nil, nil
    b.ezRingOther, b.fallOff, b.copy, b.hidden, b.never, b.grayOwned = nil, nil, nil, nil, nil, nil
    b.onRemove = opts.onRemove
    b.remove:SetShown(opts.onRemove ~= nil)
    return b
end

-- ---------------------------------------------------------------------
-- On top: whichever was clicked last, EZ-CDM's frames or Daylight UI's card
-- ---------------------------------------------------------------------

-- EZ-CDM's frames on the editor: the drawer (in its clip), the tab, the start block.
local function frames()
    local start = ns.Start and ns.Start.Frame()
    return { clip, tab, start }
end

local function setStrata(strata)
    for _, f in pairs(frames()) do f:SetFrameStrata(strata) end
end

-- Puts EZ-CDM's frames above Daylight UI's card.
function Drawer.Lift()
    if front or not clip then return end
    front = true
    setStrata(Drawer.LIFT)
end

-- Puts Daylight UI's card back on top.
function Drawer.Drop()
    if not front then return end
    front = false
    local o = Bridge.EditorOverlay()
    setStrata(o and o:GetFrameStrata() or "DIALOG")
end

-- Whether EZ-CDM's frames are on top.
function Drawer.Front() return front end

-- Whether the mouse is over a control the strip works with: a word or chip, a remove
-- button, a scroll bar, or Daylight UI's color picker.
local function overControl()
    for _, name in ipairs({ "bodyStack", "stripStack" }) do
        local s = parts[name]
        if s then
            if s.bar:IsMouseEnabled() and s.bar:IsMouseOver() then return true end
            if s.scroll:IsMouseOver() then
                for _, b in ipairs(s.pieces) do
                    if b:IsShown() and b.box and b.box:IsMouseOver() then return true end
                    if b:IsShown() and b.remove and b.remove:IsShown() and b.remove:IsMouseOver() then return true end
                    for _, t in ipairs(b.tokens or {}) do
                        if t.piece and t.piece.kind and t:IsShown() and t:IsMouseOver() then return true end
                    end
                end
            end
        end
    end
    local picker = rawget(_G, "ColorPickerFrame")
    return type(picker) == "table" and type(picker.IsShown) == "function" and picker:IsShown()
        and picker:IsMouseOver() or false
end

-- The number box while it has the keyboard, or nil.
local function typing()
    local s = parts.stripStack
    for _, b in ipairs(s and s.pieces or {}) do
        if b:IsShown() and b.box and b.box:HasFocus() then return b.box end
    end
end

-- A mouse press anywhere decides: over one of EZ-CDM's frames it lifts them,
-- anywhere else it drops them, so a click on Daylight UI's card brings it back.
-- A press on empty space, inside the drawer or out, closes the open strip; a
-- number typed in its box is written first.
function Drawer.Press()
    local inside = false
    for _, f in pairs(frames()) do
        if f:IsVisible() and f:IsMouseOver() then inside = true end
    end
    if inside then Drawer.Lift() else Drawer.Drop() end
    if slot and not overControl() then
        local box = typing()
        if box then box:ClearFocus() end
        slot = nil
        Drawer.Refresh()
    end
end

-- EZ-CDM's own listener for the game's GLOBAL_MOUSE_DOWN, on while the editor is open.
local watch = CreateFrame("Frame")
watch:SetScript("OnEvent", Drawer.Press)

-- ---------------------------------------------------------------------
-- The fold tab: the info panel's, on the drawer's edge (Panel.lua:138-160)
-- ---------------------------------------------------------------------

local function tintTab(hot)
    for _, c in ipairs(tab.chev) do
        if hot then c:SetVertexColor(API.Accent()) else c:SetVertexColor(fold.color[1], fold.color[2], fold.color[3]) end
    end
end

local function buildTab(o, level)
    tab = CreateFrame("Button", nil, o)
    -- Behind the drawer's and the tray's edge, as the info panel tucks its tab.
    tab:SetFrameLevel(math.max(0, level - 1))
    tab.chev = {}
    for i = 1, 2 do
        local c = tab:CreateTexture(nil, "OVERLAY")
        c:SetTexture(API.Media("ui-chevron.png"))
        c:SetSize(fold.arrow, fold.arrow)
        tab.chev[i] = c
    end
    tab.label = API.Text(tab, "small", "CENTER")
    tab.label:SetText(Drawer.TAB_LABEL)
    paint(tab.label, "LABEL")
    tab.chev[1]:SetPoint("RIGHT", tab.label, "LEFT", -pad(), 0)
    tab.chev[2]:SetPoint("LEFT", tab.label, "RIGHT", pad(), 0)
    tintTab(false)
    tab:SetScript("OnClick", function()
        lift()
        Drawer.SetExpanded(not Drawer.Expanded())
    end)
    tab:SetScript("OnEnter", function() tintTab(true) end)
    tab:SetScript("OnLeave", function() tintTab(false) end)
    tab:Hide()
end

-- The tab's size and art for border T and the drawer's side. Its chevrons point
-- where the drawer goes on a click, as the info panel's do.
local function layTab(T, under, open)
    local lw = tab.label:GetStringWidth()
    if type(lw) ~= "number" then lw = 0 end
    local w = math.ceil(lw) + 2 * (fold.arrow + pad()) + fold.tab[2] - fold.arrow
    local h = fold.tab[1] + T
    if tab.w ~= w or tab.h ~= h then
        tab.w, tab.h = w, h
        tab:SetSize(w, h)
        API.Skin(tab, { borderPx = fold.border })
    end
    -- The tucked side's border is hidden, so the words sit centered on the rest.
    tab.label:ClearAllPoints()
    tab.label:SetPoint("CENTER", tab, "CENTER", 0, (under and -T or T) / 2)
    local down = under ~= open
    for _, c in ipairs(tab.chev) do c:SetRotation(down and 0 or math.pi) end
end

-- ---------------------------------------------------------------------
-- The slide (the info panel's meter slide, Panel.lua:661-679)
-- ---------------------------------------------------------------------

local function applySlide()
    if not (clip and slider) then return end
    local p = slider.p
    clip:SetHeight(math.max(0.01, p * fullH))
    -- Clipped while it moves; at rest open the drawer's shadow shows whole.
    clip:SetClipsChildren(p < 1)
    d:SetAlpha(p)
    clip:SetShown(on and not waiting and (p > 0 or slider.goal == 1))
end

-- Toward open or folded. The first layout after the editor opens jumps there.
local function slide(open)
    local goal = open and 1 or 0
    if placed and tab:IsVisible() then slider:To(goal) else slider:Jump(goal) end
    placed = true
    applySlide()
end

-- ---------------------------------------------------------------------
-- Building
-- ---------------------------------------------------------------------

local function build()
    if d then return d end
    local o, tray = Bridge.EditorOverlay(), Bridge.EditorTray()
    if not (o and tray) then return nil end
    fold = Bridge.FoldTab()
    local level = tray:GetFrameLevel()
    -- The tray's own level: Daylight UI's card stays above both until EZ-CDM is clicked.
    clip = CreateFrame("Frame", nil, o)
    clip:SetFrameLevel(level)
    d = CreateFrame("Frame", nil, clip)
    d:SetFrameLevel(level)
    -- A click here never reaches the overlay, where it would clear the pick.
    d:EnableMouse(true)
    Bridge.Shell(d, {})
    local edge = Bridge.Edge()
    local body = CreateFrame("Frame", nil, d)
    body:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
    parts.body = body
    parts.bodyStack = Bridge.Stack(body, { top = pad(), bottom = pad(), side = edge })
    -- The strip: the drawer's bottom, under Daylight UI's divider.
    local strip = CreateFrame("Frame", nil, d)
    strip:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
    parts.strip = strip
    parts.rule = Bridge.Rule(strip)
    parts.rule:SetPoint("TOPLEFT", strip, "TOPLEFT", edge, 0)
    parts.rule:SetPoint("TOPRIGHT", strip, "TOPRIGHT", -edge, 0)
    parts.stripStack = Bridge.Stack(strip, { top = pad(), bottom = pad(), side = edge })
    if fold then
        buildTab(o, level)
        slider = Bridge.Slider(applySlide, { dur = fold.slide, p = Drawer.Expanded() and 1 or 0 })
    end
    clip:Hide()
    return d
end

-- ---------------------------------------------------------------------
-- Placing: out of the tray's bottom edge, or its top when the screen has no room
-- below, as Daylight UI's banner does with the tray. The slide's window grows out
-- of that edge, the drawer rides its far edge, and the tab rides with it.
-- ---------------------------------------------------------------------

-- Anchors the drawer for a height of h. Returns the room on the side taken, or
-- nil when the client hasn't placed the tray yet.
local function place(h)
    local tray, o = Bridge.EditorTray(), Bridge.EditorOverlay()
    local tb, tt, ob, ot = tray:GetBottom(), tray:GetTop(), o:GetBottom(), o:GetTop()
    local below, above
    if type(tb) == "number" and type(tt) == "number" and type(ob) == "number" and type(ot) == "number" then
        below = tb - ob
        above = ot - (Bridge.EditorTop() or 0) - tt
    end
    local T = tab and Bridge.BorderPx(d) or 0
    if tab then h = h + fold.tab[1] end
    local under = below == nil or below >= h or below >= above
    clip:ClearAllPoints()
    d:ClearAllPoints()
    if under then
        clip:SetPoint("TOPLEFT", tray, "BOTTOMLEFT", 0, 0)
        clip:SetPoint("TOPRIGHT", tray, "BOTTOMRIGHT", 0, 0)
        d:SetPoint("BOTTOMLEFT", clip, "BOTTOMLEFT", 0, 0)
        d:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT", 0, 0)
    else
        clip:SetPoint("BOTTOMLEFT", tray, "TOPLEFT", 0, 0)
        clip:SetPoint("BOTTOMRIGHT", tray, "TOPRIGHT", 0, 0)
        d:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
        d:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
    end
    if tab then
        -- Centered on the edge, tucked behind its border.
        tab:ClearAllPoints()
        if under then tab:SetPoint("TOP", clip, "BOTTOM", 0, T) else tab:SetPoint("BOTTOM", clip, "TOP", 0, -T) end
        layTab(T, under, Drawer.Expanded())
    end
    Drawer.side = under and "below" or "above"
    local room = under and below or above
    if room and tab then room = room - fold.tab[1] end
    return room
end

-- ---------------------------------------------------------------------
-- The strip and live writes
-- ---------------------------------------------------------------------

-- The open strip, or nil.
function Drawer.Slot() return slot end

-- Opens word id's strip, or closes it when it is the one open.
function Drawer.Choose(id, def)
    if slot and slot.id == id then
        slot = nil
    else
        slot = def
        def.id = id
        def.heading = Drawer.HEADINGS[def.kind] or ""
    end
    Drawer.Refresh()
end

-- The shown spell's rules: its own from the layout, then the lines that ask for
-- Daylight UI's default, then the lines not finished yet. Also returns the
-- defaults' first and last line numbers.
local function current()
    local rules = Draft.Rules(shown) or { lines = {}, group = {}, forms = {} }
    local first = #rules.lines + 1
    for _, l in ipairs(kept) do rules.lines[#rules.lines + 1] = copy(l) end
    local last = #rules.lines
    for _, l in ipairs(pending) do rules.lines[#rules.lines + 1] = copy(l) end
    return rules, first, last
end

local function refusal(why, report)
    local text = Drawer.REFUSED[why] or Drawer.REFUSED.other
    if why == "off" then text = Bridge.OffLine() or text end
    local notes = {}
    for _, n in ipairs(report and report.notes or {}) do
        if n.blocking then notes[#notes + 1] = n.words end
    end
    return { why = why, text = text, notes = notes }
end

-- The lines of a row (Grammar.Rows) in rules, in reading order.
local function rowLines(rules, row)
    local out = {}
    for p, x in ipairs(row) do out[p] = rules.lines[x] end
    return out
end

-- A row's id: its lowest line number. Its moment, number and clause words carry it.
local function rowId(row)
    local at = row[1]
    for _, x in ipairs(row) do
        if x < at then at = x end
    end
    return at
end

-- The words of a line that belong to its whole row, not to one action.
local ROW_WORDS = { moment = true, n = true, ["and"] = true, also = true, lead = true }
local function rowWord(what) return ROW_WORDS[what] or what:match("^clause%d") or what:match("^cn%d") end

-- Points the open strip at its word after a write. A line's word ids carry the
-- line's index, and the grammar can move the line, so target (the line the strip
-- is on) is found again. A group or form word's id carries the word, so it
-- follows the pick. A word that is gone closes the strip.
local function follow(target, open)
    if not slot then return end
    local was = slot.id
    local at, what = slot.id:match("^line:(%d+):(.+)$")
    if at then
        local line
        if target then
            local rules, _, last = current()
            for p, l in ipairs(open) do
                if l == target then line = last + p end
            end
            if not line then
                local key = Grammar.RowKey(target)
                for pass = 1, 2 do
                    for i = 1, last do
                        local l = rules.lines[i]
                        if not line and l.moment == target.moment and l.action == target.action
                            and (pass == 2 or Grammar.RowKey(l) == key) then line = i end
                    end
                end
            end
            -- A word of the whole line (its moment, clauses, number) goes by the line's
            -- lowest number (Grammar.Rows).
            if line and rowWord(what) then
                for _, row in ipairs(Grammar.Rows(rules.lines, Grammar.Kind(shown))) do
                    for _, x in ipairs(row) do
                        if x == line then line = rowId(row) end
                    end
                end
            end
        end
        if line then slot.id = "line:" .. line .. ":" .. what else slot = nil end
    elseif slot.follow and slot.picked ~= nil then
        slot.id = slot.follow(slot.picked)
    end
    if slot then
        -- The strip is the same one at its new id, so its scroll stays.
        if stripFor == was then stripFor = slot.id end
        slot.picked = nil
    end
end

-- Writes the shown spell's finished lines, group and form words at once. Lines
-- with a blank wait in the drawer. A write leaves the strip open on its word;
-- target is the line it is on. A refusal writes nothing, says why and closes it.
-- A line waits while a word is blank: its moment, its action, or a look's words or
-- icon.
local function blank(l)
    if l.moment == nil or l.action == nil then return true end
    local v = Grammar.ValueKind(l.moment, l.action)
    return (v == "text" or v == "icon") and l.value == nil
end

local function commit(rules, target)
    local done, open = {}, {}
    for _, l in ipairs(rules.lines) do
        if blank(l) then open[#open + 1] = l else done[#done + 1] = l end
    end
    pending, refused, notices = open, nil, {}
    local ok, why, report = Draft.Write(shown, { lines = done, group = rules.group, forms = rules.forms,
        shows = rules.shows, style = rules.style })
    if ok then
        report = why
        -- A line that asks for the default writes nothing and reads back as no line,
        -- so it stays in view while the spell is shown. One a later line overrides goes.
        local kind = Grammar.Kind(shown)
        local _, problems = Grammar.Compile({ lines = done }, kind)
        local beaten = {}
        for _, p in ipairs(problems) do
            if p.code == "twice" and p.line then beaten[p.line] = true end
        end
        kept = {}
        for i, l in ipairs(done) do
            if not beaten[i] and Grammar.IsDefault(l, kind) then kept[#kept + 1] = copy(l) end
        end
        follow(target, open)
    else
        refused, slot = refusal(why, report), nil
    end
    -- A color Daylight UI can't set back to the accent says so. That is the sweep's
    -- color, and a glow's before API 1.15.
    for _, n in ipairs(report and report.notes or {}) do
        if n.code == "accent" then notices[#notices + 1] = n.words end
    end
    if report and #report.changed > 0 then
        -- The editor redraws, and its Draw redraws the drawer.
        Bridge.EditorChanged()
    else
        Drawer.Refresh()
    end
    return ok, why
end

-- Changes the shown spell's rules and writes them. The strip stays on its word,
-- unless the change removes the line the word is on.
local function edit(fn)
    if shown == nil then return end
    local rules = current()
    local target = slot and rules.lines[tonumber(slot.id:match("^line:(%d+):") or "")]
    fn(rules)
    if target then
        local found = false
        for _, l in ipairs(rules.lines) do found = found or l == target end
        if not found then slot, target = nil, nil end
    end
    return commit(rules, target)
end

-- A strip chip: drops the word in. The strip stays open for the next pick.
local function drop(k)
    local t = slot
    if not t then return end
    t.picked = k
    t.onPick(k)
end

-- Group words apply to the whole group: a note names the others in it.
local function sharedNote(s)
    local text = Draft.GroupNote(shown)
    if text then words(s, { { text = text, size = "small", color = "LABEL" } }).shared = true end
end

-- Whether the drawer offers advanced conditions (Settings "more").
local function more()
    local S = ns.Settings
    return S ~= nil and S.Get("more") == true
end

-- The number strip: Daylight UI's number box, and its range under it.
local function makeNumber(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.box = API.Input(b, { numeric = true, maxLetters = 3 })
    b.box:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.box:SetWidth(b.box:GetHeight() * 3)
    b.range = API.Text(b, "small", "LEFT")
    b.range:SetPoint("TOPLEFT", b.box, "BOTTOMLEFT", 0, -pad())
    -- Enter and a press away both take the box's focus, and that commits it.
    -- Escape takes it too, and writes nothing. A redraw hides the box, which takes
    -- its focus as well; what was typed comes back with the box (numberStrip).
    b.box:HookScript("OnEditFocusLost", function(self)
        if b.escaped then
            b.escaped = nil
            return
        end
        if not self:IsVisible() then
            b.resume = self:GetText()
            return
        end
        if b.onCommit then b.onCommit(tonumber(self:GetText() or "")) end
    end)
    b.box:SetScript("OnEscapePressed", function(self)
        b.escaped = true
        self:ClearFocus()
        if b.onEscape then b.onEscape() end
    end)
    return b
end

-- The number box's height, from a box of Daylight UI's own.
local function inputHeight()
    local m = meterFrame()
    if not m.input then m.input = API.Input(m, { numeric = true }) end
    return math.ceil(m.input:GetHeight() or 0)
end

local function numberStrip(s, def)
    local p = def.range
    local _, textH = measure(WORDING.range, "small")
    local b = s:Piece("number", makeNumber, inputHeight() + pad() + textH, pad())
    b.onCommit, b.onEscape = nil, nil
    -- A redraw while the player types keeps what is typed, and the focus.
    if b.resume ~= nil and focusedFor == def.id then
        b.box:SetText(b.resume)
        b.box:SetFocus()
    elseif not (b.box:HasFocus() and focusedFor == def.id) then
        b.box:SetText(tostring(def.current or p.default))
    end
    b.resume = nil
    b.range:SetText(WORDING.range:format(p.min, p.max))
    paint(b.range, badNumber == def.id and "BAD" or "LABEL")
    b.onCommit = function(n)
        if slot ~= def or n == def.current then return end
        if not (n and n % 1 == 0 and n >= p.min and n <= p.max) then
            if badNumber ~= def.id then
                badNumber = def.id
                Drawer.Refresh()
            end
            return
        end
        badNumber = nil
        def.picked = n
        def.onPick(n)
    end
    b.onEscape = function()
        if slot ~= def then return end
        slot, badNumber = nil, nil
        Drawer.Refresh()
    end
    -- It opens with the keyboard, its number picked, ready to type over.
    if focusedFor ~= def.id then
        focusedFor = def.id
        b.box:SetFocus()
        b.box:HighlightText()
    end
    return b
end

-- The words strip: Daylight UI's text box, and how many letters fit under it.
local function makeText(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.box = API.Input(b, { maxLetters = ns.Conditions.TEXT_MAX })
    b.box:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    b.box:SetWidth(b.box:GetHeight() * 6)
    b.range = API.Text(b, "small", "LEFT")
    b.range:SetPoint("TOPLEFT", b.box, "BOTTOMLEFT", 0, -pad())
    -- As the number box: Enter or a press away commits, Escape writes nothing.
    b.box:HookScript("OnEditFocusLost", function(self)
        if b.escaped then
            b.escaped = nil
            return
        end
        if not self:IsVisible() then
            b.resume = self:GetText()
            return
        end
        if b.onCommit then b.onCommit(self:GetText()) end
    end)
    b.box:SetScript("OnEscapePressed", function(self)
        b.escaped = true
        self:ClearFocus()
        if b.onEscape then b.onEscape() end
    end)
    return b
end

local function textStrip(s, def)
    local _, textH = measure(WORDING.textRange, "small")
    local b = s:Piece("text", makeText, inputHeight() + pad() + textH, pad())
    b.onCommit, b.onEscape = nil, nil
    if b.resume ~= nil and focusedFor == def.id then
        b.box:SetText(b.resume)
        b.box:SetFocus()
    elseif not (b.box:HasFocus() and focusedFor == def.id) then
        b.box:SetText(type(def.current) == "string" and def.current or "")
    end
    b.resume = nil
    b.range:SetText(WORDING.textRange:format(ns.Conditions.TEXT_MAX))
    paint(b.range, badNumber == def.id and "BAD" or "LABEL")
    b.onCommit = function(text)
        if slot ~= def then return end
        local clean = ns.Conditions.CleanValue("text", text)
        if clean ~= nil and clean == def.current then return end
        if clean == nil then
            if badNumber ~= def.id then
                badNumber = def.id
                Drawer.Refresh()
            end
            return
        end
        badNumber = nil
        def.picked = clean
        def.onPick(clean)
    end
    b.onEscape = function()
        if slot ~= def then return end
        slot, badNumber = nil, nil
        Drawer.Refresh()
    end
    if focusedFor ~= def.id then
        focusedFor = def.id
        b.box:SetFocus()
        b.box:HighlightText()
    end
    return b
end

local function fillStrip()
    local s = parts.stripStack
    s:Begin()
    if slot then
        words(s, { { text = slot.heading, size = "small", color = "LABEL" } })
        if slot.kind == "group" then sharedNote(s) end
        if slot.kind == "number" then
            numberStrip(s, slot)
        elseif slot.kind == "text" then
            textStrip(s, slot)
        else
            focusedFor = nil
        end
        local pieces = {}
        for _, k in ipairs(slot.keys) do
            pieces[#pieces + 1] = { kind = "chip", text = slot.values[k] or tostring(k), key = k,
                on = slot.current ~= nil and k == slot.current,
                onClick = function()
                    if slot and (slot.kind == "sound" or (slot.kind == "flareSound" and k ~= Drawer.FLARE_SOUND)) then
                        Bridge.PreviewAlert(k)
                    end
                    drop(k)
                end }
        end
        -- Advanced words come and go without a write; the strip stays open.
        if slot.more then
            pieces[#pieces + 1] = { kind = "chip", text = more() and WORDING.fewer or WORDING.more, key = Drawer.MORE,
                onClick = function() ns.Settings.Set("more", not more()) end }
        end
        if #pieces > 0 then words(s, pieces).choices = true end
        -- Parts the line can't take with what it holds, and why.
        for _, r in ipairs(slot.refused or {}) do
            words(s, { { text = WORDING.neverPart:format(r.words or Grammar.ClauseWords(r.cond), r.why), size = "small",
                color = "LABEL" } }).never = r.cond or r.action
        end
    else
        focusedFor = nil
        words(s, { { text = Drawer.HINT, size = "small", color = "LABEL" } }).hint = true
    end
    s:End()
    return s.height or 0
end

-- ---------------------------------------------------------------------
-- Sentences. Each line reads as Grammar.Describe says it; its chosen words are
-- links and its blanks chips, and each strip holds what Grammar.Words allows.
-- ---------------------------------------------------------------------

-- Each moment's phrase, the same on its chip and in the sentence.
local function momentNames(kind)
    local out = {}
    for m in pairs(WORDING.moments) do out[m] = (Grammar.MomentWords(m, nil, kind)) end
    return out
end

-- The moments the drawer offers, each fitting moment's actions, every action the
-- offered moments take, and whether "more…" would change the moments.
local function wordsFor(kind)
    local moments, actions, any, seen = {}, {}, {}, {}
    local view = { drawer = true, more = more() }
    for _, w in ipairs(Grammar.Words(kind, view)) do
        moments[#moments + 1] = w.moment
        for _, a in ipairs(w.actions) do seen[a] = true end
    end
    for _, w in ipairs(Grammar.Words(kind)) do actions[w.moment] = w.actions end
    for _, a in ipairs(Grammar.ACTIONS) do
        if seen[a] then any[#any + 1] = a end
    end
    return moments, actions, any, ns.Conditions.AnyAdvanced()
end

-- A clause's or a moment's name on a chip ("my target is below N% health").
local function clauseNames(kind)
    local out = {}
    for _, c in ipairs(ns.Conditions.List()) do out[c.key] = Grammar.ClauseWords(c.key, nil, kind) end
    out[Drawer.DROP] = WORDING.dropClause
    return out
end

-- Puts cond in as clause j; a client one ends the line, so the clauses after it go.
local function setClause(line, j, cond)
    line.clauses = line.clauses or {}
    line.clauses[j] = { cond = cond }
    local c = ns.Conditions.Get(cond)
    if c and c.secrecy == "client" then
        for x = #line.clauses, j + 1, -1 do line.clauses[x] = nil end
    end
end

local function dropClause(line, j)
    if type(line.clauses) ~= "table" then return end
    table.remove(line.clauses, j)
    if #line.clauses == 0 then line.clauses = nil end
end

-- A phrase as pieces, its number (#) a word of its own: the text before it, the
-- number word, and the text after it. Without a number, the phrase alone.
local function withNumber(phrase, n, wordFor)
    local before, after = phrase:match("^(.-)" .. Grammar.NUMBER_MARK .. "(.*)$")
    if not before then return { wordFor(phrase) } end
    local out = {}
    local lead = before:match("^(.-)%s*$")
    out[#out + 1] = wordFor(lead)
    if lead ~= before then out[#out + 1] = { text = before:sub(#lead + 1) } end
    out[#out + 1] = n
    if after ~= "" then out[#out + 1] = { text = after } end
    return out
end

-- Daylight UI's sound list: values and the keys in order, headings left out.
local function sounds()
    local values, order = Bridge.SoundChoices()
    local keys = {}
    for _, k in ipairs(type(order) == "table" and order or {}) do
        if not tostring(k):find("^head:") then keys[#keys + 1] = k end
    end
    return type(values) == "table" and values or {}, keys
end

local function firstSound()
    local _, keys = sounds()
    for _, k in ipairs(keys) do
        if k ~= "none" then return k end
    end
    return keys[1]
end

-- A line on a new moment or action. The value and the glow's own style go with an
-- action change; a sound line takes the first sound. The fall-off lead stays while
-- the line stays on "When it's about to fall off", and goes when it leaves.
-- An EZ-CDM condition's number and clauses: a new moment takes its own number's
-- default and keeps the clauses it can, none after a client one; a new action keeps
-- a client clause only where its effect is alpha-safe. kind is the piece's.
local function retarget(line, moment, action, kind)
    local keepAt = moment == "recast" and line.moment == "recast"
    if action ~= line.action then
        line.value, line.style = nil, nil
        if not keepAt then line.at = nil end
    end
    if line.moment == "recast" and moment ~= "recast" then line.at = nil end
    if moment ~= line.moment then line.n = nil end
    line.moment, line.action = moment, action
    if action == "sound" and line.value == nil then line.value = firstSound() end
    local ck = Grammar.ClauseRoot(line, kind)
    local C = ns.Conditions
    if not ck or C.Get(ck).secrecy == "client" then
        line.clauses = nil
    elseif type(line.clauses) == "table" then
        local safe = C.ClientSafe(ck, action)
        for j = #line.clauses, 1, -1 do
            local c = C.Get(line.clauses[j].cond)
            if line.clauses[j].cond == ck or (c and c.secrecy == "client" and not safe) then dropClause(line, j) end
        end
    end
end

-- The fall-off lead is one per piece: it goes on every "about to fall off" line.
local function setLead(rules, n)
    for _, l in ipairs(rules.lines) do
        if l.moment == "recast" then l.at = n end
    end
end

-- The piece's fall-off lead, from any line that has one.
local function leadOf(rules)
    for _, l in ipairs(rules.lines) do
        if l.moment == "recast" and l.at ~= nil then return l.at end
    end
end

-- The lead's strip: Daylight UI's own timing, then the seconds choices.
local function leadChoices()
    local keys, values = { "daylight" }, { daylight = WORDING.daylightTiming }
    for _, n in ipairs(Grammar.LEADS) do
        keys[#keys + 1] = n
        values[n] = Grammar.Seconds(n)
    end
    return keys, values
end

-- The words around a lead word: one for seconds, one for Daylight UI's timing.
local function aroundLead(at)
    local text = (at ~= nil and WORDING.lead or WORDING.leadNone):format("\1")
    return text:match("^(.-)\1(.*)$")
end

-- A word: a link for a chosen word, a chip for a blank, and the strip it opens.
local function word(text, id, def, chosen, color)
    def.writes = def.writes ~= false
    drawn[id] = true
    -- An open strip takes the fresh word, so its choices and lit pick are current.
    if openNext == id or (slot and slot.id == id) then
        openNext = nil
        slot = def
        def.id, def.heading = id, Drawer.HEADINGS[def.kind] or ""
    end
    return { kind = chosen and "link" or "chip", text = text, id = id, color = color, word = def.kind,
        on = not chosen and slot ~= nil and slot.id == id,
        onClick = function() Drawer.Choose(id, def) end,
        onClear = chosen and def.clear and function()
            slot = nil
            def.clear()
        end or nil }
end

-- The glow styles EZ-CDM offers (Bridge.OfferedStyles) in the card's order, and every
-- style's label, so a piece's own style EZ no longer offers still reads by name.
-- piece puts "the spell's style" first, for a glow line with no style of its own.
local function styleChoices(piece)
    local keys, values = {}, {}
    if piece then
        keys[1] = "piece"
        values.piece = WORDING.pieceStyle
    end
    for _, st in ipairs(Bridge.GlowStyles() or {}) do values[st.key] = st.label end
    for _, st in ipairs(Bridge.OfferedStyles()) do keys[#keys + 1] = st.key end
    return keys, values
end

-- A number word: its strip is Daylight UI's number box. set(r, n) writes it.
local function numberWord(id, key, n, set, off)
    local C = ns.Conditions
    local now = C.NumberOf(key, n)
    return word(tostring(now), id, { kind = "number", keys = {}, values = {}, current = now,
        range = C.Get(key).param, onPick = function(x) edit(function(r) set(r, x) end) end,
        clear = function() edit(function(r) set(r, nil) end) end }, true, off)
end

-- Each of a row's lines in r, by its line numbers.
local function eachOf(r, row, fn)
    for _, x in ipairs(row) do fn(r.lines[x]) end
end

-- Removes the lines numbered in list from r.
local function removeLines(r, list)
    local sorted = {}
    for p, x in ipairs(list) do sorted[p] = x end
    table.sort(sorted, function(a, b) return a > b end)
    for _, x in ipairs(sorted) do table.remove(r.lines, x) end
end

-- The clauses a row may take at clause j (a new one past the end): those every
-- action's line may take (Grammar.RowClauses) and open before it, less those after
-- it, with its own first; the ones refused, with why.
local function rowClauseChoices(kind, lines, j)
    local first = lines[1]
    local clauses = type(first.clauses) == "table" and first.clauses or {}
    local before = {}
    for x = 1, j - 1 do before[x] = clauses[x] end
    local view = { drawer = true, more = more() }
    local probes = {}
    for p, l in ipairs(lines) do probes[p] = { moment = l.moment, action = l.action, clauses = before } end
    local later = {}
    for x = j + 1, #clauses do later[clauses[x].cond] = true end
    local keys = {}
    if clauses[j] then keys[1] = clauses[j].cond end
    local offered, refusedAll = Grammar.RowClauses(kind, probes, view)
    for _, k in ipairs(offered) do
        if not later[k] and k ~= keys[1] then keys[#keys + 1] = k end
    end
    local refused = {}
    for _, r in ipairs(refusedAll) do
        if not later[r.cond] then
            r.words = Grammar.ClauseWords(r.cond, nil, kind)
            refused[#refused + 1] = r
        end
    end
    return keys, ns.Conditions.AnyAdvanced() and Grammar.RowTakesClauses(probes, kind), refused
end

-- A row on a new moment: each action that fits it stays, once, and with none the
-- moment's first action. The clauses every kept action keeps stay for all.
local function retargetRow(r, row, m, kind, actions)
    local keep, drop = {}, {}
    for _, x in ipairs(row) do
        local a = r.lines[x].action
        local fine = a == nil or Grammar.Fits(kind, m, a)
        for _, y in ipairs(keep) do
            if fine and a ~= nil and Grammar.ActionsClash({ moment = m, action = r.lines[y].action },
                { moment = m, action = a }) then fine = false end
        end
        if fine then keep[#keep + 1] = x else drop[#drop + 1] = x end
    end
    if #keep == 0 then
        keep[1] = table.remove(drop, 1)
        r.lines[keep[1]].action = actions[m] and actions[m][1]
    end
    local fewest
    for _, x in ipairs(keep) do
        local l = r.lines[x]
        retarget(l, m, l.action, kind)
        if m == "recast" and l.at == nil then l.at = leadOf(r) end
        if Grammar.RingOnly(kind, m) then l.style = nil end
        local n = type(l.clauses) == "table" and #l.clauses or 0
        if not fewest or n < fewest.n then fewest = { n = n, clauses = l.clauses } end
    end
    for _, x in ipairs(keep) do r.lines[x].clauses = fewest and copy(fewest.clauses) or nil end
    removeLines(r, drop)
end

-- Another action on line's line: its moment, number, clauses and lead, a sound's
-- first sound. One whose words or icon aren't picked yet waits with its blank open.
local function addAction(line, a)
    local new = { moment = line.moment, action = a, n = line.n, at = line.at, clauses = copy(line.clauses) }
    if a == "sound" then new.value = firstSound() end
    edit(function(r) r.lines[#r.lines + 1] = new end)
    local valued = Grammar.ValueKind(new.moment, a)
    if valued ~= "text" and valued ~= "icon" then return end
    for p, l in ipairs(pending) do
        if l == new then
            local _, _, last = current()
            openNext, slot = "line:" .. (last + p) .. ":" .. valued, nil
            Drawer.Refresh()
        end
    end
end

local function sentence(s, kind, rules, row)
    local moments, actions, any, hasMore = wordsFor(kind)
    local lines = rowLines(rules, row)
    local i, line = row[1], lines[1]
    local finished = line.moment ~= nil and line.action ~= nil
    local off = finished and not Grammar.Fits(kind, line.moment, line.action) and "OFF" or nil
    local id = "line:" .. rowId(row) .. ":"
    -- Daylight UI's own ready glow and sound take "and" too (Grammar.ClauseRoot).
    local ck = Grammar.ClauseRoot(line, kind)
    local C = ns.Conditions
    -- The moment's condition takes its number before an action is picked.
    local mk = ck or Grammar.MomentCondition(line.moment)
    local phrase, joint = Grammar.MomentWords(line.moment, mk and C.Get(mk).param and Grammar.NUMBER_MARK, kind)
    local pieces = {}
    local momentDef = {
        kind = "moment", keys = moments, values = momentNames(kind), current = line.moment, more = hasMore,
        onPick = function(m)
            -- Each action stays while it fits the new moment; a blank stays blank.
            edit(function(r) retargetRow(r, row, m, kind, actions) end)
        end,
        clear = function() edit(function(r) eachOf(r, row, function(l) retarget(l, nil, l.action, kind) end) end) end }
    local nWord = mk and C.Get(mk).param and numberWord(id .. "n", mk, line.n,
        function(r, x) eachOf(r, row, function(l) l.n = x end) end, off)
    for _, p in ipairs(withNumber(phrase, nWord, function(text)
        return word(text, id .. "moment", momentDef, line.moment ~= nil, off)
    end)) do pieces[#pieces + 1] = p end
    -- "and" clauses, each its own word with its number, then the and … blank. Each
    -- goes on every action's line.
    local clauses = ck and type(line.clauses) == "table" and line.clauses or {}
    for j, cl in ipairs(clauses) do
        local keys, moreWords, refused = rowClauseChoices(kind, lines, j)
        keys[#keys + 1] = Drawer.DROP
        local def = { kind = "clause", keys = keys, values = clauseNames(kind), current = cl.cond, more = moreWords,
            refused = refused,
            onPick = function(k)
                edit(function(r)
                    eachOf(r, row, function(l)
                        if k == Drawer.DROP then dropClause(l, j) else setClause(l, j, k) end
                    end)
                end)
            end,
            clear = function() edit(function(r) eachOf(r, row, function(l) dropClause(l, j) end) end) end }
        local c = C.Get(cl.cond)
        local w = c and c.param and numberWord(id .. "cn" .. j, cl.cond, cl.n,
            function(r, x) eachOf(r, row, function(l) l.clauses[j].n = x end) end, off)
        pieces[#pieces + 1] = { text = " " .. WORDING.andWord .. " " }
        for _, p in ipairs(withNumber(Grammar.ClauseWords(cl.cond, c and Grammar.NUMBER_MARK, kind), w, function(text)
            return word(text, id .. "clause" .. j, def, true, off)
        end)) do pieces[#pieces + 1] = p end
    end
    if finished and ck and Grammar.RowTakesClauses(lines, kind) then
        local keys, moreWords, refused = rowClauseChoices(kind, lines, #clauses + 1)
        if #keys > 0 or moreWords or #refused > 0 then
            pieces[#pieces + 1] = { text = " ", aside = true }
            local chip = word(WORDING.addClause, id .. "and", { kind = "and", keys = keys, values = clauseNames(kind),
                more = moreWords, refused = refused,
                onPick = function(k)
                    edit(function(r) eachOf(r, row, function(l) setClause(l, #clauses + 1, k) end) end)
                end },
                false)
            chip.aside = true
            pieces[#pieces + 1] = chip
        end
    end
    if line.moment == "recast" then
        -- "(5 seconds before)", or Daylight UI's own timing with no lead.
        local keys, values = leadChoices()
        local before, after = aroundLead(line.at)
        pieces[#pieces + 1] = { text = " " .. before }
        pieces[#pieces + 1] = word(line.at and Grammar.Seconds(line.at) or WORDING.daylightTiming, id .. "lead", {
            kind = "seconds", keys = keys, values = values, current = line.at or "daylight",
            onPick = function(n) edit(function(r) setLead(r, n ~= "daylight" and n or nil) end) end,
            clear = line.at ~= nil and function() edit(function(r) setLead(r, nil) end) end or nil }, true, off)
        pieces[#pieces + 1] = { text = after }
    end
    pieces[#pieces + 1] = { text = joint }
    -- Each action with its own picks: "A", "A and B", "A, B, and C".
    for p, x in ipairs(row) do
        local i, line = x, rules.lines[x]
        local id = "line:" .. i .. ":"
        if p > 1 then
            local sep = #row == 2 and " " .. WORDING.andWord .. " "
                or (p == #row and ", " .. WORDING.andWord .. " " or ", ")
            pieces[#pieces + 1] = { text = sep }
        end
        -- The actions this one may become: any fitting the moment alone, else those that
        -- can stand with the line's other actions.
        local keys, refused = line.moment and actions[line.moment] or any, nil
        if #row > 1 then
            local others, rest = {}, {}
            for _, y in ipairs(row) do
                if y ~= x then others[#others + 1] = rules.lines[y] end
            end
            for _, l in ipairs(rules.lines) do
                if l ~= line then rest[#rest + 1] = l end
            end
            local can
            can, refused = Grammar.LineActions(kind, others, rest)
            keys = { line.action }
            for _, a in ipairs(can) do keys[#keys + 1] = a end
            for _, r in ipairs(refused) do r.words = Grammar.ActionWords(line.moment, r.action) end
        end
        pieces[#pieces + 1] = word(line.action and (line.action == "sound" and "play"
            or Grammar.ActionWords(line.moment, line.action))
            or WORDING.chooseWhat, id .. "action", {
            kind = "action", keys = keys, values = Grammar.ActionNames(line.moment), refused = refused,
            current = line.action,
            onPick = function(a) edit(function(r) retarget(r.lines[i], r.lines[i].moment, a, kind) end) end,
            -- One of several actions goes; a line's only action goes back to its blank.
            clear = function()
                edit(function(r)
                    if #row > 1 then
                        table.remove(r.lines, i)
                    else
                        retarget(r.lines[i], r.lines[i].moment, nil, kind)
                    end
                end)
            end },
            line.action ~= nil, off)
        local valued = line.moment ~= nil and line.action ~= nil and Grammar.ValueKind(line.moment, line.action) or nil
        if line.action == "sound" then
            local values, keys = sounds()
            local name = values[line.value]
            pieces[#pieces + 1] = { text = " " }
            pieces[#pieces + 1] = word(type(name) == "string" and name or tostring(line.value), id .. "sound", {
                kind = "sound", keys = keys, values = values, current = line.value,
                onPick = function(k) edit(function(r) r.lines[i].value = k end) end }, true, off)
        elseif valued == "text" then
            pieces[#pieces + 1] = { text = " " }
            pieces[#pieces + 1] = word(type(line.value) == "string" and ("\"" .. line.value .. "\"") or WORDING.chooseText,
                id .. "text", {
                kind = "text", keys = {}, values = {}, current = line.value,
                onPick = function(t) edit(function(r) r.lines[i].value = t end) end }, line.value ~= nil, off)
        elseif valued == "icon" then
            pieces[#pieces + 1] = { text = " " }
            pieces[#pieces + 1] = word(line.value ~= nil and WORDING.iconPicked or WORDING.chooseIcon, id .. "icon", {
                kind = "icon", keys = { "pick" }, values = { pick = Drawer.COLOR_WORDS.pick }, current = nil,
                onPick = function()
                    Bridge.PickIcon({ title = WORDING.iconTitle, first = { Bridge.SpellTexture(shown) },
                        current = line.value,
                        onPick = function(icon) edit(function(r) r.lines[i].value = icon end) end })
                end, writes = false }, line.value ~= nil, off)
        elseif valued == "fill" then
            -- " my health (tint, drains) in the accent color": each pick a word of its
            -- own. A pick back at its default is left out of the value.
            local L = ns.Looks
            local source, shape, dir, color = Grammar.FillPicks(line.value, kind, line)
            local function pick(field, k, own)
                edit(function(r)
                    local v = {}
                    for f, x in pairs(type(r.lines[i].value) == "table" and r.lines[i].value or {}) do v[f] = x end
                    if k == own then v[field] = nil else v[field] = k end
                    r.lines[i].value = next(v) and v or nil
                end)
            end
            local sourceKeys, refused = Grammar.FillSources(kind, line)
            local sourceValues = {}
            for _, k in ipairs(L.FILL_SOURCES) do sourceValues[k] = Grammar.FillSourceWords(k, kind) end
            for _, r in ipairs(refused) do r.words, r.action = sourceValues[r.key], r.key end
            pieces[#pieces + 1] = { text = " " }
            pieces[#pieces + 1] = word(sourceValues[source] or tostring(source), id .. "fillSource", {
                kind = "fillSource", keys = sourceKeys, values = sourceValues, current = source, refused = refused,
                onPick = function(k) pick("source", k, sourceKeys[1] or L.FILL_SOURCE) end }, true, off)
            pieces[#pieces + 1] = { text = " (" }
            pieces[#pieces + 1] = word(WORDING.fillShapes[shape] or shape, id .. "fillShape", {
                kind = "fillShape", keys = L.FILL_SHAPES, values = WORDING.fillShapes, current = shape,
                onPick = function(k) pick("shape", k, L.FILL_SHAPE) end }, true, off)
            pieces[#pieces + 1] = { text = ", " }
            pieces[#pieces + 1] = word(WORDING.fillDirs[dir] or dir, id .. "fillDir", {
                kind = "fillDir", keys = L.FILL_DIRS, values = WORDING.fillDirs, current = dir,
                onPick = function(k) pick("dir", k, L.FILL_DIR) end }, true, off)
            pieces[#pieces + 1] = { text = ") in " }
            pieces[#pieces + 1] = word(Draft.ColorName(color), id .. "color", {
                kind = "color", keys = { "accent", "pick" }, values = Drawer.COLOR_WORDS,
                current = color == nil and "accent" or nil,
                onPick = function(k)
                    if k == "accent" then return pick("color", nil, nil) end
                    local start = color or { API.Accent() }
                    Bridge.PickColor({ start[1], start[2], start[3] }, function(c)
                        pick("color", { c[1], c[2], c[3] }, nil)
                    end)
                end, writes = false,
                clear = color ~= nil and function() pick("color", nil, nil) end or nil },
                true, off)
        elseif valued == "flare" then
            -- " (Sunrise, Pulse, Proc Alerts' sound)": each pick a word of its own. A pick
            -- back at Proc Alerts' own is left out of the value.
            local design, anim, sound = Grammar.FlarePicks(line.value)
            local function pick(field, k, own)
                edit(function(r)
                    local v = {}
                    for f, x in pairs(type(r.lines[i].value) == "table" and r.lines[i].value or {}) do v[f] = x end
                    if k == own then v[field] = nil else v[field] = k end
                    r.lines[i].value = next(v) and v or nil
                end)
            end
            local L = ns.Looks
            local sv, sk = sounds()
            local soundKeys, soundValues = { Drawer.FLARE_SOUND }, { [Drawer.FLARE_SOUND] = WORDING.flareSound }
            for _, k in ipairs(sk) do
                soundKeys[#soundKeys + 1] = k
                soundValues[k] = sv[k]
            end
            local soundNow = sound or Drawer.FLARE_SOUND
            pieces[#pieces + 1] = { text = " (" }
            pieces[#pieces + 1] = word(WORDING.flareDesigns[design] or design, id .. "design", {
                kind = "design", keys = L.FLARE_DESIGNS, values = WORDING.flareDesigns, current = design,
                onPick = function(k) pick("design", k, L.FLARE_DESIGN) end }, true, off)
            pieces[#pieces + 1] = { text = ", " }
            pieces[#pieces + 1] = word(WORDING.flareAnims[anim] or anim, id .. "anim", {
                kind = "anim", keys = L.FLARE_ANIMS, values = WORDING.flareAnims, current = anim,
                onPick = function(k) pick("anim", k, L.FLARE_ANIM) end }, true, off)
            pieces[#pieces + 1] = { text = ", " }
            local said = soundValues[soundNow]
            pieces[#pieces + 1] = word(type(said) == "string" and said or tostring(soundNow), id .. "flareSound", {
                kind = "flareSound", keys = soundKeys, values = soundValues, current = soundNow,
                onPick = function(k) pick("sound", k, Drawer.FLARE_SOUND) end }, true, off)
            pieces[#pieces + 1] = { text = ")" }
        elseif line.action == "glow" or line.action == "tint" or valued == "color" then
            -- A glow's own style, unless it is EZ-CDM's combat ring.
            if line.action == "glow" and line.moment ~= nil and not Grammar.RingOnly(kind, line.moment) then
                local keys, values = styleChoices(true)
                local text = (line.style ~= nil and WORDING.lineStyle or WORDING.lineStyleNone):format("\1")
                local before, after = text:match("^(.-)\1(.*)$")
                pieces[#pieces + 1] = { text = " " .. before }
                pieces[#pieces + 1] = word(line.style ~= nil and (values[line.style] or tostring(line.style))
                    or WORDING.pieceStyle, id .. "style", {
                    kind = "style", keys = keys, values = values, current = line.style or "piece",
                    onPick = function(k) edit(function(r) r.lines[i].style = k ~= "piece" and k or nil end) end,
                    clear = line.style ~= nil and function() edit(function(r) r.lines[i].style = nil end) end or nil },
                    true, off)
                if after ~= "" then pieces[#pieces + 1] = { text = after } end
            end
            -- The sweep's color keeps an alpha, as the card's Highlight color does.
            local alpha = line.action == "tint"
            pieces[#pieces + 1] = { text = " in " }
            pieces[#pieces + 1] = word(Draft.ColorName(line.value), id .. "color", {
                kind = "color", keys = { "accent", "pick" }, values = Drawer.COLOR_WORDS,
                current = line.value == nil and "accent" or nil,
                onPick = function(k)
                    if k == "accent" then
                        edit(function(r) r.lines[i].value = nil end)
                        return
                    end
                    local start = line.value or { API.Accent() }
                    Bridge.PickColor({ start[1], start[2], start[3], alpha and start[4] or nil }, function(c)
                        edit(function(r) r.lines[i].value = { c[1], c[2], c[3], alpha and c[4] or nil } end)
                    end, alpha)
                end, writes = false,
                clear = line.value ~= nil and function() edit(function(r) r.lines[i].value = nil end) end or nil },
                true, off)
        end
        if line.action == "numbers" then
            -- The numbers' color (nil = Daylight UI's own) and their seconds.
            local daylight = Bridge.LookDefault("lowColor")
            pieces[#pieces + 1] = { text = " in " }
            pieces[#pieces + 1] = word(Draft.ColorName(line.value or daylight), id .. "color", {
                kind = "color", keys = { "default", "pick" },
                values = { default = WORDING.daylightColor, pick = Drawer.COLOR_WORDS.pick },
                current = line.value == nil and "default" or nil,
                onPick = function(k)
                    if k == "default" then
                        edit(function(r) r.lines[i].value = nil end)
                        return
                    end
                    local start = line.value or daylight or { API.Accent() }
                    Bridge.PickColor({ start[1], start[2], start[3] }, function(c)
                        edit(function(r) r.lines[i].value = { c[1], c[2], c[3] } end)
                    end)
                end, writes = false }, true, off)
            local at = line.at or Bridge.LookDefault("lowAt")
            local keys, values = {}, {}
            for n = 1, 10 do
                keys[n] = n
                values[n] = Grammar.Seconds(n)
            end
            pieces[#pieces + 1] = { text = " " .. WORDING.lastSeconds .. " " }
            pieces[#pieces + 1] = word(Grammar.Seconds(at), id .. "seconds", {
                kind = "seconds", keys = keys, values = values, current = at,
                onPick = function(n) edit(function(r) r.lines[i].at = n end) end }, true, off)
        end
    end
    -- The and … blank after the last action: another action on this line.
    if finished and line.moment ~= nil then
        local keys, refused = Grammar.LineActions(kind, lines, rules.lines)
        if #keys > 0 or #refused > 0 then
            for _, r in ipairs(refused) do r.words = Grammar.ActionWords(line.moment, r.action) end
            pieces[#pieces + 1] = { text = " ", aside = true }
            local chip = word(WORDING.addAction, id .. "also", { kind = "also", keys = keys,
                values = Grammar.ActionNames(line.moment), refused = refused,
                onPick = function(a) addAction(line, a) end }, false)
            chip.aside = true
            pieces[#pieces + 1] = chip
        end
    end
    pieces[#pieces + 1] = { text = "." }
    local b = words(s, pieces, { onRemove = function() edit(function(r) removeLines(r, row) end) end })
    b.line, b.lines = rowId(row), row
    -- A look Daylight UI keeps away now: a one-shot look while its motion is off, a
    -- flare while Proc Alerts is off. Each once.
    local noted = {}
    for _, l in ipairs(lines) do
        local lk = finished and Grammar.ClauseRoot(l, kind)
        local act = lk and l.action and ns.Conditions.Get(lk).actions[l.action]
        local e = act and ns.Conditions.Effect(act.effect)
        local why = e and e.offNote and e.offNote()
        if why and not noted[why] then
            noted[why] = true
            local n = words(s, { { text = WORDING[why], size = "small", color = "LABEL" } })
            n[why] = rowId(row)
        end
    end
    return b
end

-- The spell's glow style, for its glows with no style of their own: shown while a
-- line glows or a style is saved. A piece whose up glow is EZ-CDM's combat ring
-- offers no style, since its line's note already says the glow is a ring. A saved
-- style stays as it is: Daylight UI uses it for the piece's other glows, and a note
-- says so.
local function styleLine(s, rules, key)
    local glows = rules.style ~= nil
    for _, l in ipairs(rules.lines) do glows = glows or l.action == "glow" end
    if not glows then return end
    local keys, values = styleChoices(false)
    if Effects.Drawn(key) and Effects.Get(key) ~= nil then
        if rules.style ~= nil then
            local name = values[rules.style] or tostring(rules.style)
            words(s, { { text = WORDING.ezRingOther:format(name), size = "small", color = "LABEL" } }).ezRingOther = true
        end
        return
    end
    local now = rules.style or Bridge.Option({}, "glowStyle")
    local text = Grammar.StyleWords("\1")
    local before, after = text:match("^(.-)\1(.*)$")
    local b = words(s, {
        { text = before },
        word(values[now] or tostring(now), "style", { kind = "style", keys = keys, values = values, current = now,
            onPick = function(k) edit(function(r) r.style = k end) end }, true),
        { text = after },
    })
    b.style = true
end

-- The one see-through amount (cdAlpha), shown while a line makes it see-through.
-- It rides on the first fade line's value, as Grammar.Decompile puts it.
local function fadeLine(s, rules)
    local first, amount
    for _, l in ipairs(rules.lines) do
        if l.action == "fade" then
            first = first or l
            if amount == nil and type(l.value) == "number" then amount = l.value end
        end
    end
    if not first then return end
    if amount == nil then amount = Bridge.Option({}, "cdAlpha") or 0 end
    local pct = math.floor(amount * 100 + 0.5)
    local keys, values = {}, {}
    for p = 0, 95, 5 do
        keys[#keys + 1] = p
        values[p] = p .. "%"
    end
    local text = upper(WORDING.amount:format("\1"))
    local before, after = text:match("^(.-)\1(.*)$")
    local b = words(s, {
        { text = before },
        word(pct .. "%", "fade", { kind = "fade", keys = keys, values = values, current = pct,
            onPick = function(p)
                edit(function(r)
                    local set = false
                    for _, l in ipairs(r.lines) do
                        if l.action == "fade" then
                            l.value = not set and p / 100 or nil
                            set = true
                        end
                    end
                end)
            end }, true),
        { text = after .. "." },
    })
    b.fade = true
end

-- What it shows, for a piece the card's What it shows row takes: one sentence,
-- always there, as the card's row is. A pick drops the lines that no longer fit,
-- as the card clears Buff missing (CdmCard.lua:378-383).
local function showsLine(s, kind, rules)
    if not Grammar.TakesShows(kind) then return end
    local now = rules.shows or kind.showing
    local values = {}
    for _, k in ipairs(Grammar.SHOWS) do values[k] = upper(Grammar.ShowsPhrase(k, kind)) end
    local b = words(s, {
        word(values[now] or tostring(now), "shows", { kind = "shows", keys = Grammar.ShowsChoices(kind), values = values,
            current = now, onPick = function(v)
                edit(function(r)
                    r.shows = v
                    local after = Draft.Kind(shown, v)
                    local keep = {}
                    for _, l in ipairs(r.lines) do
                        if l.moment == nil or l.action == nil or Grammar.Fits(after, l.moment, l.action) then
                            keep[#keep + 1] = l
                        end
                    end
                    r.lines = keep
                    local forms = {}
                    for _, f in ipairs(r.forms or {}) do
                        for _, x in ipairs(after.forms or {}) do
                            if x == f then forms[#forms + 1] = f end
                        end
                    end
                    r.forms = forms
                end)
            end }, true),
        { text = "." },
    })
    b.shows = true
end

-- Group words as strip keys: each on word, and "where" by its value.
local GROUP_KEYS, GROUP_VALUES = {}, {}
for _, w in ipairs(Grammar.GROUP) do
    if w == "where" then
        for _, x in ipairs(Grammar.WHERE) do
            local k = "where:" .. x
            GROUP_KEYS[#GROUP_KEYS + 1] = k
            GROUP_VALUES[k] = Grammar.GroupWords("where", x)
        end
    else
        GROUP_KEYS[#GROUP_KEYS + 1] = w
        GROUP_VALUES[w] = Grammar.GroupWords(w, true)
    end
end

local function setGroup(r, k, v)
    r.group = r.group or {}
    local where = k:match("^where:(.+)$")
    if where then r.group.where = v and where or nil else r.group[k] = v or nil end
end

-- The group keys set on rules, in order.
local function groupSet(rules)
    local out, group = {}, rules.group or {}
    for _, k in ipairs(GROUP_KEYS) do
        local where = k:match("^where:(.+)$")
        if (where and group.where == where) or (not where and group[k]) then out[#out + 1] = k end
    end
    return out
end

-- A faint line (Daylight UI's rule) between the spell's lines and its group section.
local function makeRule(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.line = Bridge.Rule(b)
    b.line:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.line:SetPoint("RIGHT", b, "RIGHT", 0, 0)
    return b
end

local function groupRule(s)
    local b = s:Piece("rule", makeRule, 1, pad())
    b.divider = true
    return b
end

-- Over the group words: every spell they apply to.
local function groupHead(s)
    groupRule(s)
    local names = Draft.GroupNames(shown)
    local text = #names > 1 and WORDING.wholeGroup:format(table.concat(names, ", ")) or WORDING.thisSpell
    words(s, { { text = text, size = "small", color = "LABEL" } }, { gap = pad() }).groupHead = true
end

-- Group words show only when set, one sentence each, under their heading.
local function groupLines(s, rules)
    local set = groupSet(rules)
    if #set > 0 then groupHead(s) end
    local taken, whereSet = {}, false
    for _, y in ipairs(set) do
        taken[y] = true
        whereSet = whereSet or y:find("^where:") ~= nil
    end
    for _, k in ipairs(set) do
        -- Its own word, then every word not set yet. "where" takes one value, so
        -- its other value is offered only in its own strip.
        local keys = { k }
        local isWhere = k:find("^where:") ~= nil
        for _, x in ipairs(GROUP_KEYS) do
            if x ~= k and not taken[x] and (not x:find("^where:") or isWhere or not whereSet) then
                keys[#keys + 1] = x
            end
        end
        local b = words(s, {
            word(upper(GROUP_VALUES[k]), "group:" .. k, { kind = "group", keys = keys, values = GROUP_VALUES,
                current = k, follow = function(x) return "group:" .. x end, onPick = function(x)
                    edit(function(r)
                        setGroup(r, k, false)
                        setGroup(r, x, true)
                    end)
                end,
                clear = function() edit(function(r) setGroup(r, k, false) end) end }, true),
            { text = "." },
        }, { onRemove = function() edit(function(r) setGroup(r, k, false) end) end })
        b.group = k
    end
end

-- The forms it hides in, one sentence each: "Hide it while I'm in [Bear Form]."
local function formNames()
    local names = {}
    for _, e in ipairs((Bridge.Forms() or {})[Bridge.MyClass() or ""] or {}) do names[e.key] = e.name or e.key end
    return names
end

local function formLines(s, kind, rules)
    if not (kind.forms and #kind.forms > 0) then return end
    local names = formNames()
    local chosen = {}
    for _, k in ipairs(rules.forms or {}) do chosen[k] = true end
    for _, k in ipairs(rules.forms or {}) do
        local keys = { k }
        for _, x in ipairs(kind.forms) do
            if not chosen[x] then keys[#keys + 1] = x end
        end
        local b = words(s, {
            { text = upper(Grammar.FormWords("")) },
            word(names[k] or k, "form:" .. k, { kind = "form", keys = keys, values = names, current = k,
                follow = function(x) return "form:" .. x end, onPick = function(x)
                    edit(function(r)
                        for j, y in ipairs(r.forms) do
                            if y == k then r.forms[j] = x; break end
                        end
                    end)
                end,
                clear = function()
                    edit(function(r)
                        for j, y in ipairs(r.forms) do
                            if y == k then table.remove(r.forms, j); break end
                        end
                    end)
                end }, true),
            { text = "." },
        }, { onRemove = function()
            edit(function(r)
                for j, y in ipairs(r.forms) do
                    if y == k then table.remove(r.forms, j); break end
                end
            end)
        end })
        b.form = k
    end
end

-- An add link's strip, built on every draw. The open one takes the fresh choices, so
-- what was just added is gone from it.
local function adder(id, def)
    def.writes = true
    drawn[id] = true
    if slot and slot.id == id then
        slot = def
        def.id, def.heading = id, Drawer.HEADINGS[def.kind] or ""
    end
    return def
end

-- "+ add a line", "+ a rule for its whole group", "+ a recipe" and "+ hide it in a form …".
local function addLinks(s, kind, rules)
    local pieces = {}
    local n = #rules.lines + 1
    pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_LINE, word = "line", onClick = function()
        pending[#pending + 1] = {}
        openNext = "line:" .. n .. ":moment"
        slot = nil
        Drawer.Refresh()
    end }
    local set = groupSet(rules)
    local free = {}
    for _, k in ipairs(GROUP_KEYS) do
        local taken = false
        for _, y in ipairs(set) do
            taken = taken or y == k or (y:find("^where:") and k:find("^where:"))
        end
        if not taken then free[#free + 1] = k end
    end
    if #free > 0 then
        local def = adder("group:+", { kind = "group", keys = free, values = GROUP_VALUES,
            onPick = function(k) edit(function(r) setGroup(r, k, true) end) end })
        pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_GROUP, word = "group", onClick = function()
            Drawer.Choose("group:+", def)
        end }
    end
    local recipes = Grammar.Recipes(kind)
    if #recipes > 0 then
        local def = adder("recipe:+", { kind = "recipe", keys = recipes, values = WORDING.recipes,
            onPick = function(k) edit(function(r) Grammar.ApplyRecipe(r, k) end) end })
        pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_RECIPE, word = "recipe", onClick = function()
            Drawer.Choose("recipe:+", def)
        end }
    end
    if kind.forms and #kind.forms > 0 then
        local chosen, rest = {}, {}
        for _, k in ipairs(rules.forms or {}) do chosen[k] = true end
        for _, k in ipairs(kind.forms) do
            if not chosen[k] then rest[#rest + 1] = k end
        end
        if #rest > 0 then
            local def = adder("form:+", { kind = "form", keys = rest, values = formNames(),
                onPick = function(k)
                    edit(function(r)
                        r.forms = r.forms or {}
                        r.forms[#r.forms + 1] = k
                    end)
                end })
            pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_FORM, word = "form", onClick = function()
                Drawer.Choose("form:+", def)
            end }
        end
    end
    words(s, pieces, { gap = pad() }).adds = true
end

-- ---------------------------------------------------------------------
-- The body
-- ---------------------------------------------------------------------

-- The spell's icon and name.
local function makeSpell(parent)
    local b = CreateFrame("Frame", nil, parent)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("LEFT", b, "LEFT", 0, 0)
    Bridge.CropIcon(b.icon)
    b.name = API.Text(b, "head", "LEFT")
    b.name:SetPoint("LEFT", b.icon, "RIGHT", pad(), 0)
    b.name:SetWordWrap(false)
    return b
end

local function spellHead(s, key)
    local name = Bridge.SpellName(key) or tostring(key)
    local _, h = measure(name, "head")
    local b = s:Piece("spell", makeSpell, h, pad())
    b.icon:SetTexture(Bridge.SpellTexture(key))
    b.icon:SetSize(h, h)
    b.name:SetText(name)
    paint(b.name, "VALUE")
    b.key = key
    return b
end

local function spellBody(s, key)
    spellHead(s, key)
    local kind = Grammar.Kind(key)
    local rules, first, last = current()
    showsLine(s, kind, rules)
    local fallOffNoted, buttonNoted = false, false
    for _, row in ipairs(Grammar.Rows(rules.lines, kind)) do
        sentence(s, kind, rules, row)
        local i, line = rowId(row), rules.lines[row[1]]
        local lines = rowLines(rules, row)
        local function any(fn)
            for _, l in ipairs(lines) do
                local v = fn(l)
                if v then return v end
            end
        end
        -- Daylight UI's own Gray out line while EZ-CDM owns the gray (Gray.lua).
        local owned = any(function(l) return Grammar.GrayOwnedNote(l, rules.lines) end)
        if owned then
            words(s, { { text = owned, size = "small", color = "LABEL" } }).grayOwned = i
        end
        -- A line its piece can't show, why, and the fixes. A spell button's note shows once.
        local hidden = any(function(l) return Grammar.HiddenNote(kind, l) end)
        if hidden and not (hidden.code == "button" and buttonNoted) then
            buttonNoted = buttonNoted or hidden.code == "button"
            local bits = { { text = hidden.text, size = "small", color = "LABEL" } }
            for _, fix in ipairs(hidden.fixes) do
                bits[#bits + 1] = { text = " ", size = "small" }
                if fix == "shows" then
                    bits[#bits + 1] = { kind = "add", text = Grammar.FixText(fix, kind), onClick = function()
                        edit(function(r) r.shows = "cooldown" end)
                    end }
                else
                    bits[#bits + 1] = { kind = "add", text = Grammar.FixText(fix, kind), onClick = function()
                        edit(function(r)
                            eachOf(r, row, function(l)
                                l.clauses = l.clauses or {}
                                l.clauses[#l.clauses + 1] = { cond = "noBuff" }
                            end)
                        end)
                    end }
                end
            end
            words(s, bits).hidden = i
        end
        -- What the fall-off moment can't know, once, under its first line.
        if line.moment == "recast" and not fallOffNoted then
            fallOffNoted = true
            for _, n in ipairs(Grammar.FallOffNotes(kind, rules.lines)) do
                words(s, { { text = n.text, size = "small", color = "LABEL" } }).fallOff = n.code
            end
        end
        -- Daylight UI does every action on the line anyway.
        local default = true
        for _, x in ipairs(row) do default = default and x >= first and x <= last end
        if default then
            words(s, { { text = WORDING.default, size = "small", color = "LABEL" } }).default = i
        end
        -- EZ-CDM draws this glow itself (Effects), so it shows in a fight too.
        local upGlow = any(function(l) return l.moment == "up" and l.action == "glow" end)
        if upGlow and Effects.Drawn(key) and Effects.Get(key) ~= nil then
            words(s, { { text = WORDING.ezGlow, size = "small", color = "LABEL" } }).ezGlow = i
            if Effects.Pending(key) then
                words(s, { { text = WORDING.ezGlowReload, size = "small", color = "LABEL" } }).ezReload = i
            end
        end
    end
    -- A proc EZ-CDM draws has no fall-off moment, and this says why.
    if kind.proc then
        words(s, { { text = WORDING.fallOff.hidden, size = "small", color = "LABEL" } }).fallOff = "hidden"
    end
    -- Proc Alerts lists this piece's proc, so it flares there.
    local procNote = Grammar.ProcAlertNote(kind)
    if procNote then words(s, { { text = procNote, size = "small", color = "LABEL" } }).procNote = true end
    fadeLine(s, rules)
    styleLine(s, rules, key)
    groupLines(s, rules)
    formLines(s, kind, rules)
    addLinks(s, kind, rules)
    for _, note in ipairs(Grammar.Notes(rules)) do
        words(s, { { text = note.text, size = "small", color = "LABEL" } }).note = true
    end
    for _, text in ipairs(notices) do
        words(s, { { text = text, size = "small", color = "LABEL" } }).notice = true
    end
    if refused then
        words(s, { { text = refused.text, size = "small", color = "BAD" } }).refusal = true
        for _, n in ipairs(refused.notes) do
            words(s, { { text = n, size = "small", color = "WARN" } }).refusal = true
        end
    end
end

-- The last link: Daylight UI's copy box with the bug report in it. It shows only
-- while this Daylight UI has the box, and opens nothing in a fight.
local function reportLink(s)
    if not Bridge.CanShowText() then return end
    local b = words(s, { { kind = "add", text = Drawer.COPY_REPORT, onClick = function()
        if InCombatLockdown() then return end
        Bridge.ShowText(WORDING.copyReportTitle, WORDING.copyReportHint, ns.Report.Build())
    end } }, { gap = pad() })
    b.copy = true
end

-- whole draws the spell; without the fold tab a header row folds it.
local function fillBody(whole)
    local s = parts.bodyStack
    s:Begin()
    if not tab then
        s:Row({ id = "ez:head", text = Drawer.HEAD, chevron = whole and "open" or "closed",
            onClick = function()
                lift()
                Drawer.SetExpanded(not Drawer.Expanded())
            end })
    end
    if whole then
        if shown == nil then
            s:Text(Drawer.EMPTY, { gap = tab and 0 or pad() })
        else
            spellBody(s, shown)
        end
        reportLink(s)
    end
    s:End()
    return s.height or 0
end

-- ---------------------------------------------------------------------
-- Following the editor
-- ---------------------------------------------------------------------

-- Draws the drawer for the piece picked in the editor.
function Drawer.Refresh()
    if not (on and d) then return end
    if not Bridge.EditorOpen() then return Drawer.Detach() end
    -- A + waiting for a spell: Daylight UI's card steps aside, and so does the drawer.
    if Bridge.EditorAttach() then
        waiting = true
        clip:Hide()
        if tab then tab:Hide() end
        return
    end
    if waiting then
        waiting = nil
        for _, f in ipairs({ clip, tab }) do
            f:SetAlpha(0)
            f:Show()
            API.Fade(f, 1, "FAST")
        end
    end
    local key = Bridge.Selected()
    local same = key == shown
    if not same then
        shown, slot, pending, kept, refused, notices, openNext = key, nil, {}, {}, nil, {}, nil
    end
    -- The same spell and word redraw where they were scrolled to, so a pick doesn't jump.
    local bodyAt, stripAt = 0, 0
    if same then bodyAt, stripAt = parts.bodyStack:Scrolled(), parts.stripStack:Scrolled() end
    local tray = Bridge.EditorTray()
    local w = tray:GetWidth() or 0
    innerW = w - 2 * Bridge.Edge()
    d:SetWidth(w)
    parts.body:SetWidth(w)
    parts.strip:SetWidth(w)
    local open = Drawer.Expanded()
    if not open then slot = nil end
    -- With the fold tab the drawer is drawn whole and slides; without it, it folds
    -- to its header.
    local whole = open or tab ~= nil
    drawn = {}
    local bodyH = pad() + fillBody(whole) + pad()
    -- The strip shows only while its word is on screen.
    if slot and not drawn[slot.id] then slot = nil end
    openNext = nil
    local stripH = (whole and shown ~= nil) and (pad() + fillStrip() + pad()) or 0
    local room = place(bodyH + stripH)
    if room and room > 0 and bodyH + stripH > room then
        stripH = math.min(stripH, math.floor(room / 2))
        bodyH = room - stripH
    end
    parts.body:SetHeight(bodyH)
    parts.strip:SetHeight(math.max(1, stripH))
    parts.strip:SetShown(stripH > 0)
    fullH = bodyH + stripH
    d:SetHeight(fullH)
    parts.bodyStack:ScrollTo(bodyAt)
    local stay = slot ~= nil and slot.id == stripFor
    stripFor = slot and slot.id
    parts.stripStack:ScrollTo(stay and stripAt or 0)
    if slider then
        tab:Show()
        slide(open)
    else
        clip:SetHeight(fullH)
        clip:Show()
    end
end

-- The editor picked another piece. Draw ran inside Select already, so this only
-- catches a pick the drawer hasn't drawn.
local function follow()
    if Bridge.Selected() ~= shown then Drawer.Refresh() end
end

-- Shows the drawer on the open editor.
-- Daylight UI's Open on an editor already open only shows another layout.
function Drawer.Attach()
    if not Bridge.EditorOpen() then return end
    if on then return Drawer.Refresh() end
    if not build() then return end
    on, waiting, shown, slot, pending, kept, refused, notices, openNext = true, nil, nil, nil, {}, {}, nil, {}, nil
    placed = false
    Drawer.Drop()
    watch:RegisterEvent("GLOBAL_MOUSE_DOWN")
    clip:SetAlpha(1)
    d:SetAlpha(1)
    if tab then tab:SetAlpha(1) end
    Drawer.Refresh()
end

-- Hides it with the editor, a fight's close included.
function Drawer.Detach()
    on, waiting, shown, slot, pending, kept, refused, notices, openNext = false, nil, nil, nil, {}, {}, nil, {}, nil
    watch:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    Drawer.Drop()
    if clip then clip:Hide() end
    if tab then tab:Hide() end
end

function Drawer.Frame() return d end
-- The slide's window the drawer rides in, the fold tab (nil without the info
-- panel) and the slide.
function Drawer.Clip() return clip end
function Drawer.Tab() return tab end
-- EZ-CDM's own frame that hears GLOBAL_MOUSE_DOWN.
function Drawer.Watch() return watch end
function Drawer.Slide() return slider end
-- The drawer's parts once built: body, bodyStack, strip, stripStack, rule.
function Drawer.Parts() return parts end
function Drawer.Shown() return on and clip ~= nil and clip:IsShown() and d:IsShown() end
-- The piece the drawer shows, or nil.
function Drawer.Key() return shown end
-- The last pick that didn't write ({ why, text, notes }), or nil.
function Drawer.Refused() return refused end

-- Hooks go on once Daylight UI has started its modules and the Bridge is ready.
local function hookEditor()
    if not Bridge.Ready() then return end
    Bridge.HookEditor("Open", function() Drawer.Attach() end)
    Bridge.HookEditor("Close", function() Drawer.Detach() end)
    Bridge.HookEditor("Select", follow)
    Bridge.HookEditor("Draw", function() Drawer.Refresh() end)
    Bridge.HookEditor("EndTrayMove", function() Drawer.Refresh() end)
end

API.On("Login", hookEditor, "EZ-CDM")
