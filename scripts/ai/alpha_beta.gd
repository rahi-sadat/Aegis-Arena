class_name AlphaBetaAgent
extends RefCounted
## Minimax with two bounds. Only the bound updates and cutoff skip extra work.

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
	trace = DecisionTrace.begin(state, "Minimax + alpha-beta", {"depth": depth}, assessment)
	DecisionTrace.add_node(trace, -1, CardData.wait_action(), state, 0)
	DecisionTrace.update_node(trace, 0, {"alpha_before": "-inf", "beta_before": "+inf"})
	var alpha: float = -INF
	var best: float = -INF
	var best_action: Dictionary = CardData.wait_action()
	if SearchHelpers.terminal(state):
		best = SearchHelpers.utility(state, root_team, weights)
	else:
		for move: Dictionary in SearchHelpers.actions(state):
			trace.stats.forward_calls += 1
			var score: float = await value(SearchHelpers.result(state, move), maxi(0, depth - 1), alpha, INF, 0, move, 1)
			if cancelled:
				break
			trace.root_actions.append({"action": move.duplicate(), "score": score, "bound": "upper" if score <= alpha else "exact"})
			if score > best:
				best = score
				best_action = move
			alpha = maxf(alpha, best)
	if not is_finite(best):
		best = 0.0
	DecisionTrace.update_node(trace, 0, {"score": best, "alpha_after": DecisionTrace.bound_number(alpha), "beta_after": "+inf"})
	return DecisionTrace.finish(trace, started, _waiting, not cancelled, best_action, best)

func value(state: GameState, depth: int, alpha: float, beta: float, parent: int, move: Dictionary, ply: int) -> float:
	trace.stats.visited += 1
	var id: int = DecisionTrace.add_node(trace, parent, move, state, ply)
	DecisionTrace.update_node(trace, id, {"alpha_before": DecisionTrace.bound_number(alpha), "beta_before": DecisionTrace.bound_number(beta)})
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
		DecisionTrace.update_node(trace, id, {"alpha_after": DecisionTrace.bound_number(alpha), "beta_after": DecisionTrace.bound_number(beta)})
		return evaluated.score
	var maximizing: bool = SearchHelpers.player(state) == root_team
	var best: float = -INF if maximizing else INF
	var moves: Array = SearchHelpers.actions(state)
	for index in moves.size():
		var next: Dictionary = moves[index]
		trace.stats.forward_calls += 1
		var score: float = await value(SearchHelpers.result(state, next), depth - 1, alpha, beta, id, next, ply + 1)
		if cancelled:
			return 0.0
		if maximizing:
			best = maxf(best, score)
			alpha = maxf(alpha, best)
		else:
			best = minf(best, score)
			beta = minf(beta, best)
		if alpha >= beta:
			trace.stats.cutoffs += 1
			DecisionTrace.update_node(trace, id, {"bound": "lower" if maximizing else "upper", "cutoff": true})
			for skipped in range(index + 1, moves.size()):
				DecisionTrace.add_pruned(trace, id, moves[skipped], GameConstants.opponent(state.next_team), ply + 1)
			break
	DecisionTrace.update_node(trace, id, {"score": best, "alpha_after": DecisionTrace.bound_number(alpha), "beta_after": DecisionTrace.bound_number(beta)})
	return best
