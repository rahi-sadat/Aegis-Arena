class_name ArenaStyle
extends RefCounted
## Shared typography, ornament, and interaction states for the arena UI.

const GOLD := Color("#ebc583")
const INK := Color("#0c1627")
const TEXT := Color("#f9efdc")
const MUTED := Color("#aebdce")
const LINE := Color("#8c673c")
const VIOLET := Color("#b88aff")

static var _serif: SystemFont

static func display_font() -> SystemFont:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Cinzel", "Georgia", "DejaVu Serif", "serif"])
		_serif.font_weight = 700
	return _serif

static func box(fill: Color, edge: Color, width: int = 1, radius: int = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

static func panel(parent: Node, rect: Rect2, accent: Color = GOLD) -> Panel:
	var surface := Panel.new()
	mount(parent, surface, rect)
	decorate(surface, accent)
	return surface

static func decorate(surface: Panel, accent: Color = GOLD) -> void:
	var style := box(Color(0.039, 0.066, 0.108, 0.95), accent.darkened(0.48), 2, 9)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.54)
	style.shadow_size = 8
	surface.add_theme_stylebox_override("panel", style)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var trim := ArenaTrim.new()
	trim.tint = accent
	surface.add_child(trim)
	trim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func mount(parent: Node, control: Control, rect: Rect2) -> void:
	parent.add_child(control)
	control.position = rect.position
	control.size = rect.size

static func label(value: String, font_size: int, color: Color = TEXT, serif: bool = false) -> Label:
	var line := Label.new()
	line.text = value
	line.add_theme_font_size_override("font_size", font_size)
	line.add_theme_color_override("font_color", color)
	if serif:
		line.add_theme_font_override("font", display_font())
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

static func text(parent: Node, rect: Rect2, value: String, font_size: int, color: Color = TEXT, serif: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var line := label(value, font_size, color, serif)
	line.horizontal_alignment = align
	mount(parent, line, rect)
	return line

static func button(value: String, primary: bool = false) -> Button:
	var control := Button.new()
	format_button(control, value, primary)
	control.mouse_entered.connect(_button_motion.bind(control, 1.018))
	control.mouse_exited.connect(_button_motion.bind(control, 1.0))
	control.button_down.connect(_button_motion.bind(control, 0.974))
	control.button_up.connect(_button_motion.bind(control, 1.0))
	return control

static func _button_motion(control: Button, target: float) -> void:
	if control.has_meta(&"motion_tween"):
		var prior: Tween = control.get_meta(&"motion_tween")
		if prior.is_valid():
			prior.kill()
	if UISettings.reduce_motion or control.disabled:
		control.scale = Vector2.ONE
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE * target, 0.11)
	control.set_meta(&"motion_tween", tween)

static func cycle_focus(controls: Array[Control]) -> void:
	for index in controls.size():
		var current := controls[index]
		var next := controls[(index + 1) % controls.size()]
		var previous := controls[posmod(index - 1, controls.size())]
		current.focus_next = current.get_path_to(next)
		current.focus_previous = current.get_path_to(previous)
		current.focus_neighbor_bottom = current.focus_next
		current.focus_neighbor_top = current.focus_previous

static func icon(parent: Node, rect: Rect2, kind: ArenaIcon.Kind, tint: Color) -> void:
	var symbol := ArenaIcon.new()
	symbol.kind = kind
	symbol.tint = tint
	mount(parent, symbol, rect)

static func format_button(control: Button, value: String, primary: bool = false) -> void:
	control.text = value
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	control.add_theme_font_override("font", display_font())
	control.add_theme_font_size_override("font_size", 19)
	control.add_theme_color_override("font_color", Color("#20150f") if primary else TEXT)
	control.add_theme_color_override("font_hover_color", Color("#20150f") if primary else GOLD)
	control.add_theme_color_override("font_pressed_color", Color("#20150f") if primary else GOLD)
	control.add_theme_color_override("font_focus_color", Color("#20150f") if primary else GOLD)
	control.add_theme_color_override("font_disabled_color", MUTED)
	control.add_theme_stylebox_override("normal", box(Color("#d6a855") if primary else Color("#16263c"), GOLD if primary else LINE, 2))
	control.add_theme_stylebox_override("hover", box(Color("#f3ce83") if primary else Color("#253955"), GOLD, 2))
	control.add_theme_stylebox_override("pressed", box(Color("#bd833b") if primary else Color("#111b2e"), GOLD, 2))
	control.add_theme_stylebox_override("disabled", box(Color("#142033"), Color("#435065"), 1))
	var focus := box(Color.TRANSPARENT, Color("#ffdf99"), 2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	control.add_theme_stylebox_override("focus", focus)

static func bar(accent: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = 1.0
	meter.step = 0.0
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", box(Color("#080e1a"), Color("#584737"), 1, 4))
	meter.add_theme_stylebox_override("fill", box(accent.darkened(0.13), accent.lightened(0.22), 1, 4))
	return meter

static func art(parent: Node, rect: Rect2, texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mount(parent, picture, rect)
	return picture

static func veil(parent: Node, color: Color) -> ColorRect:
	var shade := ColorRect.new()
	shade.color = color
	parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return shade

static func enter(control: Control) -> void:
	if control.has_meta(&"enter_tween"):
		var prior: Tween = control.get_meta(&"enter_tween")
		if prior.is_valid():
			prior.kill()
	if UISettings.reduce_motion:
		control.modulate.a = 1.0
		return
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.tween_property(control, "modulate:a", 1.0, 0.2)
	control.set_meta(&"enter_tween", tween)

static func fill_bar(meter: Range, value: float, immediate: bool = false) -> void:
	if meter.has_meta(&"fill_tween"):
		var active: Tween = meter.get_meta(&"fill_tween")
		if active.is_valid():
			active.kill()
	if immediate or UISettings.reduce_motion:
		meter.value = value
		return
	var tween := meter.create_tween()
	tween.tween_property(meter, "value", value, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	meter.set_meta(&"fill_tween", tween)
