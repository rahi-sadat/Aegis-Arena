class_name AIInsightPanel
extends Panel

const METRICS := ["Threat", "Opportunity", "Energy"]
const SAMPLE := [0.62, 0.44, 0.71]
const TONES := [Color("#f77e7b"), Color("#8bd9a8"), Color("#b88aff")]
const ICONS := [ArenaIcon.Kind.SWORDS, ArenaIcon.Kind.TARGET, ArenaIcon.Kind.CRYSTAL]

var _toggle: Button
var _body: Control
var _status: Label
var _intent: Label
var _action: Label
var _details: Label
var _cost: Label
var _unit_portrait: TextureRect
var _bars: Array[ProgressBar] = []
var _values: Array[Label] = []
var _expanded: bool = true
var _title: Label
var _team: int = GameConstants.Team.BLUE

func _ready() -> void:
	ArenaStyle.decorate(self, GameConstants.BLUE_COLOR)
	_title = ArenaStyle.text(self, Rect2(22, 10, 280, 36), "AI INSIGHT · BLUE", 20, ArenaStyle.GOLD, true)
	_toggle = ArenaStyle.button("−")
	_toggle.tooltip_text = "Collapse AI insight"
	ArenaStyle.mount(self, _toggle, Rect2(306, 12, 42, 33))
	_toggle.pressed.connect(_collapse)
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArenaStyle.mount(self, _body, Rect2(22, 52, 324, 393))
	_status = ArenaStyle.text(_body, Rect2(0, 0, 324, 26), "", 16, GameConstants.BLUE_COLOR, true)
	ArenaStyle.text(_body, Rect2(0, 39, 324, 24), "TACTICAL ASSESSMENT", 16, ArenaStyle.GOLD, true)
	for index in METRICS.size():
		var y := 69 + index * 30
		ArenaStyle.icon(_body, Rect2(0, y + 4, 15, 16), ICONS[index], TONES[index])
		ArenaStyle.text(_body, Rect2(23, y, 100, 24), METRICS[index], 16, TONES[index])
		var bar := ArenaStyle.bar(TONES[index])
		ArenaStyle.mount(_body, bar, Rect2(126, y + 8, 144, 9))
		_bars.append(bar)
		_values.append(ArenaStyle.text(_body, Rect2(276, y, 46, 24), "", 16, ArenaStyle.TEXT, false, HORIZONTAL_ALIGNMENT_RIGHT))
	ArenaStyle.text(_body, Rect2(0, 166, 324, 25), "CURRENT INTENT", 16, ArenaStyle.GOLD, true)
	_intent = ArenaStyle.text(_body, Rect2(0, 194, 324, 26), "", 17, ArenaStyle.TEXT, true)
	ArenaStyle.text(_body, Rect2(0, 234, 324, 24), "CHOSEN ACTION", 16, ArenaStyle.GOLD, true)
	_unit_portrait = ArenaStyle.art(_body, Rect2(0, 262, 48, 64), null)
	_action = ArenaStyle.text(_body, Rect2(0, 265, 324, 26), "", 17, ArenaStyle.TEXT)
	_cost = ArenaStyle.text(_body, Rect2(70, 296, 250, 24), "", 16, ArenaStyle.VIOLET)
	_details = ArenaStyle.text(_body, Rect2(0, 332, 324, 60), "", 15, ArenaStyle.MUTED)
	set_preview(false)

func set_preview(enabled: bool, tank_art: Texture2D = null) -> void:
	var algorithm: String = MatchConfig.ALGORITHM_SHORT[MatchConfig.algorithms[_team]]
	_status.text = "SAMPLE ASSESSMENT" if enabled else algorithm + "  ·  PREPARING DECISION"
	for index in _bars.size():
		_bars[index].value = SAMPLE[index] if enabled else 0.0
		_values[index].text = "%.2f" % SAMPLE[index] if enabled else "—"
	_intent.text = "DEFEND LEFT" if enabled else "Attack  /  Defend  /  Save"
	_intent.modulate = Color.WHITE if enabled else ArenaStyle.MUTED
	_unit_portrait.texture = tank_art
	_unit_portrait.visible = enabled
	_action.position.x = 70.0 if enabled else 0.0
	_action.size.x = 250.0 if enabled else 324.0
	_action.text = "TANK  →  LEFT LANE" if enabled else "Waiting for first decision"
	_cost.text = "◆  5 energy" if enabled else ""
	_details.text = "Sample deployment for HUD review." if enabled else "Blue: %s\nRed: %s" % [MatchConfig.describe(GameConstants.Team.BLUE), MatchConfig.describe(GameConstants.Team.RED)]

## Follows the AI-controlled commander: Blue in AI vs AI, Red when a human plays Blue.
func follow_commander(team: int) -> void:
	_team = team
	_title.text = "AI INSIGHT · " + GameConstants.team_name(team).to_upper()
	_status.add_theme_color_override("font_color", GameConstants.team_color(team))
	set_preview(false)

func set_trace(trace: Dictionary) -> void:
	if trace.team != _team:
		return
	var assessment: Dictionary = trace.assessment
	var inputs: Dictionary = assessment.inputs
	var values: Array = [inputs.threat, inputs.opportunity, inputs.energy]
	for index in 3:
		_bars[index].value = values[index]
		_values[index].text = "%.2f" % values[index]
	_status.text = trace.algorithm.to_upper()
	var outputs: Dictionary = assessment.outputs
	var intent: String = "ATTACK" if outputs.attack >= outputs.defend and outputs.attack >= outputs.save else ("DEFEND" if outputs.defend >= outputs.save else "SAVE ENERGY")
	if maxf(outputs.attack, maxf(outputs.defend, outputs.save)) <= BattleRules.EPSILON:
		intent = "BALANCED"
	_intent.text = intent
	_intent.modulate = Color.WHITE
	var move: Dictionary = trace.execution.action
	_action.text = CardData.action_name(move).to_upper()
	_action.position.x = 60.0 if move.card >= 0 else 0.0
	_action.size.x = 264.0 if move.card >= 0 else 324.0
	_unit_portrait.visible = move.card >= 0
	_unit_portrait.texture = DeckArt.CARDS[move.card] if move.card >= 0 else null
	_cost.text = "%d energy" % CardData.COSTS[move.card] if move.card >= 0 else "No energy spent"
	_details.text = "%d states  /  %.1f ms CPU\n%s\nF2: tree and score details" % [trace.stats.visited, trace.stats.cpu_ms, trace.execution.status]

func _collapse() -> void:
	_expanded = not _expanded
	_body.visible = _expanded
	if _expanded:
		ArenaStyle.enter(_body)
	size.y = 460.0 if _expanded else 57.0
	_toggle.text = "−" if _expanded else "+"
	_toggle.tooltip_text = "Collapse AI insight" if _expanded else "Expand AI insight"
