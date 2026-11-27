EZ-CDM is a plugin for Daylight UI. It adds an "EZ" drawer to Daylight UI's Cooldown
Manager editor. Click a spell in your layout, and the drawer shows what that spell does as
plain sentences, for example:

- When it's ready, glow.
- While it's cooling down, turn it gray.
- When it's about to fall off (3 seconds before), glow, and play a sound.
- When my target is a boss and my target is below 20% health, pulse it.

Click any word to change it. A row of choices opens under the sentences, and your pick is
written to the spell at once. The editor redraws so you see the result on the real icon.

Many sentences are Daylight UI Cooldown Manager settings, written for you. What Daylight UI
doesn't do, EZ-CDM draws on top of Daylight UI's icons with Daylight UI's own looks (see
below).

### Requirements

- WoW Forever.
- Daylight UI 2.2.4 or newer, with its Cooldown Manager turned on.
- "Flare around me" needs Daylight UI 2.3.0 or newer, with its Proc Alerts turned on.

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
   ready-made set of lines in one click. Right-click a chosen word to clear it.
6. Click "and …" after a moment to add another condition to the line.
7. Click "and …" after what happens to add another action, up to three on a line: "When
   I can't cast it, glow and pulse it". Right-click one action to take just that one away.

EZ-CDM's settings are on its own page under Plugins in `/dui`.

### What you can set

Moments, from Daylight UI:

- Always, when it's ready, while it's cooling down, when it's almost ready, when it's not
  usable, when you don't have enough power, when it becomes castable, while it's active, when
  it wears off, while it's not active, when it's about to fall off.
- On a totem: while my totem is up, when my totem is down, when my totem is almost gone.

Conditions EZ-CDM adds, each a moment of its own or a part after "and":

- When I can't cast it, for any reason: a cooldown, too little power, or not usable.
- My target is out of range, I have a target, my target is an enemy, my target is a boss, my
  target is casting (on your interrupts).
- My target is below 20% health, I'm below 30% health, my power is below 30%. Click the
  number to type your own.
- It's only on the global cooldown, I'm in a form, stance or stealth, my weapon buff is
  missing, its charges are down to a number.
- Behind "more…": in combat, out of combat, in a group, in an instance. More Condition
  Choices on the settings page always shows them.

What happens:

- Show it, make it see-through, or hide it.
- Glow, with a color and a style (Ring, Circling, Breathing, Twinkle).
- Turn it gray or keep its color, tint it blue, hide or color the sweep, color the numbers
  for the last few seconds.
- Play a sound.
- Flash it, sparkle, or flash the screen's edge, once as the line turns on.
- Pulse it, color its border, light a halo behind it, show words on it, or swap its icon,
  for as long as the line is true. Each takes its own color, words or icon.
- Flare around me: Daylight UI's Proc Alerts flare around your character, in the design,
  animation and sound you pick. It goes as the line turns off.

Also:

- What a spell shows: its buff, its cooldown, or both.
- Rules for a whole group: only in combat, only with a target, only in a group, hide while
  mounted, only in dungeons and raids or only in the open world, hide in a form.
- Recipes, ready-made lines that fit the spell: Ready alert, Hidden, Dim while cooling,
  Can't cast, Mana check, Almost there, Now usable, Proc pop, Missing reminder, Refresh
  warning, Ended ping and Fight only.

The drawer offers only words that fit the spell, from the game's own spell data. A spell with
no buff offers no buff words, a debuff says "debuff", and power words name the spell's own
power. Two conditions that can never both be true are not offered together, and the drawer
says why.

What EZ-CDM adds on top of Daylight UI's own moments:

- "While it's active, glow" in combat, for buffs Daylight UI shows in its aura icons, such
  as Improved Stormstrike's 15-second mana buff. This glow is always a ring.
- A glow and a sound a set number of seconds (2 to 10) before your buff or debuff falls off.
- A different glow style for each moment of the same spell.
- "When it's ready and …": a ready glow or sound with "and" is drawn by EZ-CDM. Daylight
  UI's own ready glow or sound for that spell waits until the line goes.
- One gray. A spell with an EZ-CDM gray line has only EZ-CDM's gray. Daylight UI's Gray out
  waits, and comes back when the last gray line goes.

### Proc Alerts

Daylight UI's Proc Alerts shows a talent's proc as a flare around your character. On a spell
whose proc Proc Alerts lists, the drawer says the proc shows there and offers no Proc pop
recipe. Improved Stormstrike's proc, for example, is Stormstrike's cooldown reset, which Proc
Alerts flares. Its 15-second mana buff is a separate buff you can place and glow.

### Limits

- The editor and the drawer close in combat. You set things up out of a fight.
- The health and power conditions work in a fight, because the game draws their answer
  straight onto the icon. So they take only looks that stay on: a glow, a pulse, a border,
  a halo, words or a swapped icon. They play no sound, and each line holds one of them, as
  its last part.
- Flash, sparkle and the screen's edge need Daylight UI's motion on. The drawer says so when
  it's off.
- A new or recolored in-combat proc glow lights at once. If the game refuses it, EZ-CDM
  asks for a `/reload` as you close the editor.
- A glow goes back to your accent color only with Daylight UI 2.2.6 or newer. On an older
  Daylight UI it keeps the color you picked, and the drawer says so.
- Buffs whose timer the game hides in a fight (Improved Stormstrike's mana buff, for
  example) get no "about to fall off" moment. The drawer says so on those spells.
- "Its charges are down to" shows only on buffs the game never hides in a fight. Shields
  like Lightning Shield have none.
- "About to fall off" counts from your own cast, or from when the buff lands where Daylight
  UI can see that. On some spells it can't tell in a fight that the aura fell off early.
  The drawer notes this under the line.
- A debuff you cast on enemies has one timer per spell, not one per target.
- Buffs without a duration (forms, auras like Ghost Wolf) have no "about to fall off" or
  "wears off" moment.
- Daylight UI shows one glow at a time on an icon. When two glow lines compete, the
  drawer names the one that wins.
- Glows, sounds and looks work only on spells placed in your Daylight UI layout.

### Coming later

- Sharing one spell's sentences as a text string.
- A progress fill over an icon.
- Icons at your cursor.
- Shield charges in a fight, such as Lightning Shield's.

### Contributing

Setup, the tests and the rules a change follows are in [CONTRIBUTING.md](CONTRIBUTING.md).
Every pull request runs the test suite on GitHub.

### License

Source-available, all rights reserved. See [LICENSE](LICENSE).
