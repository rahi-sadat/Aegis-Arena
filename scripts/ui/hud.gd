class_name ArenaHUD
extends CanvasLayer
## Presents match signals and emits user requests; it never calculates victory rules.

signal pause_requested
signal restart_requested
signal damage_requested(structure_id: StringName)

const TEXT: Color = Color("e2ebf5")
const MUTED: Color = Color("91a3b7")

var manager: GameManager
var timer_label: Label
var timer_bar: ProgressBar
var status_label: Label
var pause_button: Button
var debug_button: Button
var debug_visible: bool = false
var side_rows: Array[VBoxContainer] = []
var side_summaries: Array[Label] = []
var structure_rows: Dictionary = {}

@onready var interface: Control = $Interface
@onready var result_panel: MatchResultPanel = $Interface/MatchResultPanel

func _ready() -> void:
	_build_header()
	_build_side(GameConstants.Team.BLUE, Vector2(48, 210))
	_build_side(GameConstants.Team.RED, Vector2(1532, 210))
	var footer: Label = _label("PHASE 01  /  MATCH FOUNDATION", 20, TEXT)
	_place(footer, Rect2(48, 958, 1000, 28))
	var hints: Label = _label("SPACE  Pause     R  Restart     F3  Damage controls", 18, MUTED)
	_place(hints, Rect2(48, 1000, 1200, 28))
	var note: Label = _label("Destroy the enemy core. On timeout, compare remaining structure HP.", 18, MUTED)
	_place(note, Rect2(444, 958, 1032, 28))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result_panel.restart_requested.connect(func() -> void: restart_requested.emit())
	# Keep the full-screen result overlay above the generated HUD controls.
	interface.move_child(result_panel, -1)

func bind_match(game_manager: GameManager) -> void:
	manager = game_manager
	manager.match_started.connect(_on_match_started)
	manager.match_ended.connect(_on_match_ended)
	manager.timer_changed.connect(_on_timer_changed)
	manager.structure_health_changed.connect(_on_structure_changed)
	manager.pause_changed.connect(_on_pause_changed)

func _build_header() -> void:
	_place(_label("AEGIS ARENA", 36, TEXT), Rect2(48, 32, 480, 50))
	_place(_label("TACTICAL CARD BATTLE  /  UNIVERSITY PROJECT", 15, MUTED), Rect2(50, 90, 630, 24))
	timer_label = _label("03:00", 44, TEXT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(timer_label, Rect2(830, 20, 260, 62))
	status_label = _label("MATCH READY", 15, MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(status_label, Rect2(810, 86, 300, 26))
	timer_bar = _health_bar(Color("b6c9de"))
	_place(timer_bar, Rect2(810, 122, 300, 4))
	pause_button = _button("Pause")
	pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_place(pause_button, Rect2(1532, 42, 130, 48))
	debug_button = _button("Damage controls")
	debug_button.toggle_mode = true
	debug_button.pressed.connect(toggle_debug)
	_place(debug_button, Rect2(1678, 42, 194, 48))

func _build_side(team_id: int, origin: Vector2) -> void:
	var color: Color = GameConstants.team_color(team_id)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	_place(panel, Rect2(origin, Vector2(340, 620)))
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	column.add_child(_label(GameConstants.team_name(team_id).to_upper() + " COMMANDER", 24, color))
	column.add_child(_label("2 GUARDS  /  1 CORE", 15, MUTED))
	column.add_child(HSeparator.new())
	var summary: Label = _label("100.0% structure HP", 21, TEXT)
	column.add_child(summary)
	side_summaries.append(summary)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 24)
	column.add_child(rows)
	side_rows.append(rows)
	column.add_child(_label("Debug damage is credited\nto the opposing commander.", 16, MUTED))

func _on_match_started() -> void:
	result_panel.hide()
	structure_rows.clear()
	for container in side_rows:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	for structure in manager.structures:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		side_rows[structure.team_id].add_child(column)
		column.add_child(_label(structure.display_title(), 16, MUTED))
		var health: Label = _label("", 22, TEXT)
		column.add_child(health)
		var bar: ProgressBar = _health_bar(GameConstants.team_color(structure.team_id))
		bar.custom_minimum_size.y = 8
		column.add_child(bar)
		var damage: Button = _button("Deal %d damage" % manager.balance.debug_damage_amount)
		damage.custom_minimum_size.y = 32
		damage.visible = debug_visible
		damage.tooltip_text = "Phase 1 test control: damages this structure."
		damage.pressed.connect(_request_damage.bind(structure.structure_id))
		column.add_child(damage)
		structure_rows[structure.structure_id] = {"health": health, "bar": bar, "damage": damage}
		_refresh_structure(structure)
	_refresh_summaries()
	status_label.text = "MATCH IN PROGRESS"
	pause_button.disabled = false
	_refresh_damage_controls()

func _request_damage(structure_id: StringName) -> void:
	damage_requested.emit(structure_id)

func _on_timer_changed(remaining: float) -> void:
	var seconds: int = ceili(remaining)
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	timer_bar.value = 100.0 * remaining / manager.balance.match_duration_seconds

func _on_structure_changed(structure: ArenaStructure) -> void:
	_refresh_structure(structure)
	_refresh_summaries()

func _refresh_structure(structure: ArenaStructure) -> void:
	var row: Dictionary = structure_rows[structure.structure_id]
	var health: Label = row["health"]
	var bar: ProgressBar = row["bar"]
	health.text = "DESTROYED" if structure.is_destroyed else "%d / %d HP" % [structure.current_hp, structure.max_hp]
	bar.value = 100.0 * structure.current_hp / structure.max_hp
	var damage: Button = row["damage"]
	damage.disabled = structure.is_destroyed or manager.is_paused or not manager.is_running

func _refresh_summaries() -> void:
	var hp: Array[float] = manager.total_remaining_hp()
	for team_id in [GameConstants.Team.BLUE, GameConstants.Team.RED]:
		var fraction: float = MatchRules.remaining_fraction(hp[team_id], manager.starting_structure_hp[team_id])
		side_summaries[team_id].text = "%.1f%% structure HP" % (fraction * 100.0)

func _on_pause_changed(paused: bool) -> void:
	pause_button.text = "Resume" if paused else "Pause"
	if manager.is_running:
		status_label.text = "PAUSED" if paused else "MATCH IN PROGRESS"
	_refresh_damage_controls()

func _on_match_ended(match_result: Dictionary) -> void:
	status_label.text = "MATCH COMPLETE"
	pause_button.disabled = true
	_refresh_damage_controls()
	result_panel.show_result(match_result)

func toggle_debug() -> void:
	debug_visible = not debug_visible
	debug_button.set_pressed_no_signal(debug_visible)
	_refresh_damage_controls()

func _refresh_damage_controls() -> void:
	if manager == null:
		return
	for structure in manager.structures:
		if not structure_rows.has(structure.structure_id):
			continue
		var button: Button = structure_rows[structure.structure_id]["damage"]
		button.visible = debug_visible
		button.disabled = structure.is_destroyed or manager.is_paused or not manager.is_running

func _place(control: Control, rect: Rect2) -> void:
	interface.add_child(control)
	control.position = rect.position
	control.size = rect.size

func _label(value: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT)
	var normal: StyleBoxFlat = _panel_style()
	normal.bg_color = Color("1c2d40")
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	button.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color("2b4661")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_disabled_color", Color("536276"))
	return button

func _health_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("223044")
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101d2c")
	style.border_color = Color("2b4057")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
