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

func _ready() -> void:
	ArenaStyle.decorate(self, GameConstants.BLUE_COLOR)
	ArenaStyle.text(self, Rect2(22, 10, 267, 36), "AI INSIGHT · BLUE", 20, ArenaStyle.GOLD, true)
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
	_unit_portrait = ArenaStyle.art(_body, Rect2(0, 264, 58, 61), null)
	_action = ArenaStyle.text(_body, Rect2(0, 265, 324, 26), "", 17, ArenaStyle.TEXT)
	_cost = ArenaStyle.text(_body, Rect2(70, 296, 250, 24), "", 16, ArenaStyle.VIOLET)
	_details = ArenaStyle.text(_body, Rect2(0, 332, 324, 60), "", 15, ArenaStyle.MUTED)
	set_preview(false)

func set_preview(enabled: bool, tank_art: Texture2D = null) -> void:
	_status.text = "SAMPLE ASSESSMENT" if enabled else "AI SYSTEMS NOT ACTIVE"
	for index in _bars.size():
		_bars[index].value = SAMPLE[index] if enabled else 0.0
		_values[index].text = "%.2f" % SAMPLE[index] if enabled else "—"
	_intent.text = "DEFEND LEFT" if enabled else "Attack  /  Defend  /  Save"
	_intent.modulate = Color.WHITE if enabled else ArenaStyle.MUTED
	_unit_portrait.texture = tank_art
	_unit_portrait.visible = enabled
	_action.position.x = 70.0 if enabled else 0.0
	_action.size.x = 250.0 if enabled else 324.0
	_action.text = "TANK  →  LEFT LANE" if enabled else "Awaiting commander logic"
	_cost.text = "◆  5 energy" if enabled else ""
	_details.text = "Sample deployment for HUD review." if enabled else "A* navigation · Phase 3\nFuzzy logic · Phase 6\nMinimax + alpha-beta · Phase 7  /  MCTS · 8"

func _collapse() -> void:
	_expanded = not _expanded
	_body.visible = _expanded
	if _expanded:
		ArenaStyle.enter(_body)
	size.y = 460.0 if _expanded else 57.0
	_toggle.text = "−" if _expanded else "+"
	_toggle.tooltip_text = "Collapse AI insight" if _expanded else "Expand AI insight"
