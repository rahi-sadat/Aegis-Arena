class_name AIManager
extends Node
## One deployment per slot. The next agent plans while live combat runs fifteen ticks.

signal decision_made(trace: Dictionary)
signal human_action_queued(move: Dictionary)

var manager: GameManager
var enabled: bool = true
var logging_enabled: bool = true
var last_traces: Array = [{}, {}]
var history: Array = [[], []]
var queued_human_action: Dictionary = CardData.wait_action()
var decisions: int = 0
var missed_slots: int = 0
var export_directory: String = "res://output/evidence"
var _generation: int = 0
var _agent: Variant = null
var _pending: Dictionary = {}
var _predicted_root: GameState

func bind_match(match_manager: GameManager) -> void:
	manager = match_manager
	manager.match_started.connect(_on_match_started)
	manager.battle_ticked.connect(_on_tick)
	manager.prediction_invalidated.connect(_on_prediction_invalidated)
	manager.match_ended.connect(_on_match_ended)
	if not OS.has_feature("editor"):
		export_directory = "user://evidence"

func cancel() -> void:
	_generation += 1
	if _agent != null:
		_agent.cancelled = true
	_agent = null
	_pending = {}

func _exit_tree() -> void:
	cancel()

func _on_match_started() -> void:
	cancel()
	enabled = MatchConfig.autoplay_enabled
	last_traces = [{}, {}]
	history = [[], []]
	decisions = 0
	missed_slots = 0
	queued_human_action = CardData.wait_action()
	if not enabled:
		return
	if logging_enabled:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(export_directory))
		var file: FileAccess = FileAccess.open(export_directory.path_join("decisions.csv"), FileAccess.WRITE)
		if file != null:
			file.store_csv_line(["decision", "team", "algorithm", "tick", "selected", "executed", "complete", "visited", "leaves", "cutoffs", "cpu_ms", "wall_ms", "status"])
	manager.is_preparing = true
	_predicted_root = manager.battle_state.copy_state()
	if MatchConfig.is_human(0):
		_commit(_human_choice())
	else:
		_plan(_predicted_root, true)

func _process(_delta: float) -> void:
	if enabled and manager != null and manager.is_preparing and not manager.is_paused and not _pending.is_empty():
		_commit(_pending)

func queue_human_action(move: Dictionary) -> bool:
	if not enabled or not manager.is_running or manager.is_paused or not MatchConfig.is_human(0):
		return false
	var state: GameState = manager.battle_state.copy_state()
	state.next_team = 0
	if not BattleRules.rejection_reason(state, move).is_empty():
		return false
	queued_human_action = move.duplicate()
	human_action_queued.emit(queued_human_action)
	return true

func _plan(root: GameState, first: bool = false) -> void:
	cancel()
	_predicted_root = root
	if SearchHelpers.terminal(root):
		return
	var job: int = _generation
	var team: int = root.next_team
	var algorithm: int = MatchConfig.algorithms[team]
	var job_agent: Variant
	var answer: Dictionary
	if algorithm == MatchConfig.Algorithm.MCTS:
		job_agent = MCTSAgent.new()
		_agent = job_agent
		answer = await job_agent.choose_action(root, MatchConfig.mcts_iterations[team], MatchConfig.random_seed + decisions * 1009 + team * 37, get_tree())
	else:
		job_agent = MinimaxAgent.new() if algorithm == MatchConfig.Algorithm.MINIMAX else AlphaBetaAgent.new()
		_agent = job_agent
		answer = await job_agent.choose_action(root, MatchConfig.search_depth[team], get_tree())
	if not is_inside_tree() or job != _generation or not enabled or not manager.is_running:
		return
	_agent = null
	_pending = answer
	if first and not manager.is_paused:
		_commit(answer)

func _prepare_next() -> void:
	var root: GameState = manager.battle_state.copy_state()
	BattleRules.advance_interval(root)
	_predicted_root = root
	if MatchConfig.is_human(root.next_team):
		cancel()
		return
	_plan(root)

func _on_tick() -> void:
	if not enabled or manager.battle_state.tick_index % BattleRules.TICKS_PER_DECISION != 0:
		return
	if MatchConfig.is_human(manager.battle_state.next_team):
		_commit(_human_choice())
	elif not _pending.is_empty():
		_commit(_pending)
	else:
		missed_slots += 1
		var fallback: Dictionary = _fallback("Budget exceeded; Wait executed")
		cancel()
		_commit(fallback)

func _commit(answer: Dictionary) -> void:
	var state: GameState = manager.battle_state
	var team: int = state.next_team
	var trace: Dictionary = answer.trace
	var move: Dictionary = answer.action
	var predicted_match: bool = _predicted_root != null and state.to_dictionary() == _predicted_root.to_dictionary()
	var status: String = "Executed"
	if not answer.complete:
		move = CardData.wait_action()
		status = trace.get("status", "Incomplete search; Wait executed")
	elif trace.algorithm != "Human" and not predicted_match:
		move = CardData.wait_action()
		status = "Prediction changed; Wait executed"
	elif not BattleRules.rejection_reason(state, move).is_empty():
		move = CardData.wait_action()
		status = "Action no longer legal; Wait executed"
	var accepted: bool = manager.execute_action(move)
	trace.decision_id = decisions
	trace.execution = {"action": move.duplicate(), "accepted": accepted, "tick": state.tick_index,
		"predicted_state_matched": predicted_match, "status": status}
	last_traces[team] = trace
	history[team].append(trace)
	if history[team].size() > 12:
		history[team].pop_front()
	decisions += 1
	decision_made.emit(trace)
	if logging_enabled:
		_append_csv(trace)
	if manager.is_preparing:
		manager.finish_preparation()
	state.next_team = GameConstants.opponent(team)
	_pending = {}
	manager.battle_changed.emit()
	_prepare_next()

func _human_choice() -> Dictionary:
	var move: Dictionary = queued_human_action
	queued_human_action = CardData.wait_action()
	var state: GameState = manager.battle_state
	var assessment: Dictionary = TacticalFuzzy.assess(state, state.next_team)
	var trace: Dictionary = DecisionTrace.begin(state, "Human", {}, assessment)
	trace.complete = true
	trace.selected_action = move.duplicate()
	trace.stats.cpu_ms = 0.0
	trace.stats.wall_ms = 0.0
	return {"action": move, "trace": trace, "complete": true}

func _fallback(message: String) -> Dictionary:
	var state: GameState = manager.battle_state
	var trace: Dictionary = DecisionTrace.begin(state, MatchConfig.ALGORITHM_NAMES[MatchConfig.algorithms[state.next_team]], {}, TacticalFuzzy.assess(state, state.next_team))
	trace.complete = false
	trace.status = message
	trace.selected_action = CardData.wait_action()
	trace.stats.cpu_ms = 0.0
	trace.stats.wall_ms = 0.0
	return {"action": CardData.wait_action(), "trace": trace, "complete": false}

func _on_prediction_invalidated() -> void:
	if not enabled or not manager.is_running:
		return
	if manager.is_preparing:
		_plan(manager.battle_state.copy_state(), true)
		return
	cancel()
	var root: GameState = manager.battle_state.copy_state()
	var ticks_left: int = BattleRules.TICKS_PER_DECISION - root.tick_index % BattleRules.TICKS_PER_DECISION
	for tick in ticks_left:
		BattleRules.advance_tick(root)
	_predicted_root = root
	if not MatchConfig.is_human(root.next_team):
		_plan(root)

func export_latest() -> Error:
	var error: Error = OK
	for team in 2:
		if not last_traces[team].is_empty():
			var saved: Error = DecisionTrace.export_json(last_traces[team], export_directory.path_join("last_" + GameConstants.team_name(team).to_lower() + ".json"))
			if saved != OK:
				error = saved
	var route_error: Error = DecisionTrace.export_json(ArenaGrid.trace_dictionary(), export_directory.path_join("astar_routes.json"))
	if route_error != OK:
		error = route_error
	return error

func _append_csv(trace: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(export_directory.path_join("decisions.csv"), FileAccess.READ_WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_csv_line([str(trace.decision_id), GameConstants.team_name(trace.team), trace.algorithm, str(trace.execution.tick),
		CardData.action_name(trace.selected_action), CardData.action_name(trace.execution.action), str(trace.complete),
		str(trace.stats.visited), str(trace.stats.leaves), str(trace.stats.cutoffs),
		"%.3f" % trace.stats.cpu_ms, "%.3f" % trace.stats.wall_ms, trace.execution.status])

func _on_match_ended(match_result: Dictionary) -> void:
	cancel()
	if logging_enabled:
		export_latest()
		DecisionTrace.export_json({"result": match_result, "decisions": decisions, "missed_slots": missed_slots,
			"seed": MatchConfig.random_seed}, export_directory.path_join("match_result.json"))
