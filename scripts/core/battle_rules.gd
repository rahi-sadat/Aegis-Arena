class_name BattleRules
extends RefCounted
## The same small numeric combat functions run the visible game and search copies.

const TICK_SECONDS := 0.05
const TICKS_PER_DECISION := 15
const EPSILON := 0.000001

static func rejection_reason(state: GameState, move: Dictionary) -> String:
	if state.winner != GameConstants.UNDECIDED or state.remaining_time <= 0:
		return "Match complete"
	if not move.has("card") or not move.has("lane") or not move.card is int or not move.lane is int:
		return "Invalid action"
	var card: int = move.card
	if card == -1:
		return "" if move.lane == -1 else "Invalid wait"
	if card < 0 or card >= CardData.NAMES.size() or move.lane < 0 or move.lane > 1:
		return "Invalid card or lane"
	var team: int = state.next_team
	if state.energy[team] + EPSILON < CardData.COSTS[card]:
		return "Not enough energy"
	if state.cooldowns[team][card] > EPSILON:
		return "Card cooling down"
	var own_count: int = 0
	var enemy_in_lane: bool = false
	for unit: Dictionary in state.units:
		if unit.team == team:
			own_count += 1
		elif unit.lane == move.lane and unit.hp > 0:
			enemy_in_lane = true
	if CardData.is_spell(card):
		return "No enemy units in that lane" if not enemy_in_lane else ""
	return "Unit limit reached" if own_count >= CardData.UNIT_CAP else ""

static func actions(state: GameState) -> Array:
	var legal: Array = []
	if state.winner != GameConstants.UNDECIDED:
		return legal
	for card in CardData.NAMES.size():
		for lane in 2:
			var move: Dictionary = CardData.action(card, lane)
			if rejection_reason(state, move).is_empty():
				legal.append(move)
	legal.append(CardData.wait_action())
	return legal

static func apply_action(state: GameState, move: Dictionary) -> bool:
	if not rejection_reason(state, move).is_empty():
		return false
	var card: int = move.card
	if card == -1:
		return true
	var team: int = state.next_team
	state.energy[team] -= CardData.COSTS[card]
	state.cooldowns[team][card] = CardData.COOLDOWNS[card]
	if CardData.is_spell(card):
		for unit: Dictionary in state.units:
			if unit.team != team and unit.lane == move.lane:
				unit.hp = maxf(0.0, unit.hp - CardData.DAMAGE[card])
		_remove_dead(state)
	else:
		state.units.append({"id": state.next_unit_id, "team": team, "card": card,
			"lane": move.lane, "progress": ArenaGrid.spawns[team][move.lane],
			"hp": CardData.HP[card], "attack_remaining": 0.0})
		state.next_unit_id += 1
	return true

static func advance_interval(state: GameState) -> void:
	for tick in TICKS_PER_DECISION:
		if state.winner != GameConstants.UNDECIDED:
			break
		advance_tick(state)

static func advance_tick(state: GameState, seconds: float = TICK_SECONDS) -> Array:
	if state.winner != GameConstants.UNDECIDED or seconds <= 0:
		return []
	var dt: float = minf(seconds, state.remaining_time)
	for team in 2:
		state.energy[team] = minf(CardData.MAX_ENERGY, state.energy[team] + CardData.ENERGY_PER_SECOND * dt)
		for card in CardData.NAMES.size():
			state.cooldowns[team][card] = maxf(0.0, state.cooldowns[team][card] - dt)
	# Decide attacks from the same living population, then apply damage together.
	var attacks: Array = []
	for index in state.units.size():
		var unit: Dictionary = state.units[index]
		unit.attack_remaining = maxf(0.0, unit.attack_remaining - dt)
		var target: Dictionary = _unit_target(state, unit)
		if target.is_empty():
			continue
		var distance: float = absf(unit.progress - target.progress)
		var reach: float = CardData.ATTACK_RANGE[unit.card]
		if distance <= reach + EPSILON:
			if unit.attack_remaining <= EPSILON:
				attacks.append({"kind": target.kind, "index": target.index, "damage": CardData.DAMAGE[unit.card], "team": unit.team,
					"from_lane": unit.lane, "from_progress": unit.progress, "to_progress": target.progress, "card": unit.card})
				unit.attack_remaining = CardData.ATTACK_INTERVAL[unit.card]
		else:
			var step: float = minf(CardData.SPEED[unit.card] * dt, distance - reach)
			unit.progress += step * signf(target.progress - unit.progress)
	for structure: Dictionary in state.structures:
		if structure.hp <= 0:
			continue
		structure.attack_remaining = maxf(0.0, structure.attack_remaining - dt)
		if structure.attack_remaining > EPSILON:
			continue
		var core: bool = structure.kind == StructureData.Kind.CORE
		var target_index: int = -1
		var nearest: float = 190.0 if core else 170.0
		for index in state.units.size():
			var enemy: Dictionary = state.units[index]
			if enemy.team == structure.team or (not core and enemy.lane != structure.lane):
				continue
			var progress: float = ArenaGrid.structure_progress(structure, enemy.lane)
			var distance: float = absf(enemy.progress - progress)
			if distance <= nearest and (distance < nearest or target_index == -1):
				nearest = distance
				target_index = index
		if target_index >= 0:
			var target: Dictionary = state.units[target_index]
			attacks.append({"kind": "unit", "index": target_index, "damage": 30.0 if core else 25.0,
				"team": structure.team, "from_lane": target.lane,
				"from_progress": ArenaGrid.structure_progress(structure, target.lane), "to_progress": target.progress, "card": -1})
			structure.attack_remaining = 1.0
	for attack: Dictionary in attacks:
		if attack.kind == "unit":
			var target: Dictionary = state.units[attack.index]
			target.hp = maxf(0.0, target.hp - attack.damage)
		else:
			damage_structure(state, attack.index, attack.damage, attack.team)
	_remove_dead(state)
	state.remaining_time = snappedf(maxf(0.0, state.remaining_time - dt), EPSILON)
	state.tick_index += 1
	check_terminal(state)
	return attacks

static func _unit_target(state: GameState, unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var nearest: float = INF
	var direction: float = 1.0 if unit.team == 0 else -1.0
	for index in state.units.size():
		var enemy: Dictionary = state.units[index]
		if enemy.team == unit.team or enemy.lane != unit.lane or enemy.hp <= 0:
			continue
		var distance: float = absf(enemy.progress - unit.progress)
		var ahead: bool = (enemy.progress - unit.progress) * direction >= 0.0
		if (ahead or distance <= CardData.ATTACK_RANGE[unit.card]) and distance < nearest:
			nearest = distance
			best = {"kind": "unit", "index": index, "progress": enemy.progress}
	for index in state.structures.size():
		var enemy: Dictionary = state.structures[index]
		if enemy.team == unit.team or enemy.hp <= 0 or (enemy.kind != StructureData.Kind.CORE and enemy.lane != unit.lane):
			continue
		var progress: float = ArenaGrid.structure_progress(enemy, unit.lane)
		var distance: float = absf(progress - unit.progress)
		if distance < nearest:
			nearest = distance
			best = {"kind": "structure", "index": index, "progress": progress}
	return best

static func damage_structure(state: GameState, index: int, amount: float, from_team: int) -> float:
	if not is_finite(amount) or amount <= 0:
		return 0.0
	var target: Dictionary = state.structures[index]
	var actual: float = minf(target.hp, amount)
	target.hp -= actual
	state.structure_damage_dealt[from_team] += actual
	return actual

static func _remove_dead(state: GameState) -> void:
	for index in range(state.units.size() - 1, -1, -1):
		if state.units[index].hp <= 0:
			state.units.remove_at(index)

static func total_hp(state: GameState) -> Array[float]:
	var totals: Array[float] = [0.0, 0.0]
	for structure: Dictionary in state.structures:
		totals[structure.team] += structure.hp
	return totals

static func check_terminal(state: GameState) -> void:
	var cores_dead: Array = [false, false]
	for structure: Dictionary in state.structures:
		if structure.kind == StructureData.Kind.CORE and structure.hp <= 0:
			cores_dead[structure.team] = true
	if cores_dead[0] or cores_dead[1]:
		state.winner = GameConstants.DRAW if cores_dead[0] and cores_dead[1] else (1 if cores_dead[0] else 0)
		state.reason = "BOTH CORES DESTROYED" if cores_dead[0] and cores_dead[1] else "CORE DESTROYED"
	elif state.remaining_time <= 0:
		state.winner = MatchRules.timeout_winner(total_hp(state), state.starting_structure_hp, state.structure_damage_dealt)
		state.reason = "TIME EXPIRED"
