extends Node3D


@export var grid_width: int = 15
@export var grid_height: int = 15
@export var cell_size: float = 4.0

# Exposed material slots — assign any StandardMaterial3D to replace
# the default flat colors, including via code or scene inheritance.
@export var wall_material: StandardMaterial3D
@export var floor_material: StandardMaterial3D
@export var ceiling_material: StandardMaterial3D

@export var ceiling_height: float = 4.5

@export var bone_scene: PackedScene
@export var bone_count: int = 6

@export var altar_scene: PackedScene
@export var altar_min_graph_distance := 8

@export var book_min_graph_dist: int = 4
@export var book_max_graph_dist: int = 12

@export var note_scene: PackedScene
@export var note_count: int = 4
@export var note_min_graph_distance: int = 4

@export var rat_scene: PackedScene
@export var rat_count: int = 3


var _grid: Array  # 2D array of dicts: grid[y][x] = {"N":bool,"S":bool,"E":bool,"W":bool}
var _spawn_cell: Vector2i
var _exit_cell: Vector2i
var _book_cells: Array[Vector2i] = []
var _altar_cell: Vector2i = Vector2i(-1, -1)

const WALL_THICKNESS: float = 0.2


func _ready():
	if grid_width < 5 or grid_height < 5:
		push_warning("maze_generator.gd: grid_width and grid_height should be at least 5")
	_init_materials()
	_setup_lighting()
	regenerate_maze()
	_spawn_bones()
	_spawn_altar()
	_spawn_notes()
	_spawn_rats()


func _init_materials():
	if not wall_material:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_color = Color(0.2, 0.2, 0.2)
	if not floor_material:
		floor_material = StandardMaterial3D.new()
		floor_material.albedo_color = Color(0.3, 0.15, 0.05)
	if not ceiling_material:
		ceiling_material = StandardMaterial3D.new()
		ceiling_material.albedo_color = Color(0.1, 0.1, 0.1)


# Finds the existing WorldEnvironment and configures a dim ambient light
# so the ceiling underside and other back-facing surfaces don't render
# pure black. Stays dark/atmospheric — just enough light to see geometry.
func _setup_lighting():
	var root = get_tree().current_scene
	if not root:
		return
	var env_node = root.get_node_or_null("WorldEnvironment")
	if not env_node:
		return
	if not env_node.environment:
		return

	env_node.environment.ambient_light_color = Color(0.15, 0.17, 0.2)
	env_node.environment.ambient_light_energy = 0.5
	env_node.environment.ambient_light_sky_contribution = 0.7


func regenerate_maze():
	var existing = get_node_or_null("MazeGeometry")
	if existing:
		existing.queue_free()

	_generate_maze_data()
	_post_process()
	_build_geometry()


func get_maze_data() -> Array:
	return _grid


func cell_to_world_position(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size, 0, (cell.y + 0.5) * cell_size)


func get_dead_end_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			var count: int = 0
			for dir in ["N", "S", "E", "W"]:
				if _grid[y][x][dir]:
					count += 1
			if count == 3:
				result.append(Vector2i(x, y))
	return result


func get_spawn_cell() -> Vector2i:
	return _spawn_cell


func get_exit_cell() -> Vector2i:
	return _exit_cell


# ---------------------------------------------------------------------------
# Maze generation — iterative Recursive Backtracker (randomized DFS).
# Guarantees every cell is reachable from every other cell.
# ---------------------------------------------------------------------------

func _generate_maze_data():
	_grid = []
	for y in range(grid_height):
		_grid.append([])
		for x in range(grid_width):
			_grid[y].append({"N": true, "S": true, "E": true, "W": true})

	var visited: Array = []
	for y in range(grid_height):
		visited.append([])
		for x in range(grid_width):
			visited[y].append(false)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var stack: Array[Vector2i] = []
	var current := Vector2i.ZERO
	visited[current.y][current.x] = true

	while true:
		var unvisited := _get_unvisited_neighbors(current, visited)
		if unvisited.size() > 0:
			var next: Vector2i = unvisited[rng.randi() % unvisited.size()]
			_carve_wall(current, next)
			stack.append(current)
			current = next
			visited[current.y][current.x] = true
		elif stack.size() > 0:
			current = stack.pop_back()
		else:
			break

	_spawn_cell = Vector2i.ZERO
	_exit_cell = _find_farthest_cell(_spawn_cell)


func _get_unvisited_neighbors(cell: Vector2i, visited: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
	for d in dirs:
		var nx: int = cell.x + d.x
		var ny: int = cell.y + d.y
		if nx >= 0 and nx < grid_width and ny >= 0 and ny < grid_height:
			if not visited[ny][nx]:
				result.append(Vector2i(nx, ny))
	return result


func _carve_wall(from: Vector2i, to: Vector2i):
	if from.x == to.x:
		if from.y < to.y:
			_grid[from.y][from.x]["S"] = false
			_grid[to.y][to.x]["N"] = false
		else:
			_grid[from.y][from.x]["N"] = false
			_grid[to.y][to.x]["S"] = false
	else:
		if from.x < to.x:
			_grid[from.y][from.x]["E"] = false
			_grid[to.y][to.x]["W"] = false
		else:
			_grid[from.y][from.x]["W"] = false
			_grid[to.y][to.x]["E"] = false


# BFS from the given cell — returns the cell with the longest shortest-path
# distance, so the exit is placed as far as possible from the spawn.
func _find_farthest_cell(from: Vector2i) -> Vector2i:
	var dist: Array = []
	for y in range(grid_height):
		dist.append([])
		for x in range(grid_width):
			dist[y].append(-1)

	var queue: Array[Vector2i] = [from]
	dist[from.y][from.x] = 0
	var farthest := from

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()
		var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]
		for d in dirs:
			var nx: int = current.x + d.x
			var ny: int = current.y + d.y
			if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
				continue
			if dist[ny][nx] != -1:
				continue
			if d == Vector2i(0, -1) and _grid[current.y][current.x]["N"]:
				continue
			if d == Vector2i(0, 1) and _grid[current.y][current.x]["S"]:
				continue
			if d == Vector2i(1, 0) and _grid[current.y][current.x]["E"]:
				continue
			if d == Vector2i(-1, 0) and _grid[current.y][current.x]["W"]:
				continue

			dist[ny][nx] = dist[current.y][current.x] + 1
			if dist[ny][nx] > dist[farthest.y][farthest.x]:
				farthest = Vector2i(nx, ny)
			queue.append(Vector2i(nx, ny))

	return farthest


# ---------------------------------------------------------------------------
# Post-processing — adds loops and reduces dead ends to improve topology.
# Called after DFS generation, before geometry building.
# ---------------------------------------------------------------------------

func _post_process():
	var interior_walls: Array[Dictionary] = []

	for y in range(grid_height):
		for x in range(grid_width):
			if x < grid_width - 1 and _grid[y][x]["E"]:
				interior_walls.append({
					"a": Vector2i(x, y), "b": Vector2i(x + 1, y),
					"a_dir": "E", "b_dir": "W"
				})
			if y < grid_height - 1 and _grid[y][x]["S"]:
				interior_walls.append({
					"a": Vector2i(x, y), "b": Vector2i(x, y + 1),
					"a_dir": "S", "b_dir": "N"
				})

	# Step 1 — open ~12 % of interior walls (creates loops)
	var loop_count := 0
	if interior_walls.size() > 0:
		interior_walls.shuffle()
		loop_count = maxi(1, interior_walls.size() * 12 / 100)
		for i in range(loop_count):
			var w := interior_walls[i]
			_grid[w.a.y][w.a.x][w.a_dir] = false
			_grid[w.b.y][w.b.x][w.b_dir] = false

	# Step 2 — reduce ~50 % of remaining dead ends
	var dead_ends := get_dead_end_cells()
	dead_ends.shuffle()
	var to_reduce := dead_ends.size() / 2
	var reduced := 0
	for cell_pos in dead_ends:
		if reduced >= to_reduce:
			break
		var cell: Dictionary = _grid[cell_pos.y][cell_pos.x]
		var y := cell_pos.y
		var x := cell_pos.x

		var candidates: Array[Dictionary] = []
		if cell["N"] and y > 0:
			candidates.append({"neighbor": Vector2i(x, y - 1), "dir": "N", "neighbor_dir": "S"})
		if cell["S"] and y < grid_height - 1:
			candidates.append({"neighbor": Vector2i(x, y + 1), "dir": "S", "neighbor_dir": "N"})
		if cell["E"] and x < grid_width - 1:
			candidates.append({"neighbor": Vector2i(x + 1, y), "dir": "E", "neighbor_dir": "W"})
		if cell["W"] and x > 0:
			candidates.append({"neighbor": Vector2i(x - 1, y), "dir": "W", "neighbor_dir": "E"})

		if candidates.is_empty():
			continue
		candidates.shuffle()
		var c := candidates[0]
		_grid[cell_pos.y][cell_pos.x][c.dir] = false
		_grid[c.neighbor.y][c.neighbor.x][c.neighbor_dir] = false
		reduced += 1




# ---------------------------------------------------------------------------
# Geometry building
# ---------------------------------------------------------------------------

func _build_geometry():
	var container := Node3D.new()
	container.name = "MazeGeometry"
	add_child(container)

	_build_floor(container)
	_build_ceiling(container)
	_build_walls(container)


func _build_floor(parent: Node3D):
	var body := StaticBody3D.new()
	body.name = "Floor"
	body.position = Vector3(grid_width * cell_size * 0.5, 0, grid_height * cell_size * 0.5)
	parent.add_child(body)

	floor_material.uv1_scale = Vector3(grid_width, grid_height, 1)

	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid_width * cell_size, grid_height * cell_size)
	plane.material = floor_material
	mi.mesh = plane
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(grid_width * cell_size, 0.1, grid_height * cell_size)
	col.shape = shape
	body.add_child(col)


func _build_ceiling(parent: Node3D):
	var body := StaticBody3D.new()
	body.name = "Ceiling"
	body.position = Vector3(grid_width * cell_size * 0.5, ceiling_height, grid_height * cell_size * 0.5)
	parent.add_child(body)

	ceiling_material.uv1_scale = Vector3(grid_width, grid_height, 1)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(grid_width * cell_size, 0.2, grid_height * cell_size)
	box.material = ceiling_material
	mi.mesh = box
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(grid_width * cell_size, 0.1, grid_height * cell_size)
	col.shape = shape
	body.add_child(col)


func _build_walls(parent: Node3D):
	for y in range(grid_height):
		for x in range(grid_width):
			var cell: Dictionary = _grid[y][x]

			# East wall — interior walls between cells + right border
			if cell["E"]:
				var pos := Vector3((x + 1) * cell_size, ceiling_height * 0.5, (y + 0.5) * cell_size)
				var sz := Vector3(WALL_THICKNESS, ceiling_height, cell_size)
				_create_wall_segment(parent, pos, sz, "E_%d_%d" % [x, y])

			# South wall — interior walls between cells + bottom border
			if cell["S"]:
				var pos := Vector3((x + 0.5) * cell_size, ceiling_height * 0.5, (y + 1) * cell_size)
				var sz := Vector3(cell_size, ceiling_height, WALL_THICKNESS)
				_create_wall_segment(parent, pos, sz, "S_%d_%d" % [x, y])

			# Top border — only cells on row 0 need their N wall built
			if y == 0 and cell["N"]:
				var pos := Vector3((x + 0.5) * cell_size, ceiling_height * 0.5, 0)
				var sz := Vector3(cell_size, ceiling_height, WALL_THICKNESS)
				_create_wall_segment(parent, pos, sz, "N_%d_%d" % [x, y])

			# Left border — only cells on column 0 need their W wall built
			if x == 0 and cell["W"]:
				var pos := Vector3(0, ceiling_height * 0.5, (y + 0.5) * cell_size)
				var sz := Vector3(WALL_THICKNESS, ceiling_height, cell_size)
				_create_wall_segment(parent, pos, sz, "W_%d_%d" % [x, y])


func _create_wall_segment(parent: Node3D, pos: Vector3, sz: Vector3, label: String):
	var body := StaticBody3D.new()
	body.name = "Wall_" + label
	body.position = pos
	parent.add_child(body)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	box.material = wall_material
	mi.mesh = box
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz
	col.shape = shape
	body.add_child(col)


# ---------------------------------------------------------------------------
# Collectible spawning
# ---------------------------------------------------------------------------

func _multi_source_bfs(seeds: Array[Vector2i]) -> Array:
	var dist: Array = []
	for y in range(grid_height):
		dist.append([])
		for x in range(grid_width):
			dist[y].append(-1)

	var queue: Array[Vector2i] = []
	for s in seeds:
		dist[s.y][s.x] = 0
		queue.append(s)

	var front := 0
	while front < queue.size():
		var cur: Vector2i = queue[front]
		front += 1
		var next_d: int = dist[cur.y][cur.x] + 1
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)]:
			var nx: int = cur.x + d.x
			var ny: int = cur.y + d.y
			if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
				continue
			if dist[ny][nx] != -1:
				continue
			if d == Vector2i(0, -1) and _grid[cur.y][cur.x]["N"]:
				continue
			if d == Vector2i(0, 1) and _grid[cur.y][cur.x]["S"]:
				continue
			if d == Vector2i(1, 0) and _grid[cur.y][cur.x]["E"]:
				continue
			if d == Vector2i(-1, 0) and _grid[cur.y][cur.x]["W"]:
				continue
			dist[ny][nx] = next_d
			queue.append(Vector2i(nx, ny))

	return dist


func graph_distance_between(a: Vector2i, b: Vector2i) -> int:
	var dist := _multi_source_bfs([a])
	return dist[b.y][b.x]


func _select_book_cells() -> Array[Vector2i]:
	var dist_from_spawn := _multi_source_bfs([_spawn_cell])
	var candidates: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			if dist_from_spawn[y][x] < 0:
				continue
			if cell != _spawn_cell:
				candidates.append(cell)

	var selected: Array[Vector2i] = []
	var seeds: Array[Vector2i] = [_spawn_cell]

	for i in range(bone_count):
		if candidates.is_empty():
			break
		var best := _farthest_cell_from_set(candidates, seeds)
		selected.append(best)
		seeds.append(best)
		candidates.erase(best)

	return selected


func _spawn_bones():
	if not bone_scene or bone_count <= 0:
		return

	var container: Node3D = get_node_or_null("Collectibles") as Node3D
	if container:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	else:
		container = Node3D.new()
		container.name = "Collectibles"
		add_child(container)

	var selected := _select_book_cells()
	_book_cells = selected

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(selected.size()):
		var cell := selected[i]
		var bone := bone_scene.instantiate() as Node3D
		var pos := cell_to_world_position(cell)
		pos.y = 0.35
		bone.position = pos
		bone.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		container.add_child(bone)


# Spawns the single ritual altar. Preferred placement: a room at least
# altar_min_graph_distance rooms away from spawn, never the spawn room, never
# a corridor-adjacent room, never a room holding a book. Falls back to the
# farthest valid room when no room meets the preferred distance.
func _spawn_altar():
	if not altar_scene:
		return
	var dist_from_spawn := _multi_source_bfs([_spawn_cell])
	var preferred: Array[Vector2i] = []
	var valid: Array[Vector2i] = []
	var farthest: Vector2i = _spawn_cell
	var farthest_d := -1
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			if cell == _spawn_cell:
				continue
			if _book_cells.has(cell):
				continue
			var d: int = dist_from_spawn[y][x]
			if d < 2:
				continue
			valid.append(cell)
			if d >= altar_min_graph_distance:
				preferred.append(cell)
			if d > farthest_d:
				farthest_d = d
				farthest = cell
	var chosen: Vector2i
	if not preferred.is_empty():
		chosen = preferred[randi() % preferred.size()]
	else:
		chosen = farthest
	_altar_cell = chosen
	var altar := altar_scene.instantiate() as Node3D
	var pos := cell_to_world_position(chosen)
	pos.y = 1.0
	altar.position = pos
	add_child(altar)


# Selects the Note cells using farthest-point sampling over the maze graph.
# Every candidate must be walkable and excluded hotspots: the player spawn,
# any book cell, and the altar cell. Each Note is kept at least
# note_min_graph_distance graph steps from every other Note, and the next cell
# chosen is always the one that maximizes that minimum distance, which spreads
# the Notes across different areas of the maze.
func _select_note_cells() -> Array[Vector2i]:
	var selected: Array[Vector2i] = []
	if note_count <= 0:
		return selected

	var dist_from_spawn := _multi_source_bfs([_spawn_cell])
	var candidates: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			if dist_from_spawn[y][x] < 0:
				continue
			if cell == _spawn_cell:
				continue
			if _book_cells.has(cell):
				continue
			if cell == _altar_cell:
				continue
			candidates.append(cell)
	if candidates.is_empty():
		return selected

	selected.append(_farthest_cell_from_set(candidates, [_spawn_cell]))
	candidates.erase(selected[0])

	while selected.size() < note_count and not candidates.is_empty():
		var dist_from_set := _multi_source_bfs(selected)
		var best_cell: Vector2i = Vector2i(-1, -1)
		var best_min_dist := -1
		for cell in candidates:
			var d: int = dist_from_set[cell.y][cell.x]
			if d < note_min_graph_distance:
				continue
			if d > best_min_dist:
				best_min_dist = d
				best_cell = cell
		if best_cell.x == -1:
			break
		candidates.erase(best_cell)
		selected.append(best_cell)

	return selected


func _farthest_cell_from_set(candidates: Array[Vector2i], seeds: Array[Vector2i]) -> Vector2i:
	var dist := _multi_source_bfs(seeds)
	var best: Vector2i = candidates[0]
	var best_d := -1
	for cell in candidates:
		var d: int = dist[cell.y][cell.x]
		if d > best_d:
			best_d = d
			best = cell
	return best


func _spawn_notes():
	if not note_scene or note_count <= 0:
		return

	var container: Node3D = get_node_or_null("Notes") as Node3D
	if container:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	else:
		container = Node3D.new()
		container.name = "Notes"
		add_child(container)

	var selected := _select_note_cells()
	var note_data := NoteData.get_randomized_notes()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(selected.size()):
		var note := note_scene.instantiate() as Node3D
		var pos := cell_to_world_position(selected[i])
		pos.y = 0.35
		note.position = pos
		note.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		if i < note_data.size():
			note.note_id = note_data[i]["id"]
			note.note_title = note_data[i]["title"]
			note.note_text = note_data[i]["body"]
		container.add_child(note)


# Spawns environmental Rats spread across the maze using the same farthest-point
# sampling pattern as books/bones — each rat lands as far as possible from the
# player spawn and every other rat, so they don't cluster together. Rats are
# decorative scurrying elements — they wander randomly through the maze.
func _spawn_rats():
	if not rat_scene or rat_count <= 0:
		return

	var container: Node3D = get_node_or_null("Rats") as Node3D
	if container:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	else:
		container = Node3D.new()
		container.name = "Rats"
		add_child(container)

	var dist_from_spawn := _multi_source_bfs([_spawn_cell])
	var rat_candidates: Array[Vector2i] = []
	for y in range(grid_height):
		for x in range(grid_width):
			var cell := Vector2i(x, y)
			if dist_from_spawn[y][x] < 0:
				continue
			if cell != _spawn_cell:
				rat_candidates.append(cell)

	var rat_seeds: Array[Vector2i] = [_spawn_cell]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(rat_count):
		if rat_candidates.is_empty():
			break
		var best := _farthest_cell_from_set(rat_candidates, rat_seeds)
		rat_seeds.append(best)
		rat_candidates.erase(best)
		var pos := cell_to_world_position(best)
		pos.y = 0.0
		var rat := rat_scene.instantiate()
		rat.position = pos
		rat.rotation_degrees.y = rng.randf_range(0.0, 360.0)
		container.add_child(rat)
