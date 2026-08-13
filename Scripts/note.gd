extends Area3D

@export var note_id: String = ""
@export var note_title: String = "Test Note"
@export var note_text: String = "This is a temporary test note."

@export var hover_height := 2.0
@export var float_height := 0.25
@export var float_speed := 1.8

@export var rotate_speed_y := 28.0
@export var rotate_speed_x := 8.0
@export var rotate_speed_z := 5.0


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	position.y = hover_height + sin(t * float_speed) * float_height
	rotate_x(deg_to_rad(rotate_speed_x * delta))
	rotate_y(deg_to_rad(rotate_speed_y * delta))
	rotate_z(deg_to_rad(rotate_speed_z * delta))


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_interact_note"):
			body.set_interact_note(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("clear_interact_note"):
			body.clear_interact_note(self)
