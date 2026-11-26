extends HBoxContainer


const ICON_PATH := "res://Textures/UI/candlebright.png"
const FALLBACK_MAX_LIVES := 3
const ICON_SIZE := 28
const ICON_SPACING := 6
const FULL_TINT := Color(0.85, 0.85, 0.85)
const LOST_TINT := Color(0.85, 0.85, 0.85, 0.25)


var _icons: Array[TextureRect] = []


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation", ICON_SPACING)
	alignment = BoxContainer.ALIGNMENT_END
	_build_icons()
	set_lives(int(GameState.lives))


func set_lives(count: int):
	if _icons.is_empty():
		_build_icons()
	for i in _icons.size():
		_icons[i].modulate = FULL_TINT if i < maxi(count, 0) else LOST_TINT


func _max_lives() -> int:
	return int(GameState.max_lives) if GameState.max_lives > 0 else FALLBACK_MAX_LIVES


func _build_icons():
	for icon in _icons:
		icon.queue_free()
	_icons.clear()
	var texture := load(ICON_PATH)
	for i in range(_max_lives()):
		var icon := TextureRect.new()
		icon.name = "LifeIcon%d" % (i + 1)
		icon.texture = texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = LOST_TINT
		add_child(icon)
		_icons.append(icon)
