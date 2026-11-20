extends SceneTree
## The real scene/controller pipeline, with explicit ticks for reproducible checks.

var checks: int = 0
var failures: int = 0
var captured: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(90.0).timeout.connect(func() -> void: push_error("Integration test timed out"); quit(1))
	MatchConfig.reset()
	MatchConfig.autoplay_enabled = false
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var manager: GameManager = main.get_node("GameManager")
	var ai: AIManager = main.get_node("AIManager")
	var hud: ArenaHUD = main.get_node("HUD")
	manager.set_process(false)
	ai.logging_enabled = false
	ai.decision_made.connect(func(record: Dictionary) -> void: captured.append(record))
	MatchConfig.autoplay_enabled = true
	manager.start_match(manager.structures)
	await _wait_preparation(manager)
	_check(ai.decisions == 1 and not manager.is_preparing, "First AI action completes before the live clock starts")
	_check(manager.remaining_match_time == 180.0 and manager.battle_state.next_team == 1, "Blue acts at time zero, then Red is next")
	manager._process(2.0)
	_check(manager.battle_state.tick_index == 1, "A long preparation/rendering frame cannot consume the first opponent planning window")
	await _ticks(manager, 119)
	_check(ai.decisions == 9, "Eight alternating slots follow the initial deployment")
	_check(manager.battle_state.tick_index == 120 and manager.remaining_match_time == 174, "The live numeric clock runs during search")
	_check(manager.battle_state.next_unit_id > 3, "Both agents actually deploy units")
	for record: Dictionary in captured:
		_check(record.complete and record.execution.accepted, "Default live agent finishes and executes a legal decision")
		_check(record.execution.predicted_state_matched, "The prepared future snapshot matches the actual slot state")
	_check(ai.missed_slots == 0, "Default budgets meet the live deployment slots")
	manager.toggle_pause()
	var paused: Dictionary = manager.battle_state.to_dictionary()
	manager._process(25.0)
	for frame in 25:
		await process_frame
	_check(manager.battle_state.to_dictionary() == paused, "Pause freezes combat, energy, cooldowns, and deployments")
	manager.toggle_pause()
	manager.damage_structure(&"red_left_guard", 1.0)
	await _ticks(manager, 30)
	_check(captured[-1].execution.predicted_state_matched, "Debug damage invalidates and rebuilds the prepared search snapshot")
	manager.damage_structure(&"red_core", 800.0)
	_check(not manager.is_running and ai._agent == null, "Core defeat stops the game and cancels outstanding planning")
	var ended: Dictionary = manager.battle_state.to_dictionary()
	await _ticks(manager, 10)
	_check(manager.battle_state.to_dictionary() == ended, "Finished matches accept no later deployment")
	MatchConfig.mode = MatchConfig.Mode.HUMAN_VS_AI
	manager.start_match(manager.structures)
	_check(manager.battle_state.units.is_empty() and manager.battle_state.energy[0] == 10, "Human opening defaults to Wait with full energy")
	_check(hud.blue.logic_label.text.contains("Human player") and hud.insight._team == 1, "Restart refreshes the human badge and follows the actual AI commander")
	main.search_tree.show_team(1)
	var fresh_view: Dictionary = main.search_tree.trace
	_check(main.search_tree._history.item_count == 0 and (fresh_view.is_empty() or fresh_view.root_snapshot.tick_index == BattleRules.TICKS_PER_DECISION), "Restart clears old history; live view may show only the new match's first pending decision")
	var fighter: BattleCardSlot = hud.deck.get_node("Fighter")
	_check(not fighter.disabled, "An affordable human card is enabled")
	fighter.pressed.emit()
	hud.request_lane(0)
	_check(ai.queued_human_action == CardData.action(0, 0) and manager.battle_state.units.is_empty(), "Card and lane controls queue one action without early deployment")
	await _ticks(manager, 30)
	_check(ai.last_traces[0].algorithm == "Human" and ai.last_traces[0].execution.action == CardData.action(0, 0), "Queued human action executes at the next Blue slot")
	_check(is_equal_approx(manager.battle_state.energy[0], 7.0) and fighter.disabled, "Human deployment spends energy and locks the cooling card")
	var preview_before: Dictionary = manager.battle_state.to_dictionary()
	var queued_before: Dictionary = ai.queued_human_action.duplicate()
	hud.toggle_preview()
	fighter.pressed.emit()
	_check(manager.battle_state.to_dictionary() == preview_before and ai.queued_human_action == queued_before, "Preview card inspection cannot queue a real deployment")
	hud.toggle_preview()
	_check(is_equal_approx(hud.energy._value, manager.battle_state.energy[0]), "Leaving preview restores the live energy display")
	manager.toggle_pause()
	_check(not ai.queue_human_action(CardData.wait_action()), "Paused matches reject human deployment requests")
	manager.toggle_pause()
	# Restart a different algorithm configuration and allow a complete short match.
	ai.cancel()
	MatchConfig.mode = MatchConfig.Mode.AI_VS_AI
	MatchConfig.algorithms = [MatchConfig.Algorithm.MINIMAX, MatchConfig.Algorithm.MINIMAX]
	MatchConfig.search_depth = [1, 1]
	manager.balance = manager.balance.duplicate()
	manager.balance.match_duration_seconds = 3.0
	manager.start_match(manager.structures)
	await _wait_preparation(manager)
	await _ticks(manager, 60)
	_check(not manager.is_running and manager.remaining_match_time == 0, "A complete scheduled AI match reaches its timeout result")
	_check(ai.last_traces[0].algorithm == "Minimax" and ai.last_traces[1].algorithm == "Minimax", "Both commanders run the actual selected algorithm")
	_check(manager.result.reason == "TIME EXPIRED" and hud.result_panel.visible, "The real result screen follows the numeric result")
	MatchConfig.reset()
	manager.balance.match_duration_seconds = 180.0
	manager.start_match(manager.structures)
	await _wait_preparation(manager)
	_check(ai._agent != null, "Scene exit is tested while the next AI is actively planning")
	main.queue_free()
	for frame in 30:
		await process_frame
	MatchConfig.reset()
	MatchConfig.autoplay_enabled = true
	print("Integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _wait_preparation(manager: GameManager) -> void:
	for frame in 300:
		if not manager.is_preparing:
			return
		await process_frame
	_check(false, "First deployment finishes")

func _ticks(manager: GameManager, count: int) -> void:
	for tick in count:
		manager._process(BattleRules.TICK_SECONDS)
		# Three render frames per 0.05-second tick models a 60 Hz display.
		for frame in 3:
			await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
