extends Node3D

@onready var idle_anim = $Idle
@onready var scream_anim = $Scream
@onready var screams = [$ScreamVoice/Scream1, $ScreamVoice/Scream2, $ScreamVoice/Scream3]

func _ready():
	idle_anim.play("idle")

func play_scream():
	idle_anim.stop()
	scream_anim.play("scream")
	screams[randi() % 3].play()
