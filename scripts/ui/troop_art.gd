class_name TroopArt
extends RefCounted
## Presentation-only atlas coordinates. Feet are measured from each frame's alpha.

const SHEETS := [
	preload("res://assets/units/fighter_sheet.png"),
	preload("res://assets/units/ranger_sheet.png"),
	preload("res://assets/units/tank_sheet.png"),
]
const TEAM_SHADER := preload("res://assets/units/team_palette.gdshader")
const BODY_PIXELS := [262.0, 278.0, 260.0]
const WORLD_HEIGHT := [76.0, 74.0, 96.0]
const FEET := [
	[290, 278, 287, 286, 282, 271, 282, 270, 278, 278, 277, 276, 285, 285, 283, 284],
	[300, 297, 297, 282, 296, 292, 293, 294, 298, 298, 298, 298, 297, 297, 297, 297],
	[288, 282, 288, 282, 284, 276, 284, 269, 286, 286, 286, 286, 289, 289, 291, 290],
]

static var _portraits: Array = [null, null, null]
static var _materials: Array = [null, null]

static func frame_rect(card: int, row: int, column: int) -> Rect2:
	var extent: Vector2 = SHEETS[card].get_size()
	var a := Vector2(roundf(extent.x * column / 4.0), roundf(extent.y * row / 4.0))
	var b := Vector2(roundf(extent.x * (column + 1) / 4.0), roundf(extent.y * (row + 1) / 4.0))
	return Rect2(a, b - a)

static func portrait(card: int) -> Texture2D:
	if _portraits[card] == null:
		var frame: Rect2 = frame_rect(card, 1, 0)
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEETS[card]
		atlas.region = Rect2(frame.position + frame.size * Vector2(0.11, 0.025), frame.size * Vector2(0.78, 0.69))
		_portraits[card] = atlas
	return _portraits[card]

static func team_material(team: int) -> ShaderMaterial:
	if _materials[team] == null:
		var material := ShaderMaterial.new()
		material.shader = TEAM_SHADER
		material.set_shader_parameter("enemy_team", team == 1)
		_materials[team] = material
	return _materials[team]
