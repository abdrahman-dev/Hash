extends CharacterBody3D

# Simple environmental creature with real navigation. The Rat builds the same
# AStar2D walkway graph the monster uses (from its Maze ancestor's grid data),
# picks a random walkable maze cell as its destination, then follows the valid
# path through the corridors with move_and_slide(), looping "Armature|Run".
# Destinations are always real walkable cells, never arbitrary world-space
# points, so the rat never tries to cross walls. When the player gets close it
# commits to a walkable cell away from them and bolts there at a higher speed,
# only re-targeting once the destination is reached. It faces its actual
# movement direction via the ForwardMarker and occasionally plays one of its
# positional squeak sounds at a quiet, randomized pace.
const RUN_ANIM := "Armature|Run"

const TURN_SPEED := 18.0
const ARRIVE_DIST := 0.3

# Normal scurrying: fast, decisive, so the rat never looks frozen.
const SPEED_MIN := 4.5
const SPEED_MAX := 6.0

# Fear: a player closer than FEAR_RADIUS makes the rat bolt to a far cell away
# from them at a much higher speed. Fleeing persists until the player is
# farther than FEAR_RADIUS again.
const FEAR_RADIUS := 5.0
const FEAR_SPEED_MIN := 8.0
const FEAR_SPEED_MAX := 10.0

# A flee target must stay at least this far from the player (world units).
const FLEE_MIN_DISTANCE := FEAR_RADIUS * 1.5

# Random squeaks — quiet, well separated in time so they never dominate.
const SOUND_MIN_DELAY := 3.0
const SOUND_MAX_DELAY := 9.0
const SOUND_VOLUME_DB := -20.0

var _anim_player: AnimationPlayer
var _forward_marker: Marker3D
var _fwd_angle_offset := 0.0

var _player: Node3D
var _fleeing := false
var _target := Vector3.ZERO
var _speed := 0.0

var _maze_gen: Node3D
var _astar: AStar2D
var _grid_width := 0
var _grid_height := 0

# Idle pause between wander destinations, so each rat waits a random amount of
# time before moving again — makes them feel independent.
var _wander_pause := 0.0

var _path: Array[Vector3] = []
var _path_index := 0
var _last_cell := Vector2i(999999, 999999)

var _sound_delay := 0.0
var _last_sound := -1
var _sound_players: Array[AudioStreamPlayer3D] = []

var _rng := RandomNumberGenerator.new()


func _ready():
	_rng.randomize()

	_find_anim_player()

	if _anim_player:
		var run_anim := _anim_player.get_animation(RUN_ANIM)
		if run_anim:
			run_anim.loop_mode = Animation.LOOP_LINEAR
		_anim_player.play(RUN_ANIM)

	_collect_sound_players()
	_sound_delay = _rng.randf_range(SOUND_MIN_DELAY, SOUND_MAX_DELAY)

	_setup_forward()
	_build_navigation()

	# Stagger each rat's first move so they don't all start moving together.
	await get_tree().create_timer(randf_range(0.5, 3.0)).timeout
	_pick_destination()


func _physics_process(delta: float):
	position.y = 0.0

	if _wander_pause > 0.0:
		_wander_pause -= delta
		velocity = Vector3.ZERO
		move_and_slide()
		if _wander_pause <= 0.0:
			_pick_destination()
		return

	_tick_sounds(delta)
	_check_fear()

	_move_along_path(delta)
	move_and_slide()

	if get_slide_collision_count() > 0:
		_pick_destination()

	face_movement_direction(delta)


func _move_along_path(_delta: float):
	if _path.is_empty() or _path_index >= _path.size():
		_move_to_target()
		return

	var target := _path[_path_index]
	var to_target := target - global_position
	to_target.y = 0.0

	while to_target.length_squared() < ARRIVE_DIST * ARRIVE_DIST:
		_path_index += 1

		if _path_index >= _path.size():
			_move_to_target()
			return

		target = _path[_path_index]
		to_target = target - global_position
		to_target.y = 0.0

	var dir := to_target.normalized()

	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed


# Defensive straight-line fallback used only when no maze navigation data is
# available (should not happen in the game). Otherwise the rat follows paths
# through walkable cells and never crosses walls.
func _move_to_target():
	var to_target := _target - global_position
	to_target.y = 0.0

	if to_target.length_squared() < ARRIVE_DIST * ARRIVE_DIST:
		if not _fleeing:
			_wander_pause = randf_range(1.5, 4.5)
		else:
			_pick_destination()
		return

	var dir := to_target.normalized()

	velocity.x = dir.x * _speed
	velocity.z = dir.z * _speed


func _pick_destination():
	if not _astar:
		_pick_fallback_destination()
		return

	_wander_pause = 0.0

	if _fleeing:
		var player := _get_player()

		if player == null or _distance_to(player) > FEAR_RADIUS:
			_fleeing = false
		else:
			_pick_escape_destination()
			return

	_pick_wander_destination()


func _check_fear():
	if _fleeing:
		return

	var player := _get_player()

	if player == null:
		return

	if _distance_to(player) >= FEAR_RADIUS:
		return

	_fleeing = true
	_pick_destination()


# Normal wandering: commit to one random walkable cell (never the cell we just
# came from), then follow the valid path to it.
func _pick_wander_destination():
	var current_cell := _world_to_cell(global_position)
	var candidates: Array[Vector2i] = []

	for id in _astar.get_point_ids():
		var cell := Vector2i(id % _grid_width, id / _grid_width)

		if cell == current_cell or cell == _last_cell:
			continue

		candidates.append(cell)

	if candidates.is_empty():
		candidates.append(current_cell)

	var chosen := candidates[_rng.randi_range(0, candidates.size() - 1)]

	_last_cell = chosen
	_target = _cell_to_world(chosen)
	_speed = _rng.randf_range(SPEED_MIN, SPEED_MAX)
	_build_path(chosen)


# Fleeing: commit to a walkable cell that is clearly away from the player and
# far enough from them, then follow the path at top speed. The destination is
# only re-picked once it is reached, so the flee path is never recalculated
# every frame.
func _pick_escape_destination():
	var current_cell := _world_to_cell(global_position)
	var player := _get_player()

	var away := Vector3.ZERO
	if player:
		away = global_position - player.global_position
		away.y = 0.0
		away = away.normalized()

	var candidates: Array[Vector2i] = []

	for id in _astar.get_point_ids():
		var cell := Vector2i(id % _grid_width, id / _grid_width)

		if cell == current_cell or cell == _last_cell:
			continue

		var world_pos := _cell_to_world(cell)
		var direction := world_pos - global_position
		direction.y = 0.0

		if direction.length_squared() < 0.01:
			continue

		if direction.normalized().dot(away) <= 0.25:
			continue

		if player and world_pos.distance_to(player.global_position) < FLEE_MIN_DISTANCE:
			continue

		candidates.append(cell)

	var chosen: Vector2i
	if candidates.is_empty():
		chosen = _farthest_cell(current_cell)
	else:
		chosen = candidates[_rng.randi_range(0, candidates.size() - 1)]

	_last_cell = chosen
	_target = _cell_to_world(chosen)
	_speed = _rng.randf_range(FEAR_SPEED_MIN, FEAR_SPEED_MAX)
	_build_path(chosen)


func _farthest_cell(current_cell: Vector2i) -> Vector2i:
	var best := current_cell
	var best_dist := -1

	for id in _astar.get_point_ids():
		var cell := Vector2i(id % _grid_width, id / _grid_width)
		var d := _manhattan(cell, current_cell)

		if d > best_dist:
			best_dist = d
			best = cell

	return best


func _build_path(to_cell: Vector2i):
	_path.clear()
	_path_index = 0

	if not _astar or _maze_gen == null:
		return

	var from_cell := _world_to_cell(global_position)
	var from_id := from_cell.y * _grid_width + from_cell.x
	var to_id := to_cell.y * _grid_width + to_cell.x

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return

	for id in _astar.get_id_path(from_id, to_id):
		var cx := id % _grid_width
		var cy := id / _grid_width
		var cell_local: Vector3 = _maze_gen.cell_to_world_position(Vector2i(cx, cy))
		_path.append(_maze_gen.to_global(cell_local))

	# Skip waypoint 0 (our own cell center) — AStar2D always includes the
	# start point as the first element, so re-targeting toward it would just
	# spin in place.
	_path_index = 1 if _path.size() > 1 else 0


func _distance_to(node: Node3D) -> float:
	var to_node := node.global_position - global_position
	to_node.y = 0.0
	return to_node.length()


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


# Defensive fallback only: keeps a rat moving if the maze data is missing
# (should not happen in the game). The normal path always uses AStar2D over
# walkable cells.
func _pick_fallback_destination():
	var angle := _rng.randf() * TAU
	_target = global_position + Vector3(cos(angle), 0.0, sin(angle)) * 8.0
	_speed = _rng.randf_range(SPEED_MIN, SPEED_MAX)
	_path.clear()
	_path_index = 0


func _build_navigation():
	_maze_gen = _get_maze()

	if _maze_gen == null or not _maze_gen.has_method("get_maze_data"):
		return

	var maze_data = _maze_gen.get_maze_data()

	if not (maze_data is Array):
		return

	_grid_width = _maze_gen.grid_width
	_grid_height = _maze_gen.grid_height

	_astar = AStar2D.new()

	# Every grid entry is a walkable corridor cell (walls only exist on edges
	# between cells), so every cell is an AStar2D point keyed by y * w + x,
	# exactly like the monster's navigation graph.
	for y in _grid_height:
		for x in _grid_width:
			_astar.add_point(y * _grid_width + x, Vector2(x, y))

	for y in _grid_height:
		for x in _grid_width:
			var cell: Dictionary = maze_data[y][x]
			var id := y * _grid_width + x

			if x < _grid_width - 1 and not cell["E"]:
				_astar.connect_points(id, y * _grid_width + (x + 1))

			if y < _grid_height - 1 and not cell["S"]:
				_astar.connect_points(id, (y + 1) * _grid_width + x)


func _world_to_cell(world_pos: Vector3) -> Vector2i:
	if _maze_gen == null or _grid_width <= 0:
		return Vector2i.ZERO

	var local := _maze_gen.to_local(world_pos)

	return Vector2i(
		clampi(floori(local.x / _maze_gen.cell_size), 0, _grid_width - 1),
		clampi(floori(local.z / _maze_gen.cell_size), 0, _grid_height - 1)
	)


func _cell_to_world(cell: Vector2i) -> Vector3:
	if _maze_gen == null:
		return global_position

	return _maze_gen.to_global(_maze_gen.cell_to_world_position(cell))


func _get_maze() -> Node3D:
	var node := get_parent()

	while node != null:
		if node.has_method("get_maze_data") and node.has_method("cell_to_world_position"):
			return node as Node3D
		node = node.get_parent()

	return null


func _get_player() -> Node3D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D

	return _player


func _setup_forward():
	_forward_marker = _find_forward_marker()

	if not _forward_marker:
		return

	var forward := to_local(_forward_marker.global_position)
	forward.y = 0.0

	if forward.length_squared() > 0.001:
		_fwd_angle_offset = atan2(forward.x, forward.z)


func _find_forward_marker() -> Marker3D:
	return _find_forward_marker_in(self)


func _find_forward_marker_in(node: Node) -> Marker3D:
	if node is Marker3D and node.name == "ForwardMarker":
		return node

	for child in node.get_children():
		var found := _find_forward_marker_in(child)

		if found:
			return found

	return null


func _find_anim_player():
	for child in get_children():
		if child is AnimationPlayer:
			_anim_player = child
			return

		_find_anim_player_descendants(child)


func _find_anim_player_descendants(node: Node):
	if _anim_player:
		return

	for child in node.get_children():
		if child is AnimationPlayer:
			_anim_player = child
			return

		_find_anim_player_descendants(child)


func _collect_sound_players():
	for child in get_children():
		if child is AudioStreamPlayer3D:
			child.volume_db = SOUND_VOLUME_DB
			_sound_players.append(child)


func _tick_sounds(delta: float):
	_sound_delay -= delta

	if _sound_delay > 0.0:
		return

	_sound_delay = _rng.randf_range(SOUND_MIN_DELAY, SOUND_MAX_DELAY)

	if _sound_players.is_empty():
		return

	var index := _rng.randi_range(0, _sound_players.size() - 1)

	if _sound_players.size() > 1 and index == _last_sound:
		index = (index + 1) % _sound_players.size()

	_last_sound = index

	var player := _sound_players[index]

	player.pitch_scale = _rng.randf_range(0.9, 1.1)
	player.play()


func face_movement_direction(delta: float):
	var direction := Vector3(velocity.x, 0.0, velocity.z)

	if direction.length_squared() < 0.001:
		return

	var target_angle := atan2(direction.x, direction.z) - _fwd_angle_offset

	rotation.y = lerp_angle(rotation.y, target_angle, TURN_SPEED * delta)
