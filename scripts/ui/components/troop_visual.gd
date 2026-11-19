class_name TroopVisual
extends Node2D
## A grounded animated view. It copies model values and never writes combat state.

var unit_id: int
var team: int
var card: int
var lane: int
var model_progress: float
var hp: float
var is_dying: bool = false
var finished: bool = false
var _sprite: Sprite2D
var _body: Node2D
var _overlay: Node2D
var _from: Vector2
var _target: Vector2
var _blend: float = 1.0
var _moving: bool = false
var _north: bool = true
var _flip: bool = false
var _clock: float = 0.0
var _attack_left: float = 0.0
var _attack_length: float = 0.38
var _flash: float = 0.0
var _death_left: float = 0.26
var _spawn: float = 0.0
var _frame: int = 0

func setup(unit: Dictionary) -> void:
	unit_id = unit.id
	team = unit.team
	card = unit.card
	lane = unit.lane
	hp = unit.hp
	model_progress = unit.progress
	_north = team == 0
	_target = ground_position(lane, model_progress, unit_id)
	_from = _target
	position = _target
	_body = Node2D.new()
	add_child(_body)
	_sprite = Sprite2D.new()
	_sprite.texture = TroopArt.SHEETS[card]
	_sprite.region_enabled = true
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.material = TroopArt.team_material(team)
	_body.add_child(_sprite)
	_overlay = Node2D.new()
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)
	_update_frame()

static func ground_position(unit_lane: int, progress: float, id: int) -> Vector2:
	return ArenaGrid.position_at(unit_lane, progress) + Vector2((id % 3 - 1) * 12.0, 0)

func update_model(unit: Dictionary) -> void:
	if unit.hp < hp:
		_flash = 0.14
	hp = unit.hp
	var point: Vector2 = ground_position(lane, unit.progress, unit_id)
	var movement: Vector2 = point - _target
	_moving = movement.length_squared() > 0.01
	if absf(movement.y) > 0.1:
		_north = movement.y < 0
	if absf(movement.x) > absf(movement.y):
		_flip = movement.x > 0
	else:
		_flip = false
	_from = position
	_target = point
	_blend = 0.0
	model_progress = unit.progress

func attack(target: Vector2) -> void:
	_attack_length = [0.38, 0.43, 0.52][card]
	_attack_left = _attack_length
	if absf(target.y - position.y) > 4:
		_north = target.y < position.y
	_flip = target.x > position.x + 10

func hit() -> void:
	_flash = 0.14

func die() -> void:
	if is_dying:
		return
	is_dying = true
	_moving = false
	_death_left = 0.26

func animate(delta: float, paused: bool) -> void:
	if paused or finished:
		return
	_clock += delta
	_spawn = minf(1.0, _spawn + delta * 6)
	_blend = minf(1.0, _blend + delta / BattleRules.TICK_SECONDS)
	position = _from.lerp(_target, _blend)
	_attack_left = maxf(0, _attack_left - delta)
	_flash = maxf(0, _flash - delta)
	if is_dying:
		_death_left -= delta
		_body.scale = Vector2(1, lerpf(0.65, 1.0, maxf(0, _death_left / 0.26)))
		modulate.a = maxf(0, _death_left / 0.26)
		finished = _death_left <= 0
	else:
		modulate.a = _spawn
	var light: float = 1.0 + 1.7 * (_flash / 0.14)
	_sprite.modulate = Color(light, light, light, 1)
	_update_frame()
	queue_redraw()
	_overlay.queue_redraw()

func _update_frame() -> void:
	var row: int = 0 if _north else 1
	var column: int = int(_clock * (6 if card == 2 else 9) + unit_id * 0.7) % 4 if _moving else 0
	if _attack_left > 0:
		row += 2
		column = clampi(int((1.0 - _attack_left / _attack_length) * 4), 0, 3)
	if UISettings.reduce_motion:
		column = 2 if _attack_left > 0 else 0
	_frame = row * 4 + column
	var rect: Rect2 = TroopArt.frame_rect(card, row, column)
	var scale_factor: float = TroopArt.WORLD_HEIGHT[card] / TroopArt.BODY_PIXELS[card]
	_sprite.region_rect = rect
	_sprite.scale = Vector2.ONE * scale_factor
	_sprite.position = -Vector2(rect.size.x * 0.5, TroopArt.FEET[card][_frame]) * scale_factor
	_sprite.flip_h = _flip

func ground_anchor_error() -> float:
	var rect: Rect2 = _sprite.region_rect
	var foot := Vector2(rect.size.x * 0.5, TroopArt.FEET[card][_frame])
	return _sprite.to_global(foot).distance_to(global_position)

func _draw() -> void:
	var radius: float = 24.0 if card == 2 else 15.0
	draw_set_transform(Vector2(0, 1), 0, Vector2(radius, radius * 0.31))
	draw_circle(Vector2.ZERO, 1, Color(0.015, 0.018, 0.023, 0.55), true, -1, true)
	draw_set_transform(Vector2.ZERO)
	var tint: Color = GameConstants.team_color(team)
	draw_line(Vector2(-8, 4), Vector2(8, 4), Color(tint, 0.82), 2, true)

func _draw_overlay() -> void:
	if is_dying:
		return
	var width: float = 42.0 if card == 2 else 32.0
	var y: float = -TroopArt.WORLD_HEIGHT[card] - 7
	draw_health_bar(_overlay, Rect2(-width * 0.5, y, width, 3.5), hp / CardData.HP[card], GameConstants.team_color(team))

static func draw_health_bar(canvas: Node2D, rect: Rect2, fraction: float, tint: Color) -> void:
	canvas.draw_rect(rect.grow(1), Color(0.015, 0.02, 0.025, 0.9))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), tint)
