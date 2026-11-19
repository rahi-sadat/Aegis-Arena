extends SceneTree
## Numeric gameplay checks: these run the real rules, without a screen or an agent.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: GameState = GameState.create_default()
	_check(state.energy == [10.0, 10.0], "Both sides start at ten energy")
	_check(state.structures.size() == 6 and BattleRules.total_hp(state) == [1800.0, 1800.0], "Six structures and original HP totals")
	var path: Dictionary = ManualAStar.search({"width": 3, "height": 2, "blocked": {Vector2i(1, 0): true}}, Vector2i(0, 0), Vector2i(2, 0))
	_check(path.cost == 4 and path.path == [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0)], "A* finds the four-move obstacle detour")
	_check(ManualAStar.search({"width": 2, "height": 1, "blocked": {}}, Vector2i.ZERO, Vector2i.ZERO).cost == 0, "A* start equals goal")
	_check(ManualAStar.search({"width": 3, "height": 1, "blocked": {Vector2i(1, 0): true}}, Vector2i.ZERO, Vector2i(2, 0)).path.is_empty(), "A* handles no path")
	_check(ManualAStar.search({"width": 2, "height": 1, "blocked": {Vector2i(1, 0): true}}, Vector2i.ZERO, Vector2i(1, 0)).path.is_empty(), "A* rejects a blocked goal")
	for lane in 2:
		var route: PackedVector2Array = ArenaGrid.paths[lane]
		_check(not route.is_empty() and ArenaGrid.lengths[lane] > 500, "Arena lane has a real A* route")
		for point: Vector2 in route:
			if point.y >= ArenaLayout.RIVER_TOP and point.y <= ArenaLayout.RIVER_BOTTOM:
				_check(absf(point.x - ArenaLayout.LANE_X[lane]) <= ArenaLayout.BRIDGE_HALF_WIDTH, "River crossing stays on its own bridge")
	_check(not BattleRules.apply_action(state, CardData.action(99, 0)), "Invalid card rejected")
	_check(not BattleRules.apply_action(state, CardData.action(0, 7)), "Invalid lane rejected")
	_check(not BattleRules.apply_action(state, CardData.action(3, 0)), "An empty-lane spell is rejected")
	_check(state.energy[0] == 10 and state.units.is_empty(), "Rejected actions spend nothing")
	_check(BattleRules.apply_action(state, CardData.action(0, 0)), "Fighter actually deploys")
	_check(state.energy[0] == 7 and state.cooldowns[0][0] == 4 and state.units.size() == 1, "Deployment spends once and starts cooldown")
	_check(not BattleRules.apply_action(state, CardData.action(0, 1)), "The same card cannot bypass its cooldown in another lane")
	var child: GameState = state.copy_state()
	child.units[0].hp = 1.0
	child.cooldowns[0][0] = 0.0
	child.structures[0].hp = 1.0
	child.energy[0] = 0.0
	_check(state.units[0].hp == 120 and state.cooldowns[0][0] == 4 and state.structures[0].hp == 500 and state.energy[0] == 7, "Nested state copies do not mutate their parent")
	var before_progress: float = state.units[0].progress
	var routes_before: int = ArenaGrid.route_searches
	BattleRules.advance_interval(state)
	_check(is_equal_approx(state.energy[0], 7.75) and is_equal_approx(state.cooldowns[0][0], 3.25), "Energy and cooldown advance by 0.75 seconds")
	_check(state.units[0].progress > before_progress and state.tick_index == 15, "A live unit advances along the route")
	_check(ArenaGrid.route_searches == routes_before, "Numeric simulation never reruns A*")
	state.next_team = 1
	_check(BattleRules.apply_action(state, CardData.action(0, 0)), "Red can deploy independently")
	state.next_team = 0
	var towers_before: Array = BattleRules.total_hp(state)
	_check(BattleRules.apply_action(state, CardData.action(3, 0)), "Mage casts on an occupied enemy lane")
	_check(state.units[0].hp == 120 and state.units[1].hp == 40, "Mage damages enemy units only")
	_check(BattleRules.total_hp(state) == towers_before, "Spells do not damage structures")
	state.energy[0] = 10.0
	_check(BattleRules.apply_action(state, CardData.action(4, 0)) and state.units.size() == 1, "Arrow applies damage and removes a defeated enemy")
	state = GameState.create_default()
	for card in 3:
		state.energy[0] = 10.0
		_check(BattleRules.apply_action(state, CardData.action(card, card % 2)), "Unit card deploys: " + CardData.NAMES[card])
		_check(state.units[-1].hp == CardData.HP[card], "Unit has its shared card HP")
	state.energy[0] = 0.0
	_check(BattleRules.actions(state) == [CardData.wait_action()], "WAIT is legal when nothing is affordable")
	_check(BattleRules.apply_action(state, CardData.wait_action()), "WAIT costs no energy")
	state = GameState.create_default()
	for index in CardData.UNIT_CAP:
		state.units.append({"id": index + 1, "team": 0, "card": 0, "lane": 0, "progress": 50.0, "hp": 120.0, "attack_remaining": 0.0})
	_check(not BattleRules.rejection_reason(state, CardData.action(2, 0)).is_empty(), "Unit cap is enforced")
	state = GameState.create_default()
	BattleRules.apply_action(state, CardData.action(0, 0))
	state.units[0].progress = ArenaGrid.guard_progress[1][0] - 28.0
	var predicted: GameState = state.copy_state()
	BattleRules.advance_interval(predicted)
	for tick in 15:
		BattleRules.advance_tick(state)
	_check(state.to_dictionary() == predicted.to_dictionary(), "Fifteen live ticks match the forward model exactly")
	_check(state.structures[3].hp < 500 and state.units[0].hp < 120, "Units and towers really exchange damage")
	_check(state.structure_damage_dealt[0] == 500 - state.structures[3].hp, "Structure damage is credited exactly once")
	state = GameState.create_default()
	BattleRules.apply_action(state, CardData.action(0, 0))
	state.units[0].progress = ArenaGrid.lengths[0] - 28.0
	state.structures[5].hp = 10.0
	BattleRules.advance_tick(state)
	_check(state.winner == 0 and state.reason == "CORE DESTROYED", "Core damage from a real attack ends the match")
	_check(state.structure_damage_dealt[0] == 10, "Combat overkill counts only actual structure HP lost")
	var ended: Dictionary = state.to_dictionary()
	BattleRules.advance_tick(state)
	_check(state.to_dictionary() == ended, "A terminal state cannot advance")
	state = GameState.create_default()
	state.next_team = 0
	BattleRules.apply_action(state, CardData.action(0, 0))
	state.next_team = 1
	BattleRules.apply_action(state, CardData.action(0, 0))
	state.units[0].progress = ArenaGrid.lengths[0] - 28.0
	state.units[1].progress = 28.0
	state.structures[2].hp = 10.0
	state.structures[5].hp = 10.0
	BattleRules.advance_tick(state)
	_check(state.winner == GameConstants.DRAW and state.reason == "BOTH CORES DESTROYED", "Simultaneous core defeat is a draw")
	state = GameState.create_default(0.02)
	state.structures[0].hp = 499.0
	BattleRules.advance_tick(state)
	_check(state.remaining_time == 0 and state.winner == 1, "Timeout handles the final partial tick")
	print("Battle rules: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
