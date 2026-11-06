class_name GameManager
extends Node
## Coordinates match lifetime, timer, structure events, and terminal results.

signal match_started
signal match_ended(result: Dictionary)
signal timer_changed(remaining_seconds: float)
signal structure_health_changed(structure: ArenaStructure)
signal pause_changed(paused: bool)

@export var balance: GameBalance = preload("res://data/balance/game_balance.tres")

var structures: Array[ArenaStructure] = []
var remaining_match_time: float = 0.0
var is_running: bool = false
var is_paused: bool = false
var winner: int = GameConstants.UNDECIDED
var result: Dictionary = {}
var structure_damage_dealt: Array[float] = [0.0, 0.0]
var starting_structure_hp: Array[float] = [0.0, 0.0]

func start_match(match_structures: Array[ArenaStructure]) -> void:
	is_running = false
	# Disconnect prior participants if this manager is reused with a new arena.
	for structure in structures:
		if structure.damaged.is_connected(_on_structure_damaged):
			structure.damaged.disconnect(_on_structure_damaged)
		if structure.destroyed.is_connected(_on_structure_destroyed):
			structure.destroyed.disconnect(_on_structure_destroyed)
	structures = match_structures.duplicate()
	structure_damage_dealt = [0.0, 0.0]
	starting_structure_hp = [0.0, 0.0]
	for structure in structures:
		structure.reset_health()
		starting_structure_hp[structure.team_id] += structure.max_hp
		structure.damaged.connect(_on_structure_damaged)
		structure.destroyed.connect(_on_structure_destroyed)
	remaining_match_time = balance.match_duration_seconds
	winner = GameConstants.UNDECIDED
	result = {}
	is_paused = false
	is_running = true
	pause_changed.emit(false)
	match_started.emit()
	timer_changed.emit(remaining_match_time)

func _process(delta: float) -> void:
	if not is_running or is_paused:
		return
	remaining_match_time = maxf(0.0, remaining_match_time - delta)
	timer_changed.emit(remaining_match_time)
	if remaining_match_time <= 0.0:
		var timeout_result: int = MatchRules.timeout_winner(total_remaining_hp(), starting_structure_hp, structure_damage_dealt)
		_finish_match(timeout_result, "TIME EXPIRED")

func toggle_pause() -> void:
	if not is_running:
		return
	is_paused = not is_paused
	pause_changed.emit(is_paused)

func damage_structure(structure_id: StringName, amount: float) -> float:
	# All current external damage requests enter here; paused/finished matches are inert.
	if not is_running or is_paused:
		return 0.0
	for structure in structures:
		if structure.structure_id == structure_id:
			return structure.take_damage(amount)
	return 0.0

func total_remaining_hp() -> Array[float]:
	var totals: Array[float] = [0.0, 0.0]
	for structure in structures:
		totals[structure.team_id] += structure.current_hp
	return totals

func _on_structure_damaged(structure: ArenaStructure, actual_damage: float) -> void:
	if not is_running:
		return
	structure_damage_dealt[GameConstants.opponent(structure.team_id)] += actual_damage
	structure_health_changed.emit(structure)

func _on_structure_destroyed(structure: ArenaStructure) -> void:
	if is_running and structure.data.structure_type == StructureData.Kind.CORE:
		_finish_match(GameConstants.opponent(structure.team_id), "CORE DESTROYED")

func _finish_match(winning_team: int, reason: String) -> void:
	if not is_running:
		return
	is_running = false
	is_paused = false
	winner = winning_team
	var hp: Array[float] = total_remaining_hp()
	result = {
		"winner": winner,
		"reason": reason,
		"elapsed_seconds": balance.match_duration_seconds - remaining_match_time,
		"remaining_hp": hp,
		"remaining_fraction": [MatchRules.remaining_fraction(hp[0], starting_structure_hp[0]), MatchRules.remaining_fraction(hp[1], starting_structure_hp[1])],
		"damage_dealt": structure_damage_dealt.duplicate(),
	}
	pause_changed.emit(false)
	match_ended.emit(result.duplicate(true))
