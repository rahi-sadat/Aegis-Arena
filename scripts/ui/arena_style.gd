class_name ArenaStyle
extends RefCounted
## Shared typography, ornament, and interaction states for the arena UI.

const GOLD := Color("#c8b58c")
const INK := Color("#10161d")
const TEXT := Color("#e9edf0")
const MUTED := Color("#96a3af")
const OUTLINE := Color("#060a12")
const GLASS := Color(0.045, 0.060, 0.077, 0.96)
const EDGE_BLUE := Color("#789cb8")
const LINE := Color("#3b4855")
const VIOLET := Color("#9bafcc")

static var _serif: SystemFont

static func display_font() -> SystemFont:
	if _serif == null:
		_serif = SystemFont.new()
		# Clean bold sans, matching the battle-view HUD in the design video.
		_serif.font_names = PackedStringArray(["Segoe UI Variable Text", "Segoe UI", "Helvetica Neue", "Arial", "sans-serif"])
		_serif.font_weight = 600
	return _serif

static func box(fill: Color, edge: Color, width: int = 1, radius: int = 4) -> StyleBoxFlat:
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
	var style := box(GLASS, Color(accent, 0.24), 1, 5)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0, 2)
	surface.add_theme_stylebox_override("panel", style)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		line.add_theme_color_override("font_outline_color", OUTLINE)
		line.add_theme_constant_override("outline_size", 0)
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
	# Quiet colour/focus feedback replaces elastic button scaling.
	control.scale = Vector2.ONE

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
	control.add_theme_font_size_override("font_size", 18)
	var ink := Color("#241606") if primary else TEXT
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		control.add_theme_color_override(state, ink)
	control.add_theme_color_override("font_disabled_color", Color("#7f8899"))
	if primary:
		control.add_theme_stylebox_override("normal", glass(Color("#bca982"), Color("#cbb996")))
		control.add_theme_stylebox_override("hover", glass(Color("#cdbb98"), Color("#e1d2b5")))
		control.add_theme_stylebox_override("pressed", glass(Color("#a18d67"), Color("#cbb996")))
	else:
		control.add_theme_stylebox_override("normal", glass(Color("#18222d"), Color("#394957")))
		control.add_theme_stylebox_override("hover", glass(Color("#243443"), Color(EDGE_BLUE, 0.8)))
		control.add_theme_stylebox_override("pressed", glass(Color("#101820"), EDGE_BLUE))
	control.add_theme_stylebox_override("disabled", glass(Color(0.08, 0.1, 0.15, 0.85), Color(1, 1, 1, 0.1)))
	var focus := box(Color.TRANSPARENT, EDGE_BLUE, 1, 4)
	focus.set_expand_margin_all(2)
	control.add_theme_stylebox_override("focus", focus)

## Dark-glass button face with a thin luminous edge and an optional outer glow.
static func glass(fill: Color, edge: Color, glow: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := box(fill, edge, 1, 4)
	style.shadow_size = 0
	return style

## Makes a toggle button read as "chosen" when pressed: team-coloured glow and edge.
static func selectable(control: Button, accent: Color = GOLD) -> void:
	control.toggle_mode = true
	control.add_theme_color_override("font_color", TEXT)
	control.add_theme_color_override("font_hover_color", TEXT)
	control.add_theme_stylebox_override("normal", glass(Color("#131c2c"), Color(1, 1, 1, 0.14)))
	control.add_theme_stylebox_override("hover", glass(Color("#1a2638"), Color(accent, 0.7)))
	var chosen := glass(Color("#2a3b4b"), Color(accent, 0.8))
	chosen.set_border_width_all(1)
	control.add_theme_stylebox_override("pressed", chosen)
	control.add_theme_stylebox_override("hover_pressed", chosen)
	control.add_theme_color_override("font_pressed_color", Color.WHITE)
	control.add_theme_color_override("font_hover_pressed_color", Color.WHITE)

static func bar(accent: Color) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.max_value = 1.0
	meter.step = 0.0
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.add_theme_stylebox_override("background", box(Color("#070c12"), Color.TRANSPARENT, 0, 1))
	meter.add_theme_stylebox_override("fill", box(accent, Color.TRANSPARENT, 0, 1))
	return meter

static func art(parent: Node, rect: Rect2, texture: Texture2D) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	# Artwork is drawn far below its source size; mipmaps keep it smooth. This is set
	# per image, not project-wide, because font glyph atlases have no mipmaps.
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	if is_equal_approx(float(meter.get_meta("fill_target", -1.0)), value) and (not immediate or is_equal_approx(meter.value, value)):
		return
	meter.set_meta("fill_target", value)
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
