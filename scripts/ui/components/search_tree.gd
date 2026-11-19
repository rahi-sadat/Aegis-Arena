class_name SearchTreeView
extends Panel
## Reads actual trace nodes. Select a branch, then click a leaf for its arithmetic.

signal export_requested

var controller: AIManager
var trace: Dictionary = {}
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

func _ready() -> void:
	ArenaStyle.decorate(self, ArenaStyle.EDGE_BLUE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_title = ArenaStyle.text(self, Rect2(20, 8, 700, 38), "SEARCH TREE", 23, ArenaStyle.GOLD, true)
	var blue_button := ArenaStyle.button("BLUE")
	ArenaStyle.mount(self, blue_button, Rect2(740, 12, 88, 34))
	blue_button.pressed.connect(show_team.bind(0))
	var red_button := ArenaStyle.button("RED")
	ArenaStyle.mount(self, red_button, Rect2(838, 12, 88, 34))
	red_button.pressed.connect(show_team.bind(1))
	var close := ArenaStyle.button("CLOSE")
	ArenaStyle.mount(self, close, Rect2(976, 12, 104, 34))
	close.pressed.connect(hide)
	_summary = ArenaStyle.text(self, Rect2(20, 48, 1060, 28), "", 15, ArenaStyle.MUTED)
	_branch = OptionButton.new()
	ArenaStyle.mount(self, _branch, Rect2(20, 82, 380, 34))
	_branch.add_theme_font_size_override("font_size", 16)
	_branch.item_selected.connect(func(_index: int) -> void: _layout_tree())
	_history = OptionButton.new()
	ArenaStyle.mount(self, _history, Rect2(418, 82, 470, 34))
	_history.add_theme_font_size_override("font_size", 15)
	_history.item_selected.connect(func(index: int) -> void: set_trace(_records[index]))
	var export_button := ArenaStyle.button("EXPORT [F7]")
	export_button.add_theme_font_size_override("font_size", 14)
	ArenaStyle.mount(self, export_button, Rect2(910, 82, 170, 34))
	export_button.pressed.connect(export_requested.emit)
	_scroll = ScrollContainer.new()
	ArenaStyle.mount(self, _scroll, Rect2(20, 126, 1060, 312))
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_canvas = Control.new()
	_scroll.add_child(_canvas)
	_canvas.custom_minimum_size = Vector2(1040, 292)
	_canvas.draw.connect(_draw_tree)
	_canvas.gui_input.connect(_on_tree_input)
	_details = RichTextLabel.new()
	_details.add_theme_font_size_override("normal_font_size", 15)
	_details.add_theme_color_override("default_color", ArenaStyle.TEXT)
	ArenaStyle.mount(self, _details, Rect2(20, 453, 1060, 190))
	hide()

func toggle() -> void:
	visible = not visible
	if visible:
		show_team(1 if MatchConfig.is_human(0) else _team)

func show_team(team: int) -> void:
	_team = team
	if controller == null or controller.last_traces[team].is_empty():
		trace = {}
		_records = []
		_root_children = []
		_rects = {}
		_history.clear()
		_branch.clear()
		_summary.text = "No recorded decision for this commander in the current match."
		_title.text = GameConstants.team_name(team).to_upper() + " - WAITING FOR A DECISION"
		_shown = []
		_canvas.queue_redraw()
		_details.text = "Run a match, then inspect a completed decision."
		return
	_records = controller.history[team].duplicate()
	_records.reverse()
	_history.clear()
	var selected: int = 0
	var found_branching: bool = false
	for index in _records.size():
		var record: Dictionary = _records[index]
		_history.add_item("Decision %d: %s (%.2fs left)" % [record.decision_id, CardData.action_name(record.selected_action), record.root_snapshot.remaining_time])
		if not found_branching and record.root_actions.size() > 1:
			selected = index
			found_branching = true
	_history.select(selected)
	set_trace(_records[selected] if not _records.is_empty() else controller.last_traces[team])

func set_trace(record: Dictionary) -> void:
	trace = record.duplicate(true)
	_title.text = "%s: %s" % [GameConstants.team_name(trace.team).to_upper(), trace.algorithm]
	_summary.text = "Recorded decision %s: %s | %d states | %.2f ms CPU | %s" % [str(trace.get("decision_id", "fixture")), CardData.action_name(trace.selected_action),
		trace.stats.visited, trace.stats.cpu_ms, "completed" if trace.complete else "INCOMPLETE"]
	_root_children = []
	for node: Dictionary in trace.nodes:
		if node.parent == 0:
			_root_children.append(node)
	_branch.clear()
	_branch.add_item("All root actions")
	var chosen: int = 0
	for index in _root_children.size():
		_branch.add_item(CardData.action_name(_root_children[index].action))
		if _root_children[index].action == trace.selected_action:
			chosen = index + 1
	_branch.select(0 if trace.nodes.size() <= 15 else chosen)
	_layout_tree()
	_show_details({})

func _layout_tree() -> void:
	_shown = []
	_rects = {}
	if trace.is_empty() or trace.nodes.is_empty():
		_canvas.queue_redraw()
		return
	var children: Array = _root_children.duplicate()
	if _branch.selected > 0 and _branch.selected <= children.size():
		children = [children[_branch.selected - 1]]
	var groups: Array = []
	var needed: float = 20.0
	for child: Dictionary in children:
		var leaves: Array = []
		for node: Dictionary in trace.nodes:
			if node.parent == child.id:
				leaves.append(node)
		var group_width: float = maxi(1, leaves.size()) * 132.0 + 24.0
		groups.append({"node": child, "leaves": leaves, "width": group_width})
		needed += group_width
	var width: float = maxf(1040.0, needed)
	_canvas.custom_minimum_size = Vector2(width, 292)
	_shown.append(trace.nodes[0])
	_rects[0] = Rect2(width * 0.5 - 76, 6, 152, 56)
	var x: float = (width - needed) * 0.5 + 10
	for group: Dictionary in groups:
		var child: Dictionary = group.node
		_shown.append(child)
		_rects[child.id] = Rect2(x + group.width * 0.5 - 59, 112, 118, 56)
		for index in group.leaves.size():
			var leaf: Dictionary = group.leaves[index]
			_shown.append(leaf)
			_rects[leaf.id] = Rect2(x + 12 + index * 132, 218, 118, 56)
		x += group.width
	_canvas.queue_redraw()
	_scroll.set_deferred("scroll_horizontal", int(maxf(0, width - 1040) * 0.5))

func _draw_tree() -> void:
	var font: Font = ThemeDB.fallback_font
	for node: Dictionary in _shown:
		if node.parent >= 0 and _rects.has(node.parent):
			var parent_rect: Rect2 = _rects[node.parent]
			var rect: Rect2 = _rects[node.id]
			var a: Vector2 = Vector2(parent_rect.get_center().x, parent_rect.end.y)
			var b: Vector2 = Vector2(rect.get_center().x, rect.position.y)
			if node.get("pruned", false):
				_canvas.draw_dashed_line(a, b, Color("#ee8877"), 1.5, 5.0)
			else:
				_canvas.draw_line(a, b, Color("#7c9abd"), 1.4, true)
	for node: Dictionary in _shown:
		var rect: Rect2 = _rects[node.id]
		var pruned: bool = node.get("pruned", false)
		var selected: bool = node.parent == 0 and node.action == trace.selected_action
		var accent: Color = Color("#7be2a7") if selected else (Color("#ee8877") if pruned else ArenaStyle.EDGE_BLUE)
		_canvas.draw_rect(rect, Color("#102138"))
		_canvas.draw_rect(rect, accent, false, 1.5)
		var caption: String = GameConstants.team_name(trace.team) + " MAX" if node.id == 0 else CardData.action_name(node.action)
		_canvas.draw_string(font, rect.position + Vector2(5, 20), caption, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 10, 13, ArenaStyle.TEXT)
		var detail: String = "not evaluated" if pruned else ""
		if node.has("visits"):
			detail = "n=%d  Q=%.3f" % [node.visits, node.mean]
		elif node.has("score"):
			var prefix: String = "<= " if node.get("bound", "exact") == "upper" else (">= " if node.get("bound", "exact") == "lower" else "")
			detail = prefix + "%.3f" % node.score
		_canvas.draw_string(font, rect.position + Vector2(4, 42), detail, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 13, accent)

func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for node: Dictionary in _shown:
			if _rects[node.id].has_point(event.position):
				_show_details(node)
				break

func _show_details(node: Dictionary) -> void:
	var assessment: Dictionary = trace.assessment
	var lines: Array[String] = []
	lines.append("Fuzzy outputs: attack %.3f, defend %.3f, save %.3f. Weights T=%.2f U=%.2f E=%.2f P=%.2f." % [
		assessment.outputs.attack, assessment.outputs.defend, assessment.outputs.save, assessment.weights.T,
		assessment.weights.U, assessment.weights.E, assessment.weights.P])
	for key: String in ["threat", "opportunity", "energy"]:
		var degree: Dictionary = assessment.memberships[key]
		lines.append("%s %.3f: low %.3f, medium %.3f, high %.3f" % [key.capitalize(), assessment.inputs[key], degree.low, degree.medium, degree.high])
	lines.append("Rules: attack/defend constants [0, 0.5, 1]; save [1, 0.5, 0]. Output = sum(degree * constant) / sum(degree).")
	if node.has("alpha_before"):
		lines.append("Node %d: alpha %s -> %s; beta %s -> %s; bound %s%s" % [node.id,
			str(node.alpha_before), str(node.get("alpha_after", node.alpha_before)), str(node.beta_before),
			str(node.get("beta_after", node.beta_before)), node.get("bound", "exact"), " (cutoff)" if node.get("cutoff", false) else ""])
	if node.has("visits"):
		lines.append("Node %d: %d visits, root reward total %.6f, Q %.6f." % [node.id, node.visits, node.total_value, node.mean])
	if not node.is_empty() and node.get("pruned", false):
		lines.append("This branch was pruned. No child state or score was calculated.")
	elif node.has("features"):
		for key: String in ["T", "U", "E", "P"]:
			lines.append("%s: %.6f * %.3f = %.6f" % [key, node.features[key], assessment.weights[key], node.contributions[key]])
		lines.append("Score = %.6f%s" % [node.score, " (terminal result overrides features)" if node.terminal else ""])
	elif trace.algorithm == "MCTS" and not trace.iterations.is_empty():
		var iteration: Dictionary = trace.iterations[-1]
		lines.append("Trial %d: expanded %s; reward %.6f (%s); rollout ends at ply %d." % [iteration.trial,
			CardData.action_name(iteration.expansion_action) if not iteration.expansion_action.is_empty() else "none",
			iteration.rollout.reward, iteration.rollout.source, iteration.rollout.depth])
		for step: Dictionary in iteration.get("selection_steps", []):
			lines.append("Selection at node %d, %s turn, parent visits %d:" % [step.parent, GameConstants.team_name(step.actor), step.parent_visits])
			for candidate: Dictionary in step.candidates:
				lines.append("  %s: Q %.5f, n %d; %.5f + %s = %s%s" % [CardData.action_name(candidate.action), candidate.mean,
					candidate.visits, candidate.exploitation, str(candidate.exploration), str(candidate.uct), " SELECTED" if candidate.node == step.chosen else ""])
		var sequence: Array[String] = []
		for move: Dictionary in iteration.rollout.actions:
			sequence.append(GameConstants.team_name(move.team) + " " + CardData.action_name(move.action))
		lines.append("Rollout: " + ", ".join(sequence))
		for update: Dictionary in iteration.backup:
			lines.append("Backup node %d: visits %d -> %d, total %.5f -> %.5f" % [update.node, update.visits_before, update.visits_after, update.value_before, update.value_after])
	else:
		lines.append("Click an evaluated leaf to inspect its four weighted contributions.")
	lines.append("View shows two plies. JSON export retains all recorded nodes and the root snapshot%s." % ("; trace limit reached" if trace.trace_truncated else ""))
	_details.text = "\n".join(lines)
