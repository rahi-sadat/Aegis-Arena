class_name StructureData
extends Resource
## Shared structure definition. Combat statistics will be added in Phase 2.

enum Kind { GUARD, CORE }

@export var structure_type: Kind = Kind.GUARD
@export var display_name: String = "Guard Tower"
@export_range(1.0, 10000.0, 1.0) var max_hp: float = 500.0
