# Current rules: Phase 1

## Goal and arena

Blue and Red each own one Core Tower and two Guard Towers, one guard in each
lane. Blue occupies the lower half of the arena and Red the upper half.
The two lanes and river crossings are visual landmarks in this stage.
Destroy the enemy Core Tower to win immediately; guard destruction alone
does not end a match. Guards do not shield the core in the current rules.

## Structures and health

| Structure | Count per side | Starting HP per tower |
| --- | --- | --- |
| Guard Tower | 2 | 500 |
| Core Tower | 1 | 800 |

Each side begins with 1800 combined structure HP. Definitions live in
`data/structures/guard_tower.tres` and `data/structures/core_tower.tres`.
Damage cannot take HP below zero. Negative and non-finite damage is ignored.
Overkill contributes only the HP actually lost to the damage total.
Destroyed towers remain visible as ruins, reject further damage, and cannot
heal. Restart explicitly resets all towers; it is not an in-match healing mechanic.
No towers attack yet; attacks belong to Phase 2.

## Match timer and results

The match lasts 180 seconds of unpaused gameplay, configured in
`data/balance/game_balance.tres`. Core destruction ends the match immediately
and stops the timer. When the timer reaches zero:

1. Calculate each side's remaining structure HP divided by that side's
   combined structure HP at match start. Destroyed structures still count
   toward the starting denominator and contribute zero remaining HP.
2. The higher percentage wins.
3. If the percentages are equal, the side that dealt more total structure
   damage wins. Unit damage will not count toward this tie-break.
4. If damage totals are also equal, declare a draw.

With identical starting totals and no healing, equal remaining HP currently
also implies equal damage dealt. The separate damage tie-break is nevertheless
implemented and tested as specified for future rules or asymmetric settings.
Only actual structure damage is counted. Phase 1's debug damage is attributed
to the opposing commander.

Pause stops the timer and blocks debug damage. Terminal matches accept no
more manager damage requests. Restart restores HP, the full timer, empty damage
totals, an undecided result, and the unpaused state.

## Phase 1 interaction

The HUD shows remaining time, all six HP values, team HP percentages, pause,
and results. F3 toggles optional per-tower damage buttons. Each click removes
100 HP by default, using the configurable debug damage amount. R restarts;
Space pauses/resumes. With no debug damage, an idle match ends in a draw.

## Planned rules, not implemented in this stage

AI-vs-AI will be the main mode, with alternating deployment decisions over
continuous live movement/combat. Energy is planned to start at 5, regenerate
at 1 per second, and be clamped between 0 and 10.

| Planned unit | Energy cost | HP | Damage | Attack interval |
| --- | --- | --- | --- | --- |
| Tank | 5 | 240 | 18 | 1.0 s |
| Fighter | 3 | 120 | 20 | 0.75 s |
| Ranger | 4 | 90 | 15 | 0.9 s |

Units, energy, deployment, movement, targeting, attacks, and death are Phase 2
work. These are design values only; no unused unit resources or gameplay code
are created in Phase 1. Manual A* navigation is Phase 3, and planner state,
actions, and simulation start in Phase 4.
