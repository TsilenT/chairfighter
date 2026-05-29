extends Node

## GameState — autoload singleton tracking player progress.
##
## Tracks which chair forms have been unlocked and checkpoint state
## for the MVP prototype. Also holds the canonical list of form
## definitions so Player.gd can instantiate them at runtime.

# Signal emitted when a new form is unlocked.
signal form_unlocked(form_name: String)

# Signal emitted when the player dies.
signal player_died

# Signal emitted when player health changes (for HUD updates).
signal player_health_changed(current: float, max_hp: float)

# Current checkpoint position in the test level.
var current_checkpoint := Vector2.ZERO

# Dictionary of currently unlocked form names (value is boolean true).
var unlocked_forms: Dictionary = {}

# Currently active form name.
var current_form: String = "BasicChair"

# Registry of all form definitions keyed by name.
# Populated by _ready() by scanning the forms/ directory.
var form_registry: Dictionary = {}

# List of form names in the recommended unlock order (for next/prev cycling).
var form_order: Array[String] = []

# Current player health tracking (for HUD display).
var player_current_health: float = 10.0
var player_max_health: float = 10.0


# ─────────────────────────────
#  Initialization
# ─────────────────────────────

func _ready() -> void:
	unlocked_forms["BasicChair"] = true
	unlocked_forms["Armchair"] = true
	current_form = "BasicChair"
	player_current_health = 10.0
	player_max_health = 10.0

	_populate_form_registry()

	print("[GameState] Game started. Unlocked forms: %s" % str(unlocked_forms))
	print("[GameState] Known forms: %s" % str(form_order))


func _populate_form_registry() -> void:
	"""Scan known form files and store their instances in form_registry."""
	var forms_dir := "res://scripts/player/forms/"
	var dir := DirAccess.open(forms_dir)
	if dir == null:
		printerr("[GameState] Could not open forms directory: %s" % forms_dir)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gd"):
			var path := forms_dir + file_name
			_load_form_definition(path)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[GameState] Loaded %d form definition(s)." % form_registry.size())


func _load_form_definition(path: String) -> void:
	"""Load a form script and add it to the registry."""
	var script: Script = load(path)
	if script == null:
		push_warning("[GameState] Could not load form from: %s" % path)
		return

	var instance: ChairForm = script.new()
	if instance == null:
		push_warning("[GameState] Could not instantiate form from: %s" % path)
		return

	form_registry[instance.form_name] = instance
	form_order.append(instance.form_name)


# ─────────────────────────────
#  Form management
# ─────────────────────────────

## Unlock a new chair form by name and return the form definition.
## Returns null if the form is already unlocked or doesn't exist.
func unlock_form(form_name: String) -> ChairForm:
	if form_name in unlocked_forms:
		push_warning("[GameState] Form %s already unlocked." % form_name)
		return null

	var form_def := form_registry.get(form_name)
	if form_def == null:
		push_warning("[GameState] Cannot unlock unknown form: %s" % form_name)
		return null

	unlocked_forms[form_name] = true
	if not form_order.has(form_name):
		form_order.append(form_name)
	form_unlocked.emit(form_name)
	print("[GameState] Unlocked form: %s" % form_name)
	return form_def


## Set the current active form. Returns true if successful.
func set_current_form(form_name: String) -> bool:
	if not form_name in unlocked_forms:
		push_warning("[GameState] Form %s not unlocked." % form_name)
		return false

	var form_def := form_registry.get(form_name)
	if form_def == null:
		push_warning("[GameState] Cannot set unknown form: %s" % form_name)
		return false

	current_form = form_name
	print("[GameState] Swapped to form: %s" % form_name)
	return true


## Get the current form definition (for reading movement properties).
func get_current_form_def() -> ChairForm:
	return form_registry.get(current_form)


## Get whether a form is unlocked.
func is_form_unlocked(form_name: String) -> bool:
	return form_name in unlocked_forms


## Get all unlocked form names as an array.
func get_unlocked_form_names() -> Array[String]:
	var names: Array[String] = []
	for key in unlocked_forms:
		names.append(key)
	return names


## Get the current form index within the unlocked forms array.
## Returns -1 if no forms are unlocked.
func get_unlocked_form_index() -> int:
	for i in form_order.size():
		if form_order[i] in unlocked_forms and form_order[i] == current_form:
			return i
	return -1


# ─────────────────────────────
#  Health tracking (for HUD)
# ─────────────────────────────

func update_player_health(current: float, max_hp: float) -> void:
	player_current_health = current
	player_max_health = max_hp
	player_health_changed.emit(current, max_hp)


# ─────────────────────────────
#  Test / Debug helpers
# ─────────────────────────────

## Test/unlock all forms (for debugging).
func unlock_all_forms() -> void:
	for form_name in form_registry:
		unlock_form(form_name)
	print("[GameState] TEST: All forms unlocked.")


## Set current form by index among unlocked forms (for cycling).
func set_current_form_by_unlocked_index(index: int) -> bool:
	var unlocked := get_unlocked_form_names()
	if unlocked.size() == 0 or index < 0 or index >= unlocked.size():
		push_warning("[GameState] Invalid unlocked form index: %d" % index)
		return false
	return set_current_form(unlocked[index])


# ─────────────────────────────
#  Checkpoint management
# ─────────────────────────────

## Reset checkpoint to the starting position.
func reset_checkpoint() -> void:
	current_checkpoint = Vector2.ZERO
	print("[GameState] Checkpoint reset to start.")

## Restore to checkpoint.
func respawn_at_checkpoint() -> Vector2:
	var pos := current_checkpoint
	print("[GameState] Respawning at checkpoint: %s" % str(pos))
	return pos
