class_name UISettings
extends RefCounted
## Presentation preferences shared by the title and battle during this session.

static var minimap_visible: bool = true
static var reduce_motion: bool = false

static func set_master_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, value)))

static func master_volume() -> float:
	return 0.0 if AudioServer.is_bus_mute(0) else db_to_linear(AudioServer.get_bus_volume_db(0))
