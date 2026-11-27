local stub = require("stub")
local H = require("ez_harness")

-- Daylight UI's hygiene checks (its tests/test_hygiene.lua, loaded from the
-- checkout), run on EZ-CDM's shipped files: no temporary code, no accidental
-- globals, US spelling, and the look rules (no hand-built close X, text box, scroll
-- bar or font file, no game control template or menu, no neutral gray text, no
-- typed-in text colors, no fixed Daylight colors). Every allow list starts empty, so
-- an exception needs a reviewed reason here. Its checks of Daylight UI's own layout,
-- locale and docs are left out; the ones below take their place for EZ-CDM.

local ALLOW_LISTS = { "CLOSE_ART_OK", "EDITBOX_OK", "SCROLL_OK", "FONT_FILE_OK", "GLOBALS_OK", "GRAY_OK",
                      "TEXT_COLOR_OK", "DAYLIGHT_OK", "DAYLIGHT_PENDING" }

local L = H.daylightChecks("test_hygiene", {
    skip = {
        "hygiene: the shipped list is found (the check above isn't empty)",
        "hygiene: the tests load every shipped file, in the .toc's order",
        "hygiene: our own text goes through L (core, Character, and modules done)",
        "hygiene: no British spelling in shipped comments or the docs",
    },
    rename = {
        ["hygiene: no temporary or debug code in a shipped file (use DaylightUI_Dev/)"] =
            "hygiene: no temporary or debug code in a shipped file",
    },
    fit = function(L)
        -- Shipped means what EZ-CDM's .toc lists.
        L.set("shippedTocs", function() return { stub.PLUGIN_TOC } end)
        for _, name in ipairs(ALLOW_LISTS) do H.empty(L.get(name)) end
        -- EZ-CDM's own globals.
        L.set("ourName", function(name)
            return name:find("^EZCDM") or name:find("^SLASH_EZCDM") or name:find("^BINDING_[%u_]*EZCDM")
        end)
    end,
})

local shippedFiles, read, MARKERS, britishIn = L.get("shippedFiles"), L.get("read"), L.get("MARKERS"), L.get("britishIn")

T.test("hygiene: the shipped list is found (the checks above aren't empty)", function()
    local files, set = shippedFiles(), {}
    for i = 1, #files do
        set[files[i]] = true
        T.truthy(read(files[i]), "a listed file is on disk: " .. files[i])
    end
    T.truthy(#files > 0, "found " .. #files .. " shipped files")
    local dir = stub.PLUGIN_TOC:match("^(.*/)") or ""
    T.truthy(set[dir .. "EZ-CDM.lua"], "EZ-CDM.lua is in the shipped list")
end)

T.test("hygiene: the allow lists start empty and the own-name rule is EZ-CDM's", function()
    for _, name in ipairs(ALLOW_LISTS) do T.eq(next(L.get(name)), nil, name .. " is empty") end
    local ourName = L.get("ourName")
    T.truthy(ourName("EZCDMDB"), "EZCDMDB")
    T.truthy(ourName("SLASH_EZCDM1"), "SLASH_EZCDM1")
    T.falsy(ourName("DaylightUIDB"), "Daylight UI's own global")
end)

T.test("hygiene: the marker check finds a marker", function()
    local function marked(line)
        for _, m in ipairs(MARKERS) do if line:find(m) then return true end end
        return false
    end
    T.truthy(marked("local a = 1 -- TEMP"), "-- TEMP")
    T.truthy(marked("-- TEMPORARY probe"), "TEMPORARY")
    T.falsy(marked("local TEMPO = 2"), "a word that starts the same")
    T.falsy(marked("-- template"), "template")
end)

-- A shipped file the tests never load is never tested, and another order can hide
-- a load-order bug. Load EZ-CDM as the tests do and compare what loaded with its
-- .toc. The fake game loads no Libs/ and no XML.
T.test("hygiene: EZ-CDM's tests load each shipped file in .toc order", function()
    local seen, original = {}, loadfile
    rawset(_G, "loadfile", function(file, ...)
        if type(file) == "string" and H.IsPluginFile(file) then seen[#seen + 1] = file end
        return original(file, ...)
    end)
    stub.ForgetCompiled()
    local fine, problem = pcall(stub.LoadPlugin)
    rawset(_G, "loadfile", original)
    stub.ForgetCompiled()
    assert(fine, problem)
    local dir = stub.PLUGIN_TOC:match("^(.*/)") or ""
    local _, files = stub.ReadToc(stub.PLUGIN_TOC)
    local want = {}
    for _, f in ipairs(files) do
        if not f:find("^Libs/") then want[#want + 1] = dir .. f end
    end
    T.truthy(#want > 0, stub.PLUGIN_TOC .. " lists files")
    T.eq(table.concat(seen, "\n"), table.concat(want, "\n"), "the files the tests load, in the .toc's order (see stub.LoadPlugin)")
end)

-- US spelling in comments and in this repo's own docs (text in `backticks` and in
-- fenced code is code, so it's skipped).
local DOCS = { "README.md", "CONTRIBUTING.md", "CHANGELOG.md", "AGENTS.md" }

T.test("hygiene: no British spelling in shipped comments or this repo's docs", function()
    local bad = {}
    local function eachLine(path)
        return ((read(path) or "") .. "\n"):gmatch("(.-)\n")
    end
    local files = shippedFiles()
    for i = 1, #files do
        local n = 0
        for line in eachLine(files[i]) do
            n = n + 1
            local comment = line:match("%-%-(.*)$")
            local word = comment and britishIn(comment)
            if word then bad[#bad + 1] = ("%s:%d: %s"):format(files[i], n, word) end
        end
    end
    for _, name in ipairs(DOCS) do
        local path, n, inCode = H.ROOT .. name, 0, false
        for line in eachLine(path) do
            n = n + 1
            if line:find("^%s*```") then
                inCode = not inCode
            elseif not inCode then
                local word = britishIn(line)
                if word then bad[#bad + 1] = ("%s:%d: %s"):format(path, n, word) end
            end
        end
    end
    T.eq(table.concat(bad, "\n"), "", "US spelling, please (color, gray)")
end)

-- The packager uploads CHANGELOG.md whole as each release's notes, so it holds one
-- version: the one the toc names.
T.test("hygiene: the changelog holds only the toc's version", function()
    local text = read("CHANGELOG.md") or ""
    local heads = {}
    for v in text:gmatch("%f[^\n%z]# EZ%-CDM ([^\n]+)") do heads[#heads + 1] = v end
    local toc = (read("EZ-CDM.toc") or ""):match("## Version: ([^\r\n]+)")
    T.eq(#heads, 1, "one version heading: " .. table.concat(heads, ", "))
    T.eq(heads[1], toc, "the toc's version")
end)
