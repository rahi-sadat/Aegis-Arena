class_name GameManager
extends Node
## Owns the numeric battle. Nodes display its state; planners receive isolated copies.

signal match_started
signal match_ended(result: Dictionary)
signal timer_changed(remaining_seconds: float)
signal structure_health_changed(structure: ArenaStructure)
signal pause_changed(paused: bool)
signal battle_changed
signal battle_ticked
signal action_executed(move: Dictionary, team: int)
signal prediction_invalidated

@export var balance: GameBalance = preload("res://data/balance/game_balance.tres")

var structures: Array[ArenaStructure] = []
var battle_state: GameState
var remaining_match_time: float = 0.0
var is_running: bool = false
var is_paused: bool = false
var is_preparing: bool = false
var winner: int = GameConstants.UNDECIDED
var result: Dictionary = {}
var structure_damage_dealt: Array[float] = [0.0, 0.0]
var starting_structure_hp: Array[float] = [0.0, 0.0]
var last_attacks: Array = []
var last_action: Dictionary = CardData.wait_action()
var _accumulator: float = 0.0
var _displaying_state: bool = false
var _starting_live_clock: bool = false

func start_match(match_structures: Array[ArenaStructure]) -> void:
	is_running = false
	for structure in structures:
		if structure.damaged.is_connected(_on_structure_damaged):
			structure.damaged.disconnect(_on_structure_damaged)
	structures = match_structures.duplicate()
	battle_state = GameState.create_default(balance.match_duration_seconds)
	battle_state.structures.clear()
	battle_state.starting_structure_hp = [0.0, 0.0]
	for structure in structures:
		structure.reset_health()
		battle_state.starting_structure_hp[structure.team_id] += structure.max_hp
		battle_state.structures.append({"id": String(structure.structure_id), "team": structure.team_id,
			"kind": structure.data.structure_type, "lane": -1 if structure.data.structure_type == StructureData.Kind.CORE else structure.lane,
			"hp": structure.max_hp, "max_hp": structure.max_hp, "attack_remaining": 0.0})
		structure.damaged.connect(_on_structure_damaged)
	remaining_match_time = balance.match_duration_seconds
	structure_damage_dealt = battle_state.structure_damage_dealt
	starting_structure_hp = battle_state.starting_structure_hp
	winner = GameConstants.UNDECIDED
	result = {}
	last_attacks = []
	last_action = CardData.wait_action()
	_accumulator = 0.0
	_starting_live_clock = false
	is_preparing = false
	is_paused = false
	is_running = true
	pause_changed.emit(false)
	match_started.emit()
	timer_changed.emit(remaining_match_time)
	battle_changed.emit()

func _process(delta: float) -> void:
	if not is_running or is_paused or is_preparing:
		return
	# A cold renderer may spend a long frame preparing the first move. That frame
	# must not consume most of the opponent's first 0.75-second planning window.
	if _starting_live_clock:
		delta = minf(delta, BattleRules.TICK_SECONDS)
		_starting_live_clock = false
	_accumulator += delta
	last_attacks = []
	while _accumulator + BattleRules.EPSILON >= BattleRules.TICK_SECONDS and is_running:
		_accumulator = maxf(0.0, _accumulator - BattleRules.TICK_SECONDS)
		last_attacks.append_array(BattleRules.advance_tick(battle_state))
		if battle_state.winner != GameConstants.UNDECIDED:
			_sync_display()
			_finish_match(battle_state.winner, battle_state.reason)
			break
		battle_ticked.emit()
	_sync_display()

func finish_preparation() -> void:
	is_preparing = false
	_starting_live_clock = true

func execute_action(move: Dictionary) -> bool:
	if not is_running or is_paused:
		return false
	var team: int = battle_state.next_team
	if not BattleRules.apply_action(battle_state, move):
		return false
	last_action = move.duplicate()
	action_executed.emit(move, team)
	_sync_display()
	return true

func toggle_pause() -> void:
	if not is_running:
		return
	is_paused = not is_paused
	pause_changed.emit(is_paused)
	battle_changed.emit()

func damage_structure(structure_id: StringName, amount: float) -> float:
	if not is_running or is_paused or not is_finite(amount) or amount <= 0:
		return 0.0
	for index in battle_state.structures.size():
		var structure: Dictionary = battle_state.structures[index]
		if structure.id == String(structure_id):
			var actual: float = BattleRules.damage_structure(battle_state, index, amount, GameConstants.opponent(structure.team))
			BattleRules.check_terminal(battle_state)
			_sync_display()
			prediction_invalidated.emit()
			if battle_state.winner != GameConstants.UNDECIDED:
				_finish_match(battle_state.winner, battle_state.reason)
			return actual
	return 0.0

func total_remaining_hp() -> Array[float]:
	return BattleRules.total_hp(battle_state) if battle_state != null else [0.0, 0.0]

func _sync_display() -> void:
	remaining_match_time = battle_state.remaining_time
	_displaying_state = true
	for index in structures.size():
		var structure: ArenaStructure = structures[index]
		var target_hp: float = battle_state.structures[index].hp
		if structure.current_hp > target_hp:
			structure.take_damage(structure.current_hp - target_hp)
	_displaying_state = false
	timer_changed.emit(remaining_match_time)
	battle_changed.emit()

func _on_structure_damaged(structure: ArenaStructure, actual_damage: float) -> void:
	# Display synchronization must not count model damage for a second time.
	if not _displaying_state and is_running:
		for index in structures.size():
			if structures[index] == structure:
				BattleRules.damage_structure(battle_state, index, actual_damage, GameConstants.opponent(structure.team_id))
				BattleRules.check_terminal(battle_state)
				prediction_invalidated.emit()
				if battle_state.winner != GameConstants.UNDECIDED:
					_finish_match(battle_state.winner, battle_state.reason)
	structure_health_changed.emit(structure)

func _finish_match(winning_team: int, reason: String) -> void:
	if not is_running:
		return
	is_running = false
	is_preparing = false
	is_paused = false
	winner = winning_team
	var hp: Array[float] = total_remaining_hp()
	result = {"winner": winner, "reason": reason,
		"elapsed_seconds": balance.match_duration_seconds - remaining_match_time,
		"remaining_hp": hp,
		"remaining_fraction": [MatchRules.remaining_fraction(hp[0], starting_structure_hp[0]), MatchRules.remaining_fraction(hp[1], starting_structure_hp[1])],
		"damage_dealt": structure_damage_dealt.duplicate()}
	pause_changed.emit(false)
	match_ended.emit(result.duplicate(true))
