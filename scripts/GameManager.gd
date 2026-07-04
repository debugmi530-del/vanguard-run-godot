extends Node

## Autoload singleton: shared team economy, upgrade levels, save/load,
## input map setup (P1 = keyboard, P2 = gamepad).

signal bank_changed(new_amount: int)
signal upgrades_changed()
signal level_regenerated(new_tier: int)

var bank: int = 0
var tier: int = 0

var reward_level: int = 0
var reward_mult_level: int = 0
var clone_level: int = 0
var clone_reward_level: int = 0
var clone_reward_mult_level: int = 0

# Recorded run of player 1 used for the clone ghosts. Array of {t, x, y}.
var recording: Array = []
var recording_duration: float = 0.0
var has_recording: bool = false

const SAVE_PATH := "user://vanguard_run_save.json"

func _ready() -> void:
        _setup_input_map()
        load_game()

func _unhandled_input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo:
                if event.physical_keycode == KEY_F11:
                        toggle_fullscreen()

func toggle_fullscreen() -> void:
        if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
        else:
                DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

# ---------------------------------------------------------------
# Input map: P1 keyboard, P2 gamepad (device 0)
# ---------------------------------------------------------------

func _setup_input_map() -> void:
        _ensure_action("p1_left")
        _add_key(&"p1_left", KEY_A)
        _add_key(&"p1_left", KEY_LEFT)

        _ensure_action("p1_right")
        _add_key(&"p1_right", KEY_D)
        _add_key(&"p1_right", KEY_RIGHT)

        _ensure_action("p1_jump")
        _add_key(&"p1_jump", KEY_SPACE)
        _add_key(&"p1_jump", KEY_W)
        _add_key(&"p1_jump", KEY_UP)

        _ensure_action("p2_left")
        _add_joy_axis(&"p2_left", JOY_AXIS_LEFT_X, -1.0)
        _add_joy_button(&"p2_left", JOY_BUTTON_DPAD_LEFT)

        _ensure_action("p2_right")
        _add_joy_axis(&"p2_right", JOY_AXIS_LEFT_X, 1.0)
        _add_joy_button(&"p2_right", JOY_BUTTON_DPAD_RIGHT)

        _ensure_action("p2_jump")
        _add_joy_button(&"p2_jump", JOY_BUTTON_A)
        _add_joy_button(&"p2_jump", JOY_BUTTON_X)

func _ensure_action(action_name: String) -> void:
        if not InputMap.has_action(action_name):
                InputMap.add_action(action_name)
                InputMap.action_set_deadzone(action_name, 0.35)

func _add_key(action_name: StringName, keycode: int) -> void:
        var ev := InputEventKey.new()
        ev.physical_keycode = keycode
        InputMap.action_add_event(action_name, ev)

func _add_joy_axis(action_name: StringName, axis: int, value: float) -> void:
        var ev := InputEventJoypadMotion.new()
        ev.device = 0
        ev.axis = axis
        ev.axis_value = value
        InputMap.action_add_event(action_name, ev)

func _add_joy_button(action_name: StringName, button: int) -> void:
        var ev := InputEventJoypadButton.new()
        ev.device = 0
        ev.button_index = button
        InputMap.action_add_event(action_name, ev)

# ---------------------------------------------------------------
# Upgrade cost formulas
# ---------------------------------------------------------------

func reward_cost() -> int:
        return int(floor(20.0 * pow(1.35, reward_level)))

func reward_mult_cost() -> int:
        return int(floor(30.0 * pow(1.4, reward_mult_level)))

func clone_cost() -> int:
        return int(floor(50.0 * pow(1.6, clone_level)))

func clone_reward_cost() -> int:
        return int(floor(35.0 * pow(1.5, clone_reward_level)))

func clone_reward_mult_cost() -> int:
        return int(floor(45.0 * pow(1.5, clone_reward_mult_level)))

func level_upgrade_cost() -> int:
        return int(floor(200.0 * pow(2.0, tier)))

# ---------------------------------------------------------------
# Upgrade effects
# ---------------------------------------------------------------

func player_reward() -> int:
        var base := 10.0 + reward_level * 5.0
        var mult := 1.0 + reward_mult_level * 0.15
        return int(round(base * mult))

func clone_reward() -> int:
        var base := 2.0 + clone_reward_level * 1.0
        var mult := 1.0 + clone_reward_mult_level * 0.15
        return int(round(base * mult))

func clone_count() -> int:
        return clone_level

# ---------------------------------------------------------------
# Purchases (each of the six "?" blocks calls exactly one of these)
# ---------------------------------------------------------------

func try_buy_reward() -> bool:
        var cost := reward_cost()
        if bank < cost:
                return false
        bank -= cost
        reward_level += 1
        bank_changed.emit(bank)
        upgrades_changed.emit()
        save_game()
        return true

func try_buy_reward_mult() -> bool:
        var cost := reward_mult_cost()
        if bank < cost:
                return false
        bank -= cost
        reward_mult_level += 1
        bank_changed.emit(bank)
        upgrades_changed.emit()
        save_game()
        return true

func try_buy_clone() -> bool:
        if not has_recording:
                return false
        var cost := clone_cost()
        if bank < cost:
                return false
        bank -= cost
        clone_level += 1
        bank_changed.emit(bank)
        upgrades_changed.emit()
        save_game()
        return true

func try_buy_clone_reward() -> bool:
        var cost := clone_reward_cost()
        if bank < cost:
                return false
        bank -= cost
        clone_reward_level += 1
        bank_changed.emit(bank)
        upgrades_changed.emit()
        save_game()
        return true

func try_buy_clone_reward_mult() -> bool:
        var cost := clone_reward_mult_cost()
        if bank < cost:
                return false
        bank -= cost
        clone_reward_mult_level += 1
        bank_changed.emit(bank)
        upgrades_changed.emit()
        save_game()
        return true

func try_buy_level_upgrade() -> bool:
        var cost := level_upgrade_cost()
        if bank < cost:
                return false
        bank -= cost
        tier += 1
        # Level upgrade resets ONLY clone-related progress. Player reward /
        # reward multiplier levels and the bank persist.
        clone_level = 0
        clone_reward_level = 0
        clone_reward_mult_level = 0
        recording = []
        recording_duration = 0.0
        has_recording = false
        bank_changed.emit(bank)
        upgrades_changed.emit()
        level_regenerated.emit(tier)
        save_game()
        return true

# ---------------------------------------------------------------
# Run completion / clone income
# ---------------------------------------------------------------

func complete_run(samples: Array, duration: float) -> void:
        recording = samples
        recording_duration = max(duration, 0.1)
        has_recording = true
        var earned := player_reward()
        bank += earned
        bank_changed.emit(bank)
        upgrades_changed.emit()
        save_game()

func add_clone_income(amount: int) -> void:
        if amount <= 0:
                return
        bank += amount
        bank_changed.emit(bank)

# ---------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------

func save_game() -> void:
        var data := {
                "bank": bank,
                "tier": tier,
                "reward_level": reward_level,
                "reward_mult_level": reward_mult_level,
                "clone_level": clone_level,
                "clone_reward_level": clone_reward_level,
                "clone_reward_mult_level": clone_reward_mult_level,
                "has_recording": has_recording,
                "recording_duration": recording_duration,
                "recording": recording,
        }
        var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
        if f:
                f.store_string(JSON.stringify(data))
                f.close()

func load_game() -> void:
        if not FileAccess.file_exists(SAVE_PATH):
                return
        var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
        if not f:
                return
        var text := f.get_as_text()
        f.close()
        var parsed = JSON.parse_string(text)
        if typeof(parsed) != TYPE_DICTIONARY:
                return
        bank = parsed.get("bank", 0)
        tier = parsed.get("tier", 0)
        reward_level = parsed.get("reward_level", 0)
        reward_mult_level = parsed.get("reward_mult_level", 0)
        clone_level = parsed.get("clone_level", 0)
        clone_reward_level = parsed.get("clone_reward_level", 0)
        clone_reward_mult_level = parsed.get("clone_reward_mult_level", 0)
        has_recording = parsed.get("has_recording", false)
        recording_duration = parsed.get("recording_duration", 0.0)
        recording = parsed.get("recording", [])
