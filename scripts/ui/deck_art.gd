class_name DeckArt
extends RefCounted

const NAMES := ["Fighter", "Ranger", "Tank", "Mage", "Arrow"]
const COSTS := [3, 4, 5, -1, -1]
const ACCENTS := [Color("#79c8fa"), Color("#8ad7a4"), Color("#edc783"), Color("#bb90ff"), Color("#f59376")]
const CARDS := [
	preload("res://assets/ui/cards/fighter.webp"),
	preload("res://assets/ui/cards/ranger.webp"),
	preload("res://assets/ui/cards/tank.webp"),
	preload("res://assets/ui/cards/mage.webp"),
	preload("res://assets/ui/cards/arrow.webp"),
]
const BACK := preload("res://assets/ui/cards/card_back.webp")
const BLUE_PORTRAIT := preload("res://assets/ui/portraits/blue.webp")
const RED_PORTRAIT := preload("res://assets/ui/portraits/red.webp")

static func cost_label(index: int) -> String:
	var cost: int = COSTS[index]
	return str(cost) if cost >= 0 else "—"
