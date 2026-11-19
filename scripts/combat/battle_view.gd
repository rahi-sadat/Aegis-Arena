class_name LiveBattleView
extends Node2D
## Draws actual units and attacks. This view never changes the battle's numbers.

const BLUE_FIGHTER := preload("res://assets/arena/preview/blue_fighter.webp")
const RED_FIGHTER := preload("res://assets/arena/preview/red_fighter.webp")
const TANK := preload("res://assets/arena/preview/blue_tank.webp")

var manager: GameManager
var show_routes: bool = false
var _effects: Array = []

func bind_match(match_manager: GameManager) -> void:
	manager = match_manager
	manager.battle_changed.connect(queue_redraw)
	manager.action_executed.connect(_on_action)
	manager.match_started.connect(func() -> void: _effects.clear(); queue_redraw())

func _process(delta: float) -> void:
	if manager == null:
		return
	if not manager.is_paused:
		for index in range(_effects.size() - 1, -1, -1):
			_effects[index].time -= delta
			if _effects[index].time <= 0:
				_effects.remove_at(index)
		for attack: Dictionary in manager.last_attacks:
			_effects.append({"time": 0.16, "kind": "attack", "team": attack.team,
				"from": ArenaGrid.position_at(attack.from_lane, attack.from_progress) - Vector2(0, 20),
				"to": ArenaGrid.position_at(attack.from_lane, attack.to_progress) - Vector2(0, 20)})
		manager.last_attacks.clear()
	queue_redraw()

func _on_action(move: Dictionary, team: int) -> void:
	if move.card >= 0 and CardData.is_spell(move.card):
		_effects.append({"time": 0.38, "kind": "spell", "lane": move.lane, "team": team})

func _draw() -> void:
	if manager == null or manager.battle_state == null:
		return
	if show_routes:
		draw_string(ThemeDB.fallback_font, Vector2(470, 208), "A* routes: gold path / red blocked cells / green explored cells / g,h,f at bridges", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ArenaStyle.GOLD)
		for lane in 2:
			draw_polyline(ArenaGrid.paths[lane], Color(1, 0.84, 0.31, 0.8), 3.0, true)
			var grid: Dictionary = ArenaGrid.make_grid(lane)
			for cell: Vector2i in grid.blocked:
				var point: Vector2 = ArenaGrid.cell_to_world(cell)
				if absf(point.x - ArenaLayout.LANE_X[lane]) <= 104:
					draw_rect(Rect2(point - Vector2(16, 16), Vector2(32, 32)), Color(0.9, 0.25, 0.23, 0.20))
		for trace: Dictionary in ArenaGrid.route_traces:
			if trace.segment == 2:
				for entry: Dictionary in trace.search.examined:
					var point: Vector2 = ArenaGrid.cell_to_world(Vector2i(entry.cell[0], entry.cell[1]))
					draw_circle(point, 3.0, Color(0.4, 1, 0.8, 0.7))
					draw_string(ThemeDB.fallback_font, point + Vector2(-14, 12), "%d,%d,%d" % [entry.g, entry.h, entry.f], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	for unit: Dictionary in manager.battle_state.units:
		var center: Vector2 = ArenaGrid.position_at(unit.lane, unit.progress)
		center.x += (int(unit.id) % 3 - 1) * 13.0
		var color: Color = GameConstants.team_color(unit.team)
		var texture: Texture2D = TANK if unit.card == CardData.Card.TANK else (BLUE_FIGHTER if unit.team == 0 else RED_FIGHTER)
		var height: float = 63.0 if unit.card == CardData.Card.TANK else 48.0
		var width: float = height * texture.get_width() / texture.get_height()
		draw_set_transform(center + Vector2(0, 4), 0, Vector2(20, 7))
		draw_circle(Vector2.ZERO, 1.0, Color(color, 0.38), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
		var tint: Color = Color(0.75, 1, 0.77) if unit.card == CardData.Card.RANGER else Color.WHITE
		if unit.team == 1 and unit.card == CardData.Card.TANK:
			tint = Color(1, 0.56, 0.60)
		draw_texture_rect(texture, Rect2(center - Vector2(width * 0.5, height), Vector2(width, height)), false, tint)
		var bar := Rect2(center + Vector2(-20, -height - 8), Vector2(40, 4))
		draw_rect(bar.grow(1), Color(0.03, 0.04, 0.06))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * unit.hp / CardData.HP[unit.card], 4)), color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-15, 16), CardData.NAMES[unit.card].left(1) + " " + str(ceili(unit.hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	for effect: Dictionary in _effects:
		var color: Color = GameConstants.team_color(effect.team)
		if effect.kind == "attack":
			draw_line(effect.from, effect.to, Color(color, effect.time / 0.16), 2.5, true)
		else:
			var x: float = ArenaLayout.LANE_X[effect.lane]
			draw_rect(Rect2(x - 90, 260, 180, 530), Color(color, effect.time * 0.5))
