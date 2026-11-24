-- Reviewed exceptions for the guard checks (tests/test_guards.lua, which runs Daylight
-- UI's own guard file against EZ-CDM's shipped files). Each entry needs a reason a
-- reviewer can check. Paths are as EZ-CDM's .toc test sees them.
--
--   hooks       "file|object|Method"   a hook on a game object's method
--   setscript   "file|Name"            SetScript on a global frame name
--   pcalls      file -> count          bare pcalls a file still has; never raise one
--   itemTips    file -> reason         an item tooltip that skips Parts.ItemTip
--   rules       "file|rule-id"         a line a guard rule bans
--   media       name -> reason         a Media name Daylight UI doesn't ship

-- EZ-CDM's own frames (EZCDM*) may set their scripts by global name.
local setscript = setmetatable({}, { __index = function(_, key)
    local name = type(key) == "string" and key:match("|([%w_]+)$")
    return name ~= nil and name:find("^EZCDM") ~= nil or nil
end })

return {
    hooks = {},
    setscript = setscript,
    pcalls = {},
    itemTips = {},
    rules = {},
    media = {},
}
