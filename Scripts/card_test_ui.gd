extends Control


const CARD_A_PATH := "res://assets/cards/card_a.png"
const CARD_B_PATH := "res://assets/cards/card_b.png"
const CARD_WIDTH := 200
const CARD_HEIGHT := 280
const CONTAINER_WIDTH := 500
const CONTAINER_HEIGHT := 300
const CARD_SPACING := 30.0
const SHARED_DESC_W := 460.0
const DESC_H := 50.0
const DESC_GAP := 55.0
const JITTER_STRENGTH := 3.0
const JITTER_INTERVAL := 0.06

var _card_a: TextureRect
var _card_b: TextureRect
var _desc_bg: ColorRect
var _desc_label: Label
var _desc_tween: Tween
var _flash_overlay: ColorRect


func _ready():
	_setup_layout()
	_setup_card(_card_a, CARD_A_PATH, Color.DARK_RED, "Card A clicked")
	_setup_card(_card_b, CARD_B_PATH, Color(0.0, 0.5, 0.5), "Card B clicked")
	_create_flash_overlay()


func _setup_layout():
	var vp_size := get_viewport().get_visible_rect().size
	var container := ColorRect.new()
	container.name = "CardContainer"
	container.color = Color(0.12, 0.12, 0.12, 0.9)

	var card_x := (CONTAINER_WIDTH - 2 * CARD_WIDTH - CARD_SPACING) / 2.0
	var card_y := (CONTAINER_HEIGHT - CARD_HEIGHT) / 2.0

	var desc_top_rel := -(DESC_H + DESC_GAP)
	var card_bottom_rel := card_y + CARD_HEIGHT
	var visual_center_rel := (desc_top_rel + card_bottom_rel) / 2.0
	container.position = Vector2(
		(vp_size.x - CONTAINER_WIDTH) * 0.5,
		vp_size.y * 0.5 - visual_center_rel
	)
	container.size = Vector2(CONTAINER_WIDTH, CONTAINER_HEIGHT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_desc_bg = ColorRect.new()
	_desc_bg.name = "SharedDescBG"
	_desc_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	_desc_bg.position = Vector2((CONTAINER_WIDTH - SHARED_DESC_W) * 0.5, desc_top_rel)
	_desc_bg.size = Vector2(SHARED_DESC_W, DESC_H)
	_desc_bg.modulate = Color(1.0, 1.0, 1.0, 0.0)
	container.add_child(_desc_bg)

	_desc_label = Label.new()
	_desc_label.name = "SharedDescLabel"
	_desc_label.text = ""
	_desc_label.add_theme_font_override("font", preload("res://Fonts/IMFellEnglish-Regular.ttf"))
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_desc_label.position = Vector2(4, 0)
	_desc_label.size = Vector2(SHARED_DESC_W - 8, DESC_H)
	_desc_bg.add_child(_desc_label)

	_card_a = TextureRect.new()
	_card_a.name = "CardA"
	_card_a.position = Vector2(card_x, card_y)
	_card_a.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card_a.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_a.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_a.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_a.set_meta("base_pos", Vector2(card_x, card_y))
	container.add_child(_card_a)

	_card_b = TextureRect.new()
	_card_b.name = "CardB"
	_card_b.position = Vector2(card_x + CARD_WIDTH + CARD_SPACING, card_y)
	_card_b.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card_b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card_b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card_b.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_b.set_meta("base_pos", Vector2(card_x + CARD_WIDTH + CARD_SPACING, card_y))
	container.add_child(_card_b)


func _setup_card(card: TextureRect, image_path: String, fallback_color: Color, click_message: String):
	var texture: Texture2D
	if ResourceLoader.exists(image_path):
		texture = load(image_path)
	else:
		var img := Image.create(CARD_WIDTH, CARD_HEIGHT, false, Image.FORMAT_RGBA8)
		img.fill(fallback_color)
		texture = ImageTexture.create_from_image(img)
	card.texture = texture
	card.mouse_entered.connect(_on_card_hover_start.bind(card))
	card.mouse_exited.connect(_on_card_hover_end.bind(card))
	card.gui_input.connect(_on_card_gui_input.bind(card, click_message))


func _on_card_hover_start(card: TextureRect):
	if not is_instance_valid(card):
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color(1.1, 1.1, 1.1), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_start_jitter(card)

	_desc_label.text = (
		"Adrenaline: Move faster,\nbut vision blurs"
		if card == _card_a else
		"Frozen Ground: Freezes the\nmonster, but slows you down"
	)
	if is_instance_valid(_desc_tween):
		_desc_tween.kill()
	_desc_tween = create_tween()
	_desc_tween.tween_property(_desc_bg, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _start_jitter(card: TextureRect):
	var timer := Timer.new()
	timer.name = "JitterTimer"
	timer.wait_time = JITTER_INTERVAL
	timer.timeout.connect(_on_jitter_tick.bind(card))
	card.add_child(timer)
	timer.start()


func _on_jitter_tick(card: TextureRect):
	if not is_instance_valid(card):
		return
	if not card.has_meta("base_pos"):
		return

	var old_jitter: Tween = card.get_meta("jitter_tween", null)
	if is_instance_valid(old_jitter):
		old_jitter.kill()

	var base_pos: Vector2 = card.get_meta("base_pos")
	var target := base_pos + Vector2(
		randf_range(-JITTER_STRENGTH, JITTER_STRENGTH),
		randf_range(-JITTER_STRENGTH, JITTER_STRENGTH)
	)
	var jitter_tween := create_tween()
	jitter_tween.tween_property(card, "position", target, JITTER_INTERVAL).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	card.set_meta("jitter_tween", jitter_tween)


func _on_card_hover_end(card: TextureRect):
	if not is_instance_valid(card):
		return

	var old_jitter: Tween = card.get_meta("jitter_tween", null)
	if is_instance_valid(old_jitter):
		old_jitter.kill()

	var timer := card.get_node_or_null("JitterTimer")
	if timer:
		timer.stop()
		timer.queue_free()

	if not card.has_meta("base_pos"):
		return
	var base_pos: Vector2 = card.get_meta("base_pos")
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate", Color(1.0, 1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", base_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_desc_tween):
		_desc_tween.kill()
	_desc_tween = create_tween()
	_desc_tween.tween_property(_desc_bg, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_card_gui_input(event: InputEvent, card: TextureRect, message: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger_flash(message)


func _trigger_flash(message: String):
	if not is_instance_valid(_flash_overlay):
		return
	_flash_overlay.modulate = Color(0.6, 0.0, 0.0, 0.0)
	var tween := create_tween()
	tween.tween_property(_flash_overlay, "modulate", Color(0.6, 0.0, 0.0, 0.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash_overlay, "modulate", Color(0.6, 0.0, 0.0, 0.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _create_flash_overlay():
	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "FlashOverlay"
	_flash_overlay.anchor_left = 0.0
	_flash_overlay.anchor_right = 1.0
	_flash_overlay.anchor_top = 0.0
	_flash_overlay.anchor_bottom = 1.0
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color(0.6, 0.0, 0.0)
	_flash_overlay.modulate = Color(0.6, 0.0, 0.0, 0.0)
	add_child(_flash_overlay)
