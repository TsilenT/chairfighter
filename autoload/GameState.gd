extends Node
## Autoload name: GameState. Single source of truth for progression:
## unlocked forms, active form, story flags, and the respawn checkpoint.
## Mutations emit through the Events bus; consumers never poll each other.

const FORM_ORDER: Array[StringName] = [&"basic", &"armchair", &"office", &"folding"]

const START_ZONE := "res://scenes/zones/Workshop.tscn"
const START_SPAWN := "Default"

var unlocked_forms: Array[StringName] = [&"basic"]
var current_form: StringName = &"basic"
var flags: Dictionary = {}
var checkpoint_zone: String = START_ZONE
var checkpoint_spawn: String = START_SPAWN


func new_game() -> void:
	unlocked_forms = [&"basic"]
	current_form = &"basic"
	flags = {}
	checkpoint_zone = START_ZONE
	checkpoint_spawn = START_SPAWN


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
