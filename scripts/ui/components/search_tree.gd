class_name SearchTreeView
extends Panel
## Read-only live telemetry. A held snapshot stays stable while the match runs.

signal export_requested
var controller: AIManager
var trace: Dictionary = {}
var follow_live: bool = true
var _team: int = 0
var _title: Label
var _summary: Label
var _branch: OptionButton
var _history: OptionButton
var _records: Array = []
var _scroll: ScrollContainer
var _canvas: Control
var _details: RichTextLabel
var _root_children: Array = []
var _shown: Array = []
var _rects: Dictionary = {}
var _hold: Button
var _fuzzy_source: Button
var _fuzzy: FuzzyInspector
var _tree_controls: Array[Control] = []
var _tab: int = 0
var _live_field: bool = false
var _poll_time: float = 0
var _last_key: String = ""
var _zoom: float = 1
var _logical_size := Vector2(1058, 570)
var _selected_node: int = -1
var _node_styles: Dictionary = {}

func _ready() -> void:
	ArenaStyle.decorate(self, ArenaStyle.EDGE_BLUE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = ArenaStyle.text(self, Rect2(24, 13, 880, 42), "DECISION LAB", 25, ArenaStyle.TEXT, true)
	for team in 2:
		var button := _button(["BLUE", "RED"][team], Rect2(930 + team * 100, 17, 88, 36))
		button.pressed.connect(show_team.bind(team))
	_hold = _button("HOLD VIEW", Rect2(1150, 17, 174, 36))
	_hold.pressed.connect(func() -> void: set_follow(not follow_live))
	_button("CLOSE [F2]", Rect2(1382, 17, 174, 36)).pressed.connect(hide)
	_button("SEARCH TREE", Rect2(24, 74, 180, 38)).pressed.connect(_set_tab.bind(0))
	_button("FUZZY CALCULATION", Rect2(216, 74, 240, 38)).pressed.connect(_set_tab.bind(1))
	_fuzzy_source = _button("SOURCE: DECISION", Rect2(482, 74, 260, 38))
	_fuzzy_source.pressed.connect(func() -> void: _live_field = not _live_field; _refresh_fuzzy())
	_summary = ArenaStyle.text(self, Rect2(24, 123, 1532, 28), "", 15, ArenaStyle.MUTED)
	_branch = OptionButton.new()
	ArenaStyle.mount(self, _branch, Rect2(24, 168, 365, 34))
	_branch.add_theme_font_size_override("font_size", 16)
	_branch.item_selected.connect(func(_index: int) -> void: _layout_tree(); _fit())
	_history = OptionButton.new()
	ArenaStyle.mount(self, _history, Rect2(405, 168, 660, 34))
	_history.add_theme_font_size_override("font_size", 15)
	_history.item_selected.connect(func(index: int) -> void: set_follow(false); set_trace(_records[index]))
	var export_button := _button("EXPORT [F7]", Rect2(1082, 168, 170, 34))
	export_button.pressed.connect(export_requested.emit)
	_tree_controls = [_branch, _history, export_button]
	for index in 3:
		var button := _button(["−", "+", "FIT"][index], Rect2(1274 + index * 94, 168, 82, 34))
		button.pressed.connect(_zoom_action.bind(index))
		_tree_controls.append(button)
	_scroll = ScrollContainer.new()
	ArenaStyle.mount(self, _scroll, Rect2(24, 220, 1096, 608))
	_canvas = Control.new()
	_scroll.add_child(_canvas)
	_canvas.custom_minimum_size = Vector2(1058, 570)
	_canvas.draw.connect(_draw_tree)
	_canvas.gui_input.connect(_on_tree_input)
	_details = RichTextLabel.new()
	_details.add_theme_font_size_override("normal_font_size", 17)
	_details.add_theme_color_override("default_color", ArenaStyle.TEXT)
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ArenaStyle.mount(self, _details, Rect2(1142, 220, 414, 608))
	_fuzzy = FuzzyInspector.new()
	ArenaStyle.mount(self, _fuzzy, Rect2(24, 168, 1516, 665))
	_set_tab(0)
	visibility_changed.connect(func() -> void:
		if visible and is_inside_tree() and get_parent() != null:
			get_parent().move_child(self, -1)
	)
	hide()

func _button(caption: String, rect: Rect2) -> Button:
	var button := ArenaStyle.button(caption)
	button.add_theme_font_size_override("font_size", 15)
	ArenaStyle.mount(self, button, rect)
	return button

func bind_controller(value: AIManager) -> void:
	controller = value
	controller.decision_made.connect(_on_decision)
	controller.manager.match_started.connect(reset)

func reset() -> void:
	trace = {}
	_records.clear()
	_shown.clear()
	_rects.clear()
	_root_children.clear()
	_history.clear()
	_branch.clear()
	_last_key = ""
	_selected_node = -1
	follow_live = true
	_live_field = false
	_hold.text = "HOLD VIEW"
	_team = 1 if MatchConfig.is_human(0) else 0
	_empty()

func toggle() -> void:
	visible = not visible
	if visible:
		show_team(1 if MatchConfig.is_human(0) else _team)

func show_team(team: int) -> void:
	_team = team
	_last_key = ""
	follow_live = true
	_hold.text = "HOLD VIEW"
	_refresh_history()
	_poll()

func set_follow(enabled: bool) -> void:
	follow_live = enabled
	_hold.text = "HOLD VIEW" if enabled else "RESUME LIVE"
	if enabled:
		_last_key = ""
		_poll()
	elif not trace.is_empty():
		_update_summary()

func _process(delta: float) -> void:
	if not visible or controller == null:
		return
	_poll_time += delta
	if _poll_time < 0.10:
		return
	_poll_time = 0
	if follow_live:
		_poll()
	if _tab == 1 and _live_field:
		_refresh_fuzzy()

func _poll() -> void:
	if controller == null:
		return
	var sampled: Dictionary = LiveDecisionFeed.sample(controller, _team)
	if sampled.is_empty():
		trace = {}
		_empty()
		return
	if sampled.key != _last_key:
		var previous_tick: int = trace.get("root_snapshot", {}).get("tick_index", -1)
		_last_key = sampled.key
		set_trace(LiveDecisionFeed.snapshot(sampled), previous_tick == sampled.source.root_snapshot.tick_index)

func _on_decision(record: Dictionary) -> void:
	if not visible:
		_last_key = ""
		return
	_refresh_history()
	if follow_live and record.team == _team:
		var snapshot: Dictionary = record.duplicate(true)
		snapshot.view_phase = "EXECUTED"
		set_trace(snapshot)
		_last_key = ""

func _refresh_history() -> void:
	_history.clear()
	_records = controller.history[_team].duplicate() if controller != null else []
	_records.reverse()
	var held_id: int = int(trace.get("decision_id", -1)) if not follow_live else -1
	var selected: int = 0
	var found: bool = false
	for index in _records.size():
		if _records[index].decision_id == held_id:
			selected = index
			found = true
	if held_id >= 0 and not found:
		_records.push_front(trace)
	for record: Dictionary in _records:
		_history.add_item("History · #%d  /  %s  /  %.2fs left" % [record.decision_id, CardData.action_name(record.selected_action), record.root_snapshot.remaining_time])
	if not _records.is_empty():
		_history.select(selected)
	_history.tooltip_text = "Choose a completed decision to hold its actual snapshot. Resume Live follows new searches."

func _empty() -> void:
	_title.text = "DECISION LAB  /  " + GameConstants.team_name(_team).to_upper()
	_summary.text = "Waiting for this commander's first search in the current match."
	_details.text = "Live view follows actual searches.\n\nClick a node or HOLD VIEW to inspect a stable snapshot while the match continues."
	_shown.clear()
	_rects.clear()
	_canvas.queue_redraw()
	_fuzzy.clear_assessment()

func set_trace(record: Dictionary, preserve_branch: bool = false) -> void:
	var old_branch: int = _branch.selected if preserve_branch else 0
	_selected_node = -1
	trace = record.duplicate(true)
	_title.text = "DECISION LAB  /  %s  /  %s" % [GameConstants.team_name(trace.team).to_upper(), trace.algorithm]
	_update_summary()
	_root_children = []
	for node: Dictionary in trace.nodes:
		if node.parent == 0:
			_root_children.append(node)
	_branch.clear()
	_branch.add_item("Root overview · expand a branch")
	_branch.add_item("Full recorded tree · pan / zoom")
	for child: Dictionary in _root_children:
		_branch.add_item(CardData.action_name(child.action))
	_branch.select(clampi(old_branch, 0, _branch.item_count - 1))
	_layout_tree()
	_fit()
	_show_details({})
	_refresh_fuzzy()

func _update_summary() -> void:
	var phase: String = trace.get("view_phase", "HISTORY") if follow_live else "HELD SNAPSHOT"
	var decision: String = "decision #%d" % trace.decision_id if trace.has("decision_id") else "next deployment"
	_summary.text = "%s  /  %s  /  snapshot %.2fs left  /  %d legal moves  /  %d recorded nodes  /  %s" % [phase, decision,
		trace.root_snapshot.remaining_time, trace.legal_actions.size(), trace.nodes.size(),
		"partial sampled MCTS telemetry" if trace.get("view_partial", false) else ("complete" if trace.complete else "search in progress")]

func _set_tab(index: int) -> void:
	_tab = index
	for control in _tree_controls:
		control.visible = index == 0
	_scroll.visible = index == 0
	_details.visible = index == 0
	_fuzzy.visible = index == 1
	_fuzzy_source.visible = index == 1
	_refresh_fuzzy()

func _refresh_fuzzy() -> void:
	if _fuzzy == null:
		return
	_fuzzy_source.text = "SOURCE: LIVE FIELD" if _live_field else "SOURCE: DECISION"
	if _live_field and controller != null and controller.manager.battle_state != null:
		_fuzzy.show_assessment(TacticalFuzzy.assess(controller.manager.battle_state, _team), "LIVE BATTLEFIELD  /  %s  /  %.2fs left. Search weights may use a predicted deployment snapshot." % [GameConstants.team_name(_team), controller.manager.battle_state.remaining_time])
	elif not trace.is_empty():
		_fuzzy.show_assessment(trace.assessment, "DECISION SNAPSHOT  /  exact inputs and weights used by %s at %.2fs left" % [trace.algorithm, trace.root_snapshot.remaining_time])

func _layout_tree() -> void:
	_shown = []
	_rects = {}
	if trace.is_empty() or trace.nodes.is_empty():
		_canvas.queue_redraw()
		return
	var nodes: Dictionary = {}
	var children: Dictionary = {}
	for node: Dictionary in trace.nodes:
		nodes[node.id] = node
		if not children.has(node.parent):
			children[node.parent] = []
		children[node.parent].append(node.id)
	var ids: Dictionary = {0: true}
	if _branch.selected <= 0:
		for child: Dictionary in _root_children:
			ids[child.id] = true
	elif _branch.selected == 1:
		for id: int in nodes:
			ids[id] = true
	else:
		var pending: Array = [_root_children[_branch.selected - 2].id]
		while not pending.is_empty():
			var id: int = pending.pop_back()
			ids[id] = true
			pending.append_array(children.get(id, []))
	var widths: Dictionary = {}
	_measure(0, children, ids, widths)
	var width: float = maxf(1058, widths.get(0, 176))
	_place(0, (width - widths[0]) * 0.5, 16, nodes, children, ids, widths)
	var height: float = 0
	for rect: Rect2 in _rects.values():
		height = maxf(height, rect.end.y + 24)
	_logical_size = Vector2(width, maxf(570, height))
	_canvas.custom_minimum_size = _logical_size * _zoom
	_canvas.queue_redraw()

func _measure(id: int, children: Dictionary, ids: Dictionary, widths: Dictionary) -> float:
	var total: float = 0
	for child: int in children.get(id, []):
		if ids.has(child):
			total += _measure(child, children, ids, widths)
	widths[id] = maxf(176, total)
	return widths[id]

func _place(id: int, x: float, y: float, nodes: Dictionary, children: Dictionary, ids: Dictionary, widths: Dictionary) -> void:
	if not nodes.has(id):
		return
	_shown.append(nodes[id])
	_rects[id] = Rect2(x + widths[id] * 0.5 - 78, y, 156, 76)
	var start: float = x
	for child: int in children.get(id, []):
		if ids.has(child):
			_place(child, start, y + 124, nodes, children, ids, widths)
			start += widths[child]

func _fit() -> void:
	_zoom = clampf(minf(1, 1068.0 / _logical_size.x), 0.45, 1)
	_canvas.custom_minimum_size = _logical_size * _zoom
	_canvas.queue_redraw()
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0

func _zoom_action(index: int) -> void:
	if index == 2:
		_fit()
	else:
		_zoom = clampf(_zoom + (-0.15 if index == 0 else 0.15), 0.45, 1.6)
		_canvas.custom_minimum_size = _logical_size * _zoom
		_canvas.queue_redraw()

func _draw_tree() -> void:
	_canvas.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _zoom)
	var font: Font = ThemeDB.fallback_font
	for node: Dictionary in _shown:
		if node.parent >= 0 and _rects.has(node.parent):
			var parent_rect: Rect2 = _rects[node.parent]
			var rect: Rect2 = _rects[node.id]
			var a: Vector2 = Vector2(parent_rect.get_center().x, parent_rect.end.y)
			var b: Vector2 = Vector2(rect.get_center().x, rect.position.y)
			if node.get("pruned", false):
				_canvas.draw_dashed_line(a, b, Color("#ce8c8d"), 1.5, 5)
			else:
				_canvas.draw_line(a, b, Color("#5c7488"), 1.6, true)
	for node: Dictionary in _shown:
		var rect: Rect2 = _rects[node.id]
		var pruned: bool = node.get("pruned", false)
		var chosen: bool = node.parent == 0 and node.action == trace.selected_action and trace.complete
		var accent: Color = Color("#99c9ae") if chosen else (Color("#ce8c8d") if pruned else ArenaStyle.EDGE_BLUE)
		var style_key: String = accent.to_html() + str(chosen or node.id == _selected_node)
		if not _node_styles.has(style_key):
			_node_styles[style_key] = ArenaStyle.box(Color("#15222d"), accent, 2 if chosen or node.id == _selected_node else 1, 5)
		_canvas.draw_style_box(_node_styles[style_key], rect)
		var caption: String = "ROOT / " + GameConstants.team_name(trace.team).to_upper() if node.id == 0 else CardData.action_name(node.action)
		_canvas.draw_string(font, rect.position + Vector2(8, 22), caption, HORIZONTAL_ALIGNMENT_CENTER, 140, 14, ArenaStyle.TEXT)
		var detail: String = "not evaluated" if pruned else "evaluating…"
		if node.has("visits"):
			detail = "n %d    Q %.3f" % [node.visits, node.mean]
		elif node.has("score"):
			var prefix: String = "≤ " if node.get("bound", "exact") == "upper" else ("≥ " if node.get("bound", "exact") == "lower" else "")
			detail = prefix + "%.4f" % node.score
		_canvas.draw_string(font, rect.position + Vector2(8, 46), detail, HORIZONTAL_ALIGNMENT_CENTER, 140, 15, accent)
		var role: String = "pruned" if pruned else ((GameConstants.team_name(node.actor) + " turn") if trace.algorithm == "MCTS" else ("MAX" if node.actor == trace.team else "MIN"))
		_canvas.draw_string(font, rect.position + Vector2(8, 65), "#%d / %s" % [node.id, role], HORIZONTAL_ALIGNMENT_CENTER, 140, 11, ArenaStyle.MUTED)

func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for node: Dictionary in _shown:
			if _rects[node.id].has_point(event.position / _zoom):
				set_follow(false)
				_selected_node = node.id
				_show_details(node)
				_canvas.queue_redraw()
				break

func _show_details(node: Dictionary) -> void:
	if trace.is_empty():
		return
	var lines: Array[String] = ["ACTUAL DECISION DATA", ""]
	if node.is_empty():
		lines.append("Select a root branch to expand its recorded descendants. Click a node to hold this view and inspect it.\n\nGreen: selected action. Dashed red: pruned, with no evaluated score.")
		if trace.legal_actions.size() == 1:
			lines.append("\nOnly Wait is legal here: energy, cooldowns, unit cap or spell targets restrict the deck.")
	else:
		lines.append("Node #%d / %s\n%s acts next. Scores favor %s." % [node.id, "Root game state" if node.id == 0 else CardData.action_name(node.action), GameConstants.team_name(node.actor), GameConstants.team_name(trace.team)])
	if node.has("alpha_before"):
		lines.append("\nα: %s → %s\nβ: %s → %s\nBound: %s%s" % [str(node.alpha_before), str(node.get("alpha_after", node.alpha_before)), str(node.beta_before), str(node.get("beta_after", node.beta_before)), node.get("bound", "exact"), " (cutoff)" if node.get("cutoff", false) else ""])
	if node.get("pruned", false):
		lines.append("\nPruned: this child was never evaluated. No score is invented.")
	elif node.has("features"):
		lines.append("\nLEAF SCORE")
		for key: String in ["T", "U", "E", "P"]:
			lines.append("%s: %.6f × %.3f\n     = %.6f" % [key, node.features[key], trace.assessment.weights[key], node.contributions[key]])
		lines.append("Total = %.6f%s" % [node.score, " (terminal override)" if node.terminal else ""])
	if node.has("visits"):
		lines.append("\nMCTS STATISTICS\nVisits = %d\nTotal root reward = %.6f\nQ = total / visits = %.6f" % [node.visits, node.total_value, node.mean])
		for parent: Dictionary in trace.nodes:
			if parent.id == node.parent and node.visits > 0:
				var exploitation: float = node.mean if parent.actor == trace.team else 1.0 - node.mean
				var explore: float = MCTSAgent.EXPLORATION * sqrt(log(maxi(1, parent.visits)) / node.visits)
				lines.append("\nUCT at these recorded counts:\n%s + 1.41 × √(ln(%d)/%d)\n= %.5f + %.5f = %.5f" % ["Q" if parent.actor == trace.team else "1 − Q", parent.visits, node.visits, exploitation, explore, exploitation + explore])
	if trace.algorithm == "MCTS" and not trace.iterations.is_empty():
		var iteration: Dictionary = trace.iterations[-1]
		lines.append("\nLATEST RECORDED TRIAL %d\nExpansion: %s\nReward %.5f (%s)" % [iteration.trial, CardData.action_name(iteration.expansion_action) if not iteration.expansion_action.is_empty() else "none", iteration.rollout.reward, iteration.rollout.source])
		for step: Dictionary in iteration.get("selection_steps", []):
			lines.append("Selection at #%d (%s):" % [step.parent, GameConstants.team_name(step.actor)])
			for candidate: Dictionary in step.candidates:
				lines.append("%s: %.5f + %s = %s%s" % [CardData.action_name(candidate.action), candidate.exploitation, _number(candidate.exploration), _number(candidate.uct), " ✓" if candidate.node == step.chosen else ""])
		lines.append("Rollout:")
		for move: Dictionary in iteration.rollout.actions:
			lines.append(GameConstants.team_name(move.team) + " " + CardData.action_name(move.action))
		for update: Dictionary in iteration.backup:
			lines.append("Backup #%d: n %d → %d; total %.4f → %.4f" % [update.node, update.visits_before, update.visits_after, update.value_before, update.value_after])
		lines.append("\nThe first and last three trials are recorded. Intermediate trial logs are not fabricated.")
	lines.append("\nFuzzy Calculation shows memberships, fired rules and the weights used here. Export retains the snapshot and all recorded nodes%s." % (" (trace cap reached)" if trace.trace_truncated else ""))
	_details.text = "\n".join(lines)

func _number(value: Variant) -> String:
	return "%.5f" % float(value) if value is float or value is int else str(value)
