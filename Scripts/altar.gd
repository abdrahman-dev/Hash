extends Node3D


const RITUAL_DURATION: float = 5.0

@export var hint_display_time: float = 2.0

var _manager: Node = null
var _player: Node = null
var _player_inside: bool = false
var _ritual_active: bool = false
var _ritual_completed: bool = false
var _ritual_time: float = 0.0
var _hint_active: bool = false


func _ready():
	$RitualArea.body_entered.connect(_on_body_entered)
	$RitualArea.body_exited.connect(_on_body_exited)
	_randomize_hum()
	call_deferred("_wire_manager")


func _randomize_hum():
	var hum := get_node_or_null("RitualHum") as AudioStreamPlayer3D
	if not hum:
		push_warning("altar: RitualHum not found")
		return
	hum.pitch_scale = randf_range(0.98, 1.02)
	if not hum.playing:
		hum.play()


func _wire_manager():
	if not _manager:
		_manager = get_tree().current_scene
	if not _manager:
		push_warning("altar: current scene not available")
		return
	if _manager.has_signal("player_died"):
		_manager.player_died.connect(_on_player_died)
	if _manager.has_signal("books_completed"):
		_manager.books_completed.connect(_on_books_completed)


func _process(delta: float):
	if not _ritual_active:
		return
	_ritual_time += delta
	if _ritual_time >= RITUAL_DURATION:
		_complete_ritual()
		return
	_update_ritual_ui(_ritual_time / RITUAL_DURATION)


func _on_body_entered(body: Node):
	if _ritual_completed:
		return
	if not body.is_in_group("player"):
		return
	_player = body
	_player_inside = true
	_try_start_ritual()


func _on_body_exited(body: Node):
	if not body.is_in_group("player"):
		return
	_player_inside = false
	if _ritual_active:
		_cancel_ritual()


func _on_books_completed():
	_boost_hum_beacon()
	if _player_inside and not _ritual_active and not _ritual_completed:
		_try_start_ritual()


func _boost_hum_beacon():
	var hum := get_node_or_null("RitualHum") as AudioStreamPlayer3D
	if not hum:
		return
	hum.volume_db = -2.0
	hum.max_distance = 100.0
	hum.unit_size = 7.0


func _try_start_ritual():
	if _ritual_active or _ritual_completed:
		return
	var books: int = _manager._books_collected if _manager else 0
	var total: int = _manager.total_books if _manager else 6
	if books >= total:
		_start_ritual()
	else:
		_show_hint()


func _start_ritual():
	_ritual_active = true
	_ritual_time = 0.0
	if _player and _player.has_method("set_ritual_locked"):
		_player.set_ritual_locked(true)
	_update_ritual_ui(0.0)


func _cancel_ritual():
	if not _ritual_active:
		return
	_ritual_active = false
	if _player and _player.has_method("set_ritual_locked"):
		_player.set_ritual_locked(false)
	_restore_objective_ui()


func _complete_ritual():
	_ritual_active = false
	_ritual_completed = true
	$RitualArea.monitoring = false
	if _player and _player.has_method("set_ritual_locked"):
		_player.set_ritual_locked(false)
	_restore_objective_ui()
	_show_victory()


func _on_player_died():
	_cancel_ritual()


func _update_ritual_ui(progress: float):
	var ui := _get_book_ui()
	if ui and ui.has_method("set_ritual"):
		ui.set_ritual(progress)


func _restore_objective_ui():
	var ui := _get_book_ui()
	if ui and ui.has_method("set_objective"):
		ui.set_objective()


func _get_book_ui() -> Node:
	if not _manager:
		return null
	var player := _manager.get_node_or_null("Player")
	if not player:
		return null
	return player.get_node_or_null("GameUI/BookUI")


func _get_game_ui() -> Node:
	if not _manager:
		return null
	var player := _manager.get_node_or_null("Player")
	if not player:
		return null
	return player.get_node_or_null("GameUI")


func _show_hint():
	if _hint_active:
		return
	var game_ui := _get_game_ui()
	if not game_ui:
		push_warning("altar: GameUI not found — hint skipped")
		return
	_hint_active = true

	var anchor := Control.new()
	anchor.name = "HintAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.anchor_left = 0.5
	anchor.anchor_top = 0.5
	anchor.anchor_right = 0.5
	anchor.anchor_bottom = 0.5
	anchor.offset_left = -320.0
	anchor.offset_top = 70.0
	anchor.offset_right = 320.0
	anchor.offset_bottom = 130.0
	game_ui.add_child(anchor)

	var center := CenterContainer.new()
	center.name = "HintCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.name = "HintLabel"
	label.text = "COLLECT ALL 6 CURSED BOOKS FIRST"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	label.add_theme_font_size_override("font_size", 20)
	label.modulate.a = 0.0
	center.add_child(label)

	var ui_shader := game_ui.get_node_or_null("UIShader")
	if ui_shader:
		game_ui.move_child(anchor, ui_shader.get_index())

	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(hint_display_time)
	tw.tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		_hint_active = false
		if is_instance_valid(anchor):
			anchor.queue_free()
	)


func _show_victory():
	get_tree().paused = true
	var cl := CanvasLayer.new()
	cl.name = "VictoryLayer"
	cl.layer = 10
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)

	var fade := ColorRect.new()
	fade.name = "VictoryFade"
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "VictoryCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "VictoryVBox"
	center.add_child(vbox)

	var title := Label.new()
	title.name = "VictoryTitle"
	title.text = "THE RITUAL IS COMPLETE"
	title.visible = false
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "VictorySubtitle"
	subtitle.text = "THE CURSE HAS BEEN LIFTED"
	subtitle.visible = false
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	subtitle.add_theme_font_size_override("font_size", 20)
	vbox.add_child(subtitle)

	var tw := cl.create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	tw.tween_interval(0.5)
	tw.tween_callback(func():
		title.visible = true
		subtitle.visible = true
	)
	tw.tween_interval(3.7)
	tw.tween_callback(_end_victory)


func _end_victory():
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.MAIN_MENU_SCENE)
