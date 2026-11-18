class_name ArenaTrim
extends Control
## Glass finish for panels: a soft top sheen and a luminous highlight on the top edge.

var tint := Color("#f2c76b"):
	set(value):
		tint = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var sheen := StyleBoxFlat.new()
	sheen.bg_color = Color(1, 1, 1, 0.035)
	sheen.corner_radius_top_left = 11
	sheen.corner_radius_top_right = 11
	draw_style_box(sheen, Rect2(Vector2(1, 1), Vector2(size.x - 2, minf(size.y * 0.45, 56.0))))
	var middle := size.x * 0.5
	var reach := size.x * 0.42
	draw_line(Vector2(middle - reach, 1), Vector2(middle + reach, 1), Color(tint, 0.9), 2.0, true)
	draw_line(Vector2(middle - reach * 0.6, 2), Vector2(middle + reach * 0.6, 2), Color(1, 1, 1, 0.35), 1.0, true)
