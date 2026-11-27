# EZ-CDM 1.1.0 (unreleased)

One line can do several things: "When I can't cast it, glow and pulse it."

## New
- Lines: Click "and …" after what happens to add another action to the same line, like "When it's ready, glow and pulse it". A line holds up to three, each with its own color, style, words or sound
- Lines: Flashes, sparkles and sounds play once as the line turns on, while glows, pulses, borders and words stay for as long as it holds, all from one line
- Lines: "When it's ready" can mix Daylight UI's own glow and sound with EZ-CDM's looks on one line. Add "and" to it, and EZ-CDM draws the glow, so there is still only one

## Changed
- Drawer: Lines with the same moment and the same "and" parts now read as one sentence. What they do is unchanged
- Drawer: Two actions that can't both show are not offered on one line, and the drawer says why: hiding it with anything drawn on it, gray with a swapped icon, no sweep with a sweep color, or show with hide
- Drawer: Right-click one action on a line to take just that one away; the cross removes the whole line

# EZ-CDM 1.0.0

Join conditions with "and", react to your target, health, power, range, forms and totems, and
end a line in one of nine new looks, from a pulse to a flare around your character.

Needs Daylight UI 2.2.4 or newer, on WoW Forever. Flare around me needs Daylight UI 2.3.0 or
newer.

## New
- Conditions: Add "and" to a line to join conditions, like "When it's ready and I'm in combat, glow"
- Conditions: My target is out of range, I have a target, my target is an enemy, my target is a boss, and my target is casting (on your interrupts)
- Conditions: My target is below 20% health, I'm below 30% health, and my mana (or rage, or energy) is below 30%. Click the number to type your own. These work in a fight, with a glow or a look that stays on while the line is true
- Conditions: It's only on the global cooldown, I'm in a form, stance or stealth, my weapon buff is missing, and its charges are down to a number (on buffs the game never hides in a fight)
- Conditions: In combat, out of combat, in a group and in an instance, behind "more…" in the drawer, or always shown with More Condition Choices on the settings page
- Totems: "While my totem is up" and "When my totem is down" take glows, sounds and every look
- Looks: Flash it, sparkle, flash the screen's edge, pulse it, color its border, light a halo behind it, show words on it, and swap its icon, each with its own color, words or icon
- Looks: Flare around me lights Daylight UI's Proc Alerts flare around your character, in the design, animation and sound you pick, and it goes as the line turns off
- Sounds: Every condition but the health and power ones can play a sound
- Ready: "When it's ready" takes every look and "and". A ready glow or sound with "and" is drawn by EZ-CDM, and Daylight UI's own ready glow or sound for that spell waits until the line goes
- Drawer: Right-click a chosen word to clear it

## Changed
- Can't cast: "When I can't cast it" now means any reason: a cooldown, too little power, or not usable. Your lines from 0.3.0 now read "When it's not usable" and work as before
- Glow styles: Comet and Shine are no longer offered. Comet glows become Circling, and Shine glows become Ring
- Glows: EZ-CDM's glows are as big as the Cooldown Manager's own, Ring is Daylight UI's proc ring, Circling is brighter, and Breathing is quicker, with a soft halo behind the icon
- Glows, pulses, borders, halos and words show on whichever side a spell shows, its buff or its cooldown
- Gray: A spell with an EZ-CDM gray line has one gray, drawn by EZ-CDM. Daylight UI's Gray out waits, and comes back when the last gray line goes
- Drawer: Words come from the game's own spell data. A spell with no buff offers no buff words, a debuff says "debuff", a totem speaks of its totem, and power words name the spell's own power, only on spells that cost some
- Drawer: Two conditions that can never both be true are not offered together, and the drawer says why
- Drawer: A line that is hidden while the buff shows says so, with one-click fixes
- Drawer: A spell Daylight UI's Proc Alerts lists says its proc shows there, and offers no Proc pop recipe

## Fixed
- "My target is out of range" no longer lights with no target
- A glow no longer dips out when a second glow line on the same spell turns off
- A weapon buff that wears off can glow until it's back
