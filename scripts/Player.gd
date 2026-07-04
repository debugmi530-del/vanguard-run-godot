extends CharacterBody2D

## P1 (player_index = 1) reads keyboard actions, P2 (player_index = 2) reads
## gamepad actions. Both share identical physics.

@export var player_index: int = 1
@export var body_color: Color = Color.WHITE

const SAMPLE_INTERVAL := 0.05

var is_recording: bool = false
var recording_time: float = 0.0
var recording_samples: Array = []
var _sample_accum: float = 0.0

func _ready() -> void:
	add_to_group("players")
	_build_visual()

func _build_visual() -> void:
	var body_rect := ColorRect.new()
	body_rect.size = Phys.PLAYER_SIZE
	body_rect.position = -Phys.PLAYER_SIZE / 2.0
	body_rect.color = body_color
	add_child(body_rect)

	var visor := ColorRect.new()
	visor.size = Vector2(Phys.PLAYER_SIZE.x * 0.6, 8)
	visor.position = Vector2(-visor.size.x / 2.0, -Phys.PLAYER_SIZE.y / 2.0 + 10)
	visor.color = Palette.GREEN if player_index == 2 else Palette.ORANGE
	add_child(visor)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Phys.PLAYER_SIZE
	shape.shape = rect
	add_child(shape)

func _physics_process(delta: float) -> void:
	var left_action := "p1_left" if player_index == 1 else "p2_left"
	var right_action := "p1_right" if player_index == 1 else "p2_right"
	var jump_action := "p1_jump" if player_index == 1 else "p2_jump"

	var dir := 0.0
	if Input.is_action_pressed(left_action):
		dir -= 1.0
	if Input.is_action_pressed(right_action):
		dir += 1.0

	velocity.x = dir * Phys.MOVE_SPEED

	if not is_on_floor():
		velocity.y += Phys.GRAVITY * delta
		velocity.y = min(velocity.y, Phys.MAX_FALL_SPEED)
	elif Input.is_action_just_pressed(jump_action):
		velocity.y = Phys.JUMP_VELOCITY

	move_and_slide()

	if is_recording:
		recording_time += delta
		_sample_accum += delta
		if _sample_accum >= SAMPLE_INTERVAL:
			_sample_accum = 0.0
			recording_samples.append({"t": recording_time, "x": position.x, "y": position.y})

func start_recording() -> void:
	is_recording = true
	recording_time = 0.0
	_sample_accum = 0.0
	recording_samples = []

func stop_recording() -> Dictionary:
	is_recording = false
	return {"samples": recording_samples, "duration": recording_time}

func respawn(at: Vector2) -> void:
	position = at
	velocity = Vector2.ZERO
