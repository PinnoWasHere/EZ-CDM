local _, ns = ...

-- EZ mode inside Daylight UI's own CDM editor: a drawer that slides out of the
-- editor's spell tray, the same width. A tab on the tray's edge, the info panel's
-- fold tab, opens and folds it. It follows the piece picked in the editor and shows
-- that spell's sentences. A chosen word is Daylight UI's link in the accent, a
-- blank is its chip. Clicking either fills the strip at the drawer's bottom with
-- chips for the words that fit, and a pick writes the spell at once (Draft.Write),
-- then the editor redraws. The drawer comes and goes with the editor (/cdm too),
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

-- The strip's heading per kind of word.
Drawer.HEADINGS = WORDING.headings
Drawer.COLOR_WORDS = { accent = "accent", pick = "pick…" }

-- Why a pick didn't write, in plain words.
Drawer.REFUSED = {
    combat = "You're in combat, so nothing changed.",
    unplaced = "That spell isn't in this layout any more.",
    problems = "Nothing changed. Fix the line below first.",
    other = "Daylight UI didn't take that change.",
}

-- API.md's text sizes in px, for a line's height before the client measures one.
local SIZE_PX = { small = 12, body = 13, head = 15 }
-- Stack:Text's line spacing (Parts.lua:345).
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
local slot         -- the open strip: { id, kind, heading, keys, values, current, onPick }
local pending = {} -- the shown spell's lines not finished yet, after its own
local kept = {}    -- the shown spell's finished lines that ask for Daylight UI's default
local refused      -- the last pick that didn't write: { why, text, notes }
local notices = {} -- what the last write couldn't do, in plain words
local openNext     -- a word id whose strip opens on the next draw
local drawn = {}   -- the word ids the body shows now; a strip lives only while its word does

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
            t:SetScript("OnClick", function(self)
                lift()
                if self.piece and self.piece.onClick then self.piece.onClick(self) end
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
    local said = {}
    for i, p in ipairs(pieces) do said[i] = p.text end
    b.said = table.concat(said)
    -- A pooled block forgets what it stood for last time.
    b.line, b.group, b.form, b.note, b.notice, b.refusal, b.adds, b.fade, b.shared, b.choices, b.hint, b.default,
        b.groupHead, b.shows, b.style, b.ezGlow, b.ezReload = nil, nil, nil, nil, nil, nil, nil, nil, nil,
        nil, nil, nil, nil, nil, nil, nil, nil
    b.ezRingOther, b.fallOff, b.copy = nil, nil, nil
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

-- A mouse press anywhere decides: over one of EZ-CDM's frames it lifts them,
-- anywhere else it drops them, so a click on Daylight UI's card brings it back.
function Drawer.Press()
    for _, f in pairs(frames()) do
        if f:IsVisible() and f:IsMouseOver() then return Drawer.Lift() end
    end
    Drawer.Drop()
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

-- Writes the shown spell's finished lines, group and form words at once. Lines
-- with a blank wait in the drawer. A refusal writes nothing and says why.
local function commit(rules)
    local done, open = {}, {}
    for _, l in ipairs(rules.lines) do
        if l.moment ~= nil and l.action ~= nil then done[#done + 1] = l else open[#open + 1] = l end
    end
    -- Any write closes the strip.
    pending, refused, notices, slot = open, nil, {}, nil
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
    end
    if not ok then refused = refusal(why, report) end
    -- A glow color Daylight UI can't set back to the accent says so.
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

-- Changes the shown spell's rules and writes them.
local function edit(fn)
    if shown == nil then return end
    local rules = current()
    fn(rules)
    return commit(rules)
end

-- A strip chip: closes the strip, then drops the word in.
local function drop(k)
    local t = slot
    if not t then return end
    slot = nil
    t.onPick(k)
    if slot == nil and not t.writes then Drawer.Refresh() end
end

-- Group words apply to the whole group: a note names the others in it.
local function sharedNote(s)
    local text = Draft.GroupNote(shown)
    if text then words(s, { { text = text, size = "small", color = "LABEL" } }).shared = true end
end

local function fillStrip()
    local s = parts.stripStack
    s:Begin()
    if slot then
        words(s, { { text = slot.heading, size = "small", color = "LABEL" } })
        if slot.kind == "group" then sharedNote(s) end
        local pieces = {}
        for _, k in ipairs(slot.keys) do
            pieces[#pieces + 1] = { kind = "chip", text = slot.values[k] or tostring(k), key = k,
                on = slot.current ~= nil and k == slot.current, onClick = function() drop(k) end }
        end
        if #pieces > 0 then words(s, pieces).choices = true end
    else
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
local function momentNames()
    local out = {}
    for m in pairs(WORDING.moments) do out[m] = (Grammar.MomentWords(m)) end
    return out
end

-- The moments that fit, each one's actions, and every action that fits some moment.
local function wordsFor(kind)
    local moments, actions, any, seen = {}, {}, {}, {}
    for _, w in ipairs(Grammar.Words(kind)) do
        moments[#moments + 1] = w.moment
        actions[w.moment] = w.actions
        for _, a in ipairs(w.actions) do seen[a] = true end
    end
    for _, a in ipairs(Grammar.ACTIONS) do
        if seen[a] then any[#any + 1] = a end
    end
    return moments, actions, any
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
local function retarget(line, moment, action)
    local keepAt = moment == "recast" and line.moment == "recast"
    if action ~= line.action then
        line.value, line.style = nil, nil
        if not keepAt then line.at = nil end
    end
    if line.moment == "recast" and moment ~= "recast" then line.at = nil end
    line.moment, line.action = moment, action
    if action == "sound" and line.value == nil then line.value = firstSound() end
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
    if openNext == id then
        openNext = nil
        slot = def
        def.id, def.heading = id, Drawer.HEADINGS[def.kind] or ""
    end
    return { kind = chosen and "link" or "chip", text = text, id = id, color = color, word = def.kind,
        on = not chosen and slot ~= nil and slot.id == id,
        onClick = function() Drawer.Choose(id, def) end }
end

-- The glow styles in the card's order and labels. piece puts "the spell's style"
-- first, for a glow line with no style of its own.
local function styleChoices(piece)
    local keys, values = {}, {}
    if piece then
        keys[1] = "piece"
        values.piece = WORDING.pieceStyle
    end
    for _, st in ipairs(Bridge.GlowStyles() or {}) do
        keys[#keys + 1] = st.key
        values[st.key] = st.label
    end
    return keys, values
end

local function sentence(s, kind, rules, i, line)
    local moments, actions, any = wordsFor(kind)
    local finished = line.moment ~= nil and line.action ~= nil
    local off = finished and not Grammar.Fits(kind, line.moment, line.action) and "OFF" or nil
    local id = "line:" .. i .. ":"
    local phrase, joint = Grammar.MomentWords(line.moment)
    local pieces = {}
    pieces[#pieces + 1] = word(phrase, id .. "moment", {
        kind = "moment", keys = moments, values = momentNames(), current = line.moment,
        onPick = function(m)
            edit(function(r)
                -- The action stays while it fits the new moment; a blank stays blank.
                local l = r.lines[i]
                local a = l.action
                if a ~= nil and not Grammar.Fits(kind, m, a) then a = actions[m][1] end
                retarget(l, m, a)
                if m == "recast" and l.at == nil then l.at = leadOf(r) end
                if Grammar.RingOnly(kind, m) then l.style = nil end
            end)
        end }, line.moment ~= nil, off)
    if line.moment == "recast" then
        -- "(5 seconds before)", or Daylight UI's own timing with no lead.
        local keys, values = leadChoices()
        local before, after = aroundLead(line.at)
        pieces[#pieces + 1] = { text = " " .. before }
        pieces[#pieces + 1] = word(line.at and Grammar.Seconds(line.at) or WORDING.daylightTiming, id .. "lead", {
            kind = "seconds", keys = keys, values = values, current = line.at or "daylight",
            onPick = function(n) edit(function(r) setLead(r, n ~= "daylight" and n or nil) end) end }, true, off)
        pieces[#pieces + 1] = { text = after }
    end
    pieces[#pieces + 1] = { text = joint }
    pieces[#pieces + 1] = word(line.action and (line.action == "sound" and "play" or WORDING.actions[line.action])
        or WORDING.chooseWhat, id .. "action", {
        kind = "action", keys = line.moment and actions[line.moment] or any, values = WORDING.actions,
        current = line.action,
        onPick = function(a) edit(function(r) retarget(r.lines[i], r.lines[i].moment, a) end) end },
        line.action ~= nil, off)
    if line.action == "sound" then
        local values, keys = sounds()
        local name = values[line.value]
        pieces[#pieces + 1] = { text = " " }
        pieces[#pieces + 1] = word(type(name) == "string" and name or tostring(line.value), id .. "sound", {
            kind = "sound", keys = keys, values = values, current = line.value,
            onPick = function(k) edit(function(r) r.lines[i].value = k end) end }, true, off)
    elseif line.action == "glow" or line.action == "tint" then
        -- A glow's own style, unless it is EZ-CDM's combat ring.
        if line.action == "glow" and line.moment ~= nil and not Grammar.RingOnly(kind, line.moment) then
            local keys, values = styleChoices(true)
            local text = (line.style ~= nil and WORDING.lineStyle or WORDING.lineStyleNone):format("\1")
            local before, after = text:match("^(.-)\1(.*)$")
            pieces[#pieces + 1] = { text = " " .. before }
            pieces[#pieces + 1] = word(line.style ~= nil and (values[line.style] or tostring(line.style))
                or WORDING.pieceStyle, id .. "style", {
                kind = "style", keys = keys, values = values, current = line.style or "piece",
                onPick = function(k) edit(function(r) r.lines[i].style = k ~= "piece" and k or nil end) end },
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
            end, writes = false }, true, off)
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
    pieces[#pieces + 1] = { text = "." }
    local b = words(s, pieces, { onRemove = function() edit(function(r) table.remove(r.lines, i) end) end })
    b.line = i
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
    if not kind.trackRow then return end
    local now = rules.shows or kind.showing
    local values = {}
    for _, k in ipairs(Grammar.SHOWS) do values[k] = upper(WORDING.shows[k]) end
    local b = words(s, {
        word(values[now] or tostring(now), "shows", { kind = "shows", keys = Grammar.SHOWS, values = values,
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
                current = k, onPick = function(x)
                    edit(function(r)
                        setGroup(r, k, false)
                        setGroup(r, x, true)
                    end)
                end }, true),
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
                onPick = function(x)
                    edit(function(r)
                        for j, y in ipairs(r.forms) do
                            if y == k then r.forms[j] = x; break end
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
        drawn["group:+"] = true
        pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_GROUP, word = "group", onClick = function()
            Drawer.Choose("group:+", { kind = "group", keys = free, values = GROUP_VALUES,
                onPick = function(k) edit(function(r) setGroup(r, k, true) end) end, writes = true })
        end }
    end
    local recipes = Grammar.Recipes(kind)
    if #recipes > 0 then
        drawn["recipe:+"] = true
        pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_RECIPE, word = "recipe", onClick = function()
            Drawer.Choose("recipe:+", { kind = "recipe", keys = recipes, values = WORDING.recipes,
                onPick = function(k) edit(function(r) Grammar.ApplyRecipe(r, k) end) end, writes = true })
        end }
    end
    if kind.forms and #kind.forms > 0 then
        local chosen, rest = {}, {}
        for _, k in ipairs(rules.forms or {}) do chosen[k] = true end
        for _, k in ipairs(kind.forms) do
            if not chosen[k] then rest[#rest + 1] = k end
        end
        if #rest > 0 then
            drawn["form:+"] = true
            pieces[#pieces + 1] = { kind = "add", text = Drawer.ADD_FORM, word = "form", onClick = function()
                Drawer.Choose("form:+", { kind = "form", keys = rest, values = formNames(),
                    onPick = function(k)
                        edit(function(r)
                            r.forms = r.forms or {}
                            r.forms[#r.forms + 1] = k
                        end)
                    end, writes = true })
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
    local fallOffNoted = false
    for i, line in ipairs(rules.lines) do
        sentence(s, kind, rules, i, line)
        -- What the fall-off moment can't know, once, under its first line.
        if line.moment == "recast" and not fallOffNoted then
            fallOffNoted = true
            for _, n in ipairs(Grammar.FallOffNotes(kind, rules.lines)) do
                words(s, { { text = n.text, size = "small", color = "LABEL" } }).fallOff = n.code
            end
        end
        if i >= first and i <= last then
            words(s, { { text = WORDING.default, size = "small", color = "LABEL" } }).default = i
        end
        -- EZ-CDM draws this glow itself (Effects), so it shows in a fight too.
        if line.moment == "up" and line.action == "glow" and Effects.Drawn(key) and Effects.Get(key) ~= nil then
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
    if key ~= shown then
        shown, slot, pending, kept, refused, notices, openNext = key, nil, {}, {}, nil, {}, nil
    end
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
    parts.bodyStack:ScrollTo(0)
    parts.stripStack:ScrollTo(0)
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
