extends RefCounted
class_name LevelGenerator

## Procedurally builds the parkour level for a given tier. Higher tiers are
## longer and harder (more segments, more spikes, wider gaps).

const GROUND_Y := 620.0
const SEG_WIDTH := 320.0
const SAFE_ZONE_WIDTH := 260.0
const HUB_WIDTH := 900.0

static func generate(tier: int, parent: Node2D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + tier * 97

	var segment_count := 7 + tier * 2
	var x := 0.0

	_add_platform(parent, Vector2(x, GROUND_Y), Vector2(SAFE_ZONE_WIDTH, 200))
	var spawn := Vector2(x + SAFE_ZONE_WIDTH * 0.5, GROUND_Y - 80)
	x += SAFE_ZONE_WIDTH

	var templates := ["flat", "flat", "gap_platform", "spike_run", "stairs"]
	if tier >= 1:
		templates.append("gap_double")
	if tier >= 2:
		templates.append("moving_gap")
	if tier >= 3:
		templates.append("spike_gauntlet")

	for i in range(segment_count):
		var kind: String = templates[rng.randi_range(0, templates.size() - 1)]
		x = _build_segment(parent, rng, kind, x, tier)

	_add_platform(parent, Vector2(x, GROUND_Y), Vector2(240, 200))
	var finish := Vector2(x + 120, GROUND_Y - 90)
	x += 240

	return {"spawn": spawn, "finish": finish, "width": x, "ground_y": GROUND_Y}

static func _add_platform(parent: Node2D, top_left: Vector2, size: Vector2, moving: bool = false, travel: Vector2 = Vector2.ZERO, speed: float = 60.0) -> void:
	var body
	if moving:
		body = AnimatableBody2D.new()
		body.set_script(load("res://scripts/MovingPlatform.gd"))
		body.travel = travel
		body.speed = speed
	else:
		body = StaticBody2D.new()
	body.position = top_left
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = size / 2.0
	body.add_child(shape)

	var visual := ColorRect.new()
	visual.size = size
	visual.color = Palette.DARK
	body.add_child(visual)

	var edge := ColorRect.new()
	edge.size = Vector2(size.x, 6)
	edge.color = Palette.ORANGE if moving else Palette.GREEN
	body.add_child(edge)

static func _add_spike(parent: Node2D, pos: Vector2, width: float = 48.0) -> void:
	var area := Area2D.new()
	area.set_script(load("res://scripts/Hazard.gd"))
	area.position = pos
	parent.add_child(area)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width, 28)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	area.add_child(shape)

	var poly := Polygon2D.new()
	poly.color = Palette.RED
	poly.polygon = PackedVector2Array([
		Vector2(-width / 2.0, 0),
		Vector2(0, -28),
		Vector2(width / 2.0, 0),
	])
	area.add_child(poly)

static func _build_segment(parent: Node2D, rng: RandomNumberGenerator, kind: String, start_x: float, tier: int) -> float:
	var x := start_x
	match kind:
		"flat":
			var w := SEG_WIDTH
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(w, 200))
			if rng.randf() < 0.5 + tier * 0.05:
				_add_spike(parent, Vector2(x + w * 0.5, GROUND_Y))
			x += w
		"spike_run":
			var w := SEG_WIDTH + 40
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(w, 200))
			_add_spike(parent, Vector2(x + w * 0.3, GROUND_Y))
			_add_spike(parent, Vector2(x + w * 0.65, GROUND_Y))
			x += w
		"gap_platform":
			var gap := 160.0 + tier * 6.0
			_add_platform(parent, Vector2(x, GROUND_Y - 90), Vector2(140, 40))
			x += 140 + gap
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(SEG_WIDTH, 200))
			x += SEG_WIDTH
		"gap_double":
			_add_platform(parent, Vector2(x, GROUND_Y - 60), Vector2(120, 32))
			x += 120 + 140.0
			_add_platform(parent, Vector2(x, GROUND_Y - 140), Vector2(120, 32))
			x += 120 + 140.0
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(SEG_WIDTH, 200))
			x += SEG_WIDTH
		"stairs":
			var step_w := 110.0
			var step_h := 60.0
			for i in range(4):
				_add_platform(parent, Vector2(x, GROUND_Y - i * step_h), Vector2(step_w, 200 + i * step_h))
				x += step_w
			_add_platform(parent, Vector2(x, GROUND_Y - 3 * step_h), Vector2(SEG_WIDTH, 200))
			x += SEG_WIDTH
		"moving_gap":
			var gap := 300.0 + tier * 10.0
			_add_platform(parent, Vector2(x, GROUND_Y - 40), Vector2(120, 400), true, Vector2(gap - 40, 0), 90.0)
			x += gap + 120.0
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(SEG_WIDTH, 200))
			x += SEG_WIDTH
		"spike_gauntlet":
			var w := SEG_WIDTH + 100
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(w, 200))
			_add_spike(parent, Vector2(x + 60, GROUND_Y))
			_add_spike(parent, Vector2(x + w * 0.5, GROUND_Y))
			_add_spike(parent, Vector2(x + w - 60, GROUND_Y))
			x += w
		_:
			_add_platform(parent, Vector2(x, GROUND_Y), Vector2(SEG_WIDTH, 200))
			x += SEG_WIDTH
	return x
