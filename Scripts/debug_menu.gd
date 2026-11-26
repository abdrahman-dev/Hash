extends CanvasLayer

# Temporary in-game debug menu (F1). Everything is built from code and lives in
# this one file. It only activates inside world.tscn on a debug build. To remove
# it entirely, delete this file, the single registration line in game_manager.gd
# and every line marked "# DEBUG_HOOK".

const FONT_PATH := "res://Fonts/IMFellEnglish-Regular.ttf"
const PANEL_SIZE := Vector2(440, 620)
const PANEL_MARGIN := Vector2(16, 16)
const FLY_SPEED := 10.0
const FLY_FAST_SPEED := 24.0

var _root: Node = null
var _player: CharacterBody3D = null
var _monster: CharacterBody3D = null
var _maze: Node3D = null
var _manager: Node = null
var _altar: Node3D = null
var _books: Node3D = null
var _rats: Node3D = null

var _backdrop: Control = null
var _panel: PanelContainer = null
var _info_label: Label = null
var _label_3d: Label3D = null

var _walk_slider: HSlider = null
var _sprint_slider: HSlider = null
var _lives_slider: HSlider = null
var _usage_slider: HSlider = null
var _books_slider: HSlider = null
var _monster_speed_slider: HSlider = null
var _difficulty_slider: HSlider = null

var _fly_check: CheckButton = null

var _open: bool = false
var _saved_control_locked: bool = false

var _fly_mode: bool = false
var _saved_collision_layer: int = 0
var _saved_collision_mask: int = 0

var _walk_base_speed: float = 0.0
var _run_base_speed: float = 0.0

var _saved_stamina_drain: float = 0.0
var _infinite_stamina: bool = false

var _monster_defaults: Dictionary = {}
var _monster_frozen: bool = false
var _ignore_player: bool = false
var _debug_draw: bool = false

var _books_dragging: bool = false
var _lives_dragging: bool = false
var _usage_dragging: bool = false
var _setting_books: bool = false


func _ready():
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_init_menu")


func _init_menu():
	if not OS.is_debug_build():
		queue_free()
		return

	_root = get_tree().current_scene
	if _root == null:
		queue_free()
		return
	var path: String = _root.scene_file_path
	if not path.ends_with("world.tscn") and _root.name != "World":
		queue_free()
		return

	_manager = _root
	_player = _root.get_node_or_null("Player") as CharacterBody3D
	_monster = _root.get_node_or_null("Monster") as CharacterBody3D
	_maze = _root.get_node_or_null("Maze") as Node3D
	if _maze:
		_altar = _maze.get_node_or_null("Altar") as Node3D
		_books = _maze.get_node_or_null("Collectibles") as Node3D
		_rats = _maze.get_node_or_null("Rats") as Node3D

	if _player:
		_walk_base_speed = float(_player.get("walk_speed"))
		_run_base_speed = float(_player.get("run_speed"))
		_saved_stamina_drain = float(_player.get("stamina_drain_rate"))

	if _monster:
		_capture_monster_defaults()

	_build_ui()
	_update_info()


func _capture_monster_defaults():
	_monster_defaults = {
		"wander_speed": _monster.get("wander_speed"),
		"hunt_speed": _monster.get("hunt_speed"),
		"detection_range": _monster.get("detection_range"),
		"give_up_delay": _monster.get("give_up_delay"),
		"scream_duration": _monster.get("scream_duration"),
		"path_refresh_interval": _monster.get("path_refresh_interval"),
		"wander_pause_range": _monster.get("wander_pause_range"),
	}


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent):
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_F1 or key_event.physical_keycode == KEY_F1:
		_set_open(not _open)
		get_viewport().set_input_as_handled()
	elif key_event.keycode == KEY_F2 or key_event.physical_keycode == KEY_F2:
		_set_fly(not _fly_mode)
		get_viewport().set_input_as_handled()


func _set_open(open: bool):
	if _backdrop == null:
		return
	if _open == open:
		return
	_open = open
	if _backdrop:
		_backdrop.visible = open

	if _player:
		if open:
			_saved_control_locked = bool(_player.get("_control_locked"))
			_player.set("_control_locked", true)
		else:
			_player.set("_control_locked", _saved_control_locked)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED)
	if open:
		_update_info()


# ---------------------------------------------------------------------------
# Process
# ---------------------------------------------------------------------------

func _process(delta: float):
	if _root == null:
		return
	if _debug_draw:
		_update_debug_draw()
	if _open:
		# Keep the player locked while the panel is open even if a respawn
		# cleared the flag in the meantime.
		if _player and not bool(_player.get("_control_locked")):
			_player.set("_control_locked", true)
		_update_info()
	if _fly_mode and not _open:
		_update_fly(delta)


func _update_fly(delta: float):
	if _player == null:
		return
	if bool(_player.get("_death_active")):
		return
	var cam := _player.get("camera") as Camera3D
	if cam == null:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var basis := cam.global_transform.basis
	var dir: Vector3 = basis.x * input_dir.x + basis.z * input_dir.y

	var vertical := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		vertical += 1.0
	if Input.is_key_pressed(KEY_CTRL):
		vertical -= 1.0
	dir += Vector3.UP * vertical

	if dir.length_squared() < 0.0001:
		return
	var speed := FLY_FAST_SPEED if Input.is_action_pressed("sprint") else FLY_SPEED
	_player.global_position += dir.normalized() * speed * delta


func _set_fly(enabled: bool):
	if _fly_mode == enabled:
		return
	_fly_mode = enabled
	if _fly_check:
		_fly_check.set_pressed_no_signal(enabled)
	if _player == null:
		return

	if enabled:
		_saved_collision_layer = _player.collision_layer
		_saved_collision_mask = _player.collision_mask
		_player.collision_layer = 0
		_player.collision_mask = 0
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(false)
	else:
		_player.collision_layer = _saved_collision_layer
		_player.collision_mask = _saved_collision_mask
		_player.velocity = Vector3.ZERO
		_player.set_physics_process(true)


# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _build_ui():
	_backdrop = Control.new()
	_backdrop.name = "DebugBackdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	add_child(_backdrop)

	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.position = PANEL_MARGIN
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.theme = _build_theme()
	_panel.add_theme_stylebox_override("panel", _build_panel_style())
	_backdrop.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 4)
	margin.add_child(root_box)

	var title := Label.new()
	title.text = "DEBUG MENU"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.88, 0.82, 0.62))
	root_box.add_child(title)

	var hint := Label.new()
	hint.text = "F1 close   |   F2 noclip/fly   |   game keeps running"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.66, 0.66, 0.66))
	root_box.add_child(hint)

	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 13)
	_info_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.96))
	_info_label.custom_minimum_size = Vector2(380, 110)
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_label.clip_text = true
	root_box.add_child(_info_label)

	root_box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.name = "DebugScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 420)
	root_box.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	scroll.add_child(content)

	_build_player_section(content)
	content.add_child(HSeparator.new())
	_build_books_section(content)
	content.add_child(HSeparator.new())
	_build_monster_section(content)
	content.add_child(HSeparator.new())
	_build_rats_section(content)


func _build_player_section(parent: VBoxContainer):
	_add_section(parent, "PLAYER")

	_fly_check = _add_check(parent, "Noclip / Fly (F2)", _on_fly_toggled)

	_walk_slider = _add_slider(parent, "Walk speed", 0.25, 4.0, 0.05, 1.0, 2, "x", _on_walk_changed)
	_sprint_slider = _add_slider(parent, "Sprint speed", 0.25, 4.0, 0.05, 1.0, 2, "x", _on_sprint_changed)

	_add_check(parent, "Infinite stamina", _on_infinite_stamina_toggled)
	_add_check(parent, "Invincible", _on_invincible_toggled)

	var start_lives := 3
	if _manager:
		start_lives = int(_manager.get("_current_lives"))
	_lives_slider = _add_slider(parent, "Lives", 1, 5, 1, float(start_lives), 0, "", _on_lives_changed)
	_lives_slider.drag_started.connect(func(): _lives_dragging = true)
	_lives_slider.drag_ended.connect(func(_changed: bool): _lives_dragging = false)

	var teleport_row := _add_button_row(parent)
	_add_button(teleport_row, "To altar", _teleport_to_altar)
	_add_button(teleport_row, "To random book", _teleport_to_random_book)
	_add_button(teleport_row, "To start", _teleport_to_start)

	_add_button(parent, "Reset flashlight", _reset_flashlight)
	var start_usage := 0.0
	if _player:
		start_usage = float(_player.get("_flashlight_usage_time"))
	_usage_slider = _add_slider(parent, "Flashlight usage", 0.0, 400.0, 1.0, start_usage, 0, "s", _on_usage_changed)
	_usage_slider.drag_started.connect(func(): _usage_dragging = true)
	_usage_slider.drag_ended.connect(func(_changed: bool): _usage_dragging = false)


func _build_books_section(parent: VBoxContainer):
	_add_section(parent, "BOOKS & OBJECTIVES")

	var start_books := 0
	if _manager:
		start_books = int(_manager.get("_books_collected"))
	_books_slider = _add_slider(parent, "Collected books", 0, 6, 1, float(start_books), 0, "", _on_books_changed)
	_books_slider.drag_started.connect(func(): _books_dragging = true)
	_books_slider.drag_ended.connect(func(_changed: bool): _books_dragging = false)

	_add_button(parent, "Start final hunt now", _start_final_hunt)
	_add_button(parent, "Skip countdown to 5s", _skip_countdown)
	_add_button(parent, "End final hunt", _end_final_hunt)
	_add_button(parent, "Complete ritual (ending)", _complete_ritual)


func _build_monster_section(parent: VBoxContainer):
	_add_section(parent, "MONSTER")

	_add_check(parent, "Monster ignores player", _on_ignore_player_toggled)
	_add_check(parent, "Freeze monster", _on_freeze_monster_toggled)

	_monster_speed_slider = _add_slider(parent, "Monster speed", 0.25, 3.0, 0.05, 1.0, 2, "x", _on_monster_speed_changed)

	var row := _add_button_row(parent)
	_add_button(row, "Force chase", _force_chase)
	_add_button(row, "Stop chase", _stop_chase)

	var row2 := _add_button_row(parent)
	_add_button(row2, "Teleport to player", _teleport_monster_to_player)
	_add_button(row2, "Teleport far", _teleport_monster_far)

	var start_level := 0
	if _manager:
		start_level = clampi(int(_manager.get("_books_collected")), 0, 6)
	_difficulty_slider = _add_slider(parent, "Difficulty level", 0, 6, 1, float(start_level), 0, "", _on_difficulty_changed)

	_add_check(parent, "Debug draw", _on_debug_draw_toggled)


func _build_rats_section(parent: VBoxContainer):
	_add_section(parent, "RATS")
	_add_check(parent, "Freeze all rats", _on_freeze_rats_toggled)
	_add_button(parent, "All rats flee", _make_rats_flee)


func _build_theme() -> Theme:
	var theme := Theme.new()
	var font := load(FONT_PATH) as Font
	if font:
		theme.set_font("font", "Label", font)
		theme.set_font("font", "Button", font)
		theme.set_font("font", "CheckButton", font)
		theme.set_font("font", "CheckBox", font)
	theme.set_font_size("font_size", "Label", 14)
	theme.set_font_size("font_size", "Button", 14)
	theme.set_font_size("font_size", "CheckButton", 14)
	theme.set_font_size("font_size", "CheckBox", 14)
	theme.set_constant("separation", "VBoxContainer", 4)
	theme.set_constant("separation", "HBoxContainer", 6)
	return theme


func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.9)
	style.border_color = Color(0.42, 0.38, 0.28, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style


func _add_section(parent: VBoxContainer, text: String):
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.86, 0.78, 0.52))
	parent.add_child(label)


func _add_button_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _add_button(parent: Container, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 26)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_check(parent: Container, text: String, callback: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.add_theme_font_size_override("font_size", 14)
	check.toggled.connect(callback)
	parent.add_child(check)
	return check


func _add_slider(parent: VBoxContainer, title: String, min_value: float, max_value: float, step: float, value: float, decimals: int, suffix: String, callback: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var title_label := Label.new()
	title_label.text = title
	title_label.custom_minimum_size = Vector2(160, 0)
	title_label.add_theme_font_size_override("font_size", 13)
	row.add_child(title_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 18)
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(58, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.text = _format_value(value, decimals, suffix)
	row.add_child(value_label)

	slider.set_meta("value_label", value_label)
	slider.set_meta("decimals", decimals)
	slider.set_meta("suffix", suffix)

	slider.value_changed.connect(func(v: float):
		value_label.text = _format_value(v, decimals, suffix)
		callback.call(v)
	)
	return slider


func _format_value(value: float, decimals: int, suffix: String) -> String:
	if decimals <= 0:
		return "%d%s" % [int(round(value)), suffix]
	return ("%.2f" % value) + suffix


func _refresh_slider_text(slider: HSlider):
	if slider == null:
		return
	var label := slider.get_meta("value_label") as Label
	if label == null:
		return
	label.text = _format_value(slider.value, int(slider.get_meta("decimals")), str(slider.get_meta("suffix")))


# ---------------------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------------------

func _on_fly_toggled(pressed: bool):
	_set_fly(pressed)


func _on_walk_changed(value: float):
	if _player:
		_player.set("walk_speed", _walk_base_speed * value)


func _on_sprint_changed(value: float):
	if _player:
		_player.set("run_speed", _run_base_speed * value)


func _on_infinite_stamina_toggled(pressed: bool):
	_infinite_stamina = pressed
	if _player == null:
		return
	if pressed:
		_saved_stamina_drain = float(_player.get("stamina_drain_rate"))
		_player.set("stamina_drain_rate", 0.0)
		_player.set("_stamina_locked", false)
		_player.set("current_stamina", float(_player.get("max_stamina")))
	else:
		_player.set("stamina_drain_rate", _saved_stamina_drain)


func _on_invincible_toggled(pressed: bool):
	if _monster:
		_monster.set("debug_no_catch", pressed)


func _on_lives_changed(value: float):
	if _manager == null:
		return
	var lives := int(round(value))
	_manager.set("_current_lives", lives)
	GameState.lives = lives
	_manager.emit_signal("lives_changed", lives)
	_manager.call("_update_lives_ui")


func _teleport_to_altar():
	if _player == null or _altar == null:
		return
	_teleport_player_to(_altar.global_position)


func _teleport_to_random_book():
	if _player == null:
		return
	var choices: Array[Node] = []
	if _books:
		for child in _books.get_children():
			if child is Node3D and is_instance_valid(child):
				choices.append(child)
	if choices.is_empty():
		_teleport_to_altar()
		return
	var target := choices[randi() % choices.size()] as Node3D
	_teleport_player_to(target.global_position)


func _teleport_player_to(position: Vector3):
	if _player == null:
		return
	var spawn: Transform3D = _player.get("_spawn_transform")
	_player.global_position = Vector3(position.x, spawn.origin.y, position.z)
	_player.velocity = Vector3.ZERO


func _teleport_to_start():
	if _player == null:
		return
	var spawn: Transform3D = _player.get("_spawn_transform")
	_player.global_position = spawn.origin
	_player.velocity = Vector3.ZERO


func _on_usage_changed(value: float):
	if _player:
		_player.set("_flashlight_usage_time", clampf(value, 0.0, 400.0))


func _reset_flashlight():
	if _player == null:
		return
	var base_energy := float(_player.get("_flashlight_base_energy"))
	var base_range := float(_player.get("_flashlight_base_range"))
	_player.set("_flashlight_usage_time", 0.0)
	_player.set("_flashlight_off_time", 0.0)
	_player.set("_flashlight_flicker_started", false)
	_player.set("_flicker_event_active", false)
	_player.set("_flashlight_recovery_pending", false)
	_player.set("_flashlight_recovery_time_left", 0.0)
	_player.set("_flashlight_current_energy", base_energy)
	_player.set("_flashlight_target_energy", base_energy)
	_player.set("_flashlight_fade_target", base_energy)
	_player.set("_flashlight_fade_speed", base_energy / 0.30)

	var light := _player.get("flashlight") as SpotLight3D
	if light:
		light.light_energy = base_energy
		light.spot_range = base_range

	if _usage_slider:
		_usage_slider.set_value_no_signal(0.0)
		_refresh_slider_text(_usage_slider)


# ---------------------------------------------------------------------------
# Books / final hunt / ending
# ---------------------------------------------------------------------------

func _on_books_changed(value: float):
	if _setting_books or _manager == null:
		return
	_setting_books = true

	var target := clampi(int(round(value)), 0, 6)
	var current := int(_manager.get("_books_collected"))

	if target > current:
		for i in range(target - current):
			_manager.call("_on_book_collected", null)
	elif target < current:
		_manager.set("_books_collected", target)
		_manager.call("_update_book_ui")
		_apply_monster_difficulty(target)
		if target < int(_manager.get("total_books")) and bool(_manager.get("_final_hunt_active")):
			_end_final_hunt()

	_setting_books = false
	if _books_slider:
		_books_slider.set_value_no_signal(float(target))
		_refresh_slider_text(_books_slider)
	if _manager and bool(_manager.get("_final_hunt_active")):
		_show_countdown_label()


func _start_final_hunt():
	if _manager:
		_manager.call("_start_final_hunt")
		_show_countdown_label()


func _skip_countdown():
	if _manager == null:
		return
	if not bool(_manager.get("_final_hunt_active")):
		_manager.call("_start_final_hunt")
	var timer := _manager.get("_final_hunt_timer") as Timer
	if timer:
		timer.start(5.0)
	_show_countdown_label()


# The manager keeps its countdown anchor after a hunt ends and only hides the
# label, so re-show it when a new hunt starts from the menu.
func _show_countdown_label():
	if _manager == null:
		return
	var label := _manager.get("_final_hunt_countdown_label") as Label
	if label and is_instance_valid(label):
		label.visible = true


func _end_final_hunt():
	if _manager == null:
		return
	_manager.set("_final_hunt_active", false)
	_manager.call("_stop_final_hunt_timer")
	_manager.call("_hide_final_hunt_ui")
	if _monster:
		_monster.set("_final_hunt_active", false)
		if not bool(_monster.get("_caught_player")):
			_monster.call("_end_scream")
			_monster.call("_enter_idle")


func _complete_ritual():
	if _altar and _altar.has_method("_complete_ritual"):
		_altar.call("_complete_ritual")


# ---------------------------------------------------------------------------
# Monster actions
# ---------------------------------------------------------------------------

func _on_ignore_player_toggled(pressed: bool):
	_ignore_player = pressed
	if _monster == null:
		return
	_monster.set("debug_ignore_player", pressed)
	if pressed and not bool(_monster.get("_caught_player")):
		# Also cancels the manager's final-hunt timer so it cannot force a chase
		# again while the monster is supposed to ignore the player.
		_end_final_hunt()


func _on_freeze_monster_toggled(pressed: bool):
	_monster_frozen = pressed
	if _monster == null:
		return
	_monster.process_mode = Node.PROCESS_MODE_DISABLED if pressed else Node.PROCESS_MODE_INHERIT


func _on_monster_speed_changed(value: float):
	if _monster:
		_monster.set("debug_speed_scale", value)


func _force_chase():
	if _monster:
		_monster.call("force_hunt_mode")


func _stop_chase():
	if _monster == null:
		return
	if bool(_monster.get("_caught_player")):
		return
	_monster.set("_final_hunt_active", false)
	_monster.call("_end_scream")
	_monster.call("_enter_idle")


func _teleport_monster_to_player():
	if _monster == null or _player == null:
		return
	var pos := _player.global_position
	_monster.global_position = Vector3(pos.x + 1.3, _monster.global_position.y, pos.z + 1.3)
	_monster.set("velocity", Vector3.ZERO)
	if _monster.has_method("_recalculate_path"):
		_monster.call("_recalculate_path")


func _teleport_monster_far():
	if _monster and _monster.has_method("spawn_far_from_player"):
		_monster.call("spawn_far_from_player")


func _on_difficulty_changed(value: float):
	_apply_monster_difficulty(clampi(int(round(value)), 0, 6))


func _apply_monster_difficulty(level: int):
	if _monster == null:
		return
	for key in _monster_defaults:
		_monster.set(key, _monster_defaults[key])
	if _monster.has_method("set_difficulty"):
		_monster.call("set_difficulty", level)


func _on_debug_draw_toggled(pressed: bool):
	_debug_draw = pressed
	if pressed:
		if _label_3d == null and _monster:
			_label_3d = Label3D.new()
			_label_3d.name = "DebugDrawLabel"
			_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_label_3d.no_depth_test = true
			_label_3d.font = load(FONT_PATH) as Font
			_label_3d.font_size = 40
			_label_3d.pixel_size = 0.003
			_label_3d.outline_size = 8
			_label_3d.modulate = Color(0.85, 1.0, 0.85)
			_label_3d.position = Vector3(0, 2.7, 0)
			_monster.add_child(_label_3d)
		if _label_3d:
			_label_3d.visible = true
	elif _label_3d:
		_label_3d.visible = false


func _update_debug_draw():
	if _label_3d == null or _monster == null:
		return
	var path: Array = _monster.get("_path")
	var index := int(_monster.get("_path_index"))
	var target := Vector3.ZERO
	if index >= 0 and index < path.size():
		target = path[index]
	var velocity: Vector3 = _monster.get("velocity")
	_label_3d.text = "MONSTER %s\nTARGET (%.1f, %.1f)\nSPEED %.2f m/s" % [
		_state_name(),
		target.x,
		target.z,
		Vector3(velocity.x, 0, velocity.z).length(),
	]


# ---------------------------------------------------------------------------
# Rats
# ---------------------------------------------------------------------------

func _get_rats() -> Array[Node]:
	var result: Array[Node] = []
	if _rats == null:
		return result
	for child in _rats.get_children():
		if child is Node3D and is_instance_valid(child):
			result.append(child)
	return result


func _on_freeze_rats_toggled(pressed: bool):
	for rat in _get_rats():
		rat.process_mode = Node.PROCESS_MODE_DISABLED if pressed else Node.PROCESS_MODE_INHERIT


func _make_rats_flee():
	for rat in _get_rats():
		rat.set("_fleeing", true)
		if rat.has_method("_pick_escape_destination"):
			rat.call("_pick_escape_destination")


# ---------------------------------------------------------------------------
# Live info
# ---------------------------------------------------------------------------

func _state_name() -> String:
	if _monster == null:
		return "-"
	match int(_monster.get("current_state")):
		0:
			return "IDLE"
		1:
			return "INVESTIGATING"
		2:
			return "HUNTING"
	return "?"


func _update_info():
	if _info_label == null:
		return

	var fps := Engine.get_frames_per_second()
	var pos := Vector3.ZERO
	if _player:
		pos = _player.global_position

	var books := 0
	var total := 6
	var lives := 0
	if _manager:
		books = int(_manager.get("_books_collected"))
		total = int(_manager.get("total_books"))
		lives = int(_manager.get("_current_lives"))

	var distance := 0.0
	if _player and _monster:
		distance = _player.global_position.distance_to(_monster.global_position)

	var text := "FPS %d\nPOS %.1f, %.1f, %.1f\nBOOKS %d/%d   LIVES %d\nMONSTER %s   DIST %.1fm" % [
		fps, pos.x, pos.y, pos.z, books, total, lives, _state_name(), distance,
	]

	if _debug_draw and _monster:
		var path: Array = _monster.get("_path")
		var index := int(_monster.get("_path_index"))
		var target := Vector3.ZERO
		if index >= 0 and index < path.size():
			target = path[index]
		var velocity: Vector3 = _monster.get("velocity")
		text += "\nTARGET (%.1f, %.1f)   SPEED %.2f" % [
			target.x, target.z, Vector3(velocity.x, 0, velocity.z).length(),
		]

	_info_label.text = text

	if _books_slider and not _books_dragging:
		_books_slider.set_value_no_signal(float(books))
		_refresh_slider_text(_books_slider)
	if _lives_slider and not _lives_dragging:
		_lives_slider.set_value_no_signal(float(lives))
		_refresh_slider_text(_lives_slider)
	if _usage_slider and not _usage_dragging and _player:
		var usage := clampf(float(_player.get("_flashlight_usage_time")), 0.0, 400.0)
		_usage_slider.set_value_no_signal(usage)
		_refresh_slider_text(_usage_slider)

