extends Node
## Scene wiring and input only. Numeric rules and search stay in their small modules.

const TITLE := "res://scenes/ui/screens/TitleScreen.tscn"

@onready var game_manager: GameManager = $GameManager
@onready var hud: ArenaHUD = $HUD
var ai_manager: AIManager
var battle_view: LiveBattleView
var search_tree: SearchTreeView

func _ready() -> void:
	hud.bind_match(game_manager)
	hud.restart_requested.connect(_restart_match)
	hud.pause_requested.connect(game_manager.toggle_pause)
	hud.damage_requested.connect(_debug_damage)
	hud.title_requested.connect(_return_to_title)
	battle_view = LiveBattleView.new()
	battle_view.name = "LiveBattle"
	add_child(battle_view)
	battle_view.z_index = 5
	battle_view.bind_match(game_manager)
	ai_manager = AIManager.new()
	ai_manager.name = "AIManager"
	add_child(ai_manager)
	ai_manager.bind_match(game_manager)
	hud.bind_ai(ai_manager)
	hud.deployment_requested.connect(_queue_deployment)
	hud.routes_requested.connect(_toggle_routes)
	search_tree = SearchTreeView.new()
	search_tree.name = "SearchTree"
	ArenaStyle.mount(hud.interface, search_tree, Rect2(410, 170, 1100, 660))
	search_tree.controller = ai_manager
	search_tree.export_requested.connect(_export_traces)
	hud.trace_requested.connect(search_tree.toggle)
	for overlay in [hud.pause_menu, hud.result_panel, hud.settings]:
		hud.interface.move_child(overlay, -1)
	_restart_match()

func _queue_deployment(move: Dictionary) -> void:
	if not ai_manager.queue_human_action(move):
		hud.show_message("Action unavailable. Check energy, cooldown and lane.")

func _toggle_routes() -> void:
	battle_view.show_routes = not battle_view.show_routes
	battle_view.queue_redraw()

func _export_traces() -> void:
	var error: Error = ai_manager.export_latest()
	if search_tree.visible and not search_tree.trace.is_empty():
		var selected_error: Error = DecisionTrace.export_json(search_tree.trace, ai_manager.export_directory.path_join("selected_decision.json"))
		if selected_error != OK:
			error = selected_error
	hud.show_message("Saved decision JSON to " + ai_manager.export_directory if error == OK else "Could not export trace: " + error_string(error))

func _restart_match() -> void:
	if search_tree != null:
		search_tree.hide()
	var participants: Array[ArenaStructure] = []
	for child in $Structures.get_children():
		if child is ArenaStructure:
			participants.append(child)
	game_manager.start_match(participants)

func _debug_damage(structure_id: StringName) -> void:
	game_manager.damage_structure(structure_id, game_manager.balance.debug_damage_amount)

func _return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if hud.settings.visible:
		if event.keycode == KEY_ESCAPE:
			hud.close_settings()
			get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_SPACE, KEY_ESCAPE:
			game_manager.toggle_pause()
		KEY_R:
			_restart_match()
		KEY_F3:
			hud.toggle_debug()
		KEY_F4:
			hud.toggle_preview()
		KEY_F2:
			search_tree.toggle()
		KEY_F7:
			_export_traces()
		KEY_G:
			_toggle_routes()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			hud.select_live_card(event.keycode - KEY_1)
		KEY_A:
			hud.request_lane(0)
		KEY_D:
			hud.request_lane(1)
		KEY_W:
			hud.request_wait()
		_:
			return
	get_viewport().set_input_as_handled()
