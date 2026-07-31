extends Area3D


var _collected: bool = false

@export var hover_height := 2.0
@export var float_height := 0.25
@export var float_speed := 1.8

@export var rotate_speed_y := 28.0
@export var rotate_speed_x := 8.0
@export var rotate_speed_z := 5.0


func _ready():
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _collected:
		return
	var t := Time.get_ticks_msec() / 1000.0
	position.y = hover_height + sin(t * float_speed) * float_height
	rotate_x(deg_to_rad(rotate_speed_x * delta))
	rotate_y(deg_to_rad(rotate_speed_y * delta))
	rotate_z(deg_to_rad(rotate_speed_z * delta))


func _on_body_entered(body: Node):
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	_play_collect_animation()


func _play_collect_animation():
	$CollisionShape3D.disabled = true

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0, -0.5, 0), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + deg_to_rad(720), 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.8)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var light := $OmniLight3D as OmniLight3D
	if light:
		tween.tween_property(light, "light_energy", light.light_energy * 3.0, 0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(light, "light_energy", 0.0, 0.4).set_delay(0.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	tween.chain()
	tween.tween_callback(_finish_collection)


func _finish_collection():
	var manager := get_tree().current_scene
	if manager and manager.has_method("_on_book_collected"):
		manager._on_book_collected(self)
	queue_free()
