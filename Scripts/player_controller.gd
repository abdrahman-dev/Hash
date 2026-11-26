extends CharacterBody3D


signal noise_changed(value: float)
signal stamina_changed(current: float, max: float)
signal damage_completed


@export var mouse_sensitivity: float = 0.15

@export var walk_speed: float = 2.8
@export var run_speed: float = 5.2
@export var acceleration: float = 20.0
@export var deceleration: float = 24.0
@export var turn_boost: float = 2.2  # how much snappier a sharp direction change reacts vs a straight speed-up

@export var bob_frequency_walk: float = 9.5
@export var bob_frequency_run: float = 14.0
@export var bob_amplitude: float = 0.055

@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_recover_rate: float = 20.0
@export var stamina_recover_threshold: float = 25.0

@export var footstep_volume_idle: float = -80.0
@export var footstep_volume_walk: float = -12.0
@export var footstep_volume_run: float = -4.0
@export var footstep_pitch_idle: float = 0.95
@export var footstep_pitch_run: float = 1.05
@export var footstep_blend_speed: float = 200.0

@export var breath_volume_idle: float = -28.0
@export var breath_volume_run: float = -18.0
@export var breath_pitch_idle: float = 0.97
@export var breath_pitch_run: float = 1.02
@export var breath_blend_speed: float = 4.0

@export var scream_shake_strength: float = 0.09
@export var scream_shake_frequency: float = 24.0
@export var scream_shake_decay: float = 1.4
@export var scream_kick_pitch: float = -8.0
@export var scream_kick_yaw: float = 6.0
@export var scream_kick_roll: float = -5.0
@export var scream_fov_increase: float = 10.0
@export var scream_fov_decay: float = 1.8

@export var damage_flash_color: Color = Color(0.6, 0.0, 0.0, 0.35)
@export var damage_effect_duration: float = 0.4

# --- flashlight wear ---
@export var flicker_start_time: float = 180.0
@export var flicker_max_time: float = 360.0
@export var recovery_off_time: float = 20.0
@export var min_brightness: float = 0.35
@export var base_dim_amount: float = 0.15

# --- humanizing movement feel ---
@export var lean_angle: float = 2.2        # degrees of camera roll while strafing
@export var lean_speed: float = 7.0        # how fast the lean eases in/out
@export var landing_bounce_strength: float = 0.06
@export var landing_bounce_speed: float = 9.0

var current_stamina: float = 100.0

var camera_pivot: Node3D
var camera: Camera3D
var footstep_player: AudioStreamPlayer3D
var breath_audio: AudioStreamPlayer3D
var flashlight: SpotLight3D
var flashlight_audio: AudioStreamPlayer
var note_paper_audio: AudioStreamPlayer
var _flashlight_on: bool = true

const FLICKER_INTERVAL_START: float = 2.5
const FLICKER_INTERVAL_END: float = 0.8
const FLICKER_INTERVAL_JITTER: float = 0.25
const FLICKER_DIP_FADE_TIME: float = 0.12
const FLICKER_RECOVER_FADE_TIME: float = 0.30
const FLICKER_FULL_RECOVERY_TIME: float = 1.5
const FLICKER_CUTOUT_START_TIME: float = 270.0
const FLICKER_CUTOUT_CHANCE: float = 0.08
const FLICKER_RANGE_DIM: float = 0.15
const FLICKER_CLICK_VOLUME_DB: float = -18.0
const FLICKER_CLICK_CHANCE: float = 0.35

var _flashlight_base_energy: float = 0.0
var _flashlight_current_energy: float = 0.0
var _flashlight_target_energy: float = 0.0
var _flashlight_fade_target: float = 0.0
var _flashlight_fade_speed: float = 0.0
var _flashlight_base_range: float = 0.0
var _flashlight_usage_time: float = 0.0
var _flashlight_off_time: float = 0.0
var _flashlight_flicker_started: bool = false
var _flashlight_recovery_pending: bool = false
var _flashlight_recovery_time_left: float = 0.0
var _flicker_event_active: bool = false
var _flicker_steps_remaining: int = 0
var _flicker_step_time: float = 0.0
var _flicker_step_is_dip: bool = false
var _flicker_dip_target_energy: float = 0.0
var _flicker_clicked_this_event: bool = false
var _flicker_next_time: float = 0.0
var _flashlight_audio_base_volume: float = 0.0
var _flashlight_quiet_click: bool = false

var interact_prompt: Label
var interact_note: Node3D = null
var _reading_ui: Control = null
var _reading_open: bool = false

var interact_knife: Node = null
var interact_mary_note: Node = null
var _mary_ui: Control = null
var _mary_ui_open: bool = false
var _mary_ui_canvas: CanvasLayer = null
var _mary_ui_canvas_mode: int = Node.PROCESS_MODE_INHERIT
var _mary_ui_close_time_msec: int = -1
var _mary_ui_ignore_interact_frame: bool = false
var _mary_puzzle_finished: bool = false
var _knife_used: bool = false
var _stab_count: int = 0
var _writing_locked: bool = false

const READING_UI_SCENE := "res://Scenes/reading_ui.tscn"
const NOTE_PAPER_SOUND := "res://Sounds/papper.mp3"
const MARY_UI_SCENE: String = "res://Scenes/mary_ui.tscn"
const MARY_UI_REOPEN_DELAY_MSEC: int = 400
const MAX_STABS: int = 3
const CUT_SOUND_FALLBACK := "res://Sounds/hurt.mp3"
const MARY_RESTART_SCENE := "res://Scenes/world.tscn"
const MARY_ENDING_SCENE := "res://Scenes/ending.tscn"
const DOOR_SOUND_PATHS := [
	"res://Sounds/Door/CreakDoor.mp3",
	"res://Sounds/door_open.mp3",
]

var _pivot_initial_pos: Vector3
var _bob_time: float = 0.0
var _bob_weight: float = 0.0
var _previous_noise: float = -1.0
var _stamina_locked: bool = false
var _breath_intensity: float = 0.0

var _shake_trauma: float = 0.0
var _shake_time: float = 0.0
var _camera_rest_rotation: Vector3
var _fov_trauma: float = 0.0
var _fov_default: float = 75.0

var _control_locked: bool = false
var _death_active: bool = false
var _death_rig: DeathCam = null
var _ritual_locked: bool = false
var _heartbeat_player: AudioStreamPlayer
var _heartbeat_active: bool = false
var _heartbeat_target_vol: float = -80.0
var _heartbeat_target_pitch: float = 1.0
var _monster_ref: Node3D = null

var _spawn_transform: Transform3D

# humanizing state
var _lean_current: float = 0.0
var _was_on_floor: bool = true
var _landing_bounce: float = 0.0

# --- fake ambient scare director ---
const SCARE_IGNORED_NAMES := ["Walking", "Breathing", "Heartbeat", "RitualHum", "Footsteps"]
const SCARE_QUIET_TIME: float = 45.0
const SCARE_ATTEMPT_CHANCE: float = 0.65
const SCARE_DANGER_DISTANCE: float = 10.0
const SCARE_HUNTING_STATE: int = 2  # monster_ai.State.HUNTING (IDLE=0, INVESTIGATING=1, HUNTING=2)
const SCARE_MIN_DIST: float = 4.0
const SCARE_MAX_DIST: float = 7.0
const SCARE_JITTER: float = 1.5

var _scare_players: Array = []
var _scare_tiers: Array = []
var _scare_timer: float = 0.0
var _scare_elapsed: float = 0.0
var _scare_last_index: int = -1
var _scare_enabled: bool = false
var _scare_monster: Node3D = null

const HEARTBEAT_ATTACK_SPEED: float = 55.0
const HEARTBEAT_RELEASE_SPEED: float = 18.0
const HEARTBEAT_FADEOUT_SPEED: float = 45.0
const HEARTBEAT_PITCH_SPEED: float = 2.0
const HEARTBEAT_VOLUME_FAR: float = -20.0
const HEARTBEAT_VOLUME_CLOSE: float = 0.0
const HEARTBEAT_PITCH_FAR: float = 0.90
const HEARTBEAT_PITCH_CLOSE: float = 1.25


func _ready():
	add_to_group("player")
	_ensure_child_nodes()
	_setup_input_actions()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_pivot_initial_pos = camera_pivot.position
	_fov_default = camera.fov
	_spawn_transform = global_transform
	_was_on_floor = is_on_floor()
	footstep_player.volume_db = footstep_volume_idle
	footstep_player.play()
	breath_audio.play()
	_setup_scare_director()

	if flashlight:
		_flashlight_base_energy = flashlight.light_energy
		_flashlight_current_energy = _flashlight_base_energy
		_flashlight_target_energy = _flashlight_base_energy
		_flashlight_fade_target = _flashlight_base_energy
		_flashlight_fade_speed = _flashlight_base_energy / FLICKER_RECOVER_FADE_TIME
		_flashlight_base_range = flashlight.spot_range
	if flashlight_audio:
		_flashlight_audio_base_volume = flashlight_audio.volume_db
		flashlight_audio.finished.connect(_on_flashlight_audio_finished)
	_reset_mary_puzzle_state()


# Fresh scene load always starts the Mary corridor puzzle from zero.
func _reset_mary_puzzle_state() -> void:
	interact_knife = null
	interact_mary_note = null
	_mary_ui = null
	_mary_ui_open = false
	_mary_ui_canvas = null
	_mary_ui_canvas_mode = Node.PROCESS_MODE_INHERIT
	_mary_ui_close_time_msec = -1
	_mary_ui_ignore_interact_frame = false
	_mary_puzzle_finished = false
	_knife_used = false
	_stab_count = 0
	_writing_locked = false


# Creates expected child nodes at correct positions if they don't exist,
# so the script works when dropped onto any CharacterBody3D with no setup.
func _ensure_child_nodes():
	if not has_node("CameraPivot"):
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		camera_pivot.position = Vector3(0, 1.6, 0)
		add_child(camera_pivot)
	else:
		camera_pivot = $CameraPivot

	if not camera_pivot.has_node("Camera"):
		camera = Camera3D.new()
		camera.name = "Camera"
		camera.current = true
		camera_pivot.add_child(camera)
	else:
		camera = camera_pivot.get_node("Camera")

	if not has_node("CameraPivot/Camera3D/SpotLight3D"):
		flashlight = SpotLight3D.new()
		flashlight.name = "SpotLight3D"
		flashlight.light_energy = 3.0
		flashlight.spot_range = 12.0
		flashlight.spot_angle = 45.0
		flashlight.shadow_enabled = true
		camera.add_child(flashlight)
	else:
		flashlight = $CameraPivot/Camera3D/SpotLight3D
		# Reparent the flashlight onto the runtime viewpoint camera so the beam
		# inherits the exact view transform (look, bob, lean, sway, shake).
		if flashlight.get_parent() != camera:
			var flashlight_transform := flashlight.transform
			var old_parent := flashlight.get_parent()
			if old_parent:
				old_parent.remove_child(flashlight)
			camera.add_child(flashlight)
			flashlight.transform = flashlight_transform
	_flashlight_on = flashlight.visible

	flashlight_audio = get_node_or_null("Flashlight") as AudioStreamPlayer
	note_paper_audio = get_node_or_null("Notepapper") as AudioStreamPlayer
	if note_paper_audio:
		note_paper_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	if note_paper_audio and note_paper_audio.stream == null:
		note_paper_audio.stream = load(NOTE_PAPER_SOUND)

	var gameui := get_node_or_null("GameUI") as CanvasLayer
	if gameui:
		interact_prompt = gameui.get_node_or_null("InteractPrompt") as Label
	if not interact_prompt:
		interact_prompt = Label.new()
		interact_prompt.name = "InteractPrompt"
		interact_prompt.text = "[E] Read"
		interact_prompt.visible = false
		interact_prompt.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
		interact_prompt.add_theme_font_size_override("font_size", 24)
		interact_prompt.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62, 1.0))
		if gameui:
			gameui.add_child(interact_prompt)

	if not has_node("Walking"):
		footstep_player = AudioStreamPlayer3D.new()
		footstep_player.name = "Walking"
		footstep_player.max_distance = 20.0
		add_child(footstep_player)
	else:
		footstep_player = $Walking

	if not has_node("Breathing"):
		breath_audio = AudioStreamPlayer3D.new()
		breath_audio.name = "Breathing"
		add_child(breath_audio)
	else:
		breath_audio = $Breathing

	if not has_node("CollisionShape3D"):
		var shape: CapsuleShape3D = CapsuleShape3D.new()
		shape.height = 1.8
		shape.radius = 0.4
		var cs: CollisionShape3D = CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		cs.shape = shape
		add_child(cs)

	if not has_node("Heartbeat"):
		_heartbeat_player = AudioStreamPlayer.new()
		_heartbeat_player.name = "Heartbeat"
		add_child(_heartbeat_player)
	else:
		_heartbeat_player = $Heartbeat
	_heartbeat_player.volume_db = HEARTBEAT_VOLUME_FAR - 15.0
	_heartbeat_player.finished.connect(_on_heartbeat_finished)


func _input(event: InputEvent):
	if _control_locked or _mary_ui_open:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := mouse_sensitivity * GameState.mouse_sensitivity
		rotate_y(deg_to_rad(-event.relative.x * sensitivity))
		camera_pivot.rotate_x(deg_to_rad(-event.relative.y * sensitivity))
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _unhandled_input(event: InputEvent):
	# The paper owns the keyboard while it is open (A is also move_left, E is
	# also interact). mary_ui consumes the keys it uses in _input.
	# Safety net: E/Esc still close even if the UI did not consume the event.
	if _mary_ui_open:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_on_mary_ui_closed()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif not _control_locked and event.is_action_pressed("flashlight_toggle"):
		toggle_flashlight()
	elif event.is_action_pressed("interact"):
		if _mary_ui_ignore_interact_frame:
			get_viewport().set_input_as_handled()
			return
		if interact_note and not _reading_open:
			_open_reading(interact_note)
		elif not _mary_puzzle_finished and interact_knife and not _knife_used and _stab_count < MAX_STABS:
			_use_knife()
		elif not _mary_puzzle_finished and interact_mary_note and _knife_used:
			_open_mary_ui()


# Registers input actions so the script works without any project setup.
func _setup_input_actions():
	var actions: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"flashlight_toggle": [KEY_F],
		"interact": [KEY_E],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var event: InputEventKey = InputEventKey.new()
				event.keycode = key
				InputMap.action_add_event(action, event)


func toggle_flashlight():
	_flashlight_on = not _flashlight_on
	if flashlight:
		flashlight.visible = _flashlight_on
		if not _flashlight_on:
			# Halt the flicker event but keep the current smoothed brightness.
			# It stays hidden while off, then eases back to its target on the
			# next turn-on instead of snapping.
			_flicker_event_active = false
			_flashlight_flicker_started = false
			_flashlight_target_energy = _flashlight_current_energy
		if flashlight_audio:
			_flashlight_quiet_click = false
			flashlight_audio.volume_db = _flashlight_audio_base_volume
			flashlight_audio.play()


func is_flashlight_on() -> bool:
	return _flashlight_on


func set_interact_note(note: Node3D):
	if note == null or _reading_open:
		return
	interact_note = note
	_show_interact_prompt("[E] Read")


func clear_interact_note(note: Node3D):
	if interact_note != note:
		return
	interact_note = null
	if interact_prompt:
		interact_prompt.visible = false


func _open_reading(note: Node):
	if _reading_open:
		return
	var ui := _ensure_reading_ui()
	if ui == null:
		return
	var title := ""
	var body := ""
	if note:
		title = str(note.get("note_title"))
		body = str(note.get("note_text"))
	ui.show_note(title, body)
	if note_paper_audio:
		note_paper_audio.play()
	_reading_open = true
	if interact_prompt:
		interact_prompt.visible = false
	get_tree().paused = true


func _close_reading():
	if not _reading_open:
		return
	_reading_open = false
	if is_instance_valid(_reading_ui):
		_reading_ui.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if interact_note:
		_show_interact_prompt("[E] Read")


func _ensure_reading_ui() -> Control:
	if is_instance_valid(_reading_ui):
		return _reading_ui
	var scn: PackedScene = load(READING_UI_SCENE)
	if scn == null:
		return null
	var ui := scn.instantiate() as Control
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gameui := get_node_or_null("GameUI") as CanvasLayer
	if gameui:
		gameui.add_child(ui)
		var uishader := gameui.get_node_or_null("UIShader")
		if uishader:
			gameui.move_child(ui, uishader.get_index())
		if ui.has_signal("close_requested"):
			ui.close_requested.connect(_close_reading)
		_reading_ui = ui
		return ui
	return null


func _show_interact_prompt(text: String) -> void:
	if interact_prompt == null:
		return
	interact_prompt.text = text
	interact_prompt.visible = true


func _hide_interact_prompt() -> void:
	if interact_prompt:
		interact_prompt.visible = false


func set_interact_knife(knife: Node) -> void:
	if _mary_puzzle_finished:
		return
	interact_knife = knife
	if not _knife_used and _stab_count < MAX_STABS:
		_show_interact_prompt("[E] Cut")


func clear_interact_knife(knife: Node) -> void:
	if interact_knife == knife:
		interact_knife = null
		_hide_interact_prompt()


func set_interact_mary_note(note: Node) -> void:
	if _mary_puzzle_finished:
		return
	interact_mary_note = note
	# Area3D signals (e.g. bloodmessage) only register the note; they can never
	# open the paper themselves, and must not show a new prompt during the
	# reopen guard window after a close.
	if _mary_ui_open or _mary_ui_ignore_interact_frame or Time.get_ticks_msec() - _mary_ui_close_time_msec < MARY_UI_REOPEN_DELAY_MSEC:
		return
	if _writing_locked:
		return
	if _knife_used:
		_show_interact_prompt("[E] Write")


func clear_interact_mary_note(note: Node) -> void:
	if interact_mary_note == note:
		interact_mary_note = null
		_hide_interact_prompt()


func _open_mary_ui() -> void:
	if _mary_puzzle_finished or _writing_locked or not _knife_used or _mary_ui_open:
		return
	if _mary_ui_ignore_interact_frame or Time.get_ticks_msec() - _mary_ui_close_time_msec < MARY_UI_REOPEN_DELAY_MSEC:
		return
	_ensure_mary_ui()
	if _mary_ui == null:
		return
	_mary_ui_open = true
	# The paper and its CanvasLayer must keep processing while the tree is paused.
	if is_instance_valid(_mary_ui_canvas):
		_mary_ui_canvas_mode = _mary_ui_canvas.process_mode
		_mary_ui_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	_mary_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	# MAX_STABS is the single source of truth for both cuts and attempts.
	_mary_ui.show_ui(MAX_STABS - _stab_count)
	get_tree().paused = true
	_hide_interact_prompt()


func _ensure_mary_ui() -> void:
	if _mary_ui:
		return
	var scene := load(MARY_UI_SCENE) as PackedScene
	if not scene:
		return
	_mary_ui = scene.instantiate() as Control
	_mary_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var game_ui := get_node_or_null("GameUI") as CanvasLayer
	if game_ui:
		_mary_ui_canvas = game_ui
		_mary_ui_canvas_mode = game_ui.process_mode
		game_ui.add_child(_mary_ui)
	_mary_ui.name_correct.connect(_on_mary_name_correct)
	_mary_ui.name_wrong.connect(_on_mary_name_wrong)
	_mary_ui.closed.connect(_on_mary_ui_closed)
	if not _mary_ui.visibility_changed.is_connected(_on_mary_ui_visibility_changed):
		_mary_ui.visibility_changed.connect(_on_mary_ui_visibility_changed)


func _on_mary_name_correct() -> void:
	if _mary_puzzle_finished:
		return
	_mark_mary_ui_closed()
	_mary_puzzle_finished = true
	get_tree().paused = false
	_mary_ui_open = false
	if is_instance_valid(_mary_ui):
		_mary_ui.hide_ui()
	_restore_mary_canvas_mode()

	# Controls, knife and writing stay locked for the rest of this scene.
	_control_locked = true
	_writing_locked = true
	_knife_used = true
	interact_knife = null
	interact_mary_note = null
	_hide_interact_prompt()

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return

	_begin_ending_fade(2.0)
	_fade_out_ambient_audio(2.0)
	var door_audio := _play_door_sound()

	await get_tree().create_timer(2.0).timeout
	if not is_instance_valid(self):
		return
	if door_audio and door_audio.playing:
		await door_audio.finished
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(self):
		get_tree().change_scene_to_file(MARY_ENDING_SCENE)


func _begin_ending_fade(duration: float) -> CanvasLayer:
	var cl := CanvasLayer.new()
	cl.name = "MaryEndingFade"
	cl.layer = 200
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	var rect := ColorRect.new()
	rect.name = "MaryEndingFadeRect"
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(rect)
	var tw := cl.create_tween()
	tw.tween_property(rect, "color:a", 1.0, duration)
	return cl


func _play_door_sound() -> AudioStreamPlayer:
	for path in DOOR_SOUND_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			continue
		var audio := AudioStreamPlayer.new()
		audio.name = "MaryDoorSound"
		audio.stream = stream
		audio.volume_db = -4.0
		audio.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(audio)
		audio.play()
		return audio
	return null


func _fade_out_ambient_audio(duration: float) -> void:
	var players: Array[Node] = []
	for node in get_tree().get_nodes_in_group("bg_music"):
		if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
			if not players.has(node):
				players.append(node)
	var scene := get_tree().current_scene
	if scene:
		_collect_ambient_audio(scene, players)
	for player in players:
		var tw := player.create_tween()
		tw.tween_property(player, "volume_db", -80.0, duration)


func _collect_ambient_audio(node: Node, players: Array[Node]) -> void:
	for child in node.get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D or child is AudioStreamPlayer3D:
			var label := String(child.name).to_lower()
			if "music" in label or "ambian" in label or "ambient" in label or "theme" in label or "hum" in label:
				if not players.has(child):
					players.append(child)
		_collect_ambient_audio(child, players)


func _on_mary_name_wrong() -> void:
	_mark_mary_ui_closed()
	get_tree().paused = false
	_mary_ui_open = false
	if is_instance_valid(_mary_ui):
		_mary_ui.hide_ui()
	_restore_mary_canvas_mode()
	_knife_used = false
	_writing_locked = true
	if _stab_count >= MAX_STABS:
		_die_from_mary_failure()
		return
	# A failed attempt ends here; the knife prompt offers the next cut.
	if interact_knife:
		_show_interact_prompt("[E] Cut")


func _on_mary_ui_closed() -> void:
	_mark_mary_ui_closed()
	get_tree().paused = false
	_mary_ui_open = false
	if is_instance_valid(_mary_ui):
		_mary_ui.hide_ui()
	_restore_mary_canvas_mode()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_show_mary_prompt_after_close()


# Safety net: hiding the paper from anywhere also clears the controller's open
# flag, so _mary_ui_open can never stay true while the UI is gone.
func _on_mary_ui_visibility_changed() -> void:
	if _mary_ui_open and is_instance_valid(_mary_ui) and not _mary_ui.visible:
		_on_mary_ui_closed()


# A timestamp (not a Timer) is used because the tree may still be paused here.
func _mark_mary_ui_closed() -> void:
	_mary_ui_close_time_msec = Time.get_ticks_msec()
	_mary_ui_ignore_interact_frame = true
	var close_time := _mary_ui_close_time_msec
	await get_tree().process_frame
	if _mary_ui_close_time_msec == close_time:
		_mary_ui_ignore_interact_frame = false


func _restore_mary_canvas_mode() -> void:
	if is_instance_valid(_mary_ui_canvas):
		_mary_ui_canvas.process_mode = _mary_ui_canvas_mode
	_mary_ui_canvas = null
	_mary_ui_canvas_mode = Node.PROCESS_MODE_INHERIT


# Closing never spends a cut or counts as a wrong attempt.
func _show_mary_prompt_after_close() -> void:
	if _mary_puzzle_finished:
		return
	if _writing_locked and _stab_count < MAX_STABS and interact_knife:
		_show_interact_prompt("[E] Cut")
	elif not _writing_locked and _knife_used and interact_mary_note:
		_show_interact_prompt("[E] Write")
	else:
		_hide_interact_prompt()


# One cut buys exactly one writing attempt.
func _use_knife() -> void:
	if _mary_puzzle_finished:
		return
	_stab_count += 1
	_knife_used = true
	_writing_locked = false
	_play_cut_sound()
	_flash_blood_vignette()
	_flash_cut_red()
	_small_camera_shake()
	if interact_mary_note:
		_show_interact_prompt("[E] Write")
	else:
		_hide_interact_prompt()


func _play_cut_sound() -> void:
	var path := CUT_SOUND_FALLBACK
	if is_instance_valid(interact_knife):
		var exported_path = interact_knife.get("stab_sound_path")
		if typeof(exported_path) == TYPE_STRING and not String(exported_path).is_empty():
			path = String(exported_path)
	var stream := load(path) as AudioStream
	if stream == null:
		return
	var audio := AudioStreamPlayer.new()
	audio.stream = stream
	audio.volume_db = -5.0
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _flash_cut_red() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 16
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.75, 0.0, 0.0, 0.35)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.14)
	tw.tween_callback(cl.queue_free)


func _small_camera_shake() -> void:
	if camera == null:
		return
	_camera_rest_rotation = camera.rotation
	_shake_trauma = 0.35
	_shake_time = 0.0


func _die_from_mary_failure() -> void:
	if _death_active:
		return
	_control_locked = true
	_play_cut_sound()
	_flash_blood_vignette()
	_flash_cut_red()
	_small_camera_shake()
	Fade.to_black(self, func():
		get_tree().paused = false
		GameState.lives = GameState.max_lives
		get_tree().change_scene_to_file(MARY_RESTART_SCENE)
	)


func _flash_blood_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 15
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.6, 0.0, 0.0, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(rect)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.45, 0.1)
	tw.tween_property(rect, "color:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)


func _notification(what: int):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float):
	_update_flashlight_flicker(delta)


# Wear-out model for the flashlight. The usage counter only advances while the
# light is actually on; being off pauses it, and only a full recovery_off_time
# away resets it. Energy is always eased toward a target so no flicker or
# recovery ever snaps on/off.
func _update_flashlight_flicker(delta: float):
	if flashlight == null:
		return

	var light_on := _flashlight_on and flashlight.visible
	if not light_on:
		_flashlight_off_time += delta
		_flashlight_flicker_started = false
		_flicker_event_active = false
		# Hold the current brightness while hidden. Turning it back on will
		# ease toward the appropriate target rather than jumping.
		_flashlight_target_energy = _flashlight_current_energy
		if _flashlight_off_time >= recovery_off_time:
			_flashlight_off_time = recovery_off_time
			if _flashlight_usage_time > 0.0:
				_flashlight_usage_time = 0.0
				_flashlight_recovery_pending = true
			# Range returns exactly to its original value once recovered.
			flashlight.spot_range = _flashlight_base_range
		return

	_flashlight_off_time = 0.0
	_flashlight_usage_time += delta
	if _flashlight_recovery_pending:
		_flashlight_recovery_pending = false
		_flashlight_recovery_time_left = FLICKER_FULL_RECOVERY_TIME

	_flashlight_target_energy = _get_flashlight_rest_energy()
	if _flashlight_usage_time >= flicker_start_time:
		_update_flicker_events(delta)
	else:
		_flashlight_flicker_started = false
		_flicker_event_active = false

	_smooth_flashlight_energy(delta)
	_update_flashlight_range()


# Resting brightness dims from 100% to (1 - base_dim_amount) over the first
# flicker_start_time seconds, then continues down to min_brightness at
# flicker_max_time.
func _get_flashlight_rest_energy() -> float:
	var factor: float
	if _flashlight_usage_time <= flicker_start_time:
		var t := clampf(_flashlight_usage_time / maxf(flicker_start_time, 0.001), 0.0, 1.0)
		factor = lerpf(1.0, 1.0 - base_dim_amount, t)
	else:
		var t := _get_flicker_progress()
		factor = lerpf(1.0 - base_dim_amount, min_brightness, t)
	return _flashlight_base_energy * clampf(factor, 0.0, 1.0)


func _get_flicker_progress() -> float:
	var span := maxf(flicker_max_time - flicker_start_time, 0.001)
	return clampf((_flashlight_usage_time - flicker_start_time) / span, 0.0, 1.0)


func _smooth_flashlight_energy(delta: float):
	if _flashlight_recovery_time_left > 0.0:
		_flashlight_recovery_time_left = maxf(0.0, _flashlight_recovery_time_left - delta)

	# When the target changes, size the move speed so that transition takes the
	# intended fade time regardless of how deep the dip is. This keeps even the
	# smallest 15% dip visible instead of snapping.
	var target_epsilon := maxf(_flashlight_base_energy * 0.002, 0.0001)
	if absf(_flashlight_target_energy - _flashlight_fade_target) > target_epsilon:
		_flashlight_fade_target = _flashlight_target_energy
		var fade_time := FLICKER_RECOVER_FADE_TIME
		if _flashlight_target_energy < _flashlight_current_energy:
			fade_time = FLICKER_DIP_FADE_TIME
		elif _flashlight_recovery_time_left > 0.0:
			fade_time = FLICKER_FULL_RECOVERY_TIME
		var distance := absf(_flashlight_target_energy - _flashlight_current_energy)
		_flashlight_fade_speed = distance / maxf(fade_time, 0.001)

	_flashlight_current_energy = move_toward(
		_flashlight_current_energy,
		_flashlight_target_energy,
		_flashlight_fade_speed * delta
	)
	flashlight.light_energy = _flashlight_current_energy


func _update_flashlight_range():
	var wear := clampf(_flashlight_usage_time / maxf(flicker_max_time, 0.001), 0.0, 1.0)
	flashlight.spot_range = _flashlight_base_range * lerpf(1.0, 1.0 - FLICKER_RANGE_DIM, wear)


func _update_flicker_events(delta: float):
	var progress := _get_flicker_progress()
	var rest_energy := _flashlight_target_energy

	if not _flashlight_flicker_started:
		_flashlight_flicker_started = true
		_flicker_event_active = false
		_schedule_next_flicker(progress)
		return

	if _flicker_event_active:
		_flicker_step_time -= delta
		if _flicker_step_time <= 0.0:
			if _flicker_step_is_dip:
				_flicker_step_is_dip = false
				_flicker_step_time = FLICKER_RECOVER_FADE_TIME + randf_range(0.0, 0.08)
			elif _flicker_steps_remaining > 0:
				_begin_flicker_dip(progress, rest_energy)
			else:
				_flicker_event_active = false
				_schedule_next_flicker(progress)

		if _flicker_event_active and _flicker_step_is_dip:
			_flashlight_target_energy = _flicker_dip_target_energy
		return

	_flicker_next_time -= delta
	if _flicker_next_time <= 0.0:
		_start_flicker_event(progress, rest_energy)
		if _flicker_event_active and _flicker_step_is_dip:
			_flashlight_target_energy = _flicker_dip_target_energy


func _schedule_next_flicker(progress: float):
	var interval := lerpf(FLICKER_INTERVAL_START, FLICKER_INTERVAL_END, progress)
	var jitter := interval * FLICKER_INTERVAL_JITTER
	_flicker_next_time = randf_range(interval - jitter, interval + jitter)


# Each event is a short burst of 1-3 small dips separated by smooth recoveries.
func _start_flicker_event(progress: float, rest_energy: float):
	_flicker_event_active = true
	_flicker_steps_remaining = randi_range(1, 3)
	_flicker_clicked_this_event = false
	_begin_flicker_dip(progress, rest_energy)


func _begin_flicker_dip(progress: float, rest_energy: float):
	_flicker_steps_remaining -= 1
	_flicker_step_is_dip = true
	# Give the smooth fade a beat to reach the dip before easing back out.
	_flicker_step_time = FLICKER_DIP_FADE_TIME + randf_range(0.02, 0.05)
	_flicker_dip_target_energy = _pick_flicker_dip_target(progress, rest_energy)
	_flashlight_target_energy = _flicker_dip_target_energy

	# Only the deeper dips click, and at most once per burst.
	if not _flicker_clicked_this_event and _flicker_dip_target_energy < rest_energy * 0.85:
		_flicker_clicked_this_event = true
		if randf() < FLICKER_CLICK_CHANCE:
			_play_flicker_click()


# Gentle dips go from 85% of the current resting level down to 40% as wear
# progresses. Only after 270s can a rare, much deeper dim occur, and even that
# stays at 8-15% instead of switching fully off.
func _pick_flicker_dip_target(progress: float, rest_energy: float) -> float:
	if _flashlight_usage_time >= FLICKER_CUTOUT_START_TIME and randf() < FLICKER_CUTOUT_CHANCE:
		return _flashlight_base_energy * randf_range(0.08, 0.15)

	var dip_scale := lerpf(0.85, 0.40, progress) + randf_range(-0.03, 0.03)
	return rest_energy * clampf(dip_scale, 0.35, 0.92)


func _play_flicker_click():
	if flashlight_audio == null or flashlight_audio.stream == null:
		return
	if flashlight_audio.playing:
		return
	_flashlight_quiet_click = true
	flashlight_audio.volume_db = FLICKER_CLICK_VOLUME_DB
	flashlight_audio.play()


func _on_flashlight_audio_finished():
	if not _flashlight_quiet_click:
		return
	_flashlight_quiet_click = false
	if flashlight_audio:
		flashlight_audio.volume_db = _flashlight_audio_base_volume


func _physics_process(delta: float):
	if _death_active:
		return
	_apply_gravity(delta)

	var input_dir: Vector2 = _get_input_dir()
	var wish_dir: Vector3 = _get_wish_direction(input_dir)
	var target_speed: float = _get_target_speed(input_dir)

	var was_running := target_speed == run_speed
	_update_stamina(delta, was_running)
	if was_running and current_stamina <= 0.0:
		target_speed = walk_speed if input_dir.length_squared() > 0 else 0.0

	_accelerate(wish_dir, target_speed, delta)
	move_and_slide()

	# landing detection — a small dip when touching ground after being airborne
	var now_on_floor: bool = is_on_floor()
	if not _was_on_floor and now_on_floor:
		_landing_bounce = 1.0
	_was_on_floor = now_on_floor

	var h_speed: float = Vector3(velocity.x, 0, velocity.z).length()

	_update_noise(h_speed)
	_update_head_bob(h_speed, delta)
	_update_lean(input_dir, delta)
	_update_footsteps(h_speed, delta)
	_update_breathing(h_speed, delta)
	_update_shake(delta)
	_update_heartbeat(delta)
	_update_scare_director(delta)


func _apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float * delta


func _get_input_dir() -> Vector2:
	if _control_locked or _ritual_locked or _mary_ui_open:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


# Converts 2D input into a world-space direction relative to the body's facing.
func _get_wish_direction(input_dir: Vector2) -> Vector3:
	var raw: Vector3 = Vector3(input_dir.x, 0, input_dir.y)
	if raw.length_squared() > 0:
		raw = raw.normalized()
	return transform.basis * raw


func _get_target_speed(input_dir: Vector2) -> float:
	if input_dir.length_squared() == 0:
		return 0.0
	var sprint_pressed := Input.is_action_pressed("sprint")
	if sprint_pressed and not _stamina_locked:
		return run_speed
	return walk_speed


func _update_stamina(delta: float, is_running: bool):
	if is_running and current_stamina > 0.0:
		current_stamina = max(0.0, current_stamina - stamina_drain_rate * delta)
		if current_stamina <= 0.0:
			_stamina_locked = true
	else:
		current_stamina = min(max_stamina, current_stamina + stamina_recover_rate * delta)
		if _stamina_locked and current_stamina >= max_stamina * (stamina_recover_threshold / 100.0):
			_stamina_locked = false
	stamina_changed.emit(current_stamina, max_stamina)


# Locks horizontal movement only — mouse look stays enabled so the player
# can watch the monster approach during the ritual.
func set_ritual_locked(locked: bool):
	_ritual_locked = locked


func get_stamina_ratio() -> float:
	return current_stamina / max_stamina


# Accelerates/decelerates horizontal velocity toward the target using an
# exponential response instead of a constant-slope ramp. A constant slope
# (move_toward at a fixed rate) is what makes movement read as "vehicle" —
# it's literally fixed engine force. Exponential response reacts fast up
# front and eases into the target, which is closer to how a body moves.
# turn_boost additionally makes sharp direction changes (redirect/stop-and-go)
# snap faster than a straight speed-up, like a human planting a foot,
# instead of carrying momentum through a wide arc like a car.
func _accelerate(wish_dir: Vector3, target_speed: float, delta: float):
	var target_h: Vector3 = wish_dir * target_speed
	var current_h: Vector3 = Vector3(velocity.x, 0, velocity.z)

	var turn_factor: float = 1.0
	if current_h.length() > 0.3 and wish_dir.length_squared() > 0.0:
		var alignment: float = current_h.normalized().dot(wish_dir)
		# alignment ~1 = same direction (no boost), alignment ~ -1 = reversal (max boost)
		turn_factor = lerp(turn_boost, 1.0, clamp((alignment + 1.0) * 0.5, 0.0, 1.0))

	var base_rate: float = acceleration if target_speed > 0 else deceleration
	var rate: float = base_rate * turn_factor

	var t: float = 1.0 - exp(-rate * delta)
	var result: Vector3 = current_h.lerp(target_h, t)
	velocity.x = result.x
	velocity.z = result.z


func _update_noise(h_speed: float):
	var new_noise: float = 0.0
	if h_speed > 0.1:
		new_noise = 8.0 if h_speed > walk_speed * 0.8 else 3.0

	if new_noise != _previous_noise:
		_previous_noise = new_noise
		noise_changed.emit(new_noise)


# Head bob on CameraPivot's local position using a figure-8 pattern:
# vertical bounce at full frequency, horizontal sway at half frequency
# (side-to-side shifts once per two steps). Frequency blends between
# walk/run. _bob_weight fades the bob in/out smoothly so it never snaps.
# A landing dip is layered on top when the player touches down from a fall.
func _update_head_bob(h_speed: float, delta: float):
	var should_bob: bool = is_on_floor() and h_speed > 0.1
	_bob_weight = move_toward(_bob_weight, 1.0 if should_bob else 0.0, delta * 10.0)

	if should_bob:
		var t: float = clamp((h_speed - walk_speed) / (run_speed - walk_speed), 0.0, 1.0)
		var freq: float = lerp(bob_frequency_walk, bob_frequency_run, t)
		_bob_time += freq * delta

	var offset: Vector3 = Vector3.ZERO
	if _bob_weight > 0.001:
		var amp: float = bob_amplitude * _bob_weight
		offset.y = sin(_bob_time) * amp
		offset.x = sin(_bob_time * 0.5) * amp * 0.35

	_landing_bounce = move_toward(_landing_bounce, 0.0, landing_bounce_speed * delta)
	offset.y -= _landing_bounce * landing_bounce_strength

	camera_pivot.position = _pivot_initial_pos + offset


# Subtle camera roll while strafing — a human leans into a sideways step,
# a car doesn't. Purely cosmetic, applied on CameraPivot so it never
# fights with the scream-shake system (which drives `camera` directly).
func _update_lean(input_dir: Vector2, delta: float):
	var target_lean: float = 0.0
	if not _control_locked and not _ritual_locked:
		target_lean = -input_dir.x * deg_to_rad(lean_angle)
	_lean_current = lerp(_lean_current, target_lean, clamp(lean_speed * delta, 0.0, 1.0))
	camera_pivot.rotation.z = _lean_current


# Smoothly adjusts footstep volume and pitch based on movement speed.
func _update_footsteps(h_speed: float, delta: float):
	var target_vol: float = footstep_volume_idle
	var target_pitch: float = footstep_pitch_idle
	if is_on_floor() and h_speed > 0.01:
		if h_speed <= walk_speed:
			var t: float = h_speed / walk_speed
			target_vol = lerp(footstep_volume_idle, footstep_volume_walk, t)
		else:
			var t: float = (h_speed - walk_speed) / (run_speed - walk_speed)
			target_vol = lerp(footstep_volume_walk, footstep_volume_run, t)
		var blend: float = clamp(h_speed / run_speed, 0.0, 1.0)
		target_pitch = lerp(footstep_pitch_idle, footstep_pitch_run, blend)
	footstep_player.volume_db = move_toward(footstep_player.volume_db, target_vol, footstep_blend_speed * delta)
	footstep_player.pitch_scale = move_toward(footstep_player.pitch_scale, target_pitch, footstep_blend_speed * delta)


# Smoothly adjusts breathing volume and pitch via smoothed intensity.
func _update_breathing(h_speed: float, delta: float):
	var target_intensity: float = clamp(h_speed / run_speed, 0.0, 1.0)
	_breath_intensity = move_toward(_breath_intensity, target_intensity, breath_blend_speed * delta)
	breath_audio.volume_db = lerp(breath_volume_idle, breath_volume_run, _breath_intensity)
	breath_audio.pitch_scale = lerp(breath_pitch_idle, breath_pitch_run, _breath_intensity)


func trigger_scream_shake():
	_camera_rest_rotation = camera.rotation
	_shake_trauma = 1.0
	_shake_time = 0.0
	_fov_trauma = 1.0


func _update_shake(delta: float):
	if _fov_trauma > 0.0:
		var fov_amount := _fov_trauma * _fov_trauma
		camera.fov = _fov_default + scream_fov_increase * fov_amount
		_fov_trauma = move_toward(_fov_trauma, 0.0, scream_fov_decay * delta)
	elif not is_equal_approx(camera.fov, _fov_default):
		camera.fov = move_toward(camera.fov, _fov_default, scream_fov_decay * delta * 2.0)

	if _shake_trauma <= 0.0:
		return

	var kick_trauma = _shake_trauma

	_shake_time += delta
	_shake_trauma = move_toward(_shake_trauma, 0.0, scream_shake_decay * delta)

	var amount = _shake_trauma * _shake_trauma * scream_shake_strength

	var kick_scale = kick_trauma * kick_trauma
	var kick := Vector3(
		deg_to_rad(scream_kick_pitch) * kick_scale,
		deg_to_rad(scream_kick_yaw) * kick_scale,
		deg_to_rad(scream_kick_roll) * kick_scale
	)

	if amount < 0.0001 and kick_scale < 0.0001:
		camera.rotation = _camera_rest_rotation
		camera.position = Vector3.ZERO
		_shake_trauma = 0.0
		return

	var freq = scream_shake_frequency
	var rot_offset := Vector3(
		(cos(_shake_time * freq) * 0.7 + sin(_shake_time * freq * 1.3) * 0.3) * amount,
		sin(_shake_time * freq * 1.1) * amount * 0.5,
		sin(_shake_time * freq * 0.9) * amount * 0.3
	)
	var pos_offset := Vector3(
		sin(_shake_time * freq * 1.7) * amount * 0.015,
		cos(_shake_time * freq * 0.5) * amount * 0.01,
		sin(_shake_time * freq * 0.8) * amount * 0.01
	)

	camera.rotation = _camera_rest_rotation + rot_offset + kick
	camera.position = pos_offset


func trigger_damage_effect():
	if _control_locked:
		return
	_control_locked = true
	_shake_trauma = 1.0
	_shake_time = 0.0
	_fov_trauma = 1.0
	_camera_rest_rotation = camera.rotation

	var cl := CanvasLayer.new()
	cl.name = "DamageLayer"
	cl.layer = 10
	add_child(cl)
	var cr := ColorRect.new()
	cr.name = "DamageOverlay"
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = Color(0, 0, 0, 0)
	cl.add_child(cr)
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	cr.color = damage_flash_color
	var tw := create_tween()
	tw.tween_property(cr, "color", Color(damage_flash_color.r, damage_flash_color.g, damage_flash_color.b, 0.0), damage_effect_duration)
	tw.tween_callback(func():
		if is_instance_valid(cl):
			cl.queue_free()
		if not _death_active:
			_control_locked = false
		damage_completed.emit()
	)


# Detaches the active camera into a self-cleaning death rig that jerks the head
# back, tumbles it to the floor and screams. Returns the rig, or null if the
# camera could not be detached. The rig snapshots the current view transform and
# later reattaches the camera to CameraPivot before respawn.
func begin_death_sequence(kill_dir: Vector3 = Vector3.FORWARD) -> DeathCam:
	if _death_active:
		return null
	var world := get_tree().current_scene
	if camera == null or camera.get_parent() == null or world == null:
		return null

	_control_locked = true
	_death_active = true

	# chase_ended has already dropped the heartbeat target, but the player stops
	# ticking its audio updates while _death_active is set. Stop it outright so
	# the heartbeat cannot keep playing through the death hold.
	_heartbeat_active = false
	_heartbeat_target_vol = -80.0
	_monster_ref = null
	if _heartbeat_player and _heartbeat_player.playing:
		_heartbeat_player.stop()

	var rig := DeathCam.new()
	rig.name = "DeathCamRig"
	rig.process_mode = Node.PROCESS_MODE_ALWAYS

	var cam_transform := camera.global_transform
	camera.get_parent().remove_child(camera)
	rig.add_child(camera)
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	rig.transform = cam_transform

	rig.setup(camera, kill_dir)
	world.add_child(rig)

	_death_rig = rig
	return rig


# Restores the player to its original spawn transform and resets all camera,
# audio and stamina state so gameplay can resume without reloading the scene.
func respawn():
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_control_locked = false
	_death_active = false
	_death_rig = null
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	camera_pivot.rotation = Vector3.ZERO
	camera_pivot.position = _pivot_initial_pos

	# Safety net: if the death rig could not reattach the camera, bring it home
	# here so the view is always restored before gameplay resumes.
	if camera and camera.get_parent() != camera_pivot:
		if camera.get_parent():
			camera.get_parent().remove_child(camera)
		camera_pivot.add_child(camera)
	camera.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	camera.fov = _fov_default
	camera.current = true
	_shake_trauma = 0.0
	_fov_trauma = 0.0
	_shake_time = 0.0
	_camera_rest_rotation = Vector3.ZERO

	_flashlight_on = true
	if flashlight:
		flashlight.visible = true

	_bob_time = 0.0
	_bob_weight = 0.0
	_previous_noise = -1.0
	_breath_intensity = 0.0
	_scare_elapsed = 0.0
	_scare_timer = _next_scare_wait()
	_lean_current = 0.0
	_landing_bounce = 0.0
	_was_on_floor = true

	current_stamina = max_stamina
	_stamina_locked = false
	stamina_changed.emit(current_stamina, max_stamina)

	_heartbeat_active = false
	_monster_ref = null
	_heartbeat_target_vol = -80.0
	if _heartbeat_player and _heartbeat_player.playing:
		_heartbeat_player.stop()

func start_heartbeat(monster_node: Node3D):
	if _heartbeat_active:
		return
	_monster_ref = monster_node
	_heartbeat_active = true
	_heartbeat_target_vol = HEARTBEAT_VOLUME_FAR
	_heartbeat_target_pitch = HEARTBEAT_PITCH_FAR
	if not _heartbeat_player.playing:
		_heartbeat_player.play()


func stop_heartbeat():
	if not _heartbeat_active:
		return
	_heartbeat_active = false
	_heartbeat_target_vol = -80.0
	_monster_ref = null


func _on_heartbeat_finished():
	if _heartbeat_active:
		_heartbeat_player.play()


func _update_heartbeat(delta: float):
	if _heartbeat_active and _monster_ref:
		var monster_pos: Vector3 = _monster_ref.global_position
		var dist: float = global_position.distance_to(monster_pos)
		var t: float = clamp(1.0 - dist / 25.0, 0.0, 1.0)
		_heartbeat_target_pitch = lerp(HEARTBEAT_PITCH_FAR, HEARTBEAT_PITCH_CLOSE, t)
		if dist < 8.0:
			var extra: float = pow(1.0 - dist / 8.0, 2.0) * 0.2
			t = min(1.0, t + extra)
		_heartbeat_target_vol = lerp(HEARTBEAT_VOLUME_FAR, HEARTBEAT_VOLUME_CLOSE, t)

	var current_vol := _heartbeat_player.volume_db
	if not is_equal_approx(current_vol, _heartbeat_target_vol):
		var fade_speed: float
		if not _heartbeat_active:
			fade_speed = HEARTBEAT_FADEOUT_SPEED
		elif _heartbeat_target_vol > current_vol:
			fade_speed = HEARTBEAT_ATTACK_SPEED
		else:
			fade_speed = HEARTBEAT_RELEASE_SPEED
		_heartbeat_player.volume_db = move_toward(current_vol, _heartbeat_target_vol, fade_speed * delta)

	var current_pitch := _heartbeat_player.pitch_scale
	if not is_equal_approx(current_pitch, _heartbeat_target_pitch):
		_heartbeat_player.pitch_scale = move_toward(current_pitch, _heartbeat_target_pitch, HEARTBEAT_PITCH_SPEED * delta)

	if not _heartbeat_active and _heartbeat_player.volume_db <= -79.0 and _heartbeat_player.playing:
		_heartbeat_player.stop()


# ---------------------------------------------------------------------------
# Fake ambient scare director
# ---------------------------------------------------------------------------

func _setup_scare_director():
	_discover_scare_players()
	_scare_enabled = not _scare_players.is_empty()
	if _scare_enabled:
		_scare_timer = _next_scare_wait()


# Collects every AudioStreamPlayer3D child of the player that belongs to the
# fake ambience. Functional sounds (footsteps, breathing, heartbeat, ritual
# hum, monster audio) are skipped by name; every other 3D player is fair game.
# Each sound is tagged with its tier, derived from the trailing number in its
# node name (horror1 -> tier 1), so higher-tier sounds can be gated behind
# book progression.
func _discover_scare_players():
	_scare_players.clear()
	_scare_tiers.clear()
	for child in find_children("*", "AudioStreamPlayer3D", true, false):
		if SCARE_IGNORED_NAMES.has(child.name):
			continue
		_scare_players.append(child)
		_scare_tiers.append(_scare_tier_of(child.name))


func _scare_tier_of(name: String) -> int:
	var i := name.length() - 1
	while i >= 0 and name[i].is_valid_int():
		i -= 1
	var digits := name.substr(i + 1)
	if digits.is_empty():
		return 1
	return digits.to_int()


func _update_scare_director(delta: float):
	if not _scare_enabled:
		return
	_scare_elapsed += delta
	_scare_timer -= delta
	if _scare_timer <= 0.0:
		if randf() < SCARE_ATTEMPT_CHANCE:
			_try_play_scare()
		_scare_timer = _next_scare_wait()


func _try_play_scare():
	if _scare_elapsed < SCARE_QUIET_TIME:
		return
	if _real_danger_active():
		return
	for p in _scare_players:
		if p.playing:
			return
	var idx := _pick_scare_index()
	if idx < 0:
		return
	_play_scare_at(idx)


func _play_scare_at(idx: int):
	var player := _scare_players[idx] as AudioStreamPlayer3D
	player.volume_db = randf_range(-4.0, 2.0)
	player.pitch_scale = randf_range(0.95, 1.05)
	player.global_position = _fresh_scare_position()
	player.play()
	_scare_last_index = idx


# Places the sound around the player along a random cardinal direction at a
# fresh 4-7 m distance with a small sideways jitter. Y never moves and each
# playback starts from a clean position.
func _fresh_scare_position() -> Vector3:
	var dir: Vector3
	var jitter_axis: Vector3
	match randi() % 4:
		0:
			dir = -transform.basis.z
			jitter_axis = transform.basis.x
		1:
			dir = transform.basis.z
			jitter_axis = transform.basis.x
		2:
			dir = transform.basis.x
			jitter_axis = transform.basis.z
		_:
			dir = -transform.basis.x
			jitter_axis = transform.basis.z
	var dist := randf_range(SCARE_MIN_DIST, SCARE_MAX_DIST)
	var offset: Vector3 = dir * dist + jitter_axis * randf_range(-SCARE_JITTER, SCARE_JITTER)
	offset.y = 0.0
	return global_position + offset


func _pick_scare_index() -> int:
	var allowed := _scare_allowed_tier()
	var candidates: Array = []
	for i in _scare_players.size():
		if _scare_tiers[i] > allowed:
			continue
		if i != _scare_last_index:
			candidates.append(i)
	if candidates.is_empty():
		for i in _scare_players.size():
			if _scare_tiers[i] <= allowed:
				candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]


func _next_scare_wait() -> float:
	var books := _current_book_count()
	if books >= 5:
		return randf_range(25.0, 50.0)
	if books >= 3:
		return randf_range(40.0, 70.0)
	return randf_range(50.0, 90.0)


func _scare_allowed_tier() -> int:
	var books := _current_book_count()
	if books >= 5:
		return 3
	if books >= 3:
		return 2
	return 1


# Lets the real monster take the stage: no fake scares while it is hunting or
# close enough to be the actual threat. Playback is simply skipped/rescheduled.
func _real_danger_active() -> bool:
	var monster := _find_monster()
	if not monster:
		return false
	if int(monster.get("current_state")) == SCARE_HUNTING_STATE:
		return true
	return global_position.distance_to(monster.global_position) < SCARE_DANGER_DISTANCE


func _find_monster() -> Node3D:
	if not is_instance_valid(_scare_monster):
		_scare_monster = null
		var root := get_tree().current_scene
		if root:
			_scare_monster = root.get_node_or_null("Monster") as Node3D
	return _scare_monster


func _current_book_count() -> int:
	var manager := get_tree().current_scene
	if manager and "total_books" in manager:
		return int(manager.get("_books_collected"))
	return 0
