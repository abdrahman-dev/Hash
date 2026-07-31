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
@export var stamina_recover_rate: float = 12.0
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

# --- humanizing movement feel ---
@export var lean_angle: float = 4.0        # degrees of camera roll while strafing
@export var lean_speed: float = 9.0        # how fast the lean eases in/out
@export var landing_bounce_strength: float = 0.06
@export var landing_bounce_speed: float = 9.0

var current_stamina: float = 100.0

var camera_pivot: Node3D
var camera: Camera3D
var footstep_player: AudioStreamPlayer3D
var breath_audio: AudioStreamPlayer3D

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
	if _control_locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		camera_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-80), deg_to_rad(80))


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# Registers input actions so the script works without any project setup.
func _setup_input_actions():
	var actions: Dictionary = {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in actions[action]:
				var event: InputEventKey = InputEventKey.new()
				event.keycode = key
				InputMap.action_add_event(action, event)


func _notification(what: int):
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(delta: float):
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
	if _control_locked or _ritual_locked:
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
		_control_locked = false
		damage_completed.emit()
	)


# Restores the player to its original spawn transform and resets all camera,
# audio and stamina state so gameplay can resume without reloading the scene.
func respawn():
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_control_locked = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	camera_pivot.rotation = Vector3.ZERO
	camera_pivot.position = _pivot_initial_pos
	camera.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO
	camera.fov = _fov_default
	_shake_trauma = 0.0
	_fov_trauma = 0.0
	_shake_time = 0.0
	_camera_rest_rotation = Vector3.ZERO

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
