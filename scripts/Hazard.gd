extends Area2D

## A non-solid spike trap. Fires player_hit when a player passes through it.

signal player_hit

func _ready() -> void:
	add_to_group("hazards")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("players"):
		player_hit.emit()
