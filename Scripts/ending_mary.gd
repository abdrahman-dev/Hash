extends Node3D


const LINES: Array[String] = [
	"This place...",
	"I know this corridor.",
	"She was here."
]

const FONT = preload("res://Fonts/IMFellEnglish-Regular.ttf")
const CAMERA_RISE_DURATION := 2.5
const CAMERA_START_PITCH_DEG := -75.0
const CHAR_DELAY := 0.05
const LINE_HOLD := 1.5
const FADE_DURATION := 0.4
const TEXT_COLOR := Color(0.85, 0.85, 0.85, 1.0)
const FONT_SIZE := 36
const TYPING_VOLUME_DB := -12.0
const TYPING_SKIP_CHARS := " .,!?;:'\"()[]{}<>-_—…"


enum Phase { CAMERA_RISE, TYPING, LINE_FADE, DONE }


var _player: CharacterBody3D
var _camera_pivot: Node3D
var _camera: Camera3D
var _flashlight: SpotLight3D
var _typing_sound: AudioStreamPlayer
var _ui_layer: CanvasLayer
var _dialog_label: Label
var _camera_tween: Tween
var _label_tween: Tween

var _phase := Phase.CAMERA_RISE
var _line_index := 0
var _char_index := 0
var _char_timer := 0.0
var _hold_timer := 0.0
var _normal_pivot_rotation: Vector3


func _ready():
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player == null:
		push_error("ending_mary: Player not found in group 'player'")
		queue_free()
		return

	_player.set("_flashlight_on", false)
	_flashlight = _player.get("flashlight") as SpotLight3D
	if _flashlight == null:
		_flashlight = _player.find_child("SpotLight3D", true, false) as SpotLight3D
	if _flashlight:
		_flashlight.visible = false

	var intro := _player.get_node_or_null("IntroController") as Node
	if intro:
		intro.process_mode = Node.PROCESS_MODE_DISABLED

	_camera_pivot = _player.get_node_or_null("CameraPivot") as Node3D
	if _camera_pivot == null:
		push_error("ending_mary: CameraPivot not found on player")
		queue_free()
		return

	_camera = _camera_pivot.get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		push_error("ending_mary: Camera not found under CameraPivot")
		queue_free()
		return

	_typing_sound = _player.get_node_or_null("Typing") as AudioStreamPlayer
	if _typing_sound:
		_typing_sound.volume_db = TYPING_VOLUME_DB
		_disable_stream_loop(_typing_sound)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 10
	_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_layer)

	_dialog_label = Label.new()
	_dialog_label.name = "DialogLabel"
	_dialog_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_dialog_label.add_theme_font_override("font", FONT)
	_dialog_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_dialog_label.add_theme_color_override("font_color", TEXT_COLOR)
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_dialog_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dialog_label.offset_left = 100
	_dialog_label.offset_right = -100
	_dialog_label.offset_top = -50
	_dialog_label.offset_bottom = 400
	_dialog_label.modulate.a = 0.0
	_dialog_label.visible = false
	_ui_layer.add_child(_dialog_label)

	_player.set("_control_locked", true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	_hide_game_ui()
	if _flashlight:
		_flashlight.visible = false

	_normal_pivot_rotation = _camera_pivot.rotation
	_camera_pivot.rotation = _normal_pivot_rotation + Vector3(deg_to_rad(CAMERA_START_PITCH_DEG), 0.0, 0.0)

	_camera_tween = create_tween()
	_camera_tween.tween_property(_camera_pivot, "rotation:x", _normal_pivot_rotation.x, CAMERA_RISE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_camera_tween.finished.connect(_on_camera_rise_done)


func _on_camera_rise_done():
	if _camera_tween:
		_camera_tween.kill()
		_camera_tween = null
	_camera_pivot.rotation = _normal_pivot_rotation
	_begin_typing()


func _begin_typing():
	_phase = Phase.TYPING
	_line_index = 0
	_char_index = 0
	_char_timer = 0.0
	_hold_timer = 0.0
	_show_current_line()


func _show_current_line():
	if _dialog_label:
		_dialog_label.text = ""
		_dialog_label.modulate.a = 1.0
		_dialog_label.visible = true


func _process(delta: float):
	match _phase:
		Phase.TYPING:
			_process_typing(delta)
		Phase.LINE_FADE:
			_hold_timer -= delta
			if _hold_timer <= 0.0:
				_fade_out_current_line()


func _process_typing(delta: float):
	if _line_index >= LINES.size():
		return

	if _char_index == 0 and _dialog_label:
		_dialog_label.text = ""
		_dialog_label.visible = true

	var line := LINES[_line_index]
	if _char_index < line.length():
		_char_timer += delta
		while _char_timer >= CHAR_DELAY and _char_index < line.length():
			_char_timer -= CHAR_DELAY
			_char_index += 1
			if not _is_skip_char(line[_char_index - 1]):
				_play_typing_sound()
		if _dialog_label:
			_dialog_label.text = line.substr(0, _char_index)
	else:
		_hold_timer += delta
		if _hold_timer >= LINE_HOLD:
			_hold_timer = 0.0
			_phase = Phase.LINE_FADE


func _fade_out_current_line():
	if _dialog_label and _label_tween == null:
		_label_tween = create_tween()
		_label_tween.tween_property(_dialog_label, "modulate:a", 0.0, FADE_DURATION)
		_label_tween.finished.connect(_on_line_fade_done)


func _on_line_fade_done():
	if _label_tween:
		_label_tween.kill()
		_label_tween = null
	_line_index += 1
	_char_index = 0
	_char_timer = 0.0
	if _line_index >= LINES.size():
		_finish_sequence()
	else:
		_phase = Phase.TYPING
		_show_current_line()


func _hide_game_ui():
	var game_ui := _player.get_node_or_null("GameUI") as CanvasLayer
	if game_ui:
		for child_name in ["BookUI", "LivesUI", "InteractPrompt", "UIShader", "StaminaCrosshairUI"]:
			var child := game_ui.get_node_or_null(child_name) as CanvasItem
			if child:
				child.visible = false


func _finish_sequence():
	_phase = Phase.DONE
	if _typing_sound and _typing_sound.playing:
		_typing_sound.stop()
	if _dialog_label:
		_dialog_label.visible = false
		_dialog_label.queue_free()
	if _ui_layer:
		_ui_layer.queue_free()
	if _player:
		_player.set("_control_locked", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _disable_stream_loop(player: AudioStreamPlayer) -> void:
	var stream := player.stream
	if stream and stream.get_class() == "AudioStreamMP3" and stream.loop:
		stream.loop = false


func _play_typing_sound():
	if _typing_sound and _typing_sound.stream:
		_typing_sound.stop()
		_typing_sound.play()


func _is_skip_char(c: String) -> bool:
	return c in TYPING_SKIP_CHARS
