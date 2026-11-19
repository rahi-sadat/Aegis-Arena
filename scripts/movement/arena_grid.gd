class_name ArenaGrid
extends RefCounted
## Static lane routes are built with our A* once, then shared by live play and search.

const CELL_SIZE := 32.0
const ORIGIN := Vector2(448, 120)
const WIDTH := 32
const HEIGHT := 24

static var paths: Array = []
static var lengths: Array[float] = []
static var spawns: Array = [[], []]
static var guard_progress: Array = [[], []]
static var route_traces: Array = []
static var route_searches: int = 0

static func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori((point.x - ORIGIN.x) / CELL_SIZE), floori((point.y - ORIGIN.y) / CELL_SIZE))

static func cell_to_world(cell: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

static func make_grid(lane: int) -> Dictionary:
	var blocked: Dictionary = {}
	var lane_x: float = ArenaLayout.LANE_X[lane]
	for x in WIDTH:
		for y in HEIGHT:
			var cell := Vector2i(x, y)
			var point: Vector2 = cell_to_world(cell)
			var river: bool = point.y >= ArenaLayout.RIVER_TOP and point.y <= ArenaLayout.RIVER_BOTTOM
			var outside_bridge: bool = absf(point.x - lane_x) > ArenaLayout.BRIDGE_HALF_WIDTH
			var outside_corridor: bool = point.y > 310 and point.y < 746 and absf(point.x - lane_x) > 96
			var tower: bool = point.distance_to(Vector2(lane_x, 336)) < 40 or point.distance_to(Vector2(lane_x, 716)) < 40
			if (river and outside_bridge) or outside_corridor or tower:
				blocked[cell] = true
	return {"width": WIDTH, "height": HEIGHT, "blocked": blocked}

static func setup() -> void:
	if not paths.is_empty():
		return
	for lane in 2:
		var x: float = ArenaLayout.LANE_X[lane]
		var points: Array[Vector2] = [Vector2(960, 792), Vector2(x, 776), Vector2(x, 600), Vector2(x, 488), Vector2(x, 280), Vector2(960, 264)]
		var grid: Dictionary = make_grid(lane)
		var route: PackedVector2Array = []
		for index in range(points.size() - 1):
			var found: Dictionary = ManualAStar.search(grid, world_to_cell(points[index]), world_to_cell(points[index + 1]))
			route_searches += 1
			assert(not found.path.is_empty(), "A lane route must exist through its bridge.")
			route_traces.append({"lane": lane, "segment": index, "start": points[index], "goal": points[index + 1], "search": found})
			for cell: Vector2i in found.path:
				var world: Vector2 = cell_to_world(cell)
				if route.is_empty() or route[-1] != world:
					route.append(world)
		paths.append(route)
		var distance: float = 0.0
		for index in range(1, route.size()):
			distance += route[index - 1].distance_to(route[index])
		lengths.append(distance)
		spawns[0].append(nearest_progress(lane, Vector2(x, 776)))
		spawns[1].append(nearest_progress(lane, Vector2(x, 280)))
		guard_progress[0].append(nearest_progress(lane, Vector2(x, 716)))
		guard_progress[1].append(nearest_progress(lane, Vector2(x, 336)))

static func position_at(lane: int, progress: float) -> Vector2:
	var route: PackedVector2Array = paths[lane]
	var left: float = clampf(progress, 0.0, lengths[lane])
	for index in range(1, route.size()):
		var distance: float = route[index - 1].distance_to(route[index])
		if left <= distance:
			return route[index - 1].lerp(route[index], left / distance)
		left -= distance
	return route[-1]

static func nearest_progress(lane: int, point: Vector2) -> float:
	var route: PackedVector2Array = paths[lane]
	var traveled: float = 0.0
	var best_distance: float = INF
	var best_progress: float = 0.0
	for index in range(1, route.size()):
		var a: Vector2 = route[index - 1]
		var b: Vector2 = route[index]
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(point, a, b)
		var distance: float = point.distance_squared_to(closest)
		if distance < best_distance:
			best_distance = distance
			best_progress = traveled + a.distance_to(closest)
		traveled += a.distance_to(b)
	return best_progress

static func structure_progress(structure: Dictionary, lane: int) -> float:
	if structure.kind == StructureData.Kind.CORE:
		return 0.0 if structure.team == 0 else lengths[lane]
	return guard_progress[structure.team][lane]

static func trace_dictionary() -> Dictionary:
	var lanes: Array = []
	for lane in 2:
		var blocked: Array = []
		var grid: Dictionary = make_grid(lane)
		for cell: Vector2i in grid.blocked:
			blocked.append([cell.x, cell.y])
		var segments: Array = []
		for record: Dictionary in route_traces:
			if record.lane != lane:
				continue
			var cells: Array = []
			for cell: Vector2i in record.search.path:
				cells.append([cell.x, cell.y])
			segments.append({"segment": record.segment, "path": cells, "cost": record.search.cost,
				"examined": record.search.examined.duplicate(true)})
		lanes.append({"lane": lane, "blocked": blocked, "segments": segments})
	return {"width": WIDTH, "height": HEIGHT, "cell_size": CELL_SIZE, "origin": [ORIGIN.x, ORIGIN.y], "lanes": lanes}
