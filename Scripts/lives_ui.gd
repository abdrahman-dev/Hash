extends Label


func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_lives(count: int):
	var hearts := ""
	for i in count:
		hearts += "\u2665 "
	text = "LIVES\n" + hearts.strip_edges()
