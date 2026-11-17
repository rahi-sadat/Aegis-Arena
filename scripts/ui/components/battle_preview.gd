class_name BattlePreview
extends Control
## Display samples only. This node never receives the match manager.

const UNIT_POINTS := [Vector2(723, 604), Vector2(790, 599), Vector2(1176, 603),
	Vector2(730, 445), Vector2(1170, 466), Vector2(1208, 415)]
const BLUE_FIGHTER := preload("res://assets/arena/preview/blue_fighter.webp")
const RED_FIGHTER := preload("res://assets/arena/preview/red_fighter.webp")
const BLUE_TANK := preload("res://assets/arena/preview/blue_tank.webp")

var _time: float = 0.0

static func unit_color(index: int) -> Color:
	return GameConstants.BLUE_COLOR if index < 3 else GameConstants.RED_COLOR

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if visible and not UISettings.reduce_motion:
		_time += delta
		queue_redraw()

func _draw() -> void:
	for index in UNIT_POINTS.size():
		var center: Vector2 = UNIT_POINTS[index]
		var accent := unit_color(index)
		draw_set_transform(center, 0.0, Vector2(1, 0.46))
		draw_circle(Vector2.ZERO, 20.0, Color(accent, 0.26), true, -1.0, true)
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 20, accent, 1.5, true)
		draw_set_transform(Vector2.ZERO)
		var unit := BLUE_TANK if index == 0 else (BLUE_FIGHTER if index < 3 else RED_FIGHTER)
		var height := 66.0 if index == 0 else 56.0
		var width := height * float(unit.get_width()) / unit.get_height()
		draw_texture_rect(unit, Rect2(center.x - width * 0.5, center.y - height, width, height), false)
	var progress := fposmod(_time * 0.61, 1.25)
	if progress <= 1.0:
		var start: Vector2 = UNIT_POINTS[0] - Vector2(0, 24)
		var finish: Vector2 = UNIT_POINTS[3] - Vector2(0, 21)
		var orb := start.lerp(finish, progress) + Vector2(sin(progress * PI) * 28.0, 0)
		var trail := start.lerp(finish, maxf(0.0, progress - 0.07))
		draw_line(trail, orb, Color("#6399f1"), 3.0, true)
		draw_circle(orb, 10.0, Color(0.50, 0.80, 1.0, 0.25), true, -1.0, true)
		draw_circle(orb, 4.0, Color("#bfeaff"), true, -1.0, true)
