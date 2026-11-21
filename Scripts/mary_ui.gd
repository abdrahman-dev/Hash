extends Control

signal name_correct
signal name_wrong
signal closed

const HINT_CLOSE := "[E] Close"
const LETTERS := ["A", "R", "Y"]

const LETTER_TEXTURES := {
	"A": preload("res://Textures/Letters/A.png"),
	"R": preload("res://Textures/Letters/R.png"),
	"Y": preload("res://Textures/Letters/Y.png"),
}

const ATTEMPTS_TEXT := "Stabs remaining: %d"
const FAIL_COLOR := Color(1.0, 0.25, 0.2)
const FAIL_FLASH_TIME := 0.35

var _current_slot: int = 0
var _attempts_left: int = 4
var _locked: bool = false
var _flash_tween: Tween = null

var _prompt_label: Label
var _attempts_label: Label
var _hint_label: Label
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
	_blood_audio = AudioStreamPlayer.new()
	_blood_audio.stream = load("res://Sounds/bloodinpaper.mp3")
	_blood_audio.volume_db = -8.0
	add_child(_blood_audio)


func show_ui(attempts_left: int) -> void:
	_attempts_left = maxi(0, attempts_left)
	_cancel_flash()
	_reset_slots()
	_update_attempts_label()
	visible = true


func hide_ui() -> void:
	_cancel_flash()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_try_close()
			KEY_A:
				_press_letter("A")
			KEY_R:
				_press_letter("R")
			KEY_Y:
				_press_letter("Y")


func _press_letter(letter: String) -> void:
	get_viewport().set_input_as_handled()
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


func _try_close() -> void:
	if _current_slot != 0:
		return
	get_viewport().set_input_as_handled()
	closed.emit()


func _check_name() -> void:
	for i in mini(LETTERS.size(), _slots.size()):
		if _slots[i].texture != LETTER_TEXTURES[LETTERS[i]]:
			_handle_wrong_letter()
			return
	name_correct.emit()


func _handle_wrong_letter() -> void:
	if _attempts_left > 0:
		_attempts_left -= 1
	_update_attempts_label()
	name_wrong.emit()
	_start_fail_flash()


func _start_fail_flash() -> void:
	_cancel_flash()
	_locked = true
	_flash_tween = create_tween()
	for slot in _slots:
		slot.modulate = FAIL_COLOR
		_flash_tween.parallel().tween_property(slot, "modulate", Color.WHITE, FAIL_FLASH_TIME)
	_flash_tween.tween_callback(_finish_fail_flash)


func _finish_fail_flash() -> void:
	_reset_slots()
	_locked = false


func _reset_slots() -> void:
	_current_slot = 0
	for i in _slots.size():
		_slots[i].texture = null
		if i < _underlines.size() and _underlines[i]:
			_underlines[i].visible = true


func _update_attempts_label() -> void:
	if _attempts_label:
		_attempts_label.text = ATTEMPTS_TEXT % _attempts_left


func _cancel_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null
	_locked = false
	for slot in _slots:
		slot.modulate = Color.WHITE
