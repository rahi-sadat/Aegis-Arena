class_name ArenaIcon
extends Control
## Scalable symbols for the commanders, energy, and tactical assessment.

enum Kind { CRYSTAL, SHIELD, SWORDS, TARGET }

var kind: Kind
var tint := Color.WHITE

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_set_transform(size * 0.5, 0, Vector2.ONE * minf(size.x, size.y) / 24.0)
	match kind:
		Kind.CRYSTAL:
			var stone := PackedVector2Array([Vector2(0, -11), Vector2(8, -1), Vector2(0, 11), Vector2(-8, -1)])
			draw_colored_polygon(stone, tint.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(0, 11), Vector2(-8, -1)]), tint.lightened(0.22))
			_outline(stone)
		Kind.SHIELD:
			var shield := PackedVector2Array([Vector2(-9, -9), Vector2(9, -9), Vector2(8, 2), Vector2(4, 8), Vector2(0, 11), Vector2(-4, 8), Vector2(-8, 2)])
			draw_colored_polygon(shield, tint.darkened(0.55))
			_outline(shield)
			draw_line(Vector2(0, -6), Vector2(0, 6), tint, 1.6, true)
		Kind.SWORDS:
			draw_line(Vector2(-8, 8), Vector2(8, -8), tint, 2.5, true)
			draw_line(Vector2(8, 8), Vector2(-8, -8), tint, 2.5, true)
			draw_line(Vector2(-9, 1), Vector2(-1, 9), tint, 1.8, true)
			draw_line(Vector2(9, 1), Vector2(1, 9), tint, 1.8, true)
		Kind.TARGET:
			draw_arc(Vector2.ZERO, 8.0, 0.0, TAU, 20, tint, 1.7, true)
			draw_circle(Vector2.ZERO, 3.0, tint, true, -1.0, true)

func _outline(points: PackedVector2Array) -> void:
	var line := points.duplicate()
	line.append(points[0])
	draw_polyline(line, tint.lightened(0.36), 1.1, true)
