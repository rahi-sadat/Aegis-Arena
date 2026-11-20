extends SceneTree
## Genuine decisions must update the viewer; held views and rendering stay read-only.

var checks: int = 0
var failures: int = 0
var rendered: bool = false
const FOLDER := "res://output/evidence/decision_lab"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(100).timeout.connect(func() -> void: push_error("Decision lab timed out"); quit(1))
	rendered = DisplayServer.get_name() != "headless"
	if rendered:
		root.set_flag(Window.FLAG_BORDERLESS, true)
		root.position = Vector2i.ZERO
		root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FOLDER))
	MatchConfig.reset()
	MatchConfig.autoplay_enabled = false
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	var manager: GameManager = main.game_manager
	var ai: AIManager = main.ai_manager
	var view: SearchTreeView = main.search_tree
	manager.set_process(false)
	ai.logging_enabled = false
	MatchConfig.autoplay_enabled = true
	manager.start_match(manager.structures)
	for frame in 500:
		if not manager.is_preparing:
			break
		await process_frame
	view.show()
	view.show_team(0)
	_check(not view.trace.is_empty(), "Live lab reads the actual first commander decision")
	var first_tick: int = view.trace.root_snapshot.tick_index
	await _ticks(manager, 60)
	view._poll()
	_check(view.trace.root_snapshot.tick_index > first_tick, "The graph updates automatically to a newer decision snapshot")
	_check(view.trace.algorithm == "Minimax + alpha-beta", "Blue graph uses the selected real agent")
	_check(ai.missed_slots == 0, "Rendering the lab does not miss deployment slots")
	if rendered:
		await _capture("live_alpha_beta")
	view.set_follow(false)
	var held: Dictionary = view.trace.duplicate(true)
	var decisions: int = ai.decisions
	await _ticks(manager, 60)
	_check(view.trace == held and ai.decisions > decisions, "Holding the tree keeps a stable snapshot while the game continues")
	if held.has("decision_id"):
		_check(view._records[view._history.selected].decision_id == held.decision_id, "The history dropdown stays on the held decision as new decisions arrive")
	view.set_follow(true)
	_check(view.trace.root_snapshot.tick_index > held.root_snapshot.tick_index, "Resume Live immediately catches up to the current search")
	view.set_follow(false)
	var branching: Dictionary = ai.history[0][0]
	view.set_trace(branching)
	view._branch.select(1)
	view._layout_tree()
	_check(view._shown.size() == branching.nodes.size(), "Full tree shows every recorded node, beyond the old fixed two-ply layout")
	for node: Dictionary in view._shown:
		_check(node.parent < 0 or view._rects.has(node.parent), "Every displayed node has its genuine parent edge")
	var leaf: Dictionary = {}
	for node: Dictionary in branching.nodes:
		if node.has("features"):
			leaf = node
			break
	view._show_details(leaf)
	_check(view._details.text.contains("LEAF SCORE") and view._details.text.contains("Total ="), "A genuine evaluated leaf exposes its weighted score calculation")
	view._branch.select(2)
	view._layout_tree()
	view._fit()
	if rendered:
		await _capture("expanded_alpha_beta_branch")
	var before: Dictionary = manager.battle_state.to_dictionary()
	view._set_tab(1)
	view._refresh_fuzzy()
	_check(view._fuzzy.assessment == branching.assessment, "Decision fuzzy view uses exactly the saved agent assessment")
	for index in 3:
		_check(view._fuzzy._calculations[index].text.contains("FIRING") and view._fuzzy._calculations[index].text.contains(" = "), "Fuzzy membership, rule strength and arithmetic are visible")
	if rendered:
		await _capture("fuzzy_decision_calculation")
	view._live_field = true
	view._refresh_fuzzy()
	_check(view._fuzzy.assessment == TacticalFuzzy.assess(manager.battle_state, 0), "Live field assessment is separately labelled and matches the actual current model")
	_check(manager.battle_state.to_dictionary() == before, "Tree and fuzzy inspection never alter battle state")
	if rendered:
		await _capture("fuzzy_live_calculation")
	view._live_field = false
	view._set_tab(0)
	view.show_team(1)
	view.set_follow(false)
	view.set_trace(ai.last_traces[1])
	_check(view.trace.algorithm == "MCTS" and view.trace.nodes.size() > 1, "Red view receives the actual generated MCTS tree")
	var red_record: Dictionary = view.trace.duplicate(true)
	var visit_sum: int = 0
	for node: Dictionary in red_record.nodes:
		if node.parent == 0:
			visit_sum += node.visits
	_check(visit_sum == red_record.stats.iterations_completed, "MCTS root child counts match the actual completed trial budget")
	view._branch.select(1)
	view._layout_tree()
	view._fit()
	view._show_details(red_record.nodes[1])
	_check(view._details.text.contains("UCT") and view._details.text.contains("Backup"), "MCTS shows real visit/UCT, rollout and backpropagation arithmetic")
	if rendered:
		await _capture("live_mcts_statistics")
	# Unit-test partial telemetry with a copy of a real trace, never fake gameplay.
	var adapter := AIManager.new()
	var agent := MCTSAgent.new()
	agent.trace = red_record.duplicate(true)
	agent.trace.nodes = []
	agent.trace.erase("complete")
	agent.trace.erase("selected_action")
	adapter._agent = agent
	var source_before: Dictionary = agent.trace.duplicate(true)
	var partial: Dictionary = LiveDecisionFeed.snapshot(LiveDecisionFeed.sample(adapter, 1))
	_check(partial.view_phase == "SEARCHING" and partial.view_partial and not partial.nodes.is_empty(), "In-progress MCTS is reconstructed only from real sampled telemetry")
	_check(agent.trace == source_before, "The live adapter cannot modify the agent trace")
	adapter._agent = null
	adapter.free()
	if rendered:
		root.size = Vector2i(1280, 720)
		await _capture("decision_lab_1280")
	manager.start_match(manager.structures)
	_check(view._history.item_count == 0 and view.trace.is_empty(), "Restart clears previous-match history and held graph")
	_check(view._fuzzy.assessment.is_empty(), "Restart also clears the previous match's fuzzy calculations")
	MatchConfig.algorithms[0] = MatchConfig.Algorithm.MINIMAX
	manager.start_match(manager.structures)
	for frame in 500:
		if not manager.is_preparing:
			break
		await process_frame
	view.show_team(0)
	_check(view.trace.algorithm == "Minimax" and not view.trace.nodes.is_empty(), "Plain Minimax also generates a real live tree through the same frontend")
	if rendered:
		await _capture("live_minimax")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	main._input(escape)
	_check(not view.visible and not manager.is_paused, "Escape closes the inspector without changing simulation pause")
	manager.damage_structure(&"red_core", 800)
	view.show()
	_check(main.hud.result_panel.visible and main.hud.interface.get_child(-1) == view, "Teachers can inspect the graph above the result screen after a match")
	ai.cancel()
	ai.enabled = false
	for frame in 20:
		await process_frame
	main.queue_free()
	await process_frame
	MatchConfig.autoplay_enabled = false
	_check(change_scene_to_file("res://scenes/ui/screens/LoadingScreen.tscn") == OK, "Boot loading scene opens")
	await scene_changed
	if rendered:
		root.size = Vector2i(1920, 1080)
		await _capture("loading_screen", false)
	await _wait_scene("TitleScreen")
	_check(current_scene.name == "TitleScreen", "Actual threaded boot loading reaches the home page")
	if rendered:
		await _capture("home_page")
	_press(current_scene, "PLAY")
	await _wait_scene("PreBattleScreen")
	_check(current_scene.name == "PreBattleScreen", "Home Play loads the setup scene through the frontend transition")
	if rendered:
		await _capture("battle_setup")
	print("Decision lab: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _ticks(manager: GameManager, count: int) -> void:
	for tick in count:
		manager._process(BattleRules.TICK_SECONDS)
		for frame in 3:
			await process_frame

func _wait_scene(scene_name: String) -> void:
	for frame in 1200:
		if current_scene != null and current_scene.name == scene_name:
			return
		await process_frame
	_check(false, "Scene transition finishes: " + scene_name)

func _capture(filename: String, settle: bool = true) -> void:
	if settle:
		await create_timer(0.25).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	_check(frame != null and not frame.is_empty() and frame.save_png(FOLDER.path_join(filename + ".png")) == OK, "Rendered screenshot saves: " + filename)

func _press(from: Node, caption: String) -> void:
	for child in from.get_children():
		if child is Button and child.text == caption:
			child.pressed.emit()
			return
		_press(child, caption)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
