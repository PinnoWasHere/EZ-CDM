local stub = require("stub")   -- T (test helpers) is a global set by tests/run.lua
local N = require("noplay")

-- No game actions (tests/noplay.lua): EZ-CDM never casts, targets, uses an item,
-- moves, chats or binds keys for the player, in any file its .toc loads.

local function report(bad)
    local out = {}
    for p, names in pairs(bad) do out[#out + 1] = p .. ": " .. table.concat(names, ", ") end
    table.sort(out)
    return table.concat(out, "; ")
end

T.test("noplay: every shipped file is free of calls that play the game", function()
    local files = N.TocFiles(stub.PLUGIN_TOC)
    T.truthy(#files >= 10, "found " .. #files .. " shipped files")
    local bad = N.Check(files)
    T.eq(next(bad), nil, report(bad))
end)

T.test("noplay: the scan finds a banned call and skips comments and longer names", function()
    T.eq(table.concat(N.Scan('CastSpellByName("Fireball")'), ","), "CastSpellByName (line 1)")
    T.eq(table.concat(N.Scan("x = 1\nC_ChatInfo.SendChatMessage(m)"), ","), "SendChatMessage (line 2)")
    T.eq(#N.Scan("-- CastSpellByName is never called"), 0, "a comment")
    T.eq(#N.Scan("--[[ UseAction(1) ]] local y"), 0, "a block comment")
    T.eq(#N.Scan("local IsUseActionX = 1"), 0, "part of a longer name")
end)
