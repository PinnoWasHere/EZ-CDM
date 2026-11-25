local stub = require("stub")
local CW = require("cdmworld")
local IPW = require("infopanelworld")

-- EZ-CDM/Drawer.lua: EZ mode as a drawer under Daylight UI's own CDM editor tray,
-- against Daylight UI's real Cooldown Manager, its editor and card, and the game's
-- own viewers (cdmworld, a warrior).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871
local ESSENTIAL, UTILITY, BUFFS = 0, 1, 2

local GOLD = { 1, 0.82, 0 }

-- Daylight UI with its info panel, the game's Cooldown Manager and EZ-CDM, logged in.
-- opts.noPanel leaves the info panel out.
local function world(opts)
    opts = opts or {}
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, infopanel = not opts.noPanel, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, BLOCK, RAGE, CLAP, WALL }, showAll = true })
        for id, name in pairs({ [SHOUT] = "Battle Shout", [REND] = "Rend", [BLOCK] = "Shield Block",
                                [RAGE] = "Bloodrage", [CLAP] = "Thunder Clap", [WALL] = "Shield Wall" }) do
            stub.spells[id] = { name = name }
        end
        if not opts.noPanel then IPW.Install() end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    return DUI, ns, ns.Drawer, stub.actionbars
end

-- A saved layout on talent set 1:
--   Rend - Thunder Clap - Shield Wall  (a group of three, running right)
--   Bloodrage                          (a bar on its own)
-- Thunder Clap glows gold when ready and fades on cooldown; its glow style is set too.
local function layoutWorld(opts)
    local DUI, ns, Drawer, AB = world(opts)
    local D = AB.CdmData
    local set = D.Ensure(1)
    local k = { rend = CW.ID(REND, ESSENTIAL), clap = CW.ID(CLAP, ESSENTIAL), wall = CW.ID(WALL, BUFFS),
        rage = CW.ID(RAGE, UTILITY), shout = CW.ID(SHOUT, BUFFS) }
    D.AddPiece(set, k.rend, "icon", 0, 0)
    D.AddPiece(set, k.clap, "icon", 0, 0)
    D.Hook(set, k.clap, k.rend, "right", "center")
    D.AddPiece(set, k.wall, "icon", 0, 0)
    D.Hook(set, k.wall, k.clap, "right", "center")
    D.AddPiece(set, k.rage, "bar", 0, -200)
    set.pieces[k.clap].track = "cooldown"
    D.SetSpellValue(set, k.clap, "readyGlow", true)
    D.SetSpellValue(set, k.clap, "readyGlowColor", GOLD)
    D.SetSpellValue(set, k.clap, "onCd", "fade")
    D.SetSpellValue(set, k.clap, "glowStyle", "comet")
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, Drawer, AB, k, set
end

-- The layout world with Daylight UI's editor open.
local function editorWorld(opts)
    local DUI, ns, Drawer, AB, k, set = layoutWorld(opts)
    T.truthy(AB.CdmEditor.Open(), "the editor opens")
    stub.RunTimers()
    return DUI, ns, Drawer, AB, k, set, AB.CdmEditor
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

-- A table as text, keys sorted, so two reads compare byte for byte.
local function dump(v)
    if type(v) ~= "table" then return type(v) == "string" and string.format("%q", v) or tostring(v) end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    local out = {}
    for _, k in ipairs(keys) do out[#out + 1] = "[" .. dump(k) .. "]=" .. dump(v[k]) end
    return "{" .. table.concat(out, ",") .. "}"
end

local function db() return dump(DaylightUIDB) end

-- The body's shown pieces, in order.
local function body(Drawer)
    local out = {}
    for _, b in ipairs(Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() then out[#out + 1] = b end
    end
    return out
end

local function headRow(Drawer) return body(Drawer)[1] end

-- The empty state's text, or nil.
local function emptyText(Drawer)
    for _, b in ipairs(body(Drawer)) do
        if b.text and b.text.GetText and not b.spec and stub.Text(b.text) == Drawer.EMPTY then return b end
    end
end

local function spellPiece(Drawer)
    for _, b in ipairs(body(Drawer)) do
        if b.name and b.icon and b.key ~= nil then return b end
    end
end

-- Daylight UI's /cdm handler, wherever it took the command.
local function slashCdm()
    for key, fn in pairs(SlashCmdList) do
        for i = 1, 9 do
            local s = _G["SLASH_" .. key .. i]
            if type(s) ~= "string" then break end
            if string.lower(s) == "/cdm" then return fn end
        end
    end
end

-- ---------------------------------------------------------------------
-- Step 2: the drawer
-- ---------------------------------------------------------------------

T.test("drawer: attaches under the tray on the editor's open and detaches on close", function()
    local _, _, Drawer, AB, _, _, Ed = editorWorld()
    local d, clip = Drawer.Frame(), Drawer.Clip()
    T.truthy(d, "built on the editor's first open")
    T.truthy(Drawer.Shown(), "shown")
    T.eq(clip:GetParent(), Ed.Overlay(), "on the editor's own full-screen frame")
    T.eq(d:GetParent(), clip, "riding in the slide's window")
    T.eq(d:GetFrameLevel(), Ed.Tray():GetFrameLevel(), "the tray's level")
    T.eq(clip:GetFrameLevel(), Ed.Tray():GetFrameLevel())
    T.truthy(d:GetFrameLevel() < AB.CdmCard.Frame():GetFrameLevel(), "Daylight UI's card stays above it")
    T.truthy(d:IsMouseEnabled(), "a click on it never reaches the overlay")
    local p, rel, rp = clip:GetPoint(1)
    T.eq(p, "TOPLEFT"); T.eq(rel, Ed.Tray()); T.eq(rp, "BOTTOMLEFT", "out of the tray's bottom edge")
    p, rel, rp = clip:GetPoint(2)
    T.eq(p, "TOPRIGHT"); T.eq(rel, Ed.Tray()); T.eq(rp, "BOTTOMRIGHT")
    p, rel, rp = d:GetPoint(1)
    T.eq(p, "BOTTOMLEFT"); T.eq(rel, clip); T.eq(rp, "BOTTOMLEFT", "the drawer rides the window's far edge")
    T.eq(d:GetWidth(), Ed.Tray():GetWidth(), "the tray's width")
    T.eq(clip:GetHeight(), d:GetHeight(), "open by default, all the way")
    T.eq(Drawer.side, "below")
    Ed.Close()
    T.falsy(Drawer.Shown(), "the editor's Done hides it")
    T.falsy(clip:IsShown())
    T.falsy(Drawer.Tab():IsShown(), "and its tab")
    Ed.Open()
    T.truthy(Drawer.Shown(), "back with the editor")
    noErrors()
end)

T.test("drawer: shows when /cdm opens the editor, and a fight closes both", function()
    local _, _, Drawer, AB = layoutWorld()
    local cdm = slashCdm()
    T.truthy(cdm, "Daylight UI owns /cdm")
    cdm("")
    stub.RunTimers()
    T.truthy(AB.CdmEditor.IsOpen(), "/cdm opened the editor")
    T.truthy(Drawer.Shown(), "the drawer came with it")
    stub.EnterCombat()
    T.falsy(AB.CdmEditor.IsOpen(), "Daylight UI closes its editor for a fight")
    T.falsy(Drawer.Shown(), "and the drawer with it")
    stub.LeaveCombat()
    noErrors()
end)

T.test("drawer: the editor's functions are followed through Daylight UI's public hook", function()
    local DUI, ns, _, AB = layoutWorld()
    local Ed = AB.CdmEditor
    for name in pairs(ns.Bridge.EDITOR_HOOKS) do
        local found = false
        for _, path in ipairs(ns.Bridge.NEEDS) do found = found or path == "ActionBars.CdmEditor." .. name end
        T.truthy(found, name .. " is listed in Bridge.NEEDS")
    end
    -- A second plugin's hook on the same function keeps working beside EZ-CDM's.
    local seen = 0
    DUI.API.For("Other").Hook(Ed, "Select", function() seen = seen + 1 end)
    Ed.Open()
    Ed.Select(CW.ID(CLAP, ESSENTIAL))
    T.eq(seen, 1, "the other plugin's hook ran")
    T.eq(ns.Drawer.Key(), CW.ID(CLAP, ESSENTIAL), "and EZ-CDM's")
    T.falsy(ns.Bridge.HookEditor("Remove", function() end), "only the listed functions")
    noErrors()
end)

T.test("drawer: shows the empty state with nothing picked", function()
    local DUI, _, Drawer = editorWorld()
    T.isnil(Drawer.Key())
    T.falsy(headRow(Drawer).spec, "no header row: the tab folds it")
    local e = emptyText(Drawer)
    T.truthy(e, "the empty state")
    local ink = DUI.API.Colors().TEXT
    local r, g, b = e.text:GetTextColor()
    T.deq({ r, g, b }, { ink[1], ink[2], ink[3] }, "in TEXT")
    T.isnil(spellPiece(Drawer), "no spell")
    noErrors()
end)

T.test("drawer: follows the piece picked in the editor", function()
    local DUI, _, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    T.eq(Drawer.Key(), k.clap, "follows Select")
    local s = spellPiece(Drawer)
    T.truthy(s, "the spell's head")
    T.eq(stub.Text(s.name), "Thunder Clap")
    local ink = DUI.API.Colors().VALUE
    local r, g, b = s.name:GetTextColor()
    T.deq({ r, g, b }, { ink[1], ink[2], ink[3] }, "in VALUE")
    T.eq(s.icon:GetTexture(), Ed.SpellTexture(k.clap), "the editor's own icon")
    T.isnil(emptyText(Drawer), "no empty state")
    Ed.Select(k.rage)
    T.eq(stub.Text(spellPiece(Drawer).name), "Bloodrage", "another pick")
    Ed.Select(nil)
    T.isnil(Drawer.Key())
    T.truthy(emptyText(Drawer), "back to the empty state")
    -- The editor picks a spell it adds itself (Ed.Add), without Select.
    Ed.Add(k.shout, "icon")
    T.eq(Drawer.Key(), k.shout, "follows the editor's own pick")
    -- Removing the picked spell clears it.
    Ed.Remove(k.shout)
    T.isnil(Drawer.Key())
    T.eq(AB.CdmData.Get(1).pieces[k.shout], nil)
    noErrors()
end)

-- Runs the slide to its end.
local function settle(Drawer) stub.RunOnUpdate(Drawer.Slide().driver, 1) end

T.test("drawer tab: the info panel's fold tab, centered on the tray's bottom edge", function()
    local DUI, ns, Drawer, _, _, _, Ed = editorWorld()
    local tab, clip, d = Drawer.Tab(), Drawer.Clip(), Drawer.Frame()
    local Panel = stub.infopanel.Panel
    T.truthy(tab and tab:IsShown(), "shown with the drawer")
    T.eq(tab:GetParent(), Ed.Overlay())
    T.eq(tab:GetFrameLevel(), d:GetFrameLevel() - 1, "behind the drawer's edge, as the info panel tucks its tab")
    local T_ = ns.Bridge.BorderPx(d)
    local p, rel, rp, x, y = tab:GetPoint(1)
    T.eq(p, "TOP"); T.eq(rel, clip); T.eq(rp, "BOTTOM", "centered on the slide's far edge")
    T.eq(x, 0); T.eq(y, T_, "tucked behind the border")
    T.eq(tab:GetHeight(), Panel.TAB[1] + T_, "the fold tab's thickness")
    T.eq(stub.Text(tab.label), "EZ-CDM")
    local _, size = tab.label:GetFont()
    T.eq(size, DUI.Style.SIZE.small, "API.Text small")
    local label = DUI.API.Colors().LABEL
    T.deq({ tab.label:GetTextColor() }, { label[1], label[2], label[3], 1 }, "in LABEL")
    T.eq(#tab.chev, 2, "a chevron each side")
    for _, c in ipairs(tab.chev) do
        T.eq(c:GetTexture(), DUI.MEDIA .. "ui-chevron.png", "Daylight UI's chevron art")
        T.eq(c:GetWidth(), Panel.ARROW, "the fold tab's chevron size")
        T.deq({ c:GetVertexColor() }, { Panel.ARROW_COLOR[1], Panel.ARROW_COLOR[2], Panel.ARROW_COLOR[3], 1 },
            "the fold tab's chevron color")
        T.eq(c.__rotation, math.pi, "open: pointing up, where a click folds it")
    end
    local p1, r1, rp1 = tab.chev[1]:GetPoint(1)
    T.eq(p1, "RIGHT"); T.eq(r1, tab.label); T.eq(rp1, "LEFT", "chevron, EZ-CDM, chevron")
    p1, r1, rp1 = tab.chev[2]:GetPoint(1)
    T.eq(p1, "LEFT"); T.eq(r1, tab.label); T.eq(rp1, "RIGHT")
    T.truthy(tab:GetWidth() > tab.label:GetStringWidth() + 2 * Panel.ARROW, "room for the words and both chevrons")
    T.truthy(DUI.Style.GetShell(tab), "Daylight UI's shell")
    tab:GetScript("OnEnter")(tab)
    local ar, ag, ab = DUI.API.Accent()
    T.deq({ tab.chev[1]:GetVertexColor() }, { ar, ag, ab, 1 }, "the accent on hover, as the info panel's")
    tab:GetScript("OnLeave")(tab)
    T.deq({ tab.chev[1]:GetVertexColor() }, { Panel.ARROW_COLOR[1], Panel.ARROW_COLOR[2], Panel.ARROW_COLOR[3], 1 })
    noErrors()
end)

T.test("drawer tab: toggles the drawer, and the state is saved", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local tab, clip, d = Drawer.Tab(), Drawer.Clip(), Drawer.Frame()
    local full = d:GetHeight()
    T.truthy(Drawer.Expanded())
    tab:Click()
    T.eq(EZCDMDB.drawer, false, "saved folded")
    T.falsy(Drawer.Expanded())
    T.eq(Drawer.Slide().goal, 0, "sliding in")
    settle(Drawer)
    T.eq(Drawer.Slide().p, 0)
    T.falsy(clip:IsShown(), "folded away")
    T.truthy(tab:IsShown(), "the tab stays on the tray's edge")
    T.eq(tab.chev[1].__rotation, 0, "pointing down, where a click opens it")
    T.eq(d:GetHeight(), full, "drawn whole, ready to slide out")
    Ed.Close()
    Ed.Open()
    T.falsy(Drawer.Expanded(), "still folded after the editor closes and opens")
    T.eq(Drawer.Slide().p, 0, "the first layout jumps there")
    T.falsy(clip:IsShown())
    tab:Click()
    T.eq(EZCDMDB.drawer, true, "saved open")
    T.truthy(clip:IsShown(), "on its way out")
    settle(Drawer)
    T.eq(Drawer.Slide().p, 1)
    T.eq(clip:GetHeight(), d:GetHeight(), "all the way out")
    T.truthy(emptyText(Drawer), "the editor opened with nothing picked")
    noErrors()
end)

T.test("drawer tab: the slide uses the info panel's timing and grows out of the tray's edge", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local s, clip, d = Drawer.Slide(), Drawer.Clip(), Drawer.Frame()
    local Panel = stub.infopanel.Panel
    T.eq(s.dur, Panel.SLIDE, "Panel.SLIDE seconds")
    T.truthy(getmetatable(s) == getmetatable(DaylightUI.Motion.Slider(function() end)), "Daylight UI's Motion.Slider")
    local full = d:GetHeight()
    Drawer.Tab():Click()
    stub.RunOnUpdate(s.driver, Panel.SLIDE / 2)
    T.truthy(s.p > 0 and s.p < 1, "half way: " .. tostring(s.p))
    T.truthy(math.abs(clip:GetHeight() - s.p * full) < 0.01, "the window as tall as the slide")
    T.truthy(math.abs(d:GetAlpha() - s.p) < 0.0001, "the drawer fades with it, as the meter does")
    T.truthy(clip.__clips, "clipped while it moves")
    T.eq(d:GetHeight(), full, "the drawer keeps its height and rides the edge")
    stub.RunOnUpdate(s.driver, Panel.SLIDE)
    T.eq(s.p, 0)
    Drawer.Tab():Click()
    stub.RunOnUpdate(s.driver, Panel.SLIDE)
    T.eq(s.p, 1)
    T.falsy(clip.__clips, "at rest open, its shadow shows whole")
    noErrors()
end)

T.test("drawer: without the info panel, a header row with Daylight UI's chevron folds it", function()
    local _, ns, Drawer, _, k, _, Ed = editorWorld({ noPanel = true })
    T.isnil(ns.Bridge.FoldTab(), "no fold tab to borrow")
    T.truthy(ns.Bridge.Ready(), "EZ-CDM stays on")
    T.isnil(Drawer.Tab(), "no tab")
    T.isnil(Drawer.Slide(), "no slide")
    Ed.Select(k.clap)
    local row = headRow(Drawer)
    T.truthy(row.spec and row.chevron, "Daylight UI's row with its open/closed chevron")
    T.eq(stub.Text(row.text), "EZ")
    T.eq(row.spec.chevron, "open", "open by default")
    local tall = Drawer.Frame():GetHeight()
    T.truthy(Drawer.Parts().strip:IsShown(), "the strip shows while open")
    row:Click()
    T.eq(EZCDMDB.drawer, false, "saved collapsed")
    T.eq(#body(Drawer), 1, "only the header")
    T.eq(headRow(Drawer).spec.chevron, "closed", "the chevron turns")
    T.falsy(Drawer.Parts().strip:IsShown(), "no strip")
    T.truthy(Drawer.Frame():GetHeight() < tall, "shorter")
    T.eq(Drawer.Clip():GetHeight(), Drawer.Frame():GetHeight(), "the window fits it")
    headRow(Drawer):Click()
    T.eq(EZCDMDB.drawer, true)
    noErrors()
end)

T.test("drawer: over the tray when the screen has no room under it", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    local tray, o = Ed.Tray(), Ed.Overlay()
    -- The tray at its default spot, 16 px above the screen's bottom.
    tray.GetBottom = function() return 16 end
    tray.GetTop = function() return 16 + 120 end
    o.GetBottom = function() return 0 end
    o.GetTop = function() return 768 end
    Ed.Select(k.clap)
    local clip = Drawer.Clip()
    T.eq(Drawer.side, "above")
    local p, rel, rp = clip:GetPoint(1)
    T.eq(p, "BOTTOMLEFT"); T.eq(rel, tray); T.eq(rp, "TOPLEFT", "out of the tray's top edge")
    p, rel, rp = Drawer.Frame():GetPoint(1)
    T.eq(p, "TOPLEFT"); T.eq(rel, clip); T.eq(rp, "TOPLEFT", "riding its far edge")
    p, rel, rp = Drawer.Tab():GetPoint(1)
    T.eq(p, "BOTTOM"); T.eq(rel, clip); T.eq(rp, "TOP", "the tab on that edge")
    T.eq(Drawer.Tab().chev[1].__rotation, 0, "pointing down, where a click folds it")
    -- Dragged up the screen: under it again once the drag ends.
    tray.GetBottom = function() return 500 end
    tray.GetTop = function() return 620 end
    Ed.EndTrayMove()
    T.eq(Drawer.side, "below", "follows the tray's move")
    noErrors()
end)

T.test("drawer: steps aside while a + waits for a spell, as Daylight UI's card does", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    Ed.SetAttach(k.clap, "right")
    T.falsy(Drawer.Clip():IsShown(), "hidden while the + waits")
    T.falsy(Drawer.Tab():IsShown(), "its tab too")
    Ed.SetAttach(nil)
    T.truthy(Drawer.Clip():IsShown(), "back")
    T.truthy(Drawer.Tab():IsShown())
    noErrors()
end)

T.test("drawer: opening, picking and collapsing write nothing to Daylight UI", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    local before = db()
    Ed.Select(k.clap)
    Ed.Select(k.rage)
    Drawer.Tab():Click()
    Drawer.Tab():Click()
    T.eq(db(), before, "DaylightUIDB deep-equal")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Step 3: sentences, chips and live writes
-- ---------------------------------------------------------------------

-- The body's sentence blocks, in order.
local function sentences(Drawer)
    local out = {}
    for _, b in ipairs(body(Drawer)) do
        if b.line then out[#out + 1] = b end
    end
    return out
end

local function said(Drawer)
    local out = {}
    for _, b in ipairs(sentences(Drawer)) do out[#out + 1] = b.said end
    return table.concat(out, "\n")
end

-- Line i's word of a kind ("moment", "action", "sound", "color").
local function wordOf(Drawer, i, kind)
    local b = sentences(Drawer)[i]
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == kind then return t end
    end
end

local function blockWith(Drawer, field)
    for _, b in ipairs(body(Drawer)) do
        if b[field] then return b end
    end
end

local function blocksWith(Drawer, field)
    local out = {}
    for _, b in ipairs(body(Drawer)) do
        if b[field] then out[#out + 1] = b end
    end
    return out
end

-- The see-through amount's word.
local function fadeWord(Drawer)
    local b = blockWith(Drawer, "fade")
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == "fade" then return t end
    end
end

-- An add link: "line", "group" or "form".
local function addLink(Drawer, kind)
    local b = blockWith(Drawer, "adds")
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == kind then return t end
    end
end

-- The strip: its heading, chip keys in order, chips by key, or the hint alone.
local function strip(Drawer)
    local out = { keys = {}, chip = {} }
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() and b.tokens then
            if b.choices then
                for _, t in ipairs(b.tokens) do
                    out.keys[#out.keys + 1] = t.piece.key
                    out.chip[t.piece.key] = t
                end
            elseif b.shared then
                out.note = b.said
            elseif b.hint then
                out.hint = b.said
            else
                out.heading = b.said
            end
        end
    end
    return out
end

local function keysText(list)
    local out = {}
    for i, k in ipairs(list) do out[i] = tostring(k) end
    return table.concat(out, " ")
end

local function pick(Drawer, key)
    local c = strip(Drawer).chip[key]
    T.truthy(c, "the strip has " .. tostring(key))
    c:Click()
end

local function pieceOf(key) return stub.actionbars.CdmData.Get(1).pieces[key] end
local function chainOf(key) return stub.actionbars.CdmData.Get(1).chains[key] end

-- What Daylight UI's own card reads for the picked piece.
local function cardReads(AB, field)
    for _, r in ipairs(AB.CdmCard.ROWS.show) do
        if r.item and r.item.key == "cdm.card." .. field then return r.item.get() end
    end
end

-- Every spell and group option Daylight UI's setters take, by field, in order.
local function spyWrites(AB)
    local log, D = {}, AB.CdmData
    local s, c = D.SetSpellValue, D.SetChainValue
    D.SetSpellValue = function(set, id, f, v) log[#log + 1] = f; return s(set, id, f, v) end
    D.SetChainValue = function(set, id, f, v) log[#log + 1] = "chain." .. f; return c(set, id, f, v) end
    return log, function() D.SetSpellValue, D.SetChainValue = s, c end
end

local function rgb(fs)
    local r, g, b = fs:GetTextColor()
    return { r, g, b }
end

T.test("drawer sentences: chosen words are Daylight UI's links in the accent, text in TEXT", function()
    local DUI, ns, Drawer, _, k, _, Ed = editorWorld()
    local links = 0
    local keepLink = DUI.Widgets.Link
    DUI.Widgets.Link = function(...) links = links + 1; return keepLink(...) end
    Ed.Select(k.clap)
    DUI.Widgets.Link = keepLink
    T.truthy(links > 0, "Daylight UI's W.Link made the words")
    T.eq(said(Drawer), "When it's ready, glow with the spell's style in gold.\nWhile it's cooling down, make it see-through.",
        "Grammar.Describe's wording, with the glow's style word")
    local rules = ns.Draft.Rules(k.clap)
    for i, line in ipairs(rules.lines) do
        local want = ns.Grammar.Describe(line):gsub("glow in the color you picked", "glow with the spell's style in gold")
        T.eq(sentences(Drawer)[i].said, want, "line " .. i .. " reads as Describe")
    end
    local m = wordOf(Drawer, 1, "moment")
    T.truthy(m.SetLabel and m.line, "a chosen word is Daylight UI's link, underline and all")
    T.deq(rgb(m.text), { DUI.API.Accent() }, "in the accent")
    T.eq(stub.Text(m.text), "When it's ready", "the moment is one phrase")
    local plain
    for _, t in ipairs(sentences(Drawer)[1].tokens) do
        if not t.piece.kind then plain = t end
    end
    local ink = DUI.API.Colors().TEXT
    T.deq(rgb(plain.text), { ink[1], ink[2], ink[3] }, "plain words in TEXT")
    T.eq(stub.Text(wordOf(Drawer, 1, "color").text), "gold", "the glow's color by name")
    T.truthy(sentences(Drawer)[1].remove:IsShown(), "each line has Daylight UI's remove button")
    noErrors()
end)

T.test("drawer sentences: + add a line gives blanks as Daylight UI's chips, the first one open", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local before = db()
    local chips = 0
    local keepChip = DUI.Widgets.Chip
    DUI.Widgets.Chip = function(...) chips = chips + 1; return keepChip(...) end
    addLink(Drawer, "line"):Click()
    DUI.Widgets.Chip = keepChip
    T.truthy(chips > 0, "Daylight UI's W.Chip made the blanks")
    local blank = wordOf(Drawer, 3, "moment")
    T.truthy(blank.SetOn and blank.FitWidth, "a blank is Daylight UI's chip")
    T.eq(stub.Text(blank.text), "choose a moment")
    T.truthy(blank.on, "the blank whose strip is open is lit")
    T.eq(stub.Text(wordOf(Drawer, 3, "action").text), "choose what happens")
    T.falsy(wordOf(Drawer, 3, "action").on)
    T.eq(sentences(Drawer)[3].said, "choose a moment, choose what happens.", "[choose a moment], [choose what happens].")
    T.eq(strip(Drawer).heading, "Choose a moment:", "its strip opened")
    T.eq(db(), before, "a blank writes nothing")
    noErrors()
end)

T.test("drawer wording: every moment chip is the same phrase the sentence shows", function()
    local _, ns, Drawer, _, k, _, Ed = editorWorld()
    local G = ns.Grammar
    Ed.Select(k.clap)
    addLink(Drawer, "line"):Click()
    local keys = strip(Drawer).keys
    T.truthy(#keys > 1, "the moments that fit")
    for _, m in ipairs(keys) do
        if m == Drawer.MORE then break end
        local kind = G.Kind(k.clap)
        T.eq(stub.Text(strip(Drawer).chip[m].text), (G.MomentWords(m, nil, kind)), m .. "'s chip is its phrase")
        pick(Drawer, m)
        -- A moment that takes a number shows its words up to it; the number box follows.
        local want = G.MomentWords(m, nil, kind)
        local c = ns.Conditions.Get(m)
        if c and c.param then want = want:match("^(.-)%s*N") end
        T.eq(stub.Text(wordOf(Drawer, 3, "moment").text), want, m .. ": the sentence shows the same")
    end
    -- Always takes no comma: "Always show it."
    pick(Drawer, "always")
    T.eq(sentences(Drawer)[3].said, "Always choose what happens.")
    local m, a = wordOf(Drawer, 3, "moment"), wordOf(Drawer, 3, "action")
    local _, _, _, mx = m:GetPoint(1)
    local _, _, _, ax = a:GetPoint(1)
    T.truthy(ax > mx + m:GetWidth(), "a space between Always and its action")
    noErrors()
end)

T.test("drawer strip: lists exactly what Grammar.Words allows, the current one lit", function()
    local _, ns, Drawer, AB, k, set, Ed = editorWorld()
    local G = ns.Grammar
    Ed.Select(k.clap)
    local kind = G.Kind(k.clap)
    local moments, actions = {}, {}
    for _, w in ipairs(G.Words(kind, { drawer = true })) do
        moments[#moments + 1] = w.moment
        actions[w.moment] = w.actions
    end
    -- Advanced words wait behind more…, the strip's last chip.
    if ns.Conditions.AnyAdvanced() then moments[#moments + 1] = Drawer.MORE end
    T.eq(keysText(strip(Drawer).keys), "", "nothing until a word is clicked")
    wordOf(Drawer, 1, "moment"):Click()
    local s = strip(Drawer)
    T.eq(s.heading, "Choose a moment:")
    T.eq(keysText(s.keys), keysText(moments), "the moments that fit")
    T.truthy(s.chip.ready.on, "the current one is lit (SetOn)")
    T.falsy(s.chip.cooldown.on)
    T.truthy(s.chip.ready.SetOn, "each is Daylight UI's chip")
    T.eq(stub.Text(s.chip.usable.text), "When it becomes castable", "in the player's words")
    wordOf(Drawer, 1, "moment"):Click()
    T.isnil(Drawer.Slot(), "a second click closes it")
    T.eq(keysText(strip(Drawer).keys), "")
    wordOf(Drawer, 1, "action"):Click()
    T.eq(keysText(strip(Drawer).keys), keysText(actions.ready), "the actions that fit when ready")
    wordOf(Drawer, 1, "color"):Click()
    T.eq(keysText(strip(Drawer).keys), "accent pick", "a glow's color")
    wordOf(Drawer, 2, "action"):Click()
    T.eq(keysText(strip(Drawer).keys), keysText(actions.cooldown), "gray fits an icon on cooldown")
    fadeWord(Drawer):Click()
    T.eq(#strip(Drawer).keys, 20, "the see-through amount, 0 to 95%")
    addLink(Drawer, "group"):Click()
    T.eq(keysText(strip(Drawer).keys), "combat target group mounted where:instance where:world keep", "every group word")
    addLink(Drawer, "form"):Click()
    T.eq(keysText(strip(Drawer).keys), keysText(kind.forms), "the stances it can hide in")
    -- A bar: gray isn't offered on cooldown.
    Ed.Select(k.rage)
    T.isnil(Drawer.Slot(), "another spell starts with no strip")
    addLink(Drawer, "line"):Click()
    pick(Drawer, "cooldown")
    wordOf(Drawer, 1, "action"):Click()
    local want
    for _, w in ipairs(G.Words(G.Kind(k.rage))) do
        if w.moment == "cooldown" then want = w.actions end
    end
    T.eq(keysText(strip(Drawer).keys), keysText(want), "a bar's cooldown actions")
    T.falsy(strip(Drawer).chip.gray, "no gray for a bar")
    -- A buff: its own moments.
    AB.CdmData.AddPiece(set, k.shout, "icon", 200, 0)
    Ed.Changed()
    Ed.Select(k.shout)
    addLink(Drawer, "line"):Click()
    local shoutMoments = {}
    for _, w in ipairs(G.Words(G.Kind(k.shout), { drawer = true })) do shoutMoments[#shoutMoments + 1] = w.moment end
    if ns.Conditions.AnyAdvanced() then shoutMoments[#shoutMoments + 1] = Drawer.MORE end
    T.eq(keysText(strip(Drawer).keys), keysText(shoutMoments), "a buff's moments")
    noErrors()
end)

-- No strip: no heading, no chips, only the hint.
local function noStrip(Drawer, why)
    local s = strip(Drawer)
    T.isnil(Drawer.Slot(), why)
    T.isnil(s.heading, why .. ": no heading")
    T.eq(#s.keys, 0, why .. ": no chips")
    T.eq(s.hint, Drawer.HINT, why .. ": only the hint")
end

T.test("drawer strip: shows only while a word is picked, else only the hint", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    -- Bloodrage has no lines.
    Ed.Select(k.rage)
    T.eq(#sentences(Drawer), 0, "a spell with no lines")
    noStrip(Drawer, "a spell with no lines")
    -- Picking a blank shows the strip.
    addLink(Drawer, "line"):Click()
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.moment, "picking a blank shows its strip")
    T.truthy(#strip(Drawer).keys > 0)
    T.isnil(strip(Drawer).hint, "no hint while it shows")
    -- Removing the line whose blank is open closes it.
    sentences(Drawer)[1].remove:Click()
    T.eq(#sentences(Drawer), 0)
    noStrip(Drawer, "the line went")
    -- After a pick, the strip stays on its word.
    addLink(Drawer, "line"):Click()
    pick(Drawer, "cooldown")
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.moment, "after a pick")
    wordOf(Drawer, 1, "action"):Click()
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.action)
    pick(Drawer, "hide")
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.action, "after a pick that writes")
    -- A change of spell.
    Ed.Select(k.clap)
    noStrip(Drawer, "another spell")
    addLink(Drawer, "group"):Click()
    T.truthy(Drawer.Slot())
    Ed.Select(nil)
    Ed.Select(k.clap)
    noStrip(Drawer, "the same spell picked again")
    -- Closing.
    wordOf(Drawer, 1, "moment"):Click()
    Ed.Close()
    Ed.Open()
    Ed.Select(k.clap)
    noStrip(Drawer, "after the editor closes")
    noErrors()
end)

T.test("drawer writes: a pick writes the right fields live, and Daylight UI's card reads them back", function()
    local _, ns, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local redraws, keep = 0, ns.Bridge.EditorChanged
    ns.Bridge.EditorChanged = function(...) redraws = redraws + 1; return keep(...) end
    local log, unspy = spyWrites(AB)
    local look = dump({ pieceOf(k.clap).glowStyle, pieceOf(k.clap).shape, pieceOf(k.clap).look })
    -- While it's cooling down: see-through to hidden.
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "hide")
    T.eq(table.concat(log, ","), "onCd", "only the field that changed")
    T.eq(pieceOf(k.clap).onCd, "hide", "saved at once")
    T.eq(cardReads(AB, "onCd"), "hide", "Daylight UI's card reads it back")
    T.eq(redraws, 1, "the editor redrew")
    T.eq(Drawer.Slot().kind, "action", "the strip stays")
    T.eq(said(Drawer), "When it's ready, glow with the spell's style in gold.\nWhile it's cooling down, hide it.", "drawn again from the layout")
    -- When it's ready to when it becomes castable: the glow moves, its color with it.
    for i = #log, 1, -1 do log[i] = nil end
    wordOf(Drawer, 1, "moment"):Click()
    pick(Drawer, "usable")
    T.eq(table.concat(log, ","), "readyGlow,usableGlow,usableGlowColor")
    T.isnil(pieceOf(k.clap).readyGlow, "the ready glow is off (Daylight UI drops its default)")
    T.eq(pieceOf(k.clap).usableGlow, true)
    T.eq(pieceOf(k.clap).usableGlowColor[2], GOLD[2], "in gold")
    T.eq(cardReads(AB, "usableGlow"), true, "the card's Glow when usable")
    T.eq(cardReads(AB, "readyGlow"), false, "and its Glow")
    -- A new line writes once both blanks are filled.
    for i = #log, 1, -1 do log[i] = nil end
    addLink(Drawer, "line"):Click()
    pick(Drawer, "unusable")
    T.eq(#log, 0, "half a line writes nothing")
    T.eq(sentences(Drawer)[3].said, "When it's not usable, choose what happens.")
    wordOf(Drawer, 3, "action"):Click()
    pick(Drawer, "hide")
    T.eq(table.concat(log, ","), "onUnusable")
    T.eq(cardReads(AB, "onUnusable"), "hide", "the card's Not usable")
    T.eq(dump({ pieceOf(k.clap).glowStyle, pieceOf(k.clap).shape, pieceOf(k.clap).look }), look,
        "glow style, shape and look untouched")
    unspy()
    ns.Bridge.EditorChanged = keep
    noErrors()
end)

T.test("drawer writes: the see-through amount, a sound and a glow color", function()
    local _, _, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    fadeWord(Drawer):Click()
    pick(Drawer, 25)
    T.eq(pieceOf(k.clap).cdAlpha, 0.25, "Fade to 25%")
    T.eq(cardReads(AB, "cdAlpha"), 0.25)
    T.eq(stub.Text(fadeWord(Drawer).text), "25%")
    wordOf(Drawer, 1, "action"):Click()
    pick(Drawer, "sound")
    T.isnil(pieceOf(k.clap).readyGlow, "the glow made way")
    T.truthy(type(pieceOf(k.clap).readySound) == "string" and pieceOf(k.clap).readySound ~= "none", "a sound")
    T.eq(cardReads(AB, "readySound"), pieceOf(k.clap).readySound, "the card's Sound")
    local name = wordOf(Drawer, 1, "sound")
    T.truthy(name and stub.Text(name.text) ~= "", "the sound by name")
    -- A color from the picker.
    local keepPicker = rawget(_G, "ColorPickerFrame")
    local info
    _G.ColorPickerFrame = { SetupColorPickerAndShow = function(_, t) info = t end,
        GetColorRGB = function() return 1, 0, 0 end, HookScript = function() end }
    local ok, err = pcall(function()
        pick(Drawer, "glow")
        wordOf(Drawer, 1, "color"):Click()
        pick(Drawer, "pick")
        T.truthy(info, "Daylight UI's color picker opened")
        info.swatchFunc()
        T.deq(pieceOf(k.clap).readyGlowColor, { 1, 0, 0 }, "the picked color is saved")
        T.eq(stub.Text(wordOf(Drawer, 1, "color").text), "red")
    end)
    _G.ColorPickerFrame = keepPicker
    assert(ok, err)
    noErrors()
end)

T.test("drawer default lines: a line Daylight UI does anyway stays, marked, and writes nothing", function()
    local DUI, _, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local before = db()
    local log, unspy = spyWrites(AB)
    addLink(Drawer, "line"):Click()
    pick(Drawer, "always")
    wordOf(Drawer, 3, "action"):Click()
    pick(Drawer, "show")
    T.eq(#log, 0, "nothing written")
    T.eq(db(), before, "DaylightUIDB deep-equal")
    T.eq(sentences(Drawer)[3].said, "Always show it.", "the line stays")
    local notes = blocksWith(Drawer, "default")
    T.eq(#notes, 1, "marked")
    T.eq(notes[1].said, "Daylight already does this.")
    T.eq(notes[1].default, 3, "under its line")
    local t = notes[1].tokens[1]
    T.eq(t.piece.size, "small")
    local label = DUI.API.Colors().LABEL
    T.deq(rgb(t.text), { label[1], label[2], label[3] }, "in LABEL")
    -- A second one, after it.
    addLink(Drawer, "line"):Click()
    pick(Drawer, "unusable")
    wordOf(Drawer, 4, "action"):Click()
    pick(Drawer, "show")
    T.eq(sentences(Drawer)[4].said, "When it's not usable, show it.")
    T.eq(#blocksWith(Drawer, "default"), 2)
    T.eq(#log, 0, "still nothing written")
    -- Another write keeps them.
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "hide")
    T.eq(table.concat(log, ","), "onCd")
    T.eq(said(Drawer), "When it's ready, glow with the spell's style in gold.\nWhile it's cooling down, hide it.\nAlways show it."
        .. "\nWhen it's not usable, show it.", "they stay through a write")
    -- A default line changed to something else writes, and reads back from the layout.
    for i = #log, 1, -1 do log[i] = nil end
    wordOf(Drawer, 4, "action"):Click()
    pick(Drawer, "hide")
    T.eq(table.concat(log, ","), "onUnusable")
    T.eq(pieceOf(k.clap).onUnusable, "hide")
    T.eq(#blocksWith(Drawer, "default"), 1, "only Always show it is marked now")
    -- A later line that overrides a default one: the default one goes.
    addLink(Drawer, "line"):Click()
    pick(Drawer, "unusable")
    wordOf(Drawer, #sentences(Drawer), "action"):Click()
    pick(Drawer, "show")
    T.isnil(pieceOf(k.clap).onUnusable, "show wins, back to Daylight UI's default")
    T.eq(#blocksWith(Drawer, "default"), 2)
    -- It goes when another spell is picked, as an unfinished line does.
    Ed.Select(k.rage)
    Ed.Select(k.clap)
    T.eq(#blocksWith(Drawer, "default"), 0, "gone with another pick")
    T.eq(said(Drawer), "When it's ready, glow with the spell's style in gold.\nWhile it's cooling down, hide it.")
    unspy()
    noErrors()
end)

T.test("drawer writes: removing a line clears its fields", function()
    local _, _, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local log, unspy = spyWrites(AB)
    sentences(Drawer)[1].remove:Click()
    T.eq(table.concat(log, ","), "readyGlow", "the glow, written back to Daylight UI's default")
    T.isnil(pieceOf(k.clap).readyGlow, "its setter drops the default")
    T.eq(cardReads(AB, "readyGlow"), false, "the card's Glow is off")
    T.eq(said(Drawer), "While it's cooling down, make it see-through.")
    -- An unfinished line goes without a write.
    addLink(Drawer, "line"):Click()
    local before = db()
    for i = #log, 1, -1 do log[i] = nil end
    sentences(Drawer)[2].remove:Click()
    T.eq(#log, 0, "nothing written")
    T.eq(db(), before, "DaylightUIDB deep-equal")
    T.eq(#sentences(Drawer), 1)
    unspy()
    noErrors()
end)

T.test("drawer: Grammar.Notes appear, small, in LABEL", function()
    local DUI, ns, Drawer, AB, k, set, Ed = editorWorld()
    AB.CdmData.SetSpellValue(set, k.clap, "usableGlow", true)
    Ed.Changed()
    Ed.Select(k.clap)
    local notes = ns.Grammar.Notes(ns.Draft.Rules(k.clap))
    T.eq(#notes, 1, "two glows that can show at once")
    local shownNotes = blocksWith(Drawer, "note")
    T.eq(#shownNotes, 1)
    T.eq(shownNotes[1].said, notes[1].text)
    local t = shownNotes[1].tokens[1]
    T.eq(t.piece.size, "small")
    local label = DUI.API.Colors().LABEL
    T.deq(rgb(t.text), { label[1], label[2], label[3] }, "in LABEL")
    noErrors()
end)

T.test("drawer writes: a refused write leaves DaylightUIDB unchanged and shows the reason", function()
    local DUI, _, Drawer, _, k, set, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 2, "action"):Click()
    local before = db()
    -- The fight starts as the word is picked, before the editor hears of it.
    stub.combat = true
    pick(Drawer, "hide")
    stub.combat = false
    T.eq(db(), before, "DaylightUIDB deep-equal")
    T.eq(Drawer.Refused().why, "combat")
    local lines = blocksWith(Drawer, "refusal")
    T.eq(lines[1].said, Drawer.REFUSED.combat, "the reason, in plain words")
    local bad = DUI.API.Colors().BAD
    T.deq(rgb(lines[1].tokens[1].text), { bad[1], bad[2], bad[3] }, "in BAD")
    T.eq(sentences(Drawer)[2].said, "While it's cooling down, make it see-through.", "the layout as it is")
    -- A line Daylight UI's card no longer offers this piece (Gray out on a bar) stays
    -- as it is: it shows in OFF and doesn't stop other writes.
    set.pieces[k.rage].desat = "grey"
    Ed.Changed()
    Ed.Select(k.rage)
    local grayWord = wordOf(Drawer, 1, "action")
    local off = DUI.API.Colors().OFF
    T.deq(rgb(grayWord.text), { off[1], off[2], off[3] }, "a word that doesn't fit is in OFF")
    addLink(Drawer, "line"):Click()
    pick(Drawer, "ready")
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "hide")
    T.isnil(Drawer.Refused(), "written")
    T.eq(pieceOf(k.rage).onReady, "hide")
    T.eq(pieceOf(k.rage).desat, "grey", "the bar's Gray out is left as it is")
    -- Daylight UI's setter won't take Gray out back on a bar: removing it is refused.
    before = db()
    sentences(Drawer)[2].remove:Click()
    T.eq(db(), before, "DaylightUIDB deep-equal")
    T.eq(Drawer.Refused().why, "rejected")
    lines = blocksWith(Drawer, "refusal")
    T.eq(lines[1].said, Drawer.REFUSED.other)
    noErrors()
end)

T.test("drawer group words: shown only when set; + a rule for its whole group adds one, and nothing moves", function()
    local _, ns, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    T.eq(#blocksWith(Drawer, "group"), 0, "no group words while none is set")
    T.eq(#blocksWith(Drawer, "groupHead"), 0, "and no group heading")
    T.eq(stub.Text(addLink(Drawer, "group").text), "+ a rule for its whole group")
    local before = dump({ clap = pieceOf(k.clap), wall = pieceOf(k.wall), rend = pieceOf(k.rend) })
    addLink(Drawer, "group"):Click()
    T.eq(strip(Drawer).heading, "Choose for the whole group:")
    local note = ns.Draft.SHARED:format("Rend and Shield Wall")
    T.eq(strip(Drawer).note, note, "the group strip names the others first")
    pick(Drawer, "combat")
    T.eq(pieceOf(k.clap).parent, k.rend, "still in Rend's group")
    T.eq(chainOf(k.rend).combat, true, "the word is on the group")
    T.isnil(chainOf(k.clap), "no group of its own")
    T.eq(dump({ clap = pieceOf(k.clap), wall = pieceOf(k.wall), rend = pieceOf(k.rend) }), before,
        "every piece where it was")
    T.eq(Drawer.Key(), k.clap, "still picked")
    local lines = blocksWith(Drawer, "group")
    T.eq(#lines, 1)
    T.eq(lines[1].said, "Only show it in combat.")
    T.truthy(lines[1].remove:IsShown())
    T.eq(#blocksWith(Drawer, "shared"), 0, "the heading replaces the note under the lines")
    -- Shield Wall reads the same word: it is the group's.
    Ed.Select(k.wall)
    T.eq(blocksWith(Drawer, "group")[1].said, "Only show it in combat.")
    Ed.Select(k.clap)
    blocksWith(Drawer, "group")[1].remove:Click()
    T.falsy((chainOf(k.rend) or {}).combat == true, "removed from the group")
    T.eq(#blocksWith(Drawer, "group"), 0)
    T.eq(#blocksWith(Drawer, "groupHead"), 0)
    -- "where" takes one value; its strip swaps it.
    Ed.Select(k.rage)
    addLink(Drawer, "group"):Click()
    pick(Drawer, "where:instance")
    T.eq(chainOf(k.rage).where, "instance")
    T.eq(blocksWith(Drawer, "group")[1].said, "Only in dungeons and raids.")
    blocksWith(Drawer, "group")[1].tokens[1]:Click()
    T.eq(keysText(strip(Drawer).keys), "where:instance combat target group mounted where:world keep")
    pick(Drawer, "where:world")
    T.eq(chainOf(k.rage).where, "world")
    addLink(Drawer, "group"):Click()
    T.eq(keysText(strip(Drawer).keys), "combat target group mounted keep", "one where at a time")
    noErrors()
end)

T.test("drawer group words: a heading over them names every spell in the group", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    addLink(Drawer, "group"):Click()
    pick(Drawer, "target")
    local heads = blocksWith(Drawer, "groupHead")
    T.eq(#heads, 1)
    T.eq(heads[1].said, "For its whole group: Rend, Thunder Clap, Shield Wall", "the group's spells, in Daylight UI's order")
    local t = heads[1].tokens[1]
    T.eq(t.piece.size, "small")
    local label = DaylightUI.API.Colors().LABEL
    T.deq(rgb(t.text), { label[1], label[2], label[3] }, "in LABEL")
    -- Over the group lines.
    local order = {}
    for _, b in ipairs(body(Drawer)) do
        if b.groupHead then order[#order + 1] = "head" elseif b.group then order[#order + 1] = "line" end
    end
    T.eq(table.concat(order, " "), "head line", "the heading sits over the group lines")
    -- A spell alone.
    Ed.Select(k.rage)
    addLink(Drawer, "group"):Click()
    pick(Drawer, "combat")
    T.eq(blocksWith(Drawer, "groupHead")[1].said, "For this spell:", "alone")
    noErrors()
end)

T.test("drawer group rule: a faint line shows only with the group section", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    T.eq(#blocksWith(Drawer, "divider"), 0, "no rule without a group section")
    addLink(Drawer, "group"):Click()
    pick(Drawer, "target")
    local rules = blocksWith(Drawer, "divider")
    T.eq(#rules, 1, "one rule with a group section")
    T.eq(rules[1].line:GetHeight(), 1, "Daylight UI's 1 px rule")
    local order = {}
    for _, b in ipairs(body(Drawer)) do
        if b.divider then order[#order + 1] = "rule" elseif b.groupHead then order[#order + 1] = "head" end
    end
    T.eq(table.concat(order, " "), "rule head", "the rule sits over the group heading")
    -- A refill reuses it.
    Ed.Select(k.rage)
    Ed.Select(k.clap)
    T.eq(#blocksWith(Drawer, "divider"), 1, "never piles up")
    blocksWith(Drawer, "group")[1].remove:Click()
    T.eq(#blocksWith(Drawer, "divider"), 0, "gone with the section")
    noErrors()
end)

T.test("drawer form words: + hide it in a form adds one, its strip swaps it, remove drops it", function()
    local _, ns, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local forms = ns.Grammar.Kind(k.clap).forms
    T.truthy(forms and #forms >= 2, "a warrior's stances")
    addLink(Drawer, "form"):Click()
    pick(Drawer, forms[1])
    T.eq(pieceOf(k.clap)["hideIn" .. forms[1]], true)
    local line = blocksWith(Drawer, "form")[1]
    T.truthy(line.said:find("^Hide it while I'm in "), line.said)
    line.tokens[#line.tokens - 1]:Click()
    pick(Drawer, forms[2])
    T.isnil(pieceOf(k.clap)["hideIn" .. forms[1]], "swapped")
    T.eq(pieceOf(k.clap)["hideIn" .. forms[2]], true)
    blocksWith(Drawer, "form")[1].remove:Click()
    T.isnil(pieceOf(k.clap)["hideIn" .. forms[2]], "dropped")
    noErrors()
end)

T.test("drawer writes: a glow color back to the accent writes nil on Daylight UI 2.2.6 (API 1.15)", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 1, "color"):Click()
    pick(Drawer, "accent")
    T.isnil(pieceOf(k.clap).readyGlowColor, "the accent again")
    T.eq(pieceOf(k.clap).readyGlow, true, "still lit")
    T.eq(#blocksWith(Drawer, "notice"), 0, "no note")
    T.eq(sentences(Drawer)[1].said, "When it's ready, glow with the spell's style in the accent color.")
    noErrors()
end)

T.test("drawer writes: on API 1.14 a glow color back to the accent says Daylight UI can't, small, in LABEL", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    DUI.API.minor = 14
    Ed.Select(k.clap)
    local before = db()
    wordOf(Drawer, 1, "color"):Click()
    pick(Drawer, "accent")
    T.eq(db(), before, "nothing written")
    local notes = blocksWith(Drawer, "notice")
    T.eq(#notes, 1)
    T.eq(notes[1].said, "Thunder Clap: Daylight UI can't set a glow back to the accent color, so it stays gold.")
    local label = DUI.API.Colors().LABEL
    T.deq(rgb(notes[1].tokens[1].text), { label[1], label[2], label[3] })
    Ed.Select(k.rage)
    Ed.Select(k.clap)
    T.eq(#blocksWith(Drawer, "notice"), 0, "gone with another pick")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- More conditions, step 2: buff extras and What it shows
-- ---------------------------------------------------------------------

-- The What it shows sentence and its word.
local function showsWord(Drawer)
    local b = blockWith(Drawer, "shows")
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == "shows" then return t, b end
    end
end

T.test("drawer shows: What it shows reads the card's pick, and a pick writes it live", function()
    local _, ns, Drawer, AB, k, set, Ed = editorWorld()
    Ed.Select(k.clap)
    local w, b = showsWord(Drawer)
    T.truthy(w, "a game piece takes What it shows")
    T.eq(b.said, "Show its cooldown.", "set to Cooldown")
    T.eq(cardReads(AB, "track"), "cooldown", "the card reads the same")
    w:Click()
    T.eq(strip(Drawer).heading, "Choose what it shows:")
    T.eq(keysText(strip(Drawer).keys), "both cooldown buff", "the card's three, in its order")
    T.truthy(strip(Drawer).chip.cooldown.on, "the current one lit")
    local log, unspy = spyWrites(AB)
    pick(Drawer, "both")
    unspy()
    T.eq(table.concat(log, ","), "track", "only the pick")
    T.eq(cardReads(AB, "track"), "both", "Daylight UI's card reads it back")
    -- Thunder Clap's aura is a debuff on its targets (AuraLinks.spells).
    T.eq(select(2, showsWord(Drawer)).said, "Show its debuff, then its cooldown.")
    -- Buff only drops the lines a buff doesn't take, as the card clears them.
    pick(Drawer, "buff")
    T.eq(pieceOf(k.clap).track, "buff")
    T.eq(#sentences(Drawer), 0, "ready and cooldown lines went")
    T.isnil(pieceOf(k.clap).readyGlow); T.isnil(pieceOf(k.clap).onCd)
    -- A weapon enchant has no such row.
    AB.CdmData.AddPiece(set, "mainhand", "icon", 300, 0)
    Ed.Changed()
    Ed.Select("mainhand")
    T.isnil(showsWord(Drawer), "nothing to pick")
    noErrors()
end)

T.test("drawer buff extras: hide the sweep, color it (with its alpha), offered as the card does", function()
    local _, ns, Drawer, AB, k, set, Ed = editorWorld()
    AB.CdmData.AddPiece(set, k.shout, "icon", 300, 0)
    Ed.Changed()
    Ed.Select(k.shout)
    addLink(Drawer, "line"):Click()
    pick(Drawer, "up")
    wordOf(Drawer, 1, "action"):Click()
    T.truthy(strip(Drawer).chip.nosweep and strip(Drawer).chip.tint, "both sweep words while active")
    T.eq(stub.Text(strip(Drawer).chip.nosweep.text), "hide the sweep")
    pick(Drawer, "nosweep")
    T.eq(pieceOf(k.shout).noDurationSwipe, true, "written live")
    T.eq(sentences(Drawer)[1].said, "While it's active, hide the sweep.")
    local keepPicker = rawget(_G, "ColorPickerFrame")
    local info
    _G.ColorPickerFrame = { SetupColorPickerAndShow = function(_, t) info = t end,
        GetColorRGB = function() return 0, 0, 1 end, GetColorAlpha = function() return 0.5 end,
        HookScript = function() end }
    local ok, err = pcall(function()
        pick(Drawer, "tint")
        T.isnil(pieceOf(k.shout).noDurationSwipe, "the sweep is back")
        T.eq(sentences(Drawer)[1].said, "While it's active, color the sweep in the accent color.")
        wordOf(Drawer, 1, "color"):Click()
        pick(Drawer, "pick")
        T.truthy(info and info.hasOpacity, "the picker shows its opacity bar")
        info.swatchFunc()
        T.deq(pieceOf(k.shout).activeColor, { 0, 0, 1, 0.5 }, "color and alpha saved")
        T.deq(cardReads(AB, "activeColor"), { 0, 0, 1, 0.5 }, "the card's Highlight color")
    end)
    _G.ColorPickerFrame = keepPicker
    assert(ok, err)
    -- A bar: no sweep words; flash once Buff missing shows. The icon's color stays
    -- in the layout as an unfit line, so start the bar clean.
    pieceOf(k.shout).activeColor = nil
    AB.CdmData.SetShape(set, k.shout, "bar")
    Ed.Changed()
    Ed.Select(k.rage); Ed.Select(k.shout)
    addLink(Drawer, "line"):Click()
    pick(Drawer, "missing")
    wordOf(Drawer, 1, "action"):Click()
    T.falsy(strip(Drawer).chip.flash, "not before Buff missing shows")
    pick(Drawer, "show")
    T.eq(pieceOf(k.shout).missing, true)
    addLink(Drawer, "line"):Click()
    pick(Drawer, "missing")
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "flash")
    T.eq(pieceOf(k.shout).inactiveFlash, true, "the card's Flash")
    T.eq(cardReads(AB, "inactiveFlash"), true)
    noErrors()
end)

-- ---------------------------------------------------------------------
-- More conditions, step 3: look words
-- ---------------------------------------------------------------------

-- The glow style sentence's word, and its block.
local function styleWord(Drawer)
    local b = blockWith(Drawer, "style")
    for _, t in ipairs(b and b.tokens or {}) do
        if t.piece and t.piece.word == "style" then return t, b end
    end
end

T.test("drawer style: the glow style in Daylight UI's own labels, one per spell, written live", function()
    local DUI, ns, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local w, b = styleWord(Drawer)
    T.truthy(w, "Thunder Clap glows, so its style shows")
    T.eq(b.said, "Other glows use Comet.", "the card's label for its saved style")
    T.isnil(blockWith(Drawer, "styleNote"), "no one-style note: each glow line takes its own")
    w:Click()
    T.eq(strip(Drawer).heading, "Choose a glow style:")
    local want, labels = { "ring" }, {}
    for _, st in ipairs(DUI.API.GlowStyles()) do want[#want + 1] = st.key; labels[st.key] = st.label end
    T.eq(keysText(strip(Drawer).keys), keysText(want), "Ring, then API.GlowStyles(), as the card's Style row")
    T.eq(stub.Text(strip(Drawer).chip.breathe.text), labels.breathe, "Daylight UI's own label")
    T.truthy(strip(Drawer).chip.comet.on)
    pick(Drawer, "breathe")
    T.eq(pieceOf(k.clap).glowStyle, "breathe")
    local style
    for _, r in ipairs(AB.CdmCard.ROWS.look) do
        if r.item and r.item.key == "cdm.card.glowStyle" then style = r.item.get() end
    end
    T.eq(style, "breathe", "the card's Style reads it back")
    -- No glow, no style line.
    Ed.Select(k.rage)
    T.isnil(styleWord(Drawer), "Bloodrage doesn't glow")
    noErrors()
end)

T.test("drawer style: each glow line has its own style word, written live", function()
    local DUI, ns, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    T.eq(sentences(Drawer)[1].said, "When it's ready, glow with the spell's style in gold.")
    wordOf(Drawer, 1, "style"):Click()
    T.eq(strip(Drawer).heading, "Choose a glow style:")
    local want = { "piece", "ring" }
    for _, st in ipairs(DUI.API.GlowStyles()) do want[#want + 1] = st.key end
    T.eq(keysText(strip(Drawer).keys), keysText(want), "the spell's style, then the card's styles")
    T.eq(stub.Text(strip(Drawer).chip.piece.text), "the spell's style")
    T.truthy(strip(Drawer).chip.piece.on, "none of its own yet")
    pick(Drawer, "comet")
    local profile = ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.glowStyle[profile][k.clap], { ready = "comet" }, "EZ-CDM's, by moment")
    T.eq(pieceOf(k.clap).glowStyle, "comet", "the piece's own style untouched")
    T.eq(sentences(Drawer)[1].said, "When it's ready, glow with a Comet in gold.")
    T.eq(blockWith(Drawer, "style").said, "Other glows use Comet.", "the piece's style, for the rest")
    -- Back to the spell's style.
    pick(Drawer, "piece")
    T.isnil(EZCDMDB.glowStyle[profile], "cleared")
    T.eq(sentences(Drawer)[1].said, "When it's ready, glow with the spell's style in gold.")
    -- Another action drops the style; a line that isn't a glow has no style word.
    pick(Drawer, "shine")
    wordOf(Drawer, 1, "action"):Click()
    pick(Drawer, "sound")
    T.isnil(wordOf(Drawer, 1, "style"), "no style on a sound")
    T.isnil(EZCDMDB.glowStyle[profile], "its style went with the glow")
    noErrors()
end)

T.test("drawer look: the cooldown's sweep and the almost-ready color, on cooldowns only", function()
    local _, ns, Drawer, AB, k, set, Ed = editorWorld()
    Ed.Select(k.clap)
    addLink(Drawer, "line"):Click()
    T.truthy(strip(Drawer).chip.almost, "a cooldown icon takes almost ready")
    pick(Drawer, "almost")
    wordOf(Drawer, 3, "action"):Click()
    T.eq(keysText(strip(Drawer).keys), "numbers")
    pick(Drawer, "numbers")
    T.eq(pieceOf(k.clap).look.low, true, "the card's Color when almost ready")
    T.eq(sentences(Drawer)[3].said, "When it's almost ready, color the numbers in red for the last 3 seconds.",
        "Daylight UI's own color and seconds")
    wordOf(Drawer, 3, "seconds"):Click()
    T.eq(strip(Drawer).heading, "Choose how many seconds:")
    T.eq(#strip(Drawer).keys, 10, "1 to 10, as the card's slider")
    pick(Drawer, 5)
    T.eq(pieceOf(k.clap).look.lowAt, 5)
    wordOf(Drawer, 3, "color"):Click()
    T.eq(keysText(strip(Drawer).keys), "default pick")
    T.eq(stub.Text(strip(Drawer).chip.default.text), "Daylight's color")
    -- The cooldown's sweep.
    wordOf(Drawer, 2, "action"):Click()
    T.truthy(strip(Drawer).chip.nosweep and strip(Drawer).chip.nogcd, "both sweep words on cooldown")
    pick(Drawer, "nogcd")
    T.eq(pieceOf(k.clap).noGcd, true, "the card's Hide on global cooldown")
    -- A buff alone: no almost ready, though the card offers it there.
    AB.CdmData.AddPiece(set, k.shout, "icon", 300, 0)
    Ed.Changed()
    Ed.Select(k.shout)
    addLink(Drawer, "line"):Click()
    T.falsy(strip(Drawer).chip.almost, "only a spell cooldown's numbers take the color")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The one you last clicked is on top
-- ---------------------------------------------------------------------

-- Every script on a frame, by name.
local SCRIPT_NAMES = { "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnClick", "OnShow", "OnHide", "OnEvent",
    "OnUpdate", "OnKeyDown" }
local function scriptsOf(f)
    local out = {}
    for _, name in ipairs(SCRIPT_NAMES) do out[name] = f:GetScript(name) or false end
    return out
end

-- A mouse press with the mouse over f (nil: over nothing of EZ-CDM's).
local function press(f)
    if f then stub.MouseEnter(f) end
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    if f then stub.MouseLeave(f) end
end

T.test("drawer layers: a press over EZ-CDM lifts it, a press elsewhere lowers it", function()
    local _, ns, Drawer, AB, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local card = AB.CdmCard.Frame()
    local o = Ed.Overlay()
    local d, clip, tab, block = Drawer.Frame(), Drawer.Clip(), Drawer.Tab(), ns.Start.Frame()
    local function under()
        return not Drawer.Front() and d:GetFrameStrata() == o:GetFrameStrata()
            and tab:GetFrameStrata() == o:GetFrameStrata() and block:GetFrameStrata() == o:GetFrameStrata()
    end
    local function over()
        return Drawer.Front() and d:GetFrameStrata() == Drawer.LIFT and clip:GetFrameStrata() == Drawer.LIFT
            and tab:GetFrameStrata() == Drawer.LIFT and block:GetFrameStrata() == Drawer.LIFT
    end
    T.truthy(card:IsShown(), "Daylight UI's card shows for the pick")
    T.truthy(under(), "under the card to start with")
    T.truthy(Drawer.Watch():IsEventRegistered("GLOBAL_MOUSE_DOWN"), "EZ-CDM's own frame hears the press")
    press(clip)
    T.truthy(over(), "a press on the drawer: EZ-CDM's frames go above the card")
    T.eq(card:GetFrameStrata(), o:GetFrameStrata(), "the card itself is left as it was")
    T.eq(Drawer.LIFT, "FULLSCREEN", "under Daylight UI's menus (FULLSCREEN_DIALOG)")
    press(card)
    T.truthy(under(), "a press on Daylight UI's card: back under it")
    press(block)
    T.truthy(over(), "a press on the start block")
    press(nil)
    T.truthy(under(), "a press anywhere else")
    press(tab)
    T.truthy(over(), "a press on the tab")
    -- Only a press decides: the editor's redraw and pick leave it as it is.
    Ed.Draw()
    Ed.Select(k.rage)
    T.truthy(over(), "Daylight UI's redraw leaves it on top")
    -- A pick that writes keeps it on top too.
    Ed.Select(k.clap)
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "hide")
    T.eq(pieceOf(k.clap).onCd, "hide", "the pick wrote")
    T.truthy(over(), "its own write keeps it on top")
    -- A folded drawer is no target: the press is on what lies there.
    Drawer.Tab():Click()
    stub.RunOnUpdate(Drawer.Slide().driver, 1)
    clip.__over = true
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    clip.__over = nil
    T.truthy(under(), "a folded drawer's spot doesn't lift it")
    Ed.Close()
    T.falsy(Drawer.Front(), "the editor's close resets it")
    T.falsy(Drawer.Watch():IsEventRegistered("GLOBAL_MOUSE_DOWN"), "and stops listening")
    Ed.Open()
    T.truthy(under(), "and it opens under the card")
    noErrors()
end)

T.test("drawer layers: hover changes nothing", function()
    local _, ns, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    for _, f in ipairs({ Drawer.Frame(), Drawer.Clip(), Drawer.Tab(), ns.Start.Frame() }) do
        stub.MouseEnter(f)
        T.falsy(Drawer.Front(), "a hover doesn't lift it")
        stub.MouseLeave(f)
    end
    press(Drawer.Clip())
    for _, f in ipairs({ Ed.Overlay(), Ed.Tray() }) do
        stub.MouseEnter(f)
        stub.MouseLeave(f)
    end
    T.truthy(Drawer.Front(), "a hover on Daylight UI's frames doesn't lower it")
    noErrors()
end)

T.test("drawer layers: Daylight UI's frames' scripts are unchanged", function()
    local _, ns, _, AB, k = layoutWorld()
    local Ed = AB.CdmEditor
    -- Daylight UI's own editor and card, built with no EZ-CDM hook on them yet.
    local keepDrawer, keepStart = ns.Drawer.Attach, ns.Start.Attach
    ns.Drawer.Attach, ns.Start.Attach = function() end, function() end
    Ed.Open()
    Ed.Select(k.clap)
    local frames = { overlay = Ed.Overlay(), tray = Ed.Tray(), card = AB.CdmCard.Frame() }
    local before = {}
    for name, f in pairs(frames) do before[name] = scriptsOf(f) end
    Ed.Close()
    ns.Drawer.Attach, ns.Start.Attach = keepDrawer, keepStart
    -- EZ-CDM on, pressed, hovered and clicked.
    Ed.Open()
    Ed.Select(k.clap)
    press(ns.Drawer.Clip())
    press(nil)
    press(ns.Start.Frame())
    wordOf(ns.Drawer, 1, "moment"):Click()
    for name, f in pairs(frames) do
        local now = scriptsOf(f)
        for script, fn in pairs(before[name]) do
            T.eq(now[script], fn, name .. "'s " .. script .. " is untouched")
        end
        T.falsy(f:IsEventRegistered("GLOBAL_MOUSE_DOWN"), name .. " doesn't hear the press for EZ-CDM")
    end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Polish seen in the screenshots
-- ---------------------------------------------------------------------

T.test("drawer polish: the add links stand apart by the parts' gap", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local line, group = addLink(Drawer, "line"), addLink(Drawer, "group")
    local _, _, _, x1 = line:GetPoint(1)
    local _, _, _, x2 = group:GetPoint(1)
    T.eq(x2, x1 + line:GetWidth() + DUI.Win.Parts.GAP, "+ add a line, a gap, + a rule for its whole group")
    noErrors()
end)

T.test("drawer polish: plain words are one run per line, so a gap is one space", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 1, "moment"):Click()
    local heading
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() and b.tokens and not b.choices and not b.shared then heading = b end
    end
    T.eq(heading.said, "Choose a moment:")
    local shown = {}
    for _, t in ipairs(heading.tokens) do shown[#shown + 1] = stub.Text(t.text) end
    T.deq(shown, { "Choose a moment:" }, "one font string, Daylight UI's own spacing")
    noErrors()
end)

T.test("drawer sound strip: a chip click previews the sound and still picks it", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 1, "action"):Click()
    pick(Drawer, "sound")
    local played = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(key) played[#played + 1] = key; return keep(key) end
    wordOf(Drawer, 1, "sound"):Click()
    local kinds, keys = {}, strip(Drawer).keys
    for _, key in ipairs(keys) do
        local kind = tostring(key):match("^(%a+):") or key
        if not kinds[kind] then kinds[kind] = key end
    end
    T.truthy(kinds.kit or kinds.file, "the list holds kit or file sounds")
    T.truthy(kinds.dui, "the list holds Daylight UI's own files")
    for _, kind in ipairs({ "kit", "file", "dui", "lsm" }) do
        local key = kinds[kind]
        if key then
            played = {}
            if not Drawer.Slot() then wordOf(Drawer, 1, "sound"):Click() end
            pick(Drawer, key)
            stub.RunTimers()
            T.deq(played, { key }, kind .. " chip plays its own key once")
            T.eq(pieceOf(k.clap).readySound, key, kind .. " chip still picks")
        end
    end
    -- None plays nothing but still picks.
    played = {}
    if not Drawer.Slot() then wordOf(Drawer, 1, "sound"):Click() end
    pick(Drawer, "none")
    stub.RunTimers()
    T.deq(played, {}, "None is silent")
    T.truthy(pieceOf(k.clap).readySound == nil or pieceOf(k.clap).readySound == "none", "None still picks")
    DUI.Sound.Alert = keep
    noErrors()
end)

T.test("drawer polish: the chip strip wraps inside the drawer's width", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    -- A stale scroll width, wider than the drawer, must not widen the rows.
    Drawer.Parts().stripStack.scroll:SetWidth(2000)
    -- The sound list is the longest strip.
    wordOf(Drawer, 1, "action"):Click()
    pick(Drawer, "sound")
    wordOf(Drawer, 1, "sound"):Click()
    local inner = Drawer.Frame():GetWidth() - 2 * DUI.Win.EDGE
    local lines, right = {}, 0
    for _, b in ipairs(Drawer.Parts().stripStack.pieces) do
        if b:IsShown() and b.choices then
            for _, t in ipairs(b.tokens) do
                local _, _, _, x, y = t:GetPoint(1)
                lines[y] = true
                right = math.max(right, x + t:GetWidth())
            end
        end
    end
    local n = 0
    for _ in pairs(lines) do n = n + 1 end
    T.truthy(n > 1, "the chips wrap: " .. n .. " lines")
    T.truthy(right <= inner, "the last chip ends inside the drawer: " .. right .. " <= " .. inner)
    noErrors()
end)

T.test("drawer: EZ-CDM's up glow on a holder piece reads as the line, with its ring note", function()
    local DUI, ns, Drawer, AB, k, set = layoutWorld()
    local D = AB.CdmData
    local RED = { 1, 0, 0 }
    local W = ns.Grammar.WORDING
    D.AddPiece(set, k.shout, "icon", 300, 0)
    CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    D.SetSpellValue(set, k.shout, "upGlow", true)
    D.SetSpellValue(set, k.shout, "upGlowColor", RED)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.eq(AB.CdmRows.DrawnBy(k.shout), "aura icon", "Daylight UI's aura icon holder draws Battle Shout")
    T.truthy(AB.CdmEditor.Open())
    stub.RunTimers()
    AB.CdmEditor.Select(k.shout)
    -- Daylight UI's own glow, set on its card, reads as the line with no note.
    T.eq(said(Drawer), "While it's active, glow in red.")
    T.isnil(blockWith(Drawer, "ezGlow"), "still Daylight UI's glow until the next write")
    T.truthy(ns.Draft.Write(k.shout, ns.Draft.Rules(k.shout)))
    ns.Bridge.EditorChanged(); stub.RunTimers()
    T.deq(ns.Effects.Get(k.shout), RED, "now EZ-CDM's rule")
    T.eq(said(Drawer), "While it's active, glow in red.", "the same line")
    local note = blockWith(Drawer, "ezGlow")
    T.truthy(note, "the ring note")
    T.eq(note.said, W.ezGlow)
    T.eq(note.ezGlow, 1, "under its line")
    T.eq(note.tokens[1].piece.size, "small")
    local label = DUI.API.Colors().LABEL
    T.deq(rgb(note.tokens[1].text), { label[1], label[2], label[3] }, "in LABEL")
    T.isnil(blockWith(Drawer, "ezReload"), "lit at once on the buttons made before the rule")
    noErrors()
end)

T.test("drawer: a ring the client won't take yet says it waits for a /reload", function()
    local _, ns, Drawer, AB, k, set = layoutWorld()
    local D = AB.CdmData
    local W = ns.Grammar.WORDING
    D.AddPiece(set, k.shout, "icon", 300, 0)
    CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    for _, btn in ipairs(AB.CdmAuras.Frame(k.shout).buttons) do
        btn.AddAuraShownAnimation = function() error("refused") end
    end
    T.truthy(AB.CdmEditor.Open())
    stub.RunTimers()
    AB.CdmEditor.Select(k.shout)
    T.truthy(ns.Draft.Write(k.shout, { lines = { { moment = "up", action = "glow", value = { 1, 0, 0 } } } }))
    ns.Bridge.EditorChanged(); stub.RunTimers()
    local wait = blockWith(Drawer, "ezReload")
    T.truthy(wait, "the note")
    T.eq(wait.said, W.ezGlowReload)
    T.eq(W.ezGlowReload, "It lights after a /reload. EZ asks for one as the editor closes.")
end)

-- Battle Shout drawn by Daylight UI's aura icon holder, with "While it's active,
-- glow in red" made EZ-CDM's combat ring. style: a glow style saved first.
local function ringWorld(style)
    local DUI, ns, Drawer, AB, k, set = layoutWorld()
    local D = AB.CdmData
    D.AddPiece(set, k.shout, "icon", 300, 0)
    CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
    D.SetSpellValue(set, k.shout, "upGlow", true)
    D.SetSpellValue(set, k.shout, "upGlowColor", { 1, 0, 0 })
    if style then D.SetSpellValue(set, k.shout, "glowStyle", style) end
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.eq(AB.CdmRows.DrawnBy(k.shout), "aura icon")
    T.truthy(AB.CdmEditor.Open())
    stub.RunTimers()
    AB.CdmEditor.Select(k.shout)
    T.truthy(ns.Draft.Write(k.shout, ns.Draft.Rules(k.shout)))
    ns.Bridge.EditorChanged(); stub.RunTimers()
    T.truthy(ns.Effects.Get(k.shout), "EZ-CDM's combat ring")
    return DUI, ns, Drawer, AB, k
end

T.test("drawer style: an EZ-ringed piece offers no style, and no second ring note", function()
    local DUI, ns, Drawer = ringWorld()
    local W = ns.Grammar.WORDING
    T.isnil(styleWord(Drawer), "no style word to pick")
    T.isnil(wordOf(Drawer, 1, "style"), "the ring line has no style word of its own")
    T.isnil(blockWith(Drawer, "style"), "no Other glows use ... line")
    T.isnil(blockWith(Drawer, "styleNote"), "no one-style note")
    T.isnil(blockWith(Drawer, "ezRingStyle"), "the line's own note already says it is a ring")
    T.isnil(blockWith(Drawer, "ezRingOther"), "no saved style to name")
    noErrors()
end)

T.test("drawer style: a saved style on an EZ-ringed piece stays, and the note names it", function()
    local DUI, ns, Drawer, AB, k = ringWorld("comet")
    local labels = {}
    for _, st in ipairs(DUI.API.GlowStyles()) do labels[st.key] = st.label end
    T.isnil(styleWord(Drawer), "no style chips")
    local other = blockWith(Drawer, "ezRingOther")
    T.truthy(other, "the saved style's note")
    T.eq(other.said, ("Its other glows still use %s."):format(labels.comet))
    T.eq(other.tokens[1].piece.size, "small")
    local function saved() return AB.CdmData.Get(1).pieces[k.shout].glowStyle end
    T.eq(saved(), "comet", "left as it was")
    -- Another write from the drawer's rules keeps it.
    T.truthy(ns.Draft.Write(k.shout, ns.Draft.Rules(k.shout)))
    T.eq(saved(), "comet", "still Daylight UI's for the piece's other glows")
    -- A game-drawn piece with a glow still offers the style.
    AB.CdmEditor.Select(k.clap)
    T.truthy(styleWord(Drawer), "Thunder Clap's style strip")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The fall-off lead and sound (fall-off-lead.md step 3)
-- ---------------------------------------------------------------------

-- fn runs with the game saying which spells are cast on an enemy (C_Spell.IsSpellHarmful).
local function withHarmful(set, fn)
    local keep = C_Spell.IsSpellHarmful
    C_Spell.IsSpellHarmful = function(id) return set[id] == true end
    local ok, err = pcall(fn)
    C_Spell.IsSpellHarmful = keep
    if not ok then error(err, 0) end
end

-- The fall-off notes under the picked piece's lines, by code, in order.
local function fallOffNotes(Drawer)
    local out = {}
    for _, b in ipairs(blocksWith(Drawer, "fallOff")) do out[#out + 1] = b.fallOff end
    return table.concat(out, " ")
end

-- Adds a line on Rend: "When it's about to fall off", then action.
local function addRecast(Drawer, action)
    addLink(Drawer, "line"):Click()
    pick(Drawer, "recast")
    local n = #sentences(Drawer)
    if not strip(Drawer).chip[action] then wordOf(Drawer, n, "action"):Click() end
    pick(Drawer, action)
    return n
end

T.test("drawer fall-off: the lead and the sound, picked in the drawer, round-trip", function()
    local _, ns, Drawer, AB, k, _, Ed = editorWorld()
    local W = ns.Grammar.WORDING
    withHarmful({ [REND] = true }, function()
        Ed.Select(k.rend)
        local glow = addRecast(Drawer, "glow")
        T.eq(sentences(Drawer)[glow].said, "When it's about to fall off (Daylight's timing), glow with the spell's style in the accent color.",
            "no lead yet: Daylight UI's own timing")
        T.eq(pieceOf(k.rend).clipGlow, true, "Daylight UI's recast glow")
        wordOf(Drawer, glow, "seconds"):Click()
        T.eq(strip(Drawer).heading, "Choose how many seconds:")
        T.eq(keysText(strip(Drawer).keys), "daylight 2 3 4 5 8 10")
        T.eq(stub.Text(strip(Drawer).chip.daylight.text), W.daylightTiming)
        T.eq(stub.Text(strip(Drawer).chip[5].text), "5 seconds")
        T.truthy(strip(Drawer).chip.daylight.on, "the current pick lit")
        pick(Drawer, 5)
        T.eq(sentences(Drawer)[glow].said, "When it's about to fall off (5 seconds before), glow with the spell's style in the accent color.")
        local profile = ns.Bridge.ProfileOf(1)
        T.deq(EZCDMDB.fallOff[profile][k.rend], { lead = 5 }, "EZ-CDM's rule")
        -- A sound line on the same moment takes the piece's lead.
        local sound = addRecast(Drawer, "sound")
        T.eq(sentences(Drawer)[sound].said, "When it's about to fall off (5 seconds before), play Proc.")
        local rule = EZCDMDB.fallOff[profile][k.rend]
        T.eq(rule.lead, 5)
        T.truthy(type(rule.sound) == "string" and rule.sound ~= "none", "the first sound")
        local rules = ns.Draft.Rules(k.rend)
        T.eq(select(2, ns.Draft.Write(k.rend, rules)).changes, 0, "read back and written again: no change")
        -- The lead is one per piece: a pick on either line sets both.
        wordOf(Drawer, sound, "seconds"):Click()
        pick(Drawer, 8)
        T.eq(sentences(Drawer)[glow].said, "When it's about to fall off (8 seconds before), glow with the spell's style in the accent color.")
        T.eq(EZCDMDB.fallOff[profile][k.rend].lead, 8)
        -- Back to Daylight UI's timing: the sound stays, the lead goes.
        wordOf(Drawer, glow, "seconds"):Click()
        pick(Drawer, "daylight")
        T.isnil(EZCDMDB.fallOff[profile][k.rend].lead)
        T.eq(EZCDMDB.fallOff[profile][k.rend].sound, rule.sound)
        T.eq(sentences(Drawer)[sound].said, "When it's about to fall off (Daylight's timing), play Proc.")
        -- Moved to another moment, a line drops its lead.
        pick(Drawer, 3)
        wordOf(Drawer, glow, "moment"):Click()
        pick(Drawer, "up")
        T.isnil(ns.Draft.Rules(k.rend).lines[glow] and ns.Draft.Rules(k.rend).lines[glow].at)
    end)
    noErrors()
end)

T.test("drawer fall-off: each limit note shows only on the right piece kinds", function()
    local _, ns, Drawer, AB, k, set, Ed = editorWorld()
    local W = ns.Grammar.WORDING
    withHarmful({ [REND] = true }, function()
        -- Rend: the game's own icon draws it, a debuff you cast on the target.
        Ed.Select(k.rend)
        local glow = addRecast(Drawer, "glow")
        T.eq(fallOffNotes(Drawer), "own target", "Daylight's timing: Daylight UI's own handling")
        local notes = blocksWith(Drawer, "fallOff")
        T.eq(notes[1].said, W.fallOff.own)
        T.eq(notes[1].said, "Counts from your own cast.")
        T.eq(notes[2].said, "One timer per spell, not per target.")
        T.eq(notes[1].tokens[1].piece.size, "small")
        T.eq(notes[1].tokens[1].piece.color, "LABEL")
        -- A lead is EZ-CDM's rule. Daylight UI's buff moments cover Rend (its state
        -- reads down), so the clock runs from the landing and stops on a drop.
        T.eq(ns.Bridge.BuffState(k.rend), false, "Rend's state: down")
        wordOf(Drawer, glow, "seconds"):Click()
        pick(Drawer, 5)
        T.eq(fallOffNotes(Drawer), "lands target", "a rule of EZ-CDM's, on the buff moments")
        T.eq(blocksWith(Drawer, "fallOff")[1].said, W.fallOff.lands)
        T.eq(blocksWith(Drawer, "fallOff")[1].said, "Counts from when it lands, and stops if it falls off early.")
        -- A second line on the same moment adds no second set of notes.
        addRecast(Drawer, "sound")
        T.eq(fallOffNotes(Drawer), "lands target", "once per piece")
        -- Back to Daylight UI's timing, the sound alone is still a rule.
        wordOf(Drawer, glow, "seconds"):Click()
        pick(Drawer, "daylight")
        T.eq(fallOffNotes(Drawer), "lands target", "a sound")
        -- Shield Wall: Daylight UI's holder draws its buff over the cooldown. No
        -- option needs its up or down, so no buff moment covers it.
        Ed.Select(k.wall)
        addRecast(Drawer, "glow")
        T.eq(AB.CdmRows.DrawnBy(k.wall), "aura and cooldown icon")
        T.eq(fallOffNotes(Drawer), "own early")
        wordOf(Drawer, #sentences(Drawer), "seconds"):Click()
        pick(Drawer, 5)
        T.isnil(ns.Bridge.BuffState(k.wall), "Shield Wall's state: can't tell")
        T.eq(fallOffNotes(Drawer), "own early", "a rule, not covered: the cast clock")
        -- Battle Shout drawn by Daylight UI's aura icon holder.
        AB.CdmData.AddPiece(set, k.shout, "icon", 300, 0)
        CW.Setting("BuffIconCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        CW.Setting("BuffBarCooldownViewer", "VisibleSetting", Enum.CooldownViewerVisibleSetting.Hidden)
        Ed.Changed(); stub.RunTimers()
        T.eq(AB.CdmRows.DrawnBy(k.shout), "aura icon")
        Ed.Select(k.shout)
        addRecast(Drawer, "glow")
        T.eq(fallOffNotes(Drawer), "own early")
        T.eq(blocksWith(Drawer, "fallOff")[2].said, "In a fight it can't tell if it falls off early.")
        -- No fall-off line, no notes.
        Ed.Select(k.clap)
        T.eq(fallOffNotes(Drawer), "")
    end)
    -- Rend again, with the game calling it not harmful: no target note. Its sound
    -- line keeps the rule's note.
    withHarmful({}, function()
        Ed.Select(k.rend)
        T.eq(AB.CdmRows.DrawnBy(k.rend), "game")
        T.eq(fallOffNotes(Drawer), "lands", "no target note")
    end)
    noErrors()
end)

T.test("drawer fall-off: not offered on a spell you never cast, as a proc", function()
    local _, ns, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.wall)
    addLink(Drawer, "line"):Click()
    T.truthy(strip(Drawer).chip.recast, "Shield Wall, cast by you, takes it")
    local keep = C_Spell.IsSpellPassive
    C_Spell.IsSpellPassive = function() return true end
    local ok, err = pcall(function()
        local kind = ns.Draft.Kind(k.wall)
        T.falsy(kind.cast, "every id passive: never cast")
        -- Drawn by Daylight UI's holder, with a length from the game's data: a proc
        -- EZ-CDM draws, and nothing can time its end in a fight.
        T.truthy(kind.proc, "a proc EZ-CDM draws")
        T.truthy(ns.Bridge.FactLasts(k.wall), "its length is known")
        T.falsy(ns.Grammar.Fits(kind, "recast", "glow"))
        T.falsy(ns.Grammar.Fits(kind, "recast", "sound"))
        Ed.Select(k.rend)
        Ed.Select(k.wall)
        addLink(Drawer, "line"):Click()
        T.isnil(strip(Drawer).chip.recast, "no fall-off moment to pick")
    end)
    C_Spell.IsSpellPassive = keep
    if not ok then error(err, 0) end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- A proc EZ-CDM draws: no fall-off moment, and a note says why
-- (docs/tasks/done/scrap-proc-lead.md)
-- ---------------------------------------------------------------------

T.test("drawer fall-off: a proc EZ-CDM draws says why it has no fall-off moment", function()
    local DUI, ns, Drawer, _, k, _, Ed = editorWorld()
    local W = ns.Grammar.WORDING
    -- Before: Shield Wall cast by you takes no such note.
    Ed.Select(k.wall)
    T.isnil(blockWith(Drawer, "fallOff"), "a spell you cast: no note")
    -- Shield Wall as a proc: every id passive, drawn by Daylight UI's holder.
    local keep = C_Spell.IsSpellPassive
    C_Spell.IsSpellPassive = function() return true end
    local ok, err = pcall(function()
        Ed.Select(k.rend)
        Ed.Select(k.wall)
        T.truthy(ns.Draft.Kind(k.wall).proc)
        local notes = blocksWith(Drawer, "fallOff")
        T.eq(#notes, 1, "one note, with no line on the piece")
        T.eq(notes[1].fallOff, "hidden")
        T.eq(notes[1].said, "The game hides this buff's timer in a fight, so EZ can't time its end.")
        T.eq(notes[1].said, W.fallOff.hidden)
        local label = DUI.API.Colors().LABEL
        T.deq(rgb(notes[1].tokens[1].text), { label[1], label[2], label[3] }, "small, in LABEL")
        -- The up ring is still offered, with its own note once set.
        addLink(Drawer, "line"):Click()
        T.truthy(strip(Drawer).chip.up, "While it's active is still there")
        T.isnil(strip(Drawer).chip.recast)
        T.isnil(blockWith(Drawer, "ezReload"), "no fall-off ring waiting for a /reload")
    end)
    C_Spell.IsSpellPassive = keep
    if not ok then error(err, 0) end
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Recipes (docs/specs/recipes.md)
-- ---------------------------------------------------------------------

T.test("drawer recipes: + a recipe opens chips of the fitting recipes; a pick merges its lines", function()
    local DUI, ns, Drawer, _, k, _, Ed = editorWorld()
    local G = ns.Grammar
    Ed.Select(k.clap)
    T.eq(said(Drawer), "When it's ready, glow with the spell's style in gold.\n"
        .. "While it's cooling down, make it see-through.")
    local link = addLink(Drawer, "recipe")
    T.truthy(link, "the recipe link")
    T.eq(stub.Text(link.text), "+ a recipe")
    -- Beside the other add links, after the group one, in the add link's look.
    local order = {}
    for _, t in ipairs(blockWith(Drawer, "adds").tokens) do order[#order + 1] = t.piece.word .. ":" .. t.piece.kind end
    T.eq(table.concat(order, " "), "line:add group:add recipe:add form:add")
    link:Click()
    local s = strip(Drawer)
    T.eq(s.heading, "Choose a recipe:")
    T.eq(keysText(s.keys), table.concat(G.Recipes(G.Kind(k.clap)), " "), "exactly the recipes that fit")
    T.eq(keysText(s.keys), "readyAlert outOfWay dimCooling canCast manaCheck almostThere nowUsable missingReminder fightOnly")
    T.eq(stub.Text(s.chip.readyAlert.text), "Ready alert", "the chip names the recipe")
    T.eq(Drawer.Slot().kind, "recipe")
    -- The same chips as every other strip.
    T.eq(s.chip.readyAlert.piece.kind, "chip")
    pick(Drawer, "readyAlert")
    T.eq(Drawer.Slot().kind, "recipe", "a pick leaves the strip open")
    T.eq(pieceOf(k.clap).readyGlow, true)
    T.eq(pieceOf(k.clap).readySound, "file:568016", "Daylight UI's Proc sound")
    -- The glow is replaced by one in the accent, which Daylight UI 2.2.6 writes back.
    T.isnil(pieceOf(k.clap).readyGlowColor, "the gold is gone")
    T.eq(said(Drawer), "When it's ready, glow with the spell's style in the accent color.\n"
        .. "When it's ready, play Proc.\nWhile it's cooling down, make it see-through.",
        "the glow replaced, the sound added, read back in the grammar's order")
    T.falsy(blockWith(Drawer, "notice"), "no accent note")
    -- Every word stays clickable.
    T.truthy(wordOf(Drawer, 2, "sound"), "the sound is a word to change")
    -- The same family: hide replaces the fade.
    pick(Drawer, "outOfWay")
    T.eq(pieceOf(k.clap).onCd, "hide")
    T.eq(#sentences(Drawer), 3, "nothing doubled")
    T.eq(sentences(Drawer)[3].said, "While it's cooling down, hide it.")
    -- The group recipe writes the group word.
    pick(Drawer, "fightOnly")
    T.eq(chainOf(k.rend).combat, true, "on the group")
    T.eq(blocksWith(Drawer, "group")[1].said, "Only show it in combat.")
    -- A bar has no numbers.
    Ed.Select(k.rage)
    addLink(Drawer, "recipe"):Click()
    T.falsy(strip(Drawer).chip.almostThere, "no Almost there on a bar")
    T.eq(keysText(strip(Drawer).keys), table.concat(G.Recipes(G.Kind(k.rage)), " "))
    -- A second click on the link closes the strip.
    addLink(Drawer, "recipe"):Click()
    T.isnil(Drawer.Slot())
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The "Copy report" link at the drawer's bottom
-- ---------------------------------------------------------------------

-- The report link's widget, or nil.
local function copyLink(Drawer)
    local b = blockWith(Drawer, "copy")
    return b and b.tokens and b.tokens[1]
end

T.test("drawer report link: shown at the bottom while Daylight UI has its copy box", function()
    local DUI, ns, Drawer, _, k, _, Ed = editorWorld()
    T.truthy(DUI.Profiles.ShowText, "the pinned Daylight UI has the box")
    local last = body(Drawer)[#body(Drawer)]
    T.truthy(last.copy, "the empty drawer ends on the link")
    local link = copyLink(Drawer)
    T.truthy(link and link.SetLabel, "Daylight UI's W.Link")
    T.eq(ns.Grammar.WORDING.copyReport, "Copy report")
    T.eq(link.piece.text, ns.Grammar.WORDING.copyReport)
    Ed.Select(k.clap)
    last = body(Drawer)[#body(Drawer)]
    T.truthy(last.copy, "a spell's drawer ends on it too, under the notes")
    T.eq(#blocksWith(Drawer, "copy"), 1, "one link")
    noErrors()
end)

T.test("drawer report link: absent when ShowText doesn't resolve, back when it does", function()
    local DUI, ns, Drawer, _, k, _, Ed = editorWorld()
    local keep = DUI.Profiles.ShowText
    DUI.Profiles.ShowText = nil
    T.falsy(ns.Bridge.ShowText("t", "h", "x"), "the Bridge answers nil")
    Ed.Select(k.clap)
    T.isnil(blockWith(Drawer, "copy"), "no link with a spell")
    Ed.Select(nil)
    T.isnil(blockWith(Drawer, "copy"), "no link with nothing picked")
    T.truthy(ns.Bridge.Ready(), "EZ-CDM stays on")
    DUI.Profiles.ShowText = keep
    Drawer.Refresh()
    T.truthy(blockWith(Drawer, "copy"), "back once it resolves")
    local listed = false
    for _, p in ipairs(ns.Bridge.OPTIONAL) do listed = listed or p == "DaylightUI.Profiles.ShowText" end
    T.truthy(listed, "listed in Bridge.OPTIONAL")
    noErrors()
end)

T.test("drawer report link: a click hands the box its title, hint and an EZCDM1 report", function()
    local DUI, ns, Drawer, _, k, _, Ed = editorWorld()
    local got
    DUI.Profiles.ShowText = function(title, hint, text) got = { title, hint, text } end
    Ed.Select(k.clap)
    copyLink(Drawer):Click()
    T.truthy(got, "ShowText ran")
    T.eq(got[1], "EZ-CDM report")
    T.eq(got[2], ns.Grammar.WORDING.copyReportHint)
    T.truthy(got[2]:find("GitHub issue", 1, true) and got[2]:find("Discord", 1, true), "the hint says where to paste")
    T.eq(type(got[3]), "string")
    T.eq(got[3]:sub(1, 7), "EZCDM1:", "the report's prefix")
    local t, why = ns.Report.Parse(got[3])
    T.truthy(t, "Report.Parse reads it: " .. tostring(why))
    noErrors()
end)

T.test("drawer report link: in combat a click opens nothing", function()
    local DUI, _, Drawer, _, _, _, Ed = editorWorld()
    local calls = 0
    DUI.Profiles.ShowText = function() calls = calls + 1 end
    Ed.Select(nil)
    local link = copyLink(Drawer)
    stub.combat = true
    link:Click()
    stub.combat = false
    T.eq(calls, 0, "refused in a fight")
    link:Click()
    T.eq(calls, 1, "and works after it")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The choice strip stays open (docs/tasks/strip-stays.md)
-- ---------------------------------------------------------------------

-- The sentence whose text starts with s, or nil.
local function sentenceStarting(Drawer, s)
    for i, b in ipairs(sentences(Drawer)) do
        if b.said:sub(1, #s) == s then return i, b end
    end
end

-- A mouse press with the mouse over a control of the drawer: the control, the
-- scroll frame it sits in and the drawer.
local function pressOn(Drawer, control, stackName)
    stub.MouseEnter(Drawer.Clip())
    local scroll = stackName and Drawer.Parts()[stackName].scroll
    if scroll then stub.MouseEnter(scroll) end
    stub.MouseEnter(control)
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    stub.MouseLeave(control)
    if scroll then stub.MouseLeave(scroll) end
    stub.MouseLeave(Drawer.Clip())
end

T.test("drawer strip stays: a pick keeps it open on the same word with the new pick lit", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    T.isnil(Drawer.Slot(), "closed to start with")
    wordOf(Drawer, 2, "action"):Click()
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.action)
    T.truthy(strip(Drawer).chip.fade.on, "see-through is lit")
    local stripFrame, hides = Drawer.Parts().strip, 0
    local keep = stripFrame.SetShown
    stripFrame.SetShown = function(self, on) if not on then hides = hides + 1 end return keep(self, on) end
    pick(Drawer, "hide")
    T.eq(pieceOf(k.clap).onCd, "hide", "the pick wrote")
    T.truthy(Drawer.Slot(), "the strip stays")
    T.eq(Drawer.Slot().kind, "action", "on the same word")
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.action, "same heading")
    T.truthy(strip(Drawer).chip.hide.on, "the new pick is lit")
    T.falsy(strip(Drawer).chip.fade.on, "the old one is not")
    T.eq(sentences(Drawer)[2].said, "While it's cooling down, hide it.", "the sentence above redrew")
    -- Several picks in a row, no click on the word between them.
    pick(Drawer, "fade")
    T.eq(pieceOf(k.clap).onCd, "fade")
    T.truthy(strip(Drawer).chip.fade.on and not strip(Drawer).chip.hide.on, "back to see-through, lit")
    pick(Drawer, "hide")
    T.eq(pieceOf(k.clap).onCd, "hide", "a third pick still lands on line 2")
    T.truthy(Drawer.Slot() and strip(Drawer).chip.hide.on)
    T.eq(hides, 0, "the strip's frame never hid between picks")
    stripFrame.SetShown = keep
    noErrors()
end)

T.test("drawer strip stays: it follows a line the grammar moves, and a blank filling in", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    -- "When it's ready" becomes "When it becomes castable", which reads after the cooldown line.
    wordOf(Drawer, 1, "moment"):Click()
    pick(Drawer, "usable")
    local at = sentenceStarting(Drawer, "When it becomes castable")
    T.eq(at, 2, "the line moved down")
    T.eq(Drawer.Slot().id, "line:2:moment", "the strip went with it")
    T.eq(Drawer.Slot().kind, "moment")
    T.truthy(strip(Drawer).chip.usable.on and not strip(Drawer).chip.ready.on, "lit on its new moment")
    -- A pick from here changes that line, not the one now at index 1.
    pick(Drawer, "ready")
    T.eq(sentenceStarting(Drawer, "When it's ready"), 1, "back up")
    T.eq(Drawer.Slot().id, "line:1:moment")
    T.truthy(strip(Drawer).chip.ready.on)
    T.eq(pieceOf(k.clap).readyGlow, true)
    -- A new line: the first blank stays open, then each pick moves on to the next click.
    addLink(Drawer, "line"):Click()
    T.eq(Drawer.Slot().id, "line:3:moment")
    pick(Drawer, "unusable")
    T.eq(Drawer.Slot().id, "line:3:moment", "half a line: the strip stays on its moment")
    T.truthy(strip(Drawer).chip.unusable.on, "the pick lit")
    wordOf(Drawer, 3, "action"):Click()
    pick(Drawer, "hide")
    T.eq(pieceOf(k.clap).onUnusable, "hide", "written once both were filled")
    local now = sentenceStarting(Drawer, "When it's not usable")
    T.eq(Drawer.Slot().id, "line:" .. now .. ":action", "the strip stays on that line's action, wherever it went")
    T.truthy(strip(Drawer).chip.hide.on)
    noErrors()
end)

T.test("drawer strip stays: a group word's strip follows it when it changes", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    addLink(Drawer, "group"):Click()
    pick(Drawer, "combat")
    T.eq(chainOf(k.rend).combat, true)
    T.eq(Drawer.Slot().id, "group:+", "the + strip stays for the next one")
    T.falsy(strip(Drawer).chip.combat, "the one just added is gone from it")
    pick(Drawer, "target")
    T.eq(#blocksWith(Drawer, "group"), 2, "two group words")
    local function groupWord(text)
        for _, b in ipairs(blocksWith(Drawer, "group")) do
            if b.said == text then return b.tokens[1] end
        end
    end
    groupWord("Only show it in combat."):Click()
    T.eq(Drawer.Slot().id, "group:combat")
    T.truthy(strip(Drawer).chip.combat.on, "its own word lit")
    pick(Drawer, "mounted")
    T.eq(chainOf(k.rend).mounted, true, "the word changed")
    T.falsy(chainOf(k.rend).combat == true, "and the old one went")
    T.eq(Drawer.Slot().id, "group:mounted", "the strip went to the new word")
    T.truthy(strip(Drawer).chip.mounted.on and not strip(Drawer).chip.combat.on)
    -- Daylight UI's own order can't move it: another pick from the same strip.
    pick(Drawer, "combat")
    T.eq(Drawer.Slot().id, "group:combat")
    T.eq(chainOf(k.rend).combat, true)
    noErrors()
end)

T.test("drawer strip stays: the spell's other words and the + links keep theirs open too", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    fadeWord(Drawer):Click()
    pick(Drawer, 25)
    T.eq(Drawer.Slot().kind, "fade")
    T.truthy(strip(Drawer).chip[25].on)
    pick(Drawer, 50)
    T.eq(pieceOf(k.clap).cdAlpha, 0.5)
    T.truthy(strip(Drawer).chip[50].on and not strip(Drawer).chip[25].on, "the amount follows")
    addLink(Drawer, "recipe"):Click()
    pick(Drawer, "outOfWay")
    T.eq(pieceOf(k.clap).onCd, "hide")
    T.eq(Drawer.Slot().kind, "recipe", "a recipe's strip stays for the next recipe")
    pick(Drawer, "dimCooling")
    T.eq(pieceOf(k.clap).onCd, "fade", "and a second recipe lands")
    noErrors()
end)

T.test("drawer strip stays: scroll positions are kept while the spell and word are the same", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local B, S = Drawer.Parts().bodyStack, Drawer.Parts().stripStack
    local at = {}
    B.Scrolled = function() return 37 end
    S.Scrolled = function() return 21 end
    B.ScrollTo = function(_, v) at.body = v end
    S.ScrollTo = function(_, v) at.strip = v end
    wordOf(Drawer, 2, "action"):Click()
    T.eq(at.body, 37, "opening a strip leaves the body where it was")
    T.eq(at.strip, 0, "a strip just opened starts at its top")
    pick(Drawer, "hide")
    T.eq(at.body, 37, "a pick leaves the body where it was")
    T.eq(at.strip, 21, "and the strip too")
    wordOf(Drawer, 1, "moment"):Click()
    T.eq(at.strip, 0, "another word's strip starts at the top")
    T.eq(at.body, 37)
    Ed.Select(k.rage)
    T.eq(at.body, 0, "another spell starts at the top")
    T.eq(at.strip, 0)
    noErrors()
end)

T.test("drawer strip closes: the same word again, another word switches it, a spell change, a fold", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 1, "moment"):Click()
    pick(Drawer, "usable")
    T.truthy(Drawer.Slot(), "open after a pick")
    wordOf(Drawer, 2, "moment"):Click()
    T.isnil(Drawer.Slot(), "a click on the same word closes it")
    noStrip(Drawer, "the same word again")
    wordOf(Drawer, 1, "moment"):Click()
    T.eq(Drawer.Slot().kind, "moment")
    wordOf(Drawer, 1, "action"):Click()
    T.eq(Drawer.Slot().kind, "action", "a click on another word moves the strip")
    T.eq(strip(Drawer).heading, Drawer.HEADINGS.action)
    pick(Drawer, "hide")
    T.truthy(Drawer.Slot())
    Ed.Select(k.rend)
    noStrip(Drawer, "another spell")
    addLink(Drawer, "line"):Click()
    pick(Drawer, "cooldown")
    T.truthy(Drawer.Slot())
    Drawer.Tab():Click()
    T.isnil(Drawer.Slot(), "a fold")
    Drawer.Tab():Click()
    noStrip(Drawer, "unfolded again")
    noErrors()
end)

T.test("drawer strip closes: the editor closing", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "hide")
    T.truthy(Drawer.Slot())
    Ed.Close()
    T.isnil(Drawer.Slot(), "closed with the editor")
    Ed.Open()
    Ed.Select(k.clap)
    noStrip(Drawer, "back open")
    noErrors()
end)

T.test("drawer strip closes: a press in empty drawer space or outside it, not on a control", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 2, "action"):Click()
    pick(Drawer, "hide")
    T.truthy(Drawer.Slot())
    -- A chip, a word, the + links, a remove button and the scroll bars are controls.
    pressOn(Drawer, strip(Drawer).chip.fade, "stripStack")
    T.truthy(Drawer.Slot(), "a press on a chip keeps it")
    pick(Drawer, "fade")
    T.truthy(Drawer.Slot() and strip(Drawer).chip.fade.on, "and the click still picks")
    pressOn(Drawer, wordOf(Drawer, 1, "moment"), "bodyStack")
    T.truthy(Drawer.Slot(), "a press on a word keeps it, its click moves it")
    wordOf(Drawer, 1, "moment"):Click()
    T.eq(Drawer.Slot().kind, "moment")
    pressOn(Drawer, addLink(Drawer, "group"), "bodyStack")
    T.truthy(Drawer.Slot(), "a press on an add link keeps it")
    pressOn(Drawer, sentences(Drawer)[1].remove, "bodyStack")
    T.truthy(Drawer.Slot(), "a press on a remove button keeps it")
    local bar = Drawer.Parts().stripStack.bar
    bar:EnableMouse(true)
    pressOn(Drawer, bar)
    T.truthy(Drawer.Slot(), "a press on the strip's scroll bar keeps it")
    -- Daylight UI's color picker, while it is up.
    local keepPicker = rawget(_G, "ColorPickerFrame")
    _G.ColorPickerFrame = { IsShown = function() return true end, IsMouseOver = function() return true end,
        HookScript = function() end }
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    _G.ColorPickerFrame = keepPicker
    T.truthy(Drawer.Slot(), "a press in the color picker keeps it")
    -- Empty space in the drawer.
    stub.MouseEnter(Drawer.Clip())
    stub.FireEvent("GLOBAL_MOUSE_DOWN", "LeftButton")
    stub.MouseLeave(Drawer.Clip())
    noStrip(Drawer, "a press on empty drawer space")
    T.eq(sentences(Drawer)[2].said, "While it's cooling down, make it see-through.", "the pick stays written")
    -- Anywhere outside.
    wordOf(Drawer, 1, "moment"):Click()
    T.truthy(Drawer.Slot())
    press(nil)
    noStrip(Drawer, "a press outside the drawer")
    -- With no strip open a press does nothing to the drawer.
    local before = Drawer.Frame():GetHeight()
    press(nil)
    T.eq(Drawer.Frame():GetHeight(), before)
    noErrors()
end)

T.test("drawer strip stays: a refused write closes it and says why", function()
    local _, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 2, "action"):Click()
    stub.combat = true
    pick(Drawer, "hide")
    stub.combat = false
    T.eq(Drawer.Refused().why, "combat")
    T.isnil(Drawer.Slot(), "closed, the reason in its place")
    T.eq(blocksWith(Drawer, "refusal")[1].said, Drawer.REFUSED.combat)
    noErrors()
end)

T.test("drawer strip stays: a sound chip previews and the strip stays for the next one", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    wordOf(Drawer, 1, "action"):Click()
    pick(Drawer, "sound")
    T.eq(Drawer.Slot().kind, "action")
    local played = {}
    local keep = DUI.Sound.Alert
    DUI.Sound.Alert = function(key) played[#played + 1] = key; return keep(key) end
    wordOf(Drawer, 1, "sound"):Click()
    local first, second
    for _, key in ipairs(strip(Drawer).keys) do
        if key ~= "none" and not first then first = key elseif key ~= "none" and not second and key ~= first then second = key end
    end
    pick(Drawer, first)
    stub.RunTimers()
    T.eq(Drawer.Slot().kind, "sound", "the sound list stays")
    T.truthy(strip(Drawer).chip[first].on, "the sound lit")
    pick(Drawer, second)
    stub.RunTimers()
    T.deq(played, { first, second }, "each chip played its own sound")
    T.eq(pieceOf(k.clap).readySound, second)
    T.truthy(strip(Drawer).chip[second].on and not strip(Drawer).chip[first].on)
    DUI.Sound.Alert = keep
    noErrors()
end)

-- A right-click on a chosen word puts it back to its blank (docs/tasks/w1-batch-a-fixes.md 6).
T.test("drawer right-click: a chosen word goes back to its blank chip; a blank stays", function()
    local DUI, _, Drawer, _, k, _, Ed = editorWorld()
    Ed.Select(k.clap)
    local moment = wordOf(Drawer, 1, "moment")
    T.truthy(moment.__clicks and table.concat(moment.__clicks, " "):find("RightButtonUp", 1, true),
        "a chosen word takes right-clicks")
    local clicks = 0
    local keep = DUI.Sound.Play
    DUI.Sound.Play = function(name, ...) if name == "click" then clicks = clicks + 1 end return keep(name, ...) end
    moment:Click("RightButton")
    DUI.Sound.Play = keep
    T.eq(clicks, 1, "Daylight UI's link plays its own click")
    T.isnil(pieceOf(k.clap).readyGlow, "the glow line no longer writes")
    T.truthy(said(Drawer):find("choose a moment, glow", 1, true), "the moment is a blank again: " .. said(Drawer))
    local blank
    for i = 1, #sentences(Drawer) do
        local w = wordOf(Drawer, i, "moment")
        if w and w.SetOn then blank = w end
    end
    T.truthy(blank, "a blank chip")
    T.falsy(blank.__clicks and table.concat(blank.__clicks, " "):find("RightButtonUp", 1, true),
        "a blank has nothing to clear")
    -- The action word: the line keeps its moment.
    wordOf(Drawer, 1, "action"):Click("RightButton")
    T.truthy(said(Drawer):find("choose what happens", 1, true), "the action is a blank again: " .. said(Drawer))
    T.isnil(Drawer.Slot(), "a right-click opens no strip")
    noErrors()
end)
