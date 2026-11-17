class_name ArenaPauseMenu
extends Control

signal resume_requested
signal restart_requested
signal settings_requested
signal title_requested

var _resume: Button

func _ready() -> void:
	hide()
	ArenaStyle.veil(self, Color(0.012, 0.021, 0.042, 0.65))
	var panel := ArenaStyle.panel(self, Rect2(680, 277, 560, 526))
	ArenaStyle.text(panel, Rect2(40, 30, 480, 72), "MATCH PAUSED", 42, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(panel, Rect2(40, 108, 480, 36), "The battle clock is stopped.", 20, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_resume = _button(panel, 169, "RESUME", resume_requested.emit, true)
	var restart := _button(panel, 245, "RESTART", restart_requested.emit)
	var settings := _button(panel, 321, "SETTINGS", settings_requested.emit)
	var title := _button(panel, 397, "RETURN TO TITLE", title_requested.emit)
	ArenaStyle.cycle_focus([_resume, restart, settings, title])
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_resume.grab_focus()
	)

func _button(panel: Panel, y: int, caption: String, callback: Callable, primary: bool = false) -> Button:
	var action := ArenaStyle.button(caption, primary)
	ArenaStyle.mount(panel, action, Rect2(80, y, 400, 56))
	action.pressed.connect(callback)
	return action
