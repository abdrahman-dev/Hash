extends Node


const LINES: Array[String] = [
	"Where am I...?",
	"My head hurts...",
	"What happened...?",
	"Wait.",
	"The book...",
	"Did it actually work?",
	"I need to find the curses.",
]

const RISE_DURATION := 2.6
const CAMERA_START_LOWER := 1.0
const CAMERA_START_PITCH_DEG := -65.0

const SWAY_FREQ := 1.6
const SWAY_AMP := 0.03
const SWAY_FADE_RATE := 0.25

const CHAR_DELAY := 0.05
const LINE_HOLD := 0.9

const HINT_TEXT := "Press F to turn on the flashlight."
const HINT_DURATION := 3.0

const TEXT_COLOR := Color(0.65, 0.05, 0.05, 1.0)
const TYPING_VOLUME_DB := -12.0
const TYPING_SKIP_CHARS := " .,!?;:'\"()[]{}<>-_—…"


enum Phase { CAMERA, TEXT, FLASH_OFF, HINT, DONE }


var _player: CharacterBody3D
var _camera: Camera3D
var _typing: AudioStreamPlayer
var _gameui: CanvasLayer
var _label: Label
var _camera_tween: Tween

var _camera_resolved := false
var _normal_camera_position := Vector3.ZERO
var _normal_camera_rotation := Vector3.ZERO

var _phase := Phase.CAMERA
var _sway_time := 0.0
var _sway_amp := SWAY_AMP

var _line_index := 0
var _char_index := 0
var _char_timer := 0.0
var _hold_timer := 0.0
var _hint_timer := 0.0


func _ready():
	_player = get_parent() as CharacterBody3D
	if _player == null:
		queue_free()
		return
	_typing = _player.get_node_or_null("Typing") as AudioStreamPlayer
	if _typing:
		_typing.volume_db = TYPING_VOLUME_DB
		_disable_stream_loop(_typing)
	_gameui = _player.get_node_or_null("GameUI") as CanvasLayer
	_build_label()

	# _control_locked is an existing player_controller mechanism that disables
	# both mouse look and movement. Reuse it; it is cleared by respawn() too.
	_player.set("_control_locked", true)


func _build_label():
	if _gameui == null:
		return
	_label = Label.new()
	_label.name = "IntroText"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_gameui.add_child(_label)
	# Lower third of the viewport, horizontally centered, clear of the bottom HUD.
	_label.anchor_left = 0.08
	_label.anchor_top = 0.60
	_label.anchor_right = 0.92
	_label.anchor_bottom = 0.80
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	var shader := _gameui.get_node_or_null("UIShader")
	if shader:
		_gameui.move_child(_label, shader.get_index())


func _process(delta: float):
	if not _camera_resolved:
		_resolve_camera()
		if not _camera_resolved:
			return

	match _phase:
		Phase.CAMERA:
			_sway_time += delta
			_sway_amp = move_toward(_sway_amp, 0.0, SWAY_FADE_RATE * delta)
			_camera.position.x = _normal_camera_position.x + sin(_sway_time * SWAY_FREQ) * _sway_amp
			_camera.rotation.z = _normal_camera_rotation.z + sin(_sway_time * SWAY_FREQ * 0.7) * _sway_amp * 0.35
		Phase.TEXT:
			_process_typing(delta)
		Phase.HINT:
			_hint_timer -= delta
			if _hint_timer <= 0.0:
				_finish_intro()


# The real first-person viewpoint is the runtime current Camera that
# player_controller._ensure_child_nodes() creates under CameraPivot (named
# "Camera"). The scene's dormant "Camera3D" is never current, so resolve the
# camera lazily after the player's _ready has run and animate that node.
func _resolve_camera():
	var cam := _player.get_node_or_null("CameraPivot/Camera") as Camera3D
	if cam == null or not cam.current:
		var vp := _player.get_viewport()
		if vp:
			cam = vp.get_camera_3d()
	if cam == null:
		return
	_camera = cam
	_camera_resolved = true
	_start_camera()


func _start_camera():
	_normal_camera_position = _camera.position
	_normal_camera_rotation = _camera.rotation
	_camera.position = _normal_camera_position + Vector3(0.0, -CAMERA_START_LOWER, 0.0)
	_camera.rotation = _normal_camera_rotation + Vector3(deg_to_rad(CAMERA_START_PITCH_DEG), 0.0, 0.0)

	_camera_tween = create_tween()
	_camera_tween.set_parallel(true)
	_camera_tween.tween_property(_camera, "position:y", _normal_camera_position.y, RISE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_property(_camera, "rotation:x", _normal_camera_rotation.x, RISE_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_camera_tween.finished.connect(_on_camera_done)


func _on_camera_done():
	if _camera_tween:
		_camera_tween.kill()
		_camera_tween = null
	_camera.position = _normal_camera_position
	_camera.rotation = _normal_camera_rotation
	_sway_amp = 0.0
	_begin_text()


func _begin_text():
	_phase = Phase.TEXT
	_line_index = 0
	_char_index = 0
	_char_timer = 0.0
	_hold_timer = 0.0
	if _label:
		_label.text = ""
		_label.visible = false


func _process_typing(delta: float):
	if _line_index >= LINES.size():
		return
	if _char_index == 0:
		_label.text = ""
		_label.visible = true

	var line := LINES[_line_index]
	if _char_index < line.length():
		_char_timer += delta
		while _char_timer >= CHAR_DELAY and _char_index < line.length():
			_char_timer -= CHAR_DELAY
			_char_index += 1
			if not _is_skip_char(line[_char_index - 1]):
				_play_typing()
		_label.text = line.substr(0, _char_index)
	else:
		_hold_timer += delta
		if _hold_timer >= LINE_HOLD:
			_hold_timer = 0.0
			_line_index += 1
			_char_index = 0
			_char_timer = 0.0
			if _line_index >= LINES.size():
				_finish_text()


func _finish_text():
	if _typing and _typing.playing:
		_typing.stop()
	if _label:
		_label.visible = false
		_label.text = ""
	_turn_flashlight_off()


func _turn_flashlight_off():
	if _player.has_method("is_flashlight_on") and _player.is_flashlight_on():
		if _player.has_method("toggle_flashlight"):
			_player.toggle_flashlight()
	_show_hint()


func _show_hint():
	if _label:
		_label.text = HINT_TEXT
		_label.visible = true
	_hint_timer = HINT_DURATION
	_phase = Phase.HINT


func _finish_intro():
	_phase = Phase.DONE
	if _typing and _typing.stream and _typing.playing:
		_typing.stop()
	if _label:
		_label.visible = false
		_label.queue_free()
	if _player:
		_player.set("_control_locked", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()


func _disable_stream_loop(player: AudioStreamPlayer) -> void:
	var stream := player.stream
	if stream and stream.get_class() == "AudioStreamMP3" and stream.loop:
		stream.loop = false


func _play_typing():
	if _typing and _typing.stream:
		_typing.stop()
		_typing.play()


func _is_skip_char(c: String) -> bool:
	return c in TYPING_SKIP_CHARS


func _unhandled_input(event: InputEvent):
	if _phase == Phase.DONE:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("flashlight_toggle"):
		get_viewport().set_input_as_handled()
