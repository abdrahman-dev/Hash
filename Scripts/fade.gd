class_name Fade
extends Object


static func to_black(parent: Node, on_complete: Callable, duration: float = 0.8) -> void:
	var layer := CanvasLayer.new()
	layer.name = "FadeLayer"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(layer)

	var rect := ColorRect.new()
	rect.name = "FadeRect"
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var tw := layer.create_tween()
	tw.tween_property(rect, "color:a", 1.0, duration)
	tw.tween_callback(func():
		layer.queue_free()
		if on_complete.is_valid():
			on_complete.call()
	)
