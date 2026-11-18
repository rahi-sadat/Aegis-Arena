class_name ArenaHUD
extends CanvasLayer
## Presents the match signals and emits input requests for the live scene.

signal pause_requested
signal restart_requested
signal damage_requested(structure_id: StringName)
signal title_requested

const CARD := preload("res://scenes/ui/components/CardSlot.tscn")

@onready var interface: Control = $Interface
@onready var timer_frame: Panel = $Interface/TimerFrame
@onready var minimap: BattleMinimap = $Interface/Minimap
@onready var insight: AIInsightPanel = $Interface/AIInsight
@onready var deck: Panel = $Interface/CommandStrip
@onready var energy: BattleEnergyBar = $Interface/CommandStrip/Energy
@onready var blue: CommanderPanel = $Interface/BlueCommander
@onready var red: CommanderPanel = $Interface/RedCommander
@onready var pause_menu: ArenaPauseMenu = $Interface/PauseMenu
@onready var settings: ArenaSettingsPanel = $Interface/SettingsPanel
@onready var result_panel: MatchResultPanel = $Interface/MatchResultPanel
@onready var preview: BattlePreview = $Interface/BattlePreview

var manager: GameManager
var timer_label: Label
var debug_visible: bool = false
var preview_enabled: bool = false

var _clock_state: Label
var _clock_bar: ProgressBar
var _pause_button: Button
var _cards: Array[BattleCardSlot] = []
var _selected_card: int = -1
var _preview_label: Panel
var _debug_panel: Panel
var _debug_rows: Dictionary = {}
var _cores: Array[ArenaStructure] = [null, null]
var _next_art: TextureRect
var _deck_status: Label

func _ready() -> void:
	blue.configure(GameConstants.Team.BLUE, DeckArt.BLUE_PORTRAIT, false)
	red.configure(GameConstants.Team.RED, DeckArt.RED_PORTRAIT, true)
	insight.follow_commander(GameConstants.Team.RED if MatchConfig.is_human(GameConstants.Team.BLUE) else GameConstants.Team.BLUE)
	_build_timer()
	_build_deck()
	_build_controls()
	_build_preview_label()
	minimap.visible = UISettings.minimap_visible
	settings.minimap_changed.connect(func(enabled: bool) -> void: minimap.visible = enabled)
	pause_menu.resume_requested.connect(pause_requested.emit)
	pause_menu.restart_requested.connect(restart_requested.emit)
	pause_menu.settings_requested.connect(settings.open)
	pause_menu.title_requested.connect(title_requested.emit)
	result_panel.restart_requested.connect(restart_requested.emit)
	result_panel.title_requested.connect(title_requested.emit)
	for overlay in [pause_menu, result_panel, settings]:
		interface.move_child(overlay, -1)

func bind_match(game_manager: GameManager) -> void:
	manager = game_manager
	manager.match_started.connect(_on_match_started)
	manager.match_ended.connect(_on_match_ended)
	manager.timer_changed.connect(_on_timer_changed)
	manager.structure_health_changed.connect(_on_structure_changed)
	manager.pause_changed.connect(_on_pause_changed)

func _build_timer() -> void:
	ArenaStyle.decorate(timer_frame)
	timer_label = ArenaStyle.text(timer_frame, Rect2(0, 4, 210, 50), "03:00", 41, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_clock_state = ArenaStyle.text(timer_frame, Rect2(0, 56, 210, 23), "MATCH TIME", 14, ArenaStyle.GOLD, false, HORIZONTAL_ALIGNMENT_CENTER)
	_clock_bar = ArenaStyle.bar(ArenaStyle.GOLD)
	ArenaStyle.mount(timer_frame, _clock_bar, Rect2(38, 81, 134, 5))

func _build_deck() -> void:
	ArenaStyle.decorate(deck)
	var caption := ArenaStyle.text(deck, Rect2(26, 9, 375, 23), "COMMAND DECK", 16, ArenaStyle.GOLD, true)
	caption.tooltip_text = "Illustrated card lineup for Phase 2 and later"
	_deck_status = ArenaStyle.text(deck, Rect2(380, 9, 253, 23), "DEPLOYMENT LOCKED", 14, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	for index in DeckArt.NAMES.size():
		var card := CARD.instantiate() as BattleCardSlot
		card.name = DeckArt.NAMES[index]
		ArenaStyle.mount(deck, card, Rect2(22 + index * 124, 32, 110, 118))
		card.build(index, DeckArt.CARDS[index])
		card.inspected.connect(_select_preview_card)
		_cards.append(card)
	ArenaStyle.text(deck, Rect2(664, 9, 150, 23), "NEXT", 14, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	var next := ArenaStyle.panel(deck, Rect2(695, 32, 88, 118))
	_next_art = ArenaStyle.art(next, Rect2(4, 4, 80, 110), DeckArt.BACK)
	_next_art.modulate = Color(0.61, 0.64, 0.72)
	deck.move_child(energy, -1)

func _build_controls() -> void:
	var controls := ArenaStyle.panel(interface, Rect2(1438, 949, 450, 105))
	controls.name = &"MatchControls"
	ArenaStyle.text(controls, Rect2(16, 9, 415, 25), "MATCH CONTROLS", 15, ArenaStyle.GOLD, true)
	_pause_button = ArenaStyle.button("Pause")
	_pause_button.tooltip_text = "Pause or resume • Space"
	ArenaStyle.mount(controls, _pause_button, Rect2(16, 44, 112, 46))
	_pause_button.pressed.connect(pause_requested.emit)
	var speed := ArenaStyle.button("1×")
	speed.disabled = true
	speed.tooltip_text = "Game speed is locked"
	ArenaStyle.mount(controls, speed, Rect2(140, 44, 64, 46))
	var options := ArenaStyle.button("Settings")
	ArenaStyle.mount(controls, options, Rect2(215, 44, 111, 46))
	options.pressed.connect(settings.open)
	var debug := ArenaStyle.button("F3 Debug")
	ArenaStyle.mount(controls, debug, Rect2(337, 44, 97, 46))
	debug.pressed.connect(toggle_debug)

func _build_preview_label() -> void:
	_preview_label = ArenaStyle.panel(interface, Rect2(32, 200, 545, 42), ArenaStyle.VIOLET)
	_preview_label.name = &"PreviewBadge"
	ArenaStyle.text(_preview_label, Rect2(10, 0, 525, 42), "UI PREVIEW — SAMPLE DATA — NOT LIVE GAMEPLAY", 16, Color("#eddcff"), true, HORIZONTAL_ALIGNMENT_CENTER)
	_preview_label.hide()
	_debug_panel = ArenaStyle.panel(interface, Rect2(32, 256, 334, 311))
	_debug_panel.name = &"DebugDamage"
	ArenaStyle.text(_debug_panel, Rect2(17, 9, 300, 33), "STRUCTURE DAMAGE  [F3]", 16, ArenaStyle.GOLD, true)
	_debug_panel.hide()

func _on_match_started() -> void:
	result_panel.hide()
	pause_menu.hide()
	settings.hide()
	for row: Dictionary in _debug_rows.values():
		var button: Button = row.button
		var caption: Label = row.caption
		_debug_panel.remove_child(button)
		_debug_panel.remove_child(caption)
		button.queue_free()
		caption.queue_free()
	_debug_rows.clear()
	_cores = [null, null]
	for structure in manager.structures:
		if structure.data.structure_type == StructureData.Kind.CORE:
			_cores[structure.team_id] = structure
		var y := 48 + _debug_rows.size() * 40
		var caption := ArenaStyle.text(_debug_panel, Rect2(17, y, 214, 32), "", 16, GameConstants.team_color(structure.team_id))
		var action := ArenaStyle.button("−%d HP" % manager.balance.debug_damage_amount)
		action.add_theme_font_size_override("font_size", 15)
		action.pressed.connect(_request_damage.bind(structure.structure_id))
		ArenaStyle.mount(_debug_panel, action, Rect2(222, y, 96, 32))
		_debug_rows[structure.structure_id] = {"caption": caption, "button": action}
		_refresh_debug_row(structure)
	minimap.set_battle(manager.structures)
	_refresh_commanders(true)
	_pause_button.disabled = false
	_clock_state.text = "MATCH TIME"

func _request_damage(structure_id: StringName) -> void:
	damage_requested.emit(structure_id)

func _on_timer_changed(remaining: float) -> void:
	var seconds := ceili(remaining)
	@warning_ignore("integer_division")
	timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	var tone := Color("#ffaf8f") if seconds <= 20 else ArenaStyle.TEXT
	if timer_label.get_theme_color("font_color") != tone:
		timer_label.add_theme_color_override("font_color", tone)
	_clock_bar.value = remaining / manager.balance.match_duration_seconds

func _on_structure_changed(structure: ArenaStructure) -> void:
	_refresh_debug_row(structure)
	_refresh_commanders(false)
	minimap.refresh()

func _refresh_commanders(immediate: bool) -> void:
	var hp := manager.total_remaining_hp()
	for team in _cores.size():
		if _cores[team] == null:
			continue
		var panel := blue if team == GameConstants.Team.BLUE else red
		panel.update_status(_cores[team], MatchRules.remaining_fraction(hp[team], manager.starting_structure_hp[team]), immediate)

func _on_pause_changed(paused: bool) -> void:
	_pause_button.text = "Resume" if paused else "Pause"
	_clock_state.text = "PAUSED" if paused else "MATCH TIME"
	var was_paused := pause_menu.visible
	pause_menu.visible = paused
	if paused:
		ArenaStyle.enter(pause_menu)
	elif was_paused and manager.is_running:
		_pause_button.grab_focus()
	_refresh_debug_controls()

func _on_match_ended(match_result: Dictionary) -> void:
	if settings.visible:
		settings.close()
	_pause_button.disabled = true
	_clock_state.text = "MATCH COMPLETE"
	_refresh_debug_controls()
	result_panel.show_result(match_result)

func _refresh_debug_row(structure: ArenaStructure) -> void:
	if not _debug_rows.has(structure.structure_id):
		return
	var row: Dictionary = _debug_rows[structure.structure_id]
	row.caption.text = "%s %s  ·  %d" % [GameConstants.team_name(structure.team_id), structure.display_title().capitalize(), ceili(structure.current_hp)]
	row.button.disabled = structure.is_destroyed or manager.is_paused or not manager.is_running

func _refresh_debug_controls() -> void:
	for structure in manager.structures:
		_refresh_debug_row(structure)

func toggle_debug() -> void:
	debug_visible = not debug_visible
	_debug_panel.visible = debug_visible
	if debug_visible:
		ArenaStyle.enter(_debug_panel)

func toggle_preview() -> void:
	if not OS.is_debug_build():
		return
	preview_enabled = not preview_enabled
	preview.visible = preview_enabled
	_preview_label.visible = preview_enabled
	_deck_status.text = "CARD INSPECTION" if preview_enabled else "DEPLOYMENT LOCKED"
	energy.set_preview(preview_enabled)
	insight.set_preview(preview_enabled, DeckArt.CARDS[2])
	minimap.set_preview(preview_enabled)
	_next_art.texture = DeckArt.CARDS[1] if preview_enabled else DeckArt.BACK
	_next_art.modulate = Color.WHITE if preview_enabled else Color(0.61, 0.64, 0.72)
	for card in _cards:
		card.set_interaction(preview_enabled)
	_select_preview_card(2 if preview_enabled else -1)

func _select_preview_card(index: int) -> void:
	_selected_card = index if preview_enabled else -1
	for card_index in _cards.size():
		_cards[card_index].show_selected(card_index == _selected_card)

func close_settings() -> bool:
	if not settings.visible:
		return false
	settings.close()
	return true
