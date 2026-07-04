extends Area2D

## Finish gate for a run. Requires all players to be inside simultaneously
## (co-op requirement) before the run counts as completed. Pulses to draw
## the eye once players are near.

var players_inside: Dictionary = {}
var _visual: ColorRect

func _ready() -> void:
        body_entered.connect(_on_enter)
        body_exited.connect(_on_exit)
        for c in get_children():
                if c is ColorRect:
                        _visual = c

func _process(_delta: float) -> void:
        if _visual:
                var pulse: float = 0.7 + 0.3 * sin(Time.get_ticks_msec() / 200.0)
                _visual.color = Palette.GREEN.lightened(pulse * 0.15 if players_inside.size() == 0 else 0.4)

func _on_enter(body: Node) -> void:
        if body.is_in_group("players"):
                players_inside[body.get_instance_id()] = true

func _on_exit(body: Node) -> void:
        if body.is_in_group("players"):
                players_inside.erase(body.get_instance_id())

func both_present(count: int) -> bool:
        return players_inside.size() >= count
