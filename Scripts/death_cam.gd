class_name DeathCam
extends Node3D


# Detached death camera. While the tree is paused this rig still runs because
# it is forced to PROCESS_MODE_ALWAYS; the camera is reparented into it so the
# severed-head viewpoint keeps falling and tumbling even after _show_death_screen
# pauses the scene.
#
# Phase timeline (from the moment the monster catches the player):
#   HOLD     the scream + shock flash land while the head stays put for a beat
#   IMPULSE  violent separation: jerk up/back with a fast rotation
#   FALL     ballistic tumble with gravity-like acceleration
#   IMPACT   floor hit, small bounce, light residual shake
#   REST     a short post-death hold at the final pose before YOU DIED
signal sequence_done


const HOLD_DURATION := 0.4
const IMPULSE_DURATION := 0.45
const FALL_DURATION := 0.5
const IMPACT_DURATION := 0.45
const REST_DURATION := 0.7
const GRAVITY := 30.0
const FALL_DROP := 1.45
const IMPULSE_RISE := 0.55
const IMPULSE_PUSH := 0.4
const BOUNCE_VEL := 2.6
const FOV_KICK := 10.0
const FOV_RECOVER := 24.0
const SHAKE_START := 0.6
const SHAKE_DECAY := 2.5
const SHAKE_FREQ := 18.0
const WOB_FREQ := 13.0
const WOB_MAX := deg_to_rad(5.0)
const DEATH_SCREAM := "res://Sounds/deathscream.mp3"


var _camera: Camera3D
var _kill_dir := Vector3.FORWARD
var _done := false
var _phase := 0  # 0 hold, 1 impulse, 2 fall, 3 impact, 4 rest
var _time := 0.0
var _start_pos := Vector3.ZERO
var _pos := Vector3.ZERO
var _vel := Vector3.ZERO
var _start_rot := Vector3.ZERO
var _impulse_rot := Vector3.ZERO
var _fall_rot := Vector3.ZERO
var _impact_rot := Vector3.ZERO
var _rot_at_impact := Vector3.ZERO
var _fall_progress := 0.0
var _floor_y := 0.0
var _rest_fov := 75.0
var _shake := 0.0
var _rng := RandomNumberGenerator.new()

const IMPULSE_PITCH := -22.0
const IMPULSE_YAW := 8.0
const IMPULSE_ROLL := 70.0
const FALL_PITCH := 52.0
const FALL_YAW := 30.0
const FALL_ROLL := 128.0
const IMPACT_PITCH := 72.0
const IMPACT_YAW := 40.0
const IMPACT_ROLL := 150.0


func setup(cam: Camera3D, kill_dir: Vector3):
	_camera = cam
	_kill_dir = kill_dir.normalized() if kill_dir.length() > 0.001 else Vector3.FORWARD


func _ready():
	_rng.randomize()
	if _camera == null:
		return
	_start_pos = global_position
	_start_rot = rotation
	_rest_fov = _camera.fov
	_camera.fov = _rest_fov + FOV_KICK
	_floor_y = _start_pos.y - FALL_DROP
	_impulse_rot = _start_rot + Vector3(deg_to_rad(IMPULSE_PITCH), deg_to_rad(IMPULSE_YAW), deg_to_rad(IMPULSE_ROLL))
	_fall_rot = _start_rot + Vector3(deg_to_rad(FALL_PITCH), deg_to_rad(FALL_YAW), deg_to_rad(FALL_ROLL))
	_impact_rot = _start_rot + Vector3(deg_to_rad(IMPACT_PITCH), deg_to_rad(IMPACT_YAW), deg_to_rad(IMPACT_ROLL))
	_start_scream()


func _process(delta: float):
	if _done or _camera == null:
		return
	_time += delta

	if _phase == 0:
		# Hold: the scream and shock flash hit, the head stays put for a beat,
		# with a barely-there anticipatory tremble so it isn't a static frame.
		global_position = _start_pos
		rotation = _start_rot + Vector3(sin(_time * 8.0) * 0.0015, 0.0, sin(_time * 8.0 * 1.3) * 0.001)
		if _time >= HOLD_DURATION:
			_start_impulse()
	elif _phase == 1:
		var p := clampf(_time / IMPULSE_DURATION, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - p, 3.0)
		global_position = _start_pos + Vector3.UP * (IMPULSE_RISE * eased) + _kill_dir * (IMPULSE_PUSH * eased)
		rotation = _start_rot.lerp(_impulse_rot, eased)
		if p >= 1.0:
			_start_fall()
	elif _phase == 2:
		_vel.y -= GRAVITY * delta
		_vel.x *= 1.0 - 1.8 * delta
		_vel.z *= 1.0 - 1.8 * delta
		_pos += _vel * delta
		global_position = _pos

		_fall_progress = minf(_fall_progress + delta / FALL_DURATION, 1.0)
		var eased := _fall_progress * _fall_progress
		rotation = _impulse_rot.lerp(_fall_rot, eased)
		var wob := eased * WOB_MAX
		rotation.x += sin(_time * WOB_FREQ) * wob
		rotation.z += cos(_time * WOB_FREQ * 0.85) * wob
		if global_position.y <= _floor_y:
			_start_impact()
	elif _phase == 3:
		_vel.y -= GRAVITY * delta
		_vel.x *= 1.0 - 6.0 * delta
		_vel.z *= 1.0 - 6.0 * delta
		_pos += _vel * delta
		if _pos.y <= _floor_y:
			_pos.y = _floor_y
			if _vel.y < -0.5:
				_vel.y = BOUNCE_VEL
			else:
				_vel.y = 0.0
		global_position = _pos

		var impact_k := minf(_time / 0.15, 1.0)
		var impact_eased := 1.0 - pow(1.0 - impact_k, 2.0)
		rotation = _rot_at_impact.lerp(_impact_rot, impact_eased)
		_shake = maxf(0.0, _shake - SHAKE_DECAY * delta)
		var amount := _shake * _shake
		rotation += Vector3(
			sin(_time * SHAKE_FREQ * 0.9) * amount * 0.08,
			sin(_time * SHAKE_FREQ * 1.2) * amount * 0.05,
			sin(_time * SHAKE_FREQ * 0.75) * amount * 0.11
		)
		if _time >= IMPACT_DURATION:
			_start_rest()
	elif _phase == 4:
		global_position = _pos
		rotation = _impact_rot
		if _time >= REST_DURATION:
			_finish()

	_camera.fov = move_toward(_camera.fov, _rest_fov, FOV_RECOVER * delta)


func _start_impulse():
	_phase = 1
	_time = 0.0


func _start_fall():
	_phase = 2
	_pos = global_position
	_vel = Vector3(_kill_dir.x * 0.8, -1.0, _kill_dir.z * 0.8)
	_fall_progress = 0.0


func _start_impact():
	_phase = 3
	_time = 0.0
	_pos = global_position
	_pos.y = _floor_y
	global_position = _pos
	_vel = Vector3(0.0, BOUNCE_VEL, 0.0)
	_shake = SHAKE_START
	_rot_at_impact = rotation


func _start_rest():
	_phase = 4
	_time = 0.0
	_pos = global_position
	_pos.y = _floor_y
	global_position = _pos
	_vel = Vector3.ZERO


# Ends the animation but keeps the fallen pose attached: the death screen fades
# in over this frozen view, like a GTA death. The game_manager releases the
# camera just before respawn via release_camera().
func _finish():
	if _done:
		return
	_done = true
	sequence_done.emit()


# Restores the camera to its original pivot with default state so the player
# can respawn it cleanly. The scream is a sibling of this rig and outlives it.
func release_camera():
	if _camera == null:
		return
	var world := get_tree().current_scene
	if world == null:
		return
	var pivot := world.get_node_or_null("Player/CameraPivot") as Node3D
	if pivot == null:
		return
	if _camera.get_parent() != null:
		_camera.get_parent().remove_child(_camera)
	pivot.add_child(_camera)
	_camera.position = Vector3.ZERO
	_camera.rotation = Vector3.ZERO
	_camera.fov = _rest_fov
	_camera.current = true
	queue_free()


func _start_scream():
	var scream := AudioStreamPlayer.new()
	scream.name = "DeathScream"
	scream.stream = preload("res://Sounds/deathscream.mp3")
	scream.pitch_scale = _rng.randf_range(0.92, 1.08)
	scream.process_mode = Node.PROCESS_MODE_ALWAYS
	scream.finished.connect(scream.queue_free)
	get_parent().add_child(scream)
	scream.play()