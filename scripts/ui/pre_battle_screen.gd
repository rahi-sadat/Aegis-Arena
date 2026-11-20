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
	MenuDesign.backdrop(self, background, 0.84)
	MenuDesign.brand(self, "01  /  BATTLE SETUP")
	ArenaStyle.text(self, Rect2(96, 139, 1250, 70), "Set the terms.", 49, ArenaStyle.TEXT, true)
	ArenaStyle.text(self, Rect2(98, 211, 1250, 31), "Choose your mode. Set each commander. Take the same five cards into battle.", 20, ArenaStyle.MUTED)
	var back := ArenaStyle.button("BACK TO TITLE")
	ArenaStyle.mount(self, back, Rect2(1560, 35, 264, 44))
	back.pressed.connect(_return_to_title)
	_make_modes()
	_make_commanders()
	_make_deck()
	var begin := ArenaStyle.button("ENTER BATTLE", true)
	ArenaStyle.mount(self, begin, Rect2(1472, 994, 352, 56))
	begin.pressed.connect(func() -> void: ArenaTransition.go(self, BATTLE))
	ArenaStyle.text(self, Rect2(98, 990, 1310, 64), "Human play: select a card to pause and plan. Choose a lane to resume.\nSpectating: press F2 for the live decision lab; hold a snapshot to explain it.", 17, ArenaStyle.MUTED)
	_refresh()
	begin.grab_focus()
	ArenaStyle.enter(self)

# --- Battle mode and match format -------------------------------------------------

func _make_modes() -> void:
	var panel := ArenaStyle.panel(self, Rect2(96, 265, 470, 438), ArenaStyle.GOLD)
	MenuDesign.eyebrow(panel, Rect2(22, 18, 426, 28), "HOW DO YOU WANT TO PLAY?")
	var captions := ["AI VS AI", "HUMAN VS AI"]
	var hints := ["Spectate", "You play Blue"]
	for index in captions.size():
		var choice := ArenaStyle.button(captions[index])
		choice.name = "Mode" + str(index)
		ArenaStyle.selectable(choice)
		choice.alignment = HORIZONTAL_ALIGNMENT_LEFT
		choice.text = "    " + captions[index]
		choice.tooltip_text = hints[index]
		ArenaStyle.mount(panel, choice, Rect2(22, 62 + index * 82, 426, 66))
		ArenaStyle.text(choice, Rect2(235, 0, 172, 66), hints[index], 15, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
		choice.pressed.connect(_choose_mode.bind(index))
		_mode_buttons.append(choice)
	_mode_note = ArenaStyle.text(panel, Rect2(22, 232, 426, 50), "", 17, ArenaStyle.MUTED)
	_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var facts := [
		["Match", "3 minutes"], ["Battlefield", "2 lanes"],
		["Energy", "10  /  +1 per sec"], ["Deployment slots", "%.2f sec" % MatchConfig.DECISION_INTERVAL_SECONDS],
	]
	for index in facts.size():
		var column := index % 2
		@warning_ignore("integer_division")
		var row := index / 2
		var origin := Vector2(22 + column * 222, 304 + row * 58)
		ArenaStyle.text(panel, Rect2(origin, Vector2(210, 20)), facts[index][0].to_upper(), 11, ArenaStyle.MUTED)
		ArenaStyle.text(panel, Rect2(origin + Vector2(0, 21), Vector2(210, 26)), facts[index][1], 17, ArenaStyle.TEXT, true)

func _choose_mode(index: int) -> void:
	MatchConfig.mode = index as MatchConfig.Mode
	_refresh()

# --- Commander logic ------------------------------------------------------------

func _make_commanders() -> void:
	_commander(self, GameConstants.Team.BLUE, 590, DeckArt.BLUE_PORTRAIT)
	_commander(self, GameConstants.Team.RED, 1219, DeckArt.RED_PORTRAIT)

func _commander(panel: Control, team: int, x: int, _portrait: Texture2D) -> void:
	var accent := GameConstants.team_color(team)
	var prefix := GameConstants.team_name(team)
	var card := ArenaStyle.panel(panel, Rect2(x, 265, 605, 438), accent)
	card.name = prefix + "Commander"
	ArenaStyle.icon(card, Rect2(24, 26, 37, 43), ArenaIcon.Kind.SHIELD, accent)
	ArenaStyle.text(card, Rect2(80, 22, 480, 32), prefix.to_upper() + " COMMANDER", 22, accent, true)
	var current := ArenaStyle.text(card, Rect2(24, 91, 557, 32), "", 21, ArenaStyle.TEXT, true)
	var lock := ArenaStyle.text(card, Rect2(80, 53, 480, 24), "", 14, ArenaStyle.MUTED)
	MenuDesign.eyebrow(card, Rect2(24, 145, 557, 22), "SEARCH ALGORITHM")
	var choices: Array[Button] = []
	for algorithm in MatchConfig.ALGORITHM_SHORT.size():
		var option := ArenaStyle.button(MatchConfig.ALGORITHM_SHORT[algorithm])
		option.name = prefix + "Algorithm" + str(algorithm)
		ArenaStyle.selectable(option, accent)
		option.add_theme_font_size_override("font_size", 16)
		option.tooltip_text = MatchConfig.ALGORITHM_NOTES[algorithm]
		ArenaStyle.mount(card, option, Rect2(24 + algorithm * 190, 177, 176, 48))
		option.pressed.connect(_choose_algorithm.bind(team, algorithm))
		choices.append(option)
	var param := ArenaStyle.text(card, Rect2(24, 250, 260, 44), "", 18, ArenaStyle.TEXT)
	var minus := ArenaStyle.button("−")
	minus.name = prefix + "Decrease"
	ArenaStyle.mount(card, minus, Rect2(338, 250, 48, 44))
	minus.pressed.connect(_adjust.bind(team, -1))
	var value := ArenaStyle.text(card, Rect2(394, 250, 116, 44), "", 23, ArenaStyle.GOLD, true, HORIZONTAL_ALIGNMENT_CENTER)
	var plus := ArenaStyle.button("+")
	plus.name = prefix + "Increase"
	ArenaStyle.mount(card, plus, Rect2(522, 250, 48, 44))
	plus.pressed.connect(_adjust.bind(team, 1))
	var note := ArenaStyle.text(card, Rect2(24, 330, 557, 78), "", 17, ArenaStyle.MUTED)
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
	var panel := ArenaStyle.panel(self, Rect2(96, 733, 1728, 234))
	MenuDesign.eyebrow(panel, Rect2(22, 12, 800, 32), "YOUR COMMAND DECK")
	ArenaStyle.text(panel, Rect2(1000, 12, 700, 32), "SAME FIVE CARDS FOR BOTH COMMANDERS", 12, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	for index in DeckArt.NAMES.size():
		var x := 22 + index * 341
		var card := CARD.instantiate() as BattleCardSlot
		card.name = DeckArt.NAMES[index]
		ArenaStyle.mount(panel, card, Rect2(x, 62, 104, 150))
		card.build(index, DeckArt.CARDS[index])
		card.set_display_only()
		var accent: Color = DeckArt.ACCENTS[index]
		ArenaStyle.text(panel, Rect2(x + 120, 72, 205, 28), DeckArt.NAMES[index].to_upper(), 18, accent, true)
		ArenaStyle.text(panel, Rect2(x + 120, 109, 205, 24), "%d energy  /  %d sec" % [DeckArt.COSTS[index], DeckArt.COOLDOWNS[index]], 15, ArenaStyle.MUTED)
		var role := ArenaStyle.text(panel, Rect2(x + 120, 151, 200, 50), DeckArt.ROLES[index], 17, ArenaStyle.TEXT)
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		role.vertical_alignment = VERTICAL_ALIGNMENT_TOP

func _return_to_title() -> void:
	ArenaTransition.go(self, TITLE)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_title()
