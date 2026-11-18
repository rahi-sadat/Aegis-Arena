# Aegis Arena

A Godot 4.x tactical card-battle university project. The current Phase 1 build
runs the two-lane arena, six towers, match clock, and victory rules with a fantasy
title screen, battle setup, and live HUD.

## Run

1. Install the standard desktop version of [Godot](https://godotengine.org/download/).
   This build is verified with Godot 4.7.2.
2. In Godot's Project Manager, import `project.godot` and open the project.
3. Press **F5**, pick **Play** or **Game Modes**, choose the battle mode and each
   commander's search algorithm, then press **Enter Battle**. Open `scenes/main/Main.tscn` and press **F6** to start
   the battle directly.

The game uses the Compatibility renderer with a 1920 × 1080 logical canvas and a
1280 × 720 default window. Ultrawide windows center the 16:9 play area with side
margins. The visual assets are bundled and there are no external packages. The
empty `main.py` is unrelated to the game.

## Battle controls

| Control | Action |
| --- | --- |
| Space or Esc / Pause | Pause or resume the match |
| R / Restart on the pause or result screen | Reset the match to full HP and 3:00 |
| F3 / F3 Debug | Toggle the six structure damage buttons |
| Damage button | Remove 100 HP from that tower while the match is active |
| F4 (debug builds) | Toggle sample AI, units, energy, and interactive card previews |
| Minus or plus on the minimap and AI Insight | Collapse or expand the panel |
| Settings | Set master volume, fullscreen, minimap visibility, and reduced motion |
| Return to Title or Return to Menu | Go back to the title screen |

The timer, six tower HP labels, team HP percentages, and results use the live
match. On a core defeat, the opposing team wins immediately. At timeout the match
checks remaining structure HP percentage, then structure damage dealt. Equal
scores produce a draw. See [the game rules](docs/game_rules.md).

Cards, energy, AI commanders, and speed adjustment appear as locked or planned
features in the live match. **UI Preview Mode** displays clearly labeled sample
values and effects. It leaves the actual match clock, HP, and outcomes intact.

## Checks

After importing the project, run:

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_phase_one.gd
godot --headless --path . --script res://tests/test_presentation.gd
godot --headless --path . --quit-after 120
godot --headless --path . --quit-after 120 res://scenes/main/Main.tscn
```

The Phase 1 script checks the current match rules, including pause, reset, core
wins, timeout, the damage tie-break, and draws. The presentation script exercises
the menus, all tower indicators, debug damage through the HUD, and preview
isolation. To save game-window PNGs, create an output directory and run without
headless mode:

```powershell
godot --path . --script res://tests/test_presentation.gd -- --capture "C:/path/to/output" 1920x1080
```

## Project layout

- `scenes/ui/screens/` contains the title and pre-battle screens.
- `scenes/main/` assembles the arena, game manager, six structures, and HUD.
- `scenes/ui/components/` contains reusable commander panels, cards, map, energy
  bar, AI Insight, pause, and settings.
- `scripts/core/` owns match orchestration and numeric rules.
- `scripts/combat/` owns structure state and health.
- `assets/arena/` and `assets/ui/` contain the generated artwork and shared theme.
  See [art and audio slots](assets/ASSET_REQUIREMENTS.md).
- `docs/` contains the rules and [architecture](docs/architecture.md).

Phase 2 adds actual energy, unit deployment, and combat. A* follows in Phase 3,
and the data-only search state and forward model follow in Phase 4. The pre-battle
screen already records the battle mode (AI vs AI or Human vs AI) and each
commander's algorithm — Minimax, Minimax + α–β, or MCTS — with its search depth
or iteration count in `MatchConfig` (`scripts/core/match_config.gd`). The HUD
shows these choices; the search agents will read them when they are implemented.
