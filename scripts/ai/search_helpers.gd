class_name SearchHelpers
extends RefCounted
## These five functions have the same roles as in the supplied Tic-Tac-Toe samples.

static func player(state: GameState) -> int:
	return state.next_team

static func actions(state: GameState) -> Array:
	return BattleRules.actions(state)

static func result(state: GameState, move: Dictionary) -> GameState:
	var child: GameState = state.copy_state()
	var applied: bool = BattleRules.apply_action(child, move)
	assert(applied, "A search may only expand a legal action.")
	if not applied:
		return child
	BattleRules.check_terminal(child)
	BattleRules.advance_interval(child)
	child.next_team = GameConstants.opponent(state.next_team)
	return child

static func terminal(state: GameState) -> bool:
	return state.winner != GameConstants.UNDECIDED

static func utility(state: GameState, root_team: int, weights: Dictionary) -> float:
	return BattleEvaluation.breakdown(state, root_team, weights).score
