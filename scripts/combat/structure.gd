class_name ArenaStructure
extends Node2D
## Owns live tower HP and one-time destruction signals, and presents the tower.

signal damaged(structure: ArenaStructure, actual_damage: float)
signal destroyed(structure: ArenaStructure)

@export var data: StructureData
@export_enum("Blue", "Red") var team_id: int = GameConstants.Team.BLUE
@export var structure_id: StringName
@export_enum("Left", "Right") var lane: int = 0
@export var blue_art: Texture2D
@export var red_art: Texture2D
@export var blue_ruin: Texture2D
@export var red_ruin: Texture2D

var max_hp: float:
	get:
		return data.max_hp
var current_hp: float = 0.0
var is_destroyed: bool = false
var _shown_fraction: float = 1.0
var _health_tween: Tween
var _destruction_tween: Tween
var _plate_y: float

@onready var title_label: Label = $Title
@onready var health_label: Label = $Health
@onready var _sprite: Sprite2D = $TowerArt

func _ready() -> void:
	assert(data != null, "A structure requires a StructureData resource.")
	_plate_y = -106.0 if data.structure_type == StructureData.Kind.CORE else -99.0
	_format_label(title_label, _plate_y + 2, 13)
	_format_label(health_label, _plate_y + 18, 16)
	reset_health()

func display_title() -> String:
	if data.structure_type == StructureData.Kind.CORE:
		return "CORE TOWER"
	return "LEFT GUARD" if lane == 0 else "RIGHT GUARD"

func reset_health() -> void:
	# Only match initialization/restart may restore a destroyed structure.
	current_hp = max_hp
	is_destroyed = false
	_refresh_presentation(true)

func take_damage(amount: float) -> float:
	if is_destroyed or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var actual_damage: float = minf(amount, current_hp)
	current_hp = maxf(0.0, current_hp - actual_damage)
	# Mark destruction before notifying observers, so they always see consistent HP.
	is_destroyed = current_hp <= 0.0
	_refresh_presentation()
	damaged.emit(self, actual_damage)
	if is_destroyed:
		destroyed.emit(self)
	return actual_damage

func _refresh_presentation(immediate: bool = false) -> void:
	if not is_node_ready():
		return
	title_label.text = data.display_name.to_upper()
	health_label.text = "%d / %d HP" % [ceili(current_hp), max_hp]
	title_label.modulate = GameConstants.team_color(team_id) if not is_destroyed else Color("#c3abb0")
	health_label.modulate = Color.WHITE if not is_destroyed else Color("#c6b5ad")
	_refresh_sprite(immediate)
	if _health_tween != null and _health_tween.is_valid():
		_health_tween.kill()
	var fraction := current_hp / max_hp
	if immediate or UISettings.reduce_motion:
		_show_fraction(fraction)
	else:
		_health_tween = create_tween()
		_health_tween.tween_method(_show_fraction, _shown_fraction, fraction, 0.19)

func _refresh_sprite(immediate: bool) -> void:
	var core := data.structure_type == StructureData.Kind.CORE
	var blue := team_id == GameConstants.Team.BLUE
	_sprite.texture = (blue_ruin if blue else red_ruin) if is_destroyed else (blue_art if blue else red_art)
	if _destruction_tween != null and _destruction_tween.is_valid():
		_destruction_tween.kill()
	var height := (66.0 if core else 52.0) if is_destroyed else (113.0 if core else 102.0)
	if _sprite.texture != null:
		_sprite.scale = Vector2.ONE * (height / _sprite.texture.get_height())
	_sprite.position.y = (42.0 if core else 37.0) - height * 0.5
	_sprite.modulate = Color.WHITE
	if is_destroyed and not immediate and not UISettings.reduce_motion:
		_sprite.modulate = Color(1.48, 1.21, 0.94, 0.52)
		_destruction_tween = create_tween()
		_destruction_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.31)

func _format_label(label: Label, y: float, font_size: int) -> void:
	label.position = Vector2(-80, y)
	label.size = Vector2(160, 19)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#fff7e6"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _show_fraction(value: float) -> void:
	_shown_fraction = value
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var tint := Color("#716569") if is_destroyed else GameConstants.team_color(team_id)
	draw_set_transform(Vector2(0, 25), 0, Vector2(1, 0.42))
	draw_circle(Vector2.ZERO, 57.0, Color(0.015, 0.018, 0.029, 0.48), true, -1.0, true)
	draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 28, Color(tint, 0.56), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	var plate := Rect2(-67, _plate_y, 134, 44)
	draw_rect(plate, Color(0.025, 0.035, 0.060, 0.93))
	draw_rect(plate, Color("#8a7254"), false, 1.0)
	draw_rect(Rect2(-62, _plate_y + 37, 124, 4), Color("#302838"))
	draw_rect(Rect2(-62, _plate_y + 37, 124 * _shown_fraction, 4), tint)
