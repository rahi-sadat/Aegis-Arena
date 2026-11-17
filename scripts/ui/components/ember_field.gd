class_name EmberField
extends Control
## Ambient, deterministic particles used over the title painting.

var _elapsed: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if UISettings.reduce_motion or not is_visible_in_tree():
		return
	_elapsed += delta
	queue_redraw()

func _draw() -> void:
	for index in 38:
		var drift := fposmod(_elapsed * (8.0 + index % 6) + index * 73.0, size.y)
		var center := Vector2(size.x * 0.38 + fposmod(index * 173.0, size.x * 0.62) + sin(_elapsed + index) * 10.0, size.y - drift)
		var opacity := 0.22 + 0.26 * sin(_elapsed * 0.9 + index)
		draw_circle(center, 1.5 + index % 4 * 0.45, Color(1.0, 0.62, 0.24, opacity), true, -1.0, true)
