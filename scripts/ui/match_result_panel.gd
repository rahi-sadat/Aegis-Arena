class_name MatchResultPanel
extends Control
## Displays the frozen result snapshot and provides a restart request.

signal restart_requested

@onready var title_label: Label = $Panel/Margin/Rows/Title
@onready var reason_label: Label = $Panel/Margin/Rows/Reason
@onready var summary_label: Label = $Panel/Margin/Rows/Summary

func _ready() -> void:
	$Panel/Margin/Rows/Restart.pressed.connect(func() -> void: restart_requested.emit())
	hide()

func show_result(result: Dictionary) -> void:
	var winning_team: int = result["winner"]
	title_label.text = "DRAW" if winning_team == GameConstants.DRAW else GameConstants.team_name(winning_team).to_upper() + " VICTORY"
	title_label.modulate = Color.WHITE if winning_team == GameConstants.DRAW else GameConstants.team_color(winning_team)
	reason_label.text = "%s  /  %.1f seconds elapsed" % [result["reason"], result["elapsed_seconds"]]
	var fractions: Array = result["remaining_fraction"]
	var damage: Array = result["damage_dealt"]
	summary_label.text = "Remaining structure HP\nBlue  %.1f%%     |     Red  %.1f%%\n\nStructure damage dealt\nBlue  %d     |     Red  %d" % [fractions[0] * 100.0, fractions[1] * 100.0, damage[0], damage[1]]
	show()
