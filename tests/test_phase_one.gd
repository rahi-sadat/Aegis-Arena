extends SceneTree
## Dependency-free headless checks for Phase 1 resources, scene wiring, HP, and results.

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main/Main.tscn")
	_check(scene != null, "Main scene loads")
	if scene == null:
		quit(1)
		return
	var main: Node = scene.instantiate()
	root.add_child(main)
	var manager: GameManager = main.get_node("GameManager")
	# Advance time explicitly below so the checks do not depend on machine speed.
	manager.set_process(false)
	var participants: Array[ArenaStructure] = manager.structures.duplicate()
	_check(participants.size() == 6, "Six structures are present")
	_check(manager.remaining_match_time == 180.0, "Configured match duration is 180 seconds")
	_check(manager.total_remaining_hp() == [1800.0, 1800.0], "Each side starts with 1800 combined HP")
	for team_id in [GameConstants.Team.BLUE, GameConstants.Team.RED]:
		var guards: int = 0
		var cores: int = 0
		for structure in participants:
			if structure.team_id != team_id:
				continue
			if structure.data.structure_type == StructureData.Kind.CORE:
				cores += 1
				_check(structure.max_hp == 800.0, "Core resource has 800 HP")
			else:
				guards += 1
				_check(structure.max_hp == 500.0, "Guard resource has 500 HP")
		_check(guards == 2 and cores == 1, "Team has exactly two guards and one core")

	var blue_guard: ArenaStructure = main.get_node("Structures/BlueLeftGuard")
	var red_core: ArenaStructure = main.get_node("Structures/RedCore")
	_check(manager.damage_structure(&"blue_left_guard", -100.0) == 0.0, "Negative damage cannot heal")
	_check(manager.damage_structure(&"blue_left_guard", NAN) == 0.0, "Non-finite damage is rejected")
	_check(manager.damage_structure(&"missing", 100.0) == 0.0, "Unknown structure is rejected")
	_check(manager.damage_structure(&"blue_left_guard", 200.0) == 200.0, "Damage returns actual HP lost")
	_check(blue_guard.current_hp == 300.0, "Damage changes live HP")
	_check(manager.structure_damage_dealt[1] == 200.0, "Damage is credited to the enemy commander")
	_check(manager.damage_structure(&"blue_left_guard", 1000.0) == 300.0, "Overkill is clamped to remaining HP")
	_check(blue_guard.is_destroyed and blue_guard.current_hp == 0.0, "Destroyed guard remains at zero HP")
	_check(manager.is_running, "Guard destruction does not end the match")
	_check(manager.damage_structure(&"blue_left_guard", 100.0) == 0.0, "Destroyed structures reject repeated damage")
	_check(blue_guard.take_damage(-100.0) == 0.0 and blue_guard.is_destroyed, "Destroyed structures cannot heal")
	_check(manager.structure_damage_dealt[1] == 500.0, "Overkill/repeated damage cannot inflate the tie-break total")

	manager.toggle_pause()
	var paused_time: float = manager.remaining_match_time
	manager._process(25.0)
	_check(manager.remaining_match_time == paused_time, "Pause freezes the timer")
	_check(manager.damage_structure(&"red_core", 100.0) == 0.0, "Pause blocks debug damage")
	manager.toggle_pause()
	manager._process(0.75)
	_check(manager.remaining_match_time == paused_time - 0.75, "Timer advances after resume")
	manager.damage_structure(&"red_core", 1000.0)
	_check(red_core.is_destroyed, "Core reaches destroyed state")
	_check(not manager.is_running and manager.winner == GameConstants.Team.BLUE, "Red core destruction immediately awards Blue victory")
	_check(manager.result["reason"] == "CORE DESTROYED", "Core result records the reason")
	var ended_time: float = manager.remaining_match_time
	manager._process(50.0)
	_check(manager.remaining_match_time == ended_time, "Terminal matches stop the timer")
	_check(manager.damage_structure(&"blue_core", 1000.0) == 0.0, "Terminal matches block further damage")
	_check(main.get_node("HUD/Interface/MatchResultPanel").visible, "Result panel appears on victory")
	_check(main.get_node("HUD").timer_label.text == "03:00", "Timer display rounds remaining time upward")

	manager.start_match(participants)
	_check(not red_core.is_destroyed and red_core.current_hp == red_core.max_hp, "Restart restores destroyed cores")
	_check(manager.winner == GameConstants.UNDECIDED and manager.structure_damage_dealt == [0.0, 0.0], "Restart clears result and damage totals")
	_check(not main.get_node("HUD/Interface/MatchResultPanel").visible, "Restart hides the result panel")
	manager.damage_structure(&"blue_core", 1000.0)
	_check(manager.winner == GameConstants.Team.RED, "Blue core destruction immediately awards Red victory")

	manager.start_match(participants)
	manager.damage_structure(&"blue_left_guard", 1.0)
	manager._process(180.0)
	_check(manager.remaining_match_time == 0.0, "Timer clamps to zero")
	_check(manager.winner == GameConstants.Team.RED, "Timeout awards higher remaining structure HP percentage")
	_check(manager.result["reason"] == "TIME EXPIRED", "Timeout result records the reason")
	_check(manager.result["elapsed_seconds"] == 180.0, "Timeout duration is exactly the configured duration")
	manager.start_match(participants)
	manager._process(200.0)
	_check(manager.winner == GameConstants.DRAW, "Untouched timeout is a draw")
	manager.start_match(participants)
	manager.damage_structure(&"red_right_guard", 100.0)
	manager.damage_structure(&"blue_right_guard", 100.0)
	manager._process(180.0)
	_check(manager.winner == GameConstants.DRAW, "Equal partial HP and damage is a draw")

	# Pure numeric fixtures cover tie-breaks and unequal starting totals without healing.
	_check(MatchRules.timeout_winner([500.0, 1000.0], [1000.0, 4000.0], [0.0, 1000.0]) == GameConstants.Team.BLUE, "Percentage, rather than raw HP or damage, has priority")
	_check(MatchRules.timeout_winner([900.0, 900.0], [1800.0, 1800.0], [400.0, 300.0]) == GameConstants.Team.BLUE, "Equal HP percentages use Blue damage tie-break")
	_check(MatchRules.timeout_winner([900.0, 900.0], [1800.0, 1800.0], [300.0, 400.0]) == GameConstants.Team.RED, "Equal HP percentages use Red damage tie-break")
	_check(MatchRules.timeout_winner([0.0, 0.0], [1800.0, 1800.0], [0.0, 0.0]) == GameConstants.DRAW, "Equal numeric fixture returns a draw")
	_check(MatchRules.remaining_fraction(0.0, 0.0) == 0.0, "Zero denominator is handled")
	# Let the deferred container layout and drawing run at least once as a UI smoke check.
	await process_frame
	await process_frame
	print("Phase 1: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
