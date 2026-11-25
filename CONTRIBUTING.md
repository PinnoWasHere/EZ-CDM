# Contributing to EZ-CDM

EZ-CDM is a Daylight UI plugin for WoW: Forever. It writes Daylight UI's Cooldown
Manager settings as plain sentences. This page covers setup, the tests, the rules a
change must follow, and how to send it.

## Setup

1. Fork this repository and clone your fork into a folder named `EZ-CDM`, somewhere
   outside the game folder. The game's launcher can't update while an editor holds files
   open inside it.
2. Link the clone into the game. On Windows, in PowerShell:

   ```
   New-Item -ItemType Junction -Path "<game>\_forever_\Interface\AddOns\EZ-CDM" -Target "<your clone>"
   ```

3. Install Daylight UI in the game as usual. EZ-CDM needs it.
4. In the game, `/reload` loads your changes, new files included.

## Tests

The tests run EZ-CDM on top of Daylight UI in a fake copy of the game, with no WoW
running. You need [LuaJIT](https://luajit.org), Python 3 and git.

The fake game is Daylight UI's own test harness. Daylight UI's license doesn't allow
its code in this repository, so the tests load it from a Daylight UI checkout at the
release named in `tests/pin.lua`. Set it up once:

```
git clone --depth 1 --branch v2.3.0 https://github.com/dayightt/DaylightUI .daylight/DaylightUI
python tools/fetch_blizzard.py
```

The first line puts the checkout where the tests look for it (`.daylight/` is ignored
by git). To keep it elsewhere, set `DUI_ROOT` to its folder. The second line downloads
the game's own UI code the fake game runs into `tests/blizzard/` (also ignored). Use the
tag in `tests/pin.lua`; when the pin moves, check out the new tag and fetch again.

Then, while you work:

```
python tools/affected.py --files Grammar.lua     # the tests for the files you changed
luajit tests/run.lua --par                       # everything, before you open the pull request
```

Every pull request runs the whole suite on GitHub the same way
(`.github/workflows/test.yml`).

If you fix a bug, first write a test that fails because of it, then fix the code until
the test passes. If the fake game behaves differently from the real client, the fix
goes in the fake game's fitting in `tests/ez_harness.lua`, with a note on what the
client does.

## Rules

- **WoW: Forever only.** Interface 16001: classic content on the modern client. Code
  written for the old Classic clients often doesn't work here.
- **Secret values.** In combat and in restricted content, many API returns are secret.
  You may pass one to a setter, but you can't compare it, do math on it, test it in an
  `if`, or use it as a table key. Check what a game function returns before using it.
- **Combat lockdown and restrictions.** Protected frames can't be shown, moved or
  resized in combat, and the client's aura buttons lock while auras are secret. Wait
  until the fight or restriction ends before such a change.
- **Never hook the game's frames.** No `hooksecurefunc` on a game object's method: in
  this client it breaks the game's own protected calls. React to events, or to Daylight
  UI's API, instead. `tests/test_guards.lua` catches most of these.
- **Every look comes from Daylight UI.** Frames, buttons, chips, menus, text, colors,
  motion and sounds come from Daylight UI's builders and the calls in its `API.md`. Never
  build a lookalike of one of its pieces. `tests/test_hygiene.lua` catches most of these.
- **Daylight UI internals only through `Bridge.lua`.** A Daylight UI function that
  isn't in its `API.md` is reached only from `Bridge.lua` and listed in `Bridge.NEEDS`
  (or `Bridge.OPTIONAL`), so a Daylight UI update that drops one switches EZ-CDM off
  with a clear message instead of breaking it.
- **No spell or class ids in logic.** Behavior comes from what the game and Daylight UI
  report about a piece, never from a list of particular spells or classes. The
  every-class sweep (`tests/test_sweep_*.lua`) runs each change across all nine classes.
- **New conditions go through the registry.** A new condition is a
  `Conditions.Register` call, its words in `Grammar.WORDING`, and tests.
- **All player text lives in `Grammar.WORDING`.** No sentence a player reads is
  written anywhere else.
- **US spelling** in code, comments and these docs (color, gray). The hygiene test
  checks it.

## Pull requests

- One change per pull request, kept small. Say what changes for the player and why.
- Don't change the version, the `.toc`'s metadata or `CHANGELOG.md`; that happens at
  release.
- For a bug report, open an issue with what you did, what you expected, and the error
  text. The drawer's Copy report link gives a line of text that rebuilds your layout
  offline (no names in it); paste it in the issue.

## License

EZ-CDM is source-available, not open source. Read `LICENSE` before you start. You may
fork this repository to prepare pull requests to it; you may not republish EZ-CDM or
reuse its code, art or text elsewhere. `AGENTS.md` asks automated tools not to copy or
train on this code, and applies to any tool you work with here.

By opening a pull request, you agree that your contribution is released under EZ-CDM's
license, and that the author may use, change and ship it as part of EZ-CDM.

Daylight UI's code stays in Daylight UI's repository. Don't copy any of it into this
one, tests included: the tests load it from your checkout.
