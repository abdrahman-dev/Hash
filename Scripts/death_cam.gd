class_name DeathCam
extends Node3D


# Severed-head death camera. The player's camera is reparented into this rig so
# the viewpoint keeps falling and tumbling even after the death screen pauses
# the scene (the rig is forced to PROCESS_MODE_ALWAYS).
#
# Timeline from the moment the monster catches the player:
#   FALL    ~0.6s ease-in drop to 0.15m above the floor, rolling 70-90 degrees
#           and pitching slightly, like a head coming off
#   BOUNCE  small hop and settle on the floor
#   REST    lie on the floor for the rest of the ~2.5s floor hold
# The death screen (fade, lives, game over) is started by game_manager when
# sequence_done fires.
signal sequence_done


const FALL_DURATION := 0.6
const BOUNCE_DURATION := 0.35
const REST_DURATION := 2.15
const FLOOR_CLEARANCE := 0.15
const FALL_FORWARD := 0.2
const BOUNCE_HEIGHT := 0.07
const BOUNCE_ROLL := deg_to_rad(5.0)
const FALL_PITCH_DEG := 16.0
const FALL_YAW_DEG := 10.0
const MIN_ROLL_DEG := 70.0
const MAX_ROLL_DEG := 90.0


var _camera: Camera3D
var _kill_dir := Vector3.FORWARD
var _done := false
var _phase := 0  # 0 fall, 1 bounce, 2 rest
var _time := 0.0
var _start_pos := Vector3.ZERO
var _start_rot := Vector3.ZERO
var _floor_pos := Vector3.ZERO
var _floor_rot := Vector3.ZERO
var _rest_fov := 75.0
var _rng := RandomNumberGenerator.new()


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

	var floor_y := _find_floor_y()
	var roll := deg_to_rad(_rng.randf_range(MIN_ROLL_DEG, MAX_ROLL_DEG))
	var yaw := deg_to_rad(_rng.randf_range(-FALL_YAW_DEG, FALL_YAW_DEG))

	_floor_pos = _start_pos + Vector3(_kill_dir.x * FALL_FORWARD, 0.0, _kill_dir.z * FALL_FORWARD)
	_floor_pos.y = floor_y + FLOOR_CLEARANCE
	_floor_rot = _start_rot + Vector3(deg_to_rad(FALL_PITCH_DEG), yaw, roll)

	_start_scream()


func _find_floor_y() -> float:
	var from := _start_pos
	var to := _start_pos + Vector3.DOWN * 5.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var player := get_tree().get_first_node_in_group("player") as CollisionObject3D
	if player:
		query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _start_pos.y - 1.2
	return float(hit.position.y)


func _process(delta: float):
	if _done or _camera == null:
		return

	_time += delta

	if _phase == 0:
		# Ease-in: the head accelerates toward the floor instead of gliding.
		var p := clampf(_time / FALL_DURATION, 0.0, 1.0)
		var eased := p * p
		global_position = _start_pos.lerp(_floor_pos, eased)
		rotation = _start_rot.lerp(_floor_rot, eased)
		if p >= 1.0:
			_start_bounce()
	elif _phase == 1:
		var p := clampf(_time / BOUNCE_DURATION, 0.0, 1.0)
		var arc := sin(p * PI)
		global_position = _floor_pos + Vector3.UP * (arc * BOUNCE_HEIGHT)
		rotation = _floor_rot + Vector3(0.0, 0.0, arc * BOUNCE_ROLL)
		if p >= 1.0:
			_start_rest()
	elif _phase == 2:
		global_position = _floor_pos
		rotation = _floor_rot
		if _time >= REST_DURATION:
			_finish()


func _start_bounce():
	_phase = 1
	_time = 0.0
	global_position = _floor_pos
	rotation = _floor_rot


func _start_rest():
	_phase = 2
	_time = 0.0
	global_position = _floor_pos
	rotation = _floor_rot


# Ends the animation but keeps the fallen pose attached: the death screen fades
# in over this frozen view. game_manager releases the camera just before
# respawn via release_camera().
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
