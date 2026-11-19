extends SceneTree
## Real rendered gameplay, mouse-driven human deployment, and screenshot evidence.

var checks: int = 0
var failures: int = 0
var folder: String = "res://output/evidence/screenshots"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this check without --headless so it can inspect real rendering.")
		quit(1)
		return
	create_timer(90.0).timeout.connect(func() -> void: push_error("Graphical capture timed out"); quit(1))
	root.set_flag(Window.FLAG_BORDERLESS, true)
	root.position = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	MatchConfig.reset()
	MatchConfig.autoplay_enabled = false
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var manager: GameManager = main.get_node("GameManager")
	var ai: AIManager = main.get_node("AIManager")
	var hud: ArenaHUD = main.get_node("HUD")
	ai.export_directory = "res://output/evidence/live_demo"
	MatchConfig.autoplay_enabled = true
	manager.start_match(manager.structures)
	await create_timer(9.0).timeout
	manager.set_process(false)
	_check(ai.decisions >= 9 and manager.remaining_match_time < 174, "Rendered real-time AI match deploys through multiple slots")
	_check(manager.battle_state.next_unit_id > 5, "The rendered match contains real deployments")
	_check(ai.missed_slots == 0, "Default live searches meet their slots while graphics render")
	var rendered_misses: int = ai.missed_slots
	await _capture("live_battle")
	main.battle_view.show_routes = true
	await _capture("astar_routes")
	main.battle_view.show_routes = false
	main.search_tree.show()
	main.search_tree.show_team(0)
	_check(not main.search_tree.trace.is_empty(), "Blue tree viewer receives an actual trace")
	for node: Dictionary in main.search_tree._shown:
		if node.has("features"):
			main.search_tree._show_details(node)
			main.search_tree._details.scroll_to_line(5)
			break
	await _capture("alpha_beta_tree")
	main.search_tree.show_team(1)
	main.search_tree._details.scroll_to_line(5)
	_check(main.search_tree.trace.algorithm == "MCTS", "Red tree viewer receives MCTS visit statistics")
	await _capture("mcts_tree")
	main._export_traces()
	main.search_tree.hide()
	_check(ai.export_latest() == OK, "Live decision JSON exports")
	DecisionTrace.export_json(manager.battle_state.to_dictionary(), "res://output/evidence/live_demo/snapshot.json")
	MatchConfig.mode = MatchConfig.Mode.HUMAN_VS_AI
	ai.export_directory = "res://output/evidence/human_demo"
	manager.start_match(manager.structures)
	await process_frame
	var fighter: BattleCardSlot = hud.deck.get_node("Fighter")
	_mouse_click(fighter)
	_check(hud._selected_card == 0, "A real mouse click selects the human Fighter card")
	_mouse_click(hud._lane_buttons[0])
	_check(ai.queued_human_action == CardData.action(0, 0), "A real mouse click on LEFT queues deployment")
	for tick in 30:
		manager._process(BattleRules.TICK_SECONDS)
		for frame in 3:
			await process_frame
	_check(ai.last_traces[0].execution.action == CardData.action(0, 0), "The mouse-selected card really deploys at Blue's slot")
	await _capture("human_deployment")
	print("Rendered gameplay: %d checks, %d failures; %d missed slots" % [checks, failures, rendered_misses + ai.missed_slots])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)

func _mouse_click(control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and not frame.is_empty(), "Frame is rendered for " + name)
	if frame != null and not frame.is_empty():
		_check(frame.save_png(folder.path_join(name + ".png")) == OK, "Screenshot saved for " + name)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
