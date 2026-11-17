extends Node2D
## Painted fortress covering the original logical lane and tower coordinates.

@export var fortress: Texture2D
@export var blue_banner: Texture2D
@export var red_banner: Texture2D
@export var brazier: Texture2D

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1920, 1080), Color("#0a1726"))
	if fortress != null:
		draw_texture_rect(fortress, Rect2(0, 25, 1920, 1080), false)
	for x: float in [846.0, 1074.0]:
		_draw_prop(red_banner, Vector2(x, 251), 63.0)
		_draw_prop(blue_banner, Vector2(x, 799), 63.0)
	for x: float in [581.0, 1339.0]:
		_draw_prop(brazier, Vector2(x, 465), 43.0)
		_draw_prop(brazier, Vector2(x, 631), 43.0)

func _draw_prop(texture: Texture2D, foot: Vector2, height: float) -> void:
	if texture == null:
		return
	var width := height * float(texture.get_width()) / texture.get_height()
	draw_texture_rect(texture, Rect2(foot.x - width * 0.5, foot.y - height, width, height), false)
