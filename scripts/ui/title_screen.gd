extends Control

const PRE_BATTLE := "res://scenes/ui/screens/PreBattleScreen.tscn"
const SETTINGS := preload("res://scenes/ui/components/SettingsPanel.tscn")
@export var background: Texture2D
@export var menu_music: AudioStream
@export var button_sound: AudioStream

@onready var _music: AudioStreamPlayer = $Music
@onready var _sound: AudioStreamPlayer = $ButtonSound

var _settings: ArenaSettingsPanel
var _help: Control
var _help_back: Button
var _main_action: Button

func _ready() -> void:
	MenuDesign.backdrop(self, background, 0.27)
	MenuDesign.brand(self, "TACTICAL CARD BATTLE")
	var options := ArenaStyle.button("SETTINGS")
	ArenaStyle.mount(self, options, Rect2(1500, 35, 164, 44))
	options.pressed.connect(func() -> void: _settings.open())
	var exit := ArenaStyle.button("EXIT GAME")
	ArenaStyle.mount(self, exit, Rect2(1680, 35, 168, 44))
	exit.pressed.connect(func() -> void: get_tree().quit())
	MenuDesign.eyebrow(self, Rect2(108, 236, 730, 28), "ENTER THE ARENA")
	ArenaStyle.text(self, Rect2(100, 282, 810, 200), "Two lanes.\nOne core.", 92, ArenaStyle.TEXT, true)
	ArenaStyle.text(self, Rect2(108, 516, 720, 86), "Build pressure. Defend your towers.\nChoose the card that changes the battle.", 26, Color("#b6c3cc"))
	_main_action = ArenaStyle.button("PLAY", true)
	ArenaStyle.mount(self, _main_action, Rect2(108, 660, 310, 68))
	_main_action.pressed.connect(_open_battle)
	var help := ArenaStyle.button("HOW TO PLAY")
	ArenaStyle.mount(self, help, Rect2(438, 660, 250, 68))
	help.pressed.connect(_open_help)
	ArenaStyle.text(self, Rect2(108, 754, 730, 34), "PLAY AGAINST AI     /     WATCH AI VS AI", 14, ArenaStyle.MUTED)
	_build_feature()
	ArenaStyle.text(self, Rect2(108, 970, 1000, 35), "3-minute battles     •     5-card command deck     •     Pause to plan", 16, ArenaStyle.MUTED)
	ArenaStyle.text(self, Rect2(1430, 970, 410, 35), "PLAY.  OBSERVE.  UNDERSTAND.", 12, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_RIGHT)
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
	ArenaStyle.cycle_focus([_main_action, help, options, exit])
	ArenaStyle.enter(self)

func _build_feature() -> void:
	var feature := ArenaStyle.panel(self, Rect2(1030, 225, 740, 622), ArenaStyle.EDGE_BLUE)
	MenuDesign.eyebrow(feature, Rect2(30, 20, 680, 30), "YOUR NEXT BATTLE")
	ArenaStyle.text(feature, Rect2(30, 62, 680, 58), "A small deck. A real decision.", 33, ArenaStyle.TEXT, true)
	ArenaStyle.text(feature, Rect2(30, 127, 680, 58), "Three distinct troops. Two lane spells.\nEvery card has a moment to play.", 20, ArenaStyle.MUTED)
	for index in 3:
		var x: float = 33 + index * 226
		var cell := ArenaStyle.panel(feature, Rect2(x, 223, 210, 256), Color("#546675"))
		var picture := ArenaStyle.art(cell, Rect2(12, 8, 186, 199), TroopArt.portrait(index))
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ArenaStyle.text(cell, Rect2(10, 213, 190, 28), CardData.NAMES[index].to_upper(), 14, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(feature, Rect2(33, 514, 670, 65), "See how the AI thinks.\nLive search trees and fuzzy reasoning inside every match.", 19, ArenaStyle.MUTED)

func _open_battle() -> void:
	if button_sound != null:
		_sound.play()
	ArenaTransition.go(self, PRE_BATTLE)

func _build_help() -> void:
	_help = Control.new()
	add_child(_help)
	_help.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	ArenaStyle.veil(_help, Color(0.014, 0.021, 0.041, 0.84))
	var panel := ArenaStyle.panel(_help, Rect2(568, 264, 784, 552))
	ArenaStyle.text(panel, Rect2(40, 29, 704, 70), "HOW TO PLAY", 40, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(panel, Rect2(65, 117, 656, 174), "Destroy the enemy core to win. At timeout, compare\nremaining structure HP, then structure damage.\nHuman: select a card [1–5] to freeze time and plan.\nClick a lane, or A / D, to confirm and resume.\nTab also pauses for planning. W queues Wait.\nMage and Arrow damage enemy units in one lane.", 20)
	ArenaStyle.text(panel, Rect2(65, 296, 656, 88), "SPACE   Pause / resume     R   Restart\nF2          Decision lab           F7  Export decisions\nG            A* routes              F3  Debug damage", 20, ArenaStyle.MUTED)
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
