local stub = require("stub")
local CW = require("cdmworld")

-- EZ-CDM/Start.lua: the start block beside Daylight UI's own CDM editor tray,
-- against Daylight UI's real Cooldown Manager and editor and the game's own
-- viewers (cdmworld, a warrior).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871
local ESSENTIAL, UTILITY = 0, 1

-- Daylight UI, the game's Cooldown Manager and EZ-CDM, logged in.
local function world()
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, BLOCK, RAGE, CLAP, WALL }, showAll = true })
        for id, name in pairs({ [SHOUT] = "Battle Shout", [REND] = "Rend", [BLOCK] = "Shield Block",
                                [RAGE] = "Bloodrage", [CLAP] = "Thunder Clap", [WALL] = "Shield Wall" }) do
            stub.spells[id] = { name = name }
        end
    end })
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    return DUI, ns, ns.Start, stub.actionbars
end

-- Two saved layouts: "Main" (talent set 1 uses it) holds Rend and Thunder Clap,
-- "Second" holds Bloodrage.
local function layoutsWorld()
    local DUI, ns, Start, AB = world()
    local D = AB.CdmData
    local set = D.Ensure(1)
    local main = D.Use(1)
    D.RenameProfile(main, "Main")
    D.AddPiece(set, CW.ID(REND, ESSENTIAL), "icon", 0, 0)
    D.AddPiece(set, CW.ID(CLAP, ESSENTIAL), "icon", 50, 0)
    local second = D.NewProfile("Second", "WARRIOR")
    D.AddPiece(D.Profile(second).set, CW.ID(RAGE, UTILITY), "bar", 0, -100)
    -- Daylight UI marks a layout's format on its first read (CdmData normalize), as
    -- it does for any layout it has shown. Talent set 2 shows Second once, so the
    -- byte checks below see only what EZ-CDM does.
    D.Assign(2, second)
    D.Get(2)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    return DUI, ns, Start, AB, main, second
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

-- Chat lines that start with EZ-CDM's name.
local function ourLines()
    local out = {}
    for _, line in ipairs(stub.chat) do
        if tostring(line):find("^EZ%-CDM") then out[#out + 1] = line end
    end
    return out
end

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
local function profileText(id) return dump(DaylightUIDB.cdmProfiles[id]) end
local function profileCount() return #stub.actionbars.CdmData.Profiles("WARRIOR") end

-- The layout list's rows, by profile id.
local function rowOf(Start, id)
    for _, b in ipairs(Start.Parts().stack.pieces) do
        if b:IsShown() and b.spec and b.spec.id == "layout:" .. tostring(id) then return b end
    end
end

local function rowNames(Start)
    local out = {}
    for _, b in ipairs(Start.Parts().stack.pieces) do
        if b:IsShown() and b.spec then out[#out + 1] = stub.Text(b.text) end
    end
    return table.concat(out, ", ")
end

-- Daylight UI's editor open, the block on its cards.
local function openEditor(AB)
    T.truthy(AB.CdmEditor.Open(), "the editor opens")
    stub.RunTimers()
end

local function openLoad(Start, AB)
    openEditor(AB)
    Start.Parts().picker.cards.load:Click()
end

-- Daylight UI's /cdm handler, wherever it took the command.
local function slashCdm()
    for key, fn in pairs(SlashCmdList) do
        for i = 1, 9 do
            local sl = _G["SLASH_" .. key .. i]
            if type(sl) ~= "string" then break end
            if string.lower(sl) == "/cdm" then return fn end
        end
    end
end

-- ---------------------------------------------------------------------
-- The block and its cards
-- ---------------------------------------------------------------------

T.test("start: the block attaches right of the tray on the editor's open and detaches on close", function()
    local DUI, _, Start, AB = layoutsWorld()
    local Ed = AB.CdmEditor
    local picked, keep = 0, DUI.InstallerCards.Picker
    DUI.InstallerCards.Picker = function(...) picked = picked + 1; return keep(...) end
    T.isnil(Start.Frame(), "nothing is built before the editor opens")
    openEditor(AB)
    DUI.InstallerCards.Picker = keep
    local f = Start.Frame()
    T.truthy(f, "built on the editor's first open")
    T.truthy(Start.Shown(), "shown")
    T.eq(f:GetParent(), Ed.Overlay(), "on the editor's own full-screen frame")
    T.eq(f:GetFrameLevel(), Ed.Tray():GetFrameLevel(), "the tray's level")
    T.truthy(f:IsMouseEnabled(), "a click on it never reaches the overlay")
    local p, rel, rp, x = f:GetPoint(1)
    T.eq(p, "TOPLEFT"); T.eq(rel, Ed.Tray()); T.eq(rp, "TOPRIGHT", "on the tray's right")
    T.eq(x, DUI.Win.Parts.GAP, "the window parts' gap from it")
    p, rel, rp = f:GetPoint(2)
    T.eq(p, "BOTTOMLEFT"); T.eq(rel, Ed.Tray()); T.eq(rp, "BOTTOMRIGHT", "down to the tray's bottom")
    T.eq(Start.side, "right")
    T.eq(f:GetWidth(), Start.W)
    T.eq(picked, 1, "the cards are Daylight UI's setup guide picker")
    Ed.Close()
    T.falsy(Start.Shown(), "the editor's Done hides it")
    T.falsy(f:IsShown())
    Ed.Open()
    T.truthy(Start.Shown(), "back with the editor")
    T.eq(Start.Mode(), "cards", "on its cards")
    noErrors()
end)

T.test("start: the block matches the tray's height as the tray grows", function()
    local _, _, Start, AB = layoutsWorld()
    openEditor(AB)
    local tray = AB.CdmEditor.Tray()
    T.truthy(tray:GetHeight() > 0, "the tray has a height: " .. tostring(tray:GetHeight()))
    T.eq(Start.Frame():GetHeight(), tray:GetHeight(), "the tray's height")
    -- More spells on the tray: it grows on the next draw, and the block with it.
    tray:SetHeight(tray:GetHeight() + 34)
    AB.CdmEditor.Draw()
    T.eq(Start.Frame():GetHeight(), tray:GetHeight(), "follows the tray's draw")
    noErrors()
end)

T.test("start: the two compact cards are stacked at the block's top", function()
    local DUI, _, Start, AB = layoutsWorld()
    openEditor(AB)
    local f, tray = Start.Frame(), AB.CdmEditor.Tray()
    local picker = Start.Parts().picker
    local cards = picker.cards
    T.truthy(picker:IsShown())
    T.falsy(Start.Parts().list:IsShown(), "no list yet")
    T.falsy(Start.Parts().name:IsShown(), "no name box yet")
    T.eq(stub.Text(cards.blank.label), "EZ-Start Blank")
    T.eq(stub.Text(cards.load.label), "EZ-Load Layout")
    T.deq(cards.blank.tooltip, { "EZ-Start Blank", Start.SUBS.blank }, "the card's tooltip says what it does")
    T.deq(cards.load.tooltip, { "EZ-Load Layout", Start.SUBS.load })
    T.falsy(cards.blank.selected or cards.load.selected, "neither card is ticked")
    local _, _, _, x1, y1 = cards.blank:GetPoint(1)
    local _, _, _, x2, y2 = cards.load:GetPoint(1)
    T.eq(x1, x2, "one column")
    T.eq(y1, 0, "EZ-Start Blank on top")
    T.eq(y2, -(cards.blank:GetHeight() + DUI.InstallerCards.GAP), "EZ-Load Layout under it, the picker's own gap")
    T.eq(cards.blank:GetHeight(), Start.CARD_H, "compact")
    T.eq(cards.load:GetHeight(), Start.CARD_H)
    T.truthy(Start.CARD_H <= 64, "at most the picker's own card height")
    local p, rel, rp, _, y = picker:GetPoint(1)
    T.eq(p, "TOPLEFT"); T.eq(rel, f); T.eq(rp, "TOPLEFT")
    T.eq(y, -DUI.Win.Parts.GAP, "at the block's top")
    T.truthy(DUI.Win.Parts.GAP + picker:GetHeight() < tray:GetHeight(), "room to spare under them")
    T.eq(f:GetHeight(), tray:GetHeight(), "the block keeps the tray's height")
    noErrors()
end)

T.test("start: left of the tray when the screen has no room on its right", function()
    local _, _, Start, AB = layoutsWorld()
    local Ed = AB.CdmEditor
    openEditor(AB)
    local tray, o = Ed.Tray(), Ed.Overlay()
    tray.GetLeft = function() return 1000 end
    tray.GetRight = function() return 1300 end
    o.GetLeft = function() return 0 end
    o.GetRight = function() return 1366 end
    Ed.Draw()
    local p, rel, rp = Start.Frame():GetPoint(1)
    T.eq(Start.side, "left")
    T.eq(p, "TOPRIGHT"); T.eq(rel, tray); T.eq(rp, "TOPLEFT", "on the tray's left")
    tray.GetLeft = function() return 300 end
    tray.GetRight = function() return 900 end
    Ed.EndTrayMove()
    T.eq(Start.side, "right", "back once the tray moves")
    noErrors()
end)

T.test("start: /cdm opens Daylight UI's editor with the block, and EZ-CDM adds no command", function()
    local _, _, Start, AB = layoutsWorld()
    T.eq(_G.EZCDM_Start, Start, "the debug handle")
    T.isnil(_G.SLASH_EZCDM1, "no /ezcdm")
    T.isnil(SlashCmdList.EZCDM, "no /ezcdm handler")
    SlashCmdList.DAYLIGHTUI("ezcdm")
    stub.RunTimers()
    T.falsy(AB.CdmEditor.IsOpen(), "/dui ezcdm opens nothing")
    slashCdm()("")
    stub.RunTimers()
    T.truthy(Start.Shown(), "/cdm brings the block too")
    T.eq(_G.EZCDMStart, nil, "no start window")
    noErrors()
end)

T.test("start: the Work on a copy row fits the block's width", function()
    local DUI, _, Start, AB = layoutsWorld()
    openLoad(Start, AB)
    local p = Start.Parts()
    local edge, gap = DUI.Win.EDGE, DUI.Win.Parts.GAP
    local _, rel, rp, x, y = p.copy:GetPoint(1)
    T.eq(rel, p.back); T.eq(rp, "BOTTOMLEFT", "on its own row, under Back")
    T.eq(x, 0); T.eq(y, -gap)
    local right = edge + p.copy:GetWidth() + gap + p.copyText:GetStringWidth()
    T.truthy(right <= Start.W - edge, "the words end inside the block: " .. right .. " <= " .. (Start.W - edge))
    local tp, trel, trp, tx = p.copyText:GetPoint(2)
    T.eq(tp, "RIGHT"); T.eq(trel, p.list); T.eq(trp, "RIGHT"); T.eq(tx, -edge, "held inside the block's right side")
    -- The list starts under the row.
    local top = gap + p.back:GetHeight() + gap + p.copy:GetHeight() + gap
    local _, _, _, _, sy = p.stack.scroll:GetPoint(1)
    T.eq(sy, -top, "the list under both rows")
    noErrors()
end)

T.test("start: Load a layout lists the class's layouts, the one in use tagged, copy on, and Back", function()
    local _, _, Start, AB, main, second = layoutsWorld()
    openLoad(Start, AB)
    local p = Start.Parts()
    T.eq(Start.Mode(), "load")
    T.falsy(p.picker:IsShown(), "the cards make way")
    T.truthy(p.list:IsShown(), "for the list")
    T.truthy(p.copy.on, "Work on a copy is on")
    T.eq(stub.Text(p.copyText), "Work on a copy")
    T.eq(stub.Text(p.back.text), "Back", "Daylight UI's button")
    T.eq(rowNames(Start), "Main, Second", "by name")
    local using = rowOf(Start, main)
    T.truthy(using.tag and using.tag:IsShown(), "the layout in use carries a tag")
    T.eq(stub.Text(using.tag.text), "IN USE")
    T.falsy(rowOf(Start, second).tag and rowOf(Start, second).tag:IsShown(), "the other doesn't")
    p.back:Click()
    T.eq(Start.Mode(), "cards", "Back shows the cards")
    T.truthy(p.picker:IsShown())
    T.falsy(p.list:IsShown())
    noErrors()
end)

-- ---------------------------------------------------------------------
-- What the cards do
-- ---------------------------------------------------------------------

T.test("start: EZ-Start Blank asks for a name in the block first", function()
    local DUI, _, Start, AB = layoutsWorld()
    openEditor(AB)
    local p = Start.Parts()
    local before = db()
    p.picker.cards.blank:Click()
    T.eq(Start.Mode(), "name")
    T.falsy(p.picker:IsShown(), "the cards make way")
    T.truthy(p.name:IsShown(), "for the name box")
    T.truthy(p.input.hint and p.input.SetFocus, "Daylight UI's input")
    T.eq(stub.Text(p.input.hint), "Name your layout")
    T.truthy(p.input:HasFocus(), "ready to type")
    T.eq(stub.Text(p.create.text), "Create", "Daylight UI's button")
    T.eq(stub.Text(p.nameBack.text), "Back")
    T.falsy(p.noName:IsShown(), "no refusal yet")
    T.eq(db(), before, "asking writes nothing")
    local edge = DUI.Win.EDGE
    local _, _, _, x = p.input:GetPoint(1)
    T.eq(x, edge, "inside the block's sides")
    p.nameBack:Click()
    T.eq(Start.Mode(), "cards", "Back shows the cards")
    T.falsy(p.input:HasFocus())
    noErrors()
end)

T.test("start: an empty name is refused and writes nothing", function()
    local DUI, _, Start, AB = layoutsWorld()
    openEditor(AB)
    local p = Start.Parts()
    local before, count = db(), profileCount()
    p.picker.cards.blank:Click()
    p.input:SetText("   ")
    p.create:Click()
    T.eq(db(), before, "DaylightUIDB deep-equal")
    T.eq(profileCount(), count, "no profile made")
    T.eq(Start.Mode(), "name", "still asking")
    T.truthy(p.noName:IsShown(), "the block says why")
    T.eq(stub.Text(p.noName), "Give the layout a name first.")
    local bad = DUI.API.Colors().BAD
    T.deq({ p.noName:GetTextColor() }, { bad[1], bad[2], bad[3], 1 }, "in BAD")
    local ok, why = Start.Blank("")
    T.falsy(ok); T.eq(why, "name")
    T.eq(#ourLines(), 0, "no chat line")
    p.nameBack:Click()
    p.picker.cards.blank:Click()
    T.falsy(p.noName:IsShown(), "asking again starts clean")
    noErrors()
end)

T.test("start: EZ-Start Blank makes an empty profile with the name, and the open editor shows it", function()
    local _, _, Start, AB, main, second = layoutsWorld()
    local D = AB.CdmData
    local mainText, secondText = profileText(main), profileText(second)
    openEditor(AB)
    local count = profileCount()
    Start.Parts().picker.cards.blank:Click()
    Start.Parts().input:SetText("  Raid night ")
    Start.Parts().create:Click()
    stub.RunTimers()
    local new = D.Use(1)
    T.truthy(new and new ~= main and new ~= second, "talent set 1 uses a new profile: " .. tostring(new))
    T.eq(profileCount(), count + 1, "one profile more")
    T.eq(D.Profile(new).name, "Raid night", "the name, trimmed")
    T.eq(Start.Mode(), "cards", "the block shows its cards again")
    -- Daylight UI makes a taken name unique.
    Start.Parts().picker.cards.blank:Click()
    Start.Parts().input:SetText("Main")
    Start.Parts().input:GetScript("OnEnterPressed")(Start.Parts().input)
    T.eq(D.Profile(D.Use(1)).name, "Main 2", "Enter creates it too, under Daylight UI's unique name")
    T.eq(profileText(main), mainText, "Main is byte-identical")
    new = D.Use(1)
    T.eq(D.Profile(new).class, "WARRIOR")
    T.isnil(next(D.Profile(new).set.pieces), "no pieces")
    T.isnil(next(D.Profile(new).set.chains), "no groups")
    T.truthy(AB.CdmEditor.IsOpen(), "Daylight UI's editor stays open")
    T.eq(AB.CdmEditor.Set(), D.Profile(new).set, "on the new layout")
    T.truthy(Start.Shown(), "the block stays")
    T.eq(profileText(main), mainText, "Main is byte-identical")
    T.eq(profileText(second), secondText, "Second is byte-identical")
    noErrors()
end)

T.test("start: Load with Work on a copy assigns a copy and leaves the original byte-identical", function()
    local _, _, Start, AB, main, second = layoutsWorld()
    local D = AB.CdmData
    local mainText, secondText = profileText(main), profileText(second)
    openLoad(Start, AB)
    local count = profileCount()
    rowOf(Start, second):Click()
    stub.RunTimers()
    local new = D.Use(1)
    T.truthy(new and new ~= main and new ~= second, "talent set 1 uses a copy: " .. tostring(new))
    T.eq(profileCount(), count + 1, "one profile more")
    T.eq(D.Profile(new).name, "Second 2", "Daylight UI's own name for a copy")
    T.truthy(D.Profile(new).set.pieces[CW.ID(RAGE, UTILITY)], "the copy holds Second's layout")
    T.eq(profileText(second), secondText, "Second is byte-identical")
    T.eq(profileText(main), mainText, "Main is byte-identical")
    T.truthy(AB.CdmEditor.IsOpen(), "Daylight UI's editor is open")
    T.eq(AB.CdmEditor.Set(), D.Profile(new).set, "on the copy")
    T.eq(Start.Mode(), "cards", "the block shows its cards again")
    noErrors()
end)

T.test("start: Load without a copy assigns the original", function()
    local _, _, Start, AB, main, second = layoutsWorld()
    local D = AB.CdmData
    local mainText = profileText(main)
    openLoad(Start, AB)
    local count = profileCount()
    Start.Parts().copy:Click()
    T.falsy(Start.Copy(), "Work on a copy is off")
    T.falsy(Start.Parts().copy.on, "the switch shows it")
    rowOf(Start, second):Click()
    stub.RunTimers()
    T.eq(D.Use(1), second, "talent set 1 uses Second itself")
    T.eq(profileCount(), count, "no profile made")
    T.eq(profileText(main), mainText, "Main is byte-identical")
    T.eq(AB.CdmEditor.Set(), D.Profile(second).set, "the editor shows Second")
    -- The next open starts with the copy on again.
    AB.CdmEditor.Close()
    openEditor(AB)
    T.truthy(Start.Copy(), "on again")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Refusals
-- ---------------------------------------------------------------------

T.test("start: in combat it refuses with one line and writes nothing", function()
    local _, _, Start, AB, _, second = layoutsWorld()
    openLoad(Start, AB)
    local before = db()
    -- A fight closes Daylight UI's editor, and the block with it.
    stub.EnterCombat()
    T.falsy(AB.CdmEditor.IsOpen())
    T.falsy(Start.Shown(), "a fight hides it")
    local ok, why = Start.Blank("Fresh")
    T.falsy(ok); T.eq(why, "combat", "Start blank")
    ok, why = Start.Load(second)
    T.falsy(ok); T.eq(why, "combat", "Load, on a copy")
    Start.SetCopy(false)
    ok, why = Start.Load(second)
    T.falsy(ok); T.eq(why, "combat", "Load, no copy")
    local lines = ourLines()
    T.eq(#lines, 3, "one line each")
    T.eq(lines[1], Start.COMBAT_LINE)
    T.eq(db(), before, "DaylightUIDB deep-equal")
    T.falsy(AB.CdmEditor.IsOpen(), "the editor stays shut")
    stub.LeaveCombat()
    noErrors()
end)

T.test("start: while EZ-CDM is off it refuses with one line", function()
    local _, ns, Start, AB = layoutsWorld()
    local before = db()
    ns.Bridge.NEEDS[#ns.Bridge.NEEDS + 1] = "ActionBars.CdmData.EZCDMGone"
    local ok, why = Start.Blank("Fresh")
    ns.Bridge.NEEDS[#ns.Bridge.NEEDS] = nil
    T.falsy(AB.CdmEditor.IsOpen(), "the editor isn't opened")
    T.falsy(ok); T.eq(why, "off")
    local lines = ourLines()
    T.eq(#lines, 1, "one line")
    T.truthy(lines[1]:find("EZ-CDM is off", 1, true), tostring(lines[1]))
    T.eq(db(), before, "nothing written")
    noErrors()
end)
