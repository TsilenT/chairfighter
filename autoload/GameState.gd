extends Node
## Autoload name: GameState. Single source of truth for progression:
## unlocked forms, active form, story flags, and the respawn checkpoint.
## Mutations emit through the Events bus; consumers never poll each other.

const FORM_ORDER: Array[StringName] = [&"basic", &"armchair", &"office", &"folding", &"rocking"]

const START_ZONE := "res://scenes/zones/Workshop.tscn"
const START_SPAWN := "Default"
const SAVE_PATH := "user://chairfighter_save.json"

var unlocked_forms: Array[StringName] = [&"basic"]
var current_form: StringName = &"basic"
var flags: Dictionary = {}
var checkpoint_zone: String = START_ZONE
var checkpoint_spawn: String = START_SPAWN


func _ready() -> void:
	# Autosave on every meaningful progression beat.
	Events.form_unlocked.connect(func(_id: StringName) -> void: save_game())
	Events.boss_defeated.connect(func(_id: StringName) -> void: save_game())
	Events.checkpoint_activated.connect(func(_z: String, _s: String) -> void: save_game())
	Events.game_won.connect(func() -> void: clear_save())


func new_game() -> void:
	unlocked_forms = [&"basic"]
	current_form = &"basic"
	flags = {}
	checkpoint_zone = START_ZONE
	checkpoint_spawn = START_SPAWN
	clear_save()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"version": 1,
		"unlocked_forms": unlocked_forms.map(func(f: StringName) -> String: return String(f)),
		"current_form": String(current_form),
		"flags": flags,
		"checkpoint_zone": checkpoint_zone,
		"checkpoint_spawn": checkpoint_spawn,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[GameState] Cannot write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


## Returns true when a valid save was restored.
func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_error("[GameState] Corrupt save; starting fresh")
		return false
	unlocked_forms.clear()
	for name in data.get("unlocked_forms", ["basic"]):
		var id := StringName(String(name))
		if id in FORM_ORDER:
			unlocked_forms.append(id)
	if unlocked_forms.is_empty():
		unlocked_forms = [&"basic"]
	current_form = StringName(String(data.get("current_form", "basic")))
	if current_form not in unlocked_forms:
		current_form = unlocked_forms[0]
	flags = data.get("flags", {})
	checkpoint_zone = String(data.get("checkpoint_zone", START_ZONE))
	checkpoint_spawn = String(data.get("checkpoint_spawn", START_SPAWN))
	if not ResourceLoader.exists(checkpoint_zone):
		checkpoint_zone = START_ZONE
		checkpoint_spawn = START_SPAWN
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func unlock_form(id: StringName) -> void:
	if id in unlocked_forms:
		return
	if id not in FORM_ORDER:
		push_error("[GameState] Unknown form: %s" % id)
		return
	unlocked_forms.append(id)
	Events.form_unlocked.emit(id)
	set_form(id)


func is_unlocked(id: StringName) -> bool:
	return id in unlocked_forms


func set_form(id: StringName) -> bool:
	if not is_unlocked(id):
		return false
	if current_form == id:
		return true
	current_form = id
	Events.form_changed.emit(id)
	return true


func cycle_form(dir: int) -> void:
	var idx := FORM_ORDER.find(current_form)
	if idx < 0:
		return
	for _i in FORM_ORDER.size():
		idx = (idx + dir + FORM_ORDER.size()) % FORM_ORDER.size()
		if is_unlocked(FORM_ORDER[idx]):
			set_form(FORM_ORDER[idx])
			return


func set_flag(key: String) -> void:
	if flags.get(key, false):
		return
	flags[key] = true


func has_flag(key: String) -> bool:
	return flags.get(key, false)


func set_checkpoint(zone_path: String, spawn: String) -> void:
	checkpoint_zone = zone_path
	checkpoint_spawn = spawn
	Events.checkpoint_activated.emit(zone_path, spawn)
