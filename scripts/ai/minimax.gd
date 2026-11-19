class_name MinimaxAgent
extends RefCounted
## Plain MAX/MIN recursion first. AlphaBetaAgent keeps the same scoring and order.

var cancelled: bool = false
var trace: Dictionary
var root_team: int
var weights: Dictionary
var _tree: SceneTree
var _waiting: int = 0
var _last_yield: int = 0

func choose_action(state: GameState, depth: int, tree: SceneTree = null) -> Dictionary:
	cancelled = false
	_tree = tree
	_waiting = 0
	var started: int = Time.get_ticks_usec()
	_last_yield = started
	root_team = SearchHelpers.player(state)
	var assessment: Dictionary = TacticalFuzzy.assess(state, root_team)
	weights = assessment.weights
	trace = DecisionTrace.begin(state, "Minimax", {"depth": depth}, assessment)
	DecisionTrace.add_node(trace, -1, CardData.wait_action(), state, 0)
	var best: float = -INF
	var best_action: Dictionary = CardData.wait_action()
	if SearchHelpers.terminal(state):
		best = SearchHelpers.utility(state, root_team, weights)
	else:
		for move: Dictionary in SearchHelpers.actions(state):
			trace.stats.forward_calls += 1
			var score: float = await value(SearchHelpers.result(state, move), maxi(0, depth - 1), 0, move, 1)
			if cancelled:
				break
			trace.root_actions.append({"action": move.duplicate(), "score": score, "bound": "exact"})
			if score > best:
				best = score
				best_action = move
	if not is_finite(best):
		best = 0.0
	DecisionTrace.update_node(trace, 0, {"score": best})
	return DecisionTrace.finish(trace, started, _waiting, not cancelled, best_action, best)

func value(state: GameState, depth: int, parent: int, move: Dictionary, ply: int) -> float:
	trace.stats.visited += 1
	var id: int = DecisionTrace.add_node(trace, parent, move, state, ply)
	if _tree != null and Time.get_ticks_usec() - _last_yield >= 12000:
		var before: int = Time.get_ticks_usec()
		await _tree.process_frame
		_waiting += Time.get_ticks_usec() - before
		_last_yield = Time.get_ticks_usec()
	if cancelled:
		return 0.0
	if SearchHelpers.terminal(state) or depth == 0:
		trace.stats.leaves += 1
		var evaluated: Dictionary = BattleEvaluation.breakdown(state, root_team, weights)
		DecisionTrace.update_node(trace, id, evaluated)
		return evaluated.score
	var score: float
	if SearchHelpers.player(state) == root_team:
		score = await max_value(state, depth, id, ply)
	else:
		score = await min_value(state, depth, id, ply)
	DecisionTrace.update_node(trace, id, {"score": score})
	return score

func max_value(state: GameState, depth: int, id: int, ply: int) -> float:
	var best: float = -INF
	for move: Dictionary in SearchHelpers.actions(state):
		trace.stats.forward_calls += 1
		var score: float = await value(SearchHelpers.result(state, move), depth - 1, id, move, ply + 1)
		if cancelled:
			return 0.0
		best = maxf(best, score)
	return best

func min_value(state: GameState, depth: int, id: int, ply: int) -> float:
	var best: float = INF
	for move: Dictionary in SearchHelpers.actions(state):
		trace.stats.forward_calls += 1
		var score: float = await value(SearchHelpers.result(state, move), depth - 1, id, move, ply + 1)
		if cancelled:
			return 0.0
		best = minf(best, score)
	return best
