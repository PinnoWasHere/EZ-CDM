local R = require("repro_world")

-- A bug report rebuilt in the class world (tools/repro.py --make-test shaman_stormstrike_225).
-- SHAMAN, EZ-CDM 0.1.0, Daylight UI 2.2.5, script proc, spell 1223031.
--
-- Daylight UI 2.2.5 puts a placed buff hidden by hand back in the game's buff row
-- (CdmSwitch.Placed), so the game's item draws Improved Stormstrike, not Daylight
-- UI's aura holder. That item finds an aura only by its own and linked spell
-- (1223031); the proc lands as 1238931, so the item never shows. EXPECT keeps that
-- Daylight UI bug (docs/reference/dui-prs/placed-buff-unseen-proc.md) and changes
-- when Daylight UI fixes it.
--
-- EZ-CDM's part: its up glow ring needs a client aura button. While the game's item
-- draws the piece, the rule lights Daylight UI's own upGlow in its color
-- (Effects.MoveBack), so the glow never waits on a drawer that is gone.

local REPORT = "EZCDM1:e1MzOmFwaVtOMTtOMTQ7XVM2OmNoYWluc3t9UzU6Y2xhc3NTNjpTSEFNQU5TMzpkdWlTNToyLjIuNVMyOmV6UzU6MC4xLjBTNDpnYW1lW1M2OjEuNjAuMVM1OjcxMDM3TjE2MDAxO11TNjpoaWRkZW57fVM1Omtub3duW04zMjQ7TjMyNTtOOTA1O045NDU7TjI2NDU7TjgwNTA7TjgwNTI7TjgwNTM7TjgxMzQ7Ti0xMDQzMTtOLTEwNDMyO04xMDQ0NztOLTEwNDQ4O04xNzM2NDtOLTI5MjI4O04tNDEwMTU2O040MzcwMDk7TjEyMjMwMzE7Ti0xMjM4NjQwO04tMTIzODkzMTtdUzc6cGFzc2l2ZVtOMTIyMzAzMTtdUzY6cGllY2Vze04yMDAyNjQ7e1M1OnNoYXBlUzQ6aWNvbn1OMjAwMzExO3tTODpjbGlwR2xvd1RTMTM6Y2xpcEdsb3dDb2xvcltOMDtOMC43MzcyNTQ5MTc2MjE2MTI1NTtOMC44MDM5MjE1ODAzMTQ2MzYyMztdUzU6c2hhcGVTNDppY29ufU4yMDAzMTU7e1MxNDpyZWFkeUdsb3dDb2xvcltOMTtOMC42NTg4MjM1NDk3NDc0NjcwNDtOMC4wNTg4MjM1Mjk2MzA4OTk0Mjk7XVM1OnNoYXBlUzQ6aWNvblM1OnRyYWNrUzQ6Ym90aH1OMjAwMzIwO3tTNTpzaGFwZVM0Omljb259TjIwMDMyNDt7Uzg6Y2xpcEdsb3dUUzEzOmNsaXBHbG93Q29sb3JbTjE7TjAuMDc0NTA5ODA2OTMxMDE4ODI5O04wO11TNDpsb29re1MxMDpjb3VudENvbG9yW04xO04xO04xO119UzE0OnJlYWR5R2xvd0NvbG9yW04wLjgwMzkyMTU4MDMxNDYzNjIzO04wLjA5MDE5NjA4MDUwNTg0NzkzMTtOMC41NzI1NDkwNDUwODU5MDY5ODtdUzU6c2hhcGVTNDppY29ufU4yMDA1MDE7e1M1OnNoYXBlUzQ6aWNvbn1TODptYWluaGFuZHtTNTpzaGFwZVM0Omljb25TNjp1cEdsb3dUUzExOnVwR2xvd0NvbG9yW04wO04xO04wLjA1MDk4MDM5Mjg0MzQ4NDg3OTtdfX1TNTpydWxlc3tTMTA6Y29uZGl0aW9uc3tOMjAwMzE1O3tTODpjYW50Q2FzdHtTNDpncmF5VH19TjIwMDUwMTt7UzY6bm9NYW5he1M0OmJsdWVUfX19Uzc6ZmFsbE9mZntOMjAwMzExO3tTNDpsZWFkTjEwO1M1OnNvdW5kUzEwOmtpdDozMTY0ODJ9TjIwMDMyNDt7UzQ6bGVhZE41O1M1OnNvdW5kUzEwOmtpdDozMTY0Nzd9fVM5Omdsb3dTdHlsZXtOMjAwMzI0O3tTNjpyZWNhc3RTNTpjb21ldH1TODptYWluaGFuZHtTMjp1cFM3OnR3aW5rbGV9fVM2OnVwR2xvd3tOMjAwMzIwO1tOMDtOMC4wNTQ5MDE5NjEyMzcxOTIxNDc7TjAuODAzOTIxNTgwMzE0NjM2MjM7XX19UzM6c2V0TjE7UzQ6c3BlY04xO1M2OnNwZWxsc3tOMjAwMjY0O3tTNTpkcmF3blM0OmdhbWVTMjppZE4yNjQ1O1MzOmlkc1tOMjY0NTtOMTIzODY0MDtdUzU6c2hvd3NTNDpidWZmfU4yMDAzMTE7e1M1OmRyYXduUzQ6Z2FtZVMyOmlkTjgxMzQ7UzM6aWRzW04zMjQ7TjMyNTtOOTA1O045NDU7TjgxMzQ7TjEwNDMxO04xMDQzMjtdUzU6c2hvd3NTNDpidWZmfU4yMDAzMTU7e1M1OmRyYXduUzIyOmF1cmEgYW5kIGNvb2xkb3duIGljb25TMjppZE4xNzM2NDtTMzppZHNbTjE3MzY0O040MTAxNTY7XVM1OnNob3dzUzQ6Ym90aH1OMjAwMzIwO3tTNTpkcmF3blM0OmdhbWVTMjppZE4xMjIzMDMxO1MzOmlkc1tOMTIyMzAzMTtOMTIzODkzMTtdUzU6c2hvd3NTNDpidWZmfU4yMDAzMjQ7e1M1OmRyYXduUzQ6Z2FtZVMyOmlkTjEwNDQ3O1MzOmlkc1tOODA1MDtOODA1MjtOODA1MztOMTA0NDc7TjEwNDQ4O04yOTIyODtdUzU6c2hvd3NTNDpib3RofU4yMDA1MDE7e1M1OmRyYXduUzQ6Z2FtZVMyOmlkTjQzNzAwOTtTMzppZHNbTjQzNzAwOTtdfVM4Om1haW5oYW5ke1M2OmN1c3RvbVRTNTpkcmF3blM5OmF1cmEgaWNvblMzOmlkc3t9fX1TMTp2TjE7fQ=="

local EXPECT = [[
 1 idle
     Improved Stormst hidden no state
 2 proc up
     Improved Stormst hidden no state
 3 proc down
     Improved Stormst hidden no state
 4 enter combat
     Improved Stormst hidden no state
 5 proc up
     Improved Stormst hidden no state
 6 wait 4 s
     Improved Stormst hidden no state
 7 proc down
     Improved Stormst hidden no state
 8 leave combat
     Improved Stormst hidden no state
]]

-- The same run with an aura the game's item sees: Daylight UI's up glow lights.
local EXPECT_SEEN = [[
 1 idle
     Improved Stormst hidden no state
 2 proc up
     Improved Stormst shown a=1.00 ready=- cd=- usable=- noPower=- proc=n up=y glow=y(up)
 3 proc down
     Improved Stormst hidden no state
 4 enter combat
     Improved Stormst hidden no state
 5 proc up
     Improved Stormst shown a=1.00 ready=- cd=- usable=- noPower=- proc=n up=y glow=y(up)
 6 wait 4 s
     Improved Stormst shown a=1.00 ready=- cd=- usable=- noPower=- proc=n up=y glow=y(up)
 7 proc down
     Improved Stormst hidden no state
 8 leave combat
     Improved Stormst hidden no state
]]

local KEY = 200320
local BLUE = { 0, 0.054901961237192147, 0.80392158031463623 }

T.test("repro shaman_stormstrike_225", function()
    R.Check(R.Trace(REPORT, { spell = 1223031, script = "proc" }), EXPECT)
end)

T.test("repro shaman_stormstrike_225: the game draws it, so the up glow is Daylight UI's", function()
    local w = R.Build(REPORT)
    T.eq(w.AB.CdmRows.DrawnBy(KEY), "game")
    T.rgb(w.ns.Effects.Get(KEY), BLUE, "EZ-CDM's rule kept for a holder")
    local p = w.AB.CdmData.Get(1).pieces[KEY]
    T.eq(p.upGlow, true, "Daylight UI's upGlow")
    T.rgb(p.upGlowColor, BLUE, "in the rule's color")
    T.falsy(w.ns.Effects.Drawn(KEY), "no EZ-CDM ring")
end)

T.test("repro shaman_stormstrike_225: an aura the game's item sees lights the glow", function()
    local w = R.Build(REPORT)
    local keep = C_Spell.IsSpellPassive
    C_Spell.IsSpellPassive = function() return false end
    local ok, out = pcall(R.Run, w, { KEY }, "proc")
    C_Spell.IsSpellPassive = keep
    assert(ok, out)
    R.Check(table.concat(out, "\n") .. "\n", EXPECT_SEEN)
end)
