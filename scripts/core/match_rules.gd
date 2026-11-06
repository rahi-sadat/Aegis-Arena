class_name MatchRules
extends RefCounted
## Pure numeric victory rules, independent of scenes and HUD controls.

static func remaining_fraction(hp: float, starting_hp: float) -> float:
	return clampf(hp / starting_hp, 0.0, 1.0) if starting_hp > 0.0 else 0.0

static func timeout_winner(hp: Array[float], starting_hp: Array[float], damage_dealt: Array[float]) -> int:
	# Use the percentage of combined starting structure HP, not tower-count averages.
	var blue_fraction: float = remaining_fraction(hp[0], starting_hp[0])
	var red_fraction: float = remaining_fraction(hp[1], starting_hp[1])
	if blue_fraction > red_fraction:
		return GameConstants.Team.BLUE
	if red_fraction > blue_fraction:
		return GameConstants.Team.RED
	if damage_dealt[0] > damage_dealt[1]:
		return GameConstants.Team.BLUE
	if damage_dealt[1] > damage_dealt[0]:
		return GameConstants.Team.RED
	return GameConstants.DRAW
