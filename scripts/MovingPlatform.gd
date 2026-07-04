extends AnimatableBody2D

## Kinematic moving platform that carries players standing on it.
## sync_to_physics stays true so CharacterBody2D riders get carried.

@export var travel: Vector2 = Vector2(160, 0)
@export var speed: float = 60.0
@export var phase_offset: float = 0.0

var _start_pos: Vector2
var _t: float = 0.0

func _ready() -> void:
	_start_pos = position
	_t = phase_offset

func _physics_process(delta: float) -> void:
	_t += delta * speed / max(travel.length(), 1.0)
	var f := (sin(_t) + 1.0) / 2.0
	position = _start_pos + travel * f
