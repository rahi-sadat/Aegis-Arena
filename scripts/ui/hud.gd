class_name ArenaHUD
extends CanvasLayer
## Presents the match signals and emits input requests for the live scene.

signal pause_requested
signal restart_requested
signal damage_requested(structure_id: StringName)
signal title_requested
signal deployment_requested(move: Dictionary)
signal trace_requested
signal routes_requested

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
var ai_manager: AIManager
var _human_status: Label
var _lane_buttons: Array[Button] = []

func _ready() -> void:
	blue.configure(GameConstants.Team.BLUE, DeckArt.BLUE_PORTRAIT, false)
	red.configure(GameConstants.Team.RED, DeckArt.RED_PORTRAIT, true)
	insight.follow_commander(GameConstants.Team.RED if MatchConfig.is_human(GameConstants.Team.BLUE) else GameConstants.Team.BLUE)
	_build_timer()
	_build_deck()
	_build_controls()
	_build_preview_label()
	_build_deployment_controls()
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
	manager.battle_changed.connect(_on_battle_changed)

func bind_ai(controller: AIManager) -> void:
	ai_manager = controller
	ai_manager.decision_made.connect(_on_decision)
	ai_manager.human_action_queued.connect(func(_move: Dictionary) -> void: _on_battle_changed())

func _build_timer() -> void:
	ArenaStyle.decorate(timer_frame)
	timer_label = ArenaStyle.text(timer_frame, Rect2(0, 4, 210, 50), "03:00", 41, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_clock_state = ArenaStyle.text(timer_frame, Rect2(0, 56, 210, 23), "MATCH TIME", 14, ArenaStyle.GOLD, false, HORIZONTAL_ALIGNMENT_CENTER)
	_clock_bar = ArenaStyle.bar(ArenaStyle.GOLD)
	ArenaStyle.mount(timer_frame, _clock_bar, Rect2(38, 81, 134, 5))

func _build_deck() -> void:
	ArenaStyle.decorate(deck)
	var caption := ArenaStyle.text(deck, Rect2(26, 9, 375, 23), "COMMAND DECK", 16, ArenaStyle.GOLD, true)
	caption.tooltip_text = "Fixed five-card deck; select a ready card, then a lane in Human vs AI"
	_deck_status = ArenaStyle.text(deck, Rect2(380, 9, 253, 23), "DEPLOYMENT LOCKED", 14, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	for index in DeckArt.NAMES.size():
		var card := CARD.instantiate() as BattleCardSlot
		card.name = DeckArt.NAMES[index]
		ArenaStyle.mount(deck, card, Rect2(22 + index * 124, 32, 110, 118))
		card.build(index, DeckArt.CARDS[index])
		card.inspected.connect(_select_preview_card)
		_cards.append(card)
	ArenaStyle.text(deck, Rect2(664, 9, 150, 23), "LAST PLAY", 14, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
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

func _build_deployment_controls() -> void:
	var panel := ArenaStyle.panel(interface, Rect2(32, 600, 334, 207))
	ArenaStyle.text(panel, Rect2(14, 8, 306, 28), "DEPLOYMENT & ANALYSIS", 17, ArenaStyle.GOLD, true)
	for index in 3:
		var button := ArenaStyle.button(["LEFT [A]", "RIGHT [D]", "WAIT [W]"][index])
		button.add_theme_font_size_override("font_size", 14)
		ArenaStyle.mount(panel, button, Rect2(14 + index * 104, 44, 98, 38))
		if index < 2:
			button.pressed.connect(request_lane.bind(index))
		else:
			button.pressed.connect(request_wait)
		_lane_buttons.append(button)
	_human_status = ArenaStyle.text(panel, Rect2(14, 91, 306, 49), "", 15, ArenaStyle.MUTED)
	var trace_button := ArenaStyle.button("SEARCH TREE [F2]")
	trace_button.add_theme_font_size_override("font_size", 13)
	ArenaStyle.mount(panel, trace_button, Rect2(14, 153, 170, 38))
	trace_button.pressed.connect(trace_requested.emit)
	var route_button := ArenaStyle.button("A* ROUTES [G]")
	route_button.add_theme_font_size_override("font_size", 13)
	ArenaStyle.mount(panel, route_button, Rect2(194, 153, 126, 38))
	route_button.pressed.connect(routes_requested.emit)

func select_live_card(index: int) -> void:
	if preview_enabled:
		_select_preview_card(index)
		return
	if index >= 0 and index < _cards.size() and not _cards[index].disabled:
		_selected_card = index
		for card_index in _cards.size():
			_cards[card_index].show_selected(card_index == index)
		_human_status.text = CardData.NAMES[index] + " selected. Choose LEFT or RIGHT."

func request_lane(lane: int) -> void:
	if _selected_card >= 0 and not preview_enabled:
		deployment_requested.emit(CardData.action(_selected_card, lane))

func request_wait() -> void:
	if not preview_enabled:
		deployment_requested.emit(CardData.wait_action())

func show_message(message: String) -> void:
	_human_status.text = message

func _on_battle_changed() -> void:
	if manager == null or manager.battle_state == null or preview_enabled:
		return
	var state: GameState = manager.battle_state
	var team: int = 0 if MatchConfig.is_human(0) else state.next_team
	var shown: GameState = state.copy_state()
	shown.next_team = team
	var human_ready: bool = MatchConfig.is_human(0) and manager.is_running and not manager.is_paused
	_deck_status.text = ("YOUR DECK" if MatchConfig.is_human(0) else GameConstants.team_name(team).to_upper() + " DECK")
	energy.set_energy(state.energy[team])
	for index in _cards.size():
		var left: String = BattleRules.rejection_reason(shown, CardData.action(index, 0))
		var right: String = BattleRules.rejection_reason(shown, CardData.action(index, 1))
		var ready: bool = left.is_empty() or right.is_empty()
		_cards[index].set_live(human_ready and ready, state.cooldowns[team][index],
			"Select, then LEFT [A] / RIGHT [D]" if ready and human_ready else (left if not ready else "AI controls this commander"))
	for button in _lane_buttons:
		button.disabled = not human_ready
	if MatchConfig.is_human(0):
		var queued: String = CardData.action_name(ai_manager.queued_human_action) if ai_manager != null else "Wait"
		_human_status.text = "Queued: %s\nCards [1-5], then A / D. W waits." % queued
	else:
		_human_status.text = "Next: %s  |  %d units on field\nF2 traces  /  F7 export  /  G paths" % [GameConstants.team_name(team), state.units.size()]
	minimap.live_units = state.units
	minimap.refresh()
	if manager.is_preparing:
		_clock_state.text = "PREPARING MOVE"
	elif manager.is_running and not manager.is_paused:
		_clock_state.text = "MATCH TIME"

func _on_decision(trace: Dictionary) -> void:
	if preview_enabled:
		return
	insight.set_trace(trace)
	var card: int = trace.execution.action.card
	_next_art.texture = DeckArt.CARDS[card] if card >= 0 else DeckArt.BACK
	_next_art.modulate = Color.WHITE
	if trace.team == 0 and trace.algorithm == "Human":
		_selected_card = -1
		for slot in _cards:
			slot.show_selected(false)
	_on_battle_changed()

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
	blue.update_logic(GameConstants.Team.BLUE)
	red.update_logic(GameConstants.Team.RED)
	insight.follow_commander(GameConstants.Team.RED if MatchConfig.is_human(0) else GameConstants.Team.BLUE)
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
	_selected_card = -1
	for card in _cards:
		card.show_selected(false)

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
		if preview_enabled:
			card.set_live(true, 0.0, "Preview inspection only")
	_select_preview_card(2 if preview_enabled else -1)
	if not preview_enabled:
		_selected_card = -1
		for card in _cards:
			card.show_selected(false)
		_on_battle_changed()
		if ai_manager != null:
			for trace: Dictionary in ai_manager.last_traces:
				if not trace.is_empty():
					insight.set_trace(trace)

func _select_preview_card(index: int) -> void:
	if not preview_enabled:
		select_live_card(index)
		return
	_selected_card = index if preview_enabled else -1
	for card_index in _cards.size():
		_cards[card_index].show_selected(card_index == _selected_card)

func close_settings() -> bool:
	if not settings.visible:
		return false
	settings.close()
	return true
