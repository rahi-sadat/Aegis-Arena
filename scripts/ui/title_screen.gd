extends Control

const PRE_BATTLE := "res://scenes/ui/screens/PreBattleScreen.tscn"
const SETTINGS := preload("res://scenes/ui/components/SettingsPanel.tscn")
@export var background: Texture2D
@export var menu_music: AudioStream
@export var button_sound: AudioStream

@onready var _music: AudioStreamPlayer = $Music
@onready var _sound: AudioStreamPlayer = $ButtonSound

var _art: TextureRect
var _settings: ArenaSettingsPanel
var _help: Control
var _help_back: Button
var _main_action: Button

func _ready() -> void:
	_art = ArenaStyle.art(self, Rect2(-15, -12, 1950, 1104), background)
	var embers := EmberField.new()
	add_child(embers)
	embers.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var cover := ArenaStyle.veil(self, Color(0.015, 0.025, 0.05, 0.19))
	cover.mouse_filter = MOUSE_FILTER_IGNORE
	var crest := ArenaStyle.panel(self, Rect2(102, 112, 78, 78))
	ArenaStyle.art(crest, Rect2(5, 5, 68, 68), DeckArt.BACK)
	ArenaStyle.text(self, Rect2(197, 130, 550, 33), "TACTICAL CARD BATTLE", 18, ArenaStyle.GOLD, true)
	var title := ArenaStyle.text(self, Rect2(94, 193, 690, 182), "AEGIS\nARENA", 82, ArenaStyle.TEXT, true)
	title.add_theme_color_override("font_shadow_color", Color("#030811"))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var rule := ColorRect.new()
	rule.color = Color(ArenaStyle.GOLD, 0.68)
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.mount(self, rule, Rect2(104, 398, 405, 2))
	_main_action = _menu_button("PLAY", 441, _open_battle, true)
	_menu_button("GAME MODES", 519, _open_battle)
	_menu_button("HOW TO PLAY", 597, _open_help)
	_menu_button("SETTINGS", 675, func() -> void: _settings.open())
	_menu_button("EXIT GAME", 753, func() -> void: get_tree().quit())
	_main_action.grab_focus()
	_build_help()
	_settings = SETTINGS.instantiate() as ArenaSettingsPanel
	add_child(_settings)
	_settings.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_settings.closed.connect(_main_action.grab_focus)
	if menu_music != null:
		_music.stream = menu_music
		_music.finished.connect(_music.play)
		_music.play()
	if button_sound != null:
		_sound.stream = button_sound

func _process(_delta: float) -> void:
	var period := Time.get_ticks_msec() * 0.00023
	_art.position = Vector2(-15, -12) if UISettings.reduce_motion else Vector2(-15 + sin(period) * 6.0, -12 + cos(period) * 4.0)

func _menu_button(caption: String, y: int, callback: Callable, primary: bool = false) -> Button:
	var action := ArenaStyle.button(caption, primary)
	ArenaStyle.mount(self, action, Rect2(104, y, 404, 61))
	action.pressed.connect(func() -> void:
		if button_sound != null:
			_sound.play()
		callback.call()
	)
	return action

func _open_battle() -> void:
	get_tree().change_scene_to_file(PRE_BATTLE)

func _build_help() -> void:
	_help = Control.new()
	add_child(_help)
	_help.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ArenaStyle.veil(_help, Color(0.014, 0.021, 0.041, 0.84))
	var panel := ArenaStyle.panel(_help, Rect2(568, 264, 784, 552))
	ArenaStyle.text(panel, Rect2(40, 29, 704, 70), "HOW TO PLAY", 40, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(panel, Rect2(65, 117, 656, 151), "Destroy the enemy core to win. If time expires,\nthe side with more remaining structure HP wins.\nStructure damage breaks a tie.\n\nPhase 1 uses F3 debug damage for testing.", 21)
	ArenaStyle.text(panel, Rect2(65, 296, 656, 88), "SPACE   Pause or resume\nR            Restart match\nF4          Inspect the sample battle HUD (debug builds)", 20, ArenaStyle.MUTED)
	_help_back = ArenaStyle.button("BACK", true)
	ArenaStyle.mount(panel, _help_back, Rect2(206, 423, 372, 57))
	_help_back.pressed.connect(_close_help)
	ArenaStyle.cycle_focus([_help_back])
	_help.hide()

func _open_help() -> void:
	_help.show()
	_help_back.grab_focus()
	ArenaStyle.enter(_help)

func _close_help() -> void:
	_help.hide()
	_main_action.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _settings.visible:
			_settings.close()
		elif _help.visible:
			_close_help()
