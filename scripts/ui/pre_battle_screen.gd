extends Control
## Battle setup: mode, each commander's search algorithm and its parameter, and the deck.

const TITLE := "res://scenes/ui/screens/TitleScreen.tscn"
const BATTLE := "res://scenes/main/Main.tscn"
const CARD := preload("res://scenes/ui/components/CardSlot.tscn")

@export var background: Texture2D

var _mode_buttons: Array[Button] = []
var _mode_note: Label
## Per team: {"algorithms": Array[Button], "minus", "plus", "value", "param", "note", "current", "lock"}
var _commanders: Array[Dictionary] = [{}, {}]

func _ready() -> void:
	ArenaStyle.art(self, Rect2(0, 0, 1920, 1080), background)
	var shade := ArenaStyle.veil(self, Color(0.020, 0.029, 0.052, 0.76))
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.text(self, Rect2(115, 50, 1250, 72), "BEFORE THE BATTLE", 51, ArenaStyle.TEXT, true)
	ArenaStyle.text(self, Rect2(119, 122, 1200, 31), "Choose the battle mode, commander logic, and search settings before the arena opens.", 21, ArenaStyle.GOLD)
	var back := ArenaStyle.button("BACK TO TITLE")
	ArenaStyle.mount(self, back, Rect2(1537, 72, 264, 54))
	back.pressed.connect(_return_to_title)
	_make_modes()
	_make_commanders()
	_make_deck()
	var begin := ArenaStyle.button("ENTER BATTLE", true)
	ArenaStyle.mount(self, begin, Rect2(1337, 950, 464, 68))
	begin.pressed.connect(func() -> void: get_tree().change_scene_to_file(BATTLE))
	ArenaStyle.text(self, Rect2(119, 950, 1180, 68), "Both sides use the same five cards. Units fight while deployment turns alternate.\nHuman: select a card to pause and plan; click a lane or A / D to confirm. Tab also pauses.", 18, ArenaStyle.MUTED)
	_refresh()
	begin.grab_focus()

# --- Battle mode and match format -------------------------------------------------

func _make_modes() -> void:
	var panel := ArenaStyle.panel(self, Rect2(116, 178, 540, 432), ArenaStyle.GOLD)
	ArenaStyle.text(panel, Rect2(24, 16, 480, 44), "BATTLE MODE", 26, ArenaStyle.GOLD, true)
	var captions := ["AI VS AI", "HUMAN VS AI"]
	var hints := ["Main demo mode", "Playable extension"]
	for index in captions.size():
		var choice := ArenaStyle.button(captions[index])
		choice.name = "Mode" + str(index)
		ArenaStyle.selectable(choice)
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.text = "    " + captions[index]
		choice.tooltip_text = hints[index]
		ArenaStyle.mount(panel, choice, Rect2(25, 70 + index * 66, 490, 54))
		var hint := ArenaStyle.text(choice, Rect2(250, 0, 222, 54), hints[index], 16, Color(1, 1, 1, 0.85), false, HORIZONTAL_ALIGNMENT_RIGHT)
		hint.add_theme_color_override("font_outline_color", ArenaStyle.OUTLINE)
		hint.add_theme_constant_override("outline_size", 4)
		choice.pressed.connect(_choose_mode.bind(index))
		_mode_buttons.append(choice)
	_mode_note = ArenaStyle.text(panel, Rect2(28, 200, 484, 30), "", 17, ArenaStyle.MUTED)
	ArenaStyle.text(panel, Rect2(24, 248, 480, 36), "MATCH FORMAT", 22, ArenaStyle.GOLD, true)
	var facts := [
		["Timer", "3:00"], ["Arena", "2 lanes"],
		["Max energy", "10"], ["Structures", "3 towers / side"],
		["Energy regen", "+1 / s"], ["Decision interval", "%.2f s" % MatchConfig.DECISION_INTERVAL_SECONDS],
	]
	for index in facts.size():
		var column := index % 2
		@warning_ignore("integer_division")
		var row := index / 2
		var origin := Vector2(28 + column * 248, 292 + row * 44)
		ArenaStyle.text(panel, Rect2(origin, Vector2(240, 20)), facts[index][0].to_upper(), 13, ArenaStyle.MUTED)
		ArenaStyle.text(panel, Rect2(origin + Vector2(0, 17), Vector2(240, 26)), facts[index][1], 19, ArenaStyle.TEXT, true)

func _choose_mode(index: int) -> void:
	MatchConfig.mode = index as MatchConfig.Mode
	_refresh()

# --- Commander logic ------------------------------------------------------------

func _make_commanders() -> void:
	var panel := ArenaStyle.panel(self, Rect2(686, 178, 1114, 432))
	ArenaStyle.text(panel, Rect2(24, 16, 1060, 45), "COMMANDER LOGIC", 26, ArenaStyle.GOLD, true)
	_commander(panel, GameConstants.Team.BLUE, 22, DeckArt.BLUE_PORTRAIT)
	_commander(panel, GameConstants.Team.RED, 568, DeckArt.RED_PORTRAIT)
	ArenaStyle.text(panel, Rect2(26, 392, 1060, 30), "Shared tactical layer:  Fuzzy Logic     •     Shared routing:  A* Pathfinding", 18, ArenaStyle.MUTED)

func _commander(panel: Panel, team: int, x: int, _portrait: Texture2D) -> void:
	var accent := GameConstants.team_color(team)
	var prefix := GameConstants.team_name(team)
	var card := ArenaStyle.panel(panel, Rect2(x, 66, 524, 318), accent)
	card.name = prefix + "Commander"
	var frame := ArenaStyle.panel(card, Rect2(12, 12, 86, 86), accent)
	ArenaStyle.icon(frame, Rect2(22, 18, 42, 48), ArenaIcon.Kind.SHIELD, accent)
	ArenaStyle.text(card, Rect2(112, 14, 400, 30), prefix.to_upper() + " COMMANDER", 21, accent, true)
	var current := ArenaStyle.text(card, Rect2(112, 46, 400, 28), "", 18, ArenaStyle.TEXT, true)
	var lock := ArenaStyle.text(card, Rect2(112, 72, 400, 24), "", 15, ArenaStyle.MUTED)
	ArenaStyle.text(card, Rect2(16, 110, 300, 22), "SEARCH ALGORITHM", 14, ArenaStyle.GOLD, true)
	var choices: Array[Button] = []
	for algorithm in MatchConfig.ALGORITHM_SHORT.size():
		var option := ArenaStyle.button(MatchConfig.ALGORITHM_SHORT[algorithm])
		option.name = prefix + "Algorithm" + str(algorithm)
		ArenaStyle.selectable(option, accent)
		option.add_theme_font_size_override("font_size", 16)
		option.tooltip_text = MatchConfig.ALGORITHM_NOTES[algorithm]
		ArenaStyle.mount(card, option, Rect2(16 + algorithm * 166, 136, 158, 46))
		option.pressed.connect(_choose_algorithm.bind(team, algorithm))
		choices.append(option)
	var param := ArenaStyle.text(card, Rect2(16, 196, 200, 40), "", 17, ArenaStyle.TEXT)
	var minus := ArenaStyle.button("−")
	minus.name = prefix + "Decrease"
	ArenaStyle.mount(card, minus, Rect2(230, 196, 46, 40))
	minus.pressed.connect(_adjust.bind(team, -1))
	var value := ArenaStyle.text(card, Rect2(282, 196, 100, 40), "", 21, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	var plus := ArenaStyle.button("+")
	plus.name = prefix + "Increase"
	ArenaStyle.mount(card, plus, Rect2(388, 196, 46, 40))
	plus.pressed.connect(_adjust.bind(team, 1))
	var note := ArenaStyle.text(card, Rect2(16, 246, 492, 60), "", 15, ArenaStyle.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_commanders[team] = {
		"algorithms": choices, "minus": minus, "plus": plus, "value": value,
		"param": param, "note": note, "current": current, "lock": lock,
	}

func _choose_algorithm(team: int, algorithm: int) -> void:
	MatchConfig.set_algorithm(team, algorithm as MatchConfig.Algorithm)
	_refresh()

func _adjust(team: int, steps: int) -> void:
	MatchConfig.adjust_parameter(team, steps)
	_refresh()

func _refresh() -> void:
	for index in _mode_buttons.size():
		_mode_buttons[index].set_pressed_no_signal(index == MatchConfig.mode)
	_mode_note.text = "Blue: you  •  Red: AI opponent" if MatchConfig.mode == MatchConfig.Mode.HUMAN_VS_AI else "Both commanders are controlled by search agents."
	for team in _commanders.size():
		var view: Dictionary = _commanders[team]
		var human := MatchConfig.is_human(team)
		var selected: int = MatchConfig.algorithms[team]
		var choices: Array[Button] = view.algorithms
		for index in choices.size():
			choices[index].set_pressed_no_signal(index == selected)
			choices[index].disabled = human
		view.current.text = MatchConfig.describe(team)
		view.lock.text = "Plays from the command deck" if human else ("Opponent" if MatchConfig.mode == MatchConfig.Mode.HUMAN_VS_AI else "Autonomous commander")
		view.param.text = MatchConfig.parameter_name(team)
		view.value.text = str(MatchConfig.parameter_value(team))
		var low := MatchConfig.DEPTH_RANGE.x if MatchConfig.uses_depth(team) else MatchConfig.ITERATION_RANGE.x
		var high := MatchConfig.DEPTH_RANGE.y if MatchConfig.uses_depth(team) else MatchConfig.ITERATION_RANGE.y
		var amount := MatchConfig.parameter_value(team)
		view.minus.disabled = human or amount <= low
		view.plus.disabled = human or amount >= high
		view.note.text = "The human player picks cards and lanes; no search runs for this side." if human else MatchConfig.ALGORITHM_NOTES[selected]

# --- Deck -----------------------------------------------------------------------

func _make_deck() -> void:
	var panel := ArenaStyle.panel(self, Rect2(116, 634, 1684, 292))
	ArenaStyle.text(panel, Rect2(24, 12, 560, 40), "SELECTED DECK", 24, ArenaStyle.GOLD, true)
	ArenaStyle.text(panel, Rect2(1100, 12, 560, 40), "5 CARDS", 18, ArenaStyle.MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	for index in DeckArt.NAMES.size():
		var x := 26 + index * 330
		var card := CARD.instantiate() as BattleCardSlot
		card.name = DeckArt.NAMES[index]
		ArenaStyle.mount(panel, card, Rect2(x, 56, 165, 220))
		card.build(index, DeckArt.CARDS[index])
		card.set_display_only()
		var accent: Color = DeckArt.ACCENTS[index]
		ArenaStyle.text(panel, Rect2(x + 178, 74, 145, 28), DeckArt.NAMES[index].to_upper(), 19, accent, true)
		ArenaStyle.text(panel, Rect2(x + 178, 108, 145, 24), "Cost %d" % DeckArt.COSTS[index], 17, ArenaStyle.VIOLET, true)
		var role := ArenaStyle.text(panel, Rect2(x + 178, 136, 140, 50), DeckArt.ROLES[index], 16, ArenaStyle.TEXT)
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		ArenaStyle.text(panel, Rect2(x + 178, 192, 145, 24), "%d s cooldown" % DeckArt.COOLDOWNS[index], 15, ArenaStyle.MUTED)
	ArenaStyle.text(panel, Rect2(1532, 230, 140, 46), "Enemy targets only\nNo friendly fire", 13, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)

func _return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_title()
