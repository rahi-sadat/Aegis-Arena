class_name BattleEnergyBar
extends Control
## Ten-segment energy gauge under the command deck.

const SEGMENTS := 10
const TRACK := Rect2(210, 7, 402, 18)
const FILL := Color("#c03fe0")
const FILL_EDGE := Color("#f0a8ff")

var _amount: Label
var _regen: Label
var _value: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.icon(self, Rect2(1, 5, 21, 22), ArenaIcon.Kind.CRYSTAL, ArenaStyle.VIOLET)
	_amount = ArenaStyle.text(self, Rect2(28, 0, 175, 32), "", 17, ArenaStyle.TEXT, true)
	_regen = ArenaStyle.text(self, Rect2(625, 0, 160, 32), "", 16, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	set_preview(false)

## `value` is energy in 0..SEGMENTS; partial segments fill proportionally.
func set_energy(value: float) -> void:
	_value = clampf(value, 0.0, SEGMENTS)
	_amount.text = "ENERGY   %.1f / 10" % _value
	_regen.text = "+1 / s"
	queue_redraw()

func set_preview(enabled: bool) -> void:
	set_energy(7.0 if enabled else 0.0)
	_amount.text = "ENERGY   7 / 10" if enabled else "ENERGY LOCKED"
	_regen.text = "+1 / s · sample" if enabled else "Phase 2"

func _draw() -> void:
	draw_rect(TRACK.grow(3), Color("#2a1a3a"))
	draw_rect(TRACK.grow(3), Color("#8c673c"), false, 1.0)
	var gap := 3.0
	var width := (TRACK.size.x - gap * (SEGMENTS - 1)) / SEGMENTS
	for index in SEGMENTS:
		var cell := Rect2(TRACK.position.x + index * (width + gap), TRACK.position.y, width, TRACK.size.y)
		draw_rect(cell, Color("#140b20"))
		var fraction := clampf(_value - index, 0.0, 1.0)
		if fraction <= 0.0:
			continue
		var filled := Rect2(cell.position, Vector2(cell.size.x * fraction, cell.size.y))
		draw_rect(filled, FILL)
		draw_rect(Rect2(filled.position, Vector2(filled.size.x, 5)), FILL_EDGE)
