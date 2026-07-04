extends RefCounted
class_name Phys

## Shared platforming physics constants. Tuned for a floppy, momentum-heavy
## "diving leap" feel (Super Bunny Man style) rather than a tight precision
## platformer: jumps are charged and launch the whole body into a tumble.

const GRAVITY := 2300.0
const MAX_FALL_SPEED := 1500.0
const MOVE_SPEED := 300.0
const PLAYER_SIZE := Vector2(42, 46)

const JUMP_CHARGE_MAX := 0.55
const JUMP_POWER_MIN := 560.0
const JUMP_POWER_MAX := 950.0
const JUMP_FORWARD_MIN := 60.0
const JUMP_FORWARD_MAX := 420.0
const HOP_POWER := 520.0

const HEAD_BOUNCE_VELOCITY := -1050.0
const BOUNCED_ON_PUSH := 260.0

const TUMBLE_SPIN_FACTOR := 3.2
