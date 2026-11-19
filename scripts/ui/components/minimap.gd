class_name BattleMinimap
extends Panel

var _structures: Array[ArenaStructure] = []
var _map: Control
var _toggle: Button
var _expanded: bool = true
var _preview: bool = false
var live_units: Array = []

func _ready() -> void:
	ArenaStyle.decorate(self)
	ArenaStyle.text(self, Rect2(18, 10, 202, 38), "BATTLE MAP", 19, ArenaStyle.GOLD, true)
	_toggle = ArenaStyle.button("−")
	_toggle.tooltip_text = "Collapse minimap"
	ArenaStyle.mount(self, _toggle, Rect2(210, 11, 43, 34))
	_toggle.pressed.connect(_toggle_map)
	_map = Control.new()
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArenaStyle.mount(self, _map, Rect2(16, 55, 238, 152))
	_map.draw.connect(_draw_field)

func set_battle(structures: Array[ArenaStructure]) -> void:
	_structures = structures
	refresh()

func set_preview(enabled: bool) -> void:
	_preview = enabled
	refresh()

func refresh() -> void:
	_map.queue_redraw()

func _toggle_map() -> void:
	_expanded = not _expanded
	_map.visible = _expanded
	if _expanded:
		ArenaStyle.enter(_map)
	_toggle.text = "−" if _expanded else "+"
	_toggle.tooltip_text = "Collapse minimap" if _expanded else "Expand minimap"
	position.y += -169.0 if _expanded else 169.0
	size.y = 225.0 if _expanded else 56.0

func _point(world: Vector2) -> Vector2:
	return (world - ArenaLayout.FIELD.position) * _map.size / ArenaLayout.FIELD.size

func _draw_field() -> void:
	var top := _point(Vector2(ArenaLayout.FIELD.position.x, ArenaLayout.RIVER_TOP)).y
	var bottom := _point(Vector2(ArenaLayout.FIELD.position.x, ArenaLayout.RIVER_BOTTOM)).y
	_map.draw_rect(Rect2(0, 0, _map.size.x, top), Color("#422930"))
	_map.draw_rect(Rect2(0, bottom, _map.size.x, _map.size.y - bottom), Color("#193b53"))
	_map.draw_rect(Rect2(0, top, _map.size.x, bottom - top), Color("#1b7289"))
	for lane_x: float in ArenaLayout.LANE_X:
		var x := _point(Vector2(lane_x, 0)).x
		var bridge_half := ArenaLayout.BRIDGE_HALF_WIDTH * _map.size.x / ArenaLayout.FIELD.size.x
		_map.draw_rect(Rect2(x - 12, 0, 24, _map.size.y), Color(0.71, 0.61, 0.40, 0.24))
		_map.draw_rect(Rect2(x - bridge_half, top, bridge_half * 2, bottom - top), Color("#c29d64"))
	_map.draw_rect(Rect2(Vector2.ZERO, _map.size), ArenaStyle.LINE, false, 1.0)
	for structure in _structures:
		var center := _point(structure.global_position)
		var color := GameConstants.team_color(structure.team_id) if not structure.is_destroyed else Color("#736a66")
		var radius := 5.5 if structure.data.structure_type == StructureData.Kind.CORE else 3.7
		_map.draw_circle(center, radius + 2.0, ArenaStyle.INK, true, -1.0, true)
		_map.draw_circle(center, radius, color, true, -1.0, true)
	if _preview:
		for index in BattlePreview.UNIT_POINTS.size():
			_map.draw_circle(_point(BattlePreview.UNIT_POINTS[index]), 2.4, BattlePreview.unit_color(index), true, -1.0, true)
	else:
		for unit: Dictionary in live_units:
			_map.draw_circle(_point(ArenaGrid.position_at(unit.lane, unit.progress)), 2.5, GameConstants.team_color(unit.team), true, -1.0, true)
