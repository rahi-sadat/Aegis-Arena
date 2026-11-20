class_name ArenaTransition
extends RefCounted
## A frontend loading overlay; the destination scene changes only when ready.

static func go(from: Node, destination: String) -> void:
	var previous: Node = from.get_tree().root.get_node_or_null("SceneLoading")
	if previous != null:
		if not previous.get("_opening"):
			return
		# A destination can receive input before the old overlay's deferred free.
		previous.name = "FinishedLoading"
		previous.queue_free()
	var screen := preload("res://scenes/ui/screens/LoadingScreen.tscn").instantiate()
	screen.name = "SceneLoading"
	screen.destination = destination
	from.get_tree().root.add_child(screen)
