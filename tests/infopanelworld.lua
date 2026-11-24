-- The game pieces Daylight UI's info panel needs to log in: Daylight UI's own info
-- panel world (its tests' panelworld.lua) without the parts the CDM world sets for
-- itself (the tooltip, C_Spell, UnitGUID). Call IPW.Install() in stub.LoadPlugin's
-- before, with infopanel = true.
local IPW = {}

local KEEP = { "GameTooltip", "C_Spell", "UnitGUID" }

function IPW.Install()
    local kept = {}
    for _, name in ipairs(KEEP) do kept[name] = rawget(_G, name) end
    require("panelworld").world()
    for _, name in ipairs(KEEP) do _G[name] = kept[name] end
end

return IPW
