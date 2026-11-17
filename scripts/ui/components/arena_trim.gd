class_name ArenaTrim
extends NinePatchRect
## Thin bevel and cut-metal corner ornaments scale with their parent panel.

const METAL := preload("res://assets/ui/frames/metal_trim.png")

var tint := Color("#ebc583"):
	set(value):
		tint = value
		self_modulate = value

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture = METAL
	self_modulate = tint
	patch_margin_left = 30
	patch_margin_right = 30
	patch_margin_top = 21
	patch_margin_bottom = 21
	draw_center = false
