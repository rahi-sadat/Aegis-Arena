class_name BattleEnergyBar
extends Control

var _amount: Label
var _regen: Label
var _bar: ProgressBar

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.icon(self, Rect2(1, 5, 21, 22), ArenaIcon.Kind.CRYSTAL, ArenaStyle.VIOLET)
	_amount = ArenaStyle.text(self, Rect2(28, 0, 175, 32), "", 17, ArenaStyle.TEXT, true)
	_bar = ArenaStyle.bar(ArenaStyle.VIOLET)
	ArenaStyle.mount(self, _bar, Rect2(210, 11, 402, 12))
	_regen = ArenaStyle.text(self, Rect2(625, 0, 160, 32), "", 16, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	set_preview(false)

func set_preview(enabled: bool) -> void:
	_amount.text = "ENERGY   7 / 10" if enabled else "ENERGY LOCKED"
	_regen.text = "+1 / s · sample" if enabled else "Phase 2"
	ArenaStyle.fill_bar(_bar, 0.7 if enabled else 0.0, not enabled)
