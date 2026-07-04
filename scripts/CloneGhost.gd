extends Node2D

## A translucent ghost that replays player 1's last recorded run on a loop,
## generating passive clone income each time it completes a lap.

func _ready() -> void:
	var visual := ColorRect.new()
	visual.size = Phys.PLAYER_SIZE
	visual.position = -Phys.PLAYER_SIZE / 2.0
	visual.color = Color(Palette.ORANGE.r, Palette.ORANGE.g, Palette.ORANGE.b, 0.55)
	add_child(visual)

func apply_pose(samples: Array, t: float) -> void:
	if samples.is_empty():
		return
	var prev = samples[0]
	var next = samples[samples.size() - 1]
	for s in samples:
		if s["t"] <= t:
			prev = s
		if s["t"] >= t:
			next = s
			break
	if next["t"] == prev["t"]:
		position = Vector2(prev["x"], prev["y"])
		return
	var span: float = next["t"] - prev["t"]
	var f: float = (t - prev["t"]) / span
	position = Vector2(prev["x"], prev["y"]).lerp(Vector2(next["x"], next["y"]), f)
