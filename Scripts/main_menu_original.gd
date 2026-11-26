extends Node3D

const DEFAULT_BG := Color(0.05, 0.05, 0.05, 0.45)
const HOVER_BG := Color(0.15, 0.0, 0.0, 0.55)
const PANEL_BG := Color(0.05, 0.05, 0.05, 0.85)
const FONT_COLOR := Color(0.85, 0.85, 0.85, 1)

const MENU_FONT = preload("res://Fonts/IMFellEnglish-Regular.ttf")

const CREDITS_LINES := [
	"REMNANT",
	"",
	"Developed by",
	"DimlitGames",
	"",
	"Made with Godot 4.7",
	"",
	"https://dimlitgames.vercel.app/",
	"",
	"Press Esc to return",
]

@onready var monster_intro = $MonsterIntro

@onready var _buttons: Array[Button] = [
	$CanvasLayer/VBoxContainer/BtnNewGame,
	$CanvasLayer/VBoxContainer/BtnSettings,
	$CanvasLayer/VBoxContainer/BtnCredits,
	$CanvasLayer/VBoxContainer/BtnExit,
]

var _settings_overlay: Control
var _credits_overlay: Control
var _sensitivity_slider: HSlider
var _music: AudioStreamPlayer


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_music = AudioStreamPlayer.new()
	var stream := AudioStreamWAV.new()
	stream = preload("res://Sounds/Theme/remnant_theme.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_PINGPONG
	stream.loop_begin = 0
	stream.loop_end = stream.get_length() * 44100  # sample count not seconds
	_music.stream = stream
	_music.volume_db = GameState.music_volume
	_music.bus = "Master"
	_music.add_to_group("bg_music")
	add_child(_music)
	_music.play()
	await get_tree().process_frame
	$CanvasLayer.add_child(_build_settings_overlay())
	$CanvasLayer.add_child(_build_credits_overlay())
	for button in _buttons:
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
		button.pressed.connect(_on_menu_button_pressed.bind(button))


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if _settings_overlay and _settings_overlay.visible:
			_hide_settings()
		elif _credits_overlay and _credits_overlay.visible:
			_hide_credits()


func _on_menu_button_pressed(button: Button):
	if button == $CanvasLayer/VBoxContainer/BtnNewGame:
		_start_new_game()
	elif button == $CanvasLayer/VBoxContainer/BtnSettings:
		_show_overlay(_settings_overlay)
	elif button == $CanvasLayer/VBoxContainer/BtnCredits:
		_show_overlay(_credits_overlay)
	elif button == $CanvasLayer/VBoxContainer/BtnExit:
		get_tree().quit()


func _start_new_game():
	for button in _buttons:
		button.disabled = true
	if _music:
		_music.stop()
	monster_intro.play_scream()
	$Intro.play("intro")
	await get_tree().create_timer(3).timeout
	get_tree().change_scene_to_file(GameState.GAME_SCENE)


func _on_button_mouse_entered(button: Button):
	button.get_theme_stylebox("normal").bg_color = HOVER_BG


func _on_button_mouse_exited(button: Button):
	button.get_theme_stylebox("normal").bg_color = DEFAULT_BG


func _on_sensitivity_changed(value: float):
	GameState.mouse_sensitivity = value


func _on_music_volume_changed(value: float) -> void:
	GameState.music_volume = value
	if _music:
		_music.volume_db = value


func _show_overlay(overlay: Control):
	_hide_overlays()
	overlay.visible = true


func _hide_overlays():
	if _settings_overlay:
		_settings_overlay.visible = false
	if _credits_overlay:
		_credits_overlay.visible = false


func _hide_settings():
	_settings_overlay.visible = false


func _hide_credits():
	_credits_overlay.visible = false


func _build_settings_overlay() -> Control:
	var overlay := _build_overlay_root("SettingsOverlay")
	_settings_overlay = overlay

	var panel := _make_panel("SettingsPanel")
	overlay.get_node("Center").add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	vbox.add_child(_make_title_label("SETTINGS"))

	var slider_label := _make_title_label("MOUSE SENSITIVITY")
	slider_label.add_theme_font_size_override("font_size", 20)
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

	var music_label := _make_title_label("MUSIC VOLUME")
	music_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(music_label)

	var music_slider := HSlider.new()
	music_slider.min_value = -40.0
	music_slider.max_value = 0.0
	music_slider.step = 1.0
	music_slider.value = GameState.music_volume
	music_slider.custom_minimum_size = Vector2(300, 0)
	music_slider.value_changed.connect(_on_music_volume_changed)
	vbox.add_child(music_slider)

	vbox.add_child(_make_back_button("SettingsBack", _hide_settings))
	return overlay


func _build_credits_overlay() -> Control:
	var overlay := _build_overlay_root("CreditsOverlay")
	_credits_overlay = overlay

	var panel := _make_panel("CreditsPanel")
	overlay.get_node("Center").add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	vbox.add_child(_make_title_label("CREDITS"))

	for line in CREDITS_LINES:
		var label := _make_title_label(line)
		if line == "REMNANT":
			label.add_theme_font_size_override("font_size", 40)
		vbox.add_child(label)

	vbox.add_child(_make_back_button("CreditsBack", _hide_credits))
	return overlay


func _build_overlay_root(overlay_name: String) -> Control:
	var overlay := Control.new()
	overlay.name = overlay_name
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

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

	return overlay


func _make_panel(panel_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(4)
	style.content_margin_left = 32.0
	style.content_margin_top = 24.0
	style.content_margin_right = 32.0
	style.content_margin_bottom = 24.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", MENU_FONT)
	label.add_theme_color_override("font_color", FONT_COLOR)
	label.add_theme_font_size_override("font_size", 28)
	return label


func _make_back_button(button_name: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = "BACK"
	button.custom_minimum_size = Vector2(200, 0)
	button.add_theme_font_override("font", MENU_FONT)
	button.add_theme_color_override("font_color", FONT_COLOR)
	button.add_theme_font_size_override("font_size", 22)

	var style := StyleBoxFlat.new()
	style.bg_color = DEFAULT_BG
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	button.pressed.connect(callback)
	button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
	button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
	return button
