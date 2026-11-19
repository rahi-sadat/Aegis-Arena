# Aegis Arena: simple algorithm implementation plan

**Date:** 19 November 2026

**Baseline reviewed:** `311faeb` on `main`

**Status:** the first playable implementation is now present. Read
[the implementation walkthrough](docs/implementation.md) for current code and
verification. The sections below preserve the original approved plan at the
baseline commit. The live budgets were reduced after profiling to depth 2 and
20 MCTS trials; larger searches are supported by the headless APIs.

Read the [implementation report and viva guide](docs/algorithm_implementation_report.md) for formulas, pseudocode, worked trees, examples, and questions with answers. A printable copy is at [output/pdf/algorithm_implementation_report.pdf](output/pdf/algorithm_implementation_report.pdf).

## 1. What already exists

The current build has the two-lane arena, six structures, HP and damage tracking, a 180-second clock, pause/restart, victory rules, menus, and presentation tests. `MatchConfig` records mode, algorithm, depth, iterations, and the 0.75-second decision interval. It already defaults to Blue alpha-beta and Red MCTS.

Units, attacks, energy, cooldowns, live deployment, A*, fuzzy inference, a search simulator, and the three search agents do not yet exist. F4 displays isolated UI samples. Selecting an algorithm currently records a choice; it does not run a search.

No existing `plan.md` or `PLAN.md` was found in this checkout. This file supplies the requested plan. The proposal and sample programs are reference material; the user's request and pasted lab requirements define the task.

## 2. Keep the scope understandable

- Use GDScript inside the existing Godot project. Follow the Python samples' small named functions, loops, and explicit recursion. Do not add a Python server or engine bridge.
- Keep the existing two lanes and five displayed cards. First make Fighter work, then Ranger/Tank, then two simple lane spells: Mage and Arrow. Their precise proposed rules are in the report.
- Use fixed spawn points, a fixed five-card deck, one action per deployment turn, and `WAIT`. There is no deck shuffle or arbitrary placement coordinate.
- Make both algorithms receive the same state, legal moves, simulator, and evaluator. Keep plain Minimax separately selectable for comparison with alpha-beta.
- Use one `GameState` with numeric fields and arrays of simple dictionaries. One small MCTS node class is sufficient. Avoid a class for every state or action type.
- Start live Minimax at depth 2, MCTS at 100 iterations, and a six-ply rollout limit. Profile before enabling depth 3 and 300 iterations. These are starting settings, not measured performance claims.
- Limit active units to eight per side initially. Keep static obstacles and allow units to share a navigation cell. This keeps both routing and combat explainable.

## 3. Resolve the source differences explicitly

| Item | Evidence | Proposed implementation decision |
| --- | --- | --- |
| Starting energy | Proposal slide 3 says 10; `docs/game_rules.md` proposes 5 | Start at 10, cap at 10, regenerate 1/s, matching the proposal. Update the older rules when energy is implemented. |
| Card roster | Rules describe three future units; the proposal and `DeckArt` display five cards | Three unit types plus Mage/Arrow as simple lane spells. These spell mechanics are a proposal, not an existing rule. |
| Card costs/cooldowns | `DeckArt` already lists 3/4/5/6/3 energy and 4/5/8/9/4 seconds | Preserve these values, move numeric ownership to shared card data, and let the UI read it. |
| Human mode | Selector exists, controls are not live | Human queues one card and lane for the next Blue slot. No input means `WAIT`; combat keeps running. |
| Search budget | UI permits depths 1-6 and 100-2000 iterations | Initially expose only tested live limits; explain any disabled high values. Keep the selected value and actual completed search visible. |
| Fuzzy sample | Notebook uses Mamdani output sets and defuzzification | Use a small zero-order Sugeno controller with constant outputs and weighted averages. Clearly explain this modification. |

All new balance values in the report are proposed defaults. No source is silently treated as proof of implemented gameplay.

## 4. Workflow

```text
Live numeric battle state
    -> copy the state at the next deployment slot
    -> calculate fuzzy tactical weights
    -> generate affordable, ready, valid actions plus WAIT
    -> selected Minimax / alpha-beta / MCTS searches copied states
    -> return one action and its decision trace
    -> validate and execute that action once at its slot
    -> A* supplies a live unit route; spells apply numeric damage
    -> units move/fight, energy refills, cooldowns/time advance
    -> the opponent gets the next deployment slot
```

Search never changes visible towers or spawns visible units. A* does not run inside each hypothetical state. Live numeric combat and hypothetical combat call the same small tick functions.

## 5. Build in this order

| Step | Work and insertion point | Finish condition |
| --- | --- | --- |
| 1. One working card | Add shared card data, energy/cooldowns, Fighter deployment, numeric movement, attack/death, and tower attacks. Wire `core/main.gd`, `GameManager`, and HUD requests. | A human can deploy Fighter, damage towers, finish a match, pause, and restart correctly. |
| 2. Complete the small battle | Add Ranger, Tank, Mage, Arrow, fixed spawn locations, and unit cap. | All five cards obey costs, cooldowns, enemy-only targeting, and reset rules. |
| 3. A* | Add a four-neighbor grid and manual A*. Use `ArenaLayout` for world/grid mapping. Draw the actual route and examined cells in debug mode. | A unit routes through its bridge and around a blocked cell; no-path cases do not crash. |
| 4. Search state and forward model | Add data-only `GameState`, copying, common helper functions, fixed ticks, shared combat, and numeric lane distances. | `result()` advances a copy by 0.75 seconds without changing its parent or the visible match. Replaying the same action produces the same numeric outcome. |
| 5. Baseline and scheduling | Add a very small legal random/greedy baseline and alternating commander slots in `ai_manager.gd`. Read existing `MatchConfig`. | AI vs AI runs complete matches; Human vs AI consumes queued Blue input. Real-time combat continues between slots. |
| 6. Fuzzy scoring | Implement membership functions, nine explicit rules, weighted averages, and evaluator contributions. Connect live values to AI Insight. | The report's hand calculations match program output. Fuzzy output changes weights, never legality. |
| 7. Plain Minimax | Implement `max_value`, `min_value`, and root move choice, with depth and terminal checks. | Compare the actual nine-leaf forward-model scenario against an independent exhaustive oracle; both root colors work. The original synthetic paper tree remains a separate arithmetic example. |
| 8. Alpha-beta | Add alpha/beta updates to the same recursion and retain identical ordering/tie rules. | Completed searches return the same root value and chosen move as Minimax; the teaching trace correctly marks two skipped leaves. |
| 9. MCTS | Add the small node class, selection, one-child expansion, bounded rollout, backup, and most-visited final choice. | Unvisited children receive exploration priority at both players' nodes. Seeded runs reproduce traces and always return legal actions. |
| 10. Lab evidence | Add compact trace export, a small tree viewer, score breakdown, A* overlay, measurements, screenshots, and video capture. | A teacher can inspect a genuine decision and trace it from snapshot through search to execution. |

The temporary baseline is a diagnostic tool. It must never appear as a completed Minimax/MCTS decision in the UI.

## 6. File map

The report gives each file's functions and caller. Start with these small modules and add them only when their step begins:

```text
scripts/combat/card_data.gd          shared card definitions
scripts/core/battle_rules.gd        numeric apply_action() and advance_tick()
scripts/state/game_state.gd         numeric state and deep copy
scripts/ai/search_helpers.gd        player/actions/result/terminal/utility
scripts/ai/evaluation.gd            heuristic feature contributions
scripts/ai/fuzzy_logic.gd           membership, rules, weights
scripts/ai/minimax.gd               explicit MAX and MIN recursion
scripts/ai/alpha_beta.gd            same recursion with pruning
scripts/ai/mcts.gd                  node plus four MCTS stages
scripts/ai/ai_manager.gd            slots, selected agent, execution request
scripts/movement/arena_grid.gd      walkable cells and coordinate conversion
scripts/movement/astar.gd           manual route search
scripts/debug/decision_trace.gd     trace data and JSON/CSV export
scripts/ui/components/search_tree.gd small read-only debug tree
```

Use ordinary calls and existing signals. Do not add a global event bus, inheritance framework, learning system, transposition table, or multithreaded AI.

## 7. Evidence that must pass before presentation

- Existing Phase 1 and presentation tests still pass after each gameplay integration.
- One trace shows every legal root action, parent/child state isolation, score components, and selected action.
- The full small Minimax tree and alpha-beta tree agree on the choice. A cutoff is shown as a bound, not as an exact score of an unvisited branch.
- MCTS shows a selected path, one expansion, rollout actions, reward, backup updates, visit counts, and final selection. Randomness has its own recorded seed.
- Fuzzy inputs, membership degrees, fired rules, weighted outputs, and evaluation weights are visible.
- A* shows grid neighbors, `g`, `h`, `f`, blocked cells, and the returned path.
- At least ten paired initial seeds with colors swapped are a starting experiment. Record draws, actual search time, states/ticks, and outcome. This is descriptive classroom evidence, not proof that an algorithm is universally better.
- Slides contain actual screenshots and a sped-up gameplay recording. The printed final report includes actual measurements and traces after implementation.

## 8. What this planning deliverable does and does not establish

The accompanying report teaches the algorithms and proposes their exact workflow. Its small numeric examples are teaching fixtures, not captured gameplay or benchmark results. They must be supplemented with traces from the finished game for the final lab submission.

The next implementation step is **one working Fighter card with energy, movement, and combat**, followed by the shared search model. Implementing search before it can predict real actions would leave the selectors disconnected from gameplay.
