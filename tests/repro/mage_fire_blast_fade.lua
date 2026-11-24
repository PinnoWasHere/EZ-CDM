local R = require("repro_world")

-- A bug report rebuilt in the class world (tools/repro.py --make-test mage_fire_blast_fade).
-- MAGE, EZ-CDM 0.1.0, Daylight UI test, script cooldown, spell 199186.
-- EXPECT is what EZ-CDM does now. To fix the bug, change EXPECT to what it should
-- do (the test fails), then fix the code until it passes.

local REPORT = "EZCDM1:e1MzOmFwaVtOMTtOMTQ7XVM2OmNoYWluc3t9UzU6Y2xhc3NTNDpNQUdFUzM6ZHVpUzQ6dGVzdFMyOmV6UzU6MC4xLjBTNDpnYW1lW1M2OjEuNjAuMVM1OjcxMDM3TjE2MDAxO11TNjpoaWRkZW57UzIxOkJ1ZmZCYXJDb29sZG93blZpZXdlclRTMjI6QnVmZkljb25Db29sZG93blZpZXdlclR9UzU6a25vd25bTjEyMjtOODY1O04yMTM2O04yMTM3O04yMTM4O042MTMxO044NDEyO044NDEzO04xMDE5NztOMTAxOTk7TjEwMjMwO04xMTIxMztOMTIwNTE7Ti0xMjUzNjtdUzc6cGFzc2l2ZVtOMTEyMTM7XVM2OnBpZWNlc3tOMTk5MTg2O3tTNzpjZEFscGhhTjAuMjU7UzQ6b25DZFM0OmZhZGVTOTpyZWFkeUdsb3dUUzU6c2hhcGVTNDppY29ufU4xOTkyMzU7e1M4OmNsaXBHbG93VFM1OnNoYXBlUzQ6aWNvbn1OMTk5MjY1O3tTNDpvbkNkUzQ6aGlkZVM1OnNoYXBlUzQ6aWNvbn1OMTk5MjcwO3tTNTpzaGFwZVM0Omljb259fVM1OnJ1bGVze1M3OmZhbGxPZmZ7TjE5OTIzNTt7UzQ6bGVhZE40O319UzY6dXBHbG93e04xOTkyNzA7VH19UzM6c2V0TjE7UzQ6c3BlY04xO1M2OnNwZWxsc3tOMTk5MTg2O3tTNTpkcmF3blM0OmdhbWVTMjppZE4xMDE5OTtTMzppZHNbTjIxMzY7TjIxMzc7TjIxMzg7Tjg0MTI7Tjg0MTM7TjEwMTk3O04xMDE5OTtdfU4xOTkyMzU7e1M1OmRyYXduUzQ6Z2FtZVMyOmlkTjEwMjMwO1MzOmlkc1tOMTIyO044NjU7TjYxMzE7TjEwMjMwO11TNTpzaG93c1M0OmJvdGh9TjE5OTI2NTt7UzU6ZHJhd25TNDpnYW1lUzI6aWROMTIwNTE7UzM6aWRzW04xMjA1MTtdUzU6c2hvd3NTNDpib3RofU4xOTkyNzA7e1M1OmRyYXduUzk6YXVyYSBpY29uUzI6aWROMTEyMTM7UzM6aWRzW04xMTIxMztOMTI1MzY7XVM1OnNob3dzUzQ6YnVmZn19UzE6dk4xO30="

local EXPECT = [[
 1 idle
     Fire Blast       shown a=1.00 ready=y cd=n usable=- noPower=- proc=n up=- glow=y(ready)
 2 cast
     Fire Blast       shown a=1.00 ready=y cd=n usable=- noPower=- proc=n up=- glow=y(ready)
 3 cooldown
     Fire Blast       shown a=0.25 ready=n cd=y usable=- noPower=- proc=n up=- glow=n
 4 half the cooldown
     Fire Blast       shown a=0.25 ready=n cd=y usable=- noPower=- proc=n up=- glow=n
 5 ready
     Fire Blast       shown a=1.00 ready=y cd=n usable=- noPower=- proc=n up=- glow=y(ready)
]]

T.test("repro mage_fire_blast_fade", function()
    R.Check(R.Trace(REPORT, { spell = 199186, script = "cooldown" }), EXPECT)
end)
