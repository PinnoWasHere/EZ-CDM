local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local CW = require("cdmworld")
local W = require("classworld")

-- EZ-CDM owns a piece's gray (docs/tasks/gray-owned.md):
--   1 a piece with an EZ gray line has Daylight UI's Gray out at Stay colored, and
--     the player's own Gray out comes back when the last EZ gray line goes. The
--     original is kept by profile and piece and survives a /reload. A change in
--     Daylight UI's card while EZ-CDM owns the gray becomes the kept original
--   2 EZ-CDM's gray is a desaturated copy of the piece's own icon on its
--     API.Attach holder: same texture, crop and masks, under the swipe, and it
--     follows an icon swap
--   3 on Flame Shock (its debuff and its cooldown) the gray never doubles: off
--     while the debuff shows, on the moment it gives way while the spell cools down

local FLAME = 8050

local function noErrors()
    T.eq(#stub.errors, 0, tostring(stub.errors[1]))
    T.eq(stub.lockErrors, 0, "no call the client refuses")
end

local function line(moment, action, extra)
    local l = { moment = moment, action = action }
    for k, v in pairs(extra or {}) do l[k] = v end
    return l
end

local GRAY = line("blocked", "gray")
local DAYLIGHT_GRAY = line("cooldown", "gray")

-- A Shaman with Flame Shock on its Essential row, placed as an icon. The game's
-- own item draws it, showing its debuff and its cooldown in turn.
local function shaman(opts)
    local w = W.Build("SHAMAN", opts)
    local key = CW.ID(w.Row(FLAME).spell, W.ESSENTIAL)
    if not w.AB.CdmData.Get(1).pieces[key] then
        w.AB.CdmData.AddPiece(w.AB.CdmData.Ensure(1), key, "icon", 0, 0)
    end
    w.Pass()
    return w, key
end

local function write(w, key, lines)
    local ok, why, report = w.ns.Draft.Write(key, { lines = lines, shows = "both" })
    T.truthy(ok, tostring(why) .. " " .. tostring(report and report.notes and report.notes[1]
        and report.notes[1].words))
    w.Pass()
end

local function desat(w, key) return w.AB.CdmData.Get(1).pieces[key].desat end

-- The game's gray on the piece's icon, as the client draws it.
local function gameGray(key)
    local item = CW.Item(key)
    local on
    CW.Run(function() on = item:GetIconTexture():IsDesaturated() end)
    return on
end

-- Whether EZ-CDM's desaturated copy shows on the piece now.
local function copyShown(w, key, id)
    local v = w.ns.Conditions.Visible(key, id or "cantCast:gray")
    return v.lit and v.shown and type(v.alpha) == "number" and v.alpha > 0 and not v.covered
end

-- Daylight UI's card changes Gray out, as its dropdown writes it.
local function cardSets(w, key, value)
    local D = w.AB.CdmData
    T.truthy(D.SetSpellValue(D.Ensure(1), key, "desat", value))
    w.AB.CdmEditor.Changed()
    for _ = 1, 3 do stub.RunTimers() end
    w.Pass()
end

local function openOn(w, key)
    T.truthy(w.AB.CdmEditor.Open())
    stub.RunTimers()
    w.AB.CdmEditor.Select(key)
    stub.RunTimers()
end

local function bodySaid(w)
    local out = {}
    for _, b in ipairs(w.ns.Drawer.Parts().bodyStack.pieces) do
        if b:IsShown() and type(b.said) == "string" then out[#out + 1] = b.said end
    end
    return table.concat(out, " | ")
end

-- ---------------------------------------------------------------------
-- 1. Who owns the gray
-- ---------------------------------------------------------------------

T.test("owned: an EZ gray line sets Gray out to Stay colored and keeps the player's Default", function()
    local w, key = shaman()
    T.isnil(desat(w, key), "Default before")
    write(w, key, { GRAY })
    T.eq(desat(w, key), "color", "Stay colored while EZ-CDM owns the gray")
    T.deq(w.ns.Gray.Record(key), { was = "game" }, "the player's Default kept")
    local profile = w.ns.Bridge.ProfileOf(1)
    T.deq(EZCDMDB.grayOwned[profile][key], { was = "game" }, "by profile and piece")
    write(w, key, {})
    T.isnil(desat(w, key), "Default back once the last gray line goes")
    T.isnil(w.ns.Gray.Record(key), "nothing kept")
    noErrors()
end)

T.test("owned: any EZ gray line owns it; a glow line doesn't", function()
    local w, key = shaman()
    write(w, key, { line("blocked", "glow") })
    T.isnil(desat(w, key), "a can't cast glow leaves Gray out alone")
    write(w, key, { line("unusable", "gray") })
    T.eq(desat(w, key), "color", "not usable, gray")
    write(w, key, { line("blocked", "glow"), line("unusable", "gray"), GRAY })
    T.eq(desat(w, key), "color", "two gray lines")
    write(w, key, { line("unusable", "gray") })
    T.eq(desat(w, key), "color", "one gray line left still owns it")
    write(w, key, { line("blocked", "glow") })
    T.isnil(desat(w, key), "the last gray line gone")
    noErrors()
end)

T.test("owned: the player's Gray restores, and its line reads as drawn by EZ-CDM", function()
    local w, key = shaman()
    write(w, key, { DAYLIGHT_GRAY })
    T.eq(desat(w, key), "grey", "the player's own Gray out")
    write(w, key, { DAYLIGHT_GRAY, GRAY })
    T.eq(desat(w, key), "color", "EZ-CDM owns it")
    T.deq(w.ns.Gray.Record(key), { was = "grey" })
    local rules = w.ns.Draft.Rules(key)
    local has = false
    for _, l in ipairs(rules.lines) do
        if l.moment == "cooldown" and l.action == "gray" then has = true end
        T.falsy(l.moment == "cooldown" and l.action == "color", "no keep its color line the player never wrote")
    end
    T.truthy(has, "the drawer still reads the player's own Daylight line")
    openOn(w, key)
    local said = bodySaid(w)
    T.truthy(said:find(w.ns.Grammar.WORDING.grayOwned, 1, true), said)
    write(w, key, { DAYLIGHT_GRAY })
    T.eq(desat(w, key), "grey", "Gray back once EZ-CDM's line goes")
    noErrors()
end)

T.test("owned: with the Daylight line and a not-usable gray, EZ-CDM draws the cooling gray", function()
    local w, key = shaman()
    write(w, key, { DAYLIGHT_GRAY, line("unusable", "gray") })
    w.Usable(true, false)
    local sp = w.ns.Bridge.SpellOf(key)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    T.eq(gameGray(key), false, "no game gray")
    T.falsy(copyShown(w, key, "notUsable:gray"), "usable: the not usable line is off")
    local lit = w.ns.Conditions.Lit(key) or {}
    T.truthy(lit.wash, "the Daylight line's gray, drawn by EZ-CDM")
    w.Ready(sp); w.Ready(FLAME)
    T.isnil((w.ns.Conditions.Lit(key) or {}).wash, "ready: no gray")
    noErrors()
end)

T.test("owned: the kept original survives a /reload and still restores", function()
    local w, key = shaman()
    write(w, key, { DAYLIGHT_GRAY, GRAY })
    w.Reload()
    T.eq(desat(w, key), "color")
    T.deq(w.ns.Gray.Record(key), { was = "grey" })
    write(w, key, { DAYLIGHT_GRAY })
    T.eq(desat(w, key), "grey")
    noErrors()
end)

T.test("owned: a change in Daylight UI's card becomes the kept original, never lost", function()
    local w, key = shaman()
    write(w, key, { GRAY })
    openOn(w, key)
    cardSets(w, key, "grey")
    T.eq(desat(w, key), "color", "EZ-CDM keeps the gray its own, so it never doubles")
    T.deq(w.ns.Gray.Record(key), { was = "grey" }, "the card's pick is the original now")
    local said = bodySaid(w)
    T.truthy(said:find(w.ns.Grammar.WORDING.grayOwned, 1, true), "the drawer shows the pick as EZ-CDM's: " .. said)
    write(w, key, w.ns.Draft.Rules(key).lines)
    T.eq(desat(w, key), "color")
    local rest = {}
    for _, l in ipairs(w.ns.Draft.Rules(key).lines) do
        if not (l.moment == "blocked" and l.action == "gray") then rest[#rest + 1] = l end
    end
    write(w, key, rest)
    T.eq(desat(w, key), "grey", "the card's pick comes back, not the older Default")
    noErrors()
end)

T.test("owned: a line from an earlier build is claimed at login", function()
    local w, key = shaman()
    local profile = w.ns.Bridge.SavedProfile(1)
    EZCDMDB.conditions = { [profile] = { [key] = { cantCast = { gray = true } } } }
    EZCDMDB.conditionsVersion = w.ns.Conditions.VERSION
    EZCDMDB.grayOwned = nil
    w.Reload()
    T.eq(desat(w, key), "color")
    T.deq(w.ns.Gray.Record(key), { was = "game" })
    noErrors()
end)

T.test("owned: a gray line gone another way puts the original back", function()
    local w, key = shaman()
    write(w, key, { DAYLIGHT_GRAY, GRAY })
    T.truthy(w.ns.Conditions.SetRule(1, key, nil))
    w.Pass()
    T.eq(desat(w, key), "grey")
    T.isnil(w.ns.Gray.Record(key))
    noErrors()
end)

T.test("owned: by profile; another profile's piece is left alone, and a copy gets the original", function()
    local w, key = shaman()
    write(w, key, { GRAY })
    local A = w.ns.Bridge.ProfileOf(1)
    local B = w.ns.Bridge.NewAndAssign(1, "Second")
    T.truthy(B)
    w.AB.CdmData.AddPiece(w.AB.CdmData.Ensure(1), key, "icon", 0, 0)
    w.Pass()
    w.ns.Conditions.Sync()
    T.isnil(desat(w, key), "profile B's piece keeps its own Default")
    T.isnil(w.ns.Gray.Record(key), "nothing kept on B")
    T.truthy(w.ns.Bridge.Assign(1, A))
    w.ns.Conditions.Sync()
    w.Pass()
    T.eq(desat(w, key), "color", "profile A still owned")
    local C = w.ns.Bridge.CopyAndAssign(1, A)
    T.truthy(C)
    w.ns.Conditions.Sync()
    w.Pass()
    T.isnil(w.ns.Conditions.Rule(key), "EZ-CDM's lines stay with A")
    T.isnil(desat(w, key), "the copy has the original, not A's Stay colored")
    T.truthy(w.ns.Bridge.Assign(1, A))
    w.ns.Conditions.Sync()
    T.eq(desat(w, key), "color", "A untouched")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 2. The desaturated copy
-- ---------------------------------------------------------------------

T.test("copy: a desaturated copy of the piece's icon on its holder, under the swipe", function()
    local w, key = shaman()
    write(w, key, { GRAY })
    w.Usable(false, false)
    T.truthy(copyShown(w, key), "lit and on show")
    local c = w.ns.Overlay.Copy(key, "gray")
    T.truthy(c, "the copy")
    local frame = w.ns.Conditions.FrameOf(key)
    local holder = w.DUI.API.Attach(frame)
    T.eq(c.frame:GetParent(), holder, "on the piece's API.Attach holder")
    local icon = w.ns.Bridge.PieceIcon(frame)
    T.truthy(icon, "the piece's own icon")
    T.eq(c.tex:IsDesaturated(), true, "desaturated, as the game's gray")
    T.eq(c.tex:GetTexture(), icon:GetTexture(), "the icon's texture")
    T.deq({ c.tex:GetTexCoord() }, { icon:GetTexCoord() }, "the icon's crop")
    local _, rel = c.tex:GetPoint(1)
    T.eq(rel, icon, "laid on the icon itself")
    T.eq(c.frame:GetFrameLevel(), icon:GetParent():GetFrameLevel(), "at the icon's level, under its swipe")
    T.eq(c.frame:GetAlpha(), 1, "full strength: no tint, no half gray")
    T.eq(gameGray(key), false, "and no game gray under it")
    w.Usable(true, false)
    T.falsy(copyShown(w, key), "castable: off")
    T.eq(c.frame:GetAlpha(), 0, "off at once, no fade")
    noErrors()
end)

T.test("copy: follows an icon swap and the icon's masks", function()
    local w, key = shaman()
    write(w, key, { GRAY })
    w.Usable(false, false)
    local frame = w.ns.Conditions.FrameOf(key)
    local icon = w.ns.Bridge.PieceIcon(frame)
    -- The spell's icon changes (an override), and the game's item follows on its event.
    local S = CW.G.C_Spell
    local was = S.GetSpellTexture
    S.GetSpellTexture = function() return 136048, 136048, nil end
    stub.FireEvent("SPELL_UPDATE_ICON")
    for _ = 1, 3 do stub.RunTimers() end
    local c = w.ns.Overlay.Copy(key, "gray")
    T.eq(icon:GetTexture(), 136048, "the game's item took the new icon")
    T.eq(c.tex:GetTexture(), 136048, "and the copy with it")
    S.GetSpellTexture = was
    local mask
    CW.Run(function()
        mask = icon:GetParent():CreateMaskTexture()
        mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end)
    w.Usable(true, false); w.Usable(false, false)
    T.eq(c.tex:GetNumMaskTextures(), 1, "the icon's mask")
    T.eq(c.tex:GetMaskTexture(1):GetTexture(), mask:GetTexture(), "its shape")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 3. Flame Shock: one gray, on the icon it is about
-- ---------------------------------------------------------------------

-- Never both grays, and the copy only where the sentence says.
local function oneGray(w, key, want, what)
    local copy, game = copyShown(w, key) and true or false, gameGray(key)
    T.falsy(copy and game, what .. ": never both grays")
    T.eq(game, false, what .. ": Daylight's gray stays off")
    T.eq(copy, want, what .. ": EZ-CDM's gray")
end

T.test("Flame Shock: cast, debuff up and cooling, debuff ends while cooling, cooldown ends", function()
    local w, key = shaman()
    write(w, key, { GRAY })
    w.Usable(true, false)
    w.EnterCombat()
    oneGray(w, key, false, "ready")
    local sp = w.ns.Bridge.SpellOf(key)
    w.Cast(sp)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    w.BuffUp(FLAME, { unit = "target", duration = 12 })
    oneGray(w, key, false, "debuff up, cooling: its timer in colour")
    T.eq(w.ns.Conditions.Visible(key, "cantCast:gray").covered, true, "the cooldown icon gives way to the debuff")
    w.BuffDown(FLAME)
    oneGray(w, key, true, "debuff gone, still cooling")
    w.Ready(sp); w.Ready(FLAME)
    oneGray(w, key, false, "cooldown over")
    noErrors()
end)

T.test("Flame Shock: the owner's log order, cooldown ends under the debuff, then it falls off", function()
    local w, key = shaman()
    write(w, key, { GRAY })
    w.Usable(true, false)
    w.EnterCombat()
    local sp = w.ns.Bridge.SpellOf(key)
    w.Cast(sp)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    w.BuffUp(FLAME, { unit = "target", duration = 12 })
    oneGray(w, key, false, "cast")
    w.Ready(sp); w.Ready(FLAME)
    oneGray(w, key, false, "ready under the debuff")
    w.BuffDown(FLAME)
    oneGray(w, key, false, "debuff gone, ready")
    w.Cast(sp)
    w.Cooldown(sp, 6); w.Cooldown(FLAME, 6)
    oneGray(w, key, true, "another shock cast, no debuff up yet")
    w.BuffUp(FLAME, { unit = "target", duration = 12 })
    oneGray(w, key, false, "its debuff lands")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- 4. The stacking note is gone
-- ---------------------------------------------------------------------

T.test("no stacking note and no keep its color fix: the grays never stack", function()
    local w, key = shaman()
    local G = w.ns.Grammar
    T.isnil(G.GrayNote, "no Grammar.GrayNote")
    T.isnil(G.WORDING.grayStacks); T.isnil(G.WORDING.grayDebuff); T.isnil(G.WORDING.fixColor)
    write(w, key, { GRAY })
    openOn(w, key)
    for _, b in ipairs(w.ns.Drawer.Parts().bodyStack.pieces) do
        T.falsy(b:IsShown() and b.gray, "no note under the gray line")
    end
    T.falsy(bodySaid(w):find("stack", 1, true), "no word of stacking")
    noErrors()
end)
