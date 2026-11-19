class_name CommanderPanel
extends Panel

@export var portrait: Texture2D
var _health: ProgressBar
var _score: Label
var _core: Label
var logic_label: Label

func configure(team_id: int, artwork: Texture2D, mirrored: bool) -> void:
	var accent: Color = GameConstants.team_color(team_id)
	var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	ArenaStyle.decorate(self, accent)
	ArenaStyle.icon(self, Rect2(18 if mirrored else size.x - 37, 13, 19, 19), ArenaIcon.Kind.SHIELD, accent)
	ArenaStyle.text(self, Rect2(18, 9, size.x - 36, 21), GameConstants.team_name(team_id).to_upper() + " COMMANDER", 13, accent, true, alignment)
	_core = ArenaStyle.text(self, Rect2(18, 31, size.x - 36, 25), "", 21, ArenaStyle.TEXT, true, alignment)
	_health = ArenaStyle.bar(accent)
	_health.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirrored else ProgressBar.FILL_BEGIN_TO_END
	ArenaStyle.mount(self, _health, Rect2(18, 64, size.x - 36, 4))
	_score = ArenaStyle.text(self, Rect2(18, 73, size.x - 36, 16), "", 11, ArenaStyle.MUTED, false, alignment)
	var badge := ArenaStyle.panel(self, Rect2(0, size.y + 5, size.x, 25), Color("#697a8b"))
	badge.name = &"LogicBadge"
	logic_label = ArenaStyle.text(badge, Rect2(12, 0, size.x - 24, 25), "", 12, ArenaStyle.MUTED, false, alignment)
	update_logic(team_id)

func update_logic(team_id: int) -> void:
	logic_label.text = ("YOU  /  " if MatchConfig.is_human(team_id) else "AI  /  ") + MatchConfig.describe(team_id)

func update_status(core: ArenaStructure, fraction: float, immediate: bool) -> void:
	_core.text = "%d / %d  CORE HP" % [ceili(core.current_hp), core.max_hp]
	_score.text = "STRUCTURES   %.1f%%" % (fraction * 100.0)
	ArenaStyle.fill_bar(_health, core.current_hp / core.max_hp, immediate)
