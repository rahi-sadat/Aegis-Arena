# Implementation walkthrough and verification

**19 November 2026.** The game now runs real card deployment, energy/cooldowns,
three unit types, two lane spells, automatic combat, manual A*, fuzzy assessment,
Minimax, alpha-beta, and MCTS. Both AI vs AI and Human vs AI are connected to the
actual battle. The original design report is a dated planning artifact; this
document describes the implemented version.

## Read the code in this order

1. `scripts/combat/card_data.gd`: the five cards' shared numeric values.
2. `scripts/state/game_state.gd`: one small data class and deep copying.
3. `scripts/core/battle_rules.gd`: legal actions, one action, and one combat tick.
4. `scripts/ai/search_helpers.gd`: `player`, `actions`, `result`, `terminal`, `utility`.
5. `scripts/ai/fuzzy_logic.gd` and `evaluation.gd`: membership, rules, weights, score.
6. `scripts/ai/minimax.gd`: explicit MAX/MIN recursion following the supplied sample.
7. `scripts/ai/alpha_beta.gd`: the same search with bounds and cutoffs.
8. `scripts/ai/mcts.gd`: a small node and the four MCTS stages.
9. `scripts/movement/astar.gd` and `arena_grid.gd`: manual routes and cached distances.
10. `scripts/ai/ai_manager.gd`: scheduling, human queue, prediction checks, execution.

The remaining code is presentation, trace export, and tests. There is no Python
bridge, learned model, transposition table, or external AI package.

## One decision from start to finish

`GameManager` owns a numeric `GameState`. It contains HP, unit lane/distance,
energy, cooldowns, actor, time, and result. Visible objects display these numbers.

`result(state, action)` makes a deep copy, applies one legal action, advances
fifteen 0.05-second ticks, and switches the actor. This is one search-tree edge.
Depth 2 means our action and the opponent's reply, covering 1.50 seconds.

The live game calls the same `advance_tick()` function as the simulated copies.
The next commander searches a predicted snapshot while the live battle runs
toward that snapshot. At the next deployment slot the controller checks that the
prediction still matches and executes one legal action. The first move is
prepared before the clock starts. Excess startup-rendering time is excluded
from the first opponent planning window.

In Human vs AI, a card click followed by Left/Right queues the action. It does
not deploy immediately. The last queued choice is the one considered at the
next Blue slot; no input means Wait.

## Fuzzy scoring and its intentional limitation

The implemented controller is the small nine-rule zero-order Sugeno controller
from the plan. It uses threat, opportunity, and energy membership degrees to
compute independent attack/defend/save priorities. This first controller has
linear interpolation within its simple rule groups; it does not model
interactions between the inputs. That limitation is explicit rather than hidden.

For threat 0.65, opportunity 0.35, and reserve 0.30, the outputs are attack 0.35,
defend 0.65, and save 0.70. The resulting weights are T=100, U=26.5, E=4.8, P=13.5.

The score is the weighted sum of root-relative differences in remaining
structure HP fraction (T), surviving unit HP strength (U), energy (E), and
HP-weighted forward progress (P). Root win/loss/draw overrides the heuristic with
+10000/-10000/0. Red is MAX when Red starts the search.

F2 shows membership degrees, rule constants, output weights, and clickable leaf
contributions. F7 exports the full-precision snapshot so the calculation can be
replayed. Fuzzy scoring never changes the legal action list.

## A real nine-leaf scenario

`tests/test_search.gd` constructs an actual `GameState` with 3 energy on both
sides, Fighter ready, and Arrow cooling down for 10 seconds. Other cards are too
expensive. Each side therefore has Fighter Left, Fighter Right, and Wait.

Unlike the design report's synthetic feature table, these leaf values come from
calling the real forward model. At this root, threat and opportunity are zero,
so weights are T=100, U=20, E=4.8, P=10.

| Blue action | Red Fighter Left | Red Fighter Right | Red Wait | Red's minimum |
| --- | --- | --- | --- | --- |
| Fighter Left | 0.075335 | 0.101343 | 1.387455 | 0.075335 |
| Fighter Right | 0.072832 | 0.098840 | 1.384953 | 0.072832 |
| Wait | -1.312121 | -1.286113 | 0.000000 | -1.312121 |

Blue chooses **Fighter Left** because 0.075335 is the largest row minimum. In
the first leaf, T=0 and U=0, E is zero within floating-point roundoff, and
P=0.007533482. Its score is approximately `10 * 0.007533482 = 0.07533482`.
Blue's earlier deployment has had an extra movement interval. Scores are
heuristic points, not win percentages.

Plain Minimax visits 13 states and evaluates all nine leaves. Alpha-beta visits
9 states and evaluates five leaves in the same order. After evaluating Fighter
Left, alpha is 0.075335. Fighter Right's first reply is already 0.072832, so its
other two replies cannot improve Blue's choice. The Wait branch cuts off after
-1.312121. The skipped branches have no calculated score in the exported trace.

Both recursive agents agree with a separate direct two-loop exhaustive oracle.
The files `output/evidence/small_minimax.json` and `small_alpha_beta.json` are
generated by the test. The original paper example chooses Fighter Right with a
score of 7 because it supplies different synthetic leaf features; those numbers
are not substituted into this game.

## MCTS and a forced defense

The MCTS code keeps the sample's selection, expansion, simulation, and
backpropagation functions. All rewards stay in the root player's perspective:
win 1, loss 0, draw 0.5. At a rollout cutoff it uses
`clamp(0.5 + heuristic / 400, 0, 1)`.

At our nodes, UCT uses `Q + 1.41*sqrt(log(N)/n)`. At opponent nodes it uses
`(1-Q) + 1.41*sqrt(log(N)/n)`. Both select the maximum. An unvisited child has
infinite exploration priority. This corrects the supplied sample's problem of
minimizing the whole exploration bonus at an opponent turn. Backup adds the
same root-relative reward to every ancestor once.

The regression scenario puts an enemy Fighter with 40 HP in range of a 1-HP
friendly core. The friendly commander has 3 energy. Arrow Left kills that enemy
before the next combat tick; the other actions cannot stop the immediate
defeat. Minimax, alpha-beta, and seeded MCTS all choose Arrow Left for either
root color. A 100-trial trace is saved as
`output/evidence/mcts_forced_defense.json`.

The tree viewer shows visits and Q. Recorded early/late iterations also contain
actual UCT candidates, selection paths, expansion actions, rollout actions,
terminal/cutoff reward sources, and before/after backup values. The final action
uses the most visits, then higher root Q, then stable card/lane order.

## Routing

The manual A* open list is an ordinary array. It picks minimum `g+h`, then
smaller h, then insertion order. Neighbors are Right, Up, Left, Down, each with
cost 1; h is Manhattan distance. The test's blocked (1,0) cell forces the path
`(0,0), (0,1), (1,1), (2,1), (2,0)` with cost 4.

Arena routes are cached because obstacles and spawn positions stay fixed.
Units follow those real routes; hypothetical search states use the same route
distances. G displays gold routes, red blocked cells, green examined cells, and
g/h/f at the bridges. F7 exports `astar_routes.json`, including blocked cells,
paths, costs, and every examined cell's numbers.

## Budgets changed after testing

The plan proposed starting with 100 MCTS trials and profiling before increasing
the budget. Profiling showed 100 six-ply trials could take about 0.58 seconds
with no initial units and about 2.2 seconds in one eight-unit fixture on this
machine. It did not fit the 0.75-second live slot reliably.

The live default is therefore **20 trials**, with a 10-30 range. Minimax and
alpha-beta default to **depth 2**, with a 1-2 live range. Larger values remain
available through the headless agent functions. This is a measured runtime
choice; the algorithms and shared rules remain the same.

Minimax/alpha-beta yield after roughly 12 ms of CPU work, and MCTS yields between
trials after roughly 25 ms of work. An unfinished/stale search executes a labeled
Wait. Its trace is
marked incomplete; it is never presented as a completed algorithm result.
Slow machines or deliberately higher budgets can still miss a slot. Use the
completed-budget and CPU/wall-time fields when comparing algorithms.

## Verification and evidence

Run `tests/run_checks.ps1` for the numeric/UI/integration/replay checks. Add
`-Rendered` to exercise the real renderer and mouse clicks, or `-PairedMatches`
for 20 paired 30-second games and two standard 180-second simulations. The
runner uses isolated workspace caches and rejects script errors, nonzero exit
codes, or missing completion summaries.

The verification covers:

- all five cards, costs/cooldowns, spell targeting, unit cap, movement, attacks,
  deaths, actual damage accounting, simultaneous core defeat, and timeout;
- deep-copy isolation and exact agreement between fifteen live ticks and a
  forward transition;
- fuzzy hand calculations, both root colors, exhaustive Minimax comparison,
  alpha-beta equivalence/pruning, bounded seeded MCTS, UCT and reward backup;
- alternating actual scene/controller decisions, prediction agreement, startup
  timing, pause, human queue, preview isolation, restart, cancellation, and results;
- a real graphics run, real mouse selection/lane clicks, screenshots, and JSON
  replay from the exact saved snapshot/seed.

| Check suite | Passing checks |
| --- | --- |
| Original match rules | 49 |
| Menu/HUD presentation | 81 |
| Numeric battle rules and A* | 45 |
| Fuzzy evaluation and search | 95 |
| Live scene/controller integration | 43 |
| Actual rendering and mouse input | 19 |
| Total | 332 |

JSON replay additionally reproduces the selected action and score for the
100-trial forced-defense trace and a 20-trial decision exported from the live
renderer. The rendered run reports zero missed slots at the default budgets.

The paired short suite used seeds 2026-2035, swapped algorithm colors for each
seed, alpha-beta depth 2, MCTS 20 trials, and a 30-second test limit. All 20 games
finished: MCTS won 17 and alpha-beta won 3. Combined structure damage was 1205.
These short matches are regression evidence, not the standard three-minute
format or proof that MCTS is generally superior.

Two additional full 180-second simulations, with colors swapped at seed 2026,
also completed. MCTS won both by timeout. Each deployed 84 units and removed
80 units; the games cast 25 and 26 spells and dealt 314 and 409 combined
structure damage. The one-seed sample and unequal search work limit any
algorithm-strength conclusion.

Generated CSV, JSON, and screenshots live in `output/evidence/`; they are
intentionally ignored by Git because running the game regenerates them. The
source tests remain in the repository. Detailed logs live in `build/verification/`.

## Demonstrating it in the lab

Start AI vs AI and observe units, energy, tower HP, and actual algorithm badges.
Open F2, select a recorded decision with multiple legal actions, and click a
leaf. Explain each feature contribution and the root's MAX/MIN reasoning.
Switch the history/team controls to show MCTS UCT, rollout, and backup values.
Use G for routing and F7 for exported evidence.

Restart in Human vs AI, click Fighter, then Left, and explain why it queues until
Blue's slot. Show pause/restart. Core-win behavior is covered by the tactical
tests and can also be demonstrated with F3 damage controls.

Before the final evaluation, record a sped-up gameplay clip and update the
slides and printed final report with the finished rules, screenshots, measured
tables, and exported real decision examples. The original planning PDF should
remain labeled as a design-stage guide.
