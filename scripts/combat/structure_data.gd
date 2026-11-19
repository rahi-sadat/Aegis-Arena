class_name StructureData
extends Resource
## Shared tower kind, name, and HP. Numeric attacks run in BattleRules.

enum Kind { GUARD, CORE }

@export var structure_type: Kind = Kind.GUARD
@export var display_name: String = "Guard Tower"
@export_range(1.0, 10000.0, 1.0) var max_hp: float = 500.0
