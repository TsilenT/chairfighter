extends Node
## Autoload name: GameState. Single source of truth for progression:
## unlocked forms, active form, story flags, and the respawn checkpoint.
## Mutations emit through the Events bus; consumers never poll each other.

## The basic chair is the starting chassis; the other eight are earned in
## pairs from the four guardian bosses.  Keeping this order acquisition-first
## makes cycling and the HUD read as four obvious reward pairs.
const FORM_ORDER: Array[StringName] = [
	&"basic",
	&"armchair", &"recliner",
	&"office", &"barstool",
	&"folding", &"highchair",
	&"rocking", &"stool",
]
const REQUIRED_FINAL_FORMS: Array[StringName] = [
	&"armchair", &"recliner",
	&"office", &"barstool",
	&"folding", &"highchair",
	&"rocking", &"stool",
]
const FINAL_GUARDIAN_FLAGS: Array[String] = [
	"boss_recliner_defeated",
	"boss_swivel_defeated",
	"boss_folder_defeated",
	"boss_granny_defeated",
]
const BOSS_FORM_REWARDS := {
	"boss_recliner_defeated": [&"armchair", &"recliner"],
	"boss_swivel_defeated": [&"office", &"barstool"],
	"boss_folder_defeated": [&"folding", &"highchair"],
	"boss_granny_defeated": [&"rocking", &"stool"],
}

const START_ZONE := "res://scenes/zones/Workshop.tscn"
const START_SPAWN := "Default"
const FINAL_ZONE := "res://scenes/zones/ThroneRoom.tscn"
const SAVE_PATH := "user://chairfighter_save.json"
const DEMO_SAVE_PATH := "user://chairfighter_demo_save.json"
const TEST_SAVE_PATH := "user://chairfighter_test_save.json"

var unlocked_forms: Array[StringName] = [&"basic"]
var current_form: StringName = &"basic"
var flags: Dictionary = {}
var checkpoint_zone: String = START_ZONE
var checkpoint_spawn: String = START_SPAWN

## Set once the game is won; blocks any further persistence so a checkpoint
## fired during the ending fade can't resurrect a phantom "Continue".
var _finished := false


func _ready() -> void:
	# Autosave on every meaningful progression beat.
	Events.form_unlocked.connect(func(_id: StringName) -> void: save_game())
	Events.form_changed.connect(func(_id: StringName) -> void: save_game())
	Events.boss_defeated.connect(func(_id: StringName) -> void: save_game())
	Events.checkpoint_activated.connect(func(_z: String, _s: String) -> void: save_game())
	Events.game_won.connect(func() -> void:
		_finished = true
		clear_save())


## Route saves to a throwaway path during demo/capture runs so a playthrough
## never reads or destroys the real player save.
func _save_path() -> String:
	if get_node_or_null("/root/TestRunner") != null:
		return TEST_SAVE_PATH
	var dd := get_node_or_null("/root/DemoDriver")
	if dd != null and dd.active:
		return DEMO_SAVE_PATH
	return SAVE_PATH


func new_game() -> void:
	unlocked_forms = [&"basic"]
	current_form = &"basic"
	flags = {}
	checkpoint_zone = START_ZONE
	checkpoint_spawn = START_SPAWN
	_finished = false
	# Do NOT clear the save here: an accidental "new game" that quits before
	# the first checkpoint should leave the old save intact. The Workshop's
	# entry checkpoint autosaves fresh on arrival, overwriting it naturally.


func has_save() -> bool:
	return FileAccess.file_exists(_save_path())


func save_game() -> void:
	if _finished:
		return
	var data := {
		"version": 2,
		"unlocked_forms": unlocked_forms.map(func(f: StringName) -> String: return String(f)),
		"current_form": String(current_form),
		"flags": flags,
		"checkpoint_zone": checkpoint_zone,
		"checkpoint_spawn": checkpoint_spawn,
	}
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f == null:
		push_error("[GameState] Cannot write save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data))


## Returns true when a valid save was restored.
func load_game() -> bool:
	if not has_save():
		return false
	_finished = false
	var f := FileAccess.open(_save_path(), FileAccess.READ)
	if f == null:
		return false
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		push_error("[GameState] Corrupt save; starting fresh")
		return false
	var save_version := int(data.get("version", 1))
	unlocked_forms.clear()
	for name in data.get("unlocked_forms", ["basic"]):
		var id := StringName(String(name))
		if id in FORM_ORDER:
			unlocked_forms.append(id)
	if unlocked_forms.is_empty():
		unlocked_forms = [&"basic"]
	flags = data.get("flags", {})
	# Version-1 saves may already have a defeated boss whose newly-added
	# companion reward was not present when that save was written. Repair the
	# reward set silently so loading an old run can never strand progression.
	_repair_unlocks_from_flags()
	current_form = StringName(String(data.get("current_form", "basic")))
	if current_form not in unlocked_forms:
		current_form = unlocked_forms[0]
	checkpoint_zone = String(data.get("checkpoint_zone", START_ZONE))
	checkpoint_spawn = String(data.get("checkpoint_spawn", START_SPAWN))
	if not ResourceLoader.exists(checkpoint_zone):
		checkpoint_zone = START_ZONE
		checkpoint_spawn = START_SPAWN
	# Version-1 allowed the Throne after the third guardian, and its PreBoss
	# marker now sits beyond the new Hall of Eight. Never materialize an old or
	# incomplete save on the wrong side of the new progression checks.
	var invalid_final_checkpoint := checkpoint_zone == FINAL_ZONE and (
			save_version < 2
			or not has_defeated_all_guardians()
			or (checkpoint_spawn == "PreBoss" and not has_completed_final_trials()))
	if invalid_final_checkpoint:
		checkpoint_zone = START_ZONE
		checkpoint_spawn = START_SPAWN
	# The King flag is written before the two-second ending beat. Recover that
	# terminal transition from any checkpoint if the process closed in between.
	if has_flag("boss_king_defeated"):
		_emit_recovered_victory.call_deferred()
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path()))


func unlock_form(id: StringName) -> void:
	var ids: Array[StringName] = [id]
	unlock_forms(ids)


## Award a boss's pair atomically. Both rewards are present before either
## announcement fires, and the first reward remains selected so the signature
## progression form (grapple/dash/fold/launch) is immediately demonstrated.
func unlock_forms(ids: Array[StringName]) -> void:
	var added: Array[StringName] = []
	for id in ids:
		if id in unlocked_forms or id in added:
			continue
		if id not in FORM_ORDER:
			push_error("[GameState] Unknown form: %s" % id)
			continue
		added.append(id)
	if added.is_empty():
		return
	unlocked_forms.append_array(added)
	# Switch BEFORE announcing so the form_unlocked autosave snapshots the
	# complete pair and the intended active form.
	set_form(added[0])
	for id in added:
		Events.form_unlocked.emit(id)


func is_unlocked(id: StringName) -> bool:
	return id in unlocked_forms


func has_all_final_forms() -> bool:
	for id in REQUIRED_FINAL_FORMS:
		if not is_unlocked(id):
			return false
	return true


func has_completed_final_trials() -> bool:
	for id in REQUIRED_FINAL_FORMS:
		if not has_flag("final_trial_%s" % id):
			return false
	return true


func has_defeated_all_guardians() -> bool:
	for flag in FINAL_GUARDIAN_FLAGS:
		if not has_flag(flag):
			return false
	return true


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
	# Persist immediately: broken gates / shattered floors are durable world
	# state and may not be followed by any other autosave beat.
	save_game()


func has_flag(key: String) -> bool:
	return flags.get(key, false)


func set_checkpoint(zone_path: String, spawn: String) -> void:
	checkpoint_zone = zone_path
	checkpoint_spawn = spawn
	Events.checkpoint_activated.emit(zone_path, spawn)


func _repair_unlocks_from_flags() -> void:
	for flag: String in BOSS_FORM_REWARDS:
		if not has_flag(flag):
			continue
		for id: StringName in BOSS_FORM_REWARDS[flag]:
			if id in FORM_ORDER and id not in unlocked_forms:
				unlocked_forms.append(id)


func _emit_recovered_victory() -> void:
	if has_flag("boss_king_defeated"):
		Events.game_won.emit()
