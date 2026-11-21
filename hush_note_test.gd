extends Node


var _failures: Array[String] = []


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_validate()
	await _tree_idle(5)
	_read_flow()
	var code := 0
	if not _failures.is_empty():
		code = 1
	if code == 0:
		print("NOTE_DATA_TEST: ALL PASS")
	else:
		print("NOTE_DATA_TEST: %d FAILURE(S)" % _failures.size())
	get_tree().quit(code)


func _validate():
	var notes := _get_notes()
	if notes.size() != 4:
		_fail("expected 4 notes, got %d" % notes.size())
	if notes.size() == 0:
		return

	var seen_ids := {}
	var seen_titles := {}
	var seen_bodies := {}
	for i in range(notes.size()):
		var n: Node3D = notes[i]
		var nid: String = n.note_id
		var title: String = n.note_title
		var body: String = n.note_text
		if nid.is_empty():
			_fail("note %d has empty note_id" % i)
		if seen_ids.has(nid):
			_fail("duplicate note_id: %s" % nid)
		seen_ids[nid] = true
		if title.is_empty():
			_fail("note %d has empty title" % i)
		if seen_titles.has(title):
			_fail("duplicate title rendered on note %d: %s" % [i, title])
		seen_titles[title] = true
		if body.is_empty():
			_fail("note %d has empty body" % i)
		if seen_bodies.has(body):
			_fail("duplicate body rendered on note %d" % i)
		seen_bodies[body] = true
		if title.find("Test Note") != -1 or body.find("This is a temporary test note.") != -1:
			_fail("note %d still shows placeholder text" % i)

	var source: Array = NoteData.NOTES
	var before := JSON.stringify(source)
	if source.size() != 4:
		_fail("NoteData.NOTES has %d entries, expected 4" % source.size())
	var source_ids := {}
	for e in source:
		if source_ids.has(e["id"]):
			_fail("registry has duplicate id %s" % e["id"])
		source_ids[e["id"]] = true

	var orderings := {}
	for k in range(30):
		var shuffled := NoteData.get_randomized_notes()
		if shuffled.size() != 4:
			_fail("get_randomized_notes returned %d entries" % shuffled.size())
		var ids := []
		for e in shuffled:
			ids.append(e["id"])
		var as_set := {}
		for idv in ids:
			as_set[idv] = true
		if as_set.size() != 4:
			_fail("randomized batch contains duplicates")
		orderings[JSON.stringify(ids)] = true
	var after := JSON.stringify(source)
	if before != after:
		_fail("get_randomized_notes mutated the source registry")
	if orderings.size() < 2:
		_fail("randomization produced no variety across 30 shuffles")

	print("note placement summary:")
	for n in notes:
		print("  %s @ %s" % [n.note_id, n.global_position])


func _read_flow():
	var player := get_node_or_null("World/Player")
	if player == null:
		_fail("Player node missing")
		return
	var notes := _get_notes()
	if notes.is_empty():
		return
	var note: Node3D = notes[0]

	player.call("set_interact_note", note)
	if player.interact_note != note:
		_fail("set_interact_note did not store the note")

	player.call("_open_reading", note)
	await _tree_idle(2)
	if get_tree().paused != true:
		_fail("reading did not pause the tree")
	var ui: Control = player.get("_reading_ui")
	if ui == null or not is_instance_valid(ui):
		_fail("reading UI was not created")
	if ui != null and is_instance_valid(ui):
		var title_label := ui.get_node_or_null("Paper/Title") as Label
		var body_label := ui.get_node_or_null("Paper/Body") as Label
		if title_label == null or body_label == null:
			_fail("reading UI missing Paper/Title or Paper/Body labels")
		else:
			if not ui.visible:
				_fail("reading UI is not visible while open")
			if title_label.text != note.note_title:
				_fail("UI title mismatch: expected %q got %q" % [note.note_title, title_label.text])
			if body_label.text != note.note_text:
				_fail("UI body mismatch for note %s" % note.note_id)

	player.call("clear_interact_note", note)
	if player.interact_note != null:
		_fail("clear_interact_note did not clear the note")

	player.call("_close_reading")
	await _tree_idle(2)
	if get_tree().paused != false:
		_fail("closing reading did not unpause the tree")
	if ui != null and is_instance_valid(ui) and ui.visible:
		_fail("reading UI still visible after close")


func _tree_idle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _get_notes() -> Array[Node3D]:
	var world := get_node_or_null("World")
	if world == null:
		return []
	var container := world.get_node_or_null("Maze/Notes") as Node3D
	if container == null:
		_fail("Notes container not found under Maze")
		return []
	var result: Array[Node3D] = []
	for child in container.get_children():
		result.append(child)
	return result


func _fail(msg: String):
	_failures.append(msg)
	print("NOTE_DATA_TEST FAIL: %s" % msg)
