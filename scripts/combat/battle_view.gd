class_name LiveBattleView
extends Node2D
## Animated sprites and combat feedback only. BattleRules remains the sole simulator.

var manager: GameManager
var show_routes: bool = false:
	set(value):
		show_routes = value
		queue_redraw()
var selected_lane: int = -1
var show_deployment: bool = false:
	set(value):
		show_deployment = value
		queue_redraw()
var visuals: Dictionary = {}
var effects: Array = []
var _model_tick: int = -1
var _fx_layer: Node2D
var _effect_id: int = 0
var _clock: float = 0.0

func bind_match(match_manager: GameManager) -> void:
	manager = match_manager
	y_sort_enabled = true
	_fx_layer = Node2D.new()
	_fx_layer.z_index = 20
	add_child(_fx_layer)
	_fx_layer.draw.connect(_draw_effects)
	manager.battle_changed.connect(_capture_model)
	manager.action_executed.connect(_on_action)
	manager.match_started.connect(_reset)

func _reset() -> void:
	for visual: TroopVisual in visuals.values():
		visual.queue_free()
	visuals.clear()
	effects.clear()
	_model_tick = -1
	show_deployment = false
	_capture_model()

func _capture_model() -> void:
	if manager.battle_state == null:
		return
	var state: GameState = manager.battle_state
	var tick_changed: bool = _model_tick != state.tick_index
	var present: Dictionary = {}
	for unit: Dictionary in state.units:
		present[unit.id] = true
		if not visuals.has(unit.id):
			var view := TroopVisual.new()
			add_child(view)
			view.setup(unit)
			visuals[unit.id] = view
			_add_effect("deploy", view.position, view.position, unit.team, 0.40)
		elif tick_changed or visuals[unit.id].hp != unit.hp:
			visuals[unit.id].update_model(unit)
	for id: int in visuals:
		var view: TroopVisual = visuals[id]
		if not present.has(id) and not view.is_dying:
			view.die()
			_add_effect("dust", view.position, view.position, view.team, 0.35)
	_model_tick = state.tick_index

func _process(delta: float) -> void:
	if manager == null or manager.is_paused:
		return
	var had_effects: bool = not effects.is_empty()
	if not manager.is_paused:
		_clock += delta
		for index in range(effects.size() - 1, -1, -1):
			effects[index].left -= delta
			if effects[index].left <= 0:
				effects.remove_at(index)
		for attack: Dictionary in manager.last_attacks:
			_show_attack(attack)
		manager.last_attacks.clear()
	var remove: Array = []
	for id: int in visuals:
		var view: TroopVisual = visuals[id]
		view.animate(delta, manager.is_paused)
		if view.finished:
			remove.append(id)
	for id: int in remove:
		visuals[id].queue_free()
		visuals.erase(id)
	if had_effects or not effects.is_empty():
		_fx_layer.queue_redraw()

func _find_visual(team: int, lane: int, progress: float, card: int = -1) -> TroopVisual:
	var found: TroopVisual = null
	var nearest: float = 65.0
	for view: TroopVisual in visuals.values():
		if view.team != team or view.lane != lane or (card >= 0 and view.card != card):
			continue
		var distance: float = absf(view.model_progress - progress)
		if distance < nearest:
			found = view
			nearest = distance
	return found

func _show_attack(attack: Dictionary) -> void:
	var from: Vector2 = ArenaGrid.position_at(attack.from_lane, attack.from_progress) - Vector2(0, 35)
	var target: Vector2 = ArenaGrid.position_at(attack.from_lane, attack.to_progress) - Vector2(0, 35)
	var source: TroopVisual = _find_visual(attack.team, attack.from_lane, attack.from_progress, attack.card) if attack.card >= 0 else null
	if source != null:
		from = source.position - Vector2(0, TroopArt.WORLD_HEIGHT[source.card] * 0.53)
		source.attack(target)
	if attack.kind == "structure":
		target = manager.structures[attack.index].global_position - Vector2(0, 48)
	else:
		var victim: TroopVisual = _find_visual(1 - attack.team, attack.from_lane, attack.to_progress)
		if victim != null:
			target = victim.position - Vector2(0, TroopArt.WORLD_HEIGHT[victim.card] * 0.45)
			victim.hit()
	var kind: String = "tower" if attack.card < 0 else ["slash", "arrow", "slam"][attack.card]
	if attack.card < 0:
		for index in manager.battle_state.structures.size():
			var structure: Dictionary = manager.battle_state.structures[index]
			if structure.team == attack.team and (structure.kind == StructureData.Kind.CORE or structure.lane == attack.from_lane):
				if absf(ArenaGrid.structure_progress(structure, attack.from_lane) - attack.from_progress) < 1:
					from = manager.structures[index].global_position - Vector2(0, 60)
					break
	_add_effect(kind, from, target, attack.team, 0.36 if kind != "slam" else 0.48)

func _on_action(move: Dictionary, team: int) -> void:
	if move.card < 0 or not CardData.is_spell(move.card):
		return
	for view: TroopVisual in visuals.values():
		if view.team != team and view.lane == move.lane and not view.is_dying:
			var point: Vector2 = view.position - Vector2(0, 28)
			_add_effect("fire" if move.card == 3 else "rain", point - Vector2(0, 125), point, team, 0.64)
			view.hit()

func _add_effect(kind: String, from: Vector2, to: Vector2, team: int, lifetime: float) -> void:
	_effect_id += 1
	effects.append({"kind": kind, "from": from, "to": to, "team": team,
		"life": lifetime, "left": lifetime, "seed": _effect_id})

func _draw() -> void:
	if manager == null or manager.battle_state == null:
		return
	if show_deployment:
		for lane in 2:
			var point: Vector2 = ArenaGrid.position_at(lane, ArenaGrid.spawns[0][lane])
			var tint: Color = Color(0.55, 0.78, 0.92, 0.55)
			draw_set_transform(point, 0, Vector2(1, 0.42))
			draw_circle(Vector2.ZERO, 36, Color(tint, 0.08))
			draw_arc(Vector2.ZERO, 36, 0, TAU, 48, tint, 1.5, true)
			draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font, point + Vector2(-55, 36), "LEFT  [A]" if lane == 0 else "RIGHT  [D]", HORIZONTAL_ALIGNMENT_CENTER, 110, 13, ArenaStyle.TEXT)
	if not show_routes:
		return
	draw_string(ThemeDB.fallback_font, Vector2(470, 208), "A*: gold route / red blocked / green explored / bridge g,h,f", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ArenaStyle.GOLD)
	for lane in 2:
		draw_polyline(ArenaGrid.paths[lane], Color(0.90, 0.76, 0.40, 0.8), 2.0, true)
		var grid: Dictionary = ArenaGrid.make_grid(lane)
		for cell: Vector2i in grid.blocked:
			var point: Vector2 = ArenaGrid.cell_to_world(cell)
			if absf(point.x - ArenaLayout.LANE_X[lane]) <= 104:
				draw_rect(Rect2(point - Vector2(16, 16), Vector2(32, 32)), Color(0.8, 0.3, 0.25, 0.17))
	for record: Dictionary in ArenaGrid.route_traces:
		if record.segment == 2:
			for entry: Dictionary in record.search.examined:
				var point: Vector2 = ArenaGrid.cell_to_world(Vector2i(entry.cell[0], entry.cell[1]))
				draw_circle(point, 3, Color(0.4, 0.9, 0.7, 0.7))
				draw_string(ThemeDB.fallback_font, point + Vector2(-14, 12), "%d,%d,%d" % [entry.g, entry.h, entry.f], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_effects() -> void:
	for effect: Dictionary in effects:
		var t: float = 1.0 - effect.left / effect.life
		var fade: float = 1.0 - t
		var tint: Color = GameConstants.team_color(effect.team)
		var from: Vector2 = effect.from
		var to: Vector2 = effect.to
		match effect.kind:
			"arrow", "tower":
				var travel: float = minf(1, t / 0.58)
				var point: Vector2 = from.lerp(to, travel) - Vector2(0, sin(travel * PI) * 12)
				var direction: Vector2 = (to - from).normalized()
				var color: Color = Color(0.94, 0.85, 0.59, fade) if effect.kind == "arrow" else Color(1.0, 0.65, 0.27, fade)
				_fx_layer.draw_line(point - direction * 17, point, color, 2.0 if effect.kind == "arrow" else 4.0, true)
				_fx_layer.draw_line(point, point - direction.rotated(0.5) * 7, color, 1.4, true)
				_fx_layer.draw_line(point, point - direction.rotated(-0.5) * 7, color, 1.4, true)
				if travel >= 1:
					_sparks(to, effect.seed, 5, 17 * t, color)
			"slash":
				var angle: float = (to - from).angle()
				var center: Vector2 = from.lerp(to, 0.60)
				_fx_layer.draw_arc(center, 23, angle - 1.35 + t, angle + 0.7 + t, 20, Color(0.88, 0.95, 1.0, fade), 3.5 * fade + 0.8, true)
				_sparks(to, effect.seed, 6, 23 * t, Color(0.93, 0.81, 0.50, fade))
			"slam":
				_fx_layer.draw_line(from.lerp(to, 0.3), to, Color(tint, fade * 0.8), 7 * fade + 1, true)
				_fx_layer.draw_arc(to + Vector2(0, 18), 8 + 34 * t, 0, TAU, 32, Color(0.67, 0.76, 0.79, fade * 0.8), 2, true)
				_sparks(to, effect.seed, 9, 36 * t, Color(0.48, 0.62, 0.75, fade))
			"fire":
				var radius: float = 10 + 24 * sin(t * PI)
				_fx_layer.draw_circle(to, radius, Color(0.95, 0.29, 0.08, fade * 0.35))
				_fx_layer.draw_arc(to, radius + 4, 0, TAU, 32, Color(1, 0.65, 0.2, fade), 2, true)
				_sparks(to, effect.seed, 12, 40 * t, Color(1.0, 0.54, 0.18, fade))
			"rain":
				for index in 5:
					var offset := Vector2((index - 2) * 9, (index % 2) * 8)
					var point: Vector2 = (from + offset).lerp(to + offset, minf(1, t * 2.2))
					_fx_layer.draw_line(point - Vector2(8, 25), point, Color(0.85, 0.94, 1, fade), 2, true)
				_sparks(to, effect.seed, 6, 22 * t, Color(tint, fade))
			"deploy":
				_fx_layer.draw_set_transform(to, 0, Vector2(1, 0.35))
				_fx_layer.draw_arc(Vector2.ZERO, 10 + 24 * t, 0, TAU, 32, Color(tint, fade * 0.7), 1.5, true)
				_fx_layer.draw_set_transform(Vector2.ZERO)
			"dust":
				_sparks(to, effect.seed, 7, 23 * t, Color(0.67, 0.59, 0.44, fade * 0.7))

func _sparks(center: Vector2, seed_value: int, count: int, distance: float, color: Color) -> void:
	for index in count:
		var angle: float = index * 2.39996 + seed_value * 0.7
		var direction := Vector2(cos(angle), sin(angle) * 0.65)
		var point: Vector2 = center + direction * distance
		_fx_layer.draw_line(point, point + direction * 4, color, 1.6, true)
