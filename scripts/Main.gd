extends Node2D

## Ties everything together: hub with six upgrade blocks, procedurally
## generated parkour level, two players, camera, clone simulation and HUD.

const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const CLONE_SCRIPT := preload("res://scripts/CloneGhost.gd")

const START_TRIGGER_X := 240.0

var player1: CharacterBody2D
var player2: CharacterBody2D
var camera: Camera2D
var level_root: Node2D
var hub_root: Node2D
var finish_flag: Area2D

var level_info: Dictionary = {}
var run_active := false

var clones: Array = []
var clone_elapsed := 0.0
var clone_prev_phase: Array = []

var hud: CanvasLayer
var bank_label: Label
var run_label: Label
var upgrade_labels: Dictionary = {}

func _ready() -> void:
        camera = Camera2D.new()
        camera.zoom = Vector2(1.0, 1.0)
        add_child(camera)
        camera.make_current()

        _build_background()
        _build_hub()
        _build_level(GameManager.tier)
        _spawn_players()
        _build_hud()

        GameManager.bank_changed.connect(_on_bank_changed)
        GameManager.upgrades_changed.connect(_refresh_upgrade_labels)
        GameManager.level_regenerated.connect(_on_level_regenerated)

        _refresh_upgrade_labels()
        _on_bank_changed(GameManager.bank)

func _build_background() -> void:
        var bg := ColorRect.new()
        bg.color = Palette.BG_BOTTOM
        bg.size = Vector2(20000, 2000)
        bg.position = Vector2(-2000, -1200)
        bg.z_index = -10
        add_child(bg)

        var grad := Gradient.new()
        grad.set_color(0, Palette.BG_TOP)
        grad.set_color(1, Palette.BG_BOTTOM)
        var grad_tex := GradientTexture2D.new()
        grad_tex.gradient = grad
        grad_tex.fill = GradientTexture2D.FILL_LINEAR
        grad_tex.fill_from = Vector2(0, 0)
        grad_tex.fill_to = Vector2(0, 1)
        grad_tex.width = 8
        grad_tex.height = 512
        var sky := TextureRect.new()
        sky.texture = grad_tex
        sky.stretch_mode = TextureRect.STRETCH_SCALE
        sky.size = Vector2(20000, 1400)
        sky.position = Vector2(-2000, -1200)
        sky.z_index = -9
        add_child(sky)

        # Faint horizontal scan-line grid for a sci-fi HUD feel.
        for i in range(24):
                var line := ColorRect.new()
                line.color = Color(Palette.LIGHT.r, Palette.LIGHT.g, Palette.LIGHT.b, 0.03)
                line.size = Vector2(20000, 1)
                line.position = Vector2(-2000, -1200 + i * 60)
                line.z_index = -8
                add_child(line)

        _spawn_ambient_motes()

func _spawn_ambient_motes() -> void:
        var motes := CPUParticles2D.new()
        motes.z_index = -7
        motes.position = Vector2(0, LevelGenerator.GROUND_Y - 300)
        motes.emitting = true
        motes.amount = 40
        motes.lifetime = 8.0
        motes.preprocess = 8.0
        motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_BOX
        motes.emission_box_extents = Vector3(4000, 500, 0)
        motes.direction = Vector2(0, -1)
        motes.spread = 180.0
        motes.gravity = Vector2.ZERO
        motes.initial_velocity_min = 4.0
        motes.initial_velocity_max = 14.0
        motes.scale_amount_min = 1.0
        motes.scale_amount_max = 2.5
        motes.color = Color(Palette.GREEN.r, Palette.GREEN.g, Palette.GREEN.b, 0.35)
        add_child(motes)

func _build_hub() -> void:
        hub_root = Node2D.new()
        add_child(hub_root)

        var hub_ground := StaticBody2D.new()
        hub_root.add_child(hub_ground)
        var rect := RectangleShape2D.new()
        rect.size = Vector2(LevelGenerator.HUB_WIDTH, 200)
        var shape := CollisionShape2D.new()
        shape.shape = rect
        shape.position = rect.size / 2.0
        hub_ground.add_child(shape)
        hub_ground.position = Vector2(-LevelGenerator.HUB_WIDTH, LevelGenerator.GROUND_Y)

        var visual := ColorRect.new()
        visual.size = rect.size
        visual.color = Palette.DARK
        hub_ground.add_child(visual)
        var edge := ColorRect.new()
        edge.size = Vector2(rect.size.x, 6)
        edge.color = Palette.GREEN
        hub_ground.add_child(edge)

        var defs := [
                {"key": "reward", "name": "НАГРАДА", "x_ratio": 0.1},
                {"key": "reward_mult", "name": "МНОЖИТЕЛЬ НАГРАДЫ", "x_ratio": 0.24},
                {"key": "clone", "name": "КЛОН", "x_ratio": 0.42},
                {"key": "clone_reward", "name": "НАГРАДА КЛОНА", "x_ratio": 0.58},
                {"key": "clone_reward_mult", "name": "МНОЖИТЕЛЬ НАГРАДЫ КЛОНА", "x_ratio": 0.75},
                {"key": "level_upgrade", "name": "ПРОКАЧКА УРОВНЯ", "x_ratio": 0.92},
        ]

        for def in defs:
                var bx: float = -LevelGenerator.HUB_WIDTH + LevelGenerator.HUB_WIDTH * def["x_ratio"]
                _build_upgrade_block(def["key"], def["name"], Vector2(bx, LevelGenerator.GROUND_Y - 170))

func _build_upgrade_block(key: String, label_text: String, pos: Vector2) -> void:
        var block := StaticBody2D.new()
        block.set_script(load("res://scripts/UpgradeBlock.gd"))
        block.upgrade_key = key
        block.position = pos
        hub_root.add_child(block)

        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = Vector2(64, 64)
        shape.shape = rect
        block.add_child(shape)

        var visual := ColorRect.new()
        visual.size = rect.size
        visual.position = -rect.size / 2.0
        visual.color = Palette.MID
        block.add_child(visual)

        var glow := ColorRect.new()
        glow.size = Vector2(rect.size.x - 8, 4)
        glow.position = Vector2(-glow.size.x / 2.0, -rect.size.y / 2.0 + 2)
        glow.color = Palette.GREEN
        block.add_child(glow)

        var mark := Label.new()
        mark.text = "?"
        mark.add_theme_color_override("font_color", Palette.ORANGE)
        mark.add_theme_font_size_override("font_size", 32)
        mark.position = Vector2(-8, -50)
        block.add_child(mark)

        block.register_visual(visual, mark)

        var name_label := Label.new()
        name_label.text = label_text
        name_label.add_theme_color_override("font_color", Palette.WHITE)
        name_label.add_theme_font_size_override("font_size", 14)
        name_label.position = Vector2(-70, 20)
        name_label.custom_minimum_size = Vector2(180, 0)
        name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        block.add_child(name_label)

        var info_label := Label.new()
        info_label.add_theme_color_override("font_color", Palette.GREEN)
        info_label.add_theme_font_size_override("font_size", 13)
        info_label.position = Vector2(-70, 40)
        info_label.custom_minimum_size = Vector2(180, 0)
        info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        block.add_child(info_label)

        var pillar := ColorRect.new()
        pillar.size = Vector2(8, 170)
        pillar.position = Vector2(-4, 32)
        pillar.color = Palette.DARK
        block.add_child(pillar)

        upgrade_labels[key] = info_label

func _build_level(tier: int) -> void:
        if level_root:
                level_root.queue_free()
        level_root = Node2D.new()
        add_child(level_root)
        level_info = LevelGenerator.generate(tier, level_root)

        for hz in get_tree().get_nodes_in_group("hazards"):
                if not hz.player_hit.is_connected(_on_hazard_hit):
                        hz.player_hit.connect(_on_hazard_hit)

        finish_flag = Area2D.new()
        finish_flag.set_script(load("res://scripts/FinishFlag.gd"))
        finish_flag.position = level_info["finish"]
        level_root.add_child(finish_flag)
        var fshape := CollisionShape2D.new()
        var frect := RectangleShape2D.new()
        frect.size = Vector2(60, 160)
        fshape.shape = frect
        finish_flag.add_child(fshape)
        var fvisual := ColorRect.new()
        fvisual.size = frect.size
        fvisual.position = -frect.size / 2.0
        fvisual.color = Palette.GREEN
        finish_flag.add_child(fvisual)

func _spawn_players() -> void:
        if player1 == null:
                player1 = CharacterBody2D.new()
                player1.set_script(PLAYER_SCRIPT)
                player1.player_index = 1
                player1.body_color = Palette.WHITE
                add_child(player1)
        if player2 == null:
                player2 = CharacterBody2D.new()
                player2.set_script(PLAYER_SCRIPT)
                player2.player_index = 2
                player2.body_color = Palette.GREEN
                add_child(player2)

        var spawn: Vector2 = level_info["spawn"]
        player1.position = spawn + Vector2(-20, 0)
        player2.position = spawn + Vector2(20, 0)
        player1.velocity = Vector2.ZERO
        player2.velocity = Vector2.ZERO

func _build_hud() -> void:
        hud = CanvasLayer.new()
        add_child(hud)

        var panel := ColorRect.new()
        panel.color = Color(Palette.NEAR_BLACK.r, Palette.NEAR_BLACK.g, Palette.NEAR_BLACK.b, 0.7)
        panel.size = Vector2(360, 90)
        panel.position = Vector2(20, 20)
        hud.add_child(panel)

        bank_label = Label.new()
        bank_label.add_theme_font_size_override("font_size", 26)
        bank_label.add_theme_color_override("font_color", Palette.GREEN)
        bank_label.position = Vector2(36, 28)
        hud.add_child(bank_label)

        run_label = Label.new()
        run_label.add_theme_font_size_override("font_size", 16)
        run_label.add_theme_color_override("font_color", Palette.LIGHT)
        run_label.position = Vector2(36, 68)
        hud.add_child(run_label)

        var hint := Label.new()
        hint.text = "P1: A/D + ПРОБЕЛ    P2: СТИК + КНОПКА A"
        hint.add_theme_font_size_override("font_size", 14)
        hint.add_theme_color_override("font_color", Palette.MID)
        hint.position = Vector2(20, 130)
        hud.add_child(hint)

func _process(delta: float) -> void:
        _update_camera()
        _check_zone_transitions()
        _check_finish()
        _check_fall_death()
        _simulate_clones(delta)
        _update_run_label()

func _update_camera() -> void:
        if player1 == null or player2 == null:
                return
        var mid := (player1.position + player2.position) / 2.0
        var target := Vector2(mid.x, LevelGenerator.GROUND_Y - 200)
        camera.position = camera.position.lerp(target, 0.08)

func _check_zone_transitions() -> void:
        if player1 == null or player2 == null:
                return
        var lead_x: float = max(player1.position.x, player2.position.x)
        if not run_active and lead_x > START_TRIGGER_X:
                _start_run()
        elif run_active and lead_x < 0.0:
                _cancel_run()

func _start_run() -> void:
        run_active = true
        player1.start_recording()
        player2.start_recording()

func _cancel_run() -> void:
        run_active = false
        player1.is_recording = false
        player2.is_recording = false

func _check_finish() -> void:
        if not run_active or finish_flag == null:
                return
        if finish_flag.both_present(2):
                _complete_run()

func _complete_run() -> void:
        run_active = false
        var r1: Dictionary = player1.stop_recording()
        player2.stop_recording()
        GameManager.complete_run(r1["samples"], r1["duration"])
        _reset_clones_visuals()
        _respawn_players()

func _check_fall_death() -> void:
        if player1 == null or player2 == null:
                return
        var died := false
        if player1.position.y > LevelGenerator.GROUND_Y + 400:
                died = true
        if player2.position.y > LevelGenerator.GROUND_Y + 400:
                died = true
        if died:
                _on_hazard_hit()

func _on_hazard_hit() -> void:
        if not run_active:
                return
        run_active = false
        player1.is_recording = false
        player2.is_recording = false
        _respawn_players()

func _respawn_players() -> void:
        var spawn: Vector2 = level_info["spawn"]
        player1.respawn(spawn + Vector2(-20, 0))
        player2.respawn(spawn + Vector2(20, 0))

func _on_level_regenerated(new_tier: int) -> void:
        _build_level(new_tier)
        _respawn_players()
        _reset_clones_visuals()

func _reset_clones_visuals() -> void:
        for c in clones:
                c.queue_free()
        clones.clear()
        clone_prev_phase.clear()
        clone_elapsed = 0.0

func _simulate_clones(delta: float) -> void:
        var count := GameManager.clone_count()
        if not GameManager.has_recording or count <= 0:
                if clones.size() > 0:
                        _reset_clones_visuals()
                return

        while clones.size() < count:
                var g := Node2D.new()
                g.set_script(CLONE_SCRIPT)
                level_root.add_child(g)
                clones.append(g)
                clone_prev_phase.append(0.0)

        while clones.size() > count:
                var c = clones.pop_back()
                c.queue_free()
                clone_prev_phase.pop_back()

        clone_elapsed += delta
        var duration: float = max(GameManager.recording_duration, 0.1)
        var reward_per_lap := GameManager.clone_reward()

        for i in range(clones.size()):
                var phase_offset := duration * float(i) / float(max(count, 1))
                var t := fmod(clone_elapsed + phase_offset, duration)
                clones[i].apply_pose(GameManager.recording, t)

                if t < clone_prev_phase[i]:
                        GameManager.add_clone_income(reward_per_lap)
                clone_prev_phase[i] = t

func _update_run_label() -> void:
        if run_active:
                var t: float = player1.recording_time if player1 else 0.0
                run_label.text = "ЗАБЕГ: %.1fс" % t
        else:
                run_label.text = "ЗАБЕГ: ожидание у старта"

func _on_bank_changed(new_amount: int) -> void:
        bank_label.text = "◆ %d" % new_amount

func _refresh_upgrade_labels() -> void:
        if upgrade_labels.has("reward"):
                upgrade_labels["reward"].text = "Ур. %d · +%d монет · цена %d" % [GameManager.reward_level, GameManager.player_reward(), GameManager.reward_cost()]
        if upgrade_labels.has("reward_mult"):
                upgrade_labels["reward_mult"].text = "Ур. %d · x%.2f · цена %d" % [GameManager.reward_mult_level, 1.0 + GameManager.reward_mult_level * 0.15, GameManager.reward_mult_cost()]
        if upgrade_labels.has("clone"):
                var req_txt := "" if GameManager.has_recording else " (нужен забег)"
                upgrade_labels["clone"].text = "Клонов: %d · цена %d%s" % [GameManager.clone_level, GameManager.clone_cost(), req_txt]
        if upgrade_labels.has("clone_reward"):
                upgrade_labels["clone_reward"].text = "Ур. %d · +%d монет · цена %d" % [GameManager.clone_reward_level, GameManager.clone_reward(), GameManager.clone_reward_cost()]
        if upgrade_labels.has("clone_reward_mult"):
                upgrade_labels["clone_reward_mult"].text = "Ур. %d · x%.2f · цена %d" % [GameManager.clone_reward_mult_level, 1.0 + GameManager.clone_reward_mult_level * 0.15, GameManager.clone_reward_mult_cost()]
        if upgrade_labels.has("level_upgrade"):
                upgrade_labels["level_upgrade"].text = "Уровень %d · цена %d" % [GameManager.tier, GameManager.level_upgrade_cost()]
