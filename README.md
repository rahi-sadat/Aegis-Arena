# Aegis Arena

A Godot 4.x tactical card-battle university project with working human and AI
deployment, five cards, energy, combat, manual A* routing, fuzzy assessment,
Minimax, alpha-beta pruning, and MCTS. The live game and the planners use the same
small numeric battle rules.

## Run

1. Install the standard desktop version of [Godot](https://godotengine.org/download/).
   This build is verified with Godot 4.7.2.
2. Import `project.godot` and open the project.
3. Press **F5**, choose **Play**, select AI vs AI or Human vs AI, choose each
   commander's algorithm, and press **Enter Battle**. F6 on
   `scenes/main/Main.tscn` starts a battle directly.

The game uses the Compatibility renderer, a 1920 x 1080 logical canvas, and a
1280 x 720 default window. Ultrawide windows center the 16:9 play area. Artwork
is bundled. The empty `main.py` is unrelated to the game. Algorithms are readable
GDScript functions in `scripts/ai/`; there are no Python services or packages.

## Battle controls

| Control | Action |
| --- | --- |
| 1-5 or a card click | Select a ready card and pause the match for human planning |
| A / D, Left / Right buttons, or a lane click | Confirm the selected card, resume, and queue it for Blue's next slot |
| Tab / Pause & Plan | Enter or leave tactical planning without deploying |
| W / Wait | Queue Wait; the last queued choice replaces the earlier one |
| Space or Esc / Pause | Pause or resume the match |
| R / Restart | Reset the battle |
| F2 / Search Tree | Inspect recent genuine decisions, branches, and leaf calculations |
| F7 / Export | Save decision JSON, the selected historical decision, and A* traces |
| G / A* Routes | Show routes, blocked/explored cells, and bridge g/h/f values |
| F3 / F3 Debug | Toggle the six structure damage buttons |
| F4, debug builds | Toggle isolated sample art/card/AI previews |
| Minus or plus on minimap / AI Insight | Collapse or expand the panel |
| Settings | Master volume, fullscreen, minimap visibility, reduced motion |
| Return to Title | Leave the battle |

Destroy the enemy core to win immediately. At 180 seconds, compare remaining
structure HP percentage, then actual structure damage dealt, then declare a draw.
See [the current game rules](docs/game_rules.md).

Blue acts at time zero, then deployment slots alternate every 0.75 seconds while
units fight. Start with 10 energy, regenerate 1/s, and use fixed spawn points and
an eight-unit cap per team. Fighter, Ranger, and Tank deploy units; Mage and Arrow
damage enemy units in one lane. Empty-lane spells are unavailable. The deck stays
fixed. Human Blue queues a move between its slots; no input means Wait.

Human decisions have no wall-clock deadline while planning: selecting a ready
card freezes combat, the match timer, energy, and cooldowns. Choose a lane to
resume and queue the move. Tab, Space, or Esc also resumes without confirming a
new move. The original 0.75-second alternating simulation slots remain unchanged.

The battle HUD uses compact dark panels. Fighter, Ranger, and Tank have distinct
animated swordsman, archer, and stone-golem sprites with matching card portraits,
ground contact shadows, and frame-specific foot anchors. Sword swings, arrows,
golem impacts, tower shots, and both spells have visual feedback. Cooling cards
show a translucent circular progress ring and remaining seconds. These are
presentation changes; the numeric combat and search modules are unchanged.

Tested live defaults are depth 2 and 20 MCTS trials with a six-ply horizon. Live
controls permit depths 1-2 and 10-30 trials. Larger searches remain possible in
the headless agent APIs. A late search executes a clearly recorded Wait;
completed decisions never use a hidden substitute agent. The 1x speed control
remains locked. F4 still displays isolated, clearly labeled presentation samples.

## Checks

Run the reproducible suite in PowerShell, supplying your Godot executable if it
is not on PATH:

```powershell
./tests/run_checks.ps1 -GodotPath 'C:/path/to/Godot_win64_console.exe'
# Also open the real renderer, click human controls, and capture screenshots:
./tests/run_checks.ps1 -GodotPath 'C:/path/to/Godot_win64_console.exe' -Rendered
# Also run 20 paired short matches and two complete 180-second simulations:
./tests/run_checks.ps1 -GodotPath 'C:/path/to/Godot_win64_console.exe' -PairedMatches
```

The suite checks original match/UI behavior, combat, state isolation, the forward
model, fuzzy arithmetic, independent exhaustive Minimax results, alpha-beta
equivalence, seeded MCTS, scheduler timing, and JSON replay. `-Rendered` captures
the real game and tree overlays under `output/evidence/screenshots/`, plus
planning, distinct troop/attack, and 1280x720 captures under
`output/evidence/ui_refresh/`. The UI refresh checks verify frozen planning
state, mouse deployment, every animation's ground anchor, cooldowns, and that
effects cannot mutate the numeric state. Test logs
and isolated runtime data live in the ignored `build/` folder. For the original
menu/result screenshot suite, create an output directory and run:

```powershell
godot --headless --path . --editor --quit
godot --path . --script res://tests/test_presentation.gd -- --capture 'C:/path/to/output' 1920x1080
```

## Project layout and explanations

- `scenes/ui/screens/` contains the title and pre-battle screens.
- `scenes/main/` assembles the arena, manager, six structures, and HUD.
- `scripts/core/` owns battle lifetime and shared numeric tick rules.
- `scripts/combat/` contains card definitions and the live battle view.
- `scripts/state/` contains the deep-copyable numeric `GameState`.
- `scripts/ai/` contains fuzzy scoring, common search functions, and the agents.
- `scripts/movement/` contains the manual grid/A* implementation.
- `scripts/debug/` contains plain decision-trace dictionaries and export.
- `assets/` contains the artwork. See [art and audio slots](assets/ASSET_REQUIREMENTS.md).
  The new troop atlas layout and exact generation prompts are in
  [troop art notes](assets/units/ART_NOTES.md).
- `docs/` contains the [rules](docs/game_rules.md), [architecture](docs/architecture.md),
  and [implementation walkthrough](docs/implementation.md).

Read the implementation walkthrough for the current code, a real worked
scenario, verification results, and viva starting points. [PLAN.md](PLAN.md) and
the [original design report](docs/algorithm_implementation_report.md) preserve
the approved plan and synthetic teaching examples.

F7 exports under `output/evidence/` while running the project, or `user://evidence`
in an exported game. The decision viewer keeps twelve decisions per team and
defaults to a recent branching decision. Choose a historical decision, then a
branch; click a leaf to see its exact contributions. Its dropdown shows the
recorded clock so the snapshot is distinguishable from the current live state.

Replay a completed export with its saved seed and snapshot:

```powershell
godot --headless --path . --script res://tests/replay_decision.gd -- 'res://output/evidence/selected_decision.json'
```

To record gameplay for the lab, Godot's `--write-movie` option records the actual
game. Record at ordinary simulation speed and speed up the resulting clip in a
video editor; the in-game speed button intentionally stays at 1x.
