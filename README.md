EZ-CDM is a plugin for Daylight UI. It adds an "EZ" drawer to Daylight UI's Cooldown
Manager editor. Click a spell in your layout, and the drawer shows what that spell does as
plain sentences, for example:

- When it's ready, glow.
- While it's cooling down, turn it gray.
- When it's about to fall off (3 seconds before), glow, and play a sound.

Click any word to change it. A row of choices opens under the sentences, and your pick is
written to the spell at once. The editor redraws so you see the result on the real icon.

EZ-CDM has no rule engine of its own. Almost every sentence is a Daylight UI Cooldown
Manager setting, written for you. A few things Daylight UI doesn't do yet, EZ-CDM draws on
top of Daylight UI's icons (see below).

### Requirements

- WoW Forever.
- Daylight UI 2.2.4 or newer, with its Cooldown Manager turned on.

With an older Daylight UI, EZ-CDM stays off, and Daylight UI says in chat that EZ-CDM
needs a newer Daylight UI.

### How to use it

1. Type `/cdm` to open Daylight UI's Cooldown Manager editor. EZ-CDM has no slash command of
   its own.
2. Beside the editor's spell list is a start block. "EZ-Start Blank" makes a new, empty
   layout. "EZ-Load Layout" loads one of your class's layouts. "Work on a copy" is on by
   default, so your current layout stays as it was.
3. Place spells with Daylight UI's own editor, as usual.
4. Click a spell in your layout. The EZ drawer under the spell list shows its sentences.
   The tab on the list's edge folds the drawer away and opens it again.
5. Click a word to change it, or "+ add a line" for a new one. "+ a recipe" adds a
   ready-made set of lines in one click.

### What you can set

- When a spell shows, fades or hides: always, when it's ready, while it's cooling down,
  when you can't cast it, when you don't have enough power.
- Glows, with a color, and a glow style for each moment (Ring, Circling, Comet, Breathing,
  Twinkle, Shine).
- Sounds when a spell is ready, becomes castable, goes active or wears off.
- Turn it gray or keep its color, hide or color the sweep, flash it, color the numbers for
  the last few seconds.
- What a spell shows: its buff, its cooldown, or both.
- Rules for a whole group: only in combat, only with a target, only in a group, hide while
  mounted, only in dungeons and raids or only in the open world, hide in a form.
- Recipes, ready-made lines that fit the spell: Ready alert, Hidden, Dim while cooling,
  Can't cast, Mana check, Almost there, Now usable, Proc pop, Missing reminder, Refresh
  warning, Ended ping and Fight only.

What EZ-CDM adds on top of Daylight UI:

- "While it's active, glow" in combat, for buffs Daylight UI shows in its aura icons, such
  as Improved Stormstrike's 15-second mana buff. This glow is always a ring.
- A glow and a sound a set number of seconds (2 to 10) before your buff or debuff falls off.
- A different glow style for each moment of the same spell.
- A gray wash over the icon when you can't cast the spell, and a blue wash when you don't
  have enough power.

### Limits

- The editor and the drawer close in combat. You set things up out of a fight.
- A new or recolored in-combat proc glow lights at once. If the game refuses it, EZ-CDM
  asks for a `/reload` as you close the editor.
- A glow goes back to your accent color only with Daylight UI 2.2.6 or newer. On an older
  Daylight UI it keeps the color you picked, and the drawer says so.
- Buffs whose timer the game hides in a fight (Improved Stormstrike's mana buff, for
  example) get no "about to fall off" moment. The drawer says so on those spells.
- "About to fall off" counts from your own cast, or from when the buff lands where Daylight
  UI can see that. On some spells it can't tell in a fight that the aura fell off early.
  The drawer notes this under the line.
- A debuff you cast on enemies has one timer per spell, not one per target.
- Buffs without a duration (forms, auras like Ghost Wolf) have no "about to fall off" or
  "wears off" moment.
- Daylight UI shows one glow at a time on an icon. When two glow lines compete, the
  drawer names the one that wins.
- Glows and sounds work only on spells placed in your Daylight UI layout.

### Coming later

Sharing one spell's sentences as a text string.

### Contributing

Setup, the tests and the rules a change follows are in [CONTRIBUTING.md](CONTRIBUTING.md).
Every pull request runs the test suite on GitHub.

### License

Source-available, all rights reserved. See [LICENSE](LICENSE).
