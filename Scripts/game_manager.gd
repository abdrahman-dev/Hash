extends Node3D


signal books_completed
signal lives_changed(current: int)
signal player_died

@export var total_books: int = 6
@export var max_lives: int = 3

var _books_collected: int = 0
var _current_lives: int
var _monster: Node3D


func _ready():
	GameState.max_lives = max_lives
	_current_lives = GameState.lives
	call_deferred("_wire_monster")
	call_deferred("_update_lives_ui")
	call_deferred("_update_book_ui")


func _on_player_caught(monster: Node3D, player: Node3D):
	if player.has_method("trigger_damage_effect"):
		player.trigger_damage_effect()


func _on_damage_completed():
	player_died.emit()
	lose_life()
	_show_death_screen()


func lose_life():
	if _current_lives <= 0:
		return
	_current_lives -= 1
	GameState.lives = _current_lives
	lives_changed.emit(_current_lives)
	_update_lives_ui()


func _update_lives_ui():
	var ui := get_node_or_null("Player/GameUI/LivesUI") as Label
	if ui and ui.has_method("set_lives"):
		ui.set_lives(_current_lives)


func _show_death_screen():
	var cl := CanvasLayer.new()
	cl.name = "DeathLayer"
	cl.layer = 10
	cl.process_mode = PROCESS_MODE_ALWAYS
	add_child(cl)

	var fade := ColorRect.new()
	fade.name = "DeathFade"
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0, 0, 0, 0)
	cl.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "DeathCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "DeathVBox"
	center.add_child(vbox)

	var title := Label.new()
	title.name = "DeathTitle"
	title.text = "YOU DIED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "DeathSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	subtitle.add_theme_font_size_override("font_size", 20)
	vbox.add_child(subtitle)

	if _current_lives <= 0:
		subtitle.text = "GAME OVER"
		subtitle.add_theme_font_size_override("font_size", 28)
	else:
		subtitle.text = "LIVES REMAINING: %d" % _current_lives

	var tw := cl.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(func(): get_tree().paused = true)
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), 0.8)
	if _current_lives <= 0:
		tw.tween_interval(4.0)
		tw.tween_callback(_game_over_to_menu)
	else:
		tw.tween_interval(1.5)
		tw.tween_callback(_finish_death_sequence)


func _game_over_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.MAIN_MENU_SCENE)


func _finish_death_sequence():
	var player := get_node_or_null("Player")
	var monster := get_node_or_null("Monster")
	if monster and monster.has_method("reset_to_spawn"):
		monster.reset_to_spawn()
	if player and player.has_method("respawn"):
		player.respawn()
	get_tree().paused = false
	var cl := get_node_or_null("DeathLayer") as CanvasLayer
	if cl:
		var fade := cl.get_node_or_null("DeathFade") as ColorRect
		var tw := cl.create_tween()
		if fade:
			tw.tween_property(fade, "color", Color(0, 0, 0, 0), 0.5)
		tw.tween_callback(cl.queue_free)


func _wire_monster():
	var maze := get_node_or_null("Maze")
	if not maze:
		push_warning("game_manager: Maze node not found under root")
		return

	var monster := get_node_or_null("Monster")
	if not monster:
		push_warning("game_manager: Monster node not found under root — instance res://Scenes/monster.tscn as a sibling of Maze")
		return

	if not monster.has_method("build_navigation"):
		push_warning("game_manager: Monster node lacks monster_ai.gd")
		return

	_monster = monster
	monster.build_navigation(maze)
	if monster.has_method("set_difficulty"):
		monster.set_difficulty(_books_collected)

	if monster.get("target_player") == null or monster.get("target_player").is_empty():
		monster.set("target_player", NodePath("../Player"))
	if monster.has_method("spawn_far_from_player"):
		monster.spawn_far_from_player()

	var player := get_node_or_null("Player")
	if not player:
		return
	if player.has_method("trigger_scream_shake"):
		monster.scream_started.connect(player.trigger_scream_shake)
	if player.has_method("start_heartbeat"):
		monster.chase_started.connect(player.start_heartbeat.bind(monster))
		monster.chase_ended.connect(player.stop_heartbeat)
	if player.has_method("trigger_damage_effect"):
		monster.player_caught.connect(_on_player_caught.bind(monster, player))
		player.damage_completed.connect(_on_damage_completed)


# TODO: When the maze regenerates at runtime (e.g. via a debug key or
# level transition, call monster.rebuild_navigation() alongside
# maze.regenerate_maze() to keep the AStar2D graph in sync.


func _on_book_collected(_book_node: Node3D):
	_books_collected += 1
	_update_book_ui()
	_play_book_sound()
	if _monster and _monster.has_method("set_difficulty"):
		_monster.set_difficulty(_books_collected)
	if _books_collected >= total_books:
		books_completed.emit()
		_play_completion_sound()
		_trigger_final_phase()


func _update_book_ui():
	var ui := get_node_or_null("Player/GameUI/BookUI") as Label
	if not ui:
		return
	if _books_collected >= total_books:
		if ui.has_method("set_objective"):
			ui.set_objective()
	else:
		if ui.has_method("set_count"):
			ui.set_count(_books_collected, total_books)


func _trigger_final_phase():
	if _monster and _monster.has_method("trigger_final_phase"):
		_monster.trigger_final_phase()
	var cl := CanvasLayer.new()
	cl.name = "FinalPhaseLayer"
	cl.layer = 9
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(cl)
	var flash := ColorRect.new()
	flash.name = "FinalPhaseFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.5, 0.0, 0.0, 0.0)
	cl.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.5, 0.0, 0.0, 0.4)
	var tw := cl.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 2.0)
	tw.tween_callback(cl.queue_free)


func _play_book_sound():
	var player := get_node_or_null("Player")
	if not player:
		return
	var audio := player.get_node_or_null("Horrorsting") as AudioStreamPlayer
	if audio and not audio.playing:
		audio.volume_db = -15.0
		audio.play()


func _play_completion_sound():
	var player := get_node_or_null("Player")
	if not player:
		return
	var audio := player.get_node_or_null("Sand") as AudioStreamPlayer
	if audio and not audio.playing:
		audio.volume_db = 8.0
		audio.play()
		var tween := create_tween()
		tween.tween_property(audio, "volume_db", -80.0, 0.8).set_ease(Tween.EASE_IN)
		tween.tween_callback(audio.stop)
