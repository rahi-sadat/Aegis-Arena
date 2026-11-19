class_name CardData
extends RefCounted
## The five card definitions. Gameplay and the card artwork read these same values.

enum Card { FIGHTER, RANGER, TANK, MAGE, ARROW }

const NAMES := ["Fighter", "Ranger", "Tank", "Mage", "Arrow"]
const COSTS := [3, 4, 5, 6, 3]
const COOLDOWNS := [4.0, 5.0, 8.0, 9.0, 4.0]
const HP := [120.0, 90.0, 240.0, 0.0, 0.0]
const DAMAGE := [20.0, 15.0, 18.0, 80.0, 45.0]
const ATTACK_INTERVAL := [0.75, 0.9, 1.0, 0.0, 0.0]
const SPEED := [90.0, 70.0, 45.0, 0.0, 0.0]
const ATTACK_RANGE := [28.0, 130.0, 28.0, 0.0, 0.0]
const MAX_ENERGY := 10.0
const START_ENERGY := 10.0
const ENERGY_PER_SECOND := 1.0
const UNIT_CAP := 8

static func is_spell(card: int) -> bool:
	return card == Card.MAGE or card == Card.ARROW

static func action(card: int, lane: int) -> Dictionary:
	return {"card": card, "lane": lane}

static func wait_action() -> Dictionary:
	return action(-1, -1)

static func action_name(move: Dictionary) -> String:
	var card: int = move.get("card", -1)
	if card < 0:
		return "Wait"
	return "%s %s" % [NAMES[card], "Left" if move.lane == 0 else "Right"]
