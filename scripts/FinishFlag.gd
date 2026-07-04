extends Area2D

## Finish gate for a run. Requires all players to be inside simultaneously
## (co-op requirement) before the run counts as completed.

var players_inside: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)

func _on_enter(body: Node) -> void:
	if body.is_in_group("players"):
		players_inside[body.get_instance_id()] = true

func _on_exit(body: Node) -> void:
	if body.is_in_group("players"):
		players_inside.erase(body.get_instance_id())

func both_present(count: int) -> bool:
	return players_inside.size() >= count
