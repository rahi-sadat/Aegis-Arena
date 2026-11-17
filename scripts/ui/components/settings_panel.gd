class_name ArenaSettingsPanel
extends Control

signal closed
signal minimap_changed(enabled: bool)

var _previous_focus: Control
var _done: Button

func _ready() -> void:
	hide()
	ArenaStyle.veil(self, Color(0.014, 0.021, 0.041, 0.84))
	var book := ArenaStyle.panel(self, Rect2(660, 300, 600, 480))
	ArenaStyle.text(book, Rect2(35, 23, 530, 59), "SETTINGS", 38, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(book, Rect2(49, 110, 178, 36), "Master volume", 21)
	var volume := HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = UISettings.master_volume()
	volume.value_changed.connect(UISettings.set_master_volume)
	ArenaStyle.mount(book, volume, Rect2(242, 117, 310, 23))
	var map := _toggle(book, 177, "Show minimap", UISettings.minimap_visible)
	map.toggled.connect(func(enabled: bool) -> void:
		UISettings.minimap_visible = enabled
		minimap_changed.emit(enabled)
	)
	var motion := _toggle(book, 223, "Reduce motion", UISettings.reduce_motion)
	motion.toggled.connect(func(enabled: bool) -> void: UISettings.reduce_motion = enabled)
	var fullscreen := _toggle(book, 269, "Fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	fullscreen.disabled = DisplayServer.get_name() == "headless"
	fullscreen.toggled.connect(func(enabled: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	_done = ArenaStyle.button("DONE", true)
	_done.pressed.connect(close)
	ArenaStyle.mount(book, _done, Rect2(144, 382, 312, 54))
	var controls: Array[Control] = [volume, map, motion]
	if not fullscreen.disabled:
		controls.append(fullscreen)
	controls.append(_done)
	ArenaStyle.cycle_focus(controls)

func open() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	show()
	_done.grab_focus()
	ArenaStyle.enter(self)

func close() -> void:
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	closed.emit()

func _toggle(parent: Control, y: int, caption: String, enabled: bool) -> CheckButton:
	var button := CheckButton.new()
	button.text = caption
	button.button_pressed = enabled
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", ArenaStyle.TEXT)
	button.add_theme_color_override("font_hover_color", ArenaStyle.GOLD)
	ArenaStyle.mount(parent, button, Rect2(46, y, 506, 38))
	return button
