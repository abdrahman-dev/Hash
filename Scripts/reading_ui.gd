extends Control

signal close_requested

const HINT_CLOSE := "[E] Close"
const HINT_NEXT := "[E] Next"
const PAGE_FLIP_VOLUME_DB := -6.0

const FALLBACK_BODY_WIDTH := 536.0
const FALLBACK_BODY_HEIGHT := 290.0

var _title_label: Label
var _body_label: Label
var _hint_label: Label
var _page_flip: AudioStreamPlayer = null

var _pages: Array[String] = []
var _page_index: int = 0

var _body_width := FALLBACK_BODY_WIDTH
var _body_height := FALLBACK_BODY_HEIGHT


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title_label = get_node_or_null("Paper/Title") as Label
	_body_label = get_node_or_null("Paper/Body") as Label
	_hint_label = get_node_or_null("Paper/CloseHint") as Label
	if _body_label:
		if _body_label.size.x > 0:
			_body_width = _body_label.size.x
		if _body_label.size.y > 0:
			_body_height = _body_label.size.y


func show_note(title_text: String, body_text: String) -> void:
	if _title_label:
		_title_label.text = title_text
	_pages = _paginate(body_text)
	_page_index = 0
	_apply_page()
	visible = true


func _apply_page() -> void:
	var body := ""
	if _pages.size() > 0:
		body = _pages[_page_index]
	if _body_label:
		_body_label.text = body
	if _hint_label:
		if _page_index < _pages.size() - 1:
			_hint_label.text = HINT_NEXT
		else:
			_hint_label.text = HINT_CLOSE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if _page_index < _pages.size() - 1:
			_page_index += 1
			_apply_page()
			_play_page_flip()
		else:
			close_requested.emit()


func _play_page_flip() -> void:
	var flip := _get_page_flip()
	if flip:
		flip.play()


func _get_page_flip() -> AudioStreamPlayer:
	if is_instance_valid(_page_flip):
		return _page_flip
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var node := player.get_node_or_null("Pageflip") as AudioStreamPlayer
	if node:
		node.volume_db = PAGE_FLIP_VOLUME_DB
		_page_flip = node
	return _page_flip


func _paginate(full_text: String) -> Array[String]:
	var font := _body_label.get_theme_font("font") if _body_label else null
	var font_size := _body_label.get_theme_font_size("font_size") if _body_label else 22
	if font == null:
		return [full_text] if not full_text.is_empty() else [""]
	var line_height := float(font.get_height(font_size))
	if line_height <= 0.0:
		line_height = 28.0
	var max_lines := maxi(1, int((_body_height - 2.0) / line_height))

	var pages: Array[String] = []
	var current: Array[String] = []

	for paragraph in full_text.split("\n\n"):
		var lines: PackedStringArray = _wrap_paragraph(paragraph, font, font_size, _body_width)
		if lines.is_empty():
			continue

		var separator_cost := 1 if current.size() > 0 else 0
		if current.size() + separator_cost + lines.size() <= max_lines:
			if separator_cost:
				current.append("")
			for line in lines:
				current.append(line)
		else:
			if current.size() > 0:
				pages.append("\n".join(current))
				current.clear()
			var k := 0
			while k < lines.size():
				var room := max_lines - current.size()
				if room <= 0:
					pages.append("\n".join(current))
					current.clear()
					room = max_lines
				var take := mini(room, lines.size() - k)
				for j in range(take):
					current.append(lines[k + j])
				k += take

	if current.size() > 0 or pages.is_empty():
		pages.append("\n".join(current))

	return pages


func _wrap_paragraph(text: String, font: Font, font_size: int, width: float) -> PackedStringArray:
	var result := PackedStringArray()
	for hard_line in text.split("\n"):
		if hard_line.is_empty():
			continue
		var current := ""
		for word in hard_line.split(" ", false):
			var candidate := word if current.is_empty() else current + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
				result.append(current)
				current = word
			else:
				current = candidate
		result.append(current)
	return result
