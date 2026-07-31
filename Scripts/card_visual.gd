extends Node3D


signal card_picked_up


@export var spin_speed: float = 1.0
@export var bob_amplitude: float = 0.15
@export var bob_speed: float = 2.0
@export var particle_amount: int = 12


var _initial_position: Vector3
var _bob_time: float = 0.0
var _triggered: bool = false


func _ready():
	_initial_position = position
	_ensure_mesh_instance()
	_ensure_particles()
	_ensure_area()


func _process(delta: float):
	_bob_time += delta * bob_speed
	position.y = _initial_position.y + sin(_bob_time) * bob_amplitude
	if has_node("MeshInstance3D"):
		$MeshInstance3D.rotate_y(spin_speed * delta)


func _ensure_mesh_instance():
	var mi: MeshInstance3D
	if has_node("MeshInstance3D"):
		mi = $MeshInstance3D as MeshInstance3D
	else:
		mi = MeshInstance3D.new()
		mi.name = "MeshInstance3D"
		add_child(mi)

	var mesh := mi.mesh as QuadMesh
	if not mesh:
		mesh = QuadMesh.new()
		mesh.size = Vector2(0.6, 0.84)
		mi.mesh = mesh

	var mat := mi.material_override as StandardMaterial3D
	if not mat:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.05, 0.05)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = mat


func _ensure_particles():
	var particles: GPUParticles3D
	if has_node("CardParticles"):
		particles = $CardParticles as GPUParticles3D
	else:
		particles = GPUParticles3D.new()
		particles.name = "CardParticles"
		add_child(particles)

	particles.amount = particle_amount
	particles.one_shot = false
	particles.lifetime = 1.5
	particles.local_coords = true

	var mat := particles.process_material as ParticleProcessMaterial
	if not mat:
		mat = ParticleProcessMaterial.new()
		particles.process_material = mat

	mat.color = Color(0.85, 0.05, 0.05)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 45.0
	mat.gravity = Vector3(0, -0.3, 0)
	mat.initial_velocity_min = 0.2
	mat.initial_velocity_max = 0.5
	mat.scale_min = 0.03
	mat.scale_max = 0.08
	mat.lifetime_randomness = 0.3

	particles.emitting = true


func _ensure_area():
	var area: Area3D
	if has_node("PickupArea"):
		area = $PickupArea as Area3D
	else:
		area = Area3D.new()
		area.name = "PickupArea"
		add_child(area)

	var shape_node: CollisionShape3D
	if area.has_node("CollisionShape3D"):
		shape_node = area.get_node("CollisionShape3D") as CollisionShape3D
	else:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		area.add_child(shape_node)

	var box := shape_node.shape as BoxShape3D
	if not box:
		box = BoxShape3D.new()
		box.size = Vector3(1.2, 1.5, 1.2)
		shape_node.shape = box

	area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node):
	if _triggered:
		return
	if not body.is_in_group("player"):
		return
	_triggered = true
	card_picked_up.emit()
	_placeholder_open()


func _placeholder_open():
	get_tree().paused = true

	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 1.0
	timer.process_mode = Node.PROCESS_MODE_ALWAYS
	timer.timeout.connect(_on_cleanup_timeout)
	add_child(timer)
	timer.start()


func _on_cleanup_timeout():
	if not is_instance_valid(self):
		return
	get_tree().paused = false
	queue_free()
