class_name BattleCardSlot
extends TextureButton
## A restrained card frame, matching troop portrait, and transparent radial cooldown.

signal inspected(index: int)
@export var illustration: Texture2D

var _index: int
var _accent: Color
var _shade: ColorRect
var _halo: Panel
var _cooldown: Label
var _radial: Control
var _remaining: float = 0.0
var _display_remaining: float = 0.0
var _is_selected: bool = false
var _hovered: bool = false

func build(index: int, artwork: Texture2D) -> void:
	_index = index
	_accent = [Color("#8caabd"), Color("#93a991"), Color("#bba57f"), Color("#b9806f"), Color("#8facc0")][index]
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#25313d"), Color("#111922")])
	var background := GradientTexture2D.new()
	background.gradient = gradient
	background.fill_from = Vector2.ZERO
	background.fill_to = Vector2(0, 1)
	texture_normal = background
	ignore_texture_size = true
	stretch_mode = STRETCH_SCALE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_halo = Panel.new()
	_halo.mouse_filter = MOUSE_FILTER_IGNORE
	_halo.show_behind_parent = true
	_halo.add_theme_stylebox_override("panel", ArenaStyle.box(Color.TRANSPARENT, Color("#b5cbd8"), 2, 4))
	ArenaStyle.mount(self, _halo, Rect2(Vector2(-2, -2), size + Vector2(4, 4)))
	var picture: Texture2D
	if index < 3:
		picture = TroopArt.portrait(index)
	else:
		var crop := AtlasTexture.new()
		crop.atlas = artwork if artwork != null else illustration
		var extent: Vector2 = crop.atlas.get_size()
		crop.region = Rect2(extent * Vector2(0.11, 0.09), extent * Vector2(0.78, 0.52))
		picture = crop
	var large: bool = size.x >= 130
	var art := ArenaStyle.art(self, Rect2(5, 4, size.x - 10, size.y - (56 if large else 44)), picture)
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if index < 3 else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_shade = ColorRect.new()
	_shade.color = Color(0.015, 0.02, 0.025, 0.52)
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.mount(self, _shade, Rect2(Vector2.ZERO, size))
	var cost := ArenaStyle.panel(self, Rect2(6, 7, 25, 25), Color("#8da5bc"))
	ArenaStyle.text(cost, Rect2(0, 0, 25, 25), str(CardData.COSTS[index]), 16, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(self, Rect2(size.x - 25, 8, 19, 18), str(index + 1), 11, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(self, Rect2(3, size.y - (47 if large else 39), size.x - 6, 28 if large else 21), CardData.NAMES[index], 19 if large else 14, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(self, Rect2(3, size.y - 17, size.x - 6, 12), ["MELEE", "ARCHER", "GOLEM", "FIRE SPELL", "ARROW SPELL"][index], 11 if large else 9, _accent, false, HORIZONTAL_ALIGNMENT_CENTER)
	_radial = Control.new()
	_radial.mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.mount(self, _radial, Rect2(Vector2.ZERO, size))
	_radial.draw.connect(_draw_cooldown)
	_cooldown = ArenaStyle.text(self, Rect2(0, size.y * 0.36 - 12, size.x, 25), "", 16, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	pressed.connect(func() -> void: inspected.emit(_index))
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	focus_entered.connect(_refresh_halo)
	focus_exited.connect(_refresh_halo)
	set_interaction(false)
	_refresh_halo()

func set_interaction(enabled: bool) -> void:
	disabled = not enabled
	_shade.visible = not enabled
	tooltip_text = "%s / %d energy / %.0f s cooldown" % [CardData.NAMES[_index], CardData.COSTS[_index], CardData.COOLDOWNS[_index]]
	_refresh_halo()

func set_display_only() -> void:
	# The setup screen shows full artwork without suggesting a deployment action.
	disabled = true
	_shade.hide()
	_halo.hide()
	mouse_default_cursor_shape = CURSOR_ARROW

func set_live(ready: bool, remaining: float, explanation: String) -> void:
	if disabled == ready:
		set_interaction(ready)
	if remaining > _display_remaining + 0.3:
		_display_remaining = remaining
	_remaining = remaining
	_cooldown.text = "%.1f" % remaining if remaining > BattleRules.EPSILON else ""
	_cooldown.visible = remaining > BattleRules.EPSILON
	_radial.visible = remaining > BattleRules.EPSILON
	tooltip_text = "%s / %d energy\n%s" % [CardData.NAMES[_index], CardData.COSTS[_index], explanation]
	_radial.queue_redraw()

func _process(delta: float) -> void:
	if _radial != null and _remaining > 0 and not is_equal_approx(_display_remaining, _remaining):
		_display_remaining = move_toward(_display_remaining, _remaining, delta * 2)
		_radial.queue_redraw()

func _draw_cooldown() -> void:
	if _remaining <= BattleRules.EPSILON:
		return
	var center := Vector2(size.x * 0.5, size.y * 0.36)
	var radius: float = minf(25, size.x * 0.23)
	var completed: float = 1.0 - clampf(_display_remaining / CardData.COOLDOWNS[_index], 0, 1)
	_radial.draw_circle(center, radius + 3, Color(0.02, 0.03, 0.04, 0.66), true, -1, true)
	_radial.draw_arc(center, radius, 0, TAU, 64, Color(0.85, 0.91, 0.96, 0.16), 2, true)
	_radial.draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * maxf(0.01, completed), 64, Color(0.85, 0.93, 1, 0.86), 2.5, true)

func show_selected(selected: bool) -> void:
	_is_selected = selected
	_refresh_halo()

func _refresh_halo() -> void:
	if _halo != null:
		_halo.visible = _is_selected or has_focus() or (_hovered and not disabled)

func _hover(active: bool) -> void:
	_hovered = active
	_refresh_halo()
