extends SceneTree
## Independent shallow exhaustive oracle, tactical outcomes, UCT, and trace checks.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fuzzy: Dictionary = TacticalFuzzy.from_inputs(0.65, 0.35, 0.30)
	_check(is_equal_approx(fuzzy.outputs.attack, 0.35) and is_equal_approx(fuzzy.outputs.defend, 0.65) and is_equal_approx(fuzzy.outputs.save, 0.70), "Worked Sugeno outputs match the report")
	_check(fuzzy.weights == {"T": 100.0, "U": 26.5, "E": 4.8, "P": 13.5}, "Fuzzy weights match the report")
	for value in [0.0, 0.3, 0.5, 0.65, 1.0]:
		var degrees: Dictionary = TacticalFuzzy.membership(value)
		_check(is_equal_approx(degrees.low + degrees.medium + degrees.high, 1.0), "Memberships cover endpoints and overlapping inputs")
	var state: GameState = GameState.create_default()
	state.energy = [3.0, 3.0]
	state.cooldowns[0][4] = 10.0
	state.cooldowns[1][4] = 10.0
	_check(SearchHelpers.actions(state).size() == 3, "Small scenario has exactly three legal actions")
	var original: Dictionary = state.to_dictionary()
	var expected: Dictionary = _oracle_two_plies(state)
	var plain: Dictionary = await MinimaxAgent.new().choose_action(state, 2)
	var pruned: Dictionary = await AlphaBetaAgent.new().choose_action(state, 2)
	_check(plain.action == expected.action and is_equal_approx(plain.score, expected.score), "Actual Minimax agrees with independent nine-leaf exhaustive oracle")
	_check(pruned.action == plain.action and is_equal_approx(pruned.score, plain.score), "Alpha-beta preserves the root choice and score")
	_check(plain.trace.stats.visited == 13 and plain.trace.stats.leaves == 9, "Three-by-three Minimax trace counts all thirteen states")
	_check(pruned.trace.stats.visited <= plain.trace.stats.visited, "Alpha-beta examines no more states on the same ordered tree")
	_check(state.to_dictionary() == original, "Both searches leave their root state untouched")
	for node: Dictionary in pruned.trace.nodes:
		if node.pruned:
			_check(not node.has("score"), "A skipped branch has no fabricated score")
	DecisionTrace.export_json(plain.trace, "res://output/evidence/small_minimax.json")
	DecisionTrace.export_json(pruned.trace, "res://output/evidence/small_alpha_beta.json")
	for team in 2:
		state = _core_threat(team)
		original = state.to_dictionary()
		var minimax: Dictionary = await MinimaxAgent.new().choose_action(state, 2)
		var alpha_beta: Dictionary = await AlphaBetaAgent.new().choose_action(state, 2)
		_check(minimax.action == CardData.action(4, 0), "Minimax saves the threatened core as " + GameConstants.team_name(team))
		_check(alpha_beta.action == minimax.action and is_equal_approx(alpha_beta.score, minimax.score), "Alpha-beta agrees on the forced defense for either root color")
		var sampled: Dictionary = await MCTSAgent.new().choose_action(state, 100, 2026 + team)
		var repeated: Dictionary = await MCTSAgent.new().choose_action(state, 100, 2026 + team)
		_check(sampled.action == CardData.action(4, 0), "MCTS learns the only action that avoids immediate core defeat")
		_check(sampled.trace.root_actions == repeated.trace.root_actions and sampled.action == repeated.action, "A fixed MCTS seed reproduces visits, values, and final move")
		_check(state.to_dictionary() == original, "MCTS rollouts leave the root isolated")
		var visits: int = 0
		for child: Dictionary in sampled.trace.root_actions:
			visits += child.visits
		_check(visits == 100 and sampled.trace.nodes[0].visits == 100, "Every MCTS trial backs up exactly one root visit")
		for iteration: Dictionary in sampled.trace.iterations:
			_check(iteration.rollout.depth <= 6 and iteration.rollout.reward >= 0 and iteration.rollout.reward <= 1, "Rollouts respect the shared six-ply horizon and reward bounds")
			for update: Dictionary in iteration.backup:
				_check(update.visits_after == update.visits_before + 1 and is_equal_approx(update.value_after - update.value_before, iteration.rollout.reward), "Backup applies one unchanged root-relative reward to each ancestor")
		if team == 0:
			DecisionTrace.export_json(sampled.trace, "res://output/evidence/mcts_forced_defense.json")
	var parent_state: GameState = GameState.create_default()
	parent_state.next_team = 1
	var parent := MCTSAgent.MCTSNode.new(parent_state, null, CardData.wait_action(), 0, 0)
	parent.visits = 20
	var unvisited := MCTSAgent.MCTSNode.new(parent_state.copy_state(), parent, CardData.wait_action(), 1, 1)
	_check(is_inf(MCTSAgent.uct(unvisited, 0)), "An unvisited child gets exploration priority at an opponent node")
	unvisited.visits = 6
	unvisited.total_value = 4.2
	var expected_uct: float = 0.3 + 1.41 * sqrt(log(20.0) / 6.0)
	_check(is_equal_approx(MCTSAgent.uct(unvisited, 0), expected_uct), "Opponent UCT uses 1-Q plus a positive exploration bonus")
	state = GameState.create_default()
	state.energy = [0.0, 0.0]
	var only_wait: Dictionary = await MCTSAgent.new().choose_action(state, 10, 1)
	_check(only_wait.action == CardData.wait_action(), "A wait-only root is a valid MCTS search")
	state.winner = 0
	_check(SearchHelpers.utility(state, 0, fuzzy.weights) == 10000 and SearchHelpers.utility(state, 1, fuzzy.weights) == -10000, "Terminal scoring overrides root color and heuristic")
	var finished: Dictionary = await MCTSAgent.new().choose_action(state, 100, 1)
	_check(finished.complete and finished.trace.root_actions.is_empty(), "A terminal root does not attempt an illegal expansion")
	var encoded: String = JSON.stringify(original)
	var restored: GameState = GameState.from_dictionary(JSON.parse_string(encoded))
	_check(restored.to_dictionary() == original, "Saved numeric snapshots can be replayed from JSON")
	print("Search: %d checks, %d failures" % [checks, failures])
	print("Small tree: Minimax %d states, alpha-beta %d states, root %.5f" % [plain.trace.stats.visited, pruned.trace.stats.visited, plain.score])
	quit(1 if failures else 0)

func _core_threat(team: int) -> GameState:
	var state: GameState = GameState.create_default()
	state.next_team = GameConstants.opponent(team)
	BattleRules.apply_action(state, CardData.action(0, 0))
	state.units[0].hp = 40.0
	state.units[0].progress = 28.0 if team == 0 else ArenaGrid.lengths[0] - 28.0
	state.structures[2 if team == 0 else 5].hp = 1.0
	state.next_team = team
	state.energy[team] = 3.0
	return state

func _oracle_two_plies(state: GameState) -> Dictionary:
	# Direct enumeration is independent of either recursive implementation.
	var weights: Dictionary = TacticalFuzzy.assess(state, state.next_team).weights
	var best: float = -INF
	var action: Dictionary = CardData.wait_action()
	for our_move: Dictionary in SearchHelpers.actions(state):
		var reply_state: GameState = SearchHelpers.result(state, our_move)
		var worst: float = INF
		for reply: Dictionary in SearchHelpers.actions(reply_state):
			var leaf: GameState = SearchHelpers.result(reply_state, reply)
			worst = minf(worst, SearchHelpers.utility(leaf, state.next_team, weights))
		if worst > best:
			best = worst
			action = our_move
	return {"action": action, "score": best}

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
