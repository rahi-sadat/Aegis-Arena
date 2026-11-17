class_name MatchResultPanel
extends Control
## Displays the match result supplied by GameManager.

signal restart_requested
signal title_requested

var _surface: Panel
var _outcome: Label
var _reason: Label
var _blue_hp: Label
var _red_hp: Label
var _blue_damage: Label
var _red_damage: Label
var _restart: Button

func _ready() -> void:
	hide()
	ArenaStyle.veil(self, Color(0.013, 0.023, 0.042, 0.77))
	_surface = ArenaStyle.panel(self, Rect2(590, 266, 740, 548))
	_outcome = ArenaStyle.text(_surface, Rect2(35, 37, 670, 82), "", 55, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	_reason = ArenaStyle.text(_surface, Rect2(35, 121, 670, 32), "", 20, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_make_team_column(51, GameConstants.Team.BLUE)
	_make_team_column(382, GameConstants.Team.RED)
	_restart = ArenaStyle.button("RESTART  [R]", true)
	var menu := ArenaStyle.button("RETURN TO MENU")
	ArenaStyle.mount(_surface, _restart, Rect2(51, 443, 307, 59))
	ArenaStyle.mount(_surface, menu, Rect2(382, 443, 307, 59))
	_restart.pressed.connect(restart_requested.emit)
	menu.pressed.connect(title_requested.emit)
	ArenaStyle.cycle_focus([_restart, menu])
	_restart.focus_neighbor_right = _restart.get_path_to(menu)
	menu.focus_neighbor_left = menu.get_path_to(_restart)

func _make_team_column(x: float, team: int) -> void:
	var tone := GameConstants.team_color(team)
	var card := ArenaStyle.panel(_surface, Rect2(x, 183, 307, 207), tone)
	ArenaStyle.text(card, Rect2(25, 18, 255, 35), GameConstants.team_name(team).to_upper(), 23, tone, true)
	ArenaStyle.text(card, Rect2(25, 66, 257, 24), "Remaining structure HP", 16, ArenaStyle.MUTED)
	var hp := ArenaStyle.text(card, Rect2(25, 94, 257, 34), "", 25, ArenaStyle.TEXT, true)
	ArenaStyle.text(card, Rect2(25, 141, 257, 24), "Structure damage dealt", 16, ArenaStyle.MUTED)
	var damage := ArenaStyle.text(card, Rect2(25, 169, 257, 27), "", 21, ArenaStyle.TEXT, true)
	if team == GameConstants.Team.BLUE:
		_blue_hp = hp
		_blue_damage = damage
	else:
		_red_hp = hp
		_red_damage = damage

func show_result(result: Dictionary) -> void:
	var winner: int = result["winner"]
	_outcome.text = "DRAW" if winner == GameConstants.DRAW else GameConstants.team_name(winner).to_upper() + " VICTORY"
	_outcome.add_theme_color_override("font_color", ArenaStyle.GOLD if winner == GameConstants.DRAW else GameConstants.team_color(winner))
	_reason.text = "%s  •  %.1f seconds elapsed" % [result["reason"], result["elapsed_seconds"]]
	var fractions: Array = result["remaining_fraction"]
	var damage: Array = result["damage_dealt"]
	_blue_hp.text = "%.1f%%" % (fractions[0] * 100.0)
	_red_hp.text = "%.1f%%" % (fractions[1] * 100.0)
	_blue_damage.text = str(roundi(damage[0]))
	_red_damage.text = str(roundi(damage[1]))
	show()
	_restart.grab_focus()
	ArenaStyle.enter(self)
