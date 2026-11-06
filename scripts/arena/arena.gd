extends Node2D
## Draws the two lanes, team territories, river, and crossings using shapes only.

func _draw() -> void:
	var blue: Color = GameConstants.BLUE_COLOR
	var red: Color = GameConstants.RED_COLOR
	draw_rect(Rect2(444, 144, 1032, 792), Color("0e1927"))
	draw_rect(Rect2(444, 144, 1032, 792), Color("283b50"), false, 2.0)
	draw_rect(Rect2(464, 164, 992, 350), Color(red, 0.035))
	draw_rect(Rect2(464, 576, 992, 340), Color(blue, 0.035))
	for lane_x in [760.0, 1160.0]:
		draw_rect(Rect2(lane_x - 89, 196, 178, 688), Color("142335"))
		draw_line(Vector2(lane_x - 89, 196), Vector2(lane_x - 89, 884), Color("25384b"), 1.0)
		draw_line(Vector2(lane_x + 89, 196), Vector2(lane_x + 89, 884), Color("25384b"), 1.0)
		for marker_y in range(398, 704, 28):
			draw_line(Vector2(lane_x, marker_y), Vector2(lane_x, marker_y + 10), Color("31465c"), 2.0)
	# The river/crossings are visual landmarks; navigation is introduced in Phase 3.
	draw_rect(Rect2(445, 516, 1030, 58), Color("132e42"))
	draw_line(Vector2(445, 516), Vector2(1475, 516), Color("28536a"), 2.0)
	draw_line(Vector2(445, 574), Vector2(1475, 574), Color("28536a"), 2.0)
	for lane_x in [760.0, 1160.0]:
		draw_rect(Rect2(lane_x - 70, 508, 140, 74), Color("344455"))
		draw_rect(Rect2(lane_x - 70, 508, 140, 74), Color("617387"), false, 2.0)
		for plank_y in range(518, 580, 12):
			draw_line(Vector2(lane_x - 66, plank_y), Vector2(lane_x + 66, plank_y), Color("43566b"), 2.0)
	draw_rect(Rect2(484, 190, 16, 284), Color(red, 0.4))
	draw_rect(Rect2(1420, 616, 16, 284), Color(blue, 0.4))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(670, 180), "LEFT LANE", HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color("8c9eb1"))
	draw_string(font, Vector2(1070, 180), "RIGHT LANE", HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Color("8c9eb1"))
	draw_string(font, Vector2(502, 490), "RED TERRITORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, red)
	draw_string(font, Vector2(1240, 606), "BLUE TERRITORY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, blue)
