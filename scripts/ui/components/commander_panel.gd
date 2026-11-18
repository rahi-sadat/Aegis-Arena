class_name CommanderPanel
extends Panel

@export var portrait: Texture2D

var _health: ProgressBar
var _score: Label
var _core: Label
## Shows the commander's selected search algorithm (or the human player).
var logic_label: Label

func configure(team_id: int, artwork: Texture2D, mirrored: bool) -> void:
	var accent := GameConstants.team_color(team_id)
	ArenaStyle.decorate(self, accent)
	var portrait_x := 343.0 if mirrored else 12.0
	var copy_x := 27.0 if mirrored else 127.0
	var alignment := HORIZONTAL_ALIGNMENT_RIGHT if mirrored else HORIZONTAL_ALIGNMENT_LEFT
	var surround := ArenaStyle.panel(self, Rect2(portrait_x, 10, 99, 102), accent)
	ArenaStyle.art(surround, Rect2(4, 4, 91, 94), artwork if artwork != null else portrait)
	ArenaStyle.icon(self, Rect2(308 if mirrored else copy_x, 18, 17, 17), ArenaIcon.Kind.SHIELD, accent)
	ArenaStyle.text(self, Rect2(copy_x if mirrored else copy_x + 25, 12, 269, 27), GameConstants.team_name(team_id).to_upper() + " COMMANDER", 19, accent, true, alignment)
	_core = ArenaStyle.text(self, Rect2(copy_x, 41, 298, 26), "", 21, ArenaStyle.TEXT, false, alignment)
	_health = ArenaStyle.bar(accent)
	_health.fill_mode = ProgressBar.FILL_END_TO_BEGIN if mirrored else ProgressBar.FILL_BEGIN_TO_END
	ArenaStyle.mount(self, _health, Rect2(copy_x, 75, 298, 8))
	_score = ArenaStyle.text(self, Rect2(copy_x, 87, 298, 23), "", 16, ArenaStyle.MUTED, false, alignment)
	var badge := ArenaStyle.panel(self, Rect2(0, size.y + 6, size.x, 36), accent)
	badge.name = &"LogicBadge"
	ArenaStyle.icon(badge, Rect2(size.x - 34 if mirrored else 14, 9, 18, 18), ArenaIcon.Kind.CRYSTAL, accent)
	logic_label = ArenaStyle.text(badge, Rect2(14 if mirrored else 42, 0, size.x - 56, 36), "", 16, ArenaStyle.TEXT, true, alignment)
	logic_label.text = ("YOU  ·  " if MatchConfig.is_human(team_id) else "AI  ·  ") + MatchConfig.describe(team_id)

func update_status(core: ArenaStructure, fraction: float, immediate: bool) -> void:
	_core.text = "CORE   %d / %d HP" % [ceili(core.current_hp), core.max_hp]
	_score.text = "%.1f%% total structure HP" % (fraction * 100.0)
	ArenaStyle.fill_bar(_health, core.current_hp / core.max_hp, immediate)
