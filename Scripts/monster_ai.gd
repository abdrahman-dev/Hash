extends CharacterBody3D


enum State { IDLE, INVESTIGATING, HUNTING }

signal scream_started
signal chase_started
signal chase_ended
signal player_caught

const SCREAM_FADE_DURATION := 0.6

# FINAL_PHASE altar patrol — active only after every book is collected.
const FINAL_PHASE_BOOKS := 6
const FINAL_PHASE_RING := Vector2(8.0, 12.0)
const FINAL_PHASE_RITUAL_RING := Vector2(5.0, 7.0)
const FINAL_PHASE_CROSS_CHANCE := 0.2

const DIFFICULTY_TABLE: Array[Dictionary] = [
	{},
	{},
	{"wander_speed": 2.0, "wander_pause_range": Vector2(0.6, 1.2)},
	{"detection_range": 11.5, "give_up_delay": 8.0},
	{"scream_duration": 2.0, "path_refresh_interval": 0.4},
	{"hunt_speed": 5.1, "give_up_delay": 10.0},
	{"hunt_speed": 5.15, "wander_speed": 2.2, "detection_range": 12.0},
]

@export var wander_interval: float = 4.0
@export var wander_speed: float = 1.8
@export var hunt_speed: float = 5.0
@export var target_player: NodePath

@export var detection_range: float = 10.0
@export var detection_check_interval: float = 0.2
@export var give_up_delay: float = 6.0
@export var wall_collision_mask: int = 1
@export var rotation_speed: float = 8.0

@export var catch_range: float = 1.9

@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_run: String = "run"
@export var anim_scream: String = "scream"

@export var footstep_patrol_volume: float = -23.0
@export var footstep_patrol_pitch: float = 0.30
@export var footstep_hunt_volume: float = -20.0
@export var footstep_hunt_pitch: float = 0.88
@export var footstep_scream_volume: float = -20.0
@export var footstep_blend_speed: float = 30.0
@export var footstep_pitch_blend_speed: float = 1.0

var current_state: State = State.IDLE

var _astar: AStar2D
var _maze_gen: Node
var _grid_width: int
var _grid_height: int
var _cell_size: float
var _path: Array[Vector3] = []
var _path_index: int = 0

var _wander_target: Vector2i
var _wander_pause_active: bool = false
var _wander_timer: Timer
var _wander_pause_timer: Timer

var wander_pause_range: Vector2 = Vector2(1.0, 2.0)
var scream_duration: float = 2.8
var path_refresh_interval: float = 0.5

var _time_since_last_seen: float = 0.0
var _detection_timer: Timer
var _path_timer: Timer

var _anim_players: Dictionary = {}  # anim_name → AnimationPlayer
var _scream_active: bool = false
var _scream_elapsed: float = 0.0
var _caught_player: bool = false
var _last_anim: String = ""
var _active_player: AnimationPlayer
var _forward_node: Marker3D
var _fwd_angle_offset: float
var _scream_players: Array[AudioStreamPlayer3D] = []
var _current_scream_idx: int = -1
var _scream_history: Array[int] = []
var _scream_rng: RandomNumberGenerator
var _footstep_audio: AudioStreamPlayer3D

var _spawn_transform: Transform3D
var _final_phase: bool = false
var _altar_node: Node3D


func _ready():
	_ensure_visual()
	_setup_animation()
	_setup_path_timer()
	_setup_wander()
	_setup_detection()
	_setup_rotation()
	_setup_scream_audio()
	_setup_footsteps()
	_spawn_transform = global_transform


func _ensure_visual():
	if not _has_mesh_instance_descendant(self):
		var mi := MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		var mesh := CapsuleMesh.new()
		mesh.height = 1.6
		mesh.radius = 0.3
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 0.02, 0.02)
		mi.mesh = mesh
		mi.material_override = mat
		add_child(mi)
		push_warning("[Monster] No MeshInstance3D found — created placeholder capsule")

	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not cs:
		cs = CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		add_child(cs)
		push_warning("[Monster] No CollisionShape3D found — created placeholder")
	var capsule := cs.shape as CapsuleShape3D
	if not capsule:
		capsule = CapsuleShape3D.new()
		capsule.height = 1.6
		capsule.radius = 0.3
		cs.shape = capsule


func _has_mesh_instance_descendant(node: Node) -> bool:
	for child in node.get_children():
		if child is MeshInstance3D:
			return true
		if _has_mesh_instance_descendant(child):
			return true
	return false


# ---------------------------------------------------------------------------
# Animation
# ---------------------------------------------------------------------------

func _setup_animation():
	_populate_anim_players(self)
	if _anim_players.is_empty():
		push_warning("[Monster] No AnimationPlayer found in descendants")
		return
	for player in _anim_players.values():
		player.animation_finished.connect(_on_anim_finished)


func _populate_anim_players(node: Node):
	for child in node.get_children():
		if child is AnimationPlayer:
			for anim_name in child.get_animation_list():
				_anim_players[anim_name] = child
		_populate_anim_players(child)


func _update_animation(h_speed: float):
	if _anim_players.is_empty():
		return
	if _scream_active:
		return

	var desired: String
	if current_state == State.IDLE:
		desired = anim_idle if h_speed < 0.1 else anim_walk
	else:
		desired = anim_run

	if desired == _last_anim:
		return
	_last_anim = desired

	if _anim_players.has(desired):
		var new_player := _anim_players[desired] as AnimationPlayer
		if _active_player and _active_player != new_player:
			_active_player.stop()
		_active_player = new_player
		_active_player.play(desired, 0.2)
	else:
		push_warning("monster_ai: animation \"%s\" not found" % desired)


func _on_anim_finished(anim_name: String):
	if anim_name == anim_scream:
		_scream_active = false
		if _current_scream_idx >= 0:
			_scream_players[_current_scream_idx].stop()


func _end_scream():
	if not _scream_active:
		return
	_scream_active = false
	if _current_scream_idx >= 0 and _current_scream_idx < _scream_players.size():
		var p := _scream_players[_current_scream_idx]
		if p:
			p.stop()
	_current_scream_idx = -1
	if _active_player:
		_active_player.stop()


func _setup_rotation():
	_forward_node = $Forward as Marker3D
	if not _forward_node:
		push_warning("monster_ai: Forward Marker3D not found — rotation will not work")
		return
	var fwd_pos := _forward_node.position
	_fwd_angle_offset = atan2(fwd_pos.x, fwd_pos.z)


func _setup_scream_audio():
	_scream_rng = RandomNumberGenerator.new()
	_scream_rng.randomize()
	var container := $ScreamVoice as Node3D
	if not container:
		return
	for child in container.get_children():
		if child is AudioStreamPlayer3D:
			_scream_players.append(child)


func _setup_footsteps():
	_footstep_audio = $Footsteps
	if _footstep_audio.stream:
		_footstep_audio.stream.loop = true
	_footstep_audio.play()


func _play_random_scream():
	if _scream_players.is_empty():
		return
	var candidates: Array[int] = []
	for i in _scream_players.size():
		if not (i in _scream_history):
			candidates.append(i)
	if candidates.is_empty():
		_scream_history.clear()
		for i in _scream_players.size():
			candidates.append(i)
	if candidates.is_empty():
		return
	var idx := candidates[_scream_rng.randi() % candidates.size()]
	_scream_history.append(idx)
	while _scream_history.size() > 2:
		_scream_history.pop_front()
	_current_scream_idx = idx
	var player := _scream_players[idx]
	player.pitch_scale = _scream_rng.randf_range(0.97, 1.03)
	player.volume_db = 0.0
	player.play()


func _update_monster_footsteps(_h_speed: float, delta: float):
	var target_vol: float = -80.0
	var target_pitch: float = footstep_patrol_pitch
	if _scream_active:
		target_vol = footstep_scream_volume
		target_pitch = lerp(footstep_patrol_pitch, footstep_hunt_pitch, 0.5)
	elif current_state == State.HUNTING:
		target_vol = footstep_hunt_volume
		target_pitch = footstep_hunt_pitch
	elif current_state == State.IDLE and not _wander_pause_active:
		target_vol = footstep_patrol_volume
		target_pitch = footstep_patrol_pitch
	_footstep_audio.volume_db = move_toward(_footstep_audio.volume_db, target_vol, footstep_blend_speed * delta)
	_footstep_audio.pitch_scale = move_toward(_footstep_audio.pitch_scale, target_pitch, footstep_pitch_blend_speed * delta)


func _setup_path_timer():
	_path_timer = Timer.new()
	_path_timer.name = "PathTimer"
	_path_timer.wait_time = path_refresh_interval
	_path_timer.timeout.connect(_recalculate_path)
	add_child(_path_timer)
	_path_timer.start()


func _setup_wander():
	_wander_timer = Timer.new()
	_wander_timer.name = "WanderTimer"
	add_child(_wander_timer)
	_wander_timer.timeout.connect(_pick_new_wander_destination)

	_wander_pause_timer = Timer.new()
	_wander_pause_timer.name = "WanderPauseTimer"
	_wander_pause_timer.one_shot = true
	add_child(_wander_pause_timer)
	_wander_pause_timer.timeout.connect(_on_wander_pause_ended)

	_pick_new_wander_destination()


func _pick_wander_target() -> Vector2i:
	var from_cell := world_to_cell(global_position)
	var from_id := from_cell.y * _grid_width + from_cell.x

	var visited := {from_id: 0}
	var queue: Array[int] = [from_id]
	var frontier := 0
	const MAX_STEPS := 4

	while frontier < queue.size():
		var current_id: int = queue[frontier]
		frontier += 1
		var dist: int = visited[current_id] as int
		if dist >= MAX_STEPS:
			continue
		for nid in _astar.get_point_connections(current_id):
			if not visited.has(nid):
				visited[nid] = dist + 1
				queue.append(nid)

	var candidates: Array[int] = []
	for id in visited:
		var d := visited[id] as int
		if d >= 2 and d <= MAX_STEPS:
			candidates.append(id)

	if candidates.is_empty():
		var conn := _astar.get_point_connections(from_id)
		if conn.is_empty():
			return from_cell
		candidates = conn.duplicate()

	var chosen_id := candidates[randi() % candidates.size()]
	return Vector2i(chosen_id % _grid_width, chosen_id / _grid_width)


# FINAL_PHASE: caches the altar node spawned by the maze generator.
func _find_altar() -> Node3D:
	if _altar_node and is_instance_valid(_altar_node):
		return _altar_node
	if not _maze_gen or not is_instance_valid(_maze_gen):
		return null
	_altar_node = _maze_gen.get_node_or_null("Altar") as Node3D
	return _altar_node


# FINAL_PHASE: true while the player is performing the ritual (the altar locks
# the player's controls via player_controller.set_ritual_locked).
func _ritual_active() -> bool:
	var player := get_node_or_null(target_player)
	if not player:
		return false
	return bool(player.get("_ritual_locked"))


# FINAL_PHASE: picks a patrol destination around the altar. The monster circles
# the altar at 8-12 m by default and tightens to 5-7 m while the ritual runs,
# occasionally targeting the altar cell so it visibly crosses the altar. All
# candidates are real maze cells, so the AStar path stays valid.
func _pick_final_phase_target() -> Vector2i:
	var altar := _find_altar()
	if not altar or not _astar:
		return _pick_wander_target()

	var from_cell := world_to_cell(global_position)
	var altar_cell := world_to_cell(altar.global_position)
	var altar_local: Vector3 = _maze_gen.to_local(altar.global_position)
	var ring: Vector2 = FINAL_PHASE_RITUAL_RING if _ritual_active() else FINAL_PHASE_RING

	if randf() < FINAL_PHASE_CROSS_CHANCE and altar_cell != from_cell:
		return altar_cell

	var candidates: Array[int] = []
	for id in _astar.get_point_ids():
		var cell := Vector2i(id % _grid_width, id / _grid_width)
		if cell == from_cell:
			continue
		var world: Vector3 = _maze_gen.cell_to_world_position(cell)
		var d := Vector2(world.x - altar_local.x, world.z - altar_local.z).length()
		if d >= ring.x and d <= ring.y:
			candidates.append(id)

	if candidates.is_empty():
		for id in _astar.get_point_ids():
			var cell := Vector2i(id % _grid_width, id / _grid_width)
			if cell == from_cell:
				continue
			var world: Vector3 = _maze_gen.cell_to_world_position(cell)
			var d := Vector2(world.x - altar_local.x, world.z - altar_local.z).length()
			if d >= ring.x:
				candidates.append(id)

	if candidates.is_empty():
		return _pick_wander_target()

	var chosen_id := candidates[randi() % candidates.size()]
	return Vector2i(chosen_id % _grid_width, chosen_id / _grid_width)


func _pick_new_wander_destination():
	if current_state != State.IDLE:
		return
	if not _astar or not is_instance_valid(_maze_gen):
		_wander_timer.start(randf_range(0.5, 1.0))
		return
	_wander_pause_active = false
	if _final_phase:
		_wander_target = _pick_final_phase_target()
	else:
		_wander_target = _pick_wander_target()
	_wander_timer.start(randf_range(wander_interval * 0.7, wander_interval * 1.3))
	_recalculate_path()


func _on_wander_pause_ended():
	_pick_new_wander_destination()


# ---------------------------------------------------------------------------
# Line-of-sight detection
# ---------------------------------------------------------------------------

func _setup_detection():
	_detection_timer = Timer.new()
	_detection_timer.name = "DetectionTimer"
	_detection_timer.wait_time = detection_check_interval
	_detection_timer.timeout.connect(_on_detection_timeout)
	add_child(_detection_timer)
	_detection_timer.start()


func _on_detection_timeout():
	var player := get_node_or_null(target_player) as Node3D
	if not player:
		return

	if _has_line_of_sight(player):
		_time_since_last_seen = 0.0
		if current_state != State.HUNTING:
			_enter_hunting()
	elif current_state == State.HUNTING:
		_time_since_last_seen += detection_check_interval
		if _time_since_last_seen >= give_up_delay:
			_enter_idle()


func _has_line_of_sight(player: Node3D) -> bool:
	var from := global_position + Vector3(0, 0.8, 0)
	var to := player.global_position + Vector3(0, 0.8, 0)
	if from.distance_to(to) > detection_range:
		return false

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, wall_collision_mask)
	query.exclude = [self, player]
	return space.intersect_ray(query).is_empty()


# Catches the player when within catch_range with a clear line of sight,
# so the monster never grabs through walls. Collision shapes stay untouched.
func _check_player_contact():
	var player := get_node_or_null(target_player) as Node3D
	if not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > catch_range:
		return
	if not _has_line_of_sight(player):
		return
	_caught_player = true
	velocity = Vector3.ZERO
	player_caught.emit()


func _enter_hunting():
	current_state = State.HUNTING
	_wander_timer.stop()
	_wander_pause_timer.stop()
	_recalculate_path()
	chase_started.emit()
	_start_scream()


func _start_scream():
	if not _anim_players.has(anim_scream):
		return
	_scream_active = true
	_scream_elapsed = 0.0
	var scream_player := _anim_players[anim_scream] as AnimationPlayer
	if _active_player and _active_player != scream_player:
		_active_player.stop()
	_active_player = scream_player
	_active_player.play(anim_scream)
	_play_random_scream()
	scream_started.emit()


# Force the final-phase escalation: scream + chase effects (camera shake via
# scream_started, heartbeat spike via chase_started) when all books are found.
func trigger_final_phase():
	if current_state == State.HUNTING:
		_start_scream()
	else:
		_enter_hunting()


func _enter_idle():
	current_state = State.IDLE
	_wander_pause_active = false
	_pick_new_wander_destination()
	chase_ended.emit()


# Restores the monster to its original spawn transform in IDLE state so the
# player can respawn in place without reloading the scene. Keeps navigation
# intact and resumes normal wandering.
func reset_to_spawn():
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_caught_player = false
	_path.clear()
	_path_index = 0
	_time_since_last_seen = 0.0
	_wander_pause_active = false

	if _scream_active:
		_scream_active = false
		if _current_scream_idx >= 0 and _current_scream_idx < _scream_players.size():
			var p := _scream_players[_current_scream_idx]
			if p:
				p.stop()
	_current_scream_idx = -1

	if _active_player:
		_active_player.stop()
	_last_anim = ""

	if current_state != State.IDLE:
		current_state = State.IDLE
		chase_ended.emit()

	if _wander_pause_timer:
		_wander_pause_timer.stop()
	if _wander_timer:
		_wander_timer.stop()
	_pick_new_wander_destination()


func set_difficulty(books: int):
	var level := clampi(books, 0, DIFFICULTY_TABLE.size() - 1)
	for i in range(level + 1):
		for key in DIFFICULTY_TABLE[i]:
			set(key, DIFFICULTY_TABLE[i][key])
	_apply_difficulty_timers()
	_final_phase = books >= FINAL_PHASE_BOOKS


func _apply_difficulty_timers():
	if _path_timer:
		_path_timer.wait_time = path_refresh_interval


# ---------------------------------------------------------------------------
# Public navigation API
# ---------------------------------------------------------------------------

func build_navigation(maze_gen: Node):
	_maze_gen = maze_gen
	_grid_width = maze_gen.grid_width
	_grid_height = maze_gen.grid_height
	_cell_size = maze_gen.cell_size

	var grid: Array = maze_gen.get_maze_data()
	_astar = AStar2D.new()

	# Add every maze cell as an AStar2D point keyed by y * width + x.
	for y in _grid_height:
		for x in _grid_width:
			_astar.add_point(y * _grid_width + x, Vector2(x, y))

	for y in _grid_height:
		for x in _grid_width:
			var cell: Dictionary = grid[y][x]
			var id := y * _grid_width + x

			if x < _grid_width - 1 and not cell["E"]:
				_astar.connect_points(id, y * _grid_width + (x + 1))

			if y < _grid_height - 1 and not cell["S"]:
				_astar.connect_points(id, (y + 1) * _grid_width + x)


func rebuild_navigation():
	if _astar:
		_astar.clear()
	if _maze_gen:
		build_navigation(_maze_gen)


# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

func world_to_cell(world_pos: Vector3) -> Vector2i:
	var local_pos: Vector3 = _maze_gen.to_local(world_pos)
	var x := int(floor(local_pos.x / _cell_size))
	var y := int(floor(local_pos.z / _cell_size))
	x = clampi(x, 0, _grid_width - 1)
	y = clampi(y, 0, _grid_height - 1)
	return Vector2i(x, y)


# ---------------------------------------------------------------------------
# Path recalculation (every 0.5 s via PathTimer)
# ---------------------------------------------------------------------------

func _recalculate_path():
	if not _astar or not is_instance_valid(_maze_gen):
		if current_state != State.IDLE:
			var player := get_node_or_null(target_player) as Node3D
			if player:
				_path = [player.global_position]
				_path_index = 0
		return

	var from_cell := world_to_cell(global_position)
	var from_id := from_cell.y * _grid_width + from_cell.x

	var to_cell: Vector2i
	if current_state == State.IDLE:
		to_cell = _wander_target
	else:
		var player := get_node_or_null(target_player) as Node3D
		if not player:
			return
		to_cell = world_to_cell(player.global_position)

	var to_id := to_cell.y * _grid_width + to_cell.x

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return

	var id_path := _astar.get_id_path(from_id, to_id)
	_path.clear()
	for id in id_path:
		var cx := id % _grid_width
		var cy := id / _grid_width
		var cell_local: Vector3 = _maze_gen.cell_to_world_position(Vector2i(cx, cy))
		_path.append(_maze_gen.to_global(cell_local))

	# Skip waypoint 0 (our own cell center) — AStar2D always includes the
	# start point as the first element.  Re-targeting toward it every 0.5s
	# creates oscillation: we never close the gap before the timer resets.
	# A single-element path (we're already in the player's cell) is the
	# only case where index 0 is meaningful.
	_path_index = 1 if _path.size() > 1 else 0


# ---------------------------------------------------------------------------
# Physics
# ---------------------------------------------------------------------------

func _physics_process(delta: float):
	if _caught_player:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		velocity.y = 0.0
		move_and_slide()
		return

	var grav: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8) as float
	velocity.y -= grav * delta

	if _scream_active:
		velocity.x = move_toward(velocity.x, 0.0, grav * delta * 2.0)
		velocity.z = move_toward(velocity.z, 0.0, grav * delta * 2.0)
		_scream_elapsed += delta
		if _scream_elapsed >= scream_duration - SCREAM_FADE_DURATION and _current_scream_idx >= 0:
			var p := _scream_players[_current_scream_idx]
			if p and p.playing:
				p.volume_db = move_toward(p.volume_db, -80.0, (80.0 / SCREAM_FADE_DURATION) * delta)
		if _scream_elapsed >= scream_duration:
			_end_scream()
	elif current_state == State.IDLE and _wander_pause_active:
		velocity.x = move_toward(velocity.x, 0.0, grav * delta * 2.0)
		velocity.z = move_toward(velocity.z, 0.0, grav * delta * 2.0)
	elif current_state == State.IDLE or current_state == State.HUNTING:
		_move_along_path()
	else:
		velocity.x = move_toward(velocity.x, 0.0, grav * delta * 2.0)
		velocity.z = move_toward(velocity.z, 0.0, grav * delta * 2.0)

	move_and_slide()

	if not _caught_player and current_state == State.HUNTING:
		_check_player_contact()
		if not _caught_player:
			for i in get_slide_collision_count():
				var col := get_slide_collision(i)
				var col_obj := col.get_collider()
				if col_obj and col_obj.is_in_group("player"):
					_caught_player = true
					velocity = Vector3.ZERO
					player_caught.emit()
					break

	if _scream_active:
		_face_player(delta)
	elif current_state == State.IDLE or current_state == State.HUNTING:
		_face_movement_direction(delta)

	var h_speed: float = Vector3(velocity.x, 0, velocity.z).length()
	_update_animation(h_speed)
	_update_monster_footsteps(h_speed, delta)


func _face_player(delta: float):
	if not _forward_node:
		return
	var player := get_node_or_null(target_player) as Node3D
	if not player:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() < 0.001:
		return
	var target_angle := atan2(to_player.x, to_player.z)
	rotation.y = lerp_angle(rotation.y, target_angle - _fwd_angle_offset, rotation_speed * delta)


func _face_movement_direction(delta: float):
	if not _forward_node:
		return
	var dir := Vector3(velocity.x, 0, velocity.z)
	if dir.length_squared() < 0.001:
		return
	var target_angle := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle - _fwd_angle_offset, rotation_speed * delta)


# FINAL_PHASE: the monster never stands still while guarding the altar, so
# arrivals immediately pick the next patrol point instead of pausing.
func _on_patrol_arrival():
	if _final_phase:
		_pick_new_wander_destination()
	else:
		_wander_pause_active = true
		_wander_pause_timer.start(randf_range(wander_pause_range.x, wander_pause_range.y))


func _move_along_path():
	if _path.is_empty() or _path_index >= _path.size():
		if current_state == State.IDLE and not _wander_pause_active:
			_on_patrol_arrival()
		return

	var target := _path[_path_index]
	var to_target := target - global_position
	to_target.y = 0.0

	while to_target.length_squared() < 0.3 * 0.3:
		_path_index += 1
		if _path_index >= _path.size():
			velocity.x = move_toward(velocity.x, 0.0, 1.0)
			velocity.z = move_toward(velocity.z, 0.0, 1.0)
			if current_state == State.IDLE and not _wander_pause_active:
				_on_patrol_arrival()
			return
		target = _path[_path_index]
		to_target = target - global_position
		to_target.y = 0.0

	var dir := to_target.normalized()
	var speed := wander_speed if current_state == State.IDLE else hunt_speed
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed


# ---------------------------------------------------------------------------
# Spawn placement
# ---------------------------------------------------------------------------

func spawn_far_from_player():
	if not _maze_gen or not is_instance_valid(_maze_gen):
		return
	var player := get_node_or_null(target_player) as Node3D
	if not player:
		return

	var player_cell := world_to_cell(player.global_position)
	var diagonal := Vector2(_grid_width, _grid_height).length()
	var min_dist := diagonal / 3.0

	var candidates: Array[Vector2i] = []
	var best_cell := Vector2i.ZERO
	var best_dist := -1.0

	for y in _grid_height:
		for x in _grid_width:
			var cell := Vector2i(x, y)
			var d := Vector2(cell - player_cell).length()
			if d >= min_dist:
				candidates.append(cell)
			if d > best_dist:
				best_dist = d
				best_cell = cell

	var chosen := best_cell
	if not candidates.is_empty():
		chosen = candidates[randi() % candidates.size()]

	var cell_local: Vector3 = _maze_gen.cell_to_world_position(chosen)
	global_position = _maze_gen.to_global(cell_local)
	_spawn_transform = global_transform


# ===========================================================================
# EXTERNAL WIRING NOTE
# ===========================================================================
# Call build_navigation(maze_gen) after the maze is generated, for example
# in the main scene script after maze_generator.regenerate_maze():
#
#    $Monster.build_navigation($Node3D)   # Node3D is the maze generator
#
# Also call rebuild_navigation() whenever the maze is regenerated at
# runtime (e.g. connect it to a "maze_regenerated" signal if you add one,
# or call it manually in the same place as regenerate_maze()).
