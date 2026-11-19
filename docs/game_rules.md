# Current game rules

## Objective and results

Blue and Red each have one 800-HP Core Tower and two 500-HP Guard Towers, one in
each lane. Each side starts with 1800 combined structure HP. Blue occupies the
lower half; Red the upper half. Guards do not make the core invulnerable.

Destroy the enemy core to win. Damage from one numeric tick applies together;
if both cores fall in that tick the result is a draw. At the 180-second timeout:

1. Compare remaining structure HP divided by that side's initial structure HP.
2. If equal, compare actual structure damage dealt.
3. If still equal, draw.

Only actual HP removed from structures counts as structure damage. Unit damage,
overkill, and repeated attacks on ruins cannot inflate the tie-break. Negative
and non-finite damage cannot heal a structure. Destroyed structures stay as
ruins; restart restores the original state.

## Energy and deployment slots

Each commander starts with 10 energy, regenerates 1/s, and is capped at 10.
Blue deploys at time zero. Red acts at 0.75 s, Blue at 1.50 s, and so on.
Movement, combat, regeneration, and cooldowns continue between deployment slots.
Pause freezes all of these numeric systems.

Each slot permits one card/lane action or Wait. Wait spends nothing and consumes
the slot. Each side has the same fixed five-card deck; there is no shuffle or
draw mechanic. Card cooldowns are separate per team and shared between that
card's two lane choices. Units spawn at fixed positions. Each team may have at
most eight active units. Units can share a navigation cell.

## Cards

| Card | Cost | Cooldown | HP | Damage | Attack interval | Movement |
| --- | --- | --- | --- | --- | --- | --- |
| Fighter | 3 | 4 s | 120 | 20 | 0.75 s | 90 px/s, range 28 |
| Ranger | 4 | 5 s | 90 | 15 | 0.9 s | 70 px/s, range 130 |
| Tank | 5 | 8 s | 240 | 18 | 1.0 s | 45 px/s, range 28 |
| Mage | 6 | 9 s | - | 80 | Instant | Enemy units in one lane |
| Arrow | 3 | 4 s | - | 45 | Instant | Enemy units in one lane |

Mage and Arrow are instant lane spells in this implementation. They damage each
enemy unit in the chosen lane, never friendly units or structures. Casting in a
lane without an enemy unit is illegal and spends nothing. All definitions live
in `scripts/combat/card_data.gd`; the UI reads the same costs and cooldowns.

## Automatic movement and fighting

Units follow their lane's cached manual A* route through its bridge, avoiding
static blocked cells. They attack the nearest eligible enemy in range and move
toward their chosen enemy when out of range. Target ties use stable creation
order. Enemy units behind the attacker are considered only if already in range.
The lane's enemy guard and the shared enemy core are eligible structure targets.

Guards attack an enemy unit in their own lane for 25 damage every second within
170 route pixels. Cores attack one enemy unit from either lane for 30 damage
every second within 190 route pixels. Combat distance is measured along the
cached lane route. There is no random damage, physical crowd collision, healing,
or moving-obstacle pathfinding.

The numeric model advances in 0.05-second ticks. A spell applies at the slot;
ordinary unit and structure attacks apply during ticks. Dead units are removed
and stop participating in subsequent ticks. A terminal state stops further
ticks and deployments.

## Human and AI modes

AI vs AI runs the selected search for each commander. Defaults are Blue
alpha-beta at depth 2 and Red MCTS at 20 trials with a six-ply horizon. Plain
Minimax remains selectable. Search completion, root scoring, and the actual
executed action are traceable through F2/F7.

Human vs AI assigns Blue to the player. Select a ready card with 1-5 or a click,
then choose A/Left or D/Right. The action queues for the next Blue slot; a newer
choice replaces it. W queues Wait. With no input, Blue waits. Cooldowns,
affordability, target presence, pause, and unit cap are validated again at the
slot. An unavailable action cannot spend energy.

R restarts the battle, clearing units, queues, jobs, cooldowns, damage totals,
and the result. F3 debug damage routes through the real manager. F4 is a labeled
art/UI preview whose card clicks cannot queue real actions.
