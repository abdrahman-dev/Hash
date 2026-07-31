extends Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_count(current: int, total: int):
	text = "CURSED BOOKS\n%d / %d" % [current, total]


func set_objective():
	text = "OBJECTIVE\nFIND THE ALTAR"


func set_ritual(progress: float):
	var filled := int(round(clampf(progress, 0.0, 1.0) * 10.0))
	text = "PERFORMING RITUAL\n%s" % ("█".repeat(filled) + "░".repeat(10 - filled))
