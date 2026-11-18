# Phase 1 architecture

## Screen flow and battle scene

`TitleScreen.tscn` is the startup scene. Play and Game Modes open
`PreBattleScreen.tscn`, which launches `Main.tscn` for the Phase 1 match.
The pause and result screens return to the title.

```text
Main (Node; scripts/core/main.gd)
|-- GameManager (Node)
|-- Arena (Node2D; Arena.tscn)
|-- Structures (Node2D)
|   |-- BlueLeftGuard  (GuardTower.tscn)
|   |-- BlueRightGuard (GuardTower.tscn)
|   |-- BlueCore       (CoreTower.tscn)
|   |-- RedLeftGuard   (GuardTower.tscn)
|   |-- RedRightGuard  (GuardTower.tscn)
|   `-- RedCore        (CoreTower.tscn)
`-- HUD (CanvasLayer; HUD.tscn)
    `-- Interface (Control)
        |-- BoardVignette and BattlePreview
        |-- BlueCommander, TimerFrame, RedCommander
        |-- Minimap and AIInsight
        |-- CommandStrip
        |   |-- Fighter, Ranger, Tank, Mage, Arrow
        |   `-- Energy
        |-- MatchControls, PreviewBadge, DebugDamage
        |-- PauseMenu
        |-- MatchResultPanel
        `-- SettingsPanel
```

Each reusable tower scene contains a `TowerArt` sprite and `Title` and `Health`
labels. It draws its HP bar and changes from the team tower sprite to a ruin
on destruction. `Main` runs after its children are ready,
wires HUD requests, gathers the six structures, and starts the match. Restart
reuses the existing scene instances and reconnects each signal once.

## Current script responsibilities

| Script | Responsibility |
| --- | --- |
| `core/main.gd` | Scene wiring, keyboard shortcuts, restart, routing debug requests |
| `core/game_manager.gd` | Timer, pause, match lifetime, damage attribution, result signals |
| `core/match_rules.gd` | Pure numeric percentage, damage tie-break, and draw calculation |
| `core/game_constants.gd` | Team/result identifiers, team names, team colors |
| `core/match_config.gd` | Battle-setup choices: mode, per-commander algorithm, depth/iterations |
| `core/game_balance.gd` | Resource schema for match duration and debug damage amount |
| `combat/structure_data.gd` | Resource schema for tower type, name, and starting HP |
| `combat/structure.gd` | Live HP, damage clamping, destruction, reset, tower presentation |
| `arena/arena.gd` | Painted arena and layers for banners and braziers |
| `ui/hud.gd` | Live HUD presentation and user-request signals |
| `ui/match_result_panel.gd` | Final result presentation and restart request |
| `ui/components/` | Commander panels, minimap, card slots, energy, insight, and overlays |
| `ui/title_screen.gd`, `ui/pre_battle_screen.gd` | Menus and scene navigation |
| `tests/test_phase_one.gd` | Headless integration and numeric victory-rule checks |
| `tests/test_presentation.gd` | Screen flow, live HUD, preview isolation, and optional render capture |

No global/autoload singleton is needed. Ordinary operations are local calls.
Structures emit `damaged` and `destroyed`; the manager observes these and emits
`structure_health_changed`, `timer_changed`, `pause_changed`, `match_started`,
and `match_ended`. The HUD observes those signals and emits pause, restart,
and damage requests. It cannot decide or change a winner itself.

The manager freezes its own clock rather than pausing the entire SceneTree,
so UI controls remain usable. Future live gameplay systems must honor the
manager's pause and terminal state. There are no live combat systems yet.

The minimap projects actual tower positions onto board geometry from
`ArenaLayout`. F4 in debug builds toggles presentation samples in `BattlePreview`,
the deck, energy, and AI Insight. Preview illustrations, projectile effects, and
sample values have no write path to the manager or the structures.

## Shared data

`data/balance/game_balance.tres` defines the 180-second match and debug damage.
`data/structures/*.tres` define 500-HP guards and 800-HP cores. These shared
definitions are read-only at runtime; per-instance current HP lives on each
structure. Changing a resource in the Inspector changes the next match's
settings without editing rule scripts. Team starting HP totals are recorded
when the match starts and remain the timeout denominator.

## Planned boundary: visible game and AI simulation

The current visible game uses Godot Nodes for structures, presentation, and
frame time. Later live units will also use Nodes. **Future search must not
operate on those Nodes.** A planner exploring a hypothetical attack must not
damage a visible tower, spawn visible units, mutate shared resources, or
advance the actual match clock.

Phase 4 will add data-only `GameState`, `UnitState`, `StructureState`,
`GameAction`, and a `StateBuilder` that snapshots live values. The later forward
model will copy these states and simulate numeric lane progress for one planner
interval using the same shared balance definitions as the visible game. It
will not instantiate scenes, animations, or projectiles. State-copy isolation
and forward-model behavior must be tested before search agents are introduced.

The planned responsibilities are distinct: fuzzy logic assesses the battle;
Minimax/MCTS select legal high-level deployments; alpha-beta reduces Minimax
search; manual A* navigates live units around the arena grid. Live A* routes
must not be computed for every search state. Planner scheduling must leave
movement and combat running between decisions.

## Reserved directories and development order

Future unit scenes/data, state, movement, AI subdirectories, debug tooling,
and assets are represented only by `.gitkeep` files. No empty algorithm scripts,
fake AI choices, or search stubs are present. `AIManager`, `Units`, AI status,
event-bus, and experiment logger nodes/scripts will be added when needed.

Next is Phase 2 (energy and manually triggered unit battles), then Phase 3
(grid and manual A*), Phase 4 (copyable state and simulation), Phase 5 (baseline
AI), Phase 6 (fuzzy assessment), Phase 7 (plain Minimax then alpha-beta),
Phase 8 (MCTS), Phase 9 (CSV logging), and Phase 10 (presentation/debug polish).
Advanced AI and experiment-design documents belong to those later stages.
