extends Area2D

## A non-solid spike trap. Fires player_hit when a player passes through it.
## Glows with a pulsing red warning light.

signal player_hit

var _poly: Polygon2D

func _ready() -> void:
        add_to_group("hazards")
        body_entered.connect(_on_body_entered)
        for c in get_children():
                if c is Polygon2D:
                        _poly = c

func _process(_delta: float) -> void:
        if _poly:
                var pulse: float = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0)
                _poly.color = Palette.RED.lightened(pulse * 0.2)

func _on_body_entered(body: Node) -> void:
        if body.is_in_group("players"):
                player_hit.emit()
