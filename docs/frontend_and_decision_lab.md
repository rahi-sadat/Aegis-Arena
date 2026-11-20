# Frontend and live decision lab

This update changes presentation and scene navigation. Combat, card values,
fuzzy rules, evaluation, Minimax, alpha-beta, MCTS and scheduling keep their
existing implementations. The frontend only reads their data.

## Loading and navigation

The app starts with a small loading screen. `ResourceLoader` loads destination
scenes in the background and supplies the displayed percentage. Cached scenes
can reach 100% immediately; a brief transition lets the screen render without
inventing intermediate percentages. Loading failures offer Retry.

The home page has Play, a guide, settings and Exit. Setup places the mode, two
independent commander panels and the shared deck together. Enter Battle uses
the same loading overlay. The existing 1920x1080 logical canvas preserves the
16:9 aspect ratio at smaller resolutions.

## Demonstrate a real search

1. Choose AI vs AI, Minimax or alpha-beta for Blue, and MCTS for Red.
2. Enter Battle. Press **F2** or click **Live Tree** in AI Insight.
3. Choose Blue or Red. Snapshot time, legal actions, node counts and decision
   IDs update automatically. Repeated choices and Wait-only roots are genuine
   when the same move is best or nothing else is legal.
4. Choose **Full recorded tree** or a root branch to expand. Use the scrollbars,
   minus, plus and Fit to inspect it.
5. Click a node or **Hold View** to keep its exact snapshot while the match
   continues. **Resume Live** catches up. The history dropdown holds any of the
   last twelve completed decisions for the selected commander.
6. Press **F7** to export the real decision dictionaries, selected snapshot and
   A* evidence. Unfinished exports are labelled incomplete and have no chosen move.

The lab remains accessible above the result screen after a match. Escape closes
the lab without changing pause; Space uses the existing match pause control.
Card deployment keys are captured while the lab is open to avoid accidental moves.

The old viewer refreshed only when opened and preferred an older branching
decision. The new viewer subscribes to completed decisions and polls existing
in-progress telemetry while visible. It never reruns an agent to draw a tree.

**Searching** means the agent is working; missing scores say evaluating.
**Prepared** is a completed search for the scheduler's next deployment snapshot.
**Executed** is a committed decision with an execution ID. **Held Snapshot** is
deliberately pinned. Its clock can differ from the current battlefield clock.

Minimax shows real scores and MAX/MIN roles. Alpha-beta exposes alpha/beta
changes and cutoff bounds; pruned children have no invented evaluation. MCTS
shows actual visits, total root reward and mean reward. Details explain UCT from
the recorded counts, sampled selection steps, rollout actions, reward and backup.

The existing MCTS agent records the first and last three trial logs and saves its
full tree on completion. During search, the frontend reconstructs only nodes
present in those sampled logs and labels them **partial sampled MCTS telemetry**.
Intermediate trial logs are not fabricated. The completed view uses the actual
full tree. Very fast searches can finish between display frames.

## Explain fuzzy calculation

Open **Fuzzy Calculation** or click **Fuzzy Math** in AI Insight.
**Source: Decision** shows the exact saved assessment used by the search:

- Threat: enemy HP inside our half / 400, clamped to 0..1.
- Opportunity: largest missing HP fraction among living enemy structures.
- Energy reserve: our energy / 10.

Each input has low/medium/high curves, an input marker, firing degrees, rule
constants and substituted weighted-average arithmetic. Attack uses opportunity;
defend uses threat; save uses energy with reversed output constants.

```text
T = 100
U = 20 + 10 × defend
E = 2 + 4 × save
P = 10 + 10 × attack
score = T × tower difference + U × unit HP difference
      + E × energy difference + P × lane pressure difference
```

**Source: Live Field** reads current battlefield values instead. Its source and
clock are labelled separately because the agent can use a predicted deployment
snapshot. Display rounding does not change the values retained in JSON.

## Rendering and verification

Static composited menu backgrounds replace per-frame full-screen movement.
Loading is asynchronous. Hidden decision panels do no polling. Node styles are
cached; unchanged sprite frames, health bars, shadows and cooldown rings avoid
repeated redraw work. Paused battles skip cosmetic updates. Simulation time and
search budgets remain unchanged.

`tests/test_decision_lab.gd` verifies live updates, held snapshots, catch-up,
actual parent edges, leaf/UCT/fuzzy arithmetic, model/trace isolation, restart,
all three agents, and threaded boot/home/setup navigation. Run:

```powershell
./tests/run_checks.ps1 -GodotPath 'C:/path/to/Godot_win64_console.exe' -Rendered
```

Rendered evidence lives in `output/evidence/decision_lab/`: loading, home, setup,
live trees, expanded branches, MCTS statistics, fuzzy calculations and a 1280x720
capture. Runtime evidence and caches stay local and are excluded from Git.
