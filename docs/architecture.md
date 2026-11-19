# Architecture of the playable battle

## Scene and ownership

`TitleScreen.tscn` opens `PreBattleScreen.tscn`, then `Main.tscn`.
`scripts/core/main.gd` wires the existing arena, six tower Nodes, manager, and HUD
to a small `AIManager`, a `LiveBattleView`, and a read-only `SearchTreeView`.

```text
Main
  GameManager       authoritative numeric GameState and match lifetime
  Arena             static artwork
  Structures        six tower views; HP changes synchronize from GameState
  HUD               presentation, requests, overlays, tree viewer
  LiveBattle        draws actual units/attacks and optional A* overlays
  AIManager         alternating slots, copied roots, selected search, execution
```

The manager owns one numeric `GameState`. Structures and units in the search
state are dictionaries of numbers/identifiers, not Nodes. The tower Nodes keep
their original damage/destruction notifications for the HUD; synchronization is
guarded so it never counts numeric damage twice.

## One rules implementation for live play and prediction

`BattleRules.apply_action()` validates and applies one deployment or spell.
`BattleRules.advance_tick()` advances 0.05 seconds of energy, cooldowns, movement,
attacks, damage, deaths, and time. Damage from the tick's attacks is applied as a
batch, allowing simultaneous core destruction to draw. Both the live manager and
the planners call these functions.

`SearchHelpers.result()` deep-copies a state, applies a legal action, runs fifteen
ticks, and switches the actor. The original state, sibling branches, shared card
definitions, and visible game never change. A terminal result interrupts the
interval. `MatchRules` retains the original timeout calculation.

Each unit has a lane and numeric distance along that lane's static route.
`ArenaGrid` builds those routes with `ManualAStar` on a four-neighbor grid with
blocked river cells and tower footprints. Fixed spawn points and static obstacles
allow sharing these cached routes. Search reads distances and never reruns A*.
The view converts the same numeric distance to a world position. Small formation
offsets are visual only; units are not moving grid obstacles.

## Alternating deployment scheduler

The first Blue decision is prepared before the match clock starts. On completion,
one action executes at time zero. The manager discards excess startup-frame time
so initial rendering/shader work cannot consume Red's first planning window.

After a deployment, `AIManager` switches the next actor and predicts fifteen
ticks on a copy. It starts that actor's search while the live manager runs the
same fifteen ticks. At the next 0.75-second slot it checks snapshot agreement,
legality, and completion before executing exactly one action.

Minimax/alpha-beta yield to Godot when a chunk uses roughly 12 ms of CPU. MCTS
yields between trials after roughly 25 ms of work. No worker threads or global
event bus are used. Pausing
freezes numeric ticks and deployment slots; a search may finish its copied work
and wait. Restart/exit cancels outstanding work using a generation number and
the agent's cancellation flag. Debug damage invalidates and rebuilds the next
prediction. A late or stale result executes a labeled Wait, never a fake
completed search.

Human Blue queues one action for its next slot. The last queued action replaces
the previous choice. An empty queue produces Wait. The human uses the same
legality and execution functions as the agents.

## Search and assessment

`TacticalFuzzy` implements nine zero-order Sugeno rules. It freezes T/U/E/P
weights for one root search. `BattleEvaluation` scores feature differences from
that root team's perspective. Terminal results override the heuristic.

`MinimaxAgent` contains explicit MAX and MIN recursion. `AlphaBetaAgent` uses
the same actions, scoring, horizon, and tie rule with alpha/beta cutoffs.
`MCTSAgent` contains a small node and separate selection, expansion, simulation,
and backpropagation functions. Its rewards remain root-relative; opponent
selection uses `(1-Q)+exploration`.

The live defaults are depth 2 and 20 MCTS trials, with six total plies per trial.
The menu exposes depth 1-2 and 10-30 trials. The standalone agent APIs support
larger budgets for experiments. These limits came from profiling, not a change
to the definitions of the algorithms.

## UI and evidence

`HUD` reads live values and emits requests. AI-vs-AI cards are observational;
human cards unlock when ready. `AIInsightPanel` receives actual decision traces.
F4's `BattlePreview` remains isolated from deployment requests and numeric state.

`DecisionTrace` stores plain dictionaries. It records root snapshots, legal
actions, fuzzy calculations, tree nodes and bounds, completed budgets, CPU/wall
time, and execution status. MCTS also records early/late iterations including
UCT candidates, rollouts, rewards, and backup changes. JSON uses full float
precision so decisions can be replayed.

The controller retains twelve decisions per team. F2 freezes one recorded
decision in the viewer, defaults to a recent branching decision, and offers a
history/branch selector and clickable leaf calculations. The view displays two
plies; JSON includes every recorded node, up to an explicitly marked 500-node
limit. Unvisited pruned edges never receive invented scores.

F7 exports the latest team decisions, the currently selected historical
decision, and A* grid/path/examined-cell data. A compact CSV logs every executed
slot. Project runs write `output/evidence/`; exported games use
`user://evidence`. Generated evidence and runtime caches are ignored by Git.
