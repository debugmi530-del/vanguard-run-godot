extends StaticBody2D

## Mario-style "?" block: solid collision (players can stand on it or bonk
## it), bump it from below (moving upward) to spend the shared team bank on
## exactly one upgrade. Flashes and bounces to give clear purchase feedback.

@export var upgrade_key: String = "reward"
# reward | reward_mult | clone | clone_reward | clone_reward_mult | level_upgrade

signal purchase_attempted(success: bool)

var _cooldown: float = 0.0
var _visual: ColorRect
var _mark: Label
var _base_visual_pos: Vector2
var _bounce_t: float = 0.0
var _flash_t: float = 0.0

func _ready() -> void:
	add_to_group("upgrade_blocks")

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if _bounce_t > 0.0:
		_bounce_t -= delta
		var f: float = sin((_bounce_t / 0.18) * PI) if _bounce_t > 0.0 else 0.0
		if _visual:
			_visual.position = _base_visual_pos - Vector2(0, 10.0 * f)
			_mark.position.y = -50 - 10.0 * f
	elif _visual:
		_visual.position = _base_visual_pos
	if _flash_t > 0.0:
		_flash_t -= delta
		var k: float = clamp(_flash_t / 0.35, 0.0, 1.0)
		if _visual:
			_visual.color = Palette.MID.lerp(Palette.GREEN, k)
	elif _visual:
		_visual.color = Palette.MID

func register_visual(visual: ColorRect, mark: Label) -> void:
	_visual = visual
	_mark = mark
	_base_visual_pos = visual.position

## Called by Player.gd when it collides with this block's underside while
## moving upward.
func try_hit(body: Node) -> void:
	if _cooldown > 0.0:
		return
	_cooldown = 0.4
	_bounce_t = 0.18

	var success := false
	match upgrade_key:
		"reward":
			success = GameManager.try_buy_reward()
		"reward_mult":
			success = GameManager.try_buy_reward_mult()
		"clone":
			success = GameManager.try_buy_clone()
		"clone_reward":
			success = GameManager.try_buy_clone_reward()
		"clone_reward_mult":
			success = GameManager.try_buy_clone_reward_mult()
		"level_upgrade":
			success = GameManager.try_buy_level_upgrade()

	if success:
		_flash_t = 0.35
		body.velocity.y = 60.0
		_spawn_burst()

	purchase_attempted.emit(success)

func _spawn_burst() -> void:
	var p := CPUParticles2D.new()
	add_child(p)
	p.position = Vector2(0, -40)
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 60.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 400)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = Palette.GREEN
	var timer := get_tree().create_timer(0.6)
	timer.timeout.connect(func(): p.queue_free())
