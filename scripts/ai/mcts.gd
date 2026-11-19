class_name MCTSAgent
extends RefCounted
## Four named stages, a bounded rollout, and rewards kept in the root perspective.

const EXPLORATION := 1.41
const HORIZON := 6

class MCTSNode:
	extends RefCounted
	var state: GameState
	# Parent references are weak to avoid RefCounted parent/child cycles.
	var parent_ref: WeakRef
	var action: Dictionary
	var children: Array = []
	var visits: int = 0
	var total_value: float = 0.0
	var untried_actions: Array
	var depth: int
	var id: int

	func _init(position: GameState, parent: MCTSNode, move: Dictionary, level: int, node_id: int) -> void:
		state = position
		parent_ref = weakref(parent) if parent != null else null
		action = move
		depth = level
		id = node_id
		untried_actions = SearchHelpers.actions(state)

	func parent() -> MCTSNode:
		return parent_ref.get_ref() if parent_ref != null else null

var cancelled: bool = false
var root_team: int
var weights: Dictionary
var trace: Dictionary
var rng := RandomNumberGenerator.new()
var _next_id: int = 1
var _selection_steps: Array = []

static func uct(node: MCTSNode, root_player: int) -> float:
	if node.visits == 0:
		return INF
	var parent: MCTSNode = node.parent()
	var mean: float = node.total_value / node.visits
	var exploitation: float = mean if parent.state.next_team == root_player else 1.0 - mean
	var exploration: float = EXPLORATION * sqrt(log(maxi(1, parent.visits)) / node.visits)
	return exploitation + exploration

func choose_action(state: GameState, iterations: int, seed_value: int, tree: SceneTree = null) -> Dictionary:
	cancelled = false
	_next_id = 1
	rng.seed = seed_value
	root_team = state.next_team
	var started: int = Time.get_ticks_usec()
	var waiting: int = 0
	var last_yield: int = started
	var assessment: Dictionary = TacticalFuzzy.assess(state, root_team)
	weights = assessment.weights
	trace = DecisionTrace.begin(state, "MCTS", {"iterations": iterations, "horizon": HORIZON, "seed": seed_value, "exploration": EXPLORATION}, assessment)
	var root := MCTSNode.new(state.copy_state(), null, CardData.wait_action(), 0, 0)
	var completed: int = 0
	if not SearchHelpers.terminal(state):
		for trial in iterations:
			if cancelled:
				break
			_selection_steps = []
			var selected: MCTSNode = selection(root)
			var selected_path: Array = _path(selected)
			var expanded: MCTSNode = expansion(selected)
			var rollout: Dictionary = simulation(expanded)
			var backup: Array = backpropagation(expanded, rollout.reward)
			if trial < 3 or trial >= iterations - 3:
				trace.iterations.append({"trial": trial + 1, "selected_path": selected_path,
					"selection_steps": _selection_steps,
					"expanded_node": expanded.id if expanded != selected else -1,
					"expansion_action": expanded.action.duplicate() if expanded != selected else {},
					"rollout": rollout, "backup": backup})
			completed += 1
			# Work-time yielding keeps trial count independent of display FPS.
			if tree != null and Time.get_ticks_usec() - last_yield >= 25000:
				var before: int = Time.get_ticks_usec()
				await tree.process_frame
				waiting += Time.get_ticks_usec() - before
				last_yield = Time.get_ticks_usec()
	var chosen: MCTSNode = null
	for child: MCTSNode in root.children:
		var mean: float = child.total_value / child.visits
		trace.root_actions.append({"action": child.action.duplicate(), "visits": child.visits, "mean": mean})
		if chosen == null or child.visits > chosen.visits or (child.visits == chosen.visits and _better_tie(child, chosen)):
			chosen = child
	_save_tree(root)
	trace.stats.iterations_completed = completed
	trace.stats.leaves = completed
	var move: Dictionary = chosen.action if chosen != null else CardData.wait_action()
	var score: float = chosen.total_value / chosen.visits if chosen != null else _reward(state)
	return DecisionTrace.finish(trace, started, waiting, not cancelled and (completed == iterations or SearchHelpers.terminal(state)), move, score)

func selection(node: MCTSNode) -> MCTSNode:
	while not SearchHelpers.terminal(node.state) and node.depth < HORIZON:
		if not node.untried_actions.is_empty() or node.children.is_empty():
			break
		var best: MCTSNode = node.children[0]
		var best_score: float = uct(best, root_team)
		var candidates: Array = []
		for child: MCTSNode in node.children:
			var score: float = uct(child, root_team)
			var mean: float = child.total_value / child.visits if child.visits > 0 else 0.0
			var exploitation: float = mean if node.state.next_team == root_team else 1.0 - mean
			candidates.append({"node": child.id, "action": child.action.duplicate(), "visits": child.visits,
				"mean": mean, "exploitation": exploitation,
				"exploration": DecisionTrace.bound_number(score - exploitation), "uct": DecisionTrace.bound_number(score)})
			if score > best_score:
				best = child
				best_score = score
		_selection_steps.append({"parent": node.id, "actor": node.state.next_team, "parent_visits": node.visits,
			"candidates": candidates, "chosen": best.id})
		node = best
	return node

func expansion(node: MCTSNode) -> MCTSNode:
	if SearchHelpers.terminal(node.state) or node.depth >= HORIZON or node.untried_actions.is_empty():
		return node
	var index: int = rng.randi_range(0, node.untried_actions.size() - 1)
	var move: Dictionary = node.untried_actions[index]
	node.untried_actions.remove_at(index)
	trace.stats.forward_calls += 1
	var child := MCTSNode.new(SearchHelpers.result(node.state, move), node, move, node.depth + 1, _next_id)
	_next_id += 1
	node.children.append(child)
	return child

func simulation(node: MCTSNode) -> Dictionary:
	var state: GameState = node.state.copy_state()
	var depth: int = node.depth
	var moves: Array = []
	while not SearchHelpers.terminal(state) and depth < HORIZON:
		var legal: Array = SearchHelpers.actions(state)
		var move: Dictionary = legal[rng.randi_range(0, legal.size() - 1)]
		moves.append({"team": state.next_team, "action": move.duplicate()})
		state = SearchHelpers.result(state, move)
		trace.stats.forward_calls += 1
		depth += 1
	return {"actions": moves, "depth": depth, "reward": _reward(state),
		"source": "terminal" if SearchHelpers.terminal(state) else "heuristic cutoff",
		"evaluation": BattleEvaluation.breakdown(state, root_team, weights)}

func backpropagation(node: MCTSNode, reward: float) -> Array:
	var changes: Array = []
	while node != null:
		var before_visits: int = node.visits
		var before_value: float = node.total_value
		node.visits += 1
		node.total_value += reward
		changes.append({"node": node.id, "visits_before": before_visits, "visits_after": node.visits,
			"value_before": before_value, "value_after": node.total_value})
		node = node.parent()
	return changes

func _reward(state: GameState) -> float:
	if SearchHelpers.terminal(state):
		return 0.5 if state.winner == GameConstants.DRAW else (1.0 if state.winner == root_team else 0.0)
	return clampf(0.5 + SearchHelpers.utility(state, root_team, weights) / 400.0, 0.0, 1.0)

func _path(node: MCTSNode) -> Array:
	var path: Array = []
	while node != null:
		path.push_front(node.id)
		node = node.parent()
	return path

func _better_tie(a: MCTSNode, b: MCTSNode) -> bool:
	var mean_a: float = a.total_value / a.visits
	var mean_b: float = b.total_value / b.visits
	if mean_a != mean_b:
		return mean_a > mean_b
	var key_a: int = a.action.card * 2 + a.action.lane if a.action.card >= 0 else 10
	var key_b: int = b.action.card * 2 + b.action.lane if b.action.card >= 0 else 10
	return key_a < key_b

func _save_tree(node: MCTSNode) -> void:
	if trace.nodes.size() >= DecisionTrace.MAX_NODES:
		trace.trace_truncated = true
		return
	var parent: MCTSNode = node.parent()
	trace.nodes.append({"id": node.id, "parent": parent.id if parent != null else -1,
		"action": node.action.duplicate(), "actor": node.state.next_team, "ply": node.depth,
		"visits": node.visits, "total_value": node.total_value,
		"mean": node.total_value / node.visits if node.visits > 0 else 0.0, "pruned": false})
	trace.stats.visited = trace.nodes.size()
	for child: MCTSNode in node.children:
		_save_tree(child)
