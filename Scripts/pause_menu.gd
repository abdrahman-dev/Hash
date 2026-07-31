extends Control

const SELECTED_COLOR := Color(0.9, 0.85, 0.5)
const NORMAL_COLOR := Color(0.7, 0.7, 0.7)
const SELECT_PREFIX := "> "

var _index: int = 0
var _busy: bool = false
var _open: bool = false

var _labels: Array[Label] = []
var _base_texts: Array[String] = []


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	_refresh()


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel"):
		if _busy:
			return
		if _open:
			_resume()
		elif not get_tree().paused:
			_open_menu()
		return
	if not _open:
		return
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_accept"):
		_activate()


func _build():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.name = "PauseBackdrop"
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "PauseCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "PauseVBox"
	center.add_child(vbox)

	var title := Label.new()
	title.name = "PauseTitle"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", SELECTED_COLOR)
	title.add_theme_font_size_override("font_size", 36)
	vbox.add_child(title)

	var items: Array[String] = ["RESUME", "SETTINGS", "MAIN MENU", "EXIT"]
	for text in items:
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(l)
		_labels.append(l)
		_base_texts.append(text)


func _open_menu():
	_index = 0
	_open = true
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	_refresh()


func _resume():
	_open = false
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _move_selection(step: int):
	_index = wrapi(_index + step, 0, _labels.size())
	_refresh()


func _refresh():
	for i in _labels.size():
		var label := _labels[i]
		if i == _index:
			label.text = SELECT_PREFIX + _base_texts[i]
			label.add_theme_color_override("font_color", SELECTED_COLOR)
		else:
			label.text = _base_texts[i]
			label.add_theme_color_override("font_color", NORMAL_COLOR)


func _activate():
	match _index:
		0:
			_resume()
		1:
			_show_coming_soon()
		2:
			_back_to_main_menu()
		3:
			get_tree().quit()


func _show_coming_soon():
	_busy = true
	var layer := CanvasLayer.new()
	layer.name = "PauseComingSoonLayer"
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var label := Label.new()
	label.text = "COMING SOON"
	label.add_theme_font_size_override("font_size", 28)
	center.add_child(label)

	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_callback(func():
		_busy = false
		if is_instance_valid(layer):
			layer.queue_free()
	)


func _back_to_main_menu():
	_open = false
	visible = false
	Fade.to_black(self, func():
		get_tree().paused = false
		get_tree().change_scene_to_file(GameState.MAIN_MENU_SCENE)
	)
