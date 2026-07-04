extends CharacterBody2D

## P1 (player_index = 1) reads keyboard actions, P2 (player_index = 2) reads
## gamepad actions. Both share identical "floppy bunny" physics: jumps are
## charged up and launch the whole body into a tumbling dive, and landing on
## a teammate's head bounces you into a huge co-op boost jump.

@export var player_index: int = 1
@export var body_color: Color = Color.WHITE

const SAMPLE_INTERVAL := 0.05

var is_recording: bool = false
var recording_time: float = 0.0
var recording_samples: Array = []
var _sample_accum: float = 0.0

var _visual_root: Node2D
var _torso: Polygon2D
var _head: Polygon2D
var _ear_l: Polygon2D
var _ear_r: Polygon2D
var _arm_l: Polygon2D
var _arm_r: Polygon2D
var _foot_l: Polygon2D
var _foot_r: Polygon2D
var _accent: Color

var _facing: float = 1.0
var _charging: bool = false
var _charge_t: float = 0.0
var _spin: float = 0.0
var _was_on_floor: bool = true
var _run_dust_t: float = 0.0
var _bounce_cooldown: float = 0.0
var _ear_vel_l: float = 0.0
var _ear_vel_r: float = 0.0

func _ready() -> void:
	add_to_group("players")
	_build_visual()

func _build_visual() -> void:
	_accent = Palette.GREEN if player_index == 2 else Palette.ORANGE

	_visual_root = Node2D.new()
	add_child(_visual_root)

	var w: float = Phys.PLAYER_SIZE.x
	var h: float = Phys.PLAYER_SIZE.y

	# Floppy ears, drawn behind the head, hinged at the top of the skull.
	_ear_l = _make_ear(Vector2(-w * 0.16, -h * 0.62), -0.15)
	_ear_r = _make_ear(Vector2(w * 0.16, -h * 0.62), 0.15)

	# Round squashy torso.
	_torso = Polygon2D.new()
	_torso.color = body_color
	_torso.polygon = _oval(Vector2(w * 0.95, h * 0.78), 14)
	_torso.position = Vector2(0, h * 0.05)
	_visual_root.add_child(_torso)

	# Belly accent patch.
	var belly := Polygon2D.new()
	belly.color = _accent
	belly.polygon = _oval(Vector2(w * 0.5, h * 0.4), 12)
	belly.position = Vector2(0, h * 0.16)
	_visual_root.add_child(belly)

	# Stubby arms.
	_arm_l = _make_limb(Vector2(-w * 0.42, -h * 0.05), body_color.darkened(0.1), Vector2(w * 0.16, h * 0.34))
	_arm_r = _make_limb(Vector2(w * 0.42, -h * 0.05), body_color.darkened(0.1), Vector2(w * 0.16, h * 0.34))

	# Little feet.
	_foot_l = _make_limb(Vector2(-w * 0.22, h * 0.42), Palette.WOOD_DARK.lerp(body_color, 0.3), Vector2(w * 0.22, h * 0.2))
	_foot_r = _make_limb(Vector2(w * 0.22, h * 0.42), Palette.WOOD_DARK.lerp(body_color, 0.3), Vector2(w * 0.22, h * 0.2))

	# Round head.
	_head = Polygon2D.new()
	_head.color = body_color
	_head.polygon = _oval(Vector2(w * 0.62, h * 0.5), 14)
	_head.position = Vector2(0, -h * 0.42)
	_visual_root.add_child(_head)

	# Cheerful eyes.
	for side in [-1.0, 1.0]:
		var eye := Polygon2D.new()
		eye.color = Palette.NEAR_BLACK
		eye.polygon = _oval(Vector2(6, 8), 8)
		eye.position = Vector2(side * w * 0.16, -h * 0.44)
		_visual_root.add_child(eye)

	# Rosy nose accent.
	var nose := Polygon2D.new()
	nose.color = _accent
	nose.polygon = _oval(Vector2(10, 8), 8)
	nose.position = Vector2(0, -h * 0.32)
	_visual_root.add_child(nose)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Phys.PLAYER_SIZE
	shape.shape = rect
	add_child(shape)

func _make_ear(offset: Vector2, lean: float) -> Polygon2D:
	var ear := Polygon2D.new()
	ear.color = body_color.darkened(0.05)
	var h: float = Phys.PLAYER_SIZE.y
	ear.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(6, 0),
		Vector2(8, -h * 0.55), Vector2(-8, -h * 0.55),
	])
	ear.position = offset
	ear.rotation = lean
	_visual_root.add_child(ear)
	return ear

func _make_limb(offset: Vector2, color: Color, size: Vector2) -> Polygon2D:
	var limb := Polygon2D.new()
	limb.color = color
	limb.polygon = _oval(size, 8)
	limb.position = offset
	_visual_root.add_child(limb)
	return limb

func _oval(size: Vector2, steps: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps):
		var a: float = TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * size.x / 2.0, sin(a) * size.y / 2.0))
	return pts

func _physics_process(delta: float) -> void:
	var left_action := "p1_left" if player_index == 1 else "p2_left"
	var right_action := "p1_right" if player_index == 1 else "p2_right"
	var jump_action := "p1_jump" if player_index == 1 else "p2_jump"

	var dir := 0.0
	if Input.is_action_pressed(left_action):
		dir -= 1.0
	if Input.is_action_pressed(right_action):
		dir += 1.0
	if dir != 0.0:
		_facing = sign(dir)

	var on_floor_before := is_on_floor()

	if on_floor_before:
		velocity.x = dir * Phys.MOVE_SPEED
		if Input.is_action_pressed(jump_action):
			_charging = true
			_charge_t = min(_charge_t + delta, Phys.JUMP_CHARGE_MAX)
		elif _charging:
			_launch(dir)
			_charging = false
	else:
		velocity.x = lerp(velocity.x, dir * Phys.MOVE_SPEED, 0.03)
		_charging = false
		_charge_t = 0.0

	if not on_floor_before:
		velocity.y += Phys.GRAVITY * delta
		velocity.y = min(velocity.y, Phys.MAX_FALL_SPEED)

	var was_falling := velocity.y > 60.0 and not on_floor_before

	move_and_slide()

	_check_collisions(was_falling)
	_update_visuals(delta, dir, on_floor_before)

	if _bounce_cooldown > 0.0:
		_bounce_cooldown -= delta

	if is_recording:
		recording_time += delta
		_sample_accum += delta
		if _sample_accum >= SAMPLE_INTERVAL:
			_sample_accum = 0.0
			recording_samples.append({"t": recording_time, "x": position.x, "y": position.y})

func _launch(dir: float) -> void:
	var frac: float = _charge_t / Phys.JUMP_CHARGE_MAX
	var launch_dir: float = dir if dir != 0.0 else _facing * 0.4
	velocity.y = -lerp(Phys.JUMP_POWER_MIN, Phys.JUMP_POWER_MAX, frac)
	velocity.x = launch_dir * lerp(Phys.JUMP_FORWARD_MIN, Phys.JUMP_FORWARD_MAX, frac)
	_spin = -sign(launch_dir if launch_dir != 0.0 else 1.0) * frac * 6.0
	_charge_t = 0.0

func _check_collisions(was_falling: bool) -> void:
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider == null:
			continue
		if collider.has_method("try_hit") and velocity.y < -10.0 and col.get_normal().y > 0.5:
			collider.try_hit(self)
		elif was_falling and collider.is_in_group("players") and col.get_normal().y < -0.5 and _bounce_cooldown <= 0.0:
			velocity.y = Phys.HEAD_BOUNCE_VELOCITY
			_bounce_cooldown = 0.3
			_spin = -sign(velocity.x if velocity.x != 0.0 else _facing) * 5.0
			if collider.has_method("get_bounced_on"):
				collider.get_bounced_on()

func get_bounced_on() -> void:
	velocity.y = max(velocity.y, Phys.BOUNCED_ON_PUSH)
	_bounce_cooldown = 0.3
	_visual_root.scale = Vector2(1.3, 0.7)

func _update_visuals(delta: float, dir: float, was_on_floor_before: bool) -> void:
	var on_floor := is_on_floor()

	if on_floor and not was_on_floor_before:
		_spawn_landing_dust()
		_visual_root.scale = Vector2(1.35, 0.65)
		_spin = 0.0
		_visual_root.rotation = wrapf(_visual_root.rotation, -PI, PI)
		_visual_root.rotation = lerp_angle(_visual_root.rotation, 0.0, 0.0)
	_was_on_floor = on_floor

	_visual_root.scale = _visual_root.scale.lerp(Vector2(1, 1) * sign(_facing if _facing != 0.0 else 1.0), 0.0)
	var target_scale_x: float = (1.0 if _facing >= 0.0 else -1.0)
	if not on_floor:
		var s := _visual_root.scale
		s.x = lerp(abs(s.x), 1.0, 0.15) * target_scale_x
		s.y = lerp(s.y, 1.0, 0.15)
		_visual_root.scale = s
		_visual_root.rotation += _spin * delta
	else:
		var s := _visual_root.scale
		s.x = lerp(abs(s.x), 1.0, 0.25) * target_scale_x
		s.y = lerp(s.y, 1.0, 0.25)
		_visual_root.scale = s
		_visual_root.rotation = lerp_angle(_visual_root.rotation, 0.0, 0.3)

	if _charging:
		var f: float = _charge_t / Phys.JUMP_CHARGE_MAX
		var s := _visual_root.scale
		s.y = 1.0 - f * 0.35
		s.x = target_scale_x * (1.0 + f * 0.25)
		_visual_root.scale = s

	if on_floor and dir != 0.0 and not _charging:
		var walk: float = sin(Time.get_ticks_msec() / 60.0) * 0.35
		_foot_l.position.y = Phys.PLAYER_SIZE.y * 0.42 + walk * 6.0
		_foot_r.position.y = Phys.PLAYER_SIZE.y * 0.42 - walk * 6.0
		_run_dust_t -= delta
		if _run_dust_t <= 0.0:
			_run_dust_t = 0.1
			_spawn_run_dust()
	else:
		_foot_l.position.y = Phys.PLAYER_SIZE.y * 0.42
		_foot_r.position.y = Phys.PLAYER_SIZE.y * 0.42

	# Floppy ear lag: a light spring so ears trail behind body motion.
	var target_l: float = -0.15 - velocity.x * 0.0009 - velocity.y * 0.0004
	var target_r: float = 0.15 - velocity.x * 0.0009 - velocity.y * 0.0004
	_ear_vel_l = lerp(_ear_vel_l, (target_l - _ear_l.rotation) * 14.0, 0.3)
	_ear_vel_r = lerp(_ear_vel_r, (target_r - _ear_r.rotation) * 14.0, 0.3)
	_ear_l.rotation += _ear_vel_l * delta
	_ear_r.rotation += _ear_vel_r * delta

func _spawn_run_dust() -> void:
	var p := CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, Phys.PLAYER_SIZE.y / 2.0)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 3
	p.lifetime = 0.35
	p.direction = Vector2(0, -1)
	p.spread = 40.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 300)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 2.5
	p.color = Palette.DIRT
	var timer := get_tree().create_timer(0.4)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _spawn_landing_dust() -> void:
	var p := CPUParticles2D.new()
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, Phys.PLAYER_SIZE.y / 2.0)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 12
	p.lifetime = 0.4
	p.direction = Vector2(0, -1)
	p.spread = 90.0
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 500)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Palette.DIRT
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

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
	_spin = 0.0
	_visual_root.rotation = 0.0
	_visual_root.scale = Vector2(1, 1)
