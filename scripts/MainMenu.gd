extends Node2D

## Sci-fi start screen: title, Play / Controls / Quit. Built fully in code
## like the rest of the project (no imported UI assets needed).

var _controls_panel: Control

func _ready() -> void:
	DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
	_build_background()

	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var title := Label.new()
	title.text = "VANGUARD RUN"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Palette.WHITE)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-320, 110)
	title.custom_minimum_size = Vector2(640, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "КООПЕРАТИВНЫЙ ПАРКУР · ДВА ПИЛОТА · ОБЩАЯ ЭКОНОМИКА"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Palette.GREEN)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-320, 190)
	subtitle.custom_minimum_size = Vector2(640, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-110, -20)
	box.custom_minimum_size = Vector2(220, 0)
	box.add_theme_constant_override("separation", 16)
	root.add_child(box)

	box.add_child(_make_button("ИГРАТЬ", _on_play))
	box.add_child(_make_button("УПРАВЛЕНИЕ", _on_controls))
	box.add_child(_make_button("ВЫХОД", _on_quit))

	var hint := Label.new()
	hint.text = "F11 — переключить полноэкранный режим"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Palette.MID)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.position = Vector2(0, -36)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)

	_build_controls_panel(layer)

func _make_button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(callback)
	return b

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG_BOTTOM
	bg.size = Vector2(1920, 1080)
	bg.position = Vector2(-200, -100)
	bg.z_index = -10
	add_child(bg)

	var grad := Gradient.new()
	grad.set_color(0, Palette.BG_TOP)
	grad.set_color(1, Palette.BG_BOTTOM)
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.width = 8
	grad_tex.height = 512
	var sky := TextureRect.new()
	sky.texture = grad_tex
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.size = Vector2(1920, 900)
	sky.position = Vector2(-200, -100)
	sky.z_index = -9
	add_child(sky)

	var motes := CPUParticles2D.new()
	motes.position = Vector2(760, 400)
	motes.emitting = true
	motes.amount = 40
	motes.lifetime = 8.0
	motes.preprocess = 8.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(900, 450, 0)
	motes.direction = Vector2(0, -1)
	motes.spread = 180.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 4.0
	motes.initial_velocity_max = 14.0
	motes.scale_amount_min = 1.0
	motes.scale_amount_max = 2.5
	motes.color = Color(Palette.GREEN.r, Palette.GREEN.g, Palette.GREEN.b, 0.3)
	add_child(motes)

func _build_controls_panel(layer: CanvasLayer) -> void:
	_controls_panel = Control.new()
	_controls_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_panel.visible = false
	layer.add_child(_controls_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls_panel.add_child(dim)

	var panel := ColorRect.new()
	panel.color = Palette.DARK
	panel.custom_minimum_size = Vector2(520, 320)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-260, -160)
	_controls_panel.add_child(panel)

	var text := Label.new()
	text.text = "УПРАВЛЕНИЕ\n\nИгрок 1 (клавиатура):\n  A / D — движение\n  ПРОБЕЛ / W — прыжок\n\nИгрок 2 (геймпад):\n  Стик влево/вправо — движение\n  Кнопка A — прыжок\n\nПрыгните снизу в блок \"?\", чтобы\nкупить улучшение из общего банка."
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Palette.WHITE)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.position = Vector2(-230, -140)
	text.custom_minimum_size = Vector2(460, 240)
	panel.add_child(text)

	var close_btn := Button.new()
	close_btn.text = "ЗАКРЫТЬ"
	close_btn.custom_minimum_size = Vector2(160, 44)
	close_btn.set_anchors_preset(Control.PRESET_CENTER)
	close_btn.position = Vector2(-80, 110)
	close_btn.pressed.connect(func(): _controls_panel.visible = false)
	panel.add_child(close_btn)

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_controls() -> void:
	_controls_panel.visible = true

func _on_quit() -> void:
	get_tree().quit()
