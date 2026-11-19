class_name TacticalFuzzy
extends RefCounted
## Nine explicit zero-order Sugeno rules, grouped into three readable priorities.

static func membership(value: float) -> Dictionary:
	var x: float = clampf(value, 0.0, 1.0)
	return {"low": maxf(0.0, 1.0 - 2.0 * x),
		"medium": maxf(0.0, 1.0 - absf(2.0 * x - 1.0)), "high": maxf(0.0, 2.0 * x - 1.0)}

static func weighted_output(degrees: Dictionary, low: float, medium: float, high: float) -> float:
	var total: float = degrees.low + degrees.medium + degrees.high
	return (degrees.low * low + degrees.medium * medium + degrees.high * high) / total if total > 0 else 0.0

static func from_inputs(threat: float, opportunity: float, reserve: float) -> Dictionary:
	var degrees: Dictionary = {"threat": membership(threat), "opportunity": membership(opportunity), "energy": membership(reserve)}
	var outputs: Dictionary = {
		"attack": weighted_output(degrees.opportunity, 0.0, 0.5, 1.0),
		"defend": weighted_output(degrees.threat, 0.0, 0.5, 1.0),
		"save": weighted_output(degrees.energy, 1.0, 0.5, 0.0)}
	return {"inputs": {"threat": clampf(threat, 0, 1), "opportunity": clampf(opportunity, 0, 1), "energy": clampf(reserve, 0, 1)},
		"memberships": degrees, "outputs": outputs,
		"rules": {"attack": [0.0, 0.5, 1.0], "defend": [0.0, 0.5, 1.0], "save": [1.0, 0.5, 0.0]},
		"weights": {"T": 100.0, "U": 20.0 + 10.0 * outputs.defend,
			"E": 2.0 + 4.0 * outputs.save, "P": 10.0 + 10.0 * outputs.attack}}

static func assess(state: GameState, team: int) -> Dictionary:
	var enemy_hp_nearby: float = 0.0
	for unit: Dictionary in state.units:
		var inside_our_half: bool = unit.progress < ArenaGrid.lengths[unit.lane] * 0.5 if team == 0 else unit.progress >= ArenaGrid.lengths[unit.lane] * 0.5
		if unit.team != team and inside_our_half:
			enemy_hp_nearby += unit.hp
	var opportunity: float = 0.0
	for structure: Dictionary in state.structures:
		if structure.team != team and structure.hp > 0:
			opportunity = maxf(opportunity, 1.0 - structure.hp / structure.max_hp)
	return from_inputs(enemy_hp_nearby / 400.0, opportunity, state.energy[team] / CardData.MAX_ENERGY)
