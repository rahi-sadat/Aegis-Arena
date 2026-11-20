class_name LiveDecisionFeed
extends RefCounted
## Read-only adapter over existing telemetry. Never starts or modifies a search.

static func sample(controller: AIManager, team: int) -> Dictionary:
	var source: Dictionary = {}
	var phase: String = "WAITING"
	if controller._agent != null:
		var active: Dictionary = controller._agent.trace
		if not active.is_empty() and active.team == team:
			source = active
			phase = "SEARCHING"
	if source.is_empty() and not controller._pending.is_empty() and controller._pending.trace.team == team:
		source = controller._pending.trace
		phase = "PREPARED"
	if source.is_empty() and not controller.last_traces[team].is_empty():
		source = controller.last_traces[team]
		phase = "EXECUTED"
	if source.is_empty():
		return {}
	var trial: int = source.iterations[-1].trial if not source.iterations.is_empty() else 0
	var key: String = "%d/%d/%s/%s/%d/%d/%d" % [controller._generation, team, phase,
		str(source.get("decision_id", "next")), source.stats.visited, source.stats.forward_calls, trial]
	return {"source": source, "phase": phase, "key": key}

static func snapshot(sampled: Dictionary) -> Dictionary:
	var record: Dictionary = sampled.source.duplicate(true)
	record.view_phase = sampled.phase
	if not record.has("complete"):
		record.complete = false
	if not record.has("selected_action"):
		record.selected_action = {}
	# MCTS stores its full tree on completion. While it runs, only show actual
	# nodes present in its sampled trial records, with a clear partial-data label.
	if record.algorithm == "MCTS" and record.nodes.is_empty():
		record.nodes = _partial_mcts(record)
		record.view_partial = true
	return record

static func _partial_mcts(record: Dictionary) -> Array:
	var nodes: Dictionary = {0: {"id": 0, "parent": -1, "action": CardData.wait_action(),
		"actor": record.team, "ply": 0, "visits": 0, "total_value": 0.0, "mean": 0.0, "pruned": false}}
	for trial: Dictionary in record.iterations:
		var path: Array = trial.selected_path.duplicate()
		for step: Dictionary in trial.get("selection_steps", []):
			var depth: int = path.find(step.parent) + 1
			for candidate: Dictionary in step.candidates:
				nodes[candidate.node] = {"id": candidate.node, "parent": step.parent,
					"action": candidate.action.duplicate(), "actor": 1 - step.actor, "ply": depth,
					"visits": candidate.visits, "total_value": candidate.mean * candidate.visits,
					"mean": candidate.mean, "pruned": false}
		if trial.expanded_node >= 0:
			var parent: int = path[-1]
			nodes[trial.expanded_node] = {"id": trial.expanded_node, "parent": parent,
				"action": trial.expansion_action.duplicate(), "actor": record.team if path.size() % 2 == 0 else 1 - record.team,
				"ply": path.size(), "visits": 0, "total_value": 0.0, "mean": 0.0, "pruned": false}
		for update: Dictionary in trial.backup:
			if nodes.has(update.node):
				nodes[update.node].visits = update.visits_after
				nodes[update.node].total_value = update.value_after
				nodes[update.node].mean = update.value_after / update.visits_after
	var ids: Array = nodes.keys()
	ids.sort()
	var ordered: Array = []
	for id: int in ids:
		ordered.append(nodes[id])
	return ordered
