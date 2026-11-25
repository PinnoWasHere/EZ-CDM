-- Made by tools/make_aura_links.py, client build 1.60.1.71091. Don't edit by hand.
-- The sweep's spellbook stand-ins for every spell in tests/cooldown_sets.lua or
-- EZ-CDM/AuraLinks.lua (links and spells): passive is SpellMisc's passive flag; book is true when
-- SkillLineAbility lists it, a spell a player can have rather than a proc's aura;
-- harmful is true when a SpellEffect aims at an enemy (C_Spell.IsSpellHarmful).
return {
    [0] = { passive = false, book = false, harmful = false }, -- ?
    [10] = { passive = false, book = true, harmful = true }, -- Blizzard
    [17] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [53] = { passive = false, book = true, harmful = true }, -- Backstab
    [71] = { passive = false, book = true, harmful = false }, -- Defensive Stance
    [72] = { passive = false, book = true, harmful = true }, -- Shield Bash
    [75] = { passive = false, book = true, harmful = true }, -- Auto Shot
    [78] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [99] = { passive = false, book = true, harmful = true }, -- Demoralizing Roar
    [100] = { passive = false, book = true, harmful = true }, -- Charge
    [116] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [118] = { passive = false, book = true, harmful = true }, -- Polymorph
    [120] = { passive = false, book = true, harmful = true }, -- Cone of Cold
    [122] = { passive = false, book = true, harmful = true }, -- Frost Nova
    [130] = { passive = false, book = true, harmful = false }, -- Slow Fall
    [132] = { passive = false, book = true, harmful = false }, -- Detect Invisibility
    [133] = { passive = false, book = true, harmful = true }, -- Fireball
    [136] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [139] = { passive = false, book = true, harmful = false }, -- Renew
    [143] = { passive = false, book = true, harmful = true }, -- Fireball
    [145] = { passive = false, book = true, harmful = true }, -- Fireball
    [168] = { passive = false, book = true, harmful = false }, -- Frost Armor
    [172] = { passive = false, book = true, harmful = true }, -- Corruption
    [205] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [284] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [285] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [324] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [325] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [331] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [332] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [339] = { passive = false, book = true, harmful = true }, -- Entangling Roots
    [348] = { passive = false, book = true, harmful = true }, -- Immolate
    [355] = { passive = false, book = true, harmful = true }, -- Taunt
    [370] = { passive = false, book = true, harmful = true }, -- Purge
    [403] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408] = { passive = false, book = true, harmful = true }, -- Kidney Shot
    [421] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [453] = { passive = false, book = true, harmful = true }, -- Mind Soothe
    [465] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [467] = { passive = false, book = true, harmful = false }, -- Thorns
    [475] = { passive = false, book = true, harmful = false }, -- Remove Lesser Curse
    [498] = { passive = false, book = true, harmful = false }, -- Divine Protection
    [526] = { passive = false, book = true, harmful = false }, -- Cure Poison
    [527] = { passive = false, book = true, harmful = false }, -- Dispel Magic
    [528] = { passive = false, book = true, harmful = false }, -- Cure Disease
    [529] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [543] = { passive = false, book = true, harmful = false }, -- Fire Ward
    [547] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [548] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [552] = { passive = false, book = true, harmful = false }, -- Abolish Disease
    [585] = { passive = false, book = true, harmful = true }, -- Smite
    [586] = { passive = false, book = true, harmful = false }, -- Fade
    [587] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [588] = { passive = false, book = true, harmful = false }, -- Inner Fire
    [589] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [591] = { passive = false, book = true, harmful = true }, -- Smite
    [592] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [594] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [596] = { passive = false, book = true, harmful = false }, -- Prayer of Healing
    [597] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [598] = { passive = false, book = true, harmful = true }, -- Smite
    [600] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [602] = { passive = false, book = true, harmful = false }, -- Inner Fire
    [603] = { passive = false, book = true, harmful = true }, -- Bane of Doom
    [604] = { passive = false, book = true, harmful = false }, -- Dampen Magic
    [605] = { passive = false, book = true, harmful = true }, -- Mind Control
    [633] = { passive = false, book = true, harmful = false }, -- Lay on Hands
    [635] = { passive = false, book = true, harmful = false }, -- Holy Light
    [639] = { passive = false, book = true, harmful = false }, -- Holy Light
    [642] = { passive = false, book = true, harmful = false }, -- Divine Shield
    [643] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [647] = { passive = false, book = true, harmful = false }, -- Holy Light
    [676] = { passive = false, book = true, harmful = true }, -- Disarm
    [678] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [679] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [680] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [686] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [687] = { passive = false, book = true, harmful = false }, -- Demon Skin
    [688] = { passive = false, book = true, harmful = false }, -- Summon Imp
    [689] = { passive = false, book = true, harmful = true }, -- Drain Life
    [691] = { passive = false, book = true, harmful = false }, -- Summon Felhunter
    [693] = { passive = false, book = true, harmful = false }, -- Create Soulstone
    [694] = { passive = false, book = true, harmful = true }, -- Mocking Blow
    [695] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [696] = { passive = false, book = true, harmful = false }, -- Demon Skin
    [697] = { passive = false, book = true, harmful = false }, -- Summon Voidwalker
    [698] = { passive = false, book = true, harmful = false }, -- Ritual of Summoning
    [699] = { passive = false, book = true, harmful = true }, -- Drain Life
    [702] = { passive = false, book = true, harmful = true }, -- Curse of Weakness
    [703] = { passive = false, book = true, harmful = true }, -- Garrote
    [704] = { passive = false, book = true, harmful = true }, -- Curse of Recklessness
    [705] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [706] = { passive = false, book = true, harmful = false }, -- Demon Armor
    [707] = { passive = false, book = true, harmful = true }, -- Immolate
    [709] = { passive = false, book = true, harmful = true }, -- Drain Life
    [710] = { passive = false, book = true, harmful = true }, -- Banish
    [712] = { passive = false, book = true, harmful = false }, -- Summon Succubus
    [713] = { passive = false, book = true, harmful = false }, -- Summon Incubus
    [724] = { passive = false, book = true, harmful = false }, -- Lightwell
    [740] = { passive = false, book = true, harmful = false }, -- Tranquility
    [755] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [759] = { passive = false, book = true, harmful = false }, -- Conjure Mana Agate
    [768] = { passive = false, book = true, harmful = false }, -- Cat Form
    [769] = { passive = false, book = true, harmful = true }, -- Swipe
    [770] = { passive = false, book = true, harmful = true }, -- Faerie Fire
    [772] = { passive = false, book = true, harmful = true }, -- Rend
    [774] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [778] = { passive = false, book = true, harmful = true }, -- Faerie Fire
    [779] = { passive = false, book = true, harmful = true }, -- Swipe
    [780] = { passive = false, book = true, harmful = true }, -- Swipe
    [781] = { passive = false, book = true, harmful = true }, -- Disengage
    [782] = { passive = false, book = true, harmful = false }, -- Thorns
    [783] = { passive = false, book = true, harmful = false }, -- Travel Form
    [837] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [845] = { passive = false, book = true, harmful = true }, -- Cleave
    [853] = { passive = false, book = true, harmful = true }, -- Hammer of Justice
    [865] = { passive = false, book = true, harmful = true }, -- Frost Nova
    [871] = { passive = false, book = true, harmful = false }, -- Shield Wall
    [879] = { passive = false, book = true, harmful = true }, -- Exorcism
    [905] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [913] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [915] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [921] = { passive = false, book = true, harmful = true }, -- Pick Pocket
    [930] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [939] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [943] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [945] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [959] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [970] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [976] = { passive = false, book = true, harmful = false }, -- Shadow Protection
    [980] = { passive = false, book = true, harmful = true }, -- Bane of Agony
    [982] = { passive = false, book = true, harmful = false }, -- Revive Pet
    [984] = { passive = false, book = true, harmful = true }, -- Smite
    [988] = { passive = false, book = true, harmful = false }, -- Dispel Magic
    [990] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [992] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [996] = { passive = false, book = true, harmful = false }, -- Prayer of Healing
    [1002] = { passive = false, book = true, harmful = false }, -- Eyes of the Beast
    [1004] = { passive = false, book = true, harmful = true }, -- Smite
    [1006] = { passive = false, book = true, harmful = false }, -- Inner Fire
    [1008] = { passive = false, book = true, harmful = false }, -- Amplify Magic
    [1010] = { passive = false, book = true, harmful = true }, -- Curse of Idiocy
    [1014] = { passive = false, book = true, harmful = true }, -- Bane of Agony
    [1020] = { passive = false, book = true, harmful = false }, -- Divine Shield
    [1022] = { passive = false, book = true, harmful = false }, -- Blessing of Protection
    [1026] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1032] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [1042] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1044] = { passive = false, book = true, harmful = false }, -- Blessing of Freedom
    [1058] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [1062] = { passive = false, book = true, harmful = true }, -- Entangling Roots
    [1064] = { passive = false, book = true, harmful = false }, -- Chain Heal
    [1066] = { passive = false, book = true, harmful = false }, -- Aquatic Form
    [1075] = { passive = false, book = true, harmful = false }, -- Thorns
    [1079] = { passive = false, book = true, harmful = true }, -- Rip
    [1082] = { passive = false, book = true, harmful = true }, -- Claw
    [1086] = { passive = false, book = true, harmful = false }, -- Demon Armor
    [1088] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [1094] = { passive = false, book = true, harmful = true }, -- Immolate
    [1098] = { passive = false, book = true, harmful = true }, -- Subjugate Demon
    [1106] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [1108] = { passive = false, book = true, harmful = true }, -- Curse of Weakness
    [1120] = { passive = false, book = true, harmful = true }, -- Drain Soul
    [1122] = { passive = false, book = true, harmful = true }, -- Inferno
    [1126] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [1130] = { passive = false, book = true, harmful = true }, -- Hunter's Mark
    [1152] = { passive = false, book = true, harmful = false }, -- Purify
    [1160] = { passive = false, book = true, harmful = true }, -- Demoralizing Shout
    [1161] = { passive = false, book = true, harmful = true }, -- Challenging Shout
    [1178] = { passive = true, book = true, harmful = false }, -- Bear Form (Passive)
    [1243] = { passive = false, book = true, harmful = false }, -- Power Word: Fortitude
    [1244] = { passive = false, book = true, harmful = false }, -- Power Word: Fortitude
    [1245] = { passive = false, book = true, harmful = false }, -- Power Word: Fortitude
    [1430] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [1449] = { passive = false, book = true, harmful = true }, -- Arcane Explosion
    [1454] = { passive = false, book = true, harmful = false }, -- Life Tap
    [1455] = { passive = false, book = true, harmful = false }, -- Life Tap
    [1456] = { passive = false, book = true, harmful = false }, -- Life Tap
    [1459] = { passive = false, book = true, harmful = false }, -- Arcane Intellect
    [1460] = { passive = false, book = true, harmful = false }, -- Arcane Intellect
    [1461] = { passive = false, book = true, harmful = false }, -- Arcane Intellect
    [1463] = { passive = false, book = true, harmful = false }, -- Mana Shield
    [1464] = { passive = false, book = true, harmful = true }, -- Slam
    [1494] = { passive = false, book = true, harmful = false }, -- Track Beasts
    [1495] = { passive = false, book = true, harmful = true }, -- Mongoose Bite
    [1499] = { passive = false, book = true, harmful = false }, -- Freezing Trap
    [1510] = { passive = false, book = true, harmful = true }, -- Volley
    [1513] = { passive = false, book = true, harmful = true }, -- Scare Beast
    [1543] = { passive = false, book = true, harmful = true }, -- Flare
    [1608] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [1671] = { passive = false, book = true, harmful = true }, -- Shield Bash
    [1672] = { passive = false, book = true, harmful = true }, -- Shield Bash
    [1680] = { passive = false, book = true, harmful = true }, -- Whirlwind
    [1706] = { passive = false, book = true, harmful = false }, -- Levitate
    [1714] = { passive = false, book = true, harmful = true }, -- Curse of Tongues
    [1715] = { passive = false, book = true, harmful = true }, -- Hamstring
    [1719] = { passive = false, book = true, harmful = false }, -- Recklessness
    [1725] = { passive = false, book = true, harmful = true }, -- Distract
    [1735] = { passive = false, book = true, harmful = true }, -- Demoralizing Roar
    [1752] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [1757] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [1758] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [1759] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [1760] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [1766] = { passive = false, book = true, harmful = true }, -- Kick
    [1767] = { passive = false, book = true, harmful = true }, -- Kick
    [1768] = { passive = false, book = true, harmful = true }, -- Kick
    [1769] = { passive = false, book = true, harmful = true }, -- Kick
    [1776] = { passive = false, book = true, harmful = true }, -- Gouge
    [1777] = { passive = false, book = true, harmful = true }, -- Gouge
    [1784] = { passive = false, book = true, harmful = false }, -- Stealth
    [1785] = { passive = false, book = true, harmful = false }, -- Stealth
    [1786] = { passive = false, book = true, harmful = false }, -- Stealth
    [1787] = { passive = false, book = true, harmful = false }, -- Stealth
    [1822] = { passive = false, book = true, harmful = true }, -- Rake
    [1823] = { passive = false, book = true, harmful = true }, -- Rake
    [1824] = { passive = false, book = true, harmful = true }, -- Rake
    [1833] = { passive = false, book = true, harmful = true }, -- Cheap Shot
    [1842] = { passive = false, book = true, harmful = false }, -- Disarm Trap
    [1850] = { passive = false, book = true, harmful = false }, -- Dash
    [1856] = { passive = false, book = true, harmful = false }, -- Vanish
    [1857] = { passive = false, book = true, harmful = false }, -- Vanish
    [1866] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [1943] = { passive = false, book = true, harmful = true }, -- Rupture
    [1949] = { passive = false, book = true, harmful = false }, -- Hellfire
    [1953] = { passive = false, book = true, harmful = false }, -- Blink
    [1966] = { passive = false, book = true, harmful = true }, -- Feint
    [1978] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [2006] = { passive = false, book = true, harmful = false }, -- Resurrection
    [2008] = { passive = false, book = true, harmful = false }, -- Ancestral Spirit
    [2010] = { passive = false, book = true, harmful = false }, -- Resurrection
    [2050] = { passive = false, book = true, harmful = false }, -- Lesser Heal
    [2052] = { passive = false, book = true, harmful = false }, -- Lesser Heal
    [2053] = { passive = false, book = true, harmful = false }, -- Lesser Heal
    [2054] = { passive = false, book = true, harmful = false }, -- Heal
    [2055] = { passive = false, book = true, harmful = false }, -- Heal
    [2060] = { passive = false, book = true, harmful = false }, -- Greater Heal
    [2061] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [2070] = { passive = false, book = true, harmful = true }, -- Sap
    [2090] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [2091] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [2094] = { passive = false, book = true, harmful = true }, -- Blind
    [2096] = { passive = false, book = true, harmful = false }, -- Mind Vision
    [2098] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [2120] = { passive = false, book = true, harmful = true }, -- Flamestrike
    [2121] = { passive = false, book = true, harmful = true }, -- Flamestrike
    [2136] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [2137] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [2138] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [2139] = { passive = false, book = true, harmful = true }, -- Counterspell
    [2362] = { passive = false, book = true, harmful = false }, -- Create Spellstone
    [2457] = { passive = false, book = true, harmful = false }, -- Battle Stance
    [2458] = { passive = false, book = true, harmful = false }, -- Berserker Stance
    [2480] = { passive = false, book = true, harmful = true }, -- Shoot Bow
    [2484] = { passive = false, book = true, harmful = false }, -- Earthbind Totem
    [2495] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [2565] = { passive = false, book = true, harmful = false }, -- Shield Block
    [2589] = { passive = false, book = true, harmful = true }, -- Backstab
    [2590] = { passive = false, book = true, harmful = true }, -- Backstab
    [2591] = { passive = false, book = true, harmful = true }, -- Backstab
    [2637] = { passive = false, book = true, harmful = true }, -- Hibernate
    [2643] = { passive = false, book = true, harmful = true }, -- Multi-Shot
    [2645] = { passive = false, book = true, harmful = false }, -- Ghost Wolf
    [2649] = { passive = false, book = true, harmful = true }, -- Growl
    [2651] = { passive = false, book = true, harmful = false }, -- Elune's Grace
    [2652] = { passive = false, book = true, harmful = false }, -- Touch of Weakness
    [2687] = { passive = false, book = true, harmful = false }, -- Bloodrage
    [2764] = { passive = false, book = true, harmful = true }, -- Throw
    [2767] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [2782] = { passive = false, book = true, harmful = false }, -- Remove Curse
    [2791] = { passive = false, book = true, harmful = false }, -- Power Word: Fortitude
    [2800] = { passive = false, book = true, harmful = false }, -- Lay on Hands
    [2812] = { passive = false, book = true, harmful = true }, -- Holy Wrath
    [2835] = { passive = false, book = true, harmful = false }, -- Deadly Poison
    [2837] = { passive = false, book = true, harmful = false }, -- Deadly Poison II
    [2860] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [2870] = { passive = false, book = true, harmful = false }, -- Cure Disease
    [2878] = { passive = false, book = true, harmful = true }, -- Turn Undead
    [2893] = { passive = false, book = true, harmful = false }, -- Abolish Poison
    [2908] = { passive = false, book = true, harmful = true }, -- Soothe Animal
    [2912] = { passive = false, book = true, harmful = true }, -- Starfire
    [2941] = { passive = false, book = true, harmful = true }, -- Immolate
    [2943] = { passive = false, book = true, harmful = true }, -- Touch of Weakness
    [2944] = { passive = false, book = true, harmful = true }, -- Devouring Plague
    [2947] = { passive = false, book = true, harmful = false }, -- Fire Shield
    [2948] = { passive = false, book = true, harmful = true }, -- Scorch
    [2970] = { passive = false, book = true, harmful = false }, -- Detect Invisibility
    [2973] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [2974] = { passive = false, book = true, harmful = true }, -- Wing Clip
    [2983] = { passive = false, book = true, harmful = false }, -- Sprint
    [3009] = { passive = false, book = true, harmful = true }, -- Claw
    [3010] = { passive = false, book = true, harmful = true }, -- Claw
    [3025] = { passive = true, book = true, harmful = false }, -- Cat Form (Passive)
    [3029] = { passive = false, book = true, harmful = true }, -- Claw
    [3034] = { passive = false, book = true, harmful = true }, -- Viper Sting
    [3043] = { passive = false, book = true, harmful = true }, -- Scorpid Sting
    [3044] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [3045] = { passive = false, book = true, harmful = false }, -- Rapid Fire
    [3110] = { passive = false, book = true, harmful = true }, -- Firebolt
    [3111] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [3140] = { passive = false, book = true, harmful = true }, -- Fireball
    [3261] = { passive = false, book = false, harmful = true }, -- Ignite
    [3355] = { passive = false, book = false, harmful = true }, -- Freezing Trap
    [3420] = { passive = false, book = true, harmful = false }, -- Crippling Poison
    [3421] = { passive = false, book = true, harmful = false }, -- Crippling Poison II
    [3472] = { passive = false, book = true, harmful = false }, -- Holy Light
    [3552] = { passive = false, book = true, harmful = false }, -- Conjure Mana Jade
    [3561] = { passive = false, book = true, harmful = false }, -- Teleport: Stormwind
    [3562] = { passive = false, book = true, harmful = false }, -- Teleport: Ironforge
    [3563] = { passive = false, book = true, harmful = false }, -- Teleport: Undercity
    [3565] = { passive = false, book = true, harmful = false }, -- Teleport: Darnassus
    [3566] = { passive = false, book = true, harmful = false }, -- Teleport: Thunder Bluff
    [3567] = { passive = false, book = true, harmful = false }, -- Teleport: Orgrimmar
    [3599] = { passive = false, book = true, harmful = false }, -- Searing Totem
    [3627] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [3661] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [3662] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [3698] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [3699] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [3700] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [3716] = { passive = false, book = true, harmful = true }, -- Torment
    [3747] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [4102] = { passive = false, book = false, harmful = true }, -- Gore
    [4987] = { passive = false, book = true, harmful = false }, -- Cleanse
    [5116] = { passive = false, book = true, harmful = true }, -- Concussive Shot
    [5118] = { passive = false, book = true, harmful = false }, -- Aspect of the Cheetah
    [5138] = { passive = false, book = true, harmful = true }, -- Drain Mana
    [5143] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [5144] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [5145] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [5171] = { passive = false, book = true, harmful = true }, -- Slice and Dice
    [5176] = { passive = false, book = true, harmful = true }, -- Wrath
    [5177] = { passive = false, book = true, harmful = true }, -- Wrath
    [5178] = { passive = false, book = true, harmful = true }, -- Wrath
    [5179] = { passive = false, book = true, harmful = true }, -- Wrath
    [5180] = { passive = false, book = true, harmful = true }, -- Wrath
    [5185] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [5186] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [5187] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [5188] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [5189] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [5195] = { passive = false, book = true, harmful = true }, -- Entangling Roots
    [5196] = { passive = false, book = true, harmful = true }, -- Entangling Roots
    [5201] = { passive = false, book = true, harmful = true }, -- Claw
    [5209] = { passive = false, book = true, harmful = true }, -- Challenging Roar
    [5211] = { passive = false, book = true, harmful = true }, -- Bash
    [5215] = { passive = false, book = true, harmful = false }, -- Prowl
    [5217] = { passive = false, book = true, harmful = false }, -- Tiger's Fury
    [5221] = { passive = false, book = true, harmful = true }, -- Shred
    [5229] = { passive = false, book = true, harmful = false }, -- Enrage
    [5232] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [5234] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [5242] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [5246] = { passive = false, book = true, harmful = true }, -- Intimidating Shout
    [5277] = { passive = false, book = true, harmful = false }, -- Evasion
    [5287] = { passive = false, book = false, harmful = false }, -- Mark of the Wild
    [5308] = { passive = false, book = true, harmful = true }, -- Execute
    [5384] = { passive = false, book = true, harmful = false }, -- Feign Death
    [5394] = { passive = false, book = true, harmful = false }, -- Healing Stream Totem
    [5421] = { passive = true, book = true, harmful = false }, -- Aquatic Form (Passive)
    [5484] = { passive = false, book = true, harmful = true }, -- Howl of Terror
    [5487] = { passive = false, book = true, harmful = false }, -- Bear Form
    [5504] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [5505] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [5506] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [5569] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [5570] = { passive = false, book = true, harmful = true }, -- Insect Swarm
    [5573] = { passive = false, book = true, harmful = false }, -- Divine Protection
    [5588] = { passive = false, book = true, harmful = true }, -- Hammer of Justice
    [5589] = { passive = false, book = true, harmful = true }, -- Hammer of Justice
    [5599] = { passive = false, book = true, harmful = false }, -- Blessing of Protection
    [5614] = { passive = false, book = true, harmful = true }, -- Exorcism
    [5615] = { passive = false, book = true, harmful = true }, -- Exorcism
    [5627] = { passive = false, book = true, harmful = true }, -- Turn Undead
    [5675] = { passive = false, book = true, harmful = false }, -- Mana Spring Totem
    [5676] = { passive = false, book = true, harmful = true }, -- Searing Pain
    [5677] = { passive = true, book = false, harmful = false }, -- Mana Spring
    [5678] = { passive = false, book = false, harmful = false }, -- Mana Spring Totem
    [5699] = { passive = false, book = true, harmful = false }, -- Create Healthstone
    [5720] = { passive = false, book = false, harmful = false }, -- Healthstone
    [5723] = { passive = false, book = false, harmful = false }, -- Greater Healthstone
    [5730] = { passive = false, book = true, harmful = false }, -- Stoneclaw Totem
    [5740] = { passive = false, book = true, harmful = true }, -- Rain of Fire
    [5763] = { passive = false, book = true, harmful = false }, -- Mind-numbing Poison
    [5782] = { passive = false, book = true, harmful = true }, -- Fear
    [5857] = { passive = false, book = true, harmful = true }, -- Hellfire Effect
    [5923] = { passive = true, book = true, harmful = false }, -- Holy Power
    [6041] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [6060] = { passive = false, book = true, harmful = true }, -- Smite
    [6063] = { passive = false, book = true, harmful = false }, -- Heal
    [6064] = { passive = false, book = true, harmful = false }, -- Heal
    [6065] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [6066] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [6074] = { passive = false, book = true, harmful = false }, -- Renew
    [6075] = { passive = false, book = true, harmful = false }, -- Renew
    [6076] = { passive = false, book = true, harmful = false }, -- Renew
    [6077] = { passive = false, book = true, harmful = false }, -- Renew
    [6078] = { passive = false, book = true, harmful = false }, -- Renew
    [6117] = { passive = false, book = true, harmful = false }, -- Mage Armor
    [6127] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [6129] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [6131] = { passive = false, book = true, harmful = true }, -- Frost Nova
    [6136] = { passive = false, book = false, harmful = true }, -- Chilled
    [6141] = { passive = false, book = true, harmful = true }, -- Blizzard
    [6143] = { passive = false, book = true, harmful = false }, -- Frost Ward
    [6150] = { passive = false, book = false, harmful = false }, -- Quick Shots
    [6178] = { passive = false, book = true, harmful = true }, -- Charge
    [6190] = { passive = false, book = true, harmful = true }, -- Demoralizing Shout
    [6192] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [6201] = { passive = false, book = true, harmful = false }, -- Create Healthstone
    [6202] = { passive = false, book = true, harmful = false }, -- Create Healthstone
    [6205] = { passive = false, book = true, harmful = true }, -- Curse of Weakness
    [6213] = { passive = false, book = true, harmful = true }, -- Fear
    [6215] = { passive = false, book = true, harmful = true }, -- Fear
    [6217] = { passive = false, book = true, harmful = true }, -- Bane of Agony
    [6219] = { passive = false, book = true, harmful = true }, -- Rain of Fire
    [6222] = { passive = false, book = true, harmful = true }, -- Corruption
    [6223] = { passive = false, book = true, harmful = true }, -- Corruption
    [6226] = { passive = false, book = true, harmful = true }, -- Drain Mana
    [6229] = { passive = false, book = true, harmful = false }, -- Shadow Ward
    [6262] = { passive = false, book = false, harmful = false }, -- Minor Healthstone
    [6263] = { passive = false, book = false, harmful = false }, -- Lesser Healthstone
    [6307] = { passive = false, book = true, harmful = false }, -- Blood Pact
    [6343] = { passive = false, book = true, harmful = true }, -- Thunder Clap
    [6346] = { passive = false, book = true, harmful = false }, -- Fear Ward
    [6353] = { passive = false, book = true, harmful = true }, -- Soul Fire
    [6358] = { passive = false, book = true, harmful = true }, -- Seduction
    [6360] = { passive = false, book = true, harmful = true }, -- Soothing Kiss
    [6363] = { passive = false, book = true, harmful = false }, -- Searing Totem
    [6364] = { passive = false, book = true, harmful = false }, -- Searing Totem
    [6365] = { passive = false, book = true, harmful = false }, -- Searing Totem
    [6366] = { passive = false, book = true, harmful = false }, -- Create Firestone
    [6375] = { passive = false, book = true, harmful = false }, -- Healing Stream Totem
    [6377] = { passive = false, book = true, harmful = false }, -- Healing Stream Totem
    [6390] = { passive = false, book = true, harmful = false }, -- Stoneclaw Totem
    [6391] = { passive = false, book = true, harmful = false }, -- Stoneclaw Totem
    [6392] = { passive = false, book = true, harmful = false }, -- Stoneclaw Totem
    [6474] = { passive = true, book = false, harmful = false }, -- Earthbind Totem Passive
    [6495] = { passive = false, book = true, harmful = false }, -- Sentry Totem
    [6546] = { passive = false, book = true, harmful = true }, -- Rend
    [6547] = { passive = false, book = true, harmful = true }, -- Rend
    [6548] = { passive = false, book = true, harmful = true }, -- Rend
    [6552] = { passive = false, book = true, harmful = true }, -- Pummel
    [6554] = { passive = false, book = true, harmful = true }, -- Pummel
    [6572] = { passive = false, book = true, harmful = true }, -- Revenge
    [6574] = { passive = false, book = true, harmful = true }, -- Revenge
    [6673] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [6756] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [6760] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [6761] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [6762] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [6768] = { passive = false, book = true, harmful = true }, -- Feint
    [6770] = { passive = false, book = true, harmful = true }, -- Sap
    [6774] = { passive = false, book = true, harmful = true }, -- Slice and Dice
    [6778] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [6780] = { passive = false, book = true, harmful = true }, -- Wrath
    [6783] = { passive = false, book = true, harmful = false }, -- Prowl
    [6785] = { passive = false, book = true, harmful = true }, -- Ravage
    [6787] = { passive = false, book = true, harmful = true }, -- Ravage
    [6788] = { passive = false, book = false, harmful = false }, -- Weakened Soul
    [6789] = { passive = false, book = true, harmful = true }, -- Death Coil
    [6795] = { passive = false, book = true, harmful = true }, -- Growl
    [6798] = { passive = false, book = true, harmful = true }, -- Bash
    [6800] = { passive = false, book = true, harmful = true }, -- Shred
    [6807] = { passive = false, book = true, harmful = true }, -- Maul
    [6808] = { passive = false, book = true, harmful = true }, -- Maul
    [6809] = { passive = false, book = true, harmful = true }, -- Maul
    [6940] = { passive = false, book = true, harmful = false }, -- Blessing of Sacrifice
    [7128] = { passive = false, book = true, harmful = false }, -- Inner Fire
    [7140] = { passive = false, book = false, harmful = true }, -- Expose Weakness
    [7294] = { passive = false, book = true, harmful = false }, -- Retribution Aura
    [7300] = { passive = false, book = true, harmful = false }, -- Frost Armor
    [7301] = { passive = false, book = true, harmful = false }, -- Frost Armor
    [7302] = { passive = false, book = true, harmful = false }, -- Ice Armor
    [7320] = { passive = false, book = true, harmful = false }, -- Ice Armor
    [7321] = { passive = false, book = false, harmful = true }, -- Chilled
    [7322] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [7328] = { passive = false, book = true, harmful = false }, -- Redemption
    [7369] = { passive = false, book = true, harmful = true }, -- Cleave
    [7372] = { passive = false, book = true, harmful = true }, -- Hamstring
    [7373] = { passive = false, book = true, harmful = true }, -- Hamstring
    [7376] = { passive = true, book = true, harmful = false }, -- Defensive Stance Passive
    [7379] = { passive = false, book = true, harmful = true }, -- Revenge
    [7381] = { passive = true, book = true, harmful = false }, -- Berserker Stance Passive
    [7384] = { passive = false, book = true, harmful = true }, -- Overpower
    [7386] = { passive = false, book = true, harmful = true }, -- Sunder Armor
    [7400] = { passive = false, book = true, harmful = true }, -- Mocking Blow
    [7402] = { passive = false, book = true, harmful = true }, -- Mocking Blow
    [7405] = { passive = false, book = true, harmful = true }, -- Sunder Armor
    [7641] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [7646] = { passive = false, book = true, harmful = true }, -- Curse of Weakness
    [7648] = { passive = false, book = true, harmful = true }, -- Corruption
    [7651] = { passive = false, book = true, harmful = true }, -- Drain Life
    [7658] = { passive = false, book = true, harmful = true }, -- Curse of Recklessness
    [7659] = { passive = false, book = true, harmful = true }, -- Curse of Recklessness
    [7744] = { passive = false, book = true, harmful = false }, -- Will of the Forsaken
    [7799] = { passive = false, book = true, harmful = true }, -- Firebolt
    [7800] = { passive = false, book = true, harmful = true }, -- Firebolt
    [7801] = { passive = false, book = true, harmful = true }, -- Firebolt
    [7802] = { passive = false, book = true, harmful = true }, -- Firebolt
    [7804] = { passive = false, book = true, harmful = false }, -- Blood Pact
    [7805] = { passive = false, book = true, harmful = false }, -- Blood Pact
    [7809] = { passive = false, book = true, harmful = true }, -- Torment
    [7810] = { passive = false, book = true, harmful = true }, -- Torment
    [7811] = { passive = false, book = true, harmful = true }, -- Torment
    [7812] = { passive = false, book = true, harmful = false }, -- Sacrifice
    [7813] = { passive = false, book = true, harmful = true }, -- Soothing Kiss
    [7814] = { passive = false, book = true, harmful = true }, -- Lash of Pain
    [7815] = { passive = false, book = true, harmful = true }, -- Lash of Pain
    [7816] = { passive = false, book = true, harmful = true }, -- Lash of Pain
    [7870] = { passive = false, book = true, harmful = false }, -- Lesser Invisibility
    [7887] = { passive = false, book = true, harmful = true }, -- Overpower
    [7918] = { passive = false, book = true, harmful = true }, -- Shoot Gun
    [7919] = { passive = false, book = true, harmful = true }, -- Shoot Crossbow
    [7922] = { passive = false, book = false, harmful = true }, -- Charge Stun
    [8004] = { passive = false, book = true, harmful = false }, -- Lesser Healing Wave
    [8005] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [8008] = { passive = false, book = true, harmful = false }, -- Lesser Healing Wave
    [8010] = { passive = false, book = true, harmful = false }, -- Lesser Healing Wave
    [8012] = { passive = false, book = true, harmful = true }, -- Purge
    [8042] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [8044] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [8045] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [8046] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [8050] = { passive = false, book = true, harmful = true }, -- Flame Shock
    [8052] = { passive = false, book = true, harmful = true }, -- Flame Shock
    [8053] = { passive = false, book = true, harmful = true }, -- Flame Shock
    [8056] = { passive = false, book = true, harmful = true }, -- Frost Shock
    [8058] = { passive = false, book = true, harmful = true }, -- Frost Shock
    [8071] = { passive = false, book = true, harmful = false }, -- Stoneskin Totem
    [8075] = { passive = false, book = true, harmful = false }, -- Strength of Earth Totem
    [8076] = { passive = true, book = false, harmful = false }, -- Strength of Earth
    [8092] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [8102] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [8103] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [8104] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [8105] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [8106] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [8122] = { passive = false, book = true, harmful = true }, -- Psychic Scream
    [8124] = { passive = false, book = true, harmful = true }, -- Psychic Scream
    [8129] = { passive = false, book = true, harmful = true }, -- Mana Burn
    [8131] = { passive = false, book = true, harmful = true }, -- Mana Burn
    [8134] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [8143] = { passive = false, book = true, harmful = false }, -- Tremor Totem
    [8145] = { passive = true, book = false, harmful = false }, -- Tremor Totem Passive
    [8154] = { passive = false, book = true, harmful = false }, -- Stoneskin Totem
    [8155] = { passive = false, book = true, harmful = false }, -- Stoneskin Totem
    [8160] = { passive = false, book = true, harmful = false }, -- Strength of Earth Totem
    [8161] = { passive = false, book = true, harmful = false }, -- Strength of Earth Totem
    [8162] = { passive = true, book = false, harmful = false }, -- Strength of Earth
    [8163] = { passive = true, book = false, harmful = false }, -- Strength of Earth
    [8166] = { passive = false, book = true, harmful = false }, -- Poison Cleansing Totem
    [8167] = { passive = true, book = false, harmful = false }, -- Poison Cleansing Totem Passive
    [8170] = { passive = false, book = true, harmful = false }, -- Disease Cleansing Totem
    [8172] = { passive = true, book = false, harmful = false }, -- Disease Cleansing Totem Passive
    [8177] = { passive = false, book = true, harmful = false }, -- Grounding Totem
    [8178] = { passive = false, book = false, harmful = false }, -- Grounding Totem
    [8179] = { passive = true, book = false, harmful = false }, -- Grounding Totem Passive
    [8181] = { passive = false, book = true, harmful = false }, -- Frost Resistance Totem
    [8182] = { passive = true, book = false, harmful = false }, -- Frost Resistance
    [8184] = { passive = false, book = true, harmful = false }, -- Fire Resistance Totem
    [8185] = { passive = true, book = false, harmful = false }, -- Fire Resistance
    [8190] = { passive = false, book = true, harmful = false }, -- Magma Totem
    [8192] = { passive = false, book = true, harmful = true }, -- Mind Soothe
    [8198] = { passive = false, book = true, harmful = true }, -- Thunder Clap
    [8204] = { passive = false, book = true, harmful = true }, -- Thunder Clap
    [8205] = { passive = false, book = true, harmful = true }, -- Thunder Clap
    [8227] = { passive = false, book = true, harmful = false }, -- Flametongue Totem
    [8230] = { passive = true, book = false, harmful = false }, -- Flametongue Totem
    [8232] = { passive = false, book = true, harmful = false }, -- Windfury Weapon
    [8235] = { passive = false, book = true, harmful = false }, -- Windfury Weapon
    [8249] = { passive = false, book = true, harmful = false }, -- Flametongue Totem
    [8250] = { passive = true, book = false, harmful = false }, -- Flametongue Totem
    [8288] = { passive = false, book = true, harmful = true }, -- Drain Soul
    [8289] = { passive = false, book = true, harmful = true }, -- Drain Soul
    [8316] = { passive = false, book = true, harmful = false }, -- Fire Shield
    [8317] = { passive = false, book = true, harmful = false }, -- Fire Shield
    [8380] = { passive = false, book = true, harmful = true }, -- Sunder Armor
    [8400] = { passive = false, book = true, harmful = true }, -- Fireball
    [8401] = { passive = false, book = true, harmful = true }, -- Fireball
    [8402] = { passive = false, book = true, harmful = true }, -- Fireball
    [8406] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [8407] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [8408] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [8412] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [8413] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [8416] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [8417] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [8422] = { passive = false, book = true, harmful = true }, -- Flamestrike
    [8423] = { passive = false, book = true, harmful = true }, -- Flamestrike
    [8427] = { passive = false, book = true, harmful = true }, -- Blizzard
    [8437] = { passive = false, book = true, harmful = true }, -- Arcane Explosion
    [8438] = { passive = false, book = true, harmful = true }, -- Arcane Explosion
    [8439] = { passive = false, book = true, harmful = true }, -- Arcane Explosion
    [8443] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [8444] = { passive = false, book = true, harmful = true }, -- Scorch
    [8445] = { passive = false, book = true, harmful = true }, -- Scorch
    [8446] = { passive = false, book = true, harmful = true }, -- Scorch
    [8450] = { passive = false, book = true, harmful = false }, -- Dampen Magic
    [8451] = { passive = false, book = true, harmful = false }, -- Dampen Magic
    [8455] = { passive = false, book = true, harmful = false }, -- Amplify Magic
    [8457] = { passive = false, book = true, harmful = false }, -- Fire Ward
    [8458] = { passive = false, book = true, harmful = false }, -- Fire Ward
    [8461] = { passive = false, book = true, harmful = false }, -- Frost Ward
    [8462] = { passive = false, book = true, harmful = false }, -- Frost Ward
    [8492] = { passive = false, book = true, harmful = true }, -- Cone of Cold
    [8494] = { passive = false, book = true, harmful = false }, -- Mana Shield
    [8495] = { passive = false, book = true, harmful = false }, -- Mana Shield
    [8504] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [8505] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [8512] = { passive = false, book = true, harmful = false }, -- Windfury Totem
    [8515] = { passive = true, book = false, harmful = false }, -- Windfury Totem
    [8621] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [8623] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [8624] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [8629] = { passive = false, book = true, harmful = true }, -- Gouge
    [8631] = { passive = false, book = true, harmful = true }, -- Garrote
    [8632] = { passive = false, book = true, harmful = true }, -- Garrote
    [8633] = { passive = false, book = true, harmful = true }, -- Garrote
    [8637] = { passive = false, book = true, harmful = true }, -- Feint
    [8639] = { passive = false, book = true, harmful = true }, -- Rupture
    [8640] = { passive = false, book = true, harmful = true }, -- Rupture
    [8643] = { passive = false, book = true, harmful = true }, -- Kidney Shot
    [8647] = { passive = false, book = true, harmful = true }, -- Expose Armor
    [8649] = { passive = false, book = true, harmful = true }, -- Expose Armor
    [8650] = { passive = false, book = true, harmful = true }, -- Expose Armor
    [8676] = { passive = false, book = true, harmful = true }, -- Ambush
    [8681] = { passive = false, book = true, harmful = false }, -- Instant Poison
    [8687] = { passive = false, book = true, harmful = false }, -- Instant Poison II
    [8691] = { passive = false, book = true, harmful = false }, -- Instant Poison III
    [8694] = { passive = false, book = true, harmful = false }, -- Mind-numbing Poison II
    [8696] = { passive = false, book = true, harmful = false }, -- Sprint
    [8721] = { passive = false, book = true, harmful = true }, -- Backstab
    [8724] = { passive = false, book = true, harmful = true }, -- Ambush
    [8725] = { passive = false, book = true, harmful = true }, -- Ambush
    [8820] = { passive = false, book = true, harmful = true }, -- Slam
    [8835] = { passive = false, book = true, harmful = false }, -- Grace of Air Totem
    [8836] = { passive = true, book = false, harmful = false }, -- Grace of Air
    [8875] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [8903] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [8905] = { passive = false, book = true, harmful = true }, -- Wrath
    [8907] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [8910] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [8914] = { passive = false, book = true, harmful = false }, -- Thorns
    [8918] = { passive = false, book = true, harmful = false }, -- Tranquility
    [8921] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8924] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8925] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8926] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8927] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8928] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8929] = { passive = false, book = true, harmful = true }, -- Moonfire
    [8936] = { passive = false, book = true, harmful = false }, -- Regrowth
    [8938] = { passive = false, book = true, harmful = false }, -- Regrowth
    [8939] = { passive = false, book = true, harmful = false }, -- Regrowth
    [8940] = { passive = false, book = true, harmful = false }, -- Regrowth
    [8941] = { passive = false, book = true, harmful = false }, -- Regrowth
    [8946] = { passive = false, book = true, harmful = false }, -- Cure Poison
    [8949] = { passive = false, book = true, harmful = true }, -- Starfire
    [8950] = { passive = false, book = true, harmful = true }, -- Starfire
    [8951] = { passive = false, book = true, harmful = true }, -- Starfire
    [8955] = { passive = false, book = true, harmful = true }, -- Soothe Animal
    [8972] = { passive = false, book = true, harmful = true }, -- Maul
    [8983] = { passive = false, book = true, harmful = true }, -- Bash
    [8992] = { passive = false, book = true, harmful = true }, -- Shred
    [8998] = { passive = false, book = true, harmful = true }, -- Cower
    [9000] = { passive = false, book = true, harmful = true }, -- Cower
    [9005] = { passive = false, book = true, harmful = true }, -- Pounce
    [9007] = { passive = false, book = true, harmful = true }, -- Pounce Bleed
    [9035] = { passive = false, book = true, harmful = true }, -- Hex of Weakness
    [9178] = { passive = false, book = false, harmful = false }, -- Brain Freeze
    [9472] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [9473] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [9474] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [9484] = { passive = false, book = true, harmful = true }, -- Shackle Undead
    [9485] = { passive = false, book = true, harmful = true }, -- Shackle Undead
    [9490] = { passive = false, book = true, harmful = true }, -- Demoralizing Roar
    [9492] = { passive = false, book = true, harmful = true }, -- Rip
    [9493] = { passive = false, book = true, harmful = true }, -- Rip
    [9578] = { passive = false, book = true, harmful = false }, -- Fade
    [9579] = { passive = false, book = true, harmful = false }, -- Fade
    [9592] = { passive = false, book = true, harmful = false }, -- Fade
    [9634] = { passive = false, book = true, harmful = false }, -- Dire Bear Form
    [9635] = { passive = true, book = true, harmful = false }, -- Dire Bear Form (Passive)
    [9745] = { passive = false, book = true, harmful = true }, -- Maul
    [9747] = { passive = false, book = true, harmful = true }, -- Demoralizing Roar
    [9749] = { passive = false, book = true, harmful = true }, -- Faerie Fire
    [9750] = { passive = false, book = true, harmful = false }, -- Regrowth
    [9752] = { passive = false, book = true, harmful = true }, -- Rip
    [9754] = { passive = false, book = true, harmful = true }, -- Swipe
    [9756] = { passive = false, book = true, harmful = false }, -- Thorns
    [9758] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [9821] = { passive = false, book = true, harmful = false }, -- Dash
    [9823] = { passive = false, book = true, harmful = true }, -- Pounce
    [9824] = { passive = false, book = true, harmful = true }, -- Pounce Bleed
    [9826] = { passive = false, book = true, harmful = true }, -- Pounce Bleed
    [9827] = { passive = false, book = true, harmful = true }, -- Pounce
    [9829] = { passive = false, book = true, harmful = true }, -- Shred
    [9830] = { passive = false, book = true, harmful = true }, -- Shred
    [9833] = { passive = false, book = true, harmful = true }, -- Moonfire
    [9834] = { passive = false, book = true, harmful = true }, -- Moonfire
    [9835] = { passive = false, book = true, harmful = true }, -- Moonfire
    [9839] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [9840] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [9841] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [9849] = { passive = false, book = true, harmful = true }, -- Claw
    [9850] = { passive = false, book = true, harmful = true }, -- Claw
    [9852] = { passive = false, book = true, harmful = true }, -- Entangling Roots
    [9853] = { passive = false, book = true, harmful = true }, -- Entangling Roots
    [9856] = { passive = false, book = true, harmful = false }, -- Regrowth
    [9857] = { passive = false, book = true, harmful = false }, -- Regrowth
    [9858] = { passive = false, book = true, harmful = false }, -- Regrowth
    [9862] = { passive = false, book = true, harmful = false }, -- Tranquility
    [9863] = { passive = false, book = true, harmful = false }, -- Tranquility
    [9866] = { passive = false, book = true, harmful = true }, -- Ravage
    [9867] = { passive = false, book = true, harmful = true }, -- Ravage
    [9875] = { passive = false, book = true, harmful = true }, -- Starfire
    [9876] = { passive = false, book = true, harmful = true }, -- Starfire
    [9880] = { passive = false, book = true, harmful = true }, -- Maul
    [9881] = { passive = false, book = true, harmful = true }, -- Maul
    [9884] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [9885] = { passive = false, book = true, harmful = false }, -- Mark of the Wild
    [9888] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [9889] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [9892] = { passive = false, book = true, harmful = true }, -- Cower
    [9894] = { passive = false, book = true, harmful = true }, -- Rip
    [9896] = { passive = false, book = true, harmful = true }, -- Rip
    [9898] = { passive = false, book = true, harmful = true }, -- Demoralizing Roar
    [9901] = { passive = false, book = true, harmful = true }, -- Soothe Animal
    [9904] = { passive = false, book = true, harmful = true }, -- Rake
    [9907] = { passive = false, book = true, harmful = true }, -- Faerie Fire
    [9908] = { passive = false, book = true, harmful = true }, -- Swipe
    [9910] = { passive = false, book = true, harmful = false }, -- Thorns
    [9912] = { passive = false, book = true, harmful = true }, -- Wrath
    [9913] = { passive = false, book = true, harmful = false }, -- Prowl
    [10053] = { passive = false, book = true, harmful = false }, -- Conjure Mana Citrine
    [10054] = { passive = false, book = true, harmful = false }, -- Conjure Mana Ruby
    [10059] = { passive = false, book = true, harmful = false }, -- Portal: Stormwind
    [10060] = { passive = false, book = true, harmful = false }, -- Power Infusion
    [10138] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [10139] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [10140] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [10144] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [10145] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [10148] = { passive = false, book = true, harmful = true }, -- Fireball
    [10149] = { passive = false, book = true, harmful = true }, -- Fireball
    [10150] = { passive = false, book = true, harmful = true }, -- Fireball
    [10151] = { passive = false, book = true, harmful = true }, -- Fireball
    [10156] = { passive = false, book = true, harmful = false }, -- Arcane Intellect
    [10157] = { passive = false, book = true, harmful = false }, -- Arcane Intellect
    [10159] = { passive = false, book = true, harmful = true }, -- Cone of Cold
    [10160] = { passive = false, book = true, harmful = true }, -- Cone of Cold
    [10161] = { passive = false, book = true, harmful = true }, -- Cone of Cold
    [10169] = { passive = false, book = true, harmful = false }, -- Amplify Magic
    [10170] = { passive = false, book = true, harmful = false }, -- Amplify Magic
    [10173] = { passive = false, book = true, harmful = false }, -- Dampen Magic
    [10174] = { passive = false, book = true, harmful = false }, -- Dampen Magic
    [10177] = { passive = false, book = true, harmful = false }, -- Frost Ward
    [10179] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [10180] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [10181] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [10185] = { passive = false, book = true, harmful = true }, -- Blizzard
    [10186] = { passive = false, book = true, harmful = true }, -- Blizzard
    [10187] = { passive = false, book = true, harmful = true }, -- Blizzard
    [10191] = { passive = false, book = true, harmful = false }, -- Mana Shield
    [10192] = { passive = false, book = true, harmful = false }, -- Mana Shield
    [10193] = { passive = false, book = true, harmful = false }, -- Mana Shield
    [10197] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [10199] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [10201] = { passive = false, book = true, harmful = true }, -- Arcane Explosion
    [10202] = { passive = false, book = true, harmful = true }, -- Arcane Explosion
    [10205] = { passive = false, book = true, harmful = true }, -- Scorch
    [10206] = { passive = false, book = true, harmful = true }, -- Scorch
    [10207] = { passive = false, book = true, harmful = true }, -- Scorch
    [10211] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [10212] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [10215] = { passive = false, book = true, harmful = true }, -- Flamestrike
    [10216] = { passive = false, book = true, harmful = true }, -- Flamestrike
    [10219] = { passive = false, book = true, harmful = false }, -- Ice Armor
    [10220] = { passive = false, book = true, harmful = false }, -- Ice Armor
    [10223] = { passive = false, book = true, harmful = false }, -- Fire Ward
    [10225] = { passive = false, book = true, harmful = false }, -- Fire Ward
    [10230] = { passive = false, book = true, harmful = true }, -- Frost Nova
    [10278] = { passive = false, book = true, harmful = false }, -- Blessing of Protection
    [10290] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [10291] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [10292] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [10293] = { passive = false, book = true, harmful = false }, -- Devotion Aura
    [10298] = { passive = false, book = true, harmful = false }, -- Retribution Aura
    [10299] = { passive = false, book = true, harmful = false }, -- Retribution Aura
    [10300] = { passive = false, book = true, harmful = false }, -- Retribution Aura
    [10301] = { passive = false, book = true, harmful = false }, -- Retribution Aura
    [10308] = { passive = false, book = true, harmful = true }, -- Hammer of Justice
    [10310] = { passive = false, book = true, harmful = false }, -- Lay on Hands
    [10312] = { passive = false, book = true, harmful = true }, -- Exorcism
    [10313] = { passive = false, book = true, harmful = true }, -- Exorcism
    [10314] = { passive = false, book = true, harmful = true }, -- Exorcism
    [10318] = { passive = false, book = true, harmful = true }, -- Holy Wrath
    [10322] = { passive = false, book = true, harmful = false }, -- Redemption
    [10324] = { passive = false, book = true, harmful = false }, -- Redemption
    [10326] = { passive = false, book = true, harmful = true }, -- Turn Undead
    [10328] = { passive = false, book = true, harmful = false }, -- Holy Light
    [10329] = { passive = false, book = true, harmful = false }, -- Holy Light
    [10332] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [10333] = { passive = false, book = true, harmful = true }, -- Holy Strike
    [10391] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [10392] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [10395] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [10396] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [10406] = { passive = false, book = true, harmful = false }, -- Stoneskin Totem
    [10407] = { passive = false, book = true, harmful = false }, -- Stoneskin Totem
    [10408] = { passive = false, book = true, harmful = false }, -- Stoneskin Totem
    [10412] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [10413] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [10414] = { passive = false, book = true, harmful = true }, -- Earth Shock
    [10427] = { passive = false, book = true, harmful = false }, -- Stoneclaw Totem
    [10428] = { passive = false, book = true, harmful = false }, -- Stoneclaw Totem
    [10431] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [10432] = { passive = false, book = true, harmful = false }, -- Lightning Shield
    [10437] = { passive = false, book = true, harmful = false }, -- Searing Totem
    [10438] = { passive = false, book = true, harmful = false }, -- Searing Totem
    [10441] = { passive = true, book = false, harmful = false }, -- Strength of Earth
    [10442] = { passive = false, book = true, harmful = false }, -- Strength of Earth Totem
    [10447] = { passive = false, book = true, harmful = true }, -- Flame Shock
    [10448] = { passive = false, book = true, harmful = true }, -- Flame Shock
    [10462] = { passive = false, book = true, harmful = false }, -- Healing Stream Totem
    [10463] = { passive = false, book = true, harmful = false }, -- Healing Stream Totem
    [10466] = { passive = false, book = true, harmful = false }, -- Lesser Healing Wave
    [10467] = { passive = false, book = true, harmful = false }, -- Lesser Healing Wave
    [10468] = { passive = false, book = true, harmful = false }, -- Lesser Healing Wave
    [10472] = { passive = false, book = true, harmful = true }, -- Frost Shock
    [10473] = { passive = false, book = true, harmful = true }, -- Frost Shock
    [10476] = { passive = true, book = false, harmful = false }, -- Frost Resistance
    [10477] = { passive = true, book = false, harmful = false }, -- Frost Resistance
    [10478] = { passive = false, book = true, harmful = false }, -- Frost Resistance Totem
    [10479] = { passive = false, book = true, harmful = false }, -- Frost Resistance Totem
    [10486] = { passive = false, book = true, harmful = false }, -- Windfury Weapon
    [10491] = { passive = true, book = false, harmful = false }, -- Mana Spring
    [10493] = { passive = true, book = false, harmful = false }, -- Mana Spring
    [10494] = { passive = true, book = false, harmful = false }, -- Mana Spring
    [10495] = { passive = false, book = true, harmful = false }, -- Mana Spring Totem
    [10496] = { passive = false, book = true, harmful = false }, -- Mana Spring Totem
    [10497] = { passive = false, book = true, harmful = false }, -- Mana Spring Totem
    [10521] = { passive = true, book = false, harmful = false }, -- Flametongue Totem
    [10526] = { passive = false, book = true, harmful = false }, -- Flametongue Totem
    [10534] = { passive = true, book = false, harmful = false }, -- Fire Resistance
    [10535] = { passive = true, book = false, harmful = false }, -- Fire Resistance
    [10537] = { passive = false, book = true, harmful = false }, -- Fire Resistance Totem
    [10538] = { passive = false, book = true, harmful = false }, -- Fire Resistance Totem
    [10585] = { passive = false, book = true, harmful = false }, -- Magma Totem
    [10586] = { passive = false, book = true, harmful = false }, -- Magma Totem
    [10587] = { passive = false, book = true, harmful = false }, -- Magma Totem
    [10595] = { passive = false, book = true, harmful = false }, -- Nature Resistance Totem
    [10600] = { passive = false, book = true, harmful = false }, -- Nature Resistance Totem
    [10601] = { passive = false, book = true, harmful = false }, -- Nature Resistance Totem
    [10605] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [10609] = { passive = true, book = false, harmful = false }, -- Windfury Totem
    [10612] = { passive = true, book = false, harmful = false }, -- Windfury Totem
    [10613] = { passive = false, book = true, harmful = false }, -- Windfury Totem
    [10614] = { passive = false, book = true, harmful = false }, -- Windfury Totem
    [10622] = { passive = false, book = true, harmful = false }, -- Chain Heal
    [10623] = { passive = false, book = true, harmful = false }, -- Chain Heal
    [10626] = { passive = true, book = false, harmful = false }, -- Grace of Air
    [10627] = { passive = false, book = true, harmful = false }, -- Grace of Air Totem
    [10797] = { passive = false, book = true, harmful = true }, -- Starshards
    [10874] = { passive = false, book = true, harmful = true }, -- Mana Burn
    [10875] = { passive = false, book = true, harmful = true }, -- Mana Burn
    [10876] = { passive = false, book = true, harmful = true }, -- Mana Burn
    [10880] = { passive = false, book = true, harmful = false }, -- Resurrection
    [10881] = { passive = false, book = true, harmful = false }, -- Resurrection
    [10888] = { passive = false, book = true, harmful = true }, -- Psychic Scream
    [10890] = { passive = false, book = true, harmful = true }, -- Psychic Scream
    [10892] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [10893] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [10894] = { passive = false, book = true, harmful = true }, -- Shadow Word: Pain
    [10898] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [10899] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [10900] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [10901] = { passive = false, book = true, harmful = false }, -- Power Word: Shield
    [10909] = { passive = false, book = true, harmful = false }, -- Mind Vision
    [10911] = { passive = false, book = true, harmful = true }, -- Mind Control
    [10912] = { passive = false, book = true, harmful = true }, -- Mind Control
    [10915] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [10916] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [10917] = { passive = false, book = true, harmful = false }, -- Flash Heal
    [10927] = { passive = false, book = true, harmful = false }, -- Renew
    [10928] = { passive = false, book = true, harmful = false }, -- Renew
    [10929] = { passive = false, book = true, harmful = false }, -- Renew
    [10933] = { passive = false, book = true, harmful = true }, -- Smite
    [10934] = { passive = false, book = true, harmful = true }, -- Smite
    [10937] = { passive = false, book = true, harmful = false }, -- Power Word: Fortitude
    [10938] = { passive = false, book = true, harmful = false }, -- Power Word: Fortitude
    [10941] = { passive = false, book = true, harmful = false }, -- Fade
    [10942] = { passive = false, book = true, harmful = false }, -- Fade
    [10945] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [10946] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [10947] = { passive = false, book = true, harmful = true }, -- Mind Blast
    [10951] = { passive = false, book = true, harmful = false }, -- Inner Fire
    [10952] = { passive = false, book = true, harmful = false }, -- Inner Fire
    [10953] = { passive = false, book = true, harmful = true }, -- Mind Soothe
    [10955] = { passive = false, book = true, harmful = true }, -- Shackle Undead
    [10957] = { passive = false, book = true, harmful = false }, -- Shadow Protection
    [10958] = { passive = false, book = true, harmful = false }, -- Shadow Protection
    [10960] = { passive = false, book = true, harmful = false }, -- Prayer of Healing
    [10961] = { passive = false, book = true, harmful = false }, -- Prayer of Healing
    [10963] = { passive = false, book = true, harmful = false }, -- Greater Heal
    [10964] = { passive = false, book = true, harmful = false }, -- Greater Heal
    [10965] = { passive = false, book = true, harmful = false }, -- Greater Heal
    [11069] = { passive = true, book = true, harmful = false }, -- Accelerant
    [11070] = { passive = true, book = true, harmful = false }, -- Improved Frostbolt
    [11071] = { passive = true, book = true, harmful = false }, -- Frostbite
    [11078] = { passive = true, book = true, harmful = false }, -- Improved Fire Blast
    [11083] = { passive = true, book = true, harmful = false }, -- Burning Soul
    [11094] = { passive = true, book = true, harmful = false }, -- Improved Fire Ward
    [11095] = { passive = true, book = true, harmful = true }, -- Improved Scorch
    [11100] = { passive = true, book = true, harmful = false }, -- Flame Throwing
    [11103] = { passive = true, book = true, harmful = false }, -- Impact
    [11108] = { passive = true, book = true, harmful = false }, -- Improved Flamestrike
    [11113] = { passive = false, book = true, harmful = true }, -- Blast Wave
    [11115] = { passive = true, book = true, harmful = false }, -- Critical Mass
    [11119] = { passive = true, book = true, harmful = false }, -- Ignite
    [11124] = { passive = true, book = true, harmful = false }, -- Fire Power
    [11129] = { passive = false, book = true, harmful = false }, -- Combustion
    [11151] = { passive = true, book = true, harmful = false }, -- Piercing Ice
    [11160] = { passive = true, book = true, harmful = false }, -- Frost Channeling
    [11165] = { passive = true, book = true, harmful = false }, -- Improved Frost Nova
    [11170] = { passive = true, book = true, harmful = false }, -- Shatter
    [11175] = { passive = true, book = true, harmful = false }, -- Permafrost
    [11180] = { passive = true, book = true, harmful = false }, -- Winter's Chill
    [11185] = { passive = true, book = true, harmful = false }, -- Improved Blizzard
    [11189] = { passive = true, book = true, harmful = false }, -- Frost Warding
    [11190] = { passive = true, book = true, harmful = false }, -- Improved Cone of Cold
    [11197] = { passive = false, book = true, harmful = true }, -- Expose Armor
    [11198] = { passive = false, book = true, harmful = true }, -- Expose Armor
    [11207] = { passive = true, book = true, harmful = false }, -- Ice Shards
    [11210] = { passive = true, book = true, harmful = false }, -- Arcane Subtlety
    [11213] = { passive = true, book = true, harmful = false }, -- Arcane Concentration
    [11222] = { passive = true, book = true, harmful = false }, -- Arcane Focus
    [11232] = { passive = true, book = true, harmful = false }, -- Arcane Mind
    [11237] = { passive = true, book = true, harmful = false }, -- Improved Channeling
    [11242] = { passive = true, book = true, harmful = false }, -- Arcane Impact
    [11247] = { passive = true, book = true, harmful = false }, -- Arcane Geometry
    [11252] = { passive = true, book = true, harmful = false }, -- Arcane Shielding
    [11255] = { passive = true, book = true, harmful = false }, -- Improved Counterspell
    [11267] = { passive = false, book = true, harmful = true }, -- Ambush
    [11268] = { passive = false, book = true, harmful = true }, -- Ambush
    [11269] = { passive = false, book = true, harmful = true }, -- Ambush
    [11273] = { passive = false, book = true, harmful = true }, -- Rupture
    [11274] = { passive = false, book = true, harmful = true }, -- Rupture
    [11275] = { passive = false, book = true, harmful = true }, -- Rupture
    [11279] = { passive = false, book = true, harmful = true }, -- Backstab
    [11280] = { passive = false, book = true, harmful = true }, -- Backstab
    [11281] = { passive = false, book = true, harmful = true }, -- Backstab
    [11285] = { passive = false, book = true, harmful = true }, -- Gouge
    [11286] = { passive = false, book = true, harmful = true }, -- Gouge
    [11289] = { passive = false, book = true, harmful = true }, -- Garrote
    [11290] = { passive = false, book = true, harmful = true }, -- Garrote
    [11293] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [11294] = { passive = false, book = true, harmful = true }, -- Sinister Strike
    [11297] = { passive = false, book = true, harmful = true }, -- Sap
    [11299] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [11300] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [11303] = { passive = false, book = true, harmful = true }, -- Feint
    [11305] = { passive = false, book = true, harmful = false }, -- Sprint
    [11310] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [11311] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [11327] = { passive = false, book = false, harmful = false }, -- Vanish
    [11329] = { passive = false, book = false, harmful = false }, -- Vanish
    [11341] = { passive = false, book = true, harmful = false }, -- Instant Poison IV
    [11342] = { passive = false, book = true, harmful = false }, -- Instant Poison V
    [11343] = { passive = false, book = true, harmful = false }, -- Instant Poison VI
    [11357] = { passive = false, book = true, harmful = false }, -- Deadly Poison III
    [11358] = { passive = false, book = true, harmful = false }, -- Deadly Poison IV
    [11359] = { passive = false, book = false, harmful = false }, -- Restoration
    [11366] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [11400] = { passive = false, book = true, harmful = false }, -- Mind-numbing Poison III
    [11416] = { passive = false, book = true, harmful = false }, -- Portal: Ironforge
    [11417] = { passive = false, book = true, harmful = false }, -- Portal: Orgrimmar
    [11418] = { passive = false, book = true, harmful = false }, -- Portal: Undercity
    [11419] = { passive = false, book = true, harmful = false }, -- Portal: Darnassus
    [11420] = { passive = false, book = true, harmful = false }, -- Portal: Thunder Bluff
    [11426] = { passive = false, book = true, harmful = false }, -- Ice Barrier
    [11549] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [11550] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [11551] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [11554] = { passive = false, book = true, harmful = true }, -- Demoralizing Shout
    [11555] = { passive = false, book = true, harmful = true }, -- Demoralizing Shout
    [11556] = { passive = false, book = true, harmful = true }, -- Demoralizing Shout
    [11564] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [11565] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [11566] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [11567] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [11572] = { passive = false, book = true, harmful = true }, -- Rend
    [11573] = { passive = false, book = true, harmful = true }, -- Rend
    [11574] = { passive = false, book = true, harmful = true }, -- Rend
    [11578] = { passive = false, book = true, harmful = true }, -- Charge
    [11580] = { passive = false, book = true, harmful = true }, -- Thunder Clap
    [11581] = { passive = false, book = true, harmful = true }, -- Thunder Clap
    [11584] = { passive = false, book = true, harmful = true }, -- Overpower
    [11585] = { passive = false, book = true, harmful = true }, -- Overpower
    [11596] = { passive = false, book = true, harmful = true }, -- Sunder Armor
    [11597] = { passive = false, book = true, harmful = true }, -- Sunder Armor
    [11600] = { passive = false, book = true, harmful = true }, -- Revenge
    [11601] = { passive = false, book = true, harmful = true }, -- Revenge
    [11604] = { passive = false, book = true, harmful = true }, -- Slam
    [11605] = { passive = false, book = true, harmful = true }, -- Slam
    [11608] = { passive = false, book = true, harmful = true }, -- Cleave
    [11609] = { passive = false, book = true, harmful = true }, -- Cleave
    [11659] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [11660] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [11661] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [11665] = { passive = false, book = true, harmful = true }, -- Immolate
    [11667] = { passive = false, book = true, harmful = true }, -- Immolate
    [11668] = { passive = false, book = true, harmful = true }, -- Immolate
    [11671] = { passive = false, book = true, harmful = true }, -- Corruption
    [11672] = { passive = false, book = true, harmful = true }, -- Corruption
    [11675] = { passive = false, book = true, harmful = true }, -- Drain Soul
    [11677] = { passive = false, book = true, harmful = true }, -- Rain of Fire
    [11678] = { passive = false, book = true, harmful = true }, -- Rain of Fire
    [11681] = { passive = false, book = true, harmful = true }, -- Hellfire Effect
    [11682] = { passive = false, book = true, harmful = true }, -- Hellfire Effect
    [11683] = { passive = false, book = true, harmful = false }, -- Hellfire
    [11684] = { passive = false, book = true, harmful = false }, -- Hellfire
    [11687] = { passive = false, book = true, harmful = false }, -- Life Tap
    [11688] = { passive = false, book = true, harmful = false }, -- Life Tap
    [11689] = { passive = false, book = true, harmful = false }, -- Life Tap
    [11693] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [11694] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [11695] = { passive = false, book = true, harmful = false }, -- Health Funnel
    [11699] = { passive = false, book = true, harmful = true }, -- Drain Life
    [11700] = { passive = false, book = true, harmful = true }, -- Drain Life
    [11703] = { passive = false, book = true, harmful = true }, -- Drain Mana
    [11704] = { passive = false, book = true, harmful = true }, -- Drain Mana
    [11707] = { passive = false, book = true, harmful = true }, -- Curse of Weakness
    [11708] = { passive = false, book = true, harmful = true }, -- Curse of Weakness
    [11711] = { passive = false, book = true, harmful = true }, -- Bane of Agony
    [11712] = { passive = false, book = true, harmful = true }, -- Bane of Agony
    [11713] = { passive = false, book = true, harmful = true }, -- Bane of Agony
    [11717] = { passive = false, book = true, harmful = true }, -- Curse of Recklessness
    [11719] = { passive = false, book = true, harmful = true }, -- Curse of Tongues
    [11725] = { passive = false, book = true, harmful = true }, -- Subjugate Demon
    [11726] = { passive = false, book = true, harmful = true }, -- Subjugate Demon
    [11729] = { passive = false, book = true, harmful = false }, -- Create Healthstone
    [11730] = { passive = false, book = true, harmful = false }, -- Create Healthstone
    [11732] = { passive = false, book = false, harmful = false }, -- Major Healthstone
    [11733] = { passive = false, book = true, harmful = false }, -- Demon Armor
    [11734] = { passive = false, book = true, harmful = false }, -- Demon Armor
    [11735] = { passive = false, book = true, harmful = false }, -- Demon Armor
    [11739] = { passive = false, book = true, harmful = false }, -- Shadow Ward
    [11740] = { passive = false, book = true, harmful = false }, -- Shadow Ward
    [11743] = { passive = false, book = true, harmful = false }, -- Detect Invisibility
    [11762] = { passive = false, book = true, harmful = true }, -- Firebolt
    [11763] = { passive = false, book = true, harmful = true }, -- Firebolt
    [11766] = { passive = false, book = true, harmful = false }, -- Blood Pact
    [11767] = { passive = false, book = true, harmful = false }, -- Blood Pact
    [11770] = { passive = false, book = true, harmful = false }, -- Fire Shield
    [11771] = { passive = false, book = true, harmful = false }, -- Fire Shield
    [11774] = { passive = false, book = true, harmful = true }, -- Torment
    [11775] = { passive = false, book = true, harmful = true }, -- Torment
    [11778] = { passive = false, book = true, harmful = true }, -- Lash of Pain
    [11779] = { passive = false, book = true, harmful = true }, -- Lash of Pain
    [11780] = { passive = false, book = true, harmful = true }, -- Lash of Pain
    [11784] = { passive = false, book = true, harmful = true }, -- Soothing Kiss
    [11785] = { passive = false, book = true, harmful = true }, -- Soothing Kiss
    [11958] = { passive = false, book = true, harmful = false }, -- Ice Block
    [12021] = { passive = false, book = false, harmful = true }, -- Fixate
    [12042] = { passive = false, book = true, harmful = false }, -- Arcane Power
    [12043] = { passive = false, book = true, harmful = false }, -- Presence of Mind
    [12051] = { passive = false, book = true, harmful = false }, -- Evocation
    [12282] = { passive = true, book = true, harmful = false }, -- Improved Heroic Strike
    [12285] = { passive = true, book = true, harmful = false }, -- Improved Charge
    [12286] = { passive = true, book = true, harmful = false }, -- Improved Rend
    [12287] = { passive = true, book = true, harmful = false }, -- Improved Thunder Clap
    [12288] = { passive = true, book = true, harmful = false }, -- Improved Pummel
    [12289] = { passive = true, book = true, harmful = true }, -- Improved Hamstring
    [12290] = { passive = true, book = true, harmful = false }, -- Improved Overpower
    [12292] = { passive = false, book = true, harmful = false }, -- Sweeping Strikes
    [12294] = { passive = false, book = true, harmful = true }, -- Mortal Strike
    [12295] = { passive = true, book = true, harmful = false }, -- Improved Tactical Mastery
    [12301] = { passive = true, book = true, harmful = false }, -- Improved Bloodrage
    [12302] = { passive = true, book = true, harmful = false }, -- Improved Taunt
    [12307] = { passive = true, book = true, harmful = false }, -- Improved Shield Block
    [12308] = { passive = true, book = true, harmful = false }, -- Improved Sunder Armor
    [12311] = { passive = true, book = true, harmful = false }, -- Improved Shield Bash
    [12312] = { passive = true, book = true, harmful = false }, -- Improved Shield Wall
    [12313] = { passive = true, book = true, harmful = false }, -- Improved Disarm
    [12317] = { passive = true, book = true, harmful = false }, -- Enrage
    [12318] = { passive = true, book = true, harmful = false }, -- Improved Battle Shout
    [12319] = { passive = true, book = true, harmful = false }, -- Flurry
    [12321] = { passive = true, book = true, harmful = false }, -- Booming Voice
    [12323] = { passive = false, book = true, harmful = true }, -- Piercing Howl
    [12324] = { passive = true, book = true, harmful = false }, -- Improved Demoralizing Shout
    [12327] = { passive = true, book = true, harmful = false }, -- Improved Challenging Shout
    [12328] = { passive = false, book = true, harmful = false }, -- Death Wish
    [12329] = { passive = true, book = true, harmful = false }, -- Improved Cleave
    [12355] = { passive = false, book = true, harmful = true }, -- Impact
    [12472] = { passive = false, book = true, harmful = false }, -- Cold Snap
    [12484] = { passive = false, book = true, harmful = true }, -- Chilled
    [12494] = { passive = false, book = true, harmful = true }, -- Frostbite
    [12505] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [12522] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [12523] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [12524] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [12525] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [12526] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [12529] = { passive = true, book = false, harmful = false }, -- Chilling Touch
    [12531] = { passive = false, book = false, harmful = true }, -- Chilling Touch
    [12536] = { passive = false, book = true, harmful = false }, -- Clearcasting
    [12544] = { passive = false, book = false, harmful = false }, -- Frost Armor
    [12556] = { passive = true, book = false, harmful = false }, -- Frost Armor
    [12579] = { passive = false, book = false, harmful = true }, -- Winter's Chill
    [12606] = { passive = true, book = true, harmful = false }, -- Magic Attunement
    [12707] = { passive = true, book = true, harmful = false }, -- Improved Pummel
    [12708] = { passive = true, book = true, harmful = false }, -- Improved Pummel
    [12765] = { passive = true, book = true, harmful = false }, -- Improved Taunt
    [12797] = { passive = true, book = true, harmful = false }, -- Improved Revenge
    [12809] = { passive = false, book = true, harmful = true }, -- Concussion Blow
    [12824] = { passive = false, book = true, harmful = true }, -- Polymorph
    [12825] = { passive = false, book = true, harmful = true }, -- Polymorph
    [12826] = { passive = false, book = true, harmful = true }, -- Polymorph
    [12834] = { passive = true, book = true, harmful = false }, -- Deep Wounds
    [12857] = { passive = true, book = true, harmful = false }, -- Improved Battle Shout
    [12858] = { passive = true, book = true, harmful = false }, -- Improved Battle Shout
    [12860] = { passive = true, book = true, harmful = false }, -- Improved Battle Shout
    [12861] = { passive = true, book = true, harmful = false }, -- Improved Battle Shout
    [12862] = { passive = true, book = true, harmful = false }, -- Improved Slam
    [12876] = { passive = true, book = true, harmful = false }, -- Improved Demoralizing Shout
    [12877] = { passive = true, book = true, harmful = false }, -- Improved Demoralizing Shout
    [12878] = { passive = true, book = true, harmful = false }, -- Improved Demoralizing Shout
    [12879] = { passive = true, book = true, harmful = false }, -- Improved Demoralizing Shout
    [12880] = { passive = false, book = false, harmful = false }, -- Enrage
    [12886] = { passive = true, book = true, harmful = false }, -- Improved Challenging Shout
    [12944] = { passive = true, book = true, harmful = false }, -- Improved Shield Block
    [12945] = { passive = true, book = true, harmful = false }, -- Improved Shield Block
    [12963] = { passive = true, book = true, harmful = false }, -- Improved Overpower
    [12966] = { passive = false, book = true, harmful = false }, -- Flurry
    [12975] = { passive = false, book = true, harmful = false }, -- Last Stand
    [12976] = { passive = false, book = true, harmful = false }, -- Last Stand
    [13018] = { passive = false, book = true, harmful = true }, -- Blast Wave
    [13019] = { passive = false, book = true, harmful = true }, -- Blast Wave
    [13020] = { passive = false, book = true, harmful = true }, -- Blast Wave
    [13021] = { passive = false, book = true, harmful = true }, -- Blast Wave
    [13031] = { passive = false, book = true, harmful = false }, -- Ice Barrier
    [13032] = { passive = false, book = true, harmful = false }, -- Ice Barrier
    [13033] = { passive = false, book = true, harmful = false }, -- Ice Barrier
    [13159] = { passive = false, book = true, harmful = false }, -- Aspect of the Pack
    [13161] = { passive = false, book = true, harmful = false }, -- Aspect of the Beast
    [13163] = { passive = false, book = true, harmful = false }, -- Aspect of the Monkey
    [13165] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [13220] = { passive = false, book = true, harmful = false }, -- Wound Poison
    [13228] = { passive = false, book = true, harmful = false }, -- Wound Poison II
    [13229] = { passive = false, book = true, harmful = false }, -- Wound Poison III
    [13230] = { passive = false, book = true, harmful = false }, -- Wound Poison IV
    [13542] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [13543] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [13544] = { passive = false, book = true, harmful = false }, -- Mend Pet
    [13549] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13550] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13551] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13552] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13553] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13554] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13555] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [13715] = { passive = true, book = true, harmful = false }, -- Dual Wield Specialization
    [13732] = { passive = true, book = true, harmful = false }, -- Efficient Strikes
    [13741] = { passive = true, book = true, harmful = false }, -- Improved Gouge
    [13742] = { passive = true, book = true, harmful = false }, -- Endurance
    [13743] = { passive = true, book = true, harmful = false }, -- Improved Sprint
    [13750] = { passive = false, book = true, harmful = false }, -- Adrenaline Rush
    [13754] = { passive = true, book = true, harmful = false }, -- Improved Kick
    [13795] = { passive = false, book = true, harmful = false }, -- Immolation Trap
    [13797] = { passive = false, book = true, harmful = true }, -- Immolation Trap
    [13809] = { passive = false, book = true, harmful = false }, -- Frost Trap
    [13810] = { passive = false, book = false, harmful = true }, -- Frost Trap
    [13812] = { passive = false, book = true, harmful = true }, -- Explosive Trap
    [13813] = { passive = false, book = true, harmful = false }, -- Explosive Trap
    [13877] = { passive = false, book = true, harmful = false }, -- Blade Flurry
    [13896] = { passive = false, book = true, harmful = false }, -- Feedback
    [13908] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [13975] = { passive = true, book = true, harmful = false }, -- Camouflage
    [13976] = { passive = true, book = true, harmful = false }, -- Initiative
    [13981] = { passive = true, book = true, harmful = false }, -- Elusiveness
    [14057] = { passive = true, book = true, harmful = false }, -- Opportunity
    [14076] = { passive = true, book = true, harmful = false }, -- Improved Sap
    [14079] = { passive = true, book = true, harmful = false }, -- Improved Ambush
    [14082] = { passive = true, book = true, harmful = false }, -- Dirty Deeds
    [14094] = { passive = true, book = true, harmful = false }, -- Improved Sap
    [14095] = { passive = true, book = true, harmful = false }, -- Improved Sap
    [14113] = { passive = true, book = true, harmful = false }, -- Improved Poisons
    [14128] = { passive = true, book = true, harmful = false }, -- Lethality
    [14143] = { passive = false, book = false, harmful = false }, -- Remorseless
    [14144] = { passive = true, book = true, harmful = false }, -- Remorseless Attacks
    [14156] = { passive = true, book = true, harmful = true }, -- Ruthlessness
    [14158] = { passive = true, book = true, harmful = false }, -- Murder
    [14162] = { passive = true, book = true, harmful = false }, -- Coup de Grace
    [14165] = { passive = true, book = true, harmful = false }, -- Improved Slice and Dice
    [14168] = { passive = true, book = true, harmful = false }, -- Improved Expose Armor
    [14171] = { passive = true, book = true, harmful = false }, -- Serrated Blades
    [14174] = { passive = true, book = true, harmful = false }, -- Improved Kidney Shot
    [14177] = { passive = false, book = true, harmful = false }, -- Cold Blood
    [14179] = { passive = true, book = true, harmful = false }, -- Relentless Strikes
    [14183] = { passive = false, book = true, harmful = true }, -- Premeditation
    [14185] = { passive = false, book = true, harmful = false }, -- Preparation
    [14186] = { passive = true, book = true, harmful = true }, -- Seal Fate
    [14251] = { passive = false, book = true, harmful = true }, -- Riposte
    [14260] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14261] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14262] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14263] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14264] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14265] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14266] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [14267] = { passive = false, book = true, harmful = true }, -- Wing Clip
    [14268] = { passive = false, book = true, harmful = true }, -- Wing Clip
    [14269] = { passive = false, book = true, harmful = true }, -- Mongoose Bite
    [14270] = { passive = false, book = true, harmful = true }, -- Mongoose Bite
    [14271] = { passive = false, book = true, harmful = true }, -- Mongoose Bite
    [14272] = { passive = false, book = true, harmful = true }, -- Disengage
    [14273] = { passive = false, book = true, harmful = true }, -- Disengage
    [14274] = { passive = false, book = true, harmful = true }, -- Distracting Shot
    [14278] = { passive = false, book = true, harmful = true }, -- Ghostly Strike
    [14279] = { passive = false, book = true, harmful = true }, -- Viper Sting
    [14280] = { passive = false, book = true, harmful = true }, -- Viper Sting
    [14281] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14282] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14283] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14284] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14285] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14286] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14287] = { passive = false, book = true, harmful = true }, -- Arcane Shot
    [14294] = { passive = false, book = true, harmful = true }, -- Volley
    [14295] = { passive = false, book = true, harmful = true }, -- Volley
    [14298] = { passive = false, book = true, harmful = true }, -- Immolation Trap
    [14299] = { passive = false, book = true, harmful = true }, -- Immolation Trap
    [14300] = { passive = false, book = true, harmful = true }, -- Immolation Trap
    [14301] = { passive = false, book = true, harmful = true }, -- Immolation Trap
    [14302] = { passive = false, book = true, harmful = false }, -- Immolation Trap
    [14303] = { passive = false, book = true, harmful = false }, -- Immolation Trap
    [14304] = { passive = false, book = true, harmful = false }, -- Immolation Trap
    [14305] = { passive = false, book = true, harmful = false }, -- Immolation Trap
    [14308] = { passive = false, book = false, harmful = true }, -- Freezing Trap
    [14309] = { passive = false, book = false, harmful = true }, -- Freezing Trap
    [14310] = { passive = false, book = true, harmful = false }, -- Freezing Trap
    [14311] = { passive = false, book = true, harmful = false }, -- Freezing Trap
    [14314] = { passive = false, book = true, harmful = true }, -- Explosive Trap
    [14315] = { passive = false, book = true, harmful = true }, -- Explosive Trap
    [14316] = { passive = false, book = true, harmful = false }, -- Explosive Trap
    [14317] = { passive = false, book = true, harmful = false }, -- Explosive Trap
    [14318] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [14319] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [14320] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [14321] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [14322] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [14323] = { passive = false, book = true, harmful = true }, -- Hunter's Mark
    [14324] = { passive = false, book = true, harmful = true }, -- Hunter's Mark
    [14325] = { passive = false, book = true, harmful = true }, -- Hunter's Mark
    [14326] = { passive = false, book = true, harmful = true }, -- Scare Beast
    [14327] = { passive = false, book = true, harmful = true }, -- Scare Beast
    [14520] = { passive = true, book = true, harmful = false }, -- Mental Agility
    [14523] = { passive = true, book = true, harmful = false }, -- Silent Resolve
    [14531] = { passive = true, book = true, harmful = false }, -- Martyrdom
    [14747] = { passive = true, book = true, harmful = false }, -- Improved Inner Fire
    [14748] = { passive = true, book = true, harmful = false }, -- Improved Power Word: Shield
    [14749] = { passive = true, book = true, harmful = false }, -- Improved Power Word: Fortitude
    [14750] = { passive = true, book = true, harmful = false }, -- Improved Mana Burn
    [14751] = { passive = false, book = true, harmful = false }, -- Inner Focus
    [14752] = { passive = false, book = true, harmful = false }, -- Divine Spirit
    [14767] = { passive = true, book = true, harmful = false }, -- Improved Power Word: Fortitude
    [14818] = { passive = false, book = true, harmful = false }, -- Divine Spirit
    [14819] = { passive = false, book = true, harmful = false }, -- Divine Spirit
    [14889] = { passive = true, book = true, harmful = false }, -- Holy Specialization
    [14892] = { passive = true, book = true, harmful = false }, -- Inspiration
    [14893] = { passive = false, book = false, harmful = false }, -- Inspiration
    [14898] = { passive = true, book = true, harmful = false }, -- Spiritual Healing
    [14901] = { passive = true, book = true, harmful = false }, -- Spiritual Guidance
    [14908] = { passive = true, book = true, harmful = false }, -- Improved Renew
    [14909] = { passive = true, book = true, harmful = false }, -- Searing Light
    [14912] = { passive = true, book = true, harmful = false }, -- Improved Healing
    [14913] = { passive = true, book = true, harmful = false }, -- Twilight Focus
    [14914] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [14916] = { passive = false, book = true, harmful = true }, -- Growl
    [14917] = { passive = false, book = true, harmful = true }, -- Growl
    [14918] = { passive = false, book = true, harmful = true }, -- Growl
    [14919] = { passive = false, book = true, harmful = true }, -- Growl
    [14920] = { passive = false, book = true, harmful = true }, -- Growl
    [14921] = { passive = false, book = true, harmful = true }, -- Growl
    [14983] = { passive = true, book = true, harmful = false }, -- Vigor
    [15036] = { passive = true, book = false, harmful = false }, -- Flametongue Totem
    [15058] = { passive = true, book = true, harmful = false }, -- Arcane Instability
    [15107] = { passive = false, book = true, harmful = false }, -- Windwall Totem
    [15108] = { passive = true, book = false, harmful = false }, -- Windwall
    [15109] = { passive = true, book = false, harmful = false }, -- Windwall
    [15110] = { passive = true, book = false, harmful = false }, -- Windwall
    [15111] = { passive = false, book = true, harmful = false }, -- Windwall Totem
    [15112] = { passive = false, book = true, harmful = false }, -- Windwall Totem
    [15207] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [15208] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [15237] = { passive = false, book = true, harmful = true }, -- Holy Nova
    [15257] = { passive = true, book = true, harmful = false }, -- Shadow Weaving
    [15258] = { passive = false, book = false, harmful = true }, -- Shadow Weaving
    [15259] = { passive = true, book = true, harmful = false }, -- Darkness
    [15260] = { passive = true, book = true, harmful = false }, -- Shadow Focus
    [15261] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15262] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15263] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15264] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15265] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15266] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15267] = { passive = false, book = true, harmful = true }, -- Holy Fire
    [15268] = { passive = true, book = true, harmful = false }, -- Blackout
    [15269] = { passive = false, book = false, harmful = true }, -- Blackout
    [15270] = { passive = true, book = true, harmful = false }, -- Spirit Tap
    [15271] = { passive = false, book = false, harmful = false }, -- Spirit Tap
    [15273] = { passive = true, book = true, harmful = false }, -- Improved Mind Blast
    [15274] = { passive = true, book = true, harmful = false }, -- Improved Fade
    [15275] = { passive = true, book = true, harmful = false }, -- Improved Shadow Word: Pain
    [15286] = { passive = false, book = true, harmful = true }, -- Vampiric Embrace
    [15318] = { passive = true, book = true, harmful = false }, -- Shadow Affinity
    [15323] = { passive = true, book = true, harmful = false }, -- Blackout
    [15324] = { passive = true, book = true, harmful = false }, -- Blackout
    [15325] = { passive = true, book = true, harmful = false }, -- Blackout
    [15326] = { passive = true, book = true, harmful = false }, -- Blackout
    [15392] = { passive = true, book = true, harmful = false }, -- Improved Psychic Scream
    [15407] = { passive = false, book = true, harmful = true }, -- Mind Flay
    [15430] = { passive = false, book = true, harmful = true }, -- Holy Nova
    [15431] = { passive = false, book = true, harmful = true }, -- Holy Nova
    [15473] = { passive = false, book = true, harmful = false }, -- Shadowform
    [15487] = { passive = false, book = true, harmful = true }, -- Silence
    [15571] = { passive = false, book = false, harmful = false }, -- Dazed
    [15629] = { passive = false, book = true, harmful = true }, -- Distracting Shot
    [15630] = { passive = false, book = true, harmful = true }, -- Distracting Shot
    [15631] = { passive = false, book = true, harmful = true }, -- Distracting Shot
    [15632] = { passive = false, book = true, harmful = true }, -- Distracting Shot
    [15735] = { passive = false, book = false, harmful = true }, -- Arcane Missiles
    [15784] = { passive = false, book = false, harmful = false }, -- Frost Armor
    [15790] = { passive = false, book = false, harmful = true }, -- Arcane Missiles
    [15849] = { passive = true, book = false, harmful = false }, -- Chill Wind
    [15850] = { passive = false, book = false, harmful = true }, -- Chilled
    [16035] = { passive = true, book = true, harmful = false }, -- Concussion
    [16038] = { passive = true, book = true, harmful = false }, -- Call of Flame
    [16039] = { passive = true, book = true, harmful = false }, -- Convection
    [16040] = { passive = true, book = true, harmful = false }, -- Reverberation
    [16043] = { passive = true, book = true, harmful = false }, -- Earth's Grasp
    [16086] = { passive = true, book = true, harmful = false }, -- Trial by Fire
    [16089] = { passive = true, book = true, harmful = false }, -- Elemental Fury
    [16120] = { passive = true, book = true, harmful = false }, -- Call of Thunder
    [16164] = { passive = true, book = true, harmful = false }, -- Elemental Focus
    [16166] = { passive = false, book = true, harmful = false }, -- Lightning Mastery
    [16173] = { passive = true, book = true, harmful = false }, -- Totemic Focus
    [16176] = { passive = true, book = true, harmful = false }, -- Ancestral Healing
    [16177] = { passive = false, book = true, harmful = false }, -- Ancestral Fortitude
    [16178] = { passive = true, book = true, harmful = false }, -- Purification
    [16179] = { passive = true, book = true, harmful = false }, -- Tidal Focus
    [16180] = { passive = true, book = true, harmful = false }, -- Nature's Guidance
    [16181] = { passive = true, book = true, harmful = false }, -- Healing Focus
    [16182] = { passive = true, book = true, harmful = false }, -- Improved Healing Wave
    [16184] = { passive = true, book = true, harmful = false }, -- Improved Reincarnation
    [16187] = { passive = true, book = true, harmful = false }, -- Restorative Totems
    [16188] = { passive = false, book = true, harmful = false }, -- Nature's Swiftness
    [16189] = { passive = true, book = true, harmful = false }, -- Totemic Mastery
    [16190] = { passive = false, book = true, harmful = false }, -- Mana Tide Totem
    [16191] = { passive = true, book = false, harmful = false }, -- Mana Tide
    [16194] = { passive = true, book = true, harmful = false }, -- Tidal Mastery
    [16196] = { passive = true, book = true, harmful = false }, -- Nature's Guidance
    [16198] = { passive = true, book = true, harmful = false }, -- Nature's Guidance
    [16246] = { passive = false, book = false, harmful = false }, -- Clearcasting
    [16256] = { passive = true, book = true, harmful = false }, -- Flurry
    [16258] = { passive = true, book = true, harmful = false }, -- Guardian Totems
    [16259] = { passive = true, book = true, harmful = false }, -- Enhancing Totems
    [16261] = { passive = true, book = true, harmful = false }, -- Improved Lightning Shield
    [16262] = { passive = true, book = true, harmful = false }, -- Improved Ghost Wolf
    [16266] = { passive = true, book = true, harmful = false }, -- Elemental Weapons
    [16268] = { passive = true, book = true, harmful = false }, -- Spirit Weapons
    [16295] = { passive = true, book = true, harmful = false }, -- Enhancing Totems
    [16362] = { passive = false, book = true, harmful = false }, -- Windfury Weapon
    [16387] = { passive = false, book = true, harmful = false }, -- Flametongue Totem
    [16487] = { passive = true, book = true, harmful = false }, -- Blood Craze
    [16488] = { passive = false, book = false, harmful = false }, -- Blood Craze
    [16493] = { passive = true, book = true, harmful = false }, -- Impale
    [16511] = { passive = false, book = true, harmful = true }, -- Hemorrhage
    [16513] = { passive = true, book = true, harmful = false }, -- Vile Poisons
    [16560] = { passive = false, book = false, harmful = false }, -- Flame Wrath
    [16578] = { passive = true, book = true, harmful = false }, -- Elemental Alacrity
    [16579] = { passive = true, book = true, harmful = false }, -- Lightning Mastery
    [16580] = { passive = true, book = true, harmful = false }, -- Lightning Mastery
    [16581] = { passive = true, book = true, harmful = false }, -- Lightning Mastery
    [16582] = { passive = true, book = true, harmful = false }, -- Lightning Mastery
    [16689] = { passive = false, book = true, harmful = false }, -- Nature's Grasp
    [16757] = { passive = true, book = true, harmful = false }, -- Arctic Reach
    [16810] = { passive = false, book = true, harmful = false }, -- Nature's Grasp
    [16811] = { passive = false, book = true, harmful = false }, -- Nature's Grasp
    [16812] = { passive = false, book = true, harmful = false }, -- Nature's Grasp
    [16813] = { passive = false, book = true, harmful = false }, -- Nature's Grasp
    [16814] = { passive = true, book = true, harmful = false }, -- Improved Wrath
    [16819] = { passive = true, book = true, harmful = false }, -- Nature's Reach
    [16821] = { passive = true, book = true, harmful = false }, -- Improved Moonfire
    [16827] = { passive = false, book = true, harmful = true }, -- Claw
    [16828] = { passive = false, book = true, harmful = true }, -- Claw
    [16829] = { passive = false, book = true, harmful = true }, -- Claw
    [16830] = { passive = false, book = true, harmful = true }, -- Claw
    [16831] = { passive = false, book = true, harmful = true }, -- Claw
    [16832] = { passive = false, book = true, harmful = true }, -- Claw
    [16833] = { passive = true, book = true, harmful = false }, -- Natural Shapeshifter
    [16836] = { passive = true, book = true, harmful = false }, -- Improved Thorns
    [16839] = { passive = true, book = true, harmful = false }, -- Improved Thorns
    [16840] = { passive = true, book = true, harmful = false }, -- Improved Thorns
    [16845] = { passive = true, book = true, harmful = false }, -- Moonglow
    [16850] = { passive = true, book = true, harmful = false }, -- Improved Starfire
    [16858] = { passive = true, book = true, harmful = false }, -- Feral Aggression
    [16859] = { passive = true, book = true, harmful = false }, -- Feral Aggression
    [16860] = { passive = true, book = true, harmful = false }, -- Feral Aggression
    [16861] = { passive = true, book = true, harmful = false }, -- Feral Aggression
    [16862] = { passive = true, book = true, harmful = false }, -- Feral Aggression
    [16864] = { passive = true, book = true, harmful = false }, -- Omen of Clarity
    [16870] = { passive = false, book = false, harmful = false }, -- Clearcasting
    [16880] = { passive = true, book = true, harmful = false }, -- Nature's Grace
    [16886] = { passive = false, book = false, harmful = false }, -- Nature's Grace
    [16896] = { passive = true, book = true, harmful = false }, -- Moonfury
    [16902] = { passive = true, book = true, harmful = false }, -- Natural Weapons
    [16903] = { passive = true, book = true, harmful = false }, -- Natural Weapons
    [16904] = { passive = true, book = true, harmful = false }, -- Natural Weapons
    [16905] = { passive = true, book = true, harmful = false }, -- Natural Weapons
    [16906] = { passive = true, book = true, harmful = false }, -- Natural Weapons
    [16909] = { passive = true, book = true, harmful = false }, -- Vengeance
    [16914] = { passive = false, book = true, harmful = true }, -- Hurricane
    [16918] = { passive = true, book = true, harmful = false }, -- Improved Entangling Roots
    [16922] = { passive = false, book = false, harmful = true }, -- Starfire Stun
    [16929] = { passive = true, book = true, harmful = false }, -- Thick Hide
    [16934] = { passive = true, book = true, harmful = false }, -- Ferocity
    [16940] = { passive = true, book = true, harmful = false }, -- Brutal Impact
    [16947] = { passive = true, book = true, harmful = false }, -- Feral Instinct
    [16966] = { passive = true, book = true, harmful = false }, -- Shredding Attacks
    [16968] = { passive = true, book = true, harmful = false }, -- Improved Shred
    [16972] = { passive = true, book = true, harmful = false }, -- Predatory Strikes
    [16979] = { passive = false, book = true, harmful = true }, -- Feral Charge (Bear)
    [16998] = { passive = true, book = true, harmful = false }, -- Savage Fury
    [17002] = { passive = true, book = true, harmful = false }, -- Feral Swiftness
    [17007] = { passive = true, book = true, harmful = false }, -- Leader of the Pack
    [17010] = { passive = true, book = false, harmful = false }, -- Freezing Claw
    [17011] = { passive = false, book = false, harmful = true }, -- Freezing Claw
    [17050] = { passive = true, book = true, harmful = false }, -- Improved Mark of the Wild
    [17051] = { passive = true, book = true, harmful = false }, -- Improved Mark of the Wild
    [17053] = { passive = true, book = true, harmful = false }, -- Improved Mark of the Wild
    [17054] = { passive = true, book = true, harmful = false }, -- Improved Mark of the Wild
    [17055] = { passive = true, book = true, harmful = false }, -- Improved Mark of the Wild
    [17056] = { passive = true, book = true, harmful = false }, -- Furor
    [17057] = { passive = false, book = false, harmful = false }, -- Furor
    [17063] = { passive = true, book = true, harmful = false }, -- Nature's Focus
    [17069] = { passive = true, book = true, harmful = false }, -- Naturalist
    [17074] = { passive = true, book = true, harmful = false }, -- Improved Regrowth
    [17079] = { passive = true, book = true, harmful = false }, -- Improved Enrage
    [17082] = { passive = true, book = true, harmful = false }, -- Improved Enrage
    [17104] = { passive = true, book = true, harmful = false }, -- Gift of Nature
    [17111] = { passive = true, book = true, harmful = false }, -- Improved Rejuvenation
    [17116] = { passive = false, book = true, harmful = false }, -- Nature's Swiftness
    [17118] = { passive = true, book = true, harmful = false }, -- Subtlety
    [17123] = { passive = true, book = true, harmful = false }, -- Improved Tranquility
    [17140] = { passive = false, book = false, harmful = true }, -- Holy Fire
    [17141] = { passive = false, book = false, harmful = true }, -- Holy Fire
    [17142] = { passive = false, book = false, harmful = true }, -- Holy Fire
    [17245] = { passive = true, book = true, harmful = false }, -- Overgrowth
    [17253] = { passive = false, book = true, harmful = true }, -- Bite
    [17255] = { passive = false, book = true, harmful = true }, -- Bite
    [17256] = { passive = false, book = true, harmful = true }, -- Bite
    [17257] = { passive = false, book = true, harmful = true }, -- Bite
    [17258] = { passive = false, book = true, harmful = true }, -- Bite
    [17259] = { passive = false, book = true, harmful = true }, -- Bite
    [17260] = { passive = false, book = true, harmful = true }, -- Bite
    [17261] = { passive = false, book = true, harmful = true }, -- Bite
    [17311] = { passive = false, book = true, harmful = true }, -- Mind Flay
    [17312] = { passive = false, book = true, harmful = true }, -- Mind Flay
    [17313] = { passive = false, book = true, harmful = true }, -- Mind Flay
    [17314] = { passive = false, book = true, harmful = true }, -- Mind Flay
    [17322] = { passive = true, book = true, harmful = false }, -- Shadow Reach
    [17329] = { passive = false, book = true, harmful = false }, -- Nature's Grasp
    [17354] = { passive = false, book = true, harmful = false }, -- Mana Tide Totem
    [17355] = { passive = true, book = false, harmful = false }, -- Mana Tide
    [17359] = { passive = false, book = true, harmful = false }, -- Mana Tide Totem
    [17360] = { passive = true, book = false, harmful = false }, -- Mana Tide
    [17364] = { passive = false, book = true, harmful = true }, -- Stormstrike
    [17401] = { passive = false, book = true, harmful = true }, -- Hurricane
    [17402] = { passive = false, book = true, harmful = true }, -- Hurricane
    [17441] = { passive = false, book = false, harmful = true }, -- Air Bubbles
    [17727] = { passive = false, book = true, harmful = false }, -- Create Spellstone
    [17728] = { passive = false, book = true, harmful = false }, -- Create Spellstone
    [17735] = { passive = false, book = true, harmful = true }, -- Suffering
    [17750] = { passive = false, book = true, harmful = true }, -- Suffering
    [17751] = { passive = false, book = true, harmful = true }, -- Suffering
    [17752] = { passive = false, book = true, harmful = true }, -- Suffering
    [17767] = { passive = false, book = true, harmful = false }, -- Consume Shadows
    [17778] = { passive = true, book = true, harmful = false }, -- Cataclysm
    [17783] = { passive = true, book = true, harmful = false }, -- Fel Concentration
    [17788] = { passive = true, book = true, harmful = false }, -- Bane
    [17793] = { passive = true, book = true, harmful = false }, -- Improved Shadow Bolt
    [17794] = { passive = false, book = false, harmful = true }, -- Shadow Vulnerability
    [17804] = { passive = true, book = true, harmful = false }, -- Soul Siphon
    [17810] = { passive = true, book = true, harmful = false }, -- Improved Corruption
    [17815] = { passive = true, book = true, harmful = false }, -- Improved Immolate
    [17833] = { passive = true, book = true, harmful = false }, -- Improved Immolate
    [17834] = { passive = true, book = true, harmful = false }, -- Improved Immolate
    [17835] = { passive = true, book = true, harmful = false }, -- Improved Immolate
    [17836] = { passive = true, book = true, harmful = false }, -- Improved Immolate
    [17850] = { passive = false, book = true, harmful = false }, -- Consume Shadows
    [17851] = { passive = false, book = true, harmful = false }, -- Consume Shadows
    [17852] = { passive = false, book = true, harmful = false }, -- Consume Shadows
    [17853] = { passive = false, book = true, harmful = false }, -- Consume Shadows
    [17854] = { passive = false, book = true, harmful = false }, -- Consume Shadows
    [17877] = { passive = false, book = true, harmful = true }, -- Shadowburn
    [17917] = { passive = true, book = true, harmful = false }, -- Destructive Reach
    [17919] = { passive = false, book = true, harmful = true }, -- Searing Pain
    [17920] = { passive = false, book = true, harmful = true }, -- Searing Pain
    [17921] = { passive = false, book = true, harmful = true }, -- Searing Pain
    [17922] = { passive = false, book = true, harmful = true }, -- Searing Pain
    [17923] = { passive = false, book = true, harmful = true }, -- Searing Pain
    [17924] = { passive = false, book = true, harmful = true }, -- Soul Fire
    [17925] = { passive = false, book = true, harmful = true }, -- Death Coil
    [17926] = { passive = false, book = true, harmful = true }, -- Death Coil
    [17927] = { passive = true, book = true, harmful = false }, -- Agonizing Flames
    [17928] = { passive = false, book = true, harmful = true }, -- Howl of Terror
    [17941] = { passive = false, book = false, harmful = false }, -- Shadow Trance
    [17951] = { passive = false, book = true, harmful = false }, -- Create Firestone
    [17952] = { passive = false, book = true, harmful = false }, -- Create Firestone
    [17953] = { passive = false, book = true, harmful = false }, -- Create Firestone
    [17954] = { passive = true, book = true, harmful = false }, -- Emberstorm
    [17959] = { passive = true, book = true, harmful = false }, -- Ruin
    [17962] = { passive = false, book = true, harmful = true }, -- Conflagrate
    [18073] = { passive = true, book = false, harmful = false }, -- Pyroclasm
    [18093] = { passive = false, book = true, harmful = true }, -- Pyroclasm
    [18094] = { passive = true, book = true, harmful = false }, -- Nightfall
    [18096] = { passive = true, book = true, harmful = false }, -- Apocalypse
    [18100] = { passive = false, book = false, harmful = false }, -- Frost Armor
    [18101] = { passive = false, book = false, harmful = true }, -- Chilled
    [18118] = { passive = false, book = false, harmful = true }, -- Aftermath
    [18119] = { passive = true, book = true, harmful = false }, -- Aftermath
    [18126] = { passive = true, book = true, harmful = false }, -- Improved Firebolt
    [18127] = { passive = true, book = true, harmful = false }, -- Improved Firebolt
    [18128] = { passive = true, book = true, harmful = false }, -- Improved Lash of Pain
    [18129] = { passive = true, book = true, harmful = false }, -- Improved Lash of Pain
    [18130] = { passive = true, book = true, harmful = false }, -- Devastation
    [18135] = { passive = true, book = true, harmful = false }, -- Intensity
    [18137] = { passive = false, book = true, harmful = false }, -- Shadowguard
    [18146] = { passive = true, book = false, harmful = false }, -- Chilling Touch
    [18165] = { passive = false, book = false, harmful = true }, -- Holy Fire
    [18167] = { passive = true, book = false, harmful = false }, -- Holy Fire
    [18174] = { passive = true, book = true, harmful = false }, -- Suppression
    [18179] = { passive = true, book = true, harmful = false }, -- Improved Curse of Weakness
    [18180] = { passive = true, book = true, harmful = false }, -- Improved Curse of Weakness
    [18181] = { passive = true, book = true, harmful = false }, -- Improved Curse of Weakness
    [18182] = { passive = true, book = true, harmful = false }, -- Improved Life Tap
    [18218] = { passive = true, book = true, harmful = false }, -- Grim Reach
    [18223] = { passive = false, book = true, harmful = true }, -- Curse of Exhaustion
    [18265] = { passive = false, book = true, harmful = true }, -- Siphon Life
    [18271] = { passive = true, book = true, harmful = false }, -- Shadow Mastery
    [18288] = { passive = false, book = true, harmful = false }, -- Amplify Curse
    [18310] = { passive = true, book = true, harmful = false }, -- Improved Curse of Exhaustion
    [18311] = { passive = true, book = true, harmful = false }, -- Improved Curse of Exhaustion
    [18312] = { passive = true, book = true, harmful = false }, -- Improved Curse of Exhaustion
    [18313] = { passive = true, book = true, harmful = false }, -- Improved Curse of Exhaustion
    [18425] = { passive = false, book = false, harmful = true }, -- Silenced - Kick
    [18427] = { passive = true, book = true, harmful = false }, -- Aggression
    [18459] = { passive = true, book = true, harmful = false }, -- Incineration
    [18461] = { passive = false, book = false, harmful = false }, -- Vanish Purge
    [18498] = { passive = false, book = false, harmful = true }, -- Silenced
    [18499] = { passive = false, book = true, harmful = false }, -- Berserker Rage
    [18530] = { passive = true, book = true, harmful = false }, -- Divine Fury
    [18540] = { passive = false, book = true, harmful = false }, -- Ritual of Doom
    [18544] = { passive = true, book = true, harmful = false }, -- Force of Will
    [18547] = { passive = true, book = true, harmful = false }, -- Force of Will
    [18548] = { passive = true, book = true, harmful = false }, -- Force of Will
    [18549] = { passive = true, book = true, harmful = false }, -- Force of Will
    [18550] = { passive = true, book = true, harmful = false }, -- Force of Will
    [18562] = { passive = false, book = true, harmful = false }, -- Swiftmend
    [18647] = { passive = false, book = true, harmful = true }, -- Banish
    [18657] = { passive = false, book = true, harmful = true }, -- Hibernate
    [18658] = { passive = false, book = true, harmful = true }, -- Hibernate
    [18692] = { passive = true, book = true, harmful = false }, -- Improved Healthstone
    [18693] = { passive = true, book = true, harmful = false }, -- Improved Healthstone
    [18694] = { passive = true, book = true, harmful = false }, -- Improved Imp
    [18703] = { passive = true, book = true, harmful = false }, -- Improved Health Funnel
    [18705] = { passive = true, book = true, harmful = false }, -- Improved Voidwalker
    [18708] = { passive = false, book = true, harmful = false }, -- Fel Domination
    [18709] = { passive = true, book = true, harmful = false }, -- Master Summoner
    [18727] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18728] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18729] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18730] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18731] = { passive = true, book = true, harmful = false }, -- Fel Vitality
    [18733] = { passive = false, book = false, harmful = true }, -- Air Bubbles
    [18735] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18736] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18737] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18738] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18739] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18740] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18741] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18742] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [18754] = { passive = true, book = true, harmful = false }, -- Improved Sayaad
    [18767] = { passive = true, book = true, harmful = false }, -- Improved Firestone
    [18768] = { passive = true, book = true, harmful = false }, -- Improved Firestone
    [18769] = { passive = true, book = true, harmful = false }, -- Unholy Power
    [18774] = { passive = true, book = true, harmful = false }, -- Improved Spellstone
    [18775] = { passive = true, book = true, harmful = false }, -- Improved Spellstone
    [18788] = { passive = false, book = true, harmful = false }, -- Demonic Sacrifice
    [18789] = { passive = false, book = false, harmful = false }, -- Burning Shadow
    [18790] = { passive = false, book = false, harmful = false }, -- Fel Stamina
    [18791] = { passive = false, book = false, harmful = false }, -- Touch of Fire
    [18792] = { passive = false, book = false, harmful = false }, -- Fel Energy
    [18807] = { passive = false, book = true, harmful = true }, -- Mind Flay
    [18809] = { passive = false, book = true, harmful = true }, -- Pyroblast
    [18821] = { passive = true, book = true, harmful = false }, -- Improved Subjugate Demon
    [18822] = { passive = true, book = true, harmful = false }, -- Improved Subjugate Demon
    [18823] = { passive = true, book = true, harmful = false }, -- Improved Subjugate Demon
    [18824] = { passive = true, book = true, harmful = false }, -- Improved Subjugate Demon
    [18825] = { passive = true, book = true, harmful = false }, -- Improved Subjugate Demon
    [18827] = { passive = true, book = true, harmful = false }, -- Improved Bane of Agony
    [18867] = { passive = false, book = true, harmful = true }, -- Shadowburn
    [18868] = { passive = false, book = true, harmful = true }, -- Shadowburn
    [18869] = { passive = false, book = true, harmful = true }, -- Shadowburn
    [18870] = { passive = false, book = true, harmful = true }, -- Shadowburn
    [18871] = { passive = false, book = true, harmful = true }, -- Shadowburn
    [18879] = { passive = false, book = true, harmful = true }, -- Siphon Life
    [18880] = { passive = false, book = true, harmful = true }, -- Siphon Life
    [18881] = { passive = false, book = true, harmful = true }, -- Siphon Life
    [18930] = { passive = false, book = true, harmful = true }, -- Conflagrate
    [18931] = { passive = false, book = true, harmful = true }, -- Conflagrate
    [18932] = { passive = false, book = true, harmful = true }, -- Conflagrate
    [18960] = { passive = false, book = true, harmful = false }, -- Teleport: Moonglade
    [19007] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [19028] = { passive = false, book = true, harmful = false }, -- Soul Link
    [19134] = { passive = false, book = false, harmful = true }, -- Intimidating Shout
    [19159] = { passive = true, book = true, harmful = false }, -- Savage Strikes
    [19184] = { passive = true, book = true, harmful = true }, -- Entrapment
    [19185] = { passive = false, book = true, harmful = true }, -- Entrapment
    [19228] = { passive = true, book = true, harmful = true }, -- Improved Wing Clip
    [19229] = { passive = false, book = false, harmful = true }, -- Improved Wing Clip
    [19236] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [19238] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [19239] = { passive = true, book = true, harmful = false }, -- Clever Traps
    [19240] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [19241] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [19242] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [19243] = { passive = false, book = true, harmful = false }, -- Desperate Prayer
    [19244] = { passive = false, book = true, harmful = true }, -- Spell Lock
    [19249] = { passive = false, book = true, harmful = true }, -- Touch of Weakness
    [19251] = { passive = false, book = true, harmful = true }, -- Touch of Weakness
    [19252] = { passive = false, book = true, harmful = true }, -- Touch of Weakness
    [19253] = { passive = false, book = true, harmful = true }, -- Touch of Weakness
    [19254] = { passive = false, book = true, harmful = true }, -- Touch of Weakness
    [19255] = { passive = true, book = true, harmful = false }, -- Survivalist
    [19261] = { passive = false, book = true, harmful = false }, -- Touch of Weakness
    [19262] = { passive = false, book = true, harmful = false }, -- Touch of Weakness
    [19263] = { passive = false, book = true, harmful = false }, -- Deterrence
    [19264] = { passive = false, book = true, harmful = false }, -- Touch of Weakness
    [19265] = { passive = false, book = true, harmful = false }, -- Touch of Weakness
    [19266] = { passive = false, book = true, harmful = false }, -- Touch of Weakness
    [19271] = { passive = false, book = true, harmful = false }, -- Feedback
    [19273] = { passive = false, book = true, harmful = false }, -- Feedback
    [19274] = { passive = false, book = true, harmful = false }, -- Feedback
    [19275] = { passive = false, book = true, harmful = false }, -- Feedback
    [19276] = { passive = false, book = true, harmful = true }, -- Devouring Plague
    [19277] = { passive = false, book = true, harmful = true }, -- Devouring Plague
    [19278] = { passive = false, book = true, harmful = true }, -- Devouring Plague
    [19279] = { passive = false, book = true, harmful = true }, -- Devouring Plague
    [19280] = { passive = false, book = true, harmful = true }, -- Devouring Plague
    [19281] = { passive = false, book = true, harmful = true }, -- Hex of Weakness
    [19282] = { passive = false, book = true, harmful = true }, -- Hex of Weakness
    [19283] = { passive = false, book = true, harmful = true }, -- Hex of Weakness
    [19284] = { passive = false, book = true, harmful = true }, -- Hex of Weakness
    [19285] = { passive = false, book = true, harmful = true }, -- Hex of Weakness
    [19286] = { passive = true, book = true, harmful = false }, -- Improved Feign Death
    [19287] = { passive = true, book = true, harmful = false }, -- Improved Feign Death
    [19290] = { passive = true, book = true, harmful = false }, -- Surefooted
    [19296] = { passive = false, book = true, harmful = true }, -- Starshards
    [19299] = { passive = false, book = true, harmful = true }, -- Starshards
    [19302] = { passive = false, book = true, harmful = true }, -- Starshards
    [19303] = { passive = false, book = true, harmful = true }, -- Starshards
    [19304] = { passive = false, book = true, harmful = true }, -- Starshards
    [19305] = { passive = false, book = true, harmful = true }, -- Starshards
    [19306] = { passive = false, book = true, harmful = true }, -- Counterattack
    [19308] = { passive = false, book = true, harmful = false }, -- Shadowguard
    [19309] = { passive = false, book = true, harmful = false }, -- Shadowguard
    [19310] = { passive = false, book = true, harmful = false }, -- Shadowguard
    [19311] = { passive = false, book = true, harmful = false }, -- Shadowguard
    [19312] = { passive = false, book = true, harmful = false }, -- Shadowguard
    [19376] = { passive = true, book = true, harmful = false }, -- Survival Tactics
    [19407] = { passive = true, book = true, harmful = false }, -- Improved Concussive Shot
    [19410] = { passive = false, book = false, harmful = true }, -- Improved Concussive Shot
    [19416] = { passive = true, book = true, harmful = false }, -- Efficiency
    [19421] = { passive = true, book = true, harmful = false }, -- Improved Hunter's Mark
    [19426] = { passive = true, book = true, harmful = false }, -- Lethal Attacks
    [19434] = { passive = false, book = true, harmful = true }, -- Aimed Shot
    [19438] = { passive = false, book = true, harmful = false }, -- Sacrifice
    [19440] = { passive = false, book = true, harmful = false }, -- Sacrifice
    [19441] = { passive = false, book = true, harmful = false }, -- Sacrifice
    [19442] = { passive = false, book = true, harmful = false }, -- Sacrifice
    [19443] = { passive = false, book = true, harmful = false }, -- Sacrifice
    [19454] = { passive = true, book = true, harmful = false }, -- Improved Arcane Shot
    [19461] = { passive = true, book = true, harmful = false }, -- Barrage
    [19464] = { passive = true, book = true, harmful = false }, -- Improved Serpent Sting
    [19478] = { passive = false, book = true, harmful = false }, -- Tainted Blood
    [19479] = { passive = false, book = false, harmful = true }, -- Tainted Blood Effect
    [19480] = { passive = false, book = true, harmful = false }, -- Paranoia
    [19485] = { passive = true, book = true, harmful = false }, -- Mortal Shots
    [19498] = { passive = true, book = true, harmful = false }, -- Hawk Eye
    [19503] = { passive = false, book = true, harmful = true }, -- Scatter Shot
    [19505] = { passive = false, book = true, harmful = false }, -- Devour Magic
    [19506] = { passive = false, book = true, harmful = false }, -- Trueshot Aura
    [19549] = { passive = true, book = true, harmful = false }, -- Improved Aspect of the Monkey
    [19552] = { passive = true, book = true, harmful = false }, -- Deadly Aspects
    [19557] = { passive = true, book = true, harmful = false }, -- Improved Eyes of the Beast
    [19558] = { passive = true, book = true, harmful = false }, -- Improved Eyes of the Beast
    [19559] = { passive = true, book = true, harmful = false }, -- Pathfinding
    [19572] = { passive = true, book = true, harmful = false }, -- Improved Mend Pet
    [19574] = { passive = false, book = true, harmful = false }, -- Bestial Wrath
    [19577] = { passive = false, book = true, harmful = false }, -- Intimidation
    [19580] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [19581] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [19582] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [19583] = { passive = true, book = true, harmful = false }, -- Endurance Training
    [19589] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [19590] = { passive = true, book = true, harmful = false }, -- Bestial Discipline
    [19591] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [19596] = { passive = true, book = true, harmful = false }, -- Bestial Swiftness
    [19598] = { passive = true, book = true, harmful = false }, -- Ferocity
    [19609] = { passive = true, book = true, harmful = false }, -- Thick Hide
    [19615] = { passive = false, book = false, harmful = false }, -- Frenzy
    [19616] = { passive = true, book = true, harmful = false }, -- Unleashed Fury
    [19621] = { passive = true, book = true, harmful = false }, -- Frenzy
    [19647] = { passive = false, book = true, harmful = true }, -- Spell Lock
    [19652] = { passive = false, book = false, harmful = true }, -- Tainted Blood Effect
    [19653] = { passive = false, book = false, harmful = true }, -- Tainted Blood Effect
    [19654] = { passive = false, book = false, harmful = true }, -- Tainted Blood Effect
    [19655] = { passive = false, book = true, harmful = false }, -- Tainted Blood
    [19656] = { passive = false, book = true, harmful = false }, -- Tainted Blood
    [19658] = { passive = false, book = true, harmful = false }, -- Devour Magic Effect
    [19660] = { passive = false, book = true, harmful = false }, -- Tainted Blood
    [19675] = { passive = false, book = false, harmful = true }, -- Feral Charge
    [19731] = { passive = false, book = true, harmful = false }, -- Devour Magic
    [19732] = { passive = false, book = true, harmful = false }, -- Devour Magic Effect
    [19733] = { passive = false, book = true, harmful = false }, -- Devour Magic Effect
    [19734] = { passive = false, book = true, harmful = false }, -- Devour Magic
    [19735] = { passive = false, book = true, harmful = false }, -- Devour Magic Effect
    [19736] = { passive = false, book = true, harmful = false }, -- Devour Magic
    [19740] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [19742] = { passive = false, book = true, harmful = false }, -- Blessing of Wisdom
    [19746] = { passive = false, book = true, harmful = false }, -- Concentration Aura
    [19750] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [19752] = { passive = false, book = true, harmful = false }, -- Divine Intervention
    [19753] = { passive = false, book = false, harmful = false }, -- Divine Intervention
    [19801] = { passive = false, book = true, harmful = true }, -- Tranquilizing Shot
    [19834] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [19835] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [19836] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [19837] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [19838] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [19850] = { passive = false, book = true, harmful = false }, -- Blessing of Wisdom
    [19852] = { passive = false, book = true, harmful = false }, -- Blessing of Wisdom
    [19853] = { passive = false, book = true, harmful = false }, -- Blessing of Wisdom
    [19854] = { passive = false, book = true, harmful = false }, -- Blessing of Wisdom
    [19870] = { passive = true, book = true, harmful = false }, -- Improved Intimidating Shout
    [19871] = { passive = true, book = true, harmful = false }, -- Improved Intimidating Shout
    [19876] = { passive = false, book = true, harmful = false }, -- Shadow Resistance Aura
    [19878] = { passive = false, book = true, harmful = false }, -- Track Demons
    [19879] = { passive = false, book = true, harmful = false }, -- Track Dragonkin
    [19880] = { passive = false, book = true, harmful = false }, -- Track Elementals
    [19882] = { passive = false, book = true, harmful = false }, -- Track Giants
    [19883] = { passive = false, book = true, harmful = false }, -- Track Humanoids
    [19884] = { passive = false, book = true, harmful = false }, -- Track Undead
    [19885] = { passive = false, book = true, harmful = false }, -- Track Hidden
    [19888] = { passive = false, book = true, harmful = false }, -- Frost Resistance Aura
    [19891] = { passive = false, book = true, harmful = false }, -- Fire Resistance Aura
    [19895] = { passive = false, book = true, harmful = false }, -- Shadow Resistance Aura
    [19896] = { passive = false, book = true, harmful = false }, -- Shadow Resistance Aura
    [19897] = { passive = false, book = true, harmful = false }, -- Frost Resistance Aura
    [19898] = { passive = false, book = true, harmful = false }, -- Frost Resistance Aura
    [19899] = { passive = false, book = true, harmful = false }, -- Fire Resistance Aura
    [19900] = { passive = false, book = true, harmful = false }, -- Fire Resistance Aura
    [19939] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [19940] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [19941] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [19942] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [19943] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [19968] = { passive = false, book = true, harmful = false }, -- Holy Light
    [19970] = { passive = false, book = false, harmful = true }, -- Entangling Roots
    [19971] = { passive = false, book = false, harmful = true }, -- Entangling Roots
    [19972] = { passive = false, book = false, harmful = true }, -- Entangling Roots
    [19973] = { passive = false, book = false, harmful = true }, -- Entangling Roots
    [19974] = { passive = false, book = false, harmful = true }, -- Entangling Roots
    [19975] = { passive = false, book = false, harmful = true }, -- Entangling Roots
    [19980] = { passive = false, book = true, harmful = false }, -- Holy Light
    [19981] = { passive = false, book = true, harmful = false }, -- Holy Light
    [19982] = { passive = false, book = true, harmful = false }, -- Holy Light
    [19993] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [20007] = { passive = false, book = false, harmful = false }, -- Holy Strength
    [20042] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Might
    [20043] = { passive = false, book = true, harmful = false }, -- Aspect of the Wild
    [20045] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Might
    [20046] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Might
    [20047] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Might
    [20048] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Might
    [20049] = { passive = true, book = true, harmful = false }, -- Vengeance
    [20050] = { passive = false, book = false, harmful = false }, -- Vengeance
    [20066] = { passive = false, book = true, harmful = true }, -- Repentance
    [20091] = { passive = true, book = true, harmful = false }, -- Improved Retribution Aura
    [20092] = { passive = true, book = true, harmful = false }, -- Improved Retribution Aura
    [20101] = { passive = true, book = true, harmful = false }, -- Benediction
    [20116] = { passive = false, book = true, harmful = true }, -- Consecration
    [20127] = { passive = true, book = true, harmful = false }, -- Redoubt
    [20128] = { passive = false, book = false, harmful = false }, -- Redoubt
    [20138] = { passive = true, book = true, harmful = false }, -- Improved Devotion Aura
    [20154] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20162] = { passive = false, book = true, harmful = false }, -- Seal of the Crusader
    [20163] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [20164] = { passive = false, book = true, harmful = false }, -- Seal of Justice
    [20165] = { passive = false, book = true, harmful = false }, -- Seal of Light
    [20166] = { passive = false, book = true, harmful = false }, -- Seal of Wisdom
    [20170] = { passive = false, book = false, harmful = true }, -- Stun
    [20174] = { passive = true, book = true, harmful = false }, -- Guardian's Favor
    [20177] = { passive = true, book = true, harmful = false }, -- Reckoning
    [20183] = { passive = false, book = true, harmful = true }, -- Judgement of Fury
    [20184] = { passive = false, book = true, harmful = true }, -- Judgement of Justice
    [20185] = { passive = false, book = true, harmful = true }, -- Judgement of Light
    [20186] = { passive = false, book = true, harmful = true }, -- Judgement of Wisdom
    [20187] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20188] = { passive = false, book = true, harmful = true }, -- Judgement of the Crusader
    [20190] = { passive = false, book = true, harmful = false }, -- Aspect of the Wild
    [20205] = { passive = true, book = true, harmful = false }, -- Spiritual Focus
    [20210] = { passive = true, book = true, harmful = false }, -- Illumination
    [20216] = { passive = false, book = true, harmful = false }, -- Divine Favor
    [20217] = { passive = false, book = true, harmful = false }, -- Blessing of Kings
    [20224] = { passive = true, book = true, harmful = false }, -- Improved Seals
    [20230] = { passive = false, book = true, harmful = false }, -- Retaliation
    [20237] = { passive = true, book = true, harmful = false }, -- Healing Light
    [20244] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Wisdom
    [20245] = { passive = true, book = true, harmful = false }, -- Improved Blessing of Wisdom
    [20249] = { passive = true, book = true, harmful = false }, -- Improved Flash of Light
    [20250] = { passive = true, book = true, harmful = false }, -- Improved Flash of Light
    [20251] = { passive = true, book = true, harmful = false }, -- Improved Flash of Light
    [20252] = { passive = false, book = true, harmful = true }, -- Intercept
    [20253] = { passive = false, book = false, harmful = true }, -- Intercept Stun
    [20254] = { passive = true, book = true, harmful = false }, -- Improved Concentration Aura
    [20271] = { passive = false, book = true, harmful = true }, -- Judgement
    [20272] = { passive = false, book = false, harmful = false }, -- Illumination
    [20280] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20281] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20282] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20283] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20284] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20285] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20286] = { passive = false, book = true, harmful = true }, -- Judgement of Righteousness
    [20287] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20288] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20289] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20290] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20291] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20292] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20293] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [20300] = { passive = false, book = true, harmful = true }, -- Judgement of the Crusader
    [20301] = { passive = false, book = true, harmful = true }, -- Judgement of the Crusader
    [20302] = { passive = false, book = true, harmful = true }, -- Judgement of the Crusader
    [20303] = { passive = false, book = true, harmful = true }, -- Judgement of the Crusader
    [20305] = { passive = false, book = true, harmful = false }, -- Seal of the Crusader
    [20306] = { passive = false, book = true, harmful = false }, -- Seal of the Crusader
    [20307] = { passive = false, book = true, harmful = false }, -- Seal of the Crusader
    [20308] = { passive = false, book = true, harmful = false }, -- Seal of the Crusader
    [20335] = { passive = true, book = true, harmful = false }, -- Improved Seal of the Crusader
    [20336] = { passive = true, book = true, harmful = false }, -- Improved Seal of the Crusader
    [20337] = { passive = true, book = true, harmful = false }, -- Improved Seal of the Crusader
    [20344] = { passive = false, book = true, harmful = true }, -- Judgement of Light
    [20345] = { passive = false, book = true, harmful = true }, -- Judgement of Light
    [20346] = { passive = false, book = true, harmful = true }, -- Judgement of Light
    [20347] = { passive = false, book = true, harmful = false }, -- Seal of Light
    [20348] = { passive = false, book = true, harmful = false }, -- Seal of Light
    [20349] = { passive = false, book = true, harmful = false }, -- Seal of Light
    [20354] = { passive = false, book = true, harmful = true }, -- Judgement of Wisdom
    [20355] = { passive = false, book = true, harmful = true }, -- Judgement of Wisdom
    [20356] = { passive = false, book = true, harmful = false }, -- Seal of Wisdom
    [20357] = { passive = false, book = true, harmful = false }, -- Seal of Wisdom
    [20359] = { passive = true, book = true, harmful = false }, -- Lasting Judgement
    [20360] = { passive = true, book = true, harmful = false }, -- Lasting Judgement
    [20361] = { passive = true, book = true, harmful = false }, -- Lasting Judgement
    [20375] = { passive = false, book = true, harmful = false }, -- Seal of Command
    [20411] = { passive = false, book = true, harmful = true }, -- Judgement of Fury
    [20412] = { passive = false, book = true, harmful = true }, -- Judgement of Fury
    [20413] = { passive = false, book = true, harmful = true }, -- Judgement of Fury
    [20414] = { passive = false, book = true, harmful = true }, -- Judgement of Fury
    [20419] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [20421] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [20422] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [20423] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [20425] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20467] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20468] = { passive = true, book = true, harmful = false }, -- Improved Righteous Fury
    [20473] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [20484] = { passive = false, book = true, harmful = false }, -- Rebirth
    [20487] = { passive = true, book = true, harmful = false }, -- Improved Hammer of Justice
    [20500] = { passive = true, book = true, harmful = false }, -- Improved Berserker Rage
    [20502] = { passive = true, book = true, harmful = false }, -- Improved Execute
    [20504] = { passive = true, book = true, harmful = false }, -- Improved Intercept
    [20511] = { passive = false, book = false, harmful = true }, -- Intimidating Shout
    [20549] = { passive = false, book = true, harmful = true }, -- War Stomp
    [20554] = { passive = false, book = true, harmful = false }, -- Berserking
    [20559] = { passive = false, book = true, harmful = true }, -- Mocking Blow
    [20560] = { passive = false, book = true, harmful = true }, -- Mocking Blow
    [20569] = { passive = false, book = true, harmful = true }, -- Cleave
    [20572] = { passive = false, book = true, harmful = false }, -- Blood Fury
    [20575] = { passive = true, book = true, harmful = false }, -- Command
    [20576] = { passive = true, book = true, harmful = false }, -- Command
    [20577] = { passive = false, book = true, harmful = false }, -- Cannibalize
    [20580] = { passive = false, book = true, harmful = false }, -- Shadowmeld
    [20589] = { passive = false, book = true, harmful = false }, -- Escape Artist
    [20594] = { passive = false, book = true, harmful = false }, -- Stoneform
    [20600] = { passive = false, book = true, harmful = false }, -- Perception
    [20608] = { passive = true, book = true, harmful = false }, -- Reincarnation
    [20609] = { passive = false, book = true, harmful = false }, -- Ancestral Spirit
    [20610] = { passive = false, book = true, harmful = false }, -- Ancestral Spirit
    [20614] = { passive = false, book = false, harmful = true }, -- Intercept Stun
    [20615] = { passive = false, book = false, harmful = true }, -- Intercept Stun
    [20616] = { passive = false, book = true, harmful = true }, -- Intercept
    [20617] = { passive = false, book = true, harmful = true }, -- Intercept
    [20647] = { passive = false, book = true, harmful = true }, -- Execute
    [20658] = { passive = false, book = true, harmful = true }, -- Execute
    [20660] = { passive = false, book = true, harmful = true }, -- Execute
    [20661] = { passive = false, book = true, harmful = true }, -- Execute
    [20662] = { passive = false, book = true, harmful = true }, -- Execute
    [20707] = { passive = false, book = false, harmful = false }, -- Soulstone Resurrection
    [20711] = { passive = true, book = true, harmful = false }, -- Spirit of Redemption
    [20729] = { passive = false, book = true, harmful = false }, -- Blessing of Sacrifice
    [20736] = { passive = false, book = true, harmful = true }, -- Distracting Shot
    [20739] = { passive = false, book = true, harmful = false }, -- Rebirth
    [20742] = { passive = false, book = true, harmful = false }, -- Rebirth
    [20747] = { passive = false, book = true, harmful = false }, -- Rebirth
    [20748] = { passive = false, book = true, harmful = false }, -- Rebirth
    [20752] = { passive = false, book = true, harmful = false }, -- Create Soulstone
    [20755] = { passive = false, book = true, harmful = false }, -- Create Soulstone
    [20756] = { passive = false, book = true, harmful = false }, -- Create Soulstone
    [20757] = { passive = false, book = true, harmful = false }, -- Create Soulstone
    [20762] = { passive = false, book = false, harmful = false }, -- Soulstone Resurrection
    [20763] = { passive = false, book = false, harmful = false }, -- Soulstone Resurrection
    [20764] = { passive = false, book = false, harmful = false }, -- Soulstone Resurrection
    [20765] = { passive = false, book = false, harmful = false }, -- Soulstone Resurrection
    [20770] = { passive = false, book = true, harmful = false }, -- Resurrection
    [20772] = { passive = false, book = true, harmful = false }, -- Redemption
    [20773] = { passive = false, book = true, harmful = false }, -- Redemption
    [20776] = { passive = false, book = true, harmful = false }, -- Ancestral Spirit
    [20777] = { passive = false, book = true, harmful = false }, -- Ancestral Spirit
    [20782] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [20784] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [20900] = { passive = false, book = true, harmful = true }, -- Aimed Shot
    [20901] = { passive = false, book = true, harmful = true }, -- Aimed Shot
    [20902] = { passive = false, book = true, harmful = true }, -- Aimed Shot
    [20903] = { passive = false, book = true, harmful = true }, -- Aimed Shot
    [20904] = { passive = false, book = true, harmful = true }, -- Aimed Shot
    [20905] = { passive = false, book = true, harmful = false }, -- Trueshot Aura
    [20906] = { passive = false, book = true, harmful = false }, -- Trueshot Aura
    [20909] = { passive = false, book = true, harmful = true }, -- Counterattack
    [20910] = { passive = false, book = true, harmful = true }, -- Counterattack
    [20915] = { passive = false, book = true, harmful = false }, -- Seal of Command
    [20918] = { passive = false, book = true, harmful = false }, -- Seal of Command
    [20919] = { passive = false, book = true, harmful = false }, -- Seal of Command
    [20920] = { passive = false, book = true, harmful = false }, -- Seal of Command
    [20922] = { passive = false, book = true, harmful = true }, -- Consecration
    [20923] = { passive = false, book = true, harmful = true }, -- Consecration
    [20924] = { passive = false, book = true, harmful = true }, -- Consecration
    [20925] = { passive = false, book = true, harmful = false }, -- Holy Shield
    [20927] = { passive = false, book = true, harmful = false }, -- Holy Shield
    [20928] = { passive = false, book = true, harmful = false }, -- Holy Shield
    [20929] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [20930] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [20961] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20962] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20963] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20964] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20965] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20966] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20967] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [20968] = { passive = false, book = true, harmful = true }, -- Judgement of Command
    [21082] = { passive = false, book = true, harmful = false }, -- Seal of the Crusader
    [21084] = { passive = false, book = true, harmful = false }, -- Seal of Righteousness
    [21169] = { passive = false, book = true, harmful = false }, -- Reincarnation
    [21178] = { passive = true, book = true, harmful = false }, -- Bear Form (Passive2)
    [21183] = { passive = false, book = false, harmful = true }, -- Judgement of the Crusader
    [21551] = { passive = false, book = true, harmful = true }, -- Mortal Strike
    [21552] = { passive = false, book = true, harmful = true }, -- Mortal Strike
    [21553] = { passive = false, book = true, harmful = true }, -- Mortal Strike
    [21562] = { passive = false, book = true, harmful = false }, -- Prayer of Fortitude
    [21563] = { passive = true, book = true, harmful = false }, -- Command
    [21564] = { passive = false, book = true, harmful = false }, -- Prayer of Fortitude
    [21849] = { passive = false, book = true, harmful = false }, -- Gift of the Wild
    [21850] = { passive = false, book = true, harmful = false }, -- Gift of the Wild
    [21853] = { passive = true, book = false, harmful = false }, -- Reactive Fade
    [21887] = { passive = false, book = false, harmful = false }, -- Warrior's Wrath
    [21890] = { passive = true, book = false, harmful = false }, -- Warrior's Wrath
    [21976] = { passive = false, book = false, harmful = false }, -- Reactive Fade
    [22007] = { passive = true, book = false, harmful = false }, -- Netherwind Focus
    [22008] = { passive = false, book = false, harmful = false }, -- Netherwind Focus
    [22009] = { passive = false, book = false, harmful = false }, -- Greater Heal
    [22272] = { passive = false, book = false, harmful = true }, -- Arcane Missiles
    [22568] = { passive = false, book = true, harmful = true }, -- Ferocious Bite
    [22782] = { passive = false, book = true, harmful = false }, -- Mage Armor
    [22783] = { passive = false, book = true, harmful = false }, -- Mage Armor
    [22812] = { passive = false, book = true, harmful = false }, -- Barkskin
    [22827] = { passive = false, book = true, harmful = true }, -- Ferocious Bite
    [22828] = { passive = false, book = true, harmful = true }, -- Ferocious Bite
    [22829] = { passive = false, book = true, harmful = true }, -- Ferocious Bite
    [22842] = { passive = false, book = true, harmful = false }, -- Frenzied Regeneration
    [22845] = { passive = false, book = true, harmful = false }, -- Frenzied Regeneration
    [22855] = { passive = true, book = false, harmful = false }, -- Pimgib's Collar
    [22959] = { passive = false, book = true, harmful = true }, -- Fire Vulnerability
    [23028] = { passive = false, book = true, harmful = false }, -- Arcane Brilliance
    [23415] = { passive = false, book = false, harmful = false }, -- Improved Blessing of Protection
    [23418] = { passive = false, book = false, harmful = true }, -- Siphon Blessing
    [23455] = { passive = false, book = true, harmful = false }, -- Holy Nova
    [23458] = { passive = false, book = true, harmful = false }, -- Holy Nova
    [23459] = { passive = false, book = true, harmful = false }, -- Holy Nova
    [23551] = { passive = true, book = false, harmful = false }, -- Lightning Shield
    [23552] = { passive = false, book = false, harmful = false }, -- Lightning Shield
    [23577] = { passive = false, book = false, harmful = true }, -- Expose Weakness
    [23578] = { passive = true, book = false, harmful = false }, -- Expose Weakness
    [23584] = { passive = true, book = true, harmful = false }, -- Dual Wield Specialization
    [23683] = { passive = true, book = false, harmful = false }, -- Twisting Nether
    [23694] = { passive = false, book = false, harmful = true }, -- Improved Hamstring
    [23721] = { passive = false, book = false, harmful = false }, -- Arcane Infused
    [23860] = { passive = false, book = false, harmful = true }, -- Holy Fire
    [23881] = { passive = false, book = true, harmful = true }, -- Bloodthirst
    [23892] = { passive = false, book = true, harmful = true }, -- Bloodthirst
    [23893] = { passive = false, book = true, harmful = true }, -- Bloodthirst
    [23894] = { passive = false, book = true, harmful = true }, -- Bloodthirst
    [23922] = { passive = false, book = true, harmful = true }, -- Shield Slam
    [23923] = { passive = false, book = true, harmful = true }, -- Shield Slam
    [23924] = { passive = false, book = true, harmful = true }, -- Shield Slam
    [23925] = { passive = false, book = true, harmful = true }, -- Shield Slam
    [23989] = { passive = false, book = true, harmful = false }, -- Readiness
    [24023] = { passive = false, book = false, harmful = true }, -- Charge
    [24118] = { passive = false, book = true, harmful = true }, -- Lacerate
    [24119] = { passive = false, book = true, harmful = true }, -- Lacerate
    [24120] = { passive = false, book = true, harmful = true }, -- Lacerate
    [24239] = { passive = false, book = true, harmful = true }, -- Hammer of Wrath
    [24259] = { passive = false, book = false, harmful = true }, -- Spell Lock
    [24274] = { passive = false, book = true, harmful = true }, -- Hammer of Wrath
    [24275] = { passive = false, book = true, harmful = true }, -- Hammer of Wrath
    [24293] = { passive = true, book = true, harmful = false }, -- Improved Tracking
    [24394] = { passive = false, book = true, harmful = true }, -- Intimidation
    [24406] = { passive = false, book = true, harmful = false }, -- Improved Mend Pet
    [24417] = { passive = false, book = false, harmful = false }, -- Sheen of Zanza
    [24428] = { passive = true, book = false, harmful = false }, -- Improved Hamstring
    [24429] = { passive = true, book = false, harmful = false }, -- Improved Counterspell
    [24434] = { passive = true, book = false, harmful = false }, -- Improved Kick
    [24443] = { passive = true, book = true, harmful = false }, -- Improved Revive Pet
    [24465] = { passive = true, book = false, harmful = false }, -- Improved Concussive Shot
    [24530] = { passive = false, book = true, harmful = true }, -- Felfire
    [24583] = { passive = false, book = true, harmful = true }, -- Scorpid Poison
    [24586] = { passive = false, book = true, harmful = true }, -- Scorpid Poison
    [24587] = { passive = false, book = true, harmful = true }, -- Scorpid Poison
    [24640] = { passive = false, book = true, harmful = true }, -- Scorpid Poison
    [24844] = { passive = false, book = true, harmful = true }, -- Lightning Breath
    [24858] = { passive = false, book = true, harmful = false }, -- Moonkin Form
    [24905] = { passive = true, book = true, harmful = false }, -- Moonkin Form (Passive)
    [24907] = { passive = false, book = true, harmful = false }, -- Moonkin Aura
    [24932] = { passive = false, book = false, harmful = false }, -- Leader of the Pack
    [24968] = { passive = true, book = true, harmful = false }, -- Tranquil Spirit
    [24974] = { passive = false, book = true, harmful = true }, -- Insect Swarm
    [24975] = { passive = false, book = true, harmful = true }, -- Insect Swarm
    [24976] = { passive = false, book = true, harmful = true }, -- Insect Swarm
    [24977] = { passive = false, book = true, harmful = true }, -- Insect Swarm
    [25008] = { passive = false, book = true, harmful = true }, -- Lightning Breath
    [25009] = { passive = false, book = true, harmful = true }, -- Lightning Breath
    [25010] = { passive = false, book = true, harmful = true }, -- Lightning Breath
    [25011] = { passive = false, book = true, harmful = true }, -- Lightning Breath
    [25012] = { passive = false, book = true, harmful = true }, -- Lightning Breath
    [25022] = { passive = false, book = false, harmful = true }, -- Hallow's End Fright
    [25023] = { passive = true, book = false, harmful = false }, -- Hallow's End Fright
    [25228] = { passive = false, book = false, harmful = false }, -- Soul Link
    [25286] = { passive = false, book = true, harmful = true }, -- Heroic Strike
    [25288] = { passive = false, book = true, harmful = true }, -- Revenge
    [25289] = { passive = false, book = true, harmful = false }, -- Battle Shout
    [25290] = { passive = false, book = true, harmful = false }, -- Blessing of Wisdom
    [25291] = { passive = false, book = true, harmful = false }, -- Blessing of Might
    [25292] = { passive = false, book = true, harmful = false }, -- Holy Light
    [25295] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [25296] = { passive = false, book = true, harmful = false }, -- Aspect of the Hawk
    [25297] = { passive = false, book = true, harmful = false }, -- Healing Touch
    [25298] = { passive = false, book = true, harmful = true }, -- Starfire
    [25299] = { passive = false, book = true, harmful = false }, -- Rejuvenation
    [25300] = { passive = false, book = true, harmful = true }, -- Backstab
    [25302] = { passive = false, book = true, harmful = true }, -- Feint
    [25304] = { passive = false, book = true, harmful = true }, -- Frostbolt
    [25306] = { passive = false, book = true, harmful = true }, -- Fireball
    [25307] = { passive = false, book = true, harmful = true }, -- Shadow Bolt
    [25309] = { passive = false, book = true, harmful = true }, -- Immolate
    [25311] = { passive = false, book = true, harmful = true }, -- Corruption
    [25314] = { passive = false, book = true, harmful = false }, -- Greater Heal
    [25315] = { passive = false, book = true, harmful = false }, -- Renew
    [25316] = { passive = false, book = true, harmful = false }, -- Prayer of Healing
    [25345] = { passive = false, book = true, harmful = true }, -- Arcane Missiles
    [25347] = { passive = false, book = true, harmful = false }, -- Deadly Poison V
    [25357] = { passive = false, book = true, harmful = false }, -- Healing Wave
    [25359] = { passive = false, book = true, harmful = false }, -- Grace of Air Totem
    [25360] = { passive = true, book = false, harmful = false }, -- Grace of Air
    [25361] = { passive = false, book = true, harmful = false }, -- Strength of Earth Totem
    [25362] = { passive = true, book = false, harmful = false }, -- Strength of Earth
    [25685] = { passive = false, book = false, harmful = false }, -- Energize
    [25780] = { passive = false, book = true, harmful = false }, -- Righteous Fury
    [25782] = { passive = false, book = true, harmful = false }, -- Greater Blessing of Might
    [25894] = { passive = false, book = true, harmful = false }, -- Greater Blessing of Wisdom
    [25898] = { passive = false, book = true, harmful = false }, -- Greater Blessing of Kings
    [25902] = { passive = false, book = true, harmful = true }, -- Holy Shock
    [25903] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [25911] = { passive = false, book = true, harmful = true }, -- Holy Shock
    [25912] = { passive = false, book = true, harmful = true }, -- Holy Shock
    [25913] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [25914] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [25916] = { passive = false, book = true, harmful = false }, -- Greater Blessing of Might
    [25918] = { passive = false, book = true, harmful = false }, -- Greater Blessing of Wisdom
    [25942] = { passive = false, book = false, harmful = false }, -- Judgement of the Crusader
    [25945] = { passive = false, book = false, harmful = false }, -- Judgement of Justice
    [25956] = { passive = true, book = true, harmful = false }, -- Improved Judgement
    [25997] = { passive = false, book = true, harmful = true }, -- Eye for an Eye
    [26090] = { passive = false, book = true, harmful = true }, -- Thunderstomp
    [26119] = { passive = true, book = false, harmful = false }, -- Stormcaller Spelldamage Bonus
    [26121] = { passive = false, book = false, harmful = false }, -- Stormcaller's Wrath
    [26128] = { passive = true, book = false, harmful = false }, -- Enigma Resist Bonus
    [26129] = { passive = false, book = false, harmful = false }, -- Enigma's Answer
    [26176] = { passive = true, book = false, harmful = false }, -- Unseen Path Pet Bonus
    [26187] = { passive = false, book = true, harmful = true }, -- Thunderstomp
    [26188] = { passive = false, book = true, harmful = true }, -- Thunderstomp
    [26363] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26364] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26365] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26366] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26367] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26369] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26370] = { passive = false, book = true, harmful = true }, -- Lightning Shield
    [26467] = { passive = false, book = false, harmful = false }, -- Persistent Shield
    [26470] = { passive = false, book = false, harmful = false }, -- Persistent Shield
    [26573] = { passive = false, book = true, harmful = true }, -- Consecration
    [27498] = { passive = true, book = false, harmful = false }, -- Crusader's Wrath
    [27499] = { passive = false, book = false, harmful = false }, -- Crusader's Wrath
    [27577] = { passive = false, book = false, harmful = true }, -- Intercept
    [27617] = { passive = false, book = false, harmful = false }, -- Vanish
    [27681] = { passive = false, book = true, harmful = false }, -- Prayer of Spirit
    [27683] = { passive = false, book = true, harmful = false }, -- Prayer of Shadow Protection
    [27774] = { passive = true, book = false, harmful = false }, -- The Furious Storm
    [27775] = { passive = false, book = false, harmful = false }, -- The Furious Storm
    [27789] = { passive = true, book = true, harmful = false }, -- Holy Reach
    [27799] = { passive = false, book = true, harmful = true }, -- Holy Nova
    [27800] = { passive = false, book = true, harmful = true }, -- Holy Nova
    [27801] = { passive = false, book = true, harmful = true }, -- Holy Nova
    [27803] = { passive = false, book = true, harmful = false }, -- Holy Nova
    [27804] = { passive = false, book = true, harmful = false }, -- Holy Nova
    [27805] = { passive = false, book = true, harmful = false }, -- Holy Nova
    [27811] = { passive = true, book = true, harmful = false }, -- Blessed Recovery
    [27813] = { passive = false, book = true, harmful = false }, -- Blessed Recovery
    [27827] = { passive = false, book = false, harmful = false }, -- Spirit of Redemption
    [27828] = { passive = false, book = true, harmful = false }, -- Focused Casting
    [27839] = { passive = true, book = true, harmful = false }, -- Improved Vampiric Embrace
    [27841] = { passive = false, book = true, harmful = false }, -- Divine Spirit
    [27870] = { passive = false, book = true, harmful = false }, -- Lightwell
    [27871] = { passive = false, book = true, harmful = false }, -- Lightwell
    [27900] = { passive = true, book = true, harmful = false }, -- Spell Warding
    [28134] = { passive = false, book = false, harmful = false }, -- Power Surge
    [28270] = { passive = false, book = true, harmful = true }, -- Polymorph: Cow
    [28271] = { passive = false, book = true, harmful = true }, -- Polymorph
    [28272] = { passive = false, book = true, harmful = true }, -- Polymorph
    [28377] = { passive = false, book = true, harmful = true }, -- Shadowguard
    [28378] = { passive = false, book = true, harmful = true }, -- Shadowguard
    [28379] = { passive = false, book = true, harmful = true }, -- Shadowguard
    [28380] = { passive = false, book = true, harmful = true }, -- Shadowguard
    [28381] = { passive = false, book = true, harmful = true }, -- Shadowguard
    [28382] = { passive = false, book = true, harmful = true }, -- Shadowguard
    [28609] = { passive = false, book = true, harmful = false }, -- Frost Ward
    [28612] = { passive = false, book = true, harmful = false }, -- Conjure Food
    [28682] = { passive = false, book = false, harmful = false }, -- Combustion
    [28761] = { passive = true, book = false, harmful = false }, -- Not There
    [28762] = { passive = false, book = false, harmful = false }, -- Not There
    [28789] = { passive = true, book = false, harmful = false }, -- Holy Power
    [28802] = { passive = true, book = false, harmful = false }, -- Epiphany
    [28804] = { passive = false, book = false, harmful = false }, -- Epiphany
    [28809] = { passive = true, book = false, harmful = false }, -- Greater Heal
    [28820] = { passive = false, book = false, harmful = false }, -- Lightning Shield
    [28821] = { passive = true, book = false, harmful = false }, -- Lightning Shield
    [28845] = { passive = true, book = false, harmful = false }, -- Cheat Death
    [28846] = { passive = false, book = false, harmful = false }, -- Cheat Death
    [28996] = { passive = true, book = true, harmful = false }, -- Elemental Warding
    [28999] = { passive = true, book = true, harmful = false }, -- Elemental Reach
    [29062] = { passive = true, book = true, harmful = false }, -- Eye of the Storm
    [29074] = { passive = true, book = true, harmful = false }, -- Master of Elements
    [29131] = { passive = false, book = false, harmful = false }, -- Bloodrage
    [29166] = { passive = false, book = true, harmful = false }, -- Innervate
    [29184] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29185] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29187] = { passive = true, book = true, harmful = false }, -- Natural Grace
    [29189] = { passive = true, book = true, harmful = false }, -- Healing Grace
    [29191] = { passive = true, book = true, harmful = false }, -- Healing Grace
    [29192] = { passive = true, book = true, harmful = false }, -- Improved Weapon Totems
    [29193] = { passive = true, book = true, harmful = false }, -- Improved Weapon Totems
    [29194] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29195] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29196] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29197] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29198] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29199] = { passive = false, book = false, harmful = false }, -- Corrupted Mind
    [29206] = { passive = true, book = true, harmful = false }, -- Healing Way
    [29228] = { passive = false, book = true, harmful = true }, -- Flame Shock
    [29233] = { passive = false, book = false, harmful = false }, -- Beast of the Unseen Path
    [29438] = { passive = true, book = true, harmful = false }, -- Precision
    [29441] = { passive = true, book = true, harmful = false }, -- Magic Absorption
    [29544] = { passive = false, book = false, harmful = true }, -- Intimidating Shout
    [30003] = { passive = false, book = false, harmful = false }, -- Sheen of Zanza
    [30160] = { passive = true, book = true, harmful = false }, -- Elemental Devastation
    [30165] = { passive = false, book = true, harmful = false }, -- Elemental Devastation
    [30331] = { passive = false, book = false, harmful = false }, -- Permanent Sheen of Zanza
    [30892] = { passive = true, book = true, harmful = false }, -- Sleight of Hand
    [31016] = { passive = false, book = true, harmful = true }, -- Eviscerate
    [31018] = { passive = false, book = true, harmful = true }, -- Ferocious Bite
    [36936] = { passive = false, book = true, harmful = false }, -- Totemic Recall
    [52127] = { passive = false, book = false, harmful = false }, -- ?
    [53601] = { passive = false, book = false, harmful = false }, -- Sacred Shield
    [53672] = { passive = false, book = false, harmful = false }, -- Infusion of Light
    [58597] = { passive = false, book = false, harmful = false }, -- Sacred Shield
    [66842] = { passive = false, book = true, harmful = false }, -- Call of the Elements
    [66843] = { passive = false, book = true, harmful = false }, -- Call of the Ancestors
    [66844] = { passive = false, book = true, harmful = false }, -- Call of the Spirits
    [368218] = { passive = false, book = false, harmful = false }, -- Consecration
    [368235] = { passive = false, book = false, harmful = false }, -- Consecration
    [398196] = { passive = false, book = true, harmful = true }, -- Quick Draw
    [399956] = { passive = false, book = true, harmful = true }, -- Mutilate
    [399960] = { passive = false, book = true, harmful = true }, -- Mutilate
    [399961] = { passive = false, book = true, harmful = true }, -- Mutilate
    [399965] = { passive = true, book = false, harmful = false }, -- Deadly Brew
    [399969] = { passive = true, book = false, harmful = false }, -- Deadly Brew
    [399985] = { passive = false, book = true, harmful = true }, -- Shadowstrike
    [399986] = { passive = false, book = true, harmful = true }, -- Shuriken Toss
    [400009] = { passive = false, book = true, harmful = true }, -- Between the Eyes
    [400012] = { passive = false, book = true, harmful = true }, -- Blade Dance
    [400015] = { passive = false, book = false, harmful = false }, -- Rolling with the Punches
    [400016] = { passive = true, book = false, harmful = false }, -- Rolling with the Punches
    [400029] = { passive = false, book = false, harmful = true }, -- Shadowstep
    [400040] = { passive = true, book = false, harmful = false }, -- Rolling with the Punches
    [400573] = { passive = false, book = false, harmful = false }, -- Arcane Blast
    [400574] = { passive = false, book = true, harmful = true }, -- Arcane Blast
    [400586] = { passive = false, book = false, harmful = false }, -- Arcane Blast
    [400588] = { passive = true, book = false, harmful = false }, -- Missile Barrage
    [400589] = { passive = false, book = false, harmful = false }, -- Missile Barrage
    [400610] = { passive = false, book = true, harmful = true }, -- Arcane Barrage
    [400613] = { passive = false, book = true, harmful = true }, -- Living Bomb
    [400614] = { passive = false, book = true, harmful = true }, -- Living Bomb
    [400616] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400618] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400619] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400620] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400621] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400622] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400623] = { passive = false, book = true, harmful = true }, -- Fire Blast
    [400624] = { passive = true, book = false, harmful = false }, -- Heating Up
    [400625] = { passive = false, book = false, harmful = false }, -- Heating Up
    [400640] = { passive = false, book = true, harmful = true }, -- Ice Lance
    [400647] = { passive = true, book = false, harmful = false }, -- Fingers of Frost
    [400669] = { passive = false, book = false, harmful = false }, -- Fingers of Frost
    [400670] = { passive = false, book = false, harmful = false }, -- Fingers of Frost
    [400730] = { passive = false, book = false, harmful = false }, -- Fireball!
    [400731] = { passive = true, book = false, harmful = false }, -- Brain Freeze
    [401417] = { passive = false, book = true, harmful = false }, -- Regeneration
    [401462] = { passive = false, book = true, harmful = false }, -- Rewind Time
    [401488] = { passive = false, book = true, harmful = false }, -- Engrave Pants - Cutty's Rune
    [401502] = { passive = false, book = true, harmful = true }, -- Frostfire Bolt
    [401556] = { passive = false, book = true, harmful = true }, -- Living Flame
    [401558] = { passive = false, book = true, harmful = false }, -- Living Flame
    [401725] = { passive = true, book = false, harmful = false }, -- Brain Freeze
    [401729] = { passive = true, book = false, harmful = false }, -- Arcane Blast
    [401736] = { passive = true, book = false, harmful = false }, -- Missile Barrage
    [401741] = { passive = true, book = false, harmful = false }, -- Fingers of Frost
    [401744] = { passive = true, book = false, harmful = false }, -- Living Flame
    [401859] = { passive = false, book = true, harmful = false }, -- Prayer of Mending
    [401863] = { passive = false, book = true, harmful = false }, -- Prayer of Mending
    [401877] = { passive = false, book = false, harmful = false }, -- Prayer of Mending
    [401946] = { passive = false, book = true, harmful = false }, -- Circle of Healing
    [401955] = { passive = false, book = true, harmful = true }, -- Shadow Word: Death
    [401977] = { passive = false, book = true, harmful = false }, -- Shadowfiend
    [402004] = { passive = false, book = true, harmful = false }, -- Pain Suppression
    [402174] = { passive = false, book = true, harmful = false }, -- Penance
    [402284] = { passive = false, book = true, harmful = false }, -- Penance
    [402289] = { passive = false, book = true, harmful = false }, -- Penance
    [402668] = { passive = false, book = true, harmful = true }, -- Vampiric Touch
    [402789] = { passive = false, book = true, harmful = false }, -- Eye of the Void
    [402799] = { passive = false, book = true, harmful = false }, -- Homunculi
    [402877] = { passive = true, book = false, harmful = false }, -- Flagellation
    [402906] = { passive = false, book = false, harmful = false }, -- Flagellation
    [402911] = { passive = false, book = true, harmful = true }, -- Raging Blow
    [402913] = { passive = false, book = true, harmful = false }, -- Enraged Regeneration
    [402927] = { passive = false, book = true, harmful = true }, -- Victory Rush
    [402975] = { passive = false, book = false, harmful = false }, -- Victorious
    [403196] = { passive = false, book = true, harmful = true }, -- Devastate
    [403215] = { passive = false, book = true, harmful = false }, -- Commanding Shout
    [403228] = { passive = false, book = true, harmful = true }, -- Meathook
    [403619] = { passive = false, book = true, harmful = false }, -- Fel Armor
    [403629] = { passive = false, book = true, harmful = true }, -- Chaos Bolt
    [403677] = { passive = false, book = true, harmful = true }, -- Drain Life
    [403685] = { passive = false, book = true, harmful = true }, -- Drain Life
    [403686] = { passive = false, book = true, harmful = true }, -- Drain Life
    [403687] = { passive = false, book = true, harmful = true }, -- Drain Life
    [403688] = { passive = false, book = true, harmful = true }, -- Drain Life
    [403689] = { passive = false, book = true, harmful = true }, -- Drain Life
    [403789] = { passive = false, book = true, harmful = false }, -- Metamorphosis
    [403828] = { passive = false, book = true, harmful = true }, -- Menace
    [403835] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403839] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403840] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403841] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403842] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403843] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403844] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403848] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403851] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403852] = { passive = false, book = true, harmful = true }, -- Shadow Cleave
    [403863] = { passive = true, book = false, harmful = false }, -- Soul Siphon
    [406722] = { passive = false, book = false, harmful = false }, -- Shadowstep
    [407627] = { passive = false, book = true, harmful = false }, -- Righteous Fury
    [407632] = { passive = false, book = true, harmful = true }, -- Hammer of the Righteous
    [407778] = { passive = false, book = true, harmful = true }, -- Divine Storm
    [407784] = { passive = false, book = true, harmful = false }, -- Divine Storm
    [407788] = { passive = false, book = true, harmful = false }, -- Avenging Wrath
    [407798] = { passive = false, book = true, harmful = false }, -- Seal of Martyrdom
    [407799] = { passive = false, book = true, harmful = true }, -- Seal of Martyrdom
    [407803] = { passive = false, book = true, harmful = true }, -- Judgement of Martyrdom
    [407804] = { passive = false, book = true, harmful = false }, -- Divine Sacrifice
    [407880] = { passive = false, book = true, harmful = false }, -- Inspiration Exemplar
    [407957] = { passive = false, book = false, harmful = false }, -- Avenging Wrath
    [407975] = { passive = false, book = false, harmful = false }, -- Wild Strikes
    [407977] = { passive = true, book = false, harmful = false }, -- Wild Strikes
    [407995] = { passive = false, book = true, harmful = true }, -- Primal Bite
    [408024] = { passive = false, book = true, harmful = false }, -- Survival Instincts
    [408120] = { passive = false, book = true, harmful = false }, -- Wild Growth
    [408124] = { passive = false, book = true, harmful = false }, -- Lifebloom
    [408245] = { passive = false, book = true, harmful = false }, -- Lifebloom
    [408247] = { passive = false, book = true, harmful = false }, -- Nourish
    [408248] = { passive = true, book = false, harmful = false }, -- Eclipse
    [408255] = { passive = false, book = false, harmful = false }, -- Eclipse
    [408258] = { passive = true, book = false, harmful = false }, -- Dreamstate
    [408261] = { passive = false, book = false, harmful = false }, -- Dreamstate
    [408339] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [408341] = { passive = false, book = true, harmful = false }, -- Fire Nova
    [408342] = { passive = false, book = true, harmful = false }, -- Fire Nova
    [408343] = { passive = false, book = true, harmful = false }, -- Fire Nova
    [408344] = { passive = false, book = true, harmful = false }, -- Fire Nova
    [408345] = { passive = false, book = true, harmful = false }, -- Fire Nova
    [408423] = { passive = false, book = false, harmful = true }, -- Fire Nova
    [408424] = { passive = false, book = false, harmful = true }, -- Fire Nova
    [408426] = { passive = false, book = false, harmful = true }, -- Fire Nova
    [408427] = { passive = false, book = false, harmful = true }, -- Fire Nova
    [408428] = { passive = false, book = false, harmful = true }, -- Fire Nova
    [408439] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408440] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408441] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408442] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408443] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408472] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408473] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408474] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408475] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408477] = { passive = false, book = true, harmful = true }, -- Lightning Bolt
    [408479] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [408481] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [408482] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [408484] = { passive = false, book = true, harmful = true }, -- Chain Lightning
    [408490] = { passive = false, book = false, harmful = true }, -- Lava Burst
    [408498] = { passive = true, book = false, harmful = false }, -- Maelstrom Weapon
    [408505] = { passive = false, book = false, harmful = false }, -- Maelstrom Weapon
    [408507] = { passive = false, book = true, harmful = true }, -- Lava Lash
    [408510] = { passive = false, book = true, harmful = false }, -- Water Shield
    [408514] = { passive = false, book = true, harmful = false }, -- Earth Shield
    [408519] = { passive = false, book = true, harmful = false }, -- Earth Shield
    [408521] = { passive = false, book = true, harmful = false }, -- Riptide
    [408531] = { passive = true, book = false, harmful = false }, -- Way of Earth
    [408680] = { passive = false, book = false, harmful = false }, -- Way of Earth
    [408696] = { passive = false, book = true, harmful = false }, -- Spirit of the Alpha
    [408699] = { passive = false, book = false, harmful = true }, -- Waylay
    [408700] = { passive = true, book = false, harmful = false }, -- Waylay
    [409324] = { passive = false, book = true, harmful = false }, -- Ancestral Guidance
    [409333] = { passive = false, book = true, harmful = false }, -- Ancestral Guidance
    [409337] = { passive = false, book = true, harmful = true }, -- Ancestral Guidance
    [409365] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [409379] = { passive = false, book = true, harmful = false }, -- Kill Command
    [409396] = { passive = false, book = false, harmful = false }, -- Kill Command
    [409418] = { passive = false, book = false, harmful = false }, -- Kill Command
    [409433] = { passive = false, book = true, harmful = true }, -- Chimera Shot
    [409493] = { passive = false, book = true, harmful = true }, -- Chimera Shot - Serpent
    [409494] = { passive = false, book = true, harmful = false }, -- Chimera Shot - Viper
    [409495] = { passive = false, book = true, harmful = true }, -- Chimera Shot - Scorpid
    [409504] = { passive = true, book = false, harmful = false }, -- Expose Weakness
    [409507] = { passive = false, book = false, harmful = false }, -- Expose Weakness
    [409580] = { passive = false, book = true, harmful = false }, -- Heart of the Lion
    [409691] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409693] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409748] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409750] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409751] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409752] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409754] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409755] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [409805] = { passive = true, book = false, harmful = false }, -- Wild Strikes
    [409813] = { passive = true, book = false, harmful = false }, -- Eclipse
    [409925] = { passive = true, book = false, harmful = false }, -- Divine Light
    [409934] = { passive = true, book = false, harmful = false }, -- Avenging Wrath
    [409936] = { passive = true, book = false, harmful = false }, -- Inspiration Exemplar
    [409938] = { passive = true, book = false, harmful = false }, -- Fire Nova
    [409941] = { passive = true, book = false, harmful = false }, -- Water Shield
    [409946] = { passive = true, book = false, harmful = false }, -- Maelstrom Weapon
    [409955] = { passive = true, book = false, harmful = false }, -- Way of Earth
    [409959] = { passive = true, book = false, harmful = false }, -- Expose Weakness
    [409960] = { passive = true, book = false, harmful = false }, -- Cobra Slayer
    [409974] = { passive = true, book = false, harmful = false }, -- Kill Shot
    [409979] = { passive = true, book = false, harmful = false }, -- Lone Wolf
    [410144] = { passive = false, book = false, harmful = false }, -- Savage Defense
    [410156] = { passive = false, book = false, harmful = true }, -- Stormstrike
    [410176] = { passive = false, book = true, harmful = true }, -- Skull Bash
    [411128] = { passive = false, book = true, harmful = true }, -- Swipe
    [411684] = { passive = false, book = false, harmful = true }, -- Charge
    [411688] = { passive = false, book = false, harmful = true }, -- Charge Stun
    [412018] = { passive = false, book = false, harmful = false }, -- Sacred Shield
    [412019] = { passive = false, book = true, harmful = false }, -- Sacred Shield
    [412324] = { passive = true, book = false, harmful = false }, -- Enlightenment
    [412325] = { passive = false, book = false, harmful = false }, -- Enlightenment
    [412326] = { passive = false, book = false, harmful = false }, -- Enlightenment
    [412510] = { passive = false, book = true, harmful = false }, -- Mass Regeneration
    [412532] = { passive = false, book = true, harmful = true }, -- Spellfrost Bolt
    [412538] = { passive = false, book = false, harmful = true }, -- Ignite
    [412609] = { passive = false, book = false, harmful = true }, -- Deep Wound
    [412729] = { passive = true, book = true, harmful = false }, -- Tamed Pet Passive (DND)
    [412732] = { passive = true, book = false, harmful = false }, -- Demonic Knowledge
    [412735] = { passive = false, book = false, harmful = false }, -- Demonic Knowledge
    [412758] = { passive = false, book = true, harmful = true }, -- Incinerate
    [412788] = { passive = false, book = true, harmful = true }, -- Demon Charge
    [412789] = { passive = false, book = true, harmful = true }, -- Demonic Howl
    [412798] = { passive = true, book = true, harmful = false }, -- Dance of the Wicked
    [412800] = { passive = false, book = false, harmful = false }, -- Dance of the Wicked
    [413247] = { passive = false, book = false, harmful = false }, -- Serendipity
    [413248] = { passive = true, book = false, harmful = false }, -- Serendipity
    [413259] = { passive = false, book = true, harmful = true }, -- Mind Sear
    [413260] = { passive = false, book = true, harmful = true }, -- Mind Sear
    [413380] = { passive = true, book = false, harmful = false }, -- Blood Surge
    [413399] = { passive = false, book = false, harmful = false }, -- Blood Surge
    [413404] = { passive = true, book = false, harmful = false }, -- Single-Minded Fury
    [414644] = { passive = false, book = true, harmful = true }, -- Lacerate
    [414647] = { passive = false, book = true, harmful = true }, -- Lacerate
    [414683] = { passive = false, book = true, harmful = false }, -- Living Seed
    [414684] = { passive = false, book = true, harmful = true }, -- Sunfire
    [414687] = { passive = false, book = true, harmful = true }, -- Sunfire
    [414689] = { passive = false, book = true, harmful = true }, -- Sunfire
    [414799] = { passive = true, book = false, harmful = false }, -- Fury of Stormrage
    [414800] = { passive = false, book = false, harmful = false }, -- Fury of Stormrage
    [414923] = { passive = false, book = false, harmful = true }, -- Feral Charge
    [415004] = { passive = false, book = false, harmful = false }, -- Unpowered
    [415005] = { passive = false, book = false, harmful = false }, -- Powered
    [415058] = { passive = false, book = false, harmful = false }, -- Guarded by the Light
    [415059] = { passive = true, book = false, harmful = false }, -- Guarded by the Light
    [415068] = { passive = false, book = true, harmful = true }, -- Exorcism
    [415069] = { passive = false, book = true, harmful = true }, -- Exorcism
    [415070] = { passive = false, book = true, harmful = true }, -- Exorcism
    [415071] = { passive = false, book = true, harmful = true }, -- Exorcism
    [415072] = { passive = false, book = true, harmful = true }, -- Exorcism
    [415073] = { passive = false, book = true, harmful = true }, -- Exorcism
    [415076] = { passive = true, book = true, harmful = false }, -- Exorcist
    [415100] = { passive = true, book = false, harmful = false }, -- Power Surge
    [415105] = { passive = false, book = false, harmful = false }, -- Power Surge
    [415236] = { passive = false, book = true, harmful = false }, -- Healing Rain
    [415242] = { passive = false, book = true, harmful = false }, -- Healing Rain
    [415320] = { passive = false, book = true, harmful = true }, -- Flanking Strike
    [415327] = { passive = true, book = false, harmful = false }, -- Flanking Strike
    [415335] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415336] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415337] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415338] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415340] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415341] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415342] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415343] = { passive = false, book = true, harmful = true }, -- Raptor Strike
    [415358] = { passive = true, book = false, harmful = false }, -- Raptor Fury
    [415362] = { passive = false, book = false, harmful = false }, -- Raptor Fury
    [415370] = { passive = true, book = false, harmful = false }, -- Lone Wolf
    [415399] = { passive = true, book = false, harmful = false }, -- Sniper Training
    [415405] = { passive = true, book = false, harmful = false }, -- Rapid Killing
    [415407] = { passive = false, book = false, harmful = false }, -- Rapid Killing
    [415413] = { passive = true, book = false, harmful = false }, -- Lock and Load
    [415414] = { passive = false, book = false, harmful = false }, -- Lock and Load
    [415423] = { passive = false, book = true, harmful = false }, -- Aspect of the Viper
    [415429] = { passive = true, book = true, harmful = false }, -- Hunter Pet Scaling
    [415703] = { passive = true, book = false, harmful = false }, -- Sacred Shield
    [415712] = { passive = true, book = false, harmful = false }, -- Power Surge
    [415725] = { passive = true, book = false, harmful = false }, -- Waylay
    [415729] = { passive = true, book = false, harmful = false }, -- Enlightenment
    [415743] = { passive = true, book = false, harmful = false }, -- Blood Surge
    [415749] = { passive = true, book = false, harmful = false }, -- Demonic Knowledge
    [415751] = { passive = true, book = false, harmful = false }, -- Dance of the Wicked
    [415755] = { passive = true, book = false, harmful = false }, -- Guarded by the Light
    [416189] = { passive = true, book = true, harmful = false }, -- Warlock Pet Scaling
    [417045] = { passive = false, book = true, harmful = false }, -- Tiger's Fury
    [417046] = { passive = true, book = false, harmful = false }, -- King of the Jungle
    [417123] = { passive = true, book = true, harmful = false }, -- Enhanced Restoration
    [417141] = { passive = false, book = true, harmful = false }, -- Berserk
    [417145] = { passive = true, book = false, harmful = false }, -- Gore
    [417147] = { passive = false, book = false, harmful = false }, -- Efflorescence
    [417148] = { passive = false, book = true, harmful = false }, -- Efflorescence
    [417149] = { passive = true, book = false, harmful = false }, -- Efflorescence
    [417157] = { passive = false, book = true, harmful = true }, -- Starsurge
    [421248] = { passive = false, book = false, harmful = false }, -- Shadowguard
    [424762] = { passive = true, book = false, harmful = false }, -- King of the Jungle
    [424785] = { passive = false, book = true, harmful = true }, -- Saber Slash
    [424799] = { passive = false, book = true, harmful = true }, -- Shiv
    [424919] = { passive = false, book = true, harmful = true }, -- Main Gauche
    [424980] = { passive = true, book = false, harmful = false }, -- Cutthroat
    [424982] = { passive = true, book = false, harmful = false }, -- Main Gauche
    [425012] = { passive = false, book = true, harmful = true }, -- Poisoned Knife
    [425013] = { passive = false, book = true, harmful = true }, -- Poisoned Knife
    [425096] = { passive = true, book = false, harmful = false }, -- Master of Subtlety
    [425098] = { passive = false, book = false, harmful = false }, -- Master of Subtlety
    [425101] = { passive = true, book = false, harmful = false }, -- Master of Subtlety
    [425121] = { passive = false, book = true, harmful = false }, -- Icy Veins
    [425124] = { passive = false, book = true, harmful = true }, -- Arcane Surge
    [425187] = { passive = true, book = false, harmful = false }, -- Chronostatic Preservation
    [425204] = { passive = false, book = true, harmful = true }, -- Void Plague
    [425207] = { passive = false, book = true, harmful = false }, -- Power Word: Barrier
    [425268] = { passive = false, book = true, harmful = false }, -- Renew
    [425269] = { passive = false, book = true, harmful = false }, -- Renew
    [425270] = { passive = false, book = true, harmful = false }, -- Renew
    [425271] = { passive = false, book = true, harmful = false }, -- Renew
    [425272] = { passive = false, book = true, harmful = false }, -- Renew
    [425273] = { passive = false, book = true, harmful = false }, -- Renew
    [425274] = { passive = false, book = true, harmful = false }, -- Renew
    [425275] = { passive = false, book = true, harmful = false }, -- Renew
    [425276] = { passive = false, book = true, harmful = false }, -- Renew
    [425277] = { passive = false, book = true, harmful = false }, -- Renew
    [425280] = { passive = true, book = false, harmful = false }, -- Renewed Hope
    [425294] = { passive = false, book = true, harmful = false }, -- Dispersion
    [425303] = { passive = true, book = false, harmful = false }, -- Renewed Hope
    [425336] = { passive = false, book = true, harmful = false }, -- Rage of the Farseer
    [425339] = { passive = false, book = true, harmful = true }, -- Molten Blast
    [425412] = { passive = true, book = false, harmful = false }, -- Frenzied Assault
    [425463] = { passive = false, book = true, harmful = false }, -- Demonic Grace
    [425464] = { passive = true, book = false, harmful = false }, -- Demonic Pact
    [425466] = { passive = true, book = false, harmful = false }, -- Demonic Pact
    [425467] = { passive = false, book = false, harmful = false }, -- Demonic Pact
    [425600] = { passive = false, book = true, harmful = false }, -- Horn of Lordaeron
    [425609] = { passive = false, book = true, harmful = true }, -- Rebuke
    [425614] = { passive = true, book = false, harmful = false }, -- Hallowed Ground
    [425711] = { passive = false, book = true, harmful = true }, -- Carve
    [425713] = { passive = true, book = false, harmful = false }, -- Cobra Strikes
    [425714] = { passive = false, book = false, harmful = false }, -- Cobra Strikes
    [425718] = { passive = false, book = false, harmful = false }, -- Cobra Strikes
    [425728] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425729] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425730] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425732] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425733] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425734] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425735] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425736] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425737] = { passive = false, book = true, harmful = true }, -- Serpent Sting
    [425738] = { passive = true, book = false, harmful = false }, -- Serpent Spread
    [425755] = { passive = true, book = false, harmful = false }, -- Cobra Strikes
    [425756] = { passive = true, book = false, harmful = false }, -- Serpent Spread
    [425757] = { passive = true, book = false, harmful = false }, -- Flanking Strike
    [425858] = { passive = true, book = false, harmful = false }, -- Ancestral Awakening
    [425874] = { passive = false, book = true, harmful = false }, -- Decoy Totem
    [425876] = { passive = false, book = false, harmful = false }, -- Decoy Totem
    [425879] = { passive = true, book = false, harmful = false }, -- Ancestral Awakening
    [425881] = { passive = true, book = false, harmful = false }, -- Decoy Totem
    [426065] = { passive = true, book = false, harmful = false }, -- Infusion of Light
    [426179] = { passive = true, book = false, harmful = false }, -- Infusion of Light
    [426195] = { passive = false, book = true, harmful = false }, -- Vengeance
    [426241] = { passive = false, book = true, harmful = true }, -- Invocation
    [426243] = { passive = true, book = false, harmful = false }, -- Invocation
    [426245] = { passive = false, book = true, harmful = true }, -- Invocation
    [426246] = { passive = false, book = true, harmful = true }, -- Invocation
    [426247] = { passive = false, book = true, harmful = true }, -- Invocation
    [426301] = { passive = false, book = true, harmful = false }, -- Grimoire of Synergy
    [426303] = { passive = false, book = false, harmful = false }, -- Grimoire of Synergy
    [426311] = { passive = false, book = false, harmful = false }, -- Flame
    [426316] = { passive = true, book = false, harmful = false }, -- Shadow and Flame
    [426320] = { passive = false, book = true, harmful = true }, -- Shadowflame
    [426325] = { passive = false, book = true, harmful = true }, -- Shadowflame
    [426331] = { passive = false, book = true, harmful = true }, -- Invocation
    [426442] = { passive = true, book = false, harmful = false }, -- Invocation
    [426444] = { passive = true, book = false, harmful = false }, -- Grimoire of Synergy
    [426449] = { passive = true, book = false, harmful = false }, -- Shadow and Flame
    [426490] = { passive = false, book = true, harmful = false }, -- Rallying Cry
    [426953] = { passive = true, book = false, harmful = false }, -- Taste for Blood
    [426969] = { passive = false, book = false, harmful = false }, -- Taste for Blood
    [426978] = { passive = true, book = false, harmful = false }, -- Sword and Board
    [426979] = { passive = false, book = false, harmful = false }, -- Sword and Board
    [427065] = { passive = true, book = false, harmful = false }, -- Wrecking Crew
    [427066] = { passive = false, book = false, harmful = false }, -- Enrage
    [427067] = { passive = true, book = false, harmful = false }, -- Taste for Blood
    [427073] = { passive = true, book = false, harmful = false }, -- Sword and Board
    [427074] = { passive = true, book = false, harmful = false }, -- Wrecking Crew
    [427076] = { passive = false, book = true, harmful = false }, -- Engrave Helm - Taste for Blood
    [427078] = { passive = false, book = true, harmful = false }, -- Engrave Helm - Vigilance
    [427080] = { passive = false, book = true, harmful = false }, -- Engrave Helm - Shield Mastery
    [427081] = { passive = false, book = true, harmful = false }, -- Engrave Bracers - Rampage
    [427082] = { passive = false, book = true, harmful = false }, -- Engrave Bracers - Sword and Board
    [427084] = { passive = false, book = true, harmful = false }, -- Engrave Bracers - Wrecking Crew
    [427726] = { passive = false, book = false, harmful = false }, -- Immolation Aura
    [427742] = { passive = false, book = true, harmful = true }, -- Anguish
    [427743] = { passive = false, book = true, harmful = false }, -- Avoidance
    [427744] = { passive = false, book = true, harmful = true }, -- Cleave
    [427745] = { passive = false, book = true, harmful = true }, -- Intercept
    [427746] = { passive = false, book = true, harmful = true }, -- Intercept Stun
    [428728] = { passive = false, book = false, harmful = false }, -- Frenzy
    [428739] = { passive = false, book = false, harmful = true }, -- Deep Freeze
    [428878] = { passive = false, book = true, harmful = true }, -- Balefire Bolt
    [428909] = { passive = true, book = false, harmful = false }, -- Light's Grace
    [428912] = { passive = false, book = false, harmful = false }, -- Light's Grace
    [428920] = { passive = true, book = false, harmful = false }, -- Deep Freeze
    [429243] = { passive = true, book = false, harmful = false }, -- Light's Grace
    [429303] = { passive = true, book = false, harmful = false }, -- Deep Freeze
    [429765] = { passive = false, book = true, harmful = true }, -- Quick Strike
    [430025] = { passive = false, book = false, harmful = false }, -- Demonic Grace
    [430472] = { passive = false, book = false, harmful = false }, -- Single-Minded Fury
    [431046] = { passive = false, book = false, harmful = false }, -- Frenzied Assault
    [431446] = { passive = true, book = false, harmful = false }, -- Gore
    [431466] = { passive = true, book = false, harmful = false }, -- Efflorescence
    [431606] = { passive = false, book = false, harmful = false }, -- Frenzy
    [431622] = { passive = true, book = false, harmful = false }, -- Divine Aegis
    [431624] = { passive = false, book = false, harmful = false }, -- Divine Aegis
    [431655] = { passive = false, book = true, harmful = true }, -- Mind Spike
    [431664] = { passive = true, book = false, harmful = false }, -- Surge of Light
    [431666] = { passive = false, book = false, harmful = false }, -- Surge of Light
    [431668] = { passive = true, book = false, harmful = false }, -- Surge of Light
    [431757] = { passive = true, book = false, harmful = false }, -- Immolation Aura
    [432041] = { passive = false, book = false, harmful = false }, -- Tidal Waves
    [432042] = { passive = true, book = false, harmful = false }, -- Tidal Waves
    [432056] = { passive = true, book = false, harmful = false }, -- Rolling Thunder
    [432140] = { passive = true, book = false, harmful = false }, -- Overcharged
    [432143] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432144] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432145] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432146] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432147] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432148] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432149] = { passive = false, book = false, harmful = true }, -- Lightning Shield
    [432235] = { passive = true, book = false, harmful = false }, -- Rolling Thunder
    [432240] = { passive = true, book = false, harmful = false }, -- Overcharged
    [432266] = { passive = false, book = false, harmful = false }, -- Honor Among Thieves
    [432268] = { passive = false, book = false, harmful = false }, -- Honor Among Thieves
    [432275] = { passive = false, book = false, harmful = true }, -- Carnage
    [432276] = { passive = true, book = false, harmful = false }, -- Carnage
    [432294] = { passive = true, book = false, harmful = false }, -- Honor Among Thieves
    [433521] = { passive = true, book = false, harmful = false }, -- Deadly Brew
    [435977] = { passive = true, book = false, harmful = false }, -- Energized Hyperconductor
    [435978] = { passive = false, book = false, harmful = false }, -- Energized Hyperconductor
    [435982] = { passive = true, book = false, harmful = false }, -- Energize
    [435984] = { passive = true, book = true, harmful = false }, -- Enhanced Blessings
    [436287] = { passive = true, book = false, harmful = false }, -- Improved Wrath
    [436364] = { passive = true, book = false, harmful = false }, -- Two-Handed Mastery
    [436365] = { passive = false, book = false, harmful = false }, -- Two-Handed Mastery
    [436367] = { passive = true, book = false, harmful = false }, -- Two-Handed Mastery
    [436390] = { passive = false, book = false, harmful = false }, -- Decoy Totem
    [436430] = { passive = false, book = false, harmful = false }, -- Avenging Wrath
    [436516] = { passive = false, book = false, harmful = false }, -- Chronostatic Preservation
    [436858] = { passive = false, book = false, harmful = false }, -- [DNT] Combat Dummy I
    [436861] = { passive = false, book = false, harmful = false }, -- [DNT] Combat Dummy II
    [436863] = { passive = false, book = false, harmful = false }, -- [DNT] Combat Dummy III
    [436949] = { passive = true, book = true, harmful = false }, -- Expanded Intellect
    [436951] = { passive = true, book = true, harmful = false }, -- Increased Fortitude
    [436956] = { passive = true, book = true, harmful = false }, -- Deeper Wilds
    [436969] = { passive = false, book = false, harmful = false }, -- [DNT] Combat Dummy II Powered
    [436970] = { passive = false, book = false, harmful = false }, -- [DNT] Combat Dummy III Powered
    [436973] = { passive = false, book = false, harmful = false }, -- [DNT] Combat Dummy I Powered
    [437009] = { passive = false, book = true, harmful = false }, -- Totemic Call
    [437032] = { passive = true, book = true, harmful = false }, -- Soul Harvest
    [437063] = { passive = false, book = false, harmful = false }, -- Infusion of Light
    [437132] = { passive = false, book = false, harmful = true }, -- Dreamstate
    [437138] = { passive = false, book = true, harmful = false }, -- Revive
    [437169] = { passive = false, book = true, harmful = false }, -- Portal of Summoning
    [437877] = { passive = false, book = false, harmful = false }, -- Infusion of Light
    [438040] = { passive = false, book = true, harmful = true }, -- Redirect
    [438538] = { passive = false, book = false, harmful = true }, -- Charge
    [438541] = { passive = false, book = false, harmful = true }, -- Charge
    [439748] = { passive = false, book = true, harmful = false }, -- Starfall
    [439753] = { passive = false, book = true, harmful = true }, -- Starfall
    [439756] = { passive = false, book = true, harmful = true }, -- Starfall
    [439768] = { passive = true, book = false, harmful = false }, -- Starfall
    [440113] = { passive = true, book = false, harmful = false }, -- Sudden Death
    [440114] = { passive = false, book = false, harmful = false }, -- Sudden Death
    [440285] = { passive = false, book = false, harmful = false }, -- Power Surge
    [440484] = { passive = true, book = false, harmful = false }, -- Fresh Meat
    [440488] = { passive = false, book = true, harmful = false }, -- Shockwave
    [440493] = { passive = true, book = false, harmful = false }, -- Fresh Meat
    [440495] = { passive = true, book = false, harmful = false }, -- Sudden Death
    [440529] = { passive = true, book = false, harmful = false }, -- Resourcefulness
    [440651] = { passive = false, book = false, harmful = false }, -- Sacred Shield
    [440658] = { passive = false, book = true, harmful = true }, -- Shield of Righteousness
    [440667] = { passive = false, book = false, harmful = true }, -- Vindication
    [440668] = { passive = false, book = false, harmful = false }, -- Vindication
    [440677] = { passive = false, book = true, harmful = true }, -- Righteous Judgement
    [440791] = { passive = true, book = false, harmful = false }, -- Shock and Awe
    [440802] = { passive = false, book = true, harmful = false }, -- Frozen Orb
    [440809] = { passive = false, book = true, harmful = true }, -- Frozen Orb
    [440870] = { passive = true, book = false, harmful = false }, -- Decimation
    [440873] = { passive = false, book = false, harmful = false }, -- Decimation
    [440892] = { passive = false, book = true, harmful = true }, -- Curse of the Elements
    [441260] = { passive = false, book = false, harmful = false }, -- Eclipse
    [443369] = { passive = false, book = false, harmful = false }, -- Chronostatic Preservation
    [444678] = { passive = false, book = true, harmful = true }, -- Lava Breath
    [444681] = { passive = false, book = true, harmful = true }, -- Lava Breath
    [446219] = { passive = false, book = false, harmful = false }, -- Cries of Corrupted Ancestry
    [446220] = { passive = true, book = false, harmful = false }, -- Totem of Tormented Ancestry
    [446699] = { passive = false, book = false, harmful = false }, -- Gore
    [447549] = { passive = false, book = false, harmful = false }, -- Feedback
    [449924] = { passive = true, book = false, harmful = false }, -- Power Shredder
    [449925] = { passive = false, book = false, harmful = false }, -- Power Shredder
    [449927] = { passive = false, book = false, harmful = true }, -- Blood Corruption
    [449928] = { passive = true, book = false, harmful = false }, -- Blood Corrupting
    [449931] = { passive = true, book = false, harmful = false }, -- Fiery Strength
    [449932] = { passive = false, book = false, harmful = false }, -- Fiery Strength
    [449934] = { passive = false, book = false, harmful = false }, -- The Furious Storm
    [449935] = { passive = true, book = false, harmful = false }, -- The Furious Storm
    [449980] = { passive = true, book = false, harmful = false }, -- Libram of Holy Alacrity
    [449982] = { passive = false, book = false, harmful = false }, -- Libram of Holy Alacrity
    [450012] = { passive = true, book = false, harmful = false }, -- Shadow Spark
    [450013] = { passive = false, book = false, harmful = false }, -- Shadow Spark
    [450083] = { passive = true, book = false, harmful = false }, -- Rapid Cutting
    [450084] = { passive = false, book = false, harmful = false }, -- Rapid Cutting
    [450108] = { passive = false, book = false, harmful = false }, -- Mind Vision
    [450625] = { passive = true, book = false, harmful = false }, -- Item - Crusader's Wrath Proc - Lightforge Armor
    [450626] = { passive = true, book = false, harmful = false }, -- Item - The Furious Storm Proc
    [450667] = { passive = false, book = false, harmful = false }, -- Stealth
    [453165] = { passive = false, book = false, harmful = false }, -- Sniper Training
    [456496] = { passive = false, book = false, harmful = true }, -- Judgement of the Crusader
    [456549] = { passive = false, book = false, harmful = false }, -- Melting Faces
    [457325] = { passive = true, book = false, harmful = false }, -- S03 - Item - T1 - Priest - Shadow 6P Bonus
    [457520] = { passive = true, book = false, harmful = false }, -- S03 - Item - T1 - Shaman - Elemental 4P Bonus
    [457553] = { passive = true, book = false, harmful = false }, -- S03 - Item - T1 - Warlock - Damage 6P Bonus
    [457642] = { passive = true, book = false, harmful = false }, -- S03 - Item - T1 - Warlock - Tank 6P Bonus
    [457643] = { passive = false, book = false, harmful = false }, -- Soul Fire!
    [458112] = { passive = true, book = false, harmful = false }, -- Crusader
    [458285] = { passive = false, book = false, harmful = false }, -- Consecration
    [458287] = { passive = true, book = false, harmful = false }, -- Hallowed Ground
    [458393] = { passive = true, book = false, harmful = false }, -- Cobra Slayer
    [458856] = { passive = false, book = true, harmful = false }, -- Divine Light
    [458857] = { passive = false, book = false, harmful = false }, -- Divine Light
    [458860] = { passive = true, book = false, harmful = false }, -- Divine Light
    [459703] = { passive = false, book = false, harmful = false }, -- Feedback
    [459709] = { passive = false, book = false, harmful = false }, -- Shadowguard
    [459714] = { passive = false, book = false, harmful = false }, -- Touch of Weakness
    [460084] = { passive = false, book = false, harmful = true }, -- Spectral Shout
    [460086] = { passive = false, book = false, harmful = true }, -- Spectral Shout
    [460906] = { passive = true, book = false, harmful = false }, -- Demonic Frenzy
    [460907] = { passive = false, book = false, harmful = false }, -- Demonic Frenzy
    [461152] = { passive = false, book = false, harmful = false }, -- Flame Wrath
    [461154] = { passive = true, book = false, harmful = false }, -- Flame Wrath
    [461252] = { passive = false, book = false, harmful = false }, -- Shadowflame Fury
    [461253] = { passive = true, book = false, harmful = false }, -- Shadowflame Fury
    [461290] = { passive = false, book = false, harmful = false }, -- Libram of the Consecrated
    [461294] = { passive = true, book = false, harmful = false }, -- Libram of Holy Alacrity
    [461297] = { passive = false, book = false, harmful = false }, -- Totem of Raging Fire
    [461298] = { passive = true, book = false, harmful = false }, -- Totem of Raging Fire
    [461761] = { passive = false, book = false, harmful = false }, -- Destructor's Devastation
    [462160] = { passive = false, book = false, harmful = false }, -- Destructor's Devastation
    [462225] = { passive = false, book = false, harmful = false }, -- Destructor's Devastation
    [462226] = { passive = false, book = false, harmful = false }, -- Destructor's Devastation
    [462707] = { passive = false, book = false, harmful = false }, -- Cutthroat
    [462708] = { passive = true, book = false, harmful = false }, -- Cutthroat
    [462752] = { passive = false, book = false, harmful = false }, -- Main Gauche
    [462832] = { passive = false, book = false, harmful = false }, -- Shock and Awe
    [462834] = { passive = true, book = false, harmful = false }, -- Shock and Awe
    [462885] = { passive = true, book = false, harmful = false }, -- Enrage
    [463146] = { passive = true, book = false, harmful = false }, -- Libram of the Consecrated
    [465230] = { passive = false, book = false, harmful = true }, -- Entrapment
    [467088] = { passive = false, book = false, harmful = false }, -- Astral Power
    [467090] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2 - Druid - Balance 6P Bonus
    [467099] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2- Druid - Restoration 2P Bonus
    [467203] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2- Druid - Restoration 4P Bonus
    [467204] = { passive = false, book = false, harmful = false }, -- Healing Grace
    [467329] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2- Hunter - Melee 2P Bonus
    [467331] = { passive = false, book = false, harmful = false }, -- Clever Strikes
    [467409] = { passive = false, book = false, harmful = false }, -- Missile Barrage
    [467446] = { passive = false, book = false, harmful = false }, -- Arcane Infused
    [467708] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2 - Rogue - Damage 2P Bonus
    [467735] = { passive = false, book = false, harmful = false }, -- Clearcasting
    [467818] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2 - Shaman - Elemental 2P Bonus
    [467889] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2 - Shaman - Tank 2P Bonus
    [467891] = { passive = false, book = false, harmful = false }, -- Shield Block
    [467983] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2 - Warlock - Damage 4P Bonus
    [468046] = { passive = true, book = false, harmful = false }, -- S03 - Item - T2 - Warlock - Tank 4P Bonus
    [468048] = { passive = false, book = false, harmful = false }, -- S03 - Item - T2 - Warlock - Tank 4P Bonus
    [468453] = { passive = true, book = false, harmful = false }, -- S03 - Item - ZG - Warrior - Gladiator 5P Bonus
    [468455] = { passive = false, book = false, harmful = false }, -- S03 - Item - ZG - Warrior - Gladiator 5P Bonus
    [468526] = { passive = false, book = false, harmful = false }, -- Power Surge
    [468540] = { passive = false, book = false, harmful = false }, -- Massive Destruction
    [468543] = { passive = false, book = false, harmful = false }, -- Demonic Destruction
    [468689] = { passive = false, book = false, harmful = false }, -- Lock and Load
    [468766] = { passive = false, book = true, harmful = false }, -- Conjure Water
    [469057] = { passive = false, book = false, harmful = true }, -- Earth Volley
    [469144] = { passive = false, book = false, harmful = false }, -- Quick Strikes
    [469145] = { passive = false, book = true, harmful = false }, -- Aspect of the Falcon
    [469211] = { passive = true, book = false, harmful = false }, -- Scythe of Chaos
    [469220] = { passive = false, book = false, harmful = false }, -- Scythe of Chaos
    [469227] = { passive = false, book = false, harmful = true }, -- Felhunted
    [469228] = { passive = false, book = false, harmful = true }, -- Felhunted
    [469357] = { passive = false, book = false, harmful = false }, -- Immolation Aura
    [469433] = { passive = false, book = false, harmful = true }, -- Poison Bolt
    [470240] = { passive = true, book = false, harmful = false }, -- Totem of Conductive Currents
    [470246] = { passive = true, book = false, harmful = false }, -- Libram of Wrath
    [470271] = { passive = false, book = false, harmful = false }, -- Libram of Wrath
    [470272] = { passive = false, book = false, harmful = false }, -- Totem of Conductive Currents
    [1213188] = { passive = true, book = false, harmful = false }, -- S03 - Item - TAQ - Druid - Guardian 2P Bonus
    [1213190] = { passive = false, book = false, harmful = false }, -- Animal Fury
    [1213406] = { passive = true, book = false, harmful = false }, -- S03 - Item - TAQ - Paladin - Retribution 4P Bonus
    [1213463] = { passive = false, book = false, harmful = true }, -- Charge
    [1213465] = { passive = false, book = false, harmful = true }, -- Intimidating Shout
    [1213930] = { passive = true, book = false, harmful = false }, -- S03 - Item - TAQ - Shaman - Tank 2P Bonus
    [1213934] = { passive = false, book = false, harmful = false }, -- Stormbraced
    [1214087] = { passive = true, book = false, harmful = false }, -- S03 - Item - TAQ - Warlock - Damage 4P Bonus
    [1214088] = { passive = false, book = false, harmful = false }, -- Infernalist
    [1214151] = { passive = true, book = false, harmful = false }, -- S03 - Item - RAQ - Warlock - Tank 3P Bonus
    [1214156] = { passive = false, book = false, harmful = false }, -- Spreading Pain
    [1217927] = { passive = false, book = false, harmful = false }, -- Excommunication
    [1218154] = { passive = false, book = false, harmful = false }, -- Strikes of the Sinister
    [1218178] = { passive = false, book = false, harmful = false }, -- Kill Shot
    [1218478] = { passive = true, book = false, harmful = false }, -- S03 - Item - Naxxramas - Druid - Feral 6P Bonus
    [1218479] = { passive = false, book = false, harmful = false }, -- Undead Slaying
    [1218575] = { passive = true, book = false, harmful = false }, -- S03 - Item - Naxxramas - Hunter - Ranged 6P Bonus
    [1218587] = { passive = false, book = false, harmful = false }, -- Undead Slaying
    [1218589] = { passive = true, book = false, harmful = false }, -- S03 - Item - Naxxramas - Hunter - Melee 6P Bonus
    [1219101] = { passive = false, book = false, harmful = false }, -- Scythe of Chaos
    [1219232] = { passive = false, book = false, harmful = false }, -- Mind's Eye
    [1219233] = { passive = true, book = false, harmful = false }, -- S03 - Item - Naxxramas - Priest - Healer 4P Bonus
    [1219235] = { passive = false, book = false, harmful = false }, -- Overcharged
    [1219373] = { passive = true, book = false, harmful = false }, -- S03 - Item - Naxxramas - Shaman - Enhancement 2P Bonus
    [1219485] = { passive = false, book = false, harmful = false }, -- Undead Slaying
    [1219486] = { passive = true, book = false, harmful = false }, -- S03 - Item - Naxxramas - Warrior - Damage 6P Bonus
    [1221404] = { passive = false, book = true, harmful = true }, -- Enchanted Flare
    [1221416] = { passive = false, book = false, harmful = false }, -- Enchanted Flare
    [1221421] = { passive = false, book = false, harmful = false }, -- Mind Vision
    [1221422] = { passive = false, book = false, harmful = false }, -- Mind Vision
    [1222988] = { passive = true, book = false, harmful = false }, -- Earthbound
    [1223031] = { passive = true, book = false, harmful = false }, -- Improved Stormstrike
    [1223987] = { passive = true, book = false, harmful = false }, -- Rapid Recuperation
    [1224716] = { passive = true, book = true, harmful = false }, -- Puncturing Wounds
    [1225228] = { passive = false, book = true, harmful = true }, -- Bane of Havoc
    [1226121] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Druid - Guardian 2P Bonus
    [1226126] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Druid - Guardian 6P Bonus
    [1226127] = { passive = false, book = false, harmful = false }, -- Savage Flurry
    [1226136] = { passive = false, book = false, harmful = false }, -- Wicked Shot
    [1226137] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Hunter - Ranged 4P Bonus
    [1226138] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Hunter - Ranged 6P Bonus
    [1226357] = { passive = false, book = false, harmful = false }, -- Wicked Fast
    [1226359] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Hunter - Melee 4P Bonus
    [1226460] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Paladin - Retribution 2P Bonus
    [1226461] = { passive = false, book = false, harmful = false }, -- Holy Power
    [1226466] = { passive = false, book = false, harmful = false }, -- Righteous Shield
    [1226467] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Paladin - Protection 2P Bonus
    [1226739] = { passive = false, book = false, harmful = false }, -- Undead Slaying
    [1226977] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Shaman - Elemental 4P Bonus
    [1226981] = { passive = true, book = false, harmful = false }, -- Grimoire of Synergy
    [1227196] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Warlock - Damage 6P Bonus
    [1227200] = { passive = false, book = false, harmful = false }, -- Wickedness
    [1227245] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Warrior - Protection 6P Bonus
    [1231124] = { passive = false, book = false, harmful = false }, -- Righteous Strength
    [1231126] = { passive = true, book = false, harmful = false }, -- Grand Crusader
    [1231380] = { passive = false, book = false, harmful = false }, -- Feral Dedication
    [1231381] = { passive = false, book = false, harmful = false }, -- Feral Dedication
    [1231382] = { passive = true, book = false, harmful = false }, -- Feral Dedication
    [1231601] = { passive = false, book = false, harmful = false }, -- Strand of Fate
    [1231604] = { passive = false, book = false, harmful = false }, -- Strand of Fate
    [1232169] = { passive = false, book = false, harmful = false }, -- Righteous Inquisition
    [1232170] = { passive = true, book = false, harmful = false }, -- Grand Inquisitor
    [1232890] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1232959] = { passive = false, book = false, harmful = false }, -- Strand of Fate
    [1232969] = { passive = false, book = false, harmful = false }, -- Strand of Fate
    [1232976] = { passive = false, book = false, harmful = false }, -- Strand of Fate
    [1233451] = { passive = false, book = false, harmful = false }, -- Trick Shots
    [1233835] = { passive = false, book = false, harmful = false }, -- Thunder and Lava
    [1234067] = { passive = false, book = false, harmful = false }, -- Gladiator's Cunning
    [1234540] = { passive = false, book = false, harmful = false }, -- Ignite
    [1234545] = { passive = false, book = false, harmful = false }, -- Immolation Aura
    [1235330] = { passive = false, book = false, harmful = false }, -- Crimson Crusade
    [1235336] = { passive = false, book = false, harmful = false }, -- Crimson Crusade
    [1235337] = { passive = false, book = false, harmful = false }, -- Crimson Crusade
    [1235341] = { passive = false, book = false, harmful = false }, -- Crimson Crusade
    [1235344] = { passive = false, book = false, harmful = false }, -- Crimson Crusade
    [1235349] = { passive = false, book = false, harmful = false }, -- Crimson Crusade
    [1235353] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1235355] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1235357] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1235359] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1235361] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1235390] = { passive = false, book = false, harmful = false }, -- Mercy by Fire
    [1235473] = { passive = false, book = false, harmful = false }, -- Restoration
    [1235681] = { passive = false, book = false, harmful = false }, -- Feral Dedication
    [1235826] = { passive = false, book = true, harmful = true }, -- Lacerate
    [1235827] = { passive = false, book = true, harmful = true }, -- Lacerate
    [1237312] = { passive = false, book = true, harmful = true }, -- Frostfire Bolt
    [1237313] = { passive = false, book = true, harmful = true }, -- Frostfire Bolt
    [1237317] = { passive = false, book = false, harmful = false }, -- Twisting Nether
    [1237948] = { passive = false, book = true, harmful = false }, -- Revive
    [1237949] = { passive = false, book = true, harmful = false }, -- Revive
    [1237950] = { passive = false, book = true, harmful = false }, -- Revive
    [1237951] = { passive = false, book = true, harmful = false }, -- Revive
    [1238069] = { passive = false, book = true, harmful = true }, -- Primal Bite
    [1238070] = { passive = false, book = true, harmful = true }, -- Primal Bite
    [1238073] = { passive = false, book = false, harmful = true }, -- Primal Bite
    [1238122] = { passive = false, book = true, harmful = true }, -- Feral Charge
    [1238149] = { passive = false, book = false, harmful = false }, -- S03 - Item - Naxxramas - Shaman - Enhancement 2P Bonus
    [1238214] = { passive = false, book = true, harmful = false }, -- Wild Growth
    [1238215] = { passive = false, book = true, harmful = false }, -- Wild Growth
    [1238289] = { passive = false, book = false, harmful = true }, -- Earthbound
    [1238299] = { passive = false, book = false, harmful = true }, -- Lava Burst
    [1238300] = { passive = false, book = false, harmful = true }, -- Lava Burst
    [1238640] = { passive = false, book = false, harmful = false }, -- Ghost Wolf
    [1238931] = { passive = false, book = false, harmful = false }, -- Improved Stormstrike
    [1239242] = { passive = false, book = true, harmful = false }, -- Riptide
    [1239243] = { passive = false, book = true, harmful = false }, -- Riptide
    [1239570] = { passive = false, book = true, harmful = false }, -- Holy Shield
    [1239696] = { passive = false, book = true, harmful = true }, -- Arcane Blast
    [1239697] = { passive = false, book = true, harmful = true }, -- Arcane Blast
    [1239699] = { passive = false, book = true, harmful = true }, -- Arcane Blast
    [1239700] = { passive = false, book = true, harmful = true }, -- Arcane Blast
    [1239832] = { passive = false, book = false, harmful = false }, -- Impact
    [1240044] = { passive = false, book = true, harmful = true }, -- Ice Lance
    [1240045] = { passive = false, book = true, harmful = true }, -- Ice Lance
    [1240046] = { passive = false, book = true, harmful = true }, -- Ice Lance
    [1240047] = { passive = false, book = true, harmful = true }, -- Ice Lance
    [1240193] = { passive = false, book = true, harmful = true }, -- Slam
    [1240287] = { passive = false, book = false, harmful = true }, -- Charge
    [1240288] = { passive = false, book = false, harmful = true }, -- Charge
    [1240289] = { passive = false, book = false, harmful = true }, -- Charge
    [1240571] = { passive = true, book = false, harmful = false }, -- S03 - Item - Scarlet Enclave - Paladin - Shockadin 2P Bonus
    [1240720] = { passive = false, book = true, harmful = false }, -- Penance
    [1240721] = { passive = false, book = true, harmful = false }, -- Penance
    [1240723] = { passive = false, book = true, harmful = false }, -- Penance
    [1240724] = { passive = false, book = true, harmful = false }, -- Penance
    [1240727] = { passive = false, book = true, harmful = false }, -- Penance
    [1240730] = { passive = false, book = true, harmful = false }, -- Penance
    [1240826] = { passive = false, book = true, harmful = false }, -- Prayer of Mending
    [1240827] = { passive = false, book = true, harmful = false }, -- Prayer of Mending
    [1240848] = { passive = false, book = false, harmful = false }, -- Prayer of Mending
    [1240849] = { passive = false, book = false, harmful = false }, -- Prayer of Mending
    [1241582] = { passive = false, book = true, harmful = true }, -- Mutilate
    [1241584] = { passive = false, book = true, harmful = true }, -- Mutilate
    [1241585] = { passive = false, book = true, harmful = true }, -- Mutilate
    [1241586] = { passive = false, book = true, harmful = true }, -- Mutilate
    [1241588] = { passive = false, book = true, harmful = true }, -- Mutilate
    [1241590] = { passive = false, book = true, harmful = true }, -- Mutilate
    [1241810] = { passive = false, book = false, harmful = false }, -- Cutthroat
    [1242512] = { passive = false, book = false, harmful = false }, -- Rapid Recuperation
    [1242634] = { passive = false, book = true, harmful = true }, -- Counterattack
    [1242688] = { passive = false, book = false, harmful = false }, -- Resourcefulness
    [1242853] = { passive = false, book = false, harmful = false }, -- Soul Harvest
    [1248996] = { passive = true, book = false, harmful = false }, -- Improved Wrath
    [1256867] = { passive = false, book = false, harmful = false }, -- Stealth
    [1259416] = { passive = false, book = true, harmful = false }, -- Walk on Air
    [1259686] = { passive = false, book = true, harmful = false }, -- Skysight
    [1259688] = { passive = false, book = false, harmful = false }, -- Elemental Blessing
    [1259691] = { passive = false, book = false, harmful = false }, -- Attuned
    [1259705] = { passive = false, book = true, harmful = false }, -- Read Leyline
    [1259718] = { passive = false, book = true, harmful = false }, -- Will to Survive
    [1259799] = { passive = false, book = true, harmful = false }, -- Elune's Light
    [1259812] = { passive = false, book = true, harmful = false }, -- Eureka!
    [1259813] = { passive = false, book = true, harmful = false }, -- Eureka!
    [1259817] = { passive = false, book = true, harmful = false }, -- Eureka!
    [1259821] = { passive = false, book = true, harmful = false }, -- Eureka!
    [1259823] = { passive = false, book = true, harmful = false }, -- Eureka!
    [1259918] = { passive = true, book = true, harmful = false }, -- Plainsrunning
    [1260270] = { passive = false, book = true, harmful = false }, -- Rapid Regeneration
    [1264455] = { passive = false, book = true, harmful = true }, -- Thunderstomp
    [1264478] = { passive = false, book = true, harmful = true }, -- Sonic Blast
    [1264479] = { passive = false, book = true, harmful = true }, -- Sonic Blast
    [1264480] = { passive = false, book = true, harmful = true }, -- Sonic Blast
    [1264481] = { passive = false, book = true, harmful = true }, -- Sonic Blast
    [1264482] = { passive = false, book = true, harmful = true }, -- Sonic Blast
    [1264494] = { passive = false, book = true, harmful = true }, -- Swipe
    [1264497] = { passive = false, book = true, harmful = true }, -- Swipe
    [1264498] = { passive = false, book = true, harmful = true }, -- Swipe
    [1264501] = { passive = false, book = true, harmful = true }, -- Swipe
    [1264502] = { passive = false, book = true, harmful = true }, -- Swipe
    [1264530] = { passive = false, book = false, harmful = false }, -- Apparition
    [1264735] = { passive = false, book = true, harmful = true }, -- Pinch
    [1264736] = { passive = false, book = true, harmful = true }, -- Pinch
    [1264739] = { passive = false, book = true, harmful = true }, -- Pinch
    [1264741] = { passive = false, book = true, harmful = true }, -- Pinch
    [1264742] = { passive = false, book = true, harmful = true }, -- Pinch
    [1264758] = { passive = false, book = true, harmful = true }, -- Dismember
    [1264927] = { passive = false, book = true, harmful = true }, -- Dismember
    [1264929] = { passive = false, book = true, harmful = true }, -- Dismember
    [1264930] = { passive = false, book = true, harmful = true }, -- Dismember
    [1264933] = { passive = false, book = true, harmful = true }, -- Dismember
    [1265038] = { passive = false, book = true, harmful = true }, -- Tendon Rip
    [1265039] = { passive = false, book = true, harmful = true }, -- Tendon Rip
    [1265040] = { passive = false, book = true, harmful = true }, -- Tendon Rip
    [1265041] = { passive = false, book = true, harmful = true }, -- Tendon Rip
    [1265042] = { passive = false, book = true, harmful = true }, -- Tendon Rip
    [1265054] = { passive = false, book = true, harmful = true }, -- Mine!
    [1265055] = { passive = false, book = true, harmful = true }, -- Mine!
    [1265056] = { passive = false, book = true, harmful = true }, -- Mine!
    [1265057] = { passive = false, book = true, harmful = true }, -- Mine!
    [1265058] = { passive = false, book = true, harmful = true }, -- Mine!
    [1265065] = { passive = false, book = true, harmful = true }, -- Savage Rend
    [1265066] = { passive = false, book = true, harmful = true }, -- Savage Rend
    [1265067] = { passive = false, book = true, harmful = true }, -- Savage Rend
    [1265068] = { passive = false, book = true, harmful = true }, -- Savage Rend
    [1265069] = { passive = false, book = true, harmful = true }, -- Savage Rend
    [1265843] = { passive = false, book = true, harmful = true }, -- Web
    [1265878] = { passive = false, book = true, harmful = true }, -- Web
    [1265880] = { passive = false, book = true, harmful = true }, -- Web
    [1265881] = { passive = false, book = true, harmful = true }, -- Web
    [1265883] = { passive = false, book = true, harmful = true }, -- Web
    [1265899] = { passive = false, book = true, harmful = true }, -- Dust Cloud
    [1265901] = { passive = false, book = true, harmful = true }, -- Dust Cloud
    [1265902] = { passive = false, book = true, harmful = true }, -- Dust Cloud
    [1265903] = { passive = false, book = true, harmful = true }, -- Dust Cloud
    [1265904] = { passive = false, book = true, harmful = true }, -- Dust Cloud
    [1266050] = { passive = false, book = false, harmful = false }, -- Apparition
    [1269135] = { passive = false, book = false, harmful = false }, -- Apparition
    [1270811] = { passive = false, book = false, harmful = true }, -- Intimidating Shout
    [1270842] = { passive = false, book = false, harmful = false }, -- Energized
    [1270893] = { passive = false, book = false, harmful = false }, -- Charged
    [1277324] = { passive = false, book = true, harmful = false }, -- Dark Sacrifice
    [1277325] = { passive = false, book = true, harmful = false }, -- Dark Sacrifice
    [1277326] = { passive = false, book = true, harmful = false }, -- Dark Sacrifice
    [1277327] = { passive = false, book = true, harmful = false }, -- Dark Sacrifice
    [1277328] = { passive = false, book = true, harmful = false }, -- Dark Sacrifice
    [1277331] = { passive = false, book = true, harmful = true }, -- Chastise
    [1277332] = { passive = false, book = true, harmful = true }, -- Chastise
    [1277333] = { passive = false, book = true, harmful = true }, -- Chastise
    [1277334] = { passive = false, book = true, harmful = true }, -- Chastise
    [1277335] = { passive = false, book = true, harmful = true }, -- Chastise
    [1277370] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277371] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277372] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277374] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277376] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277377] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277378] = { passive = false, book = true, harmful = false }, -- Divine Grace
    [1277455] = { passive = false, book = true, harmful = true }, -- Confounding Flash
    [1277456] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277457] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277458] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277459] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277460] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277462] = { passive = false, book = true, harmful = false }, -- Contingency Plan
    [1277463] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277464] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277465] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277466] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277467] = { passive = false, book = false, harmful = false }, -- Contingency Plan
    [1277634] = { passive = false, book = true, harmful = false }, -- Contingency Plan
    [1277638] = { passive = false, book = true, harmful = false }, -- Contingency Plan
    [1277639] = { passive = false, book = true, harmful = false }, -- Contingency Plan
    [1277640] = { passive = false, book = true, harmful = false }, -- Contingency Plan
    [1280345] = { passive = false, book = false, harmful = true }, -- Consecration
    [1280346] = { passive = false, book = false, harmful = true }, -- Consecration
    [1280347] = { passive = false, book = false, harmful = true }, -- Consecration
    [1280348] = { passive = false, book = false, harmful = true }, -- Consecration
    [1280349] = { passive = false, book = false, harmful = true }, -- Consecration
    [1280353] = { passive = false, book = false, harmful = true }, -- Consecration
    [1282733] = { passive = false, book = false, harmful = true }, -- Overpower
    [1284536] = { passive = false, book = false, harmful = false }, -- Holy Purpose
    [1285372] = { passive = false, book = false, harmful = false }, -- Vanish
    [1287162] = { passive = false, book = false, harmful = false }, -- Stealth
    [1288559] = { passive = false, book = false, harmful = true }, -- Bloom
    [1289238] = { passive = false, book = false, harmful = false }, -- Tiger's Fury
    [1289681] = { passive = false, book = false, harmful = true }, -- Bloodthrill
    [1289682] = { passive = true, book = false, harmful = false }, -- Bloodthrill
    [1289849] = { passive = true, book = false, harmful = false }, -- Main Gauche
    [1290041] = { passive = false, book = false, harmful = false }, -- Bloom
    [1290708] = { passive = false, book = false, harmful = false }, -- Stealth
    [1291075] = { passive = true, book = false, harmful = false }, -- Swiftmend Cooldown Reduction
    [1293241] = { passive = false, book = true, harmful = true }, -- Summon Hawk
    [1293525] = { passive = false, book = true, harmful = true }, -- Summon Hawk
    [1293526] = { passive = false, book = true, harmful = true }, -- Summon Hawk
    [1293527] = { passive = false, book = true, harmful = true }, -- Summon Hawk
    [1293695] = { passive = true, book = false, harmful = false }, -- Demonic Brand
    [1293696] = { passive = false, book = false, harmful = true }, -- Demonic Brand
    [1293803] = { passive = false, book = false, harmful = false }, -- Pyroclasm
    [1293812] = { passive = false, book = true, harmful = true }, -- Incinerate
    [1293813] = { passive = false, book = true, harmful = true }, -- Incinerate
    [1293816] = { passive = false, book = false, harmful = false }, -- Shadow
    [1293817] = { passive = false, book = true, harmful = true }, -- Conflagrate
    [1293818] = { passive = false, book = true, harmful = true }, -- Conflagrate
    [1297659] = { passive = false, book = true, harmful = false }, -- Teleport: Dalaran
    [1299026] = { passive = false, book = true, harmful = false }, -- Shatter Curse
    [1299332] = { passive = false, book = true, harmful = true }, -- Lacerate
    [1299346] = { passive = false, book = true, harmful = false }, -- Trueshot Aura
    [1299348] = { passive = false, book = true, harmful = false }, -- Trueshot Aura
    [1299445] = { passive = false, book = true, harmful = false }, -- Aspect of the Beast
    [1299446] = { passive = false, book = true, harmful = false }, -- Aspect of the Beast
    [1299447] = { passive = false, book = true, harmful = false }, -- Aspect of the Beast
    [1299448] = { passive = false, book = false, harmful = false }, -- Quick Strikes
    [1300176] = { passive = false, book = false, harmful = false }, -- Arcane Blast
    [1300177] = { passive = false, book = false, harmful = false }, -- Arcane Blast
    [1302363] = { passive = false, book = false, harmful = false }, -- Pimgib's Collar
    [1306459] = { passive = false, book = false, harmful = false }, -- Thick Hide
    [1306488] = { passive = true, book = false, harmful = false }, -- Swiftmend Cooldown Reduction
    [1309595] = { passive = false, book = true, harmful = true }, -- Shadow Word: Death
    [1309633] = { passive = false, book = true, harmful = true }, -- Shadow Word: Death
    [1309635] = { passive = false, book = true, harmful = true }, -- Shadow Word: Death
    [1309636] = { passive = false, book = true, harmful = true }, -- Shadow Word: Death
    [1310077] = { passive = false, book = false, harmful = false }, -- Holy Power
    [1310185] = { passive = true, book = true, harmful = false }, -- Tactical Mastery
    [1310222] = { passive = false, book = true, harmful = true }, -- Spearing Strike
    [1310532] = { passive = true, book = false, harmful = false }, -- Expose Prey
    [1310533] = { passive = true, book = false, harmful = false }, -- Lacerating Strikes
    [1310536] = { passive = false, book = false, harmful = true }, -- Lacerating Strikes
    [1310684] = { passive = false, book = false, harmful = false }, -- Lone Wolf
    [1310687] = { passive = false, book = true, harmful = true }, -- Sniper Shot
    [1310703] = { passive = false, book = false, harmful = false }, -- Venom
    [1310711] = { passive = true, book = true, harmful = false }, -- Flawless Execution
    [1310721] = { passive = true, book = false, harmful = false }, -- Thousand Cuts
    [1310723] = { passive = false, book = false, harmful = false }, -- Thousand Cuts
    [1310726] = { passive = false, book = false, harmful = false }, -- Expose Prey
    [1310735] = { passive = true, book = true, harmful = false }, -- Unsealed Wrath
    [1310785] = { passive = false, book = true, harmful = true }, -- Sniper Shot
    [1310786] = { passive = false, book = true, harmful = true }, -- Sniper Shot
    [1310897] = { passive = false, book = true, harmful = false }, -- Voice of Truth
    [1310909] = { passive = false, book = false, harmful = false }, -- Light's Vigil
    [1310910] = { passive = false, book = false, harmful = true }, -- Light's Vigil
    [1310911] = { passive = false, book = true, harmful = false }, -- Light's Vigil
    [1310994] = { passive = false, book = true, harmful = true }, -- Swift Judgement
    [1311015] = { passive = false, book = true, harmful = false }, -- Templar's Bulwark
    [1311033] = { passive = false, book = false, harmful = false }, -- Iron Creed
    [1311074] = { passive = true, book = true, harmful = false }, -- Sanctified Judgement
    [1311590] = { passive = false, book = true, harmful = false }, -- Light's Vigil
    [1311593] = { passive = false, book = false, harmful = false }, -- Light's Vigil
    [1311594] = { passive = false, book = false, harmful = true }, -- Light's Vigil
    [1311595] = { passive = false, book = true, harmful = false }, -- Light's Vigil
    [1311597] = { passive = false, book = false, harmful = false }, -- Light's Vigil
    [1311599] = { passive = false, book = false, harmful = true }, -- Light's Vigil
    [1311606] = { passive = false, book = true, harmful = false }, -- Holy Shock
    [1311649] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [1311656] = { passive = false, book = true, harmful = false }, -- Seal of Fury
    [1311676] = { passive = false, book = true, harmful = true }, -- Curse of the Elements
    [1311677] = { passive = false, book = true, harmful = true }, -- Curse of the Elements
    [1311680] = { passive = false, book = true, harmful = true }, -- Curse of the Elements
    [1311701] = { passive = false, book = false, harmful = false }, -- Echo of Fury
    [1311703] = { passive = false, book = false, harmful = false }, -- Echo of Command
    [1311704] = { passive = false, book = false, harmful = false }, -- Echo of Righteousness
    [1311705] = { passive = false, book = false, harmful = false }, -- Echo of Justice
    [1312002] = { passive = false, book = true, harmful = true }, -- Ice Lance
    [1312152] = { passive = false, book = false, harmful = false }, -- Tiger's Fury
    [1313342] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [1313343] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [1313344] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [1313345] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [1313346] = { passive = false, book = true, harmful = false }, -- Flash of Light
    [1313348] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1313349] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1313350] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1313351] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1313352] = { passive = false, book = true, harmful = false }, -- Holy Light
    [1316697] = { passive = false, book = true, harmful = true }, -- Wrack
    [1316709] = { passive = false, book = true, harmful = true }, -- Death Mark
    [1316991] = { passive = false, book = true, harmful = false }, -- Penance
    [1316993] = { passive = false, book = true, harmful = false }, -- Penance
    [1316995] = { passive = false, book = true, harmful = false }, -- Penance
    [1317006] = { passive = true, book = true, harmful = false }, -- Litany of Light
    [1317257] = { passive = false, book = true, harmful = true }, -- Strider Kick
    [1318151] = { passive = false, book = false, harmful = false }, -- Stealth
    [1318827] = { passive = false, book = false, harmful = false }, -- Mana Gems
    [1319289] = { passive = false, book = false, harmful = false }, -- Druid Forms
    [1319507] = { passive = false, book = false, harmful = false }, -- Stances
    [1319652] = { passive = false, book = false, harmful = false }, -- Curses
    [1320379] = { passive = false, book = false, harmful = false }, -- Polymorph
    [1322574] = { passive = true, book = true, harmful = false }, -- Rule of Rage (DND)
    [1322605] = { passive = false, book = true, harmful = false }, -- Shifting Power
    [1323522] = { passive = false, book = false, harmful = false }, -- Seals
    [1323965] = { passive = false, book = false, harmful = false }, -- Lingering Rage
    [1323966] = { passive = false, book = false, harmful = false }, -- Lingering Rage
    [1323967] = { passive = true, book = false, harmful = false }, -- Gore Drinker
    [1323969] = { passive = false, book = false, harmful = false }, -- Gore Drinker
    [1324056] = { passive = false, book = false, harmful = false }, -- Aspects
    [1324187] = { passive = false, book = false, harmful = false }, -- Polymorph
    [1324188] = { passive = false, book = false, harmful = false }, -- Polymorph
    [1324189] = { passive = false, book = false, harmful = false }, -- Polymorph
    [1324401] = { passive = false, book = false, harmful = false }, -- Counterspell - Silenced
    [1324415] = { passive = false, book = false, harmful = false }, -- Shackle Undead
    [1324420] = { passive = false, book = false, harmful = false }, -- Shackle Undead
    [1324422] = { passive = false, book = false, harmful = false }, -- Shackle Undead
    [1324427] = { passive = false, book = false, harmful = false }, -- Silence
    [1324448] = { passive = false, book = false, harmful = false }, -- Fear
    [1324451] = { passive = false, book = false, harmful = false }, -- Fear
    [1324453] = { passive = false, book = false, harmful = false }, -- Fear
    [1324459] = { passive = false, book = false, harmful = false }, -- Death Coil
    [1324462] = { passive = false, book = false, harmful = false }, -- Banish
    [1324463] = { passive = false, book = false, harmful = false }, -- Banish
    [1324468] = { passive = false, book = false, harmful = false }, -- Subjugate Demon
    [1324473] = { passive = false, book = false, harmful = false }, -- Bane of Havoc
    [1324474] = { passive = false, book = false, harmful = false }, -- Kidney Shot
    [1324475] = { passive = false, book = false, harmful = false }, -- Kidney Shot
    [1324477] = { passive = false, book = false, harmful = false }, -- Blind
    [1324481] = { passive = false, book = false, harmful = false }, -- Gouge
    [1324482] = { passive = false, book = false, harmful = false }, -- Sap
    [1324483] = { passive = false, book = false, harmful = false }, -- Sap
    [1324484] = { passive = false, book = false, harmful = false }, -- Sap
    [1324485] = { passive = false, book = false, harmful = false }, -- Silenced - Kick
    [1324487] = { passive = false, book = false, harmful = false }, -- Bash
    [1324488] = { passive = false, book = false, harmful = false }, -- Bash
    [1324490] = { passive = false, book = false, harmful = false }, -- Bash
    [1324494] = { passive = false, book = false, harmful = false }, -- Intimidation
    [1324499] = { passive = false, book = false, harmful = false }, -- Scatter Shot
    [1324500] = { passive = false, book = false, harmful = false }, -- Freezing Trap
    [1324501] = { passive = false, book = false, harmful = false }, -- Freezing Trap
    [1324502] = { passive = false, book = false, harmful = false }, -- Freezing Trap
    [1324506] = { passive = false, book = false, harmful = false }, -- Scare Beast
    [1324507] = { passive = false, book = false, harmful = false }, -- Scare Beast
    [1324510] = { passive = false, book = false, harmful = false }, -- Scare Beast
    [1324511] = { passive = false, book = false, harmful = false }, -- Improved Concussive Shot
    [1324513] = { passive = false, book = false, harmful = false }, -- Hammer of Justice
    [1324515] = { passive = false, book = false, harmful = false }, -- Hammer of Justice
    [1324516] = { passive = false, book = false, harmful = false }, -- Hammer of Justice
    [1324517] = { passive = false, book = false, harmful = false }, -- Hammer of Justice
    [1324538] = { passive = false, book = false, harmful = false }, -- Repentance
    [1324543] = { passive = false, book = false, harmful = false }, -- Turn Undead
    [1324545] = { passive = false, book = false, harmful = false }, -- Turn Undead
    [1324546] = { passive = false, book = false, harmful = false }, -- Turn Undead
    [1324551] = { passive = false, book = false, harmful = false }, -- Silenced
    [1324556] = { passive = false, book = false, harmful = false }, -- Concussion Blow
    [1324558] = { passive = false, book = false, harmful = false }, -- Disarm
    [1325256] = { passive = false, book = true, harmful = false }, -- Mana Tide Totem
    [1325257] = { passive = true, book = false, harmful = false }, -- Mana Tide
    [1325756] = { passive = false, book = true, harmful = true }, -- Death Mark
    [1325757] = { passive = false, book = true, harmful = true }, -- Death Mark
    [1325758] = { passive = false, book = true, harmful = true }, -- Death Mark
    [1326053] = { passive = false, book = false, harmful = true }, -- Frost Blast
    [1326054] = { passive = false, book = false, harmful = true }, -- Frost Blast
    [1326055] = { passive = false, book = false, harmful = true }, -- Frost Blast
    [1326057] = { passive = false, book = false, harmful = false }, -- Healthstone
    [1326079] = { passive = false, book = true, harmful = true }, -- Arcane Wrath
    [1326080] = { passive = false, book = true, harmful = true }, -- Arcane Wrath
    [1326081] = { passive = false, book = true, harmful = true }, -- Arcane Wrath
    [1326082] = { passive = false, book = true, harmful = true }, -- Arcane Wrath
    [1326083] = { passive = false, book = false, harmful = false }, -- Missile Barrage
    [1326084] = { passive = false, book = false, harmful = false }, -- Reckoning
    [1326159] = { passive = true, book = false, harmful = false }, -- Dark Inspiration
    [1326168] = { passive = false, book = false, harmful = false }, -- Dark Inspiration
    [1326175] = { passive = false, book = false, harmful = false }, -- Stealth
    [1328198] = { passive = false, book = false, harmful = false }, -- Echo of Light
    [1328206] = { passive = false, book = false, harmful = false }, -- Echo of Wisdom
    [1328544] = { passive = true, book = false, harmful = false }, -- Shieldsworn
    [1328548] = { passive = false, book = true, harmful = false }, -- Oath of Light
    [1328551] = { passive = false, book = false, harmful = false }, -- Shieldsworn
    [1328616] = { passive = false, book = true, harmful = true }, -- Lacerate
    [1328617] = { passive = false, book = true, harmful = true }, -- Lacerate
    [1328618] = { passive = false, book = true, harmful = true }, -- Ferocious Bite
    [1328621] = { passive = true, book = false, harmful = false }, -- Bloom
    [1328825] = { passive = true, book = true, harmful = false }, -- Poised
    [1328826] = { passive = false, book = false, harmful = false }, -- Poised
    [1328827] = { passive = false, book = false, harmful = false }, -- Poised
    [1329283] = { passive = false, book = true, harmful = true }, -- Shank
    [1329326] = { passive = false, book = false, harmful = false }, -- Ghostly Strike
    [1329328] = { passive = true, book = true, harmful = false }, -- Venom
    [1329549] = { passive = false, book = true, harmful = true }, -- Shank
    [1329553] = { passive = false, book = false, harmful = false }, -- Counterspell - Silenced
    [1329555] = { passive = false, book = true, harmful = false }, -- Reckless Swings
    [1330741] = { passive = false, book = false, harmful = false }, -- Poised
    [1330746] = { passive = false, book = false, harmful = false }, -- Poised
    [1330763] = { passive = false, book = false, harmful = false }, -- Poised
    [1330765] = { passive = false, book = false, harmful = false }, -- Poised
}
