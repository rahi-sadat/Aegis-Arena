class_name GameState
extends RefCounted
## Numbers only. A search child owns its own arrays and dictionaries, never Nodes.

var next_team: int = 0
var remaining_time: float = 180.0
var tick_index: int = 0
var next_unit_id: int = 1
var energy: Array[float] = [10.0, 10.0]
var cooldowns: Array = [[0.0, 0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0, 0.0]]
var structures: Array = []
var units: Array = []
var starting_structure_hp: Array[float] = [1800.0, 1800.0]
var structure_damage_dealt: Array[float] = [0.0, 0.0]
var winner: int = GameConstants.UNDECIDED
var reason: String = ""

static func create_default(duration: float = 180.0) -> GameState:
	ArenaGrid.setup()
	var state := GameState.new()
	state.remaining_time = duration
	for team in 2:
		for slot in 3:
			var core: bool = slot == 2
			var hp: float = 800.0 if core else 500.0
			var suffix: String = "core" if core else ("left_guard" if slot == 0 else "right_guard")
			state.structures.append({"id": ("blue_" if team == 0 else "red_") + suffix,
				"team": team, "kind": StructureData.Kind.CORE if core else StructureData.Kind.GUARD,
				"lane": -1 if core else slot, "hp": hp, "max_hp": hp, "attack_remaining": 0.0})
	return state

func copy_state() -> GameState:
	var child := GameState.new()
	child.next_team = next_team
	child.remaining_time = remaining_time
	child.tick_index = tick_index
	child.next_unit_id = next_unit_id
	child.energy = energy.duplicate()
	child.cooldowns = cooldowns.duplicate(true)
	child.structures = structures.duplicate(true)
	child.units = units.duplicate(true)
	child.starting_structure_hp = starting_structure_hp.duplicate()
	child.structure_damage_dealt = structure_damage_dealt.duplicate()
	child.winner = winner
	child.reason = reason
	return child

func to_dictionary() -> Dictionary:
	return {"next_team": next_team, "remaining_time": remaining_time, "tick_index": tick_index,
		"next_unit_id": next_unit_id, "energy": energy.duplicate(), "cooldowns": cooldowns.duplicate(true),
		"structures": structures.duplicate(true), "units": units.duplicate(true),
		"starting_structure_hp": starting_structure_hp.duplicate(),
		"structure_damage_dealt": structure_damage_dealt.duplicate(), "winner": winner, "reason": reason}

static func from_dictionary(data: Dictionary) -> GameState:
	var state := GameState.new()
	for key: String in data:
		if data[key] is Array:
			var target: Array = state.get(key)
			target.assign(data[key].duplicate(true))
		else:
			state.set(key, data[key])
	# JSON numbers are floats. Restore the integer fields used as array indices.
	for structure: Dictionary in state.structures:
		for key: String in ["team", "kind", "lane"]:
			structure[key] = int(structure[key])
	for unit: Dictionary in state.units:
		for key: String in ["id", "team", "card", "lane"]:
			unit[key] = int(unit[key])
	return state
