extends Node
## Wires the current scene together; no gameplay rules or future AI live here.

@onready var game_manager: GameManager = $GameManager
@onready var hud: ArenaHUD = $HUD

func _ready() -> void:
	hud.bind_match(game_manager)
	hud.restart_requested.connect(_restart_match)
	hud.pause_requested.connect(game_manager.toggle_pause)
	hud.damage_requested.connect(_debug_damage)
	_restart_match()

func _restart_match() -> void:
	var participants: Array[ArenaStructure] = []
	for child in $Structures.get_children():
		if child is ArenaStructure:
			participants.append(child)
	game_manager.start_match(participants)

func _debug_damage(structure_id: StringName) -> void:
	game_manager.damage_structure(structure_id, game_manager.balance.debug_damage_amount)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			game_manager.toggle_pause()
		KEY_R:
			_restart_match()
		KEY_F3:
			hud.toggle_debug()
		_:
			return
	get_viewport().set_input_as_handled()
