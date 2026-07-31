extends Node

const SELECTED_COLOR := Color(0.9, 0.85, 0.5)
const NORMAL_COLOR := Color(0.7, 0.7, 0.7)
const SELECT_PREFIX := "> "

var _index: int = 0
var _busy: bool = false
var _credits_overlay: Control

var _labels: Array[Label] = []
var _base_texts: Array[String] = []


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var menu := $CanvasLayer/Menu as VBoxContainer
	if menu:
		for child in menu.get_children():
			if child is Label:
				_labels.append(child)
				_base_texts.append(child.text)
	_build_credits_overlay()
	_refresh()


func _unhandled_input(event: InputEvent):
	if _credits_overlay and _credits_overlay.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_credits()
		return
	if _busy:
		return
	if event.is_action_pressed("ui_up"):
		_move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		_move_selection(1)
	elif event.is_action_pressed("ui_accept"):
		_activate()


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
			_start_new_game()
		1:
			_show_coming_soon()
		2:
			_show_credits()
		3:
			get_tree().quit()


func _start_new_game():
	_busy = true
	GameState.lives = GameState.max_lives
	Fade.to_black(self, func():
		get_tree().paused = false
		get_tree().change_scene_to_file(GameState.GAME_SCENE)
	)


func _show_coming_soon():
	_busy = true
	var layer := CanvasLayer.new()
	layer.name = "ComingSoonLayer"
	layer.layer = 20
	add_child(layer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)

	var label := Label.new()
	label.name = "ComingSoon"
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


func _build_credits_overlay():
	_credits_overlay = Control.new()
	_credits_overlay.name = "CreditsOverlay"
	_credits_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.visible = false
	$CanvasLayer.add_child(_credits_overlay)

	var backdrop := ColorRect.new()
	backdrop.name = "CreditsBackdrop"
	backdrop.color = Color(0, 0, 0, 0.75)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "CreditsCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_credits_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "CreditsVBox"
	center.add_child(vbox)

	var lines: Array[String] = [
		"HUSH",
		"",
		"Developed by",
		"DimlitGames",
		"",
		"Made with Godot 4.7",
		"",
		"https://dimlitgames.vercel.app/",
		"",
		"Press Esc to return",
	]
	for line in lines:
		var l := Label.new()
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if line == "HUSH":
			l.add_theme_font_size_override("font_size", 40)
		vbox.add_child(l)


func _show_credits():
	_busy = true
	if _credits_overlay:
		_credits_overlay.visible = true
	$CanvasLayer/Menu.visible = false
	$CanvasLayer/Title.visible = false


func _close_credits():
	if _credits_overlay:
		_credits_overlay.visible = false
	$CanvasLayer/Menu.visible = true
	$CanvasLayer/Title.visible = true
	_refresh()
	_busy = false
