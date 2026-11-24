local addonName, ns = ...

DaylightUI:RegisterPlugin(addonName, { needs = { 1, 14 } })

-- The module EZ-CDM's options rows hang on (Settings.lua). No pages of its own.
DaylightUI:RegisterModule(addonName, { plugin = addonName, label = "EZ-CDM", defaults = {} })
