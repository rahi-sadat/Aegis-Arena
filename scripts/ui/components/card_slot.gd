class_name BattleCardSlot
extends TextureButton

signal inspected(index: int)

@export var illustration: Texture2D

var _index: int
var _accent: Color
var _shade: ColorRect
var _trim: ArenaTrim
var _halo: Panel
var _animation: Tween
var _is_selected: bool = false

func build(index: int, artwork: Texture2D) -> void:
	_index = index
	_accent = DeckArt.ACCENTS[index]
	texture_normal = artwork if artwork != null else illustration
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_halo = Panel.new()
	_halo.mouse_filter = MOUSE_FILTER_IGNORE
	_halo.show_behind_parent = true
	var glow := ArenaStyle.box(Color.TRANSPARENT, ArenaStyle.GOLD, 3, 7)
	glow.shadow_color = Color(ArenaStyle.GOLD, 0.62)
	glow.shadow_size = 8
	_halo.add_theme_stylebox_override("panel", glow)
	ArenaStyle.mount(self, _halo, Rect2(-2, -2, size.x + 4, size.y + 4))
	_shade = ArenaStyle.veil(self, Color(0.020, 0.027, 0.043, 0.33))
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	var name_plate := Panel.new()
	name_plate.mouse_filter = MOUSE_FILTER_IGNORE
	name_plate.add_theme_stylebox_override("panel", ArenaStyle.box(Color(0.027, 0.042, 0.064, 0.93), _accent.darkened(0.45), 1, 4))
	ArenaStyle.mount(self, name_plate, Rect2(4, size.y - 32, size.x - 8, 28))
	ArenaStyle.text(name_plate, Rect2(0, 0, name_plate.size.x, 28), DeckArt.NAMES[index], 16, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	var cost_plate := Panel.new()
	cost_plate.mouse_filter = MOUSE_FILTER_IGNORE
	cost_plate.add_theme_stylebox_override("panel", ArenaStyle.box(Color("#281944"), _accent, 1, 9))
	ArenaStyle.mount(self, cost_plate, Rect2(7, 7, 28, 28))
	ArenaStyle.text(cost_plate, Rect2(0, 0, 28, 28), DeckArt.cost_label(index), 16, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_trim = ArenaTrim.new()
	_trim.tint = _accent
	add_child(_trim)
	_trim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pressed.connect(func() -> void: inspected.emit(_index))
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	button_down.connect(_hover.bind(false))
	button_up.connect(func() -> void: _hover(is_hovered()))
	focus_entered.connect(_refresh_trim)
	focus_exited.connect(_refresh_trim)
	set_interaction(false)
	_refresh_trim()

func set_interaction(enabled: bool) -> void:
	disabled = not enabled
	_shade.visible = not enabled
	var planned := " • Planned for Phase 2" if DeckArt.COSTS[_index] >= 0 else " • Concept card"
	tooltip_text = DeckArt.NAMES[_index] + (" • Preview artwork" if enabled else planned)
	_hover(false)

func show_selected(selected: bool) -> void:
	_is_selected = selected
	_refresh_trim()

func _refresh_trim() -> void:
	_halo.visible = _is_selected or has_focus()
	_trim.tint = ArenaStyle.GOLD if _halo.visible else _accent

func _hover(active: bool) -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	var lift := 1.045 if active and not disabled else 1.0
	pivot_offset = size * 0.5
	if UISettings.reduce_motion:
		scale = Vector2.ONE
		return
	_animation = create_tween()
	_animation.tween_property(self, "scale", Vector2.ONE * lift, 0.13)
