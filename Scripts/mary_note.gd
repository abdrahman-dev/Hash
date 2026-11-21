extends Area3D


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("set_interact_mary_note"):
			body.set_interact_mary_note(self)


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		if body.has_method("clear_interact_mary_note"):
			body.clear_interact_mary_note(self)
