extends Control


var _stamina_bar: ProgressBar = null
var _player: Node = null


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bar = get_node_or_null("../StaminaBar") as ProgressBar
	call_deferred("_setup_player")


func _process(_delta):
	if _player == null or _stamina_bar == null:
		return
	if "current_stamina" not in _player or "max_stamina" not in _player:
		return
	var ratio := clampf(float(_player.current_stamina) / float(_player.max_stamina), 0.0, 1.0)
	_stamina_bar.value = ratio * 100.0


func _setup_player():
	_player = get_tree().get_first_node_in_group("player")
