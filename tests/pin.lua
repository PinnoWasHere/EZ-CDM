-- The Daylight UI release the suite runs against. Its test harness loads from a
-- checkout at this tag (tests/ez_harness.lua). CI clones the tag; locally, point
-- DUI_ROOT at a checkout or clone it into .daylight/DaylightUI.
return {
    tag = "v2.2.7",
    version = "2.2.7",
    commit = "08dc459",
    repo = "https://github.com/dayightt/DaylightUI",
}
