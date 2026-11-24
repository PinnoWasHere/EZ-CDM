local stub = require("stub")
local CW = require("cdmworld")
local IPW = require("infopanelworld")

-- EZ-CDM/Bridge.lua against Daylight UI's real Cooldown Manager and the game's
-- own viewers (cdmworld, a warrior's rows from the game's data).

local SHOUT, REND, BLOCK, RAGE, CLAP, WALL = 6673, 772, 2565, 2687, 6343, 871

-- Daylight UI, the game's Cooldown Manager and EZ-CDM, stopped before login.
-- opts.before(DUI, ns) runs there; opts.off turns Daylight UI's CDM off; opts.panel
-- loads its info panel too.
local function world(opts)
    opts = opts or {}
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, infopanel = opts.panel, login = false, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true },
                        target = { name = "Boar", reaction = 2 } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND, BLOCK, RAGE, CLAP, WALL }, showAll = true })
        for id, name in pairs({ [SHOUT] = "Battle Shout", [REND] = "Rend", [BLOCK] = "Shield Block",
                                [RAGE] = "Bloodrage", [CLAP] = "Thunder Clap", [WALL] = "Shield Wall" }) do
            stub.spells[id] = { name = name }
        end
        if opts.panel then IPW.Install() end
    end })
    if opts.off then
        local mods = DaylightUIDB.profileData[DUI.DB.DEFAULT].modules
        mods.ActionBars = mods.ActionBars or {}
        mods.ActionBars.cooldowns = false
    end
    if opts.before then opts.before(DUI, ns) end
    stub.FireEvent("PLAYER_LOGIN")
    DUI.Fade.SkipIntro()
    stub.RunTimers()
    return DUI, ns, ns.Bridge, stub.actionbars
end

-- Chat lines that start with EZ-CDM's name.
local function ourLines()
    local out = {}
    for _, line in ipairs(stub.chat) do
        if tostring(line):find("^EZ%-CDM") then out[#out + 1] = line end
    end
    return out
end

local function noErrors() T.eq(#stub.errors, 0, tostring(stub.errors[1])) end

T.test("bridge: every NEEDS entry resolves on Daylight UI 2.2.5", function()
    local _, _, B = world()
    T.truthy(#B.NEEDS > 0, "NEEDS lists the internals")
    T.eq(table.concat(B.Missing(), ", "), "", "nothing missing")
    for _, path in ipairs(B.NEEDS) do T.truthy(B.Resolve(path) ~= nil, path .. " resolves") end
    T.truthy(B.CdmOn(), "Daylight UI's Cooldown Manager is on")
    T.truthy(B.Ready(), "the bridge is ready")
    T.falsy(B.off, "not switched off")
    T.eq(#ourLines(), 0, "no chat line")
    T.eq(_G.EZCDM_Bridge, B, "the debug handle")
    noErrors()
end)

T.test("bridge: a missing internal switches EZ-CDM off with one line and no error", function()
    local GONE = "ActionBars.CdmData.EZCDMGone"
    local B
    world({ before = function(_, ns)
        B = ns.Bridge
        B.NEEDS[#B.NEEDS + 1] = GONE
    end })
    T.eq(table.concat(B.Missing(), ", "), GONE, "the missing internal is named")
    T.falsy(B.Ready(), "not ready")
    T.truthy(B.off, "switched off")
    local lines = ourLines()
    T.eq(#lines, 1, "one chat line")
    T.truthy(lines[1]:find(GONE, 1, true), "the line names it: " .. tostring(lines[1]))
    noErrors()
end)

T.test("bridge: a removed internal switches EZ-CDM off, and its read answers nil", function()
    local GONE = "ActionBars.CdmEditor.SpellName"
    local B
    world({ before = function(_, ns)
        B = ns.Bridge
        local found = false
        for _, path in ipairs(B.NEEDS) do found = found or path == GONE end
        T.truthy(found, GONE .. " is in NEEDS")
        stub.actionbars.CdmEditor.SpellName = nil
    end })
    T.eq(table.concat(B.Missing(), ", "), GONE, "the removed internal is named")
    T.falsy(B.Ready(), "not ready")
    T.eq(#ourLines(), 1, "one chat line")
    T.isnil(B.SpellName(CW.ID(REND, ESSENTIAL)), "its read answers nil")
    noErrors()
end)

T.test("bridge: Daylight UI's Cooldown Manager off switches EZ-CDM off with one line", function()
    local _, _, B = world({ off = true })
    T.eq(#B.Missing(), 0, "every internal is there")
    T.falsy(B.CdmOn(), "the Cooldown Manager is off")
    T.falsy(B.Ready(), "not ready")
    local lines = ourLines()
    T.eq(#lines, 1, "one chat line")
    T.truthy(lines[1]:find("Cooldown Manager is off", 1, true), tostring(lines[1]))
    noErrors()
end)

T.test("bridge: an older Daylight UI (API 1.13) switches EZ-CDM off with Daylight UI's one line", function()
    stub.neverSecretAuras = {}
    local DUI, ns = stub.LoadPlugin({ actionbars = true, api13 = true, before = function()
        stub.SetUnits({ player = { name = "Me", class = "WARRIOR", friend = true } })
        CW.Install({ with = SHOUT, known = { SHOUT, REND }, showAll = true })
    end })
    stub.RunTimers()
    local B = ns.Bridge
    T.eq(DUI.API.minor, 13, "API 1.13 (stub.OlderApi)")
    T.falsy(B.ApiFits(), "1.13 is older than EZ-CDM's 1.14")
    T.eq(#B.Missing(), 0, "every internal is there")
    T.falsy(B.Ready(), "not ready")
    T.truthy(B.off, "switched off")
    T.truthy(B.OffLine():find("1.14", 1, true), tostring(B.OffLine()))
    local newer = 0
    for _, line in ipairs(stub.chat) do
        if tostring(line):find("needs a newer DaylightUI", 1, true) then newer = newer + 1 end
    end
    T.eq(newer, 1, "Daylight UI's own line")
    T.eq(#ourLines(), 0, "no second line of EZ-CDM's")
    T.falsy(B.OnBuff(function() end, function() end), "no buff moments to hear")
    T.isnil(B.BuffState(CW.ID(REND, 0)), "no state to read")
    noErrors()
end)

T.test("bridge: the buff moments (API 1.14): OnBuff hears them, BuffState reads them, Refresh asks a pass", function()
    local _, _, B, AB = world()
    T.truthy(B.ApiFits(), "API 1.14")
    local heard = {}
    T.truthy(B.OnBuff(function(sid, key) heard[#heard + 1] = "up " .. tostring(key) .. " " .. tostring(sid) end,
                      function(sid, key) heard[#heard + 1] = "down " .. tostring(key) .. " " .. tostring(sid) end))
    local D = AB.CdmData
    -- Rend, drawn by the game's cooldown icon, which shows its debuff.
    local key = CW.ID(REND, 0)
    D.AddPiece(D.Ensure(1), key, "icon", 0, 0)
    local passes = 0
    _G.DaylightUI.API.For("test").Hook(AB.CdmEffects, "EndPass", function() passes = passes + 1 end)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    local up, by = B.BuffState(key)
    T.eq(up, false, "Rend down")
    T.eq(by, "game", "drawn by the game's item")
    CW.Aura("target", REND, { harmful = true, duration = 9 }); stub.RunTimers()
    T.eq(heard[#heard], "up " .. key .. " " .. REND, "CooldownBuffUp with the key and spell")
    T.eq(B.BuffState(key), true, "up")
    CW.Unaura("target", REND); stub.RunTimers()
    T.eq(heard[#heard], "down " .. key .. " " .. REND, "CooldownBuffDown")
    T.isnil(B.BuffState("no-such-piece"), "nil for a piece not on show")
    local before = passes
    B.Refresh(); stub.RunTimers()
    T.eq(passes, before + 1, "one pass")
    noErrors()
end)

T.test("bridge: Resolve walks a path and stops at a missing part", function()
    local DUI, _, B, AB = world()
    T.eq(B.Resolve("DaylightUI"), DUI, "the core")
    T.eq(B.Resolve("ActionBars.CdmData"), AB.CdmData, "a module's ns")
    T.isnil(B.Resolve("NoSuchModule.Thing"), "an unknown module")
    T.isnil(B.Resolve("ActionBars.CdmData.Nope.Deeper"), "a missing middle part")
    T.isnil(B.Resolve("ActionBars.CdmData.FORMAT.Deeper"), "a value is not a table")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Reads
-- ---------------------------------------------------------------------

local ESSENTIAL, BUFFS = 0, 2

T.test("bridge reads: talent sets, profiles and which one each set uses", function()
    local _, _, B, AB = world()
    local D = AB.CdmData
    T.eq(B.CurrentIndex(), 1, "talent set 1 is shown")
    T.eq(B.SetCount(), 2, "two talent sets")
    T.eq(B.MyClass(), "WARRIOR")
    T.eq(type(B.Layout().pieces), "table", "the current layout")
    T.isnil(B.ProfileOf(1), "no profile picked yet")
    T.eq(#B.Profiles(), 0, "no profiles yet")
    D.Ensure(1)
    local id = B.ProfileOf(1)
    T.truthy(id, "Ensure picked a profile for set 1")
    T.isnil(B.ProfileOf(2), "set 2 still has none")
    T.eq(#B.Profiles(), 1)
    T.eq(B.Profiles()[1].id, id)
    T.eq(B.Profile(id).class, "WARRIOR")
    T.eq(B.Layout(1), B.Profile(id).set, "the layout is the profile's set")
    noErrors()
end)

T.test("bridge reads: Tracked, IsCustom and an option with its default", function()
    local _, _, B, AB = world()
    local D = AB.CdmData
    local wall = CW.ID(WALL, BUFFS)
    local set = D.Ensure(1)
    D.AddPiece(set, wall, "icon", 0, 0)
    set.pieces[wall].track = "buff"
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.eq(B.Tracked(wall), true, "the game has an item for Shield Wall's buff")
    T.isnil(B.Tracked(CW.ID(CLAP, ESSENTIAL)), "an unplaced spell: nil")
    T.truthy(B.IsCustom("s12294"), "a spell key")
    T.truthy(B.IsCustom("mainhand"), "a named family")
    T.falsy(B.IsCustom(wall), "a game cooldown id")
    T.eq(B.Option({}, "cdAlpha"), 0.4, "the default")
    T.eq(B.Option({ cdAlpha = 0.2 }, "cdAlpha"), 0.2, "the piece's own")
    T.eq(B.Option(set.pieces[wall], "glowStyle"), "ring")
    noErrors()
end)

T.test("bridge reads: what a piece shows, its entry, its spell and group defaults", function()
    local _, _, B, AB = world()
    local clap, wall = CW.ID(CLAP, ESSENTIAL), CW.ID(WALL, BUFFS)
    T.eq(B.Shows(wall, { track = "buff" }), "buff", "a piece set to Buff only")
    T.eq(B.Shows(clap, { track = "cooldown" }), "cooldown")
    T.eq(B.Shows(clap, nil), AB.CdmOwn.Track(clap, nil), "Daylight UI's own answer")
    T.eq(type(B.Entry(clap)), "table", "a known spell's entry")
    T.isnil(B.Entry(123456789), "none for an unknown id")
    T.eq(B.SpellOf(clap), CLAP, "the spell a cooldown id casts")
    T.isnil(B.SpellOf("mainhand"), "a weapon enchant casts nothing")
    local ids = B.SpellIDs(clap)
    T.truthy(type(ids) == "table" and ids[CLAP], "the ids a cast of it starts its clock by")
    T.deq(ids, AB.CdmAuras.SpellIDs(clap), "Daylight UI's own answer")
    T.eq(B.ChainDefault("combat"), false)
    T.eq(B.ChainDefault("where"), "any")
    T.isnil(B.ChainDefault("nope"))
    noErrors()
end)

T.test("bridge reads: look keys, their fallbacks and the card's glow styles", function()
    local DUI, _, B, AB = world()
    local D = AB.CdmData
    local clap = CW.ID(CLAP, ESSENTIAL)
    local set = D.Ensure(1)
    D.AddPiece(set, clap, "icon", 0, 0)
    T.eq(B.LookDefault("low"), false, "the card's fallback")
    T.eq(B.LookDefault("lowAt"), AB.Cooldowns.LOW_AT)
    T.deq(B.LookDefault("lowColor"), AB.CdmCard.Fallback("lowColor"))
    T.eq(B.PieceLook(clap, "low"), false, "unset reads as the fallback")
    D.SetLook(set, clap, "low", true)
    T.eq(B.PieceLook(clap, "low"), true, "the piece's own")
    T.eq(B.PieceLook(clap, "cdNumbers"), AB.CdmCard.Fallback("cdNumbers"))
    local styles = B.GlowStyles()
    T.eq(styles[1].key, "ring", "Ring first, Daylight UI's default")
    local api = DUI.API.GlowStyles()
    T.eq(#styles, #api + 1, "then API.GlowStyles()")
    for i, st in ipairs(api) do
        T.eq(styles[i + 1].key, st.key); T.eq(styles[i + 1].label, st.label, "Daylight UI's own label")
    end
    noErrors()
end)

T.test("bridge reads: forms and the sound list", function()
    local _, _, B = world()
    T.eq(B.Forms().WARRIOR[1].key, "Battle", "the warrior's stances")
    local values, order, titles = B.SoundChoices()
    T.eq(order[1], "none", "None first")
    T.eq(values.none, "None")
    T.truthy(values["dui:quest"], "Daylight UI's own sounds")
    T.truthy(titles["head:punchy"], "with headings")
    noErrors()
end)

T.test("bridge reads: groups, names and CanTrack", function()
    local _, _, B, AB = world()
    local D = AB.CdmData
    local rend, clap, block = CW.ID(REND, ESSENTIAL), CW.ID(CLAP, ESSENTIAL), CW.ID(RAGE, 1)
    local set = D.Ensure(1)
    D.AddPiece(set, rend, "icon", 0, 0)
    D.AddPiece(set, clap, "icon", 0, 0)
    D.Hook(set, clap, rend, "right", "center")
    D.AddPiece(set, block, "icon", 0, 0)
    D.Hook(set, block, clap, "down", "start")
    T.eq(B.Root(block), rend, "the group's first piece")
    T.eq(B.Root(rend, 1), rend, "a first piece is its own root")
    T.eq(#B.Subtree(clap), 2, "Thunder Clap and what hangs off it")
    T.eq(B.SpellName(clap), "Thunder Clap", "the editor's name")
    T.truthy(B.CanTrack("s" .. RAGE), "a spell of Daylight UI's own picks what it shows")
    T.falsy(B.CanTrack("mainhand"), "a weapon enchant doesn't")
    T.falsy(B.CanTrack(clap), "nor a game piece")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Writes
-- ---------------------------------------------------------------------

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

local function saved(id) return DaylightUIDB.cdmProfiles[id] end

-- Places a piece on talent set g's saved layout with Daylight UI's own setter.
local function place(g, key, shape, x, y)
    local D = stub.actionbars.CdmData
    return D.AddPiece(D.Ensure(g), key, shape, x or 0, y or 0) ~= nil
end

T.test("bridge writes: pieces, hooks, options and group rules land in DaylightUIDB.cdmProfiles", function()
    local _, _, B, AB = world()
    local rend, clap, rage = CW.ID(REND, ESSENTIAL), CW.ID(CLAP, ESSENTIAL), CW.ID(RAGE, 1)
    T.isnil(B.ProfileOf(1), "no profile yet")
    local ok, why = B.SetSpellValue(1, rend, "readyGlow", true)
    T.falsy(ok); T.eq(why, "rejected", "Rend isn't placed")
    local id = B.ProfileOf(1)
    T.truthy(id, "the first write saved the layout as a profile")
    place(1, rend, "icon", 0, 0)
    place(1, clap, "icon", 0, 0)
    AB.CdmData.Hook(AB.CdmData.Get(1), clap, rend, "right", "center")
    place(1, rage, "bar", 10, -200)
    T.eq(B.SetSpellValue(1, rend, "readyGlow", true), true)
    T.eq(B.SetSpellValue(1, rend, "readySound", "dui:quest"), true)
    T.eq(B.SetSpellValue(1, rend, "glowStyle", "comet"), true)
    T.eq(B.SetSpellValue(1, rend, "track", "cooldown"), true, "a game piece's track word")
    T.eq(B.SetChainValue(1, clap, "combat", true), true, "a group rule set from a hooked piece")
    T.eq(B.SetLook(1, rend, "lowAt", 5), true, "a look key")
    T.eq(saved(id).set.pieces[rend].look.lowAt, 5, "saved: the piece's own look")
    place(1, "s99999999", "icon", 200, 0)
    T.eq(B.SetTrack(1, "s99999999", "aura"), true, "its track word")
    local p = saved(id).set.pieces
    T.eq(p[rend].readyGlow, true, "saved: readyGlow")
    T.eq(p[rend].readySound, "dui:quest", "saved: readySound")
    T.eq(p[rend].glowStyle, "comet", "saved: glowStyle")
    T.eq(p[rend].track, "cooldown", "saved: track")
    T.eq(p[clap].parent, rend, "the hook stays")
    T.eq(saved(id).set.chains[rend].combat, true, "saved: the group rule, on the group's first piece")
    T.isnil(saved(id).set.chains[clap], "and not on the hooked piece")
    T.eq(p["s99999999"].track, "aura")
    -- Daylight UI's refusals come back as "rejected".
    local function rejected(what, ok, why) T.falsy(ok, what); T.eq(why, "rejected", what) end
    rejected("a bar-only option on an icon", B.SetSpellValue(1, rend, "barMode", "solid"))
    rejected("an icon-only option on a bar", B.SetSpellValue(1, rage, "desat", "grey"))
    rejected("a bad value", B.SetSpellValue(1, rend, "onCd", "sometimes"))
    rejected("a piece not placed", B.SetSpellValue(1, 424242, "readyGlow", true))
    rejected("SetTrack on a game piece", B.SetTrack(1, rend, "aura"))
    rejected("a bad group value", B.SetChainValue(1, rend, "where", "space"))
    ok, why = B.SetSpellValue(3, rend, "readyGlow", true)
    T.falsy(ok); T.eq(why, "set", "talent set 3 doesn't exist")
    T.isnil(saved(id).set.pieces[rend].onCd, "nothing refused was written")
    noErrors()
end)

T.test("bridge writes: copy and assign leaves the old profile byte-identical", function()
    local _, _, B, AB = world()
    local rend = CW.ID(REND, ESSENTIAL)
    place(1, rend, "icon", 0, 0)
    B.SetSpellValue(1, rend, "readyGlow", true)
    local old = B.ProfileOf(1)
    local before = dump(saved(old))
    local new = B.CopyAndAssign(1, old, "EZ copy")
    T.truthy(new and new ~= old, "a new profile: " .. tostring(new))
    T.eq(B.ProfileOf(1), new, "talent set 1 uses the copy")
    T.eq(saved(new).name, "EZ copy")
    T.eq(saved(new).set.pieces[rend].readyGlow, true, "the copy holds the layout")
    T.eq(B.SetSpellValue(1, rend, "onCd", "fade"), true, "a write after the switch")
    place(1, CW.ID(CLAP, ESSENTIAL), "icon", 50, 0)
    T.eq(saved(new).set.pieces[rend].onCd, "fade", "lands in the copy")
    T.eq(dump(saved(old)), before, "the old profile is byte-identical")
    T.eq(#B.Profiles(), 2, "both profiles are listed")
    local ok, why = B.CopyAndAssign(1, "p404")
    T.falsy(ok); T.eq(why, "rejected", "no such profile")
    ok, why = B.CopyAndAssign(3, old)
    T.falsy(ok); T.eq(why, "set", "talent set 3 doesn't exist")
    -- A talent set with no profile gets the copy and no extra profile.
    T.isnil(B.ProfileOf(2))
    local copy2 = B.CopyAndAssign(2, old)
    T.eq(B.ProfileOf(2), copy2, "set 2 uses its copy")
    T.eq(#B.Profiles(), 3, "just the copy")
    T.eq(AB.CdmData.Use(1), new, "set 1 keeps its own")
    noErrors()
end)

T.test("bridge writes: Assign picks a profile for a talent set and changes no profile", function()
    local _, _, B = world()
    place(1, CW.ID(REND, ESSENTIAL), "icon", 0, 0)
    local first = B.ProfileOf(1)
    local second = B.NewAndAssign(1, "Second")
    local before = dump(DaylightUIDB.cdmProfiles)
    T.eq(B.Assign(1, first), true)
    T.eq(B.ProfileOf(1), first, "set 1 uses the first again")
    T.eq(B.Assign(2, second), true)
    T.eq(B.ProfileOf(2), second, "set 2 uses the second")
    T.eq(dump(DaylightUIDB.cdmProfiles), before, "no profile changed")
    local ok, why = B.Assign(1, "p404")
    T.falsy(ok); T.eq(why, "rejected", "no such profile")
    ok, why = B.Assign(0, first)
    T.falsy(ok); T.eq(why, "set")
    noErrors()
end)

T.test("bridge writes: new and assign picks an empty profile and leaves the old one byte-identical", function()
    local _, _, B = world()
    local rend = CW.ID(REND, ESSENTIAL)
    place(1, rend, "icon", 0, 0)
    B.SetSpellValue(1, rend, "readyGlow", true)
    local old = B.ProfileOf(1)
    local before = dump(saved(old))
    local new = B.NewAndAssign(1, "  EZ fresh ")
    T.truthy(new and new ~= old, "a new profile: " .. tostring(new))
    T.eq(B.ProfileOf(1), new, "talent set 1 uses it")
    T.eq(saved(new).name, "EZ fresh", "Daylight UI trims the name")
    T.eq(saved(new).class, "WARRIOR", "the player's class")
    T.isnil(next(saved(new).set.pieces), "no pieces")
    T.isnil(next(saved(new).set.chains), "no groups")
    place(1, CW.ID(CLAP, ESSENTIAL), "icon", 50, 0)
    T.eq(B.SetSpellValue(1, CW.ID(CLAP, ESSENTIAL), "readyGlow", true), true, "a write after the switch")
    T.truthy(saved(new).set.pieces[CW.ID(CLAP, ESSENTIAL)].readyGlow, "lands in the new profile")
    T.eq(dump(saved(old)), before, "the old profile is byte-identical")
    T.eq(saved(B.NewAndAssign(1, "EZ fresh")).name, "EZ fresh 2", "a taken name made unique")
    T.eq(#B.Profiles(), 3)
    local ok, why = B.NewAndAssign(3, "Nowhere")
    T.falsy(ok); T.eq(why, "set", "talent set 3 doesn't exist")
    stub.units.player.class = nil
    local count = #B.Profiles("WARRIOR")
    ok, why = B.NewAndAssign(1, "Classless")
    T.falsy(ok); T.eq(why, "unsaved", "the class isn't known yet")
    T.eq(#B.Profiles("WARRIOR"), count, "no profile made")
    noErrors()
end)

T.test("bridge writes: every write is refused in combat and while off", function()
    local _, _, B = world()
    local rend = CW.ID(REND, ESSENTIAL)
    place(1, rend, "icon", 0, 0)
    local before = dump(DaylightUIDB.cdmProfiles)
    stub.EnterCombat()
    local mine = B.ProfileOf(1)
    local calls = {
        SetSpellValue = function() return B.SetSpellValue(1, rend, "readyGlow", true) end,
        SetTrack = function() return B.SetTrack(1, "s1", "aura") end,
        SetChainValue = function() return B.SetChainValue(1, rend, "combat", true) end,
        SetLook = function() return B.SetLook(1, rend, "low", true) end,
        CopyAndAssign = function() return B.CopyAndAssign(1, mine, "In a fight") end,
        Assign = function() return B.Assign(2, mine) end,
        NewAndAssign = function() return B.NewAndAssign(1, "In a fight") end,
    }
    for name, fn in pairs(calls) do
        local ok, why = fn()
        T.falsy(ok, name .. " in combat")
        T.eq(why, "combat", name .. "'s reason")
    end
    T.eq(dump(DaylightUIDB.cdmProfiles), before, "nothing was written")
    stub.LeaveCombat()
    T.eq(B.SetSpellValue(1, rend, "readyGlow", true), true, "out of combat it writes")
    -- Switched off: the same refusal, by its own reason.
    B.NEEDS[#B.NEEDS + 1] = "ActionBars.CdmData.EZCDMGone"
    local ok, why = B.SetSpellValue(1, rend, "readyGlow", false)
    local newOk, newWhy = B.NewAndAssign(1, "While off")
    B.NEEDS[#B.NEEDS] = nil
    T.falsy(ok); T.eq(why, "off", "refused while an internal is missing")
    T.falsy(newOk); T.eq(newWhy, "off", "NewAndAssign too")
    noErrors()
end)

T.test("bridge writes: refused while Daylight UI's Cooldown Manager is off", function()
    local _, _, B = world({ off = true })
    local ok, why = B.SetSpellValue(1, CW.ID(REND, ESSENTIAL), "readyGlow", true)
    T.falsy(ok); T.eq(why, "off")
    T.isnil(next(DaylightUIDB.cdmProfiles or {}), "no profile was made")
    noErrors()
end)

T.test("bridge writes: with the class not known yet, nothing is saved", function()
    local _, _, B = world()
    stub.units.player.class = nil
    local ok, why = B.SetSpellValue(2, CW.ID(REND, ESSENTIAL), "readyGlow", true)
    T.falsy(ok); T.eq(why, "unsaved", "Daylight UI would keep a scratch set")
    T.isnil(next(DaylightUIDB.cdmProfiles or {}), "no profile was made")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Looks
-- ---------------------------------------------------------------------

T.test("bridge looks: Shell and CropIcon on a scratch frame", function()
    local DUI, _, B = world()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(36, 36)
    local tex = f:CreateTexture(nil, "ARTWORK")
    T.truthy(B.Shell(f, {}), "Daylight UI's shell")
    T.noerror(function() B.CropIcon(tex) end, "CropIcon")
    local l, r, t, b = tex:GetTexCoord()
    T.eq(l, DUI.Style.ICON_CROP[1], "the icon crop is Daylight UI's")
    T.eq(r, DUI.Style.ICON_CROP[2])
    noErrors()
end)

-- ---------------------------------------------------------------------
-- Window
-- ---------------------------------------------------------------------

T.test("bridge window: Daylight UI's window parts, remove button and spell icon", function()
    local DUI, _, B = world()
    local page = CreateFrame("Frame", nil, UIParent)
    page:SetSize(400, 300)
    local s = B.Stack(page, { bottom = 52 })
    T.truthy(s and s.scroll and s.bar, "a stack with its scroll frame and W.Scroll bar")
    s:Begin()
    local line = s:Line({ text = "Rend", dim = true })
    s:End()
    T.eq(stub.Text(line.name), "Rend", "a line")
    local r = B.RemoveButton(page)
    T.truthy(r and r.icon and r.bg, "the list's remove button")
    local rule = B.Rule(page)
    T.eq(rule:GetObjectType(), "Texture", "Daylight UI's divider line")
    T.eq(rule:GetHeight(), 1, "1 px")
    T.eq(B.Rule(page, true):GetWidth(), 1, "upright")
    T.eq(B.Gap(), DUI.Win.Parts.GAP, "the window parts' gap")
    T.eq(B.Edge(), DUI.Win.EDGE, "the kit's side margin")
    T.truthy(type(B.Gap()) == "number" and B.Gap() > 0)
    T.eq(B.SpellTexture(CW.ID(REND, ESSENTIAL)), DUI.Widgets and stub.actionbars.CdmEditor.SpellTexture(CW.ID(REND, ESSENTIAL)),
        "the editor's icon")
    noErrors()
end)

T.test("bridge window: PickColor opens the game's color picker the way Daylight UI does", function()
    local _, _, B = world()
    T.noerror(function() B.PickColor({ 1, 0, 0 }, function() end) end, "no picker in the bare fake game")
    local info
    local keep = rawget(_G, "ColorPickerFrame")
    _G.ColorPickerFrame = { SetupColorPickerAndShow = function(_, t) info = t end,
        GetColorRGB = function() return 0, 1, 0 end, HookScript = function() end }
    local got
    local ok, err = pcall(function()
        B.PickColor({ 1, 0, 0 }, function(c) got = c end)
        T.eq(info.r, 1, "it starts at the color given"); T.eq(info.g, 0)
        info.swatchFunc()
        T.deq(got, { 0, 1, 0 }, "a pick comes back as { r, g, b }")
        info.cancelFunc()
        T.deq(got, { 1, 0, 0 }, "Cancel gives the start color back")
    end)
    _G.ColorPickerFrame = keep
    assert(ok, err)
    noErrors()
end)

T.test("bridge looks: Daylight UI's link, chip and the setup guide's choice cards", function()
    local DUI, _, B = world()
    local page = CreateFrame("Frame", nil, UIParent)
    page:SetSize(400, 300)
    local link = B.Link(page, "body", true)
    T.truthy(link and link.SetLabel and link.line, "W.Link, with its underline")
    link.SetLabel("it's ready")
    T.eq(link:GetWidth(), link.text:GetStringWidth(), "sized to its word")
    local _, size = link.text:GetFont()
    T.eq(size, DUI.Style.SIZE.body, "at the body size")
    T.truthy(B.Link(page, "small").SetLabel, "a plain link")
    local chip = B.Chip(page, "glow")
    T.truthy(chip and chip.SetOn and chip.FitWidth, "W.Chip")
    chip.SetOn(true)
    T.truthy(chip.on, "on")
    local picked
    local picker = B.Picker(page, { keys = { "a", "b" }, width = 300, cols = 2, height = 84,
        label = function(k) return "Card " .. k end, sub = function(k) return "Sub " .. k end,
        get = function() return picked end, set = function(k) picked = k end })
    T.truthy(picker.cards.a and picker.cards.b, "a card per key")
    T.eq(picker.height, 84)
    picker.cards.b:Click()
    T.eq(picked, "b", "a click picks")
    T.truthy(picker.cards.b.selected, "and ticks it")
    noErrors()
end)

T.test("bridge editor: Open, its reads and Changed pass Daylight UI's editor through", function()
    local DUI, _, B, AB = world()
    local Ed = AB.CdmEditor
    local rend = CW.ID(REND, ESSENTIAL)
    place(1, rend, "icon", 0, 0)
    T.falsy(B.EditorOpen(), "shut")
    T.isnil(B.EditorTray(), "nothing built yet")
    T.eq(B.OpenEditor(), true, "opens")
    T.truthy(Ed.IsOpen() and B.EditorOpen())
    T.eq(B.EditorTray(), Ed.Tray(), "the tray")
    T.eq(B.EditorOverlay(), Ed.Overlay(), "the overlay")
    T.eq(B.EditorTop(), AB.CdmCard.TOP, "the room kept at the top")
    T.isnil(B.Selected())
    Ed.Select(rend)
    T.eq(B.Selected(), rend, "the pick")
    T.falsy(B.EditorAttach())
    Ed.SetAttach(rend, "right")
    T.truthy(B.EditorAttach(), "a + waits")
    Ed.SetAttach(nil)
    local drawn, keep = 0, Ed.Draw
    Ed.Draw = function(...) drawn = drawn + 1; return keep(...) end
    B.EditorChanged()
    Ed.Draw = keep
    T.eq(drawn, 1, "Changed redraws the editor")
    T.eq(B.OpenEditor(2), true, "an open editor shows another talent set")
    T.eq(AB.CdmData.CurrentIndex(), 2)
    Ed.Close()
    stub.EnterCombat()
    T.eq(B.OpenEditor(), false, "Daylight UI refuses in combat")
    stub.LeaveCombat()
    noErrors()
end)

T.test("bridge editor: HookEditor hooks the listed functions through Daylight UI's public hook", function()
    local DUI, ns, B, AB = world()
    local Ed = AB.CdmEditor
    for name in pairs(B.EDITOR_HOOKS) do
        local found = false
        for _, path in ipairs(B.NEEDS) do found = found or path == "ActionBars.CdmEditor." .. name end
        T.truthy(found, name .. " is in NEEDS")
    end
    local calls, used = {}, 0
    local keepFor = DUI.API.For
    DUI.API.For = function(...) used = used + 1; return keepFor(...) end
    T.truthy(B.HookEditor("EndTrayMove", function() calls[#calls + 1] = "end" end), "a handle")
    DUI.API.For = keepFor
    T.truthy(used <= 1, "API.For, the public way in")
    Ed.EndTrayMove()
    T.deq(calls, { "end" }, "runs after Daylight UI's own")
    T.falsy(B.HookEditor("Remove", function() end), "an unlisted function is refused")
    T.falsy(B.HookEditor("Open", nil), "no function, no hook")
    noErrors()
end)

-- ---------------------------------------------------------------------
-- The internals list
-- ---------------------------------------------------------------------

-- ---------------------------------------------------------------------
-- The fold tab and its slide
-- ---------------------------------------------------------------------

T.test("bridge: the up glow's internals (Effects): who draws a piece, restrictions, the ring", function()
    local _, _, B, AB = world()
    local D = AB.CdmData
    local set = D.Ensure(1)
    local shout = CW.ID(SHOUT, 2)
    D.AddPiece(set, shout, "icon", 0, 0)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    T.truthy(B.DrawnBy(shout) ~= nil, "placed and drawn")
    T.eq(B.DrawnBy(shout), AB.CdmRows.DrawnBy(shout), "Daylight UI's own answer")
    T.isnil(B.DrawnBy(999999), "nothing for a piece not placed")
    T.falsy(B.Restricted())
    local ran = 0
    B.AfterRestrictions(function() ran = ran + 1 end, "test")
    T.eq(ran, 1, "runs at once out of restrictions")
    stub.EnterCombat()
    T.truthy(B.Restricted(), "in combat")
    B.AfterRestrictions(function() ran = ran + 1 end, "test")
    B.AfterRestrictions(function() ran = ran + 10 end, "test")
    T.eq(ran, 1, "waits")
    stub.LeaveCombat(); stub.RunTimers()
    T.eq(ran, 11, "once after, the later call with the same key in place")
    local art = B.RingArt()
    T.truthy(art, "Daylight UI's ring art and measures")
    T.eq(art.atlas, AB.CdmEffects.GLOW_ATLAS)
    T.eq(art.loop, AB.CdmEffects.GLOW_LOOP)
    local tex = CreateFrame("Frame", nil, UIParent):CreateTexture()
    B.PaintAccent(tex)
    T.truthy(tex.__vertex ~= nil or tex.__gradient ~= nil, "painted in the accent")
    noErrors()
end)

T.test("bridge: the recast clock's internals (Effects): the wraps, the fields read, the sound", function()
    local DUI, _, B, AB = world()
    for name, path in pairs(B.CLOCK_WRAPS) do
        local found = false
        for _, p in ipairs(B.NEEDS) do found = found or p == path .. "." .. name end
        T.truthy(found, name .. " is in NEEDS")
    end
    local used, keepFor = 0, DUI.API.For
    DUI.API.For = function(...) used = used + 1; return keepFor(...) end
    local asked = {}
    T.truthy(B.WrapClock("ClipDue", function(orig, h, sid)
        asked[#asked + 1] = h
        return orig(h, sid)
    end), "a handle")
    DUI.API.For = keepFor
    T.truthy(used <= 1, "API.For, the public way in")
    T.falsy(B.WrapClock("ClipPass", function() end), "an unlisted function is refused")
    T.falsy(B.WrapClock("Clip", nil), "no function, no wrap")
    -- Rend with Daylight UI's recast glow: your cast starts its watch's clock.
    local D = AB.CdmData
    local set = D.Ensure(1)
    local rend = CW.ID(REND, 0)
    D.AddPiece(set, rend, "icon", 0, 0)
    T.truthy(D.SetSpellValue(set, rend, "clipGlow", true))
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    stub.EnterCombat(); stub.RunTimers()
    stub.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", REND)
    CW.Aura("target", REND, { harmful = true, duration = 9 }); stub.RunTimers()
    local w = AB.CdmAuras.Watch(rend)
    T.eq(w.id, rend, "h.id is the piece key")
    T.eq(type(w.endsAt), "number", "h.endsAt is the clock's end")
    T.falsy(issecretvalue(w.endsAt), "plain in a fight")
    T.truthy(math.abs(w.endsAt - (GetTime() + 9)) < 0.01, "9 s from your cast")
    T.truthy(#asked > 0 and asked[#asked] == w, "the wrap sees the watch")
    T.truthy(AB.CdmEffects.ClipGlows(set.pieces[rend]), "ClipGlows takes the saved piece")
    stub.LeaveCombat()
    -- The sound, as Daylight UI plays its own.
    local got
    local keepAlert = DUI.Sound.Alert
    DUI.Sound.Alert = function(k) got = k end
    B.PlayAlert("dui:done")
    DUI.Sound.Alert = keepAlert
    T.eq(got, "dui:done", "Sound.Alert")
    noErrors()
end)

T.test("bridge: the glow style's internals (Effects): the wraps and what they are handed", function()
    local DUI, _, B, AB = world()
    for name, path in pairs(B.GLOW_WRAPS) do
        local found = false
        for _, p in ipairs(B.NEEDS) do found = found or p == path .. "." .. name end
        T.truthy(found, name .. " is in NEEDS")
    end
    local used, keepFor = 0, DUI.API.For
    DUI.API.For = function(...) used = used + 1; return keepFor(...) end
    local downs, passes, styles = {}, 0, {}
    T.truthy(B.WrapGlow("SetDown", function(orig, item, piece, isDown, isDue)
        downs[#downs + 1] = { item = item, piece = piece }
        return orig(item, piece, isDown, isDue)
    end), "a handle")
    T.truthy(B.WrapGlow("EndPass", function(orig, told)
        passes = passes + 1
        return orig(told)
    end))
    T.truthy(B.WrapGlow("GlowStyle", function(orig, button)
        styles[#styles + 1] = button
        return orig(button)
    end))
    DUI.API.For = keepFor
    T.truthy(used <= 1, "API.For, the public way in")
    T.falsy(B.WrapGlow("ClipDue", function() end), "a clock function is not a glow one")
    T.falsy(B.WrapGlow("SetGlow", function() end), "an unlisted function is refused")
    -- Rend with Daylight UI's ready glow: a pass tells it, and its glow lights.
    local D = AB.CdmData
    local set = D.Ensure(1)
    local rend = CW.ID(REND, 0)
    D.AddPiece(set, rend, "icon", 0, 0)
    T.truthy(D.SetSpellValue(set, rend, "readyGlow", true))
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    local seen
    for _, d in ipairs(downs) do
        if d.piece == D.Get(1).pieces[rend] then seen = d end
    end
    T.truthy(seen, "SetDown gets the saved piece table")
    T.eq(seen.item, CW.Item(rend), "and the item the game draws")
    T.truthy(passes > 0, "EndPass after the pass")
    T.truthy(AB.CdmEffects.GlowShown(CW.Item(rend)), "the ready glow lit")
    T.eq(styles[#styles], D.Get(1).pieces[rend], "GlowStyle gets the same saved table")
    noErrors()
end)

T.test("bridge: an aura's length (Effects): the holder's read and the game's data", function()
    local _, _, B, AB = world()
    local D = AB.CdmData
    local set = D.Ensure(1)
    local shout = CW.ID(SHOUT, 2)
    D.AddPiece(set, shout, "icon", 0, 0)
    D.Changed(); AB.CdmRows.Refresh(); stub.RunTimers()
    local h = AB.CdmAuras.Frame(shout)
    T.truthy(h, "Daylight UI's aura icon holder")
    -- The game's data: Battle Shout lasts as CdmSpells.FACTS says.
    local fact = AB.CdmCustom.Fact(SHOUT)
    T.truthy(fact and fact.lasts, "FACTS has a length for Battle Shout")
    T.eq(B.FactLasts(shout), fact.lasts, "through CdmCustom.Fact")
    T.isnil(B.FactLasts(CW.ID(999999, 0)), "nothing for a spell the data doesn't cover")
    -- The holder's read: nothing until it reads the aura up.
    T.isnil(B.AuraLasts(shout))
    T.isnil(B.AuraLasts(CW.ID(REND, 0)), "no holder, nothing")
    local id = next(h.ids)
    CW.Aura("player", id, { duration = 120 }); stub.RunTimers()
    T.eq(AB.CdmAuras.Read(h), true, "Daylight UI's own read: up")
    T.eq(B.AuraLasts(shout), 120, "the length it learned (h.auraLasts)")
    T.falsy(issecretvalue(h.auraLasts))
    noErrors()
end)

T.test("bridge: the info panel's fold tab, with the panel loaded", function()
    local DUI, _, B = world({ panel = true })
    T.eq(#B.MissingOptional(), 0, "every OPTIONAL entry resolves")
    T.truthy(B.Ready())
    local Panel = stub.infopanel.Panel
    local f = B.FoldTab()
    T.truthy(f, "the fold tab's measures")
    T.eq(f.tab, Panel.TAB); T.eq(f.arrow, Panel.ARROW); T.eq(f.color, Panel.ARROW_COLOR)
    T.eq(f.slide, Panel.SLIDE); T.eq(f.border, Panel.XP_BORDER)
    T.eq(B.Resolve("InfoPanel.Panel.TAB"), DUI:GetModule("InfoPanel").ns.Panel.TAB, "through the module's ns")
    noErrors()
end)

T.test("bridge: without the info panel, FoldTab is nil and EZ-CDM stays on", function()
    local _, _, B = world()
    T.eq(#B.MissingOptional(), #B.OPTIONAL - 1, "every info panel entry is missing; the copy box is in the core")
    T.truthy(B.CanShowText())
    T.isnil(B.FoldTab())
    T.truthy(B.Ready(), "on")
    T.eq(#ourLines(), 0, "no chat line")
    noErrors()
end)

T.test("bridge: Daylight UI's slider and a shell's border", function()
    local DUI, _, B = world()
    local seen = {}
    local s = B.Slider(function(sl) seen[#seen + 1] = sl.p end, { dur = 0.3, p = 0 })
    T.truthy(s and s.driver, "Motion.Slider")
    T.eq(getmetatable(s), getmetatable(DUI.Motion.Slider(function() end)))
    T.eq(s.p, 0); T.eq(s.dur, 0.3)
    s:To(1)
    stub.RunOnUpdate(s.driver, 0.15)
    T.truthy(s.p > 0 and s.p < 1, "half way")
    stub.RunOnUpdate(s.driver, 1)
    T.eq(s.p, 1)
    T.truthy(#seen >= 2, "apply ran each step")
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(40, 40)
    B.Shell(f, {})
    local px = B.BorderPx(f)
    T.eq(px, DUI.Pixel.Px(f, DUI.Style.BorderPx(f)), "the info panel's tuck: Pixel.Px of Style.BorderPx")
    T.truthy(px > 0)
    noErrors()
end)

-- The list of Daylight UI internals EZ-CDM calls is the private project's
-- (docs/reference/daylight-internals.md, beside the addon folder). These two checks
-- run where it is found.
local DOC = "docs/reference/daylight-internals.md"
local docTest = require("ez_harness").exists(DOC) and T.test or function() end

-- The Internals table's rows: { path, file, line }.
local function docRows()
    local rows = {}
    for line in io.lines(DOC) do
        local path, file, at = line:match("^| `([%w_%.]+)` |.*| ([%w_/%.]+%.lua):(%d+) |%s*$")
        if path then rows[#rows + 1] = { path = path, file = file, line = tonumber(at) } end
    end
    return rows
end

docTest("bridge: daylight-internals.md matches Bridge.NEEDS, then Bridge.OPTIONAL, row for row", function()
    local _, _, B = world()
    local rows = docRows()
    T.truthy(#rows > 0, "the table is found in " .. DOC)
    local doc, want = {}, {}
    for i, r in ipairs(rows) do doc[i] = r.path end
    for _, path in ipairs(B.NEEDS) do want[#want + 1] = path end
    for _, path in ipairs(B.OPTIONAL) do want[#want + 1] = path end
    T.eq(table.concat(doc, "\n"), table.concat(want, "\n"), "the doc's rows are NEEDS, then OPTIONAL, in order")
end)

docTest("bridge: each internal's file:line in the list names it in Daylight UI", function()
    local bad = {}
    for _, r in ipairs(docRows()) do
        local name = r.path:match("([^%.]+)$")
        local n, text = 0, nil
        local fh = io.open(stub.DUI_ROOT .. r.file)
        if fh then
            for l in fh:lines() do
                n = n + 1
                if n == r.line then text = l; break end
            end
            fh:close()
        end
        if not (text and text:find(name, 1, true)) then
            bad[#bad + 1] = string.format("%s: %s:%d reads %q", r.path, r.file, r.line, tostring(text))
        end
    end
    T.eq(table.concat(bad, "\n  "), "", "every row points at its definition (re-check after a Daylight UI update)")
end)
