class_name BattleCardSlot
extends TextureButton
## A deck card. The artwork already carries its frame, cost orb, and name plate.

signal inspected(index: int)

@export var illustration: Texture2D

var _index: int
var _accent: Color
var _shade: ColorRect
var _halo: Panel
var _animation: Tween
var _is_selected: bool = false
var _cooldown: Label

func build(index: int, artwork: Texture2D) -> void:
	_index = index
	_accent = DeckArt.ACCENTS[index]
	texture_normal = artwork if artwork != null else illustration
	texture_filter = TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ignore_texture_size = true
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_halo = Panel.new()
	_halo.mouse_filter = MOUSE_FILTER_IGNORE
	_halo.show_behind_parent = true
	var glow := ArenaStyle.box(Color.TRANSPARENT, _accent.lightened(0.25), 3, 10)
	glow.shadow_color = Color(_accent, 0.7)
	glow.shadow_size = 12
	_halo.add_theme_stylebox_override("panel", glow)
	ArenaStyle.mount(self, _halo, _art_rect().grow(3))
	_shade = ColorRect.new()
	_shade.color = Color(0.020, 0.027, 0.043, 0.38)
	_shade.mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.mount(self, _shade, _art_rect().grow(-2))
	_cooldown = ArenaStyle.text(self, Rect2(5, 40, 100, 32), "", 23, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	pressed.connect(func() -> void: inspected.emit(_index))
	mouse_entered.connect(_hover.bind(true))
	mouse_exited.connect(_hover.bind(false))
	button_down.connect(_hover.bind(false))
	button_up.connect(func() -> void: _hover(is_hovered()))
	focus_entered.connect(_refresh_halo)
	focus_exited.connect(_refresh_halo)
	set_interaction(false)
	_refresh_halo()

## The visible card area inside this slot after keep-aspect centering.
func _art_rect() -> Rect2:
	var width := minf(size.x, size.y * DeckArt.CARD_ASPECT)
	var height := width / DeckArt.CARD_ASPECT
	return Rect2((size.x - width) * 0.5, (size.y - height) * 0.5, width, height)

func set_interaction(enabled: bool) -> void:
	disabled = not enabled
	_shade.visible = not enabled
	var details := "%s  •  %d s cooldown" % [DeckArt.summary(_index), DeckArt.COOLDOWNS[_index]]
	tooltip_text = DeckArt.NAMES[_index] + "\n" + details
	_hover(false)

func set_live(ready: bool, remaining: float, explanation: String) -> void:
	if disabled == ready:
		set_interaction(ready)
	_cooldown.text = "%.1fs" % remaining if remaining > BattleRules.EPSILON else ""
	tooltip_text = DeckArt.summary(_index) + "\n" + explanation

func show_selected(selected: bool) -> void:
	_is_selected = selected
	_refresh_halo()

func _refresh_halo() -> void:
	_halo.visible = _is_selected or has_focus()

func _hover(active: bool) -> void:
	if _animation != null and _animation.is_valid():
		_animation.kill()
	var lift := 1.06 if active and not disabled else 1.0
	pivot_offset = size * 0.5
	if UISettings.reduce_motion:
		scale = Vector2.ONE
		return
	_animation = create_tween()
	_animation.tween_property(self, "scale", Vector2.ONE * lift, 0.13)
