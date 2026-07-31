extends Control


var _stamina_ratio: float = 0.0
var _threshold: float = 25.0

const RING_RADIUS := 22.0
const RING_WIDTH := 3.0
const RING_POINTS := 40


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_setup_player")


func _setup_player():
	var player := get_tree().get_first_node_in_group("player")
	if not player:
		push_warning("StaminaCrosshairUI: player not found in group \"player\"")
		return
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	if "stamina_recover_threshold" in player:
		_threshold = player.stamina_recover_threshold
	if player.has_method("get_stamina_ratio"):
		_stamina_ratio = player.get_stamina_ratio()
	queue_redraw()


func _on_stamina_changed(current: float, max: float):
	var new_ratio := current / max if max > 0 else 0.0
	if not is_equal_approx(new_ratio, _stamina_ratio):
		_stamina_ratio = new_ratio
		queue_redraw()


func _draw():
	var center := get_viewport_rect().size / 2.0
	var white := Color(1.0, 1.0, 1.0, 0.85)
	var cross_len := 5.0
	var cross_width := 1.5

	draw_line(center + Vector2(-cross_len, 0), center + Vector2(cross_len, 0), white, cross_width)
	draw_line(center + Vector2(0, -cross_len), center + Vector2(0, cross_len), white, cross_width)

	if _stamina_ratio > 0.001:
		var green := Color(0.723, 0.85, 0.723, 1.0)
		var orange := Color(1.0, 0.459, 0.411, 1.0)
		var ring_color := green if _stamina_ratio > _threshold / 100.0 else orange
		var start_angle := -PI / 2.0
		var end_angle := start_angle + TAU * _stamina_ratio
		draw_arc(center, RING_RADIUS, start_angle, end_angle, RING_POINTS, ring_color, RING_WIDTH, true)
