class_name BattleEvaluation
extends RefCounted
## A positive score favors the root commander, even at the opponent's nodes.

static func breakdown(state: GameState, root_team: int, weights: Dictionary) -> Dictionary:
	var hp: Array[float] = BattleRules.total_hp(state)
	var unit_hp: Array[float] = [0.0, 0.0]
	var pressure: Array[float] = [0.0, 0.0]
	for unit: Dictionary in state.units:
		unit_hp[unit.team] += unit.hp
		var forward: float = clampf(unit.progress / ArenaGrid.lengths[unit.lane], 0.0, 1.0)
		if unit.team == 1:
			forward = 1.0 - forward
		pressure[unit.team] += (unit.hp / CardData.HP[unit.card]) * forward / CardData.UNIT_CAP
	var other: int = GameConstants.opponent(root_team)
	var features: Dictionary = {
		"T": MatchRules.remaining_fraction(hp[root_team], state.starting_structure_hp[root_team]) - MatchRules.remaining_fraction(hp[other], state.starting_structure_hp[other]),
		"U": clampf(unit_hp[root_team] / 1000.0, 0, 1) - clampf(unit_hp[other] / 1000.0, 0, 1),
		"E": (state.energy[root_team] - state.energy[other]) / CardData.MAX_ENERGY,
		"P": pressure[root_team] - pressure[other]}
	var contributions: Dictionary = {}
	var score: float = 0.0
	for key: String in features:
		contributions[key] = features[key] * weights[key]
		score += contributions[key]
	var terminal: bool = state.winner != GameConstants.UNDECIDED
	if terminal:
		score = 0.0 if state.winner == GameConstants.DRAW else (10000.0 if state.winner == root_team else -10000.0)
	return {"features": features, "contributions": contributions, "score": score, "terminal": terminal}
