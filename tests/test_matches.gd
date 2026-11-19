extends SceneTree
## Reproducible paired regressions. Override --pairs, --duration, --iterations.
## Example: godot --headless --path . --script res://tests/test_matches.gd -- --pairs 10 --duration 30

var pairs: int = 10
var duration: float = 30.0
var iterations: int = 20
var failures: int = 0

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index in range(0, args.size() - 1, 2):
		match args[index]:
			"--pairs": pairs = args[index + 1].to_int()
			"--duration": duration = args[index + 1].to_float()
			"--iterations": iterations = args[index + 1].to_int()
	call_deferred("_run")

func _run() -> void:
	var folder: String = "res://output/evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var suffix: String = "full" if duration == 180.0 else "short"
	var file: FileAccess = FileAccess.open(folder.path_join("paired_" + suffix + "_matches.csv"), FileAccess.WRITE)
	file.store_csv_line(["seed", "blue", "red", "duration_limit", "elapsed", "winner", "reason", "blue_hp", "red_hp", "blue_structure_damage", "red_structure_damage", "deployments", "deaths", "spells", "plies", "alpha_beta_cpu_ms", "mcts_cpu_ms", "mcts_iterations"])
	var totals: Dictionary = {"alpha_beta_wins": 0, "mcts_wins": 0, "draws": 0, "games": 0, "structure_damage": 0.0}
	for seed_index in pairs:
		for swapped in 2:
			var state: GameState = GameState.create_default(duration)
			var alpha_team: int = swapped
			var deployments: int = 0
			var spells: int = 0
			var ply: int = 0
			var mcts_turn: int = 0
			var cpu: Array[float] = [0.0, 0.0]
			var max_plies: int = ceili(duration / MatchConfig.DECISION_INTERVAL_SECONDS) + 1
			while not SearchHelpers.terminal(state) and ply < max_plies:
				var team: int = state.next_team
				var answer: Dictionary
				if team == alpha_team:
					answer = await AlphaBetaAgent.new().choose_action(state, 2)
				else:
					# Paired colors reuse the same sequence of seeds for MCTS's own turns.
					answer = await MCTSAgent.new().choose_action(state, iterations, 2026 + seed_index + mcts_turn * 1009)
					mcts_turn += 1
				cpu[team] += answer.trace.stats.cpu_ms
				if not answer.complete or not BattleRules.rejection_reason(state, answer.action).is_empty():
					failures += 1
					push_error("A match agent returned an illegal or incomplete move")
					break
				if answer.action.card >= 0:
					if CardData.is_spell(answer.action.card):
						spells += 1
					else:
						deployments += 1
				state = SearchHelpers.result(state, answer.action)
				ply += 1
				if ply % 20 == 0:
					await process_frame
			if not SearchHelpers.terminal(state) or deployments == 0:
				failures += 1
				push_error("A complete numeric match did not finish or deploy units")
			var hp: Array[float] = BattleRules.total_hp(state)
			var damage: float = state.structure_damage_dealt[0] + state.structure_damage_dealt[1]
			# A defended short game may legitimately draw without tower damage.
			totals.structure_damage += damage
			var deaths: int = deployments - state.units.size()
			var blue: String = "AlphaBeta" if alpha_team == 0 else "MCTS"
			var red: String = "MCTS" if alpha_team == 0 else "AlphaBeta"
			var winner_name: String = "Draw" if state.winner == GameConstants.DRAW else (blue if state.winner == 0 else red)
			file.store_csv_line([str(2026 + seed_index), blue, red, str(duration), str(duration - state.remaining_time), winner_name, state.reason,
				str(hp[0]), str(hp[1]), str(state.structure_damage_dealt[0]), str(state.structure_damage_dealt[1]),
				str(deployments), str(deaths), str(spells), str(ply), str(cpu[alpha_team]), str(cpu[1 - alpha_team]), str(iterations)])
			file.flush()
			totals.games += 1
			if winner_name == "Draw": totals.draws += 1
			elif winner_name == "AlphaBeta": totals.alpha_beta_wins += 1
			else: totals.mcts_wins += 1
			print("MATCH %d/%d: %s, %.2fs simulated, damage %.0f, deployments %d, deaths %d, spells %d" % [totals.games, pairs * 2, winner_name, duration - state.remaining_time, damage, deployments, deaths, spells])
	if duration >= 30 and totals.structure_damage <= 0:
		failures += 1
		push_error("The complete match suite produced no structure combat")
	DecisionTrace.export_json({"format": {"duration": duration, "iterations": iterations, "alpha_beta_depth": 2},
		"results": totals, "failures": failures}, folder.path_join("paired_" + suffix + "_summary.json"))
	print("Paired matches: %d games, %d failures; %s" % [totals.games, failures, str(totals)])
	quit(1 if failures else 0)
