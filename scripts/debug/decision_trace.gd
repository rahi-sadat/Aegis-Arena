class_name DecisionTrace
extends RefCounted
## Plain dictionaries keep a decision inspectable and JSON-exportable.

const MAX_NODES := 500

static func begin(state: GameState, algorithm: String, parameters: Dictionary, assessment: Dictionary) -> Dictionary:
	return {"algorithm": algorithm, "team": state.next_team, "parameters": parameters,
		"root_snapshot": state.to_dictionary(), "assessment": assessment,
		"legal_actions": BattleRules.actions(state), "root_actions": [], "nodes": [], "iterations": [],
		"trace_truncated": false, "stats": {"visited": 1, "leaves": 0, "cutoffs": 0, "forward_calls": 0}}

static func add_node(trace: Dictionary, parent: int, move: Dictionary, state: GameState, ply: int) -> int:
	if trace.nodes.size() >= MAX_NODES:
		trace.trace_truncated = true
		return -1
	var id: int = trace.nodes.size()
	trace.nodes.append({"id": id, "parent": parent, "action": move.duplicate(), "actor": state.next_team,
		"ply": ply, "pruned": false, "bound": "exact"})
	return id

static func update_node(trace: Dictionary, id: int, values: Dictionary) -> void:
	if id >= 0:
		trace.nodes[id].merge(values, true)

static func add_pruned(trace: Dictionary, parent: int, move: Dictionary, actor: int, ply: int) -> void:
	if trace.nodes.size() >= MAX_NODES:
		trace.trace_truncated = true
		return
	trace.nodes.append({"id": trace.nodes.size(), "parent": parent, "action": move.duplicate(), "actor": actor,
		"ply": ply, "pruned": true, "bound": "not evaluated"})

static func bound_number(value: float) -> Variant:
	return value if is_finite(value) else ("+inf" if value > 0 else "-inf")

static func finish(trace: Dictionary, started: int, waiting: int, complete: bool, move: Dictionary, score: float) -> Dictionary:
	trace.complete = complete
	trace.selected_action = move.duplicate()
	trace.score = score
	var elapsed: int = Time.get_ticks_usec() - started
	trace.stats.wall_ms = elapsed / 1000.0
	trace.stats.cpu_ms = (elapsed - waiting) / 1000.0
	trace.stats.forward_ticks_upper_bound = trace.stats.forward_calls * BattleRules.TICKS_PER_DECISION
	return {"action": move, "score": score, "trace": trace, "complete": complete}

static func export_json(trace: Dictionary, path: String) -> Error:
	var error: Error = DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(trace, "\t", false, true))
	return OK
