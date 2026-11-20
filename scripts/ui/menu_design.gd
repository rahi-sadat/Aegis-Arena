class_name MenuDesign
extends RefCounted
## Static, reusable menu surfaces. No full-screen animation loop.

static func backdrop(parent: Control, artwork: Texture2D, dim: float = 0.45) -> void:
	var art := ArenaStyle.art(parent, Rect2(0, 0, 1920, 1080), artwork)
	art.modulate = Color(0.78, 0.83, 0.88)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.025, 0.043, 0.065, 0.98))
	gradient.set_color(1, Color(0.025, 0.043, 0.065, dim))
	gradient.add_point(0.52, Color(0.025, 0.043, 0.065, 0.83))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	var shade := ArenaStyle.art(parent, Rect2(0, 0, 1920, 1080), texture)
	shade.stretch_mode = TextureRect.STRETCH_SCALE

static func brand(parent: Control, caption: String) -> void:
	ArenaStyle.icon(parent, Rect2(72, 42, 28, 32), ArenaIcon.Kind.SHIELD, ArenaStyle.GOLD)
	ArenaStyle.text(parent, Rect2(114, 41, 430, 34), "AEGIS  /  ARENA", 22, ArenaStyle.TEXT, true)
	ArenaStyle.text(parent, Rect2(600, 43, 720, 28), caption, 13, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	var line := ColorRect.new()
	line.color = Color(0.6, 0.7, 0.8, 0.12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArenaStyle.mount(parent, line, Rect2(72, 101, 1776, 1))

static func eyebrow(parent: Node, rect: Rect2, value: String) -> Label:
	return ArenaStyle.text(parent, rect, value, 13, ArenaStyle.GOLD, true)
