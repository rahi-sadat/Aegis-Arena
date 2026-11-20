class_name FuzzyInspector
extends Control
## Displays the exact assessment used by a decision, or a labelled live assessment.

var assessment: Dictionary = {}
var _plots: Array[Control] = []
var _values: Array[Label] = []
var _calculations: Array[Label] = []
var _weights: Label
var _source: Label

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_source = ArenaStyle.text(self, Rect2(0, 0, 1516, 32), "", 17, ArenaStyle.MUTED)
	for index in 3:
		var x: float = index * 512
		var card := ArenaStyle.panel(self, Rect2(x, 58, 492, 476), Color("#485b6b"))
		ArenaStyle.text(card, Rect2(22, 15, 448, 34), ["THREAT", "OPPORTUNITY", "ENERGY RESERVE"][index], 20, ArenaStyle.TEXT, true)
		_values.append(ArenaStyle.text(card, Rect2(22, 56, 448, 48), "", 16, ArenaStyle.MUTED))
		var plot := Control.new()
		plot.mouse_filter = MOUSE_FILTER_IGNORE
		ArenaStyle.mount(card, plot, Rect2(22, 123, 448, 158))
		plot.draw.connect(_draw_membership.bind(plot, index))
		_plots.append(plot)
		_calculations.append(ArenaStyle.text(card, Rect2(22, 293, 448, 167), "", 16, ArenaStyle.TEXT))
	var panel := ArenaStyle.panel(self, Rect2(0, 553, 1516, 112), ArenaStyle.GOLD)
	MenuDesign.eyebrow(panel, Rect2(22, 9, 1472, 25), "EVALUATION WEIGHTS  /  ZERO-ORDER SUGENO")
	_weights = ArenaStyle.text(panel, Rect2(22, 41, 1472, 58), "", 18, ArenaStyle.TEXT)

func clear_assessment() -> void:
	assessment = {}
	_source.text = "Waiting for an assessment in the current match."
	_weights.text = ""
	for index in 3:
		_values[index].text = ""
		_calculations[index].text = ""
		_plots[index].queue_redraw()

func show_assessment(value: Dictionary, source: String) -> void:
	assessment = value.duplicate(true)
	_source.text = source
	var keys: Array[String] = ["threat", "opportunity", "energy"]
	for index in 3:
		var key: String = keys[index]
		var degrees: Dictionary = assessment.memberships[key]
		var output: String = ["defend", "attack", "save"][index]
		var constants: Array = assessment.rules[output]
		var total: float = degrees.low + degrees.medium + degrees.high
		var numerator: float = degrees.low * constants[0] + degrees.medium * constants[1] + degrees.high * constants[2]
		_values[index].text = ["Enemy HP in our half / 400, clamped to 0–1", "Largest missing enemy structure HP fraction", "Our energy / 10"][index] + "\nx = %.4f" % assessment.inputs[key]
		_calculations[index].text = "RULE          FIRING μ       OUTPUT\nLow              %.3f             %.1f\nMedium       %.3f             %.1f\nHigh             %.3f             %.1f\n\n(%.3f×%.1f + %.3f×%.1f + %.3f×%.1f) / %.3f\n%s = %.4f / %.3f = %.4f" % [degrees.low, constants[0], degrees.medium, constants[1], degrees.high, constants[2],
			degrees.low, constants[0], degrees.medium, constants[1], degrees.high, constants[2], total, output.to_upper(), numerator, total, assessment.outputs[output]]
		_plots[index].queue_redraw()
	_weights.text = "T = 100     U = 20 + 10 × defend = %.3f     E = 2 + 4 × save = %.3f     P = 10 + 10 × attack = %.3f\nLeaf score = T × tower difference + U × unit HP difference + E × energy difference + P × lane pressure difference" % [assessment.weights.U, assessment.weights.E, assessment.weights.P]

func _draw_membership(plot: Control, index: int) -> void:
	if assessment.is_empty():
		return
	var origin := Vector2(28, 112)
	var width: float = 386
	var height: float = 90
	var font: Font = ThemeDB.fallback_font
	var colors: Array[Color] = [Color("#86b7cc"), Color("#d7bc85"), Color("#c38d97")]
	plot.draw_line(origin, origin + Vector2(width, 0), ArenaStyle.MUTED, 1, true)
	plot.draw_line(origin, origin - Vector2(0, height), ArenaStyle.MUTED, 1, true)
	plot.draw_polyline(PackedVector2Array([origin - Vector2(0, height), origin + Vector2(width * 0.5, 0), origin + Vector2(width, 0)]), colors[0], 2, true)
	plot.draw_polyline(PackedVector2Array([origin, origin + Vector2(width * 0.5, -height), origin + Vector2(width, 0)]), colors[1], 2, true)
	plot.draw_polyline(PackedVector2Array([origin, origin + Vector2(width * 0.5, 0), origin + Vector2(width, -height)]), colors[2], 2, true)
	var key: String = ["threat", "opportunity", "energy"][index]
	var x: float = origin.x + assessment.inputs[key] * width
	plot.draw_dashed_line(Vector2(x, origin.y), Vector2(x, origin.y - height), Color.WHITE, 1, 4)
	for level in 3:
		var degree: float = assessment.memberships[key][["low", "medium", "high"][level]]
		plot.draw_circle(Vector2(x, origin.y - degree * height), 4, colors[level], true, -1, true)
		plot.draw_string(font, Vector2(28 + level * 137, 12), ["LOW", "MEDIUM", "HIGH"][level], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, colors[level])
	for tick in 3:
		plot.draw_string(font, origin + Vector2(tick * width * 0.5 - 5, 22), ["0", "0.5", "1"][tick], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ArenaStyle.MUTED)
