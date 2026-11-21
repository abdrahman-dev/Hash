extends Node3D


signal books_completed
signal lives_changed(current: int)
signal player_died
signal final_hunt_started

@export var total_books: int = 6
@export var max_lives: int = 3
@export var final_hunt_duration: float = 60.0

var _books_collected: int = 0
var _current_lives: int
var _monster: Node3D
var _death_in_progress: bool = false
var _death_rig: DeathCam = null
var _killer_dir := Vector3.FORWARD
var _final_hunt_active: bool = false
var _final_hunt_timer: Timer
var _final_hunt_countdown_label: Label
var _final_hunt_message_anchor: Control
var _music: AudioStreamPlayer


func _ready():
	GameState.max_lives = max_lives
	_current_lives = GameState.lives
	_music = AudioStreamPlayer.new()
	var stream := AudioStreamWAV.new()
	stream = preload("res://Sounds/Theme/remnant_theme.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_PINGPONG
	stream.loop_begin = 0
	stream.loop_end = stream.get_length() * 44100  # sample count not seconds
	_music.stream = stream
	_music.volume_db = GameState.music_volume
	_music.bus = "Master"
	_music.add_to_group("bg_music")
	add_child(_music)
	_music.play()
	call_deferred("_wire_monster")
	call_deferred("_update_lives_ui")
	call_deferred("_update_book_ui")


# The monster kills in one touch. Death begins immediately — at the same
# moment it catches the player — so the scream, red flash, control lock and
# the detached falling camera all start together instead of waiting for the
# 0.4s damage flash to finish first.
func _on_player_caught(monster: Node3D, player: Node3D):
	if _death_in_progress:
		return
	_death_in_progress = true

	var dir := (player.global_position - monster.global_position)
	if dir.length_squared() > 0.001:
		_killer_dir = Vector3(dir.x, 0.0, dir.z).normalized()

	player_died.emit()
	lose_life()

	if player.has_method("trigger_damage_effect"):
		player.trigger_damage_effect()
	if player.has_method("begin_death_sequence"):
		var rig: DeathCam = player.begin_death_sequence(_killer_dir)
		if rig:
			rig.sequence_done.connect(_on_death_sequence_done.bind(rig), CONNECT_ONE_SHOT)
			return

	# Fallback: if the death camera could not be detached, show the screen now.
	# _death_in_progress stays true so the flash tail's damage_completed is a no-op.
	_show_death_screen()


# The damage flash's 0.4s tail still emits damage_completed afterwards; keep it
# as a guarded dead-end so the death sequence can never be double-triggered.
func _on_damage_completed():
	if _death_in_progress:
		return
	_death_in_progress = true
	_show_death_screen()


func _on_death_sequence_done(rig: DeathCam):
	_death_rig = rig
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


func _show_death_screen(force_game_over: bool = false):
	var game_over := force_game_over or _current_lives <= 0

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
	title.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "DeathSubtitle"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	subtitle.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
	subtitle.add_theme_font_size_override("font_size", 20)
	vbox.add_child(subtitle)

	if game_over:
		subtitle.text = "GAME OVER"
		subtitle.add_theme_font_size_override("font_size", 28)
	else:
		subtitle.text = "LIVES REMAINING: %d" % _current_lives

	var tw := cl.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(func(): get_tree().paused = true)
	tw.tween_property(fade, "color", Color(0, 0, 0, 1), 0.8)
	if game_over:
		tw.tween_interval(4.0)
		tw.tween_callback(_game_over_to_menu)
	else:
		tw.tween_interval(1.5)
		tw.tween_callback(_finish_death_sequence)


func _game_over_to_menu():
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.MAIN_MENU_SCENE)


func _finish_death_sequence():
	_death_in_progress = false
	if _death_rig and is_instance_valid(_death_rig):
		_death_rig.release_camera()
		_death_rig = null
	var player := get_node_or_null("Player")
	var monster := get_node_or_null("Monster")
	if monster and monster.has_method("reset_to_spawn"):
		monster.reset_to_spawn()
	if player and player.has_method("respawn"):
		player.respawn()
	if _monster and _monster.has_method("reset_final_hunt"):
		_monster.reset_final_hunt()
	if _final_hunt_active:
		_start_final_hunt_timer()
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

	var altar := maze.get_node_or_null("Altar")
	if altar and altar.has_signal("ritual_completed"):
		altar.ritual_completed.connect(_on_ritual_completed)


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
		_start_final_hunt()


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


func _process(_delta: float):
	if not _final_hunt_active:
		return
	_update_countdown_label()


# FINAL HUNT: starts the 60s countdown the moment the 6th book is collected,
# shows the altar message, forces the monster into persistent hunt mode and
# arms the countdown timer.
func _start_final_hunt():
	if _final_hunt_active:
		return
	_final_hunt_active = true
	_create_final_hunt_ui()
	_show_final_hunt_message()
	final_hunt_started.emit()
	_start_final_hunt_timer()


func _start_final_hunt_timer():
	if not _final_hunt_timer:
		_final_hunt_timer = Timer.new()
		_final_hunt_timer.name = "FinalHuntTimer"
		_final_hunt_timer.one_shot = true
		_final_hunt_timer.timeout.connect(_on_final_hunt_timeout)
		add_child(_final_hunt_timer)
	_final_hunt_timer.start(final_hunt_duration)


func _stop_final_hunt_timer():
	if _final_hunt_timer:
		_final_hunt_timer.stop()


func _on_final_hunt_timeout():
	if not _final_hunt_active:
		return
	if _monster and _monster.has_method("force_hunt_mode"):
		_monster.force_hunt_mode()


# Stopped and hidden as soon as the altar ritual completes; victory then
# proceeds normally through altar.gd.
func _on_ritual_completed():
	if not _final_hunt_active:
		return
	_final_hunt_active = false
	_stop_final_hunt_timer()
	_hide_final_hunt_ui()


func _create_final_hunt_ui():
	var game_ui := _get_game_ui()
	if not game_ui:
		push_warning("game_manager: GameUI not found — final hunt countdown skipped")
		return
	if game_ui.has_node("FinalHuntCountdownAnchor"):
		return

	var anchor := Control.new()
	anchor.name = "FinalHuntCountdownAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.anchor_left = 0.5
	anchor.anchor_right = 0.5
	anchor.anchor_top = 0.0
	anchor.anchor_bottom = 0.0
	anchor.offset_left = -160.0
	anchor.offset_right = 160.0
	anchor.offset_top = 10.0
	anchor.offset_bottom = 70.0
	game_ui.add_child(anchor)

	var center := CenterContainer.new()
	center.name = "FinalHuntCountdownCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.name = "FinalHuntCountdown"
	label.text = _format_final_hunt_time(final_hunt_duration)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
	label.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 32)
	center.add_child(label)
	_final_hunt_countdown_label = label

	var ui_shader := game_ui.get_node_or_null("UIShader")
	if ui_shader:
		game_ui.move_child(anchor, ui_shader.get_index())


func _show_final_hunt_message():
	if _final_hunt_message_anchor and is_instance_valid(_final_hunt_message_anchor):
		return
	var game_ui := _get_game_ui()
	if not game_ui:
		return

	var anchor := Control.new()
	anchor.name = "FinalHuntMessageAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.anchor_left = 0.5
	anchor.anchor_top = 0.65
	anchor.anchor_right = 0.5
	anchor.anchor_bottom = 0.65
	anchor.offset_left = -320.0
	anchor.offset_top = -30.0
	anchor.offset_right = 320.0
	anchor.offset_bottom = 30.0
	game_ui.add_child(anchor)
	_final_hunt_message_anchor = anchor

	var center := CenterContainer.new()
	center.name = "FinalHuntMessageCenter"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var label := Label.new()
	label.name = "FinalHuntMessage"
	label.text = "Find the altar... NOW."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	label.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
	label.add_theme_font_size_override("font_size", 24)
	label.modulate.a = 0.0
	center.add_child(label)

	var ui_shader := game_ui.get_node_or_null("UIShader")
	if ui_shader:
		game_ui.move_child(anchor, ui_shader.get_index())

	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.0)
	tw.tween_property(label, "modulate:a", 0.0, 0.75)
	tw.tween_callback(func():
		if is_instance_valid(anchor):
			anchor.queue_free()
		if _final_hunt_message_anchor == anchor:
			_final_hunt_message_anchor = null
	)


func _hide_final_hunt_ui():
	if _final_hunt_countdown_label and is_instance_valid(_final_hunt_countdown_label):
		_final_hunt_countdown_label.visible = false
	if _final_hunt_message_anchor and is_instance_valid(_final_hunt_message_anchor):
		_final_hunt_message_anchor.queue_free()
		_final_hunt_message_anchor = null


func _update_countdown_label():
	if not _final_hunt_countdown_label or not is_instance_valid(_final_hunt_countdown_label):
		return
	if not _final_hunt_timer:
		return
	_final_hunt_countdown_label.text = _format_final_hunt_time(_final_hunt_timer.time_left)


func _format_final_hunt_time(seconds: float) -> String:
	var remaining := int(ceil(seconds))
	return "%02d:%02d" % [remaining / 60, remaining % 60]


func _get_game_ui() -> CanvasLayer:
	var player := get_node_or_null("Player")
	if not player:
		return null
	return player.get_node_or_null("GameUI") as CanvasLayer


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
