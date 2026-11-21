extends Area3D

@export var stab_sound_path: String = "res://Sounds/hurt.mp3"


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_interact_knife"):
			body.set_interact_knife(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("clear_interact_knife"):
			body.clear_interact_knife(self)
