extends Node
## Discovers and runs unit tests inside a live SceneTree so tests can await
## physics frames and use autoloads. See tests/run_all.gd.

const UNIT_DIR := "res://tests/unit"


func _ready() -> void:
	# Defer a frame so autoloads are fully ready.
	await get_tree().process_frame
	var failures: Array[String] = []
	var count := 0
	var dir := DirAccess.open(UNIT_DIR)
	if dir == null:
		print("TESTS FAIL: cannot open %s" % UNIT_DIR)
		get_tree().quit(1)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
		f = dir.get_next()
	files.sort()
	for file in files:
		var script := load(UNIT_DIR + "/" + file)
		if script == null:
			failures.append("%s: failed to load" % file)
			continue
		var inst: Object = script.new()
		if not inst.has_method("run"):
			failures.append("%s: no run() method" % file)
			continue
		count += 1
		print("── %s" % file)
		var fails: Variant = await inst.run(get_tree())
		if fails == null:
			# run() aborted (script error) — never let that pass silently.
			failures.append("%s: run() aborted with a script error" % file)
			continue
		for msg in fails:
			failures.append("%s: %s" % [file, msg])
		if inst is Node:
			inst.queue_free()
	if failures.is_empty():
		print("TESTS PASS (%d files)" % count)
		get_tree().quit(0)
	else:
		for msg in failures:
			printerr("FAIL: " + msg)
		print("TESTS FAIL (%d failures across %d files)" % [failures.size(), count])
		get_tree().quit(1)
