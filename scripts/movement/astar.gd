class_name ManualAStar
extends RefCounted
## Four-direction A*. An array is enough for this small board's open list.

const DIRECTIONS := [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN]

static func heuristic(cell: Vector2i, goal: Vector2i) -> int:
	return absi(cell.x - goal.x) + absi(cell.y - goal.y)

static func walkable(grid: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid.width and cell.y < grid.height and not grid.blocked.has(cell)

static func search(grid: Dictionary, start: Vector2i, goal: Vector2i) -> Dictionary:
	var trace: Dictionary = {"path": [], "examined": [], "cost": -1}
	if not walkable(grid, start) or not walkable(grid, goal):
		return trace
	var open: Array[Vector2i] = [start]
	var closed: Dictionary = {}
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	while not open.is_empty():
		var best_index: int = 0
		for index in range(1, open.size()):
			var cell: Vector2i = open[index]
			var best: Vector2i = open[best_index]
			var h: int = heuristic(cell, goal)
			var best_h: int = heuristic(best, goal)
			var f: int = int(g_score[cell]) + h
			var best_f: int = int(g_score[best]) + best_h
			if f < best_f or (f == best_f and h < best_h):
				best_index = index
		var current: Vector2i = open[best_index]
		open.remove_at(best_index)
		var g: int = g_score[current]
		var h: int = heuristic(current, goal)
		trace.examined.append({"cell": [current.x, current.y], "g": g, "h": h, "f": g + h})
		if current == goal:
			var path: Array[Vector2i] = [current]
			while came_from.has(current):
				current = came_from[current]
				path.push_front(current)
			trace.path = path
			trace.cost = g
			return trace
		closed[current] = true
		for direction: Vector2i in DIRECTIONS:
			var next: Vector2i = current + direction
			if not walkable(grid, next) or closed.has(next):
				continue
			var new_g: int = g + 1
			if new_g < int(g_score.get(next, 1000000)):
				came_from[next] = current
				g_score[next] = new_g
				if not open.has(next):
					open.append(next)
	return trace
