class_name GameConstants
extends RefCounted
## Shared team identifiers and presentation colors; balance values live in resources.

enum Team { BLUE, RED }

const UNDECIDED: int = -2
const DRAW: int = -1
const BLUE_COLOR: Color = Color("58b7ff")
const RED_COLOR: Color = Color("ff7b85")

static func team_name(team_id: int) -> String:
	return "Blue" if team_id == Team.BLUE else "Red"

static func team_color(team_id: int) -> Color:
	return BLUE_COLOR if team_id == Team.BLUE else RED_COLOR

static func opponent(team_id: int) -> int:
	return Team.RED if team_id == Team.BLUE else Team.BLUE
