class_name ArenaStructure
extends Node2D
## Owns live tower HP, one-time destruction signals, and placeholder tower drawing.

signal damaged(structure: ArenaStructure, actual_damage: float)
signal destroyed(structure: ArenaStructure)

@export var data: StructureData
@export_enum("Blue", "Red") var team_id: int = GameConstants.Team.BLUE
@export var structure_id: StringName
@export_enum("Left", "Right") var lane: int = 0

var max_hp: float:
	get:
		return data.max_hp
var current_hp: float = 0.0
var is_destroyed: bool = false

@onready var title_label: Label = $Title
@onready var health_label: Label = $Health

func _ready() -> void:
	assert(data != null, "A structure requires a StructureData resource.")
	reset_health()

func display_title() -> String:
	if data.structure_type == StructureData.Kind.CORE:
		return "CORE TOWER"
	return "LEFT GUARD" if lane == 0 else "RIGHT GUARD"

func reset_health() -> void:
	# Only match initialization/restart may restore a destroyed structure.
	current_hp = max_hp
	is_destroyed = false
	_refresh_presentation()

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

func _refresh_presentation() -> void:
	if is_node_ready():
		title_label.text = display_title()
		health_label.text = "DESTROYED" if is_destroyed else "%d / %d HP" % [current_hp, max_hp]
		title_label.modulate = GameConstants.team_color(team_id)
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var tint: Color = GameConstants.team_color(team_id)
	if is_destroyed:
		tint = Color("56616c")
	draw_circle(Vector2.ZERO, 47.0, Color(tint, 0.09))
	if data.structure_type == StructureData.Kind.CORE:
		var corners := PackedVector2Array([Vector2(0, -36), Vector2(36, 0), Vector2(0, 36), Vector2(-36, 0)])
		draw_colored_polygon(corners, Color(tint, 0.24))
		var outline: PackedVector2Array = corners.duplicate()
		outline.append(corners[0])
		draw_polyline(outline, tint, 3.0, true)
		draw_circle(Vector2.ZERO, 10.0, tint)
	else:
		draw_rect(Rect2(-27, -27, 54, 54), Color(tint, 0.22))
		draw_rect(Rect2(-27, -27, 54, 54), tint, false, 3.0)
		draw_rect(Rect2(-13, -13, 26, 26), tint, false, 3.0)
	if is_destroyed:
		draw_line(Vector2(-24, -24), Vector2(24, 24), tint, 4.0, true)
		draw_line(Vector2(24, -24), Vector2(-24, 24), tint, 4.0, true)
	draw_rect(Rect2(-43, -58, 86, 6), Color("1a2635"))
	draw_rect(Rect2(-43, -58, 86 * current_hp / max_hp, 6), tint)
