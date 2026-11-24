local addonName = ...

-- EZ-CDM's section under /dui's Plugins, with Daylight UI's own Cooldown Manager icon.
-- Its page is the module Settings.lua registers.
DaylightUI:RegisterPlugin(addonName, {
    needs = { 1, 14 },
    icon = DaylightUI.API.Media("ui-section-cooldowns.png"), -- look-ok: Daylight UI's CDM section icon, by API.Media
    short = "EZ-CDM",
    blurb = "Set up the Cooldown Manager in plain sentences.",
})
