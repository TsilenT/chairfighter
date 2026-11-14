extends Node
## Autoload name: GameState. Single source of truth for progression:
## unlocked forms, active form, story flags, and the respawn checkpoint.
## Mutations emit through the Events bus; consumers never poll each other.

const FORM_ORDER: Array[StringName] = [
	&"basic", &"armchair", &"recliner", &"office", &"barstool",
	&"folding", &"highchair", &"rocking", &"stool",
]
const REQUIRED_FINAL_FORMS: Array[StringName] = [
	&"armchair", &"recliner", &"office", &"barstool",
	&"folding", &"highchair", &"rocking", &"stool",
]
const CAMPAIGN := [
	{"boss": &"recliner", "form": &"armchair", "zone": "Lounge", "title": "The Lounge",
		"objective": "The Baron took the guest list. Start in the Lounge."},
	{"boss": &"boiler", "form": &"recliner", "zone": "BoilerRoom", "title": "The Boiler Room",
		"objective": "Take the Armchair to the gold hoist east of the Lounge. The Boiler Room is up on the catwalk."},
	{"boss": &"swivel", "form": &"office", "zone": "OfficeComplex", "title": "The Office Complex",
		"objective": "The Office is west of Otto. Face the relief valve and brace against its blast."},
	{"boss": &"bartender", "form": &"barstool", "zone": "NightBar", "title": "The Night Bar",
		"objective": "Dash into the cracked baffle west of the Office. The Night Bar is on the far side."},
	{"boss": &"folder", "form": &"folding", "zone": "StorageCloset", "title": "The Storage Closet",
		"objective": "Find the Storage bell east of the hoist. Spin to send its own shot back into it."},
	{"boss": &"nanny", "form": &"highchair", "zone": "Nursery", "title": "The Nursery",
		"objective": "Past the Night Bar, fold flat and crawl under the linen cabinet to reach the Nursery."},
	{"boss": &"granny", "form": &"rocking", "zone": "Parlor", "title": "The Parlor",
		"objective": "The Parlor is in the east wing. Throw the High Chair's tray into the catch beside its door."},
	{"boss": &"bouncer", "form": &"stool", "zone": "Conservatory", "title": "The Conservatory",
		"objective": "Slam through the hatch at the far east end of the Workshop. The Conservatory drains open below."},
]
const FINAL_GUARDIAN_FLAGS: Array[String] = [
	"boss_recliner_defeated", "boss_boiler_defeated", "boss_swivel_defeated",
	"boss_bartender_defeated", "boss_folder_defeated", "boss_nanny_defeated",
	"boss_granny_defeated", "boss_bouncer_defeated",
]
const LEGACY_REWARDS := {
	"boss_recliner_defeated": [&"armchair", &"recliner"],
	"boss_swivel_defeated": [&"office", &"barstool"],
	"boss_folder_defeated": [&"folding", &"highchair"],
	"boss_granny_defeated": [&"rocking", &"stool"],
}
const FINAL_OBJECTIVE := "In the Workshop drains, head west and use Spring Stool to reach the Throne landing."

const START_ZONE := "res://scenes/zones/Workshop.tscn"
const START_SPAWN := "Default"
const FINAL_ZONE := "res://scenes/zones/ThroneRoom.tscn"
const SAVE_PATH := "user://chairfighter_save.json"
const DEMO_SAVE_PATH := "user://chairfighter_demo_save.json"
const TEST_SAVE_PATH := "user://chairfighter_test_save.json"
const PREFERENCES_PATH := "user://chairfighter_preferences.cfg"

var unlocked_forms: Array[StringName] = [&"basic"]
var current_form: StringName = &"basic"
var flags: Dictionary = {}
var checkpoint_zone: String = START_ZONE
var checkpoint_spawn: String = START_SPAWN

## Set once the game is won; blocks any further persistence so a checkpoint
## fired during the ending fade can't resurrect a phantom "Continue".
var _finished := false
var touch_controls := false
var camera_shake := true


func _ready() -> void:
	var prefs := ConfigFile.new()
	if prefs.load(PREFERENCES_PATH) == OK:
		camera_shake = prefs.get_value("accessibility", "camera_shake", true)
	# Autosave on every meaningful progression beat.
	Events.form_unlocked.connect(func(_id: StringName) -> void: save_game())
	Events.form_changed.connect(func(_id: StringName) -> void: save_game())
	Events.boss_defeated.connect(func(_id: StringName) -> void: save_game())
	Events.checkpoint_activated.connect(func(_z: String, _s: String) -> void: save_game())
	Events.game_won.connect(func() -> void:
		_finished = true
		clear_save())


func set_camera_shake(enabled: bool) -> void:
	camera_shake = enabled
	var prefs := ConfigFile.new()
	prefs.set_value("accessibility", "camera_shake", enabled)
	prefs.save(PREFERENCES_PATH)


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
		"version": 4,
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
	# Preserve prior rewards while leaving new boss doors for the player to earn.
	_repair_unlocks_from_flags(save_version)
	current_form = StringName(String(data.get("current_form", "basic")))
	if current_form not in unlocked_forms:
		current_form = unlocked_forms[0]
	checkpoint_zone = String(data.get("checkpoint_zone", START_ZONE))
	checkpoint_spawn = String(data.get("checkpoint_spawn", START_SPAWN))
	if not ResourceLoader.exists(checkpoint_zone):
		checkpoint_zone = START_ZONE
		checkpoint_spawn = START_SPAWN
	var invalid_final_checkpoint := checkpoint_zone == FINAL_ZONE and (
			save_version < 2
			or not has_defeated_all_guardians()
			or (checkpoint_spawn == "PreBoss" and not has_completed_final_trials()))
	if invalid_final_checkpoint:
		checkpoint_zone = START_ZONE
		checkpoint_spawn = START_SPAWN
	if save_version < 3:
		var next := next_floor_index()
		for index in range(next + 1, CAMPAIGN.size()):
			var zone := "res://scenes/zones/%s.tscn" % CAMPAIGN[index]["zone"]
			if checkpoint_zone == zone:
				checkpoint_zone = START_ZONE
				checkpoint_spawn = START_SPAWN
				break
	if save_version < 3 and checkpoint_zone == START_ZONE and checkpoint_spawn != "FromThrone":
		checkpoint_spawn = START_SPAWN
	if save_version < 4:
		_restore_reached_workshop_routes()
	# A save past the Workshop hatch predates the hatch on older runs. Its
	# return climb needs the opening above it.
	var in_workshop_basement := checkpoint_zone == START_ZONE and checkpoint_spawn == "FromThrone"
	if checkpoint_zone == FINAL_ZONE or in_workshop_basement:
		if has_defeated_all_guardians():
			flags["workshop_throne_hatch_broken"] = true
		else:
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


## Record the defeat and its full reward before notifying the world or saving.
func defeat_boss(boss_id: StringName) -> void:
	var flag := "boss_%s_defeated" % boss_id
	if has_flag(flag):
		return
	flags[flag] = true
	var floor := floor_for_boss(boss_id)
	if not floor.is_empty():
		var reward: StringName = floor["form"]
		if is_unlocked(reward):
			set_form(reward)
		else:
			unlock_form(reward)
	Events.boss_defeated.emit(boss_id)


## Update the roster before notifying listeners or persisting the active form.
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
	set_form(added[0])
	for id in added:
		Events.form_unlocked.emit(id)


func floor_for_boss(boss_id: StringName) -> Dictionary:
	for floor: Dictionary in CAMPAIGN:
		if floor["boss"] == boss_id:
			return floor
	return {}


func next_floor_index() -> int:
	for index in FINAL_GUARDIAN_FLAGS.size():
		if not has_flag(FINAL_GUARDIAN_FLAGS[index]):
			return index
	return CAMPAIGN.size()


func current_objective() -> String:
	var next := next_floor_index()
	return CAMPAIGN[next]["objective"] if next < CAMPAIGN.size() else FINAL_OBJECTIVE


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


func _repair_unlocks_from_flags(save_version: int) -> void:
	if save_version < 3:
		for flag: String in LEGACY_REWARDS:
			if has_flag(flag):
				for id: StringName in LEGACY_REWARDS[flag]:
					if id not in unlocked_forms:
						unlocked_forms.append(id)
	for index in CAMPAIGN.size():
		var id: StringName = CAMPAIGN[index]["form"]
		if has_flag(FINAL_GUARDIAN_FLAGS[index]) and id not in unlocked_forms:
			unlocked_forms.append(id)


## Old doorways could already have been used without the new Workshop fixtures.
## Preserve a route only when the save has reached that floor or cleared it.
func _restore_reached_workshop_routes() -> void:
	var routes := {
		&"swivel": "workshop_office_unlatched",
		&"bartender": "workshop_night_bar_wall_broken",
		&"folder": "workshop_storage_unlatched",
		&"granny": "workshop_parlor_unlatched",
		&"bouncer": "workshop_throne_hatch_broken",
	}
	for floor: Dictionary in CAMPAIGN:
		var boss: StringName = floor["boss"]
		if not routes.has(boss):
			continue
		var zone := "res://scenes/zones/%s.tscn" % floor["zone"]
		if checkpoint_zone == zone or has_flag("boss_%s_defeated" % boss):
			flags[routes[boss]] = true
	if checkpoint_zone.ends_with("/Nursery.tscn") or has_flag("boss_nanny_defeated"):
		flags["workshop_night_bar_wall_broken"] = true

func _emit_recovered_victory() -> void:
	if has_flag("boss_king_defeated"):
		Events.game_won.emit()
