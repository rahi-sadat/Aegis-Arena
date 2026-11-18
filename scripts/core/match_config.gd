class_name MatchConfig
extends RefCounted
## Battle-setup choices that carry from the pre-battle screen into the match.
## The search algorithms read their commander's entry when they are implemented.

enum Mode { AI_VS_AI, HUMAN_VS_AI }
enum Algorithm { MINIMAX, ALPHA_BETA, MCTS }

const ALGORITHM_NAMES := ["Minimax", "Minimax + α–β", "MCTS"]
const ALGORITHM_SHORT := ["MINIMAX", "α–β PRUNING", "MCTS"]
const ALGORITHM_NOTES := [
	"Searches every reply to a fixed depth and assumes the opponent plays its best counter.",
	"Same decision as Minimax, but skips branches that cannot beat the best move found so far.",
	"Runs many random playouts and focuses trials on promising moves using UCT.",
]
const MODE_NAMES := ["AI vs AI", "Human vs AI"]

const DEPTH_RANGE := Vector2i(1, 6)
const DEPTH_STEP := 1
const ITERATION_RANGE := Vector2i(100, 2000)
const ITERATION_STEP := 100
const DEFAULT_DEPTH := 3
const DEFAULT_ITERATIONS := 300
const DECISION_INTERVAL_SECONDS := 0.75

static var mode: Mode = Mode.AI_VS_AI
## Indexed by GameConstants.Team. Defaults follow the design: Blue α–β, Red MCTS.
static var algorithms: Array[Algorithm] = [Algorithm.ALPHA_BETA, Algorithm.MCTS]
static var search_depth: Array[int] = [DEFAULT_DEPTH, DEFAULT_DEPTH]
static var mcts_iterations: Array[int] = [DEFAULT_ITERATIONS, DEFAULT_ITERATIONS]

static func reset() -> void:
	mode = Mode.AI_VS_AI
	algorithms = [Algorithm.ALPHA_BETA, Algorithm.MCTS]
	search_depth = [DEFAULT_DEPTH, DEFAULT_DEPTH]
	mcts_iterations = [DEFAULT_ITERATIONS, DEFAULT_ITERATIONS]

## In Human vs AI the player commands Blue and Red is the AI opponent.
static func is_human(team: int) -> bool:
	return mode == Mode.HUMAN_VS_AI and team == GameConstants.Team.BLUE

static func set_algorithm(team: int, algorithm: Algorithm) -> void:
	algorithms[team] = algorithm

static func uses_depth(team: int) -> bool:
	return algorithms[team] != Algorithm.MCTS

## Adjusts the active search parameter (depth or iterations) by `steps` and clamps it.
static func adjust_parameter(team: int, steps: int) -> void:
	if uses_depth(team):
		search_depth[team] = clampi(search_depth[team] + steps * DEPTH_STEP, DEPTH_RANGE.x, DEPTH_RANGE.y)
	else:
		mcts_iterations[team] = clampi(mcts_iterations[team] + steps * ITERATION_STEP, ITERATION_RANGE.x, ITERATION_RANGE.y)

static func parameter_name(team: int) -> String:
	return "Search depth" if uses_depth(team) else "Iterations"

static func parameter_value(team: int) -> int:
	return search_depth[team] if uses_depth(team) else mcts_iterations[team]

## e.g. "Minimax + α–β · depth 3" or "MCTS · 300 iterations", or "Human player".
static func describe(team: int) -> String:
	if is_human(team):
		return "Human player"
	var detail := "depth %d" % search_depth[team] if uses_depth(team) else "%d iterations" % mcts_iterations[team]
	return "%s  ·  %s" % [ALGORITHM_NAMES[algorithms[team]], detail]
