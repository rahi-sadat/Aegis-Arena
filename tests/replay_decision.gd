extends SceneTree
## Re-run an exported completed decision using its exact numeric snapshot and seed.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: --script res://tests/replay_decision.gd -- <decision.json>")
		quit(1)
		return
	var file: FileAccess = FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		push_error("Could not read the decision JSON")
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("root_snapshot") or not parsed.get("complete", false):
		push_error("Provide a completed algorithm decision with its root_snapshot")
		quit(1)
		return
	var trace: Dictionary = parsed
	ArenaGrid.setup()
	var state: GameState = GameState.from_dictionary(trace.root_snapshot)
	var answer: Dictionary
	if trace.algorithm == "MCTS":
		answer = await MCTSAgent.new().choose_action(state, int(trace.parameters.iterations), int(trace.parameters.seed))
	elif trace.algorithm == "Minimax":
		answer = await MinimaxAgent.new().choose_action(state, int(trace.parameters.depth))
	elif trace.algorithm == "Minimax + alpha-beta":
		answer = await AlphaBetaAgent.new().choose_action(state, int(trace.parameters.depth))
	else:
		push_error("This trace is not a supported search decision")
		quit(1)
		return
	var expected: Dictionary = CardData.action(int(trace.selected_action.card), int(trace.selected_action.lane))
	var matches_action: bool = answer.action == expected
	var matches_score: bool = is_equal_approx(answer.score, float(trace.score))
	DecisionTrace.export_json(answer.trace, "res://output/evidence/replayed_decision.json")
	print("Replay %s: action %s, score %.8f; action matches=%s, score matches=%s" % [trace.algorithm,
		CardData.action_name(answer.action), answer.score, matches_action, matches_score])
	quit(0 if matches_action and matches_score else 1)
