# Aegis Arena

A Godot 4.x / GDScript university project for a two-player tactical card battle.
The current implementation is **Phase 1 only**: the arena, six structures, HP,
the match timer, victory rules, and a basic HUD with optional damage controls.

## Run

1. Install the standard desktop version of [Godot 4.x](https://godotengine.org/download/).
2. In Godot's Project Manager, choose **Import**, select `project.godot`, then **Edit**.
3. Press **F6** with `scenes/main/Main.tscn` open, or **F5** to run the project.

The project renders a 1920 x 1080 canvas in a default 1280 x 720 desktop window,
using the Compatibility renderer. All visuals are Godot placeholder shapes and
the built-in font. No external packages or assets are required.

From a terminal with the Godot executable on PATH:

```powershell
godot --path . --editor
godot --path .
```

Replace `godot` with your actual Godot executable path if necessary.
The pre-existing empty `main.py` is unrelated to this Godot project.

## Controls and checks

| Control | Action |
| --- | --- |
| Space / Pause button | Pause or resume the current match |
| R / result panel button | Restart with full HP and 180 seconds |
| F3 / Damage controls button | Show or hide six debug damage buttons |
| A tower's damage button | Remove 100 HP from that tower |

Damage controls are hidden initially and disabled during pause or after a match.
They exist to verify Phase 1 rules before units/combat are implemented. Damage
is credited to the opposing team and overkill is excluded from the total.

- Destroy either core with eight debug hits: the opposing side wins immediately.
- Damage one guard, then let the timer expire: the side with more remaining
  combined structure HP percentage wins.
- Restart and leave all structures untouched: timeout produces a draw.
- Pause: the countdown and debug damage stop. Restart also clears pause.

## Automated checks

Run the import step once so Godot registers the script classes, then run the
dependency-free test script:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_phase_one.gd
godot --headless --path . --quit-after 120
```

The test runner returns a nonzero exit code for failed checks. It verifies the
actual Main scene and manager, HP clamping, overkill, destruction, both core
victories, pause/resume, reset, timeout, the percentage/damage/draw ordering,
and HUD result visibility. The last command is a short runtime smoke check.

Verified during implementation with **Godot 4.7.2 stable**: headless editor
import completed without parser errors, **49 checks passed**, and the Main
scene ran for 120 frames without script/runtime errors. Other Godot 4.x versions
have not been tested. The portable verification runtime is in the system's
temporary directory, not bundled with the project.

The arena, expanded debug controls, and victory panel were also rendered with
the Compatibility renderer and visually inspected. The core-damage HUD button
signal was exercised through to the victory panel. Physical mouse/keyboard
input has not been manually exercised. Local preview images and verification
logs are in the ignored `.godot/` cache, not required game assets.

## Project layout

- `scenes/`: Main, arena, reusable tower scenes, HUD, and match result panel.
- `scripts/core/`: match orchestration, pure victory rules, constants, and settings.
- `scripts/combat/`: live structure HP and shared structure definitions.
- `scripts/arena/`, `scripts/ui/`: shape drawing and interface presentation.
- `data/`: editable balance and tower resources, shared by every tower instance.
- `tests/`: Phase 1 checks; no external test framework.
- `docs/`: [rules](docs/game_rules.md) and [architecture](docs/architecture.md).
- Reserved directories use `.gitkeep` files to preserve the planned structure.
  They contain no placeholder algorithm implementations.

## Scope and next phase

This foundation has no units, attacks, energy, deployment, AI planning,
pathfinding, fuzzy logic, Minimax, MCTS, or experiment logging. Without debug
damage, both sides remain idle and draw after 180 seconds.

Phase 2 adds shared unit data, energy, the three units, manual spawning,
movement, deterministic targeting, attacks, damage, and death. A* follows in
Phase 3; data-only search states and the forward model follow in Phase 4.
