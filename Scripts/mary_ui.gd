extends Control

signal name_correct
signal name_wrong
signal closed

const HINT_CLOSE := "[E] Close"
const LETTERS := ["A", "R", "Y"]
const ALPHABET := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const LETTER_TEXTURES := {
	"A": preload("res://Textures/Letters/A.png"),
	"R": preload("res://Textures/Letters/R.png"),
	"Y": preload("res://Textures/Letters/Y.png"),
}

const ATTEMPTS_TEXT := "Cuts remaining: %d"
const FAIL_COLOR := Color(1.0, 0.25, 0.2)
const FAIL_FLASH_TIME := 0.35
const HINT_FONT = preload("res://Fonts/IMFellEnglish-Regular.ttf")
const HINT_TEXTS := [
	"Read what she left on the walls.",
	"Look at how each line begins.",
	"The first letter of every line.",
]

var _current_slot: int = 0
var _cuts_remaining: int = 0
var _locked: bool = false
var _flash_tween: Tween = null

var _prompt_label: Label
var _attempts_label: Label
var _hint_label: Label
var _hint_text_label: Label
var _hint_tween: Tween = null
var _slots: Array[TextureRect] = []
var _underlines: Array[ColorRect] = []
var _blood_audio: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prompt_label = get_node_or_null("Paper/Prompt") as Label
	_attempts_label = get_node_or_null("Paper/AttemptsLabel") as Label
	_hint_label = get_node_or_null("Paper/CloseHint") as Label
	for slot_path in ["Paper/Slot1", "Paper/Slot2", "Paper/Slot3"]:
		var slot := get_node_or_null(slot_path) as TextureRect
		if slot == null:
			continue
		_slots.append(slot)
		_underlines.append(slot.get_node_or_null("Underline") as ColorRect)
	if _hint_label:
		_hint_label.text = HINT_CLOSE
	_create_hint_label()
	_update_attempts_label()
	_blood_audio = AudioStreamPlayer.new()
	_blood_audio.stream = load("res://Sounds/bloodinpaper.mp3")
	_blood_audio.volume_db = -8.0
	add_child(_blood_audio)


func _create_hint_label() -> void:
	_hint_text_label = Label.new()
	_hint_text_label.name = "HintLabel"
	_hint_text_label.offset_left = 48.0
	_hint_text_label.offset_top = 300.0
	_hint_text_label.offset_right = 600.0
	_hint_text_label.offset_bottom = 356.0
	_hint_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_text_label.add_theme_font_override("font", HINT_FONT)
	_hint_text_label.add_theme_font_size_override("font_size", 16)
	_hint_text_label.add_theme_color_override("font_color", Color(0.35, 0.12, 0.12, 0.75))
	_hint_text_label.modulate.a = 0.0
	var paper := get_node_or_null("Paper") as Control
	if paper:
		paper.add_child(_hint_text_label)
	else:
		add_child(_hint_text_label)


func show_ui(cuts_remaining: int) -> void:
	_cuts_remaining = maxi(0, cuts_remaining)
	_cancel_flash()
	_reset_slots()
	_update_attempts_label()
	_update_hint(_cuts_remaining)
	visible = true
	add_to_group("mary_ui_open")


func hide_ui() -> void:
	_cancel_flash()
	_cancel_hint_fade()
	_reset_slots()
	visible = false
	remove_from_group("mary_ui_open")


func _exit_tree() -> void:
	remove_from_group("mary_ui_open")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		var physical_key: int = event.physical_keycode
		# Close handling lives in _input so it runs before every other handler,
		# including the controller's interact action and the pause menu.
		if key == KEY_E or key == KEY_ESCAPE or physical_key == KEY_E or physical_key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			closed.emit()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	var physical_key: int = event.physical_keycode
	# E and Escape are close keys handled in _input; never letters.
	if key == KEY_E or key == KEY_ESCAPE or physical_key == KEY_E or physical_key == KEY_ESCAPE:
		return
	# M is already on the paper: completely inert.
	if key == KEY_M or physical_key == KEY_M:
		return
	if _locked or _current_slot >= LETTERS.size():
		return
	if key < KEY_A or key > KEY_Z:
		key = physical_key
	if key < KEY_A or key > KEY_Z:
		return
	get_viewport().set_input_as_handled()
	_press_letter(ALPHABET[key - KEY_A])


func _press_letter(letter: String) -> void:
	if letter != LETTERS[_current_slot]:
		_handle_wrong_letter()
		return
	_fill_slot(_current_slot, letter)
	_current_slot += 1
	if _current_slot >= LETTERS.size():
		_check_name()


func _fill_slot(index: int, letter: String) -> void:
	if index < 0 or index >= _slots.size():
		return
	_slots[index].texture = LETTER_TEXTURES[letter]
	if index < _underlines.size() and _underlines[index]:
		_underlines[index].visible = false
	if _blood_audio:
		_blood_audio.stop()
		_blood_audio.play()


func _check_name() -> void:
	for i in mini(LETTERS.size(), _slots.size()):
		if _slots[i].texture != LETTER_TEXTURES[LETTERS[i]]:
			_handle_wrong_letter()
			return
	name_correct.emit()


# A wrong letter ends this cut's single attempt. The flash is allowed to read
# first, then the controller closes the paper and applies the cut/failure rules.
func _handle_wrong_letter() -> void:
	_cancel_flash()
	_locked = true
	_flash_tween = create_tween()
	for slot in _slots:
		slot.modulate = FAIL_COLOR
		_flash_tween.parallel().tween_property(slot, "modulate", Color.WHITE, FAIL_FLASH_TIME)
	_flash_tween.tween_callback(func():
		_flash_tween = null
		name_wrong.emit()
	)


func _reset_slots() -> void:
	_current_slot = 0
	for i in _slots.size():
		_slots[i].texture = null
		if i < _underlines.size() and _underlines[i]:
			_underlines[i].visible = true


func _update_attempts_label() -> void:
	if _attempts_label:
		_attempts_label.text = ATTEMPTS_TEXT % _cuts_remaining


func _update_hint(cuts_remaining: int) -> void:
	if _hint_text_label == null:
		return
	var level: int = 0
	if cuts_remaining == 1:
		level = 1
	elif cuts_remaining <= 0:
		level = 2
	_hint_text_label.text = HINT_TEXTS[level]
	_cancel_hint_fade()
	_hint_tween = _hint_text_label.create_tween()
	_hint_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hint_tween.tween_property(_hint_text_label, "modulate:a", 1.0, 1.5)


func _cancel_hint_fade() -> void:
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = null
	if _hint_text_label:
		_hint_text_label.modulate.a = 0.0


func _cancel_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_locked = false
	for slot in _slots:
		slot.modulate = Color.WHITE
