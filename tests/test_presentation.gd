extends SceneTree
## Exercises Phase 1 through the UI. --capture <directory> <WxH> also saves rendered PNGs.

const TITLE := "res://scenes/ui/screens/TitleScreen.tscn"

var _checks := 0
var _failed := 0
var _capture_path := ""
var _capture_size := Vector2i.ZERO

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 3 and arguments[0] == "--capture":
		_capture_path = arguments[1]
		var extent := arguments[2].split("x")
		if extent.size() == 2:
			_capture_size = Vector2i(extent[0].to_int(), extent[1].to_int())
	call_deferred("_run")

func _run() -> void:
	create_timer(30.0).timeout.connect(_watchdog)
	if not _capture_path.is_empty():
		if _capture_size.x <= 0 or _capture_size.y <= 0 or DisplayServer.get_name() == "headless":
			push_error("Capture requires a graphical runtime and a positive WxH size.")
			quit(1)
			return
		root.set_flag(Window.FLAG_BORDERLESS, true)
		root.position = Vector2i.ZERO
		root.size = _capture_size
	_check(change_scene_to_file(TITLE) == OK, "Title scene loads")
	await scene_changed
	await _capture("title")
	_press(current_scene, "HOW TO PLAY")
	_press(current_scene, "BACK")
	_press(current_scene, "SETTINGS")
	var title_settings: ArenaSettingsPanel = _find_panel(current_scene, "SettingsPanel")
	_check(title_settings != null and title_settings.visible, "Title settings open")
	_press(title_settings, "DONE")
	_press(current_scene, "PLAY")
	await scene_changed
	_check(current_scene.name == &"PreBattleScreen", "Play advances to battle setup")
	MatchConfig.reset()
	var setup := current_scene
	_check(MatchConfig.algorithms == [MatchConfig.Algorithm.ALPHA_BETA, MatchConfig.Algorithm.MCTS], "Default commanders are α–β and MCTS")
	_named(setup, "BlueAlgorithm2").pressed.emit()
	_check(MatchConfig.algorithms[GameConstants.Team.BLUE] == MatchConfig.Algorithm.MCTS, "Blue algorithm can be switched to MCTS")
	_named(setup, "BlueIncrease").pressed.emit()
	_check(MatchConfig.mcts_iterations[GameConstants.Team.BLUE] == MatchConfig.DEFAULT_ITERATIONS + MatchConfig.ITERATION_STEP, "MCTS iterations increase")
	_named(setup, "RedAlgorithm0").pressed.emit()
	_check(MatchConfig.algorithms[GameConstants.Team.RED] == MatchConfig.Algorithm.MINIMAX, "Red algorithm can be switched to Minimax")
	for step in 10:
		_named(setup, "RedDecrease").pressed.emit()
	_check(MatchConfig.search_depth[GameConstants.Team.RED] == MatchConfig.DEPTH_RANGE.x and _named(setup, "RedDecrease").disabled, "Search depth clamps at its minimum")
	_named(setup, "Mode1").pressed.emit()
	_check(MatchConfig.mode == MatchConfig.Mode.HUMAN_VS_AI and _named(setup, "BlueAlgorithm0").disabled, "Human vs AI hands Blue to the player")
	_named(setup, "Mode0").pressed.emit()
	_check(MatchConfig.mode == MatchConfig.Mode.AI_VS_AI and not _named(setup, "BlueAlgorithm0").disabled, "AI vs AI restores both search commanders")
	MatchConfig.reset()
	_named(setup, "Mode0").pressed.emit()
	await _capture("pre-battle")
	_press(current_scene, "ENTER BATTLE")
	await scene_changed
	_check(current_scene.name == &"Main", "Setup launches the actual Main scene")
	var manager: GameManager = current_scene.get_node("GameManager")
	var hud: ArenaHUD = current_scene.get_node("HUD")
	manager.set_process(false)
	_check(hud.timer_label.text == "03:00", "HUD shows the live countdown")
	_check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "The arena preserves its aspect ratio")
	_check(hud.minimap.visible and hud.insight.visible, "Minimap and AI Insight load")
	var fighter: BattleCardSlot = hud.deck.get_node("Fighter")
	_check(fighter.disabled, "Cards are locked in live mode")
	_check(hud.blue.logic_label.text.contains("Minimax + α–β") and hud.red.logic_label.text.contains("MCTS"), "Commander badges show the selected algorithms")
	await _capture("battle")

	var minimap_height := hud.minimap.size.y
	_press(hud.minimap, "−")
	_check(hud.minimap.size.y < minimap_height, "Minimap collapses")
	_press(hud.minimap, "+")
	_check(hud.minimap.size.y == minimap_height, "Minimap expands")
	var insight_height := hud.insight.size.y
	_press(hud.insight, "−")
	_check(hud.insight.size.y < insight_height, "AI Insight collapses")
	_press(hud.insight, "+")
	_check(hud.insight.size.y == insight_height, "AI Insight expands")

	for structure in manager.structures:
		manager.damage_structure(structure.structure_id, 25.0)
		_check(structure.health_label.text == "%d / %d HP" % [structure.max_hp - 25, structure.max_hp],
			"Live tower indicator updates for " + structure.structure_id)

	manager._process(46.0)
	_check(hud.timer_label.text == "02:14", "HUD follows the actual match clock")
	var hp_before := manager.total_remaining_hp()
	var damage_before := manager.structure_damage_dealt.duplicate()
	var time_before := manager.remaining_match_time
	_key(KEY_F4)
	_check(hud.preview_enabled and hud.preview.visible, "F4 opens developer preview")
	_check(not fighter.disabled, "Preview card inspection is enabled")
	fighter.pressed.emit()
	_check(hud.preview_enabled and manager.total_remaining_hp() == hp_before
		and manager.structure_damage_dealt == damage_before and manager.remaining_match_time == time_before
		and manager.is_running and manager.winner == GameConstants.UNDECIDED, "Preview leaves live match state unchanged")
	await _capture("battle-preview")
	_key(KEY_F4)
	_check(not hud.preview_enabled and fighter.disabled, "F4 returns to live presentation")
	_key(KEY_R)
	_check(manager.total_remaining_hp() == [1800.0, 1800.0], "R resets structure damage")

	_key(KEY_F3)
	_check(hud.debug_visible, "F3 toggles debug damage")
	var red_core: ArenaStructure = current_scene.get_node("Structures/RedCore")
	var button: Button = hud._debug_rows[red_core.structure_id].button
	_key(KEY_SPACE)
	_check(manager.is_paused and hud.pause_menu.visible and button.disabled, "Space pauses and locks damage")
	await _capture("pause")
	_press(hud.pause_menu, "SETTINGS")
	_check(hud.settings.visible and manager.is_paused, "Pause settings retain pause")
	var map_toggle := _find_button(hud.settings, "Show minimap")
	map_toggle.button_pressed = false
	_check(not hud.minimap.visible, "Settings can hide the minimap")
	map_toggle.button_pressed = true
	_check(hud.minimap.visible, "Settings can show the minimap")
	_key(KEY_ESCAPE)
	_check(not hud.settings.visible and manager.is_paused, "Escape closes settings")
	_press(hud.pause_menu, "RESUME")
	_check(not manager.is_paused and not hud.pause_menu.visible and not button.disabled, "Resume re-enables damage")
	button.pressed.emit()
	_check(red_core.current_hp == 700.0, "The debug HUD button routes damage to GameManager")
	for hit in 7:
		button.pressed.emit()
	_check(red_core.is_destroyed and red_core.get_node("TowerArt").texture == red_core.red_ruin, "Destroyed core uses ruin artwork")
	_check(hud.result_panel.visible and manager.winner == GameConstants.Team.BLUE, "Core destruction opens the victory screen")
	await _capture("result")
	_press(hud.result_panel, "RESTART  [R]")
	_check(not hud.result_panel.visible and red_core.current_hp == 800.0, "Result screen restarts the match")
	_key(KEY_SPACE)
	_press(hud.pause_menu, "RETURN TO TITLE")
	await scene_changed
	_check(current_scene.name == &"TitleScreen", "Pause menu returns to the title")
	_press(current_scene, "GAME MODES")
	await scene_changed
	_check(current_scene.name == &"PreBattleScreen", "Game Modes opens setup")
	_press(current_scene, "BACK TO TITLE")
	await scene_changed
	_check(current_scene.name == &"TitleScreen", "Setup returns to title")
	print("Presentation: %d checks, %d failures" % [_checks, _failed])
	quit(1 if _failed else 0)

func _capture(name: String) -> void:
	if _capture_path.is_empty():
		return
	await create_timer(0.28).timeout
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var target := _capture_path.path_join(name + ".png")
	_check(root.size == _capture_size, "Render window is %d × %d" % [_capture_size.x, _capture_size.y])
	if image == null or image.is_empty():
		_check(false, "Viewport image is available for " + name)
		return
	if image.get_size() != root.size:
		# The viewport texture excludes the window's letterbox margins.
		var framed := Image.create_empty(root.size.x, root.size.y, false, image.get_format())
		framed.fill(Color.BLACK)
		@warning_ignore("integer_division")
		var offset := (root.size - image.get_size()) / 2
		framed.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), offset)
		image = framed
	_check(image.save_png(target) == OK, "Saved " + target)

func _press(from: Node, caption: String) -> void:
	var button := _find_button(from, caption)
	_check(button != null and button.is_visible_in_tree() and not button.disabled, "Usable control " + caption)
	if button != null:
		button.pressed.emit()

func _find_button(from: Node, caption: String) -> Button:
	for child in from.get_children():
		if child is Button and child.text == caption:
			return child
		var match_button := _find_button(child, caption)
		if match_button != null:
			return match_button
	return null

func _named(from: Node, node_name: String) -> Button:
	var found := from.find_child(node_name, true, false) as Button
	_check(found != null, "Found control " + node_name)
	return found

func _find_panel(from: Node, panel_name: String) -> ArenaSettingsPanel:
	for child in from.get_children():
		if child is ArenaSettingsPanel and child.name == panel_name:
			return child
	return null

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failed += 1
		push_error("FAIL: " + description)

func _watchdog() -> void:
	push_error("Timed out during presentation checks.")
	quit(1)
