class_name GameBalance
extends Resource
## Inspector-editable settings used by the current match and debug damage controls.

@export_range(1.0, 3600.0, 1.0) var match_duration_seconds: float = 180.0
@export_range(1.0, 1000.0, 1.0) var debug_damage_amount: float = 100.0
