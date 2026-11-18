class_name DeckArt
extends RefCounted
## Card artwork and the design values shown for the five-card deck.

const NAMES := ["Fighter", "Ranger", "Tank", "Mage", "Arrow"]
const COSTS := [3, 4, 5, 6, 3]
const COOLDOWNS := [4, 5, 8, 9, 4]
const ROLES := ["Fast front line", "Ranged damage", "High durability", "Spell burst", "Quick support"]
## Matches each card's gem colour: sapphire, emerald, amber, ruby, ice.
const ACCENTS := [Color("#5aa8ff"), Color("#4fd18b"), Color("#f2b04a"), Color("#ff5f6b"), Color("#5fe3f0")]
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
const LOGO := preload("res://assets/ui/logo.webp")
## Card art is 3:4; slots keep this ratio so the painted frame is never cropped.
const CARD_ASPECT := 0.75

static func cost_label(index: int) -> String:
	return str(COSTS[index])

static func summary(index: int) -> String:
	return "Cost %d  •  %s" % [COSTS[index], ROLES[index]]
