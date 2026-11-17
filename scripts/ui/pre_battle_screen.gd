extends Control

const TITLE := "res://scenes/ui/screens/TitleScreen.tscn"
const BATTLE := "res://scenes/main/Main.tscn"
const CARD := preload("res://scenes/ui/components/CardSlot.tscn")

@export var background: Texture2D

func _ready() -> void:
	ArenaStyle.art(self, Rect2(0, 0, 1920, 1080), background)
	var shade := ArenaStyle.veil(self, Color(0.020, 0.029, 0.052, 0.73))
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	ArenaStyle.text(self, Rect2(115, 62, 1250, 72), "BEFORE THE BATTLE", 51, ArenaStyle.TEXT, true)
	ArenaStyle.text(self, Rect2(119, 137, 1100, 31), "Aegis Citadel  •  Phase 1 live match", 22, ArenaStyle.GOLD)
	var back := ArenaStyle.button("BACK TO TITLE")
	ArenaStyle.mount(self, back, Rect2(1537, 91, 264, 54))
	back.pressed.connect(_return_to_title)
	_make_modes()
	_make_commanders()
	_make_deck()
	var begin := ArenaStyle.button("ENTER BATTLE", true)
	ArenaStyle.mount(self, begin, Rect2(1337, 921, 464, 68))
	begin.pressed.connect(func() -> void: get_tree().change_scene_to_file(BATTLE))
	begin.grab_focus()

func _make_modes() -> void:
	var panel := ArenaStyle.panel(self, Rect2(116, 195, 540, 388), ArenaStyle.GOLD)
	ArenaStyle.text(panel, Rect2(24, 20, 480, 44), "BATTLE MODE", 26, ArenaStyle.GOLD, true)
	var live := ArenaStyle.button("◆  PHASE 1 LIVE MATCH", true)
	live.toggle_mode = true
	live.button_pressed = true
	live.toggled.connect(func(_pressed: bool) -> void: live.set_pressed_no_signal(true))
	ArenaStyle.mount(panel, live, Rect2(25, 86, 490, 53))
	_locked_mode(panel, 154, "AI VS AI  ·  PLANNED")
	_locked_mode(panel, 218, "HUMAN VS AI  ·  PLANNED")
	ArenaStyle.text(panel, Rect2(28, 292, 480, 70), "Inspect the arena, timer, and tower HP.\nUse F3 to test damage and victory.", 20, ArenaStyle.MUTED)

func _locked_mode(panel: Panel, y: int, caption: String) -> void:
	var item := ArenaStyle.button(caption)
	item.disabled = true
	ArenaStyle.mount(panel, item, Rect2(25, y, 490, 50))

func _make_commanders() -> void:
	var panel := ArenaStyle.panel(self, Rect2(686, 195, 1114, 388))
	ArenaStyle.text(panel, Rect2(24, 20, 1060, 45), "COMMANDERS & MATCH RULES", 26, ArenaStyle.GOLD, true)
	_commander(panel, 26, "BLUE COMMANDER", "Minimax + Alpha-Beta  ·  Phase 7", GameConstants.BLUE_COLOR, DeckArt.BLUE_PORTRAIT)
	_commander(panel, 564, "RED COMMANDER", "MCTS  ·  Phase 8", GameConstants.RED_COLOR, DeckArt.RED_PORTRAIT)
	ArenaStyle.text(panel, Rect2(27, 198, 1050, 34), "Shared systems   •   Fuzzy Logic (Phase 6)   •   A* Pathfinding (Phase 3)", 21, ArenaStyle.MUTED)
	ArenaStyle.text(panel, Rect2(27, 247, 1060, 35), "3:00 match   /   2 lanes   /   3 towers per side", 25, ArenaStyle.TEXT, true)
	ArenaStyle.text(panel, Rect2(27, 305, 1060, 49), "Planned energy   5 starting   /   +1 per second   /   10 maximum", 22, ArenaStyle.VIOLET)

func _commander(panel: Panel, x: int, name_text: String, strategy: String, accent: Color, image: Texture2D) -> void:
	var card := ArenaStyle.panel(panel, Rect2(x, 83, 524, 100), accent)
	ArenaStyle.art(card, Rect2(7, 7, 83, 86), image)
	ArenaStyle.text(card, Rect2(107, 12, 400, 32), name_text, 20, accent, true)
	ArenaStyle.text(card, Rect2(107, 49, 400, 31), strategy, 18, ArenaStyle.TEXT)

func _make_deck() -> void:
	var panel := ArenaStyle.panel(self, Rect2(116, 612, 1684, 283))
	ArenaStyle.text(panel, Rect2(24, 13, 560, 43), "PLANNED DECK", 26, ArenaStyle.GOLD, true)
	for index in DeckArt.NAMES.size():
		var card := CARD.instantiate() as BattleCardSlot
		ArenaStyle.mount(panel, card, Rect2(28 + index * 167, 65, 149, 188))
		card.build(index, DeckArt.CARDS[index])
	ArenaStyle.text(panel, Rect2(904, 81, 700, 124), "Fighter, Ranger and Tank are planned for Phase 2.\nMage and Arrow are preview cards.\nCard deployment is unavailable in this match.", 23, ArenaStyle.MUTED)

func _return_to_title() -> void:
	get_tree().change_scene_to_file(TITLE)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_return_to_title()
