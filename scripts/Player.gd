extends CharacterBody2D

## P1 (player_index = 1) reads keyboard actions, P2 (player_index = 2) reads
## gamepad actions. Both share identical physics. Visuals are a small
## stylised sci-fi trooper built from polygons, animated procedurally
## (leg swing while running, squash/stretch on jump/land, dust particles).

@export var player_index: int = 1
@export var body_color: Color = Color.WHITE

const SAMPLE_INTERVAL := 0.05

var is_recording: bool = false
var recording_time: float = 0.0
var recording_samples: Array = []
var _sample_accum: float = 0.0

var _visual_root: Node2D
var _leg_l: Polygon2D
var _leg_r: Polygon2D
var _arm_l: Polygon2D
var _arm_r: Polygon2D
var _visor: Polygon2D
var _torso: Polygon2D
var _anim_t: float = 0.0
var _was_on_floor: bool = true
var _run_dust_t: float = 0.0
var _accent: Color

func _ready() -> void:
        add_to_group("players")
        _build_visual()

func _build_visual() -> void:
        _accent = Palette.GREEN if player_index == 2 else Palette.ORANGE

        _visual_root = Node2D.new()
        add_child(_visual_root)

        var w: float = Phys.PLAYER_SIZE.x
        var h: float = Phys.PLAYER_SIZE.y

        # Legs (behind torso), pivoted at the hip so they can swing.
        _leg_l = _make_leg(Vector2(-w * 0.18, h * 0.06))
        _leg_r = _make_leg(Vector2(w * 0.18, h * 0.06))

        # Torso: rounded capsule silhouette.
        _torso = Polygon2D.new()
        _torso.color = body_color
        _torso.polygon = _rounded_rect(Vector2(w * 0.82, h * 0.62), 8.0)
        _torso.position = Vector2(0, -h * 0.06)
        _visual_root.add_child(_torso)

        # Chest accent stripe.
        var stripe := Polygon2D.new()
        stripe.color = _accent
        stripe.polygon = PackedVector2Array([
                Vector2(-w * 0.12, -h * 0.28), Vector2(w * 0.12, -h * 0.28),
                Vector2(w * 0.08, h * 0.2), Vector2(-w * 0.08, h * 0.2),
        ])
        stripe.position = Vector2(0, -h * 0.06)
        _visual_root.add_child(stripe)

        # Arms.
        _arm_l = _make_arm(Vector2(-w * 0.46, -h * 0.12))
        _arm_r = _make_arm(Vector2(w * 0.46, -h * 0.12))

        # Head.
        var head := Polygon2D.new()
        head.color = Palette.LIGHT.lerp(body_color, 0.35)
        head.polygon = _rounded_rect(Vector2(w * 0.6, h * 0.32), 8.0)
        head.position = Vector2(0, -h * 0.52)
        _visual_root.add_child(head)

        # Visor: glowing accent slit, pulses gently.
        _visor = Polygon2D.new()
        _visor.color = _accent
        _visor.polygon = PackedVector2Array([
                Vector2(-w * 0.24, -2), Vector2(w * 0.24, -2),
                Vector2(w * 0.2, 4), Vector2(-w * 0.2, 4),
        ])
        _visor.position = Vector2(0, -h * 0.54)
        _visual_root.add_child(_visor)

        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Phys.PLAYER_SIZE
        shape.shape = rect
        add_child(shape)

func _make_leg(offset: Vector2) -> Polygon2D:
        var leg := Polygon2D.new()
        leg.color = Palette.DARK.lerp(body_color, 0.2)
        var w: float = Phys.PLAYER_SIZE.x
        var h: float = Phys.PLAYER_SIZE.y
        leg.polygon = PackedVector2Array([
                Vector2(-w * 0.09, 0), Vector2(w * 0.09, 0),
                Vector2(w * 0.09, h * 0.4), Vector2(-w * 0.09, h * 0.4),
        ])
        leg.position = offset
        _visual_root.add_child(leg)
        return leg

func _make_arm(offset: Vector2) -> Polygon2D:
        var arm := Polygon2D.new()
        arm.color = body_color.darkened(0.15)
        var w: float = Phys.PLAYER_SIZE.x
        var h: float = Phys.PLAYER_SIZE.y
        arm.polygon = PackedVector2Array([
                Vector2(-w * 0.08, -h * 0.05), Vector2(w * 0.08, -h * 0.05),
                Vector2(w * 0.08, h * 0.32), Vector2(-w * 0.08, h * 0.32),
        ])
        arm.position = offset
        _visual_root.add_child(arm)
        return arm

func _rounded_rect(size: Vector2, corner: float) -> PackedVector2Array:
        var hx: float = size.x / 2.0
        var hy: float = size.y / 2.0
        var pts := PackedVector2Array()
        var steps := 4
        var corners := [
                Vector2(hx - corner, -hy), Vector2(hx, -hy + corner),
                Vector2(hx, hy - corner), Vector2(hx - corner, hy),
                Vector2(-hx + corner, hy), Vector2(-hx, hy - corner),
                Vector2(-hx, -hy + corner), Vector2(-hx + corner, -hy),
        ]
        for p in corners:
                pts.append(p)
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

        velocity.x = dir * Phys.MOVE_SPEED

        var was_moving_up := velocity.y < -10.0

        if not is_on_floor():
                velocity.y += Phys.GRAVITY * delta
                velocity.y = min(velocity.y, Phys.MAX_FALL_SPEED)
        elif Input.is_action_just_pressed(jump_action):
                velocity.y = Phys.JUMP_VELOCITY
                was_moving_up = true

        move_and_slide()

        if was_moving_up:
                _check_head_bump()

        _update_visuals(delta, dir)
        _update_floor_state()

        if is_recording:
                recording_time += delta
                _sample_accum += delta
                if _sample_accum >= SAMPLE_INTERVAL:
                        _sample_accum = 0.0
                        recording_samples.append({"t": recording_time, "x": position.x, "y": position.y})

func _check_head_bump() -> void:
        for i in range(get_slide_collision_count()):
                var col := get_slide_collision(i)
                var collider := col.get_collider()
                if collider and collider.has_method("try_hit") and col.get_normal().y > 0.5:
                        collider.try_hit(self)

func _update_floor_state() -> void:
        var on_floor := is_on_floor()
        if on_floor and not _was_on_floor:
                _spawn_landing_dust()
                _visual_root.scale = Vector2(1.25, 0.75)
        _was_on_floor = on_floor

func _update_visuals(delta: float, dir: float) -> void:
        _visual_root.scale = _visual_root.scale.lerp(Vector2.ONE, min(delta * 12.0, 1.0))

        if dir != 0.0:
                _visual_root.scale.x = sign(dir) * abs(_visual_root.scale.x) if abs(_visual_root.scale.x) > 0.01 else sign(dir)
                if abs(_visual_root.scale.x) < 0.5:
                        _visual_root.scale.x = sign(dir)

        if not is_on_floor():
                # Stretch a bit while airborne for a snappy platformer feel.
                var stretch: float = clamp(-velocity.y / 900.0, -0.3, 0.3)
                _visual_root.scale.y = lerp(_visual_root.scale.y, 1.0 + stretch * 0.4, 0.3)
                _leg_l.rotation = lerp(_leg_l.rotation, -0.35, 0.2)
                _leg_r.rotation = lerp(_leg_r.rotation, 0.35, 0.2)
                _arm_l.rotation = lerp(_arm_l.rotation, 0.5, 0.2)
                _arm_r.rotation = lerp(_arm_r.rotation, -0.5, 0.2)
        elif dir != 0.0:
                _anim_t += delta * 10.0
                var swing := sin(_anim_t) * 0.6
                _leg_l.rotation = swing
                _leg_r.rotation = -swing
                _arm_l.rotation = -swing * 0.8
                _arm_r.rotation = swing * 0.8
                _run_dust_t -= delta
                if _run_dust_t <= 0.0:
                        _run_dust_t = 0.09
                        _spawn_run_dust()
        else:
                _anim_t = 0.0
                _leg_l.rotation = lerp(_leg_l.rotation, 0.0, 0.3)
                _leg_r.rotation = lerp(_leg_r.rotation, 0.0, 0.3)
                _arm_l.rotation = lerp(_arm_l.rotation, 0.0, 0.3)
                _arm_r.rotation = lerp(_arm_r.rotation, 0.0, 0.3)

        # Subtle visor pulse.
        var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 260.0)
        _visor.color = _accent.lightened(pulse * 0.2)

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
        p.color = Palette.MID
        var timer := get_tree().create_timer(0.4)
        timer.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func _spawn_landing_dust() -> void:
        var p := CPUParticles2D.new()
        get_parent().add_child(p)
        p.global_position = global_position + Vector2(0, Phys.PLAYER_SIZE.y / 2.0)
        p.emitting = true
        p.one_shot = true
        p.explosiveness = 1.0
        p.amount = 10
        p.lifetime = 0.4
        p.direction = Vector2(0, -1)
        p.spread = 80.0
        p.initial_velocity_min = 40.0
        p.initial_velocity_max = 120.0
        p.gravity = Vector2(0, 500)
        p.scale_amount_min = 1.5
        p.scale_amount_max = 3.0
        p.color = Palette.LIGHT
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
