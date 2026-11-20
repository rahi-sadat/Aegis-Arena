extends CanvasLayer
## Actual ResourceLoader progress. No artificial loading percentages.

@export var destination: String = "res://scenes/ui/screens/TitleScreen.tscn"
var progress: float = 0
var _elapsed: float = 0
var _bar: ProgressBar
var _status: Label
var _percent: Label
var _failed: bool = false
var _opening: bool = false
var _requested: bool = false
var _startup_frames: int = 2
var _script_guard: Script
const SCRIPTS := {
	"res://scenes/ui/screens/TitleScreen.tscn": "res://scripts/ui/title_screen.gd",
	"res://scenes/ui/screens/PreBattleScreen.tscn": "res://scripts/ui/pre_battle_screen.gd",
	"res://scenes/main/Main.tscn": "res://scripts/core/main.gd",
}

func _ready() -> void:
	var page := Control.new()
	add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ArenaStyle.veil(page, Color("#0a1018"))
	ArenaStyle.icon(page, Rect2(892, 264, 136, 144), ArenaIcon.Kind.SHIELD, ArenaStyle.GOLD)
	ArenaStyle.text(page, Rect2(480, 450, 960, 64), "AEGIS  /  ARENA", 46, ArenaStyle.TEXT, true, HORIZONTAL_ALIGNMENT_CENTER)
	_status = ArenaStyle.text(page, Rect2(480, 540, 960, 32), "Preparing your arena", 20, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	_bar = ArenaStyle.bar(ArenaStyle.GOLD)
	ArenaStyle.mount(page, _bar, Rect2(600, 612, 720, 4))
	_percent = ArenaStyle.text(page, Rect2(600, 637, 720, 26), "", 14, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	ArenaStyle.text(page, Rect2(480, 930, 960, 30), "TWO LANES.  FIVE CARDS.  ONE CORE.", 13, ArenaStyle.MUTED, false, HORIZONTAL_ALIGNMENT_CENTER)
	var retry := ArenaStyle.button("RETRY")
	ArenaStyle.mount(page, retry, Rect2(840, 708, 240, 48))
	retry.hide()
	retry.pressed.connect(func() -> void: retry.hide(); _request())
	set_meta("retry", retry)

func _request() -> void:
	_failed = false
	_requested = true
	# Initialize script classes on the UI thread; scene/art loading stays threaded.
	if SCRIPTS.has(destination):
		_script_guard = load(SCRIPTS[destination])
	var error: Error = ResourceLoader.load_threaded_request(destination, "PackedScene")
	if error != OK:
		_failure(error_string(error))

func _process(delta: float) -> void:
	if _failed or _opening:
		return
	_elapsed += delta
	if not _requested:
		if _startup_frames > 0:
			_startup_frames -= 1
			return
		_request()
		return
	var values: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(destination, values)
	progress = float(values[0]) if not values.is_empty() else 0.0
	_bar.value = progress
	_percent.text = "%d%%  /  %s" % [roundi(progress * 100), "BATTLEFIELD" if destination.contains("Main.tscn") else "MENU"]
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_status.text = "Ready"
		# Allow the loading view to render; this is a transition, not a fake delay.
		if _elapsed < 0.22 and DisplayServer.get_name() != "headless":
			return
		_opening = true
		var packed: PackedScene = ResourceLoader.load_threaded_get(destination)
		get_tree().scene_changed.connect(queue_free, CONNECT_ONE_SHOT)
		var error: Error = get_tree().change_scene_to_packed(packed)
		if error != OK:
			_opening = false
			_failure(error_string(error))
	elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_failure("Could not load the scene")

func _failure(message: String) -> void:
	_failed = true
	_status.text = message + ". Please retry."
	get_meta("retry").show()
