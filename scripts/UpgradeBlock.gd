extends Area2D

## Mario-style "?" block: bump it from below (moving upward) to spend the
## shared team bank on exactly one upgrade.

@export var upgrade_key: String = "reward"
# reward | reward_mult | clone | clone_reward | clone_reward_mult | level_upgrade

signal purchase_attempted(success: bool)

var _cooldown: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_entered)

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

func _on_entered(body: Node) -> void:
	if _cooldown > 0.0:
		return
	if not body.is_in_group("players"):
		return
	if body.velocity.y >= -10.0:
		return  # only trigger on an upward bump, like Mario blocks
	_cooldown = 0.4

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
		body.velocity.y = 120.0

	purchase_attempted.emit(success)
