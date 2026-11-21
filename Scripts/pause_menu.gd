extends Control

const DEFAULT_BG := Color(0.05, 0.05, 0.05, 0.45)
const HOVER_BG := Color(0.15, 0.0, 0.0, 0.55)
const PANEL_BG := Color(0.05, 0.05, 0.05, 0.85)
const FONT_COLOR := Color(0.85, 0.85, 0.85, 1)
const SELECTED_COLOR := Color(0.9, 0.85, 0.5)

const MENU_FONT = preload("res://Fonts/IMFellEnglish-Regular.ttf")

var _busy: bool = false
var _open: bool = false

var _sensitivity_slider: HSlider


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if _busy:
			return
		if _open:
			_resume()
		elif not get_tree().paused:
			_open_menu()


func _build():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.name = "PauseBackdrop"
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "PauseCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "PauseVBox"
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	var title := _make_title_label("PAUSED", 36)
	vbox.add_child(title)

	var resume := _make_menu_button("RESUME", _resume)
	vbox.add_child(resume)

	var settings := _make_menu_button("SETTINGS", _show_settings)
	vbox.add_child(settings)

	var main_menu := _make_menu_button("MAIN MENU", _back_to_main_menu)
	vbox.add_child(main_menu)

	var exit := _make_menu_button("EXIT", get_tree().quit)
	vbox.add_child(exit)


func _make_title_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", SELECTED_COLOR)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _make_menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_color_override("font_color", FONT_COLOR)
	button.add_theme_font_size_override("font_size", 28)

	var style := StyleBoxFlat.new()
	style.bg_color = DEFAULT_BG
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	button.pressed.connect(callback)
	return button


func _on_button_mouse_entered(button: Button):
	button.get_theme_stylebox("normal").bg_color = HOVER_BG


func _on_button_mouse_exited(button: Button):
	button.get_theme_stylebox("normal").bg_color = DEFAULT_BG


func _open_menu():
	_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true


func _resume():
	_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _show_settings():
	_busy = true
	var layer := CanvasLayer.new()
	layer.name = "PauseSettingsLayer"
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var overlay := Control.new()
	overlay.name = "SettingsOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = Color(0, 0, 0, 0.35)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.name = "SettingsPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(4)
	style.content_margin_left = 32.0
	style.content_margin_top = 24.0
	style.content_margin_right = 32.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	vbox.add_child(_make_title_label("SETTINGS", 28))

	var slider_label := _make_title_label("MOUSE SENSITIVITY", 20)
	vbox.add_child(slider_label)

	_sensitivity_slider = HSlider.new()
	_sensitivity_slider.name = "SensitivitySlider"
	_sensitivity_slider.min_value = 0.1
	_sensitivity_slider.max_value = 3.0
	_sensitivity_slider.step = 0.05
	_sensitivity_slider.value = GameState.mouse_sensitivity
	_sensitivity_slider.custom_minimum_size = Vector2(300, 0)
	_sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	vbox.add_child(_sensitivity_slider)

	var music_label := _make_title_label("MUSIC VOLUME", 20)
	vbox.add_child(music_label)

	var music_slider := HSlider.new()
	music_slider.min_value = -40.0
	music_slider.max_value = 0.0
	music_slider.step = 1.0
	music_slider.value = GameState.music_volume
	music_slider.custom_minimum_size = Vector2(300, 0)
	music_slider.value_changed.connect(_on_music_volume_changed)
	vbox.add_child(music_slider)

	vbox.add_child(_make_menu_button("BACK", func():
		_busy = false
		if is_instance_valid(layer):
			layer.queue_free()
	))


func _on_sensitivity_changed(value: float):
	GameState.mouse_sensitivity = value


func _on_music_volume_changed(value: float) -> void:
	GameState.music_volume = value
	for node in get_tree().get_nodes_in_group("bg_music"):
		if node is AudioStreamPlayer:
			node.volume_db = value


func _back_to_main_menu():
	_open = false
	visible = false
	Fade.to_black(self, func():
		get_tree().paused = false
		get_tree().change_scene_to_file(GameState.MAIN_MENU_SCENE)
	)
