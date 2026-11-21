extends CanvasLayer

const LINES := [
	"The curse is broken.",
	"The way is open.",
	"She is waiting.",
]

const FONT = preload("res://Fonts/IMFellEnglish-Regular.ttf")
const WIFY_AUDIO = preload("res://Sounds/wify/wify.mp3")
const TEXT_COLOR := Color(0.85, 0.85, 0.85, 1.0)
const FADE_DURATION := 0.4
const LINE_HOLD := 2.5
const SCREAM_VOLUME_DB := -5.0
const WIFY_VOLUME_DB := 2.0

@onready var _fade: ColorRect = $Fade
@onready var _label: Label = $Label
@onready var _screams: Array[AudioStreamPlayer] = [$Scream1, $Scream2, $Scream3]

func _ready():
	_fade.color = Color(0, 0, 0, 1.0)
	_label.visible = false
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", 48)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	for scream in _screams:
		scream.volume_db = SCREAM_VOLUME_DB
	_run_sequence()

func _run_sequence() -> void:
	for node in get_tree().get_nodes_in_group("bg_music"):
		node.queue_free()
	await _fade_to_black(0.5)
	await get_tree().create_timer(1.0).timeout

	for line in LINES:
		await _show_line(line)

	var scream := _screams[randi() % _screams.size()]
	scream.play()
	await scream.finished

	await get_tree().create_timer(0.5).timeout

	var wify := AudioStreamPlayer.new()
	wify.stream = WIFY_AUDIO
	wify.volume_db = WIFY_VOLUME_DB
	add_child(wify)
	wify.play()
	await wify.finished

	await get_tree().create_timer(1.5).timeout
	await _fade_to_black(1.0)
	get_tree().change_scene_to_file("res://Scenes/MainManu(original).tscn")

func _show_line(line: String) -> Signal:
	_label.text = line
	_label.modulate.a = 0.0
	_label.visible = true
	var tw := create_tween()
	tw.tween_property(_label, "modulate:a", 1.0, FADE_DURATION)
	tw.tween_interval(LINE_HOLD)
	tw.tween_property(_label, "modulate:a", 0.0, FADE_DURATION)
	return tw.finished

func _fade_to_black(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished
