extends SceneTree
## Presentation regression checks; numeric rules are deliberately unchanged.

var checks: int = 0
var failures: int = 0
var folder: String = "res://output/evidence/ui_refresh"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(90).timeout.connect(func() -> void: push_error("UI refresh timed out"); quit(1))
	var rendered: bool = DisplayServer.get_name() != "headless"
	if rendered:
		root.set_flag(Window.FLAG_BORDERLESS, true)
		root.position = Vector2i.ZERO
		root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	MatchConfig.reset()
	MatchConfig.mode = MatchConfig.Mode.HUMAN_VS_AI
	MatchConfig.autoplay_enabled = false
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var manager: GameManager = main.game_manager
	var hud: ArenaHUD = main.hud
	var ai: AIManager = main.ai_manager
	manager.set_process(false)
	ai.logging_enabled = false
	MatchConfig.autoplay_enabled = true
	manager.start_match(manager.structures)
	await process_frame
	hud.select_live_card(0)
	_check(hud.planning_mode and manager.is_paused, "Selecting a ready human card pauses for planning")
	_check(not hud.pause_menu.visible and not hud._lane_buttons[0].disabled, "Planning keeps lane controls accessible without pause modal")
	var frozen: Dictionary = manager.battle_state.to_dictionary()
	manager._process(10.0)
	for frame in 10:
		await process_frame
	_check(manager.battle_state.to_dictionary() == frozen, "Thinking time freezes all numeric game state")
	_check(main.battle_view.show_deployment, "Planning reveals the fixed deployment markers")
	if rendered:
		await _capture("human_planning")
	hud.request_lane(0)
	_check(not manager.is_paused and not hud.planning_mode, "Choosing a lane resumes the live match")
	_check(ai.queued_human_action == CardData.action(0, 0) and manager.battle_state.units.is_empty(), "Lane confirmation queues the original action without early spawning")
	main._begin_planning()
	main._queue_deployment(CardData.action(3, 1))
	_check(manager.is_paused and hud.planning_mode, "An illegal empty-lane spell leaves planning open")
	main._toggle_pause()
	_check(not manager.is_paused and not hud.planning_mode, "Normal resume can leave planning without deploying")
	manager.toggle_pause()
	_check(hud.pause_menu.visible, "Ordinary pause still opens the existing menu")
	manager.toggle_pause()
	# Real viewport input must reach the arena, including in a smaller window.
	if rendered:
		root.size = Vector2i(1280, 720)
		await process_frame
		_mouse_click(hud._cards[1].get_global_rect().get_center())
		_check(hud.planning_mode and hud._selected_card == 1, "A card click starts planning at 1280x720")
		_mouse_click(Vector2(ArenaLayout.LANE_X[1], 650))
		_check(not manager.is_paused and ai.queued_human_action == CardData.action(1, 1), "Clicking the arena queues the chosen card in the right lane")
		root.size = Vector2i(1920, 1080)
		await process_frame

	# Distinct visual fixtures: the actual numeric simulator advances their combat.
	ai.cancel()
	ai.enabled = false
	var state: GameState = manager.battle_state
	for card in 3:
		_check(TroopArt.portrait(card).atlas == TroopArt.SHEETS[card], "Card portrait uses its own matching troop sheet")
		for team in 2:
			state.next_team = team
			state.energy[team] = 10
			BattleRules.apply_action(state, CardData.action(card, card % 2))
			var unit: Dictionary = state.units[-1]
			# Spread roles along their legal lane routes around the river.
			unit.progress = 290.0 + card * 80 if team == 0 else 340.0 + card * 80
	state.next_team = 0
	state.energy[0] = 6.5
	state.cooldowns[0][3] = 6.1
	state.cooldowns[0][4] = 2.4
	manager._sync_display()
	await process_frame
	_check(main.battle_view.visuals.size() == 6, "Every live numeric unit receives its own visual")
	_check(hud._cards[3]._radial.visible and hud._cards[4]._radial.visible, "Cooling cards show circular countdown overlays")
	_check(not hud._cards[3]._cooldown.text.is_empty(), "Cooldown overlay includes the remaining seconds")
	for view: TroopVisual in main.battle_view.visuals.values():
		for row in 4:
			for column in 4:
				view._north = row % 2 == 0
				view._moving = true
				view._clock = (column + 0.1 - view.unit_id * 0.7) / (6 if view.card == 2 else 9)
				view._attack_left = view._attack_length * (1 - (column + 0.1) / 4.0) if row >= 2 else 0
				view._update_frame()
				_check(view.ground_anchor_error() < 0.01, "Animation frame keeps the feet on its ground anchor")
		view._attack_left = 0
		view._clock = 0
		view._moving = false
		view.animate(0.2, false)
	var before_fx: Dictionary = state.to_dictionary()
	for card in 3:
		var unit: Dictionary = state.units[card * 2]
		main.battle_view._show_attack({"kind": "unit", "index": card * 2 + 1,
			"damage": CardData.DAMAGE[card], "team": 0, "from_lane": unit.lane,
			"from_progress": unit.progress, "to_progress": state.units[card * 2 + 1].progress, "card": card})
	main.battle_view._on_action(CardData.action(3, 0), 0)
	main.battle_view._on_action(CardData.action(4, 1), 0)
	for kind in ["slash", "arrow", "slam", "fire", "rain"]:
		var found: bool = false
		for effect: Dictionary in main.battle_view.effects:
			found = found or effect.kind == kind
		_check(found, "Distinct combat feedback exists for " + kind)
	_check(state.to_dictionary() == before_fx, "Animation, spell effects and card rendering never change model state")
	if rendered:
		await _capture("distinct_troops_and_attacks")
	# Advance real combat to exercise live attack events and interpolation.
	for tick in 20:
		manager.last_attacks.append_array(BattleRules.advance_tick(state))
		manager._sync_display()
		for frame in 3:
			await process_frame
	_check(state.tick_index == 20 and state.units.size() > 0, "The refreshed visuals survive actual combat ticks")
	if rendered:
		await _capture("combat_after_ticks")
		root.size = Vector2i(1280, 720)
		await _capture("window_1280")
	print("UI refresh: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and not frame.is_empty(), "A real frame renders for " + filename)
	_check(frame.save_png(folder.path_join(filename + ".png")) == OK, "A real screenshot saves for " + filename)

func _mouse_click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
