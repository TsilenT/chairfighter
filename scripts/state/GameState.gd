extends Node

## GameState — autoload singleton tracking player progress.
##
## Tracks which chair forms have been unlocked and checkpoint state
## for the MVP prototype.

# Signal emitted when a new form is unlocked.
signal form_unlocked(form_name: String)

# Signal emitted when the player dies.
signal player_died

# Current checkpoint position in the test level.
var current_checkpoint := Vector2.ZERO

# Dictionary of unlocked forms by name.
var unlocked_forms := {}

# Currently active form name.
var current_form := "BasicChair"

# Basic Chair is always unlocked at game start.
func _ready() -> void:
	unlocked_forms["BasicChair"] = true
	current_form = "BasicChair"
	print("[GameState] Game started. Unlocked forms: " + str(unlocked_forms))

## Unlock a new chair form by name.
func unlock_form(form_name: String) -> void:
	if form_name in unlocked_forms:
		push_warning("[GameState] Form %s already unlocked." % form_name)
		return
	unlocked_forms[form_name] = true
	form_unlocked.emit(form_name)
	print("[GameState] Unlocked form: %s" % form_name)

## Set the current active form. Returns true if successful.
func set_current_form(form_name: String) -> bool:
	if not form_name in unlocked_forms:
		push_warning("[GameState] Form %s not unlocked." % form_name)
		return false
	if not form_name in ["BasicChair", "Armchair"]:
		push_warning("[GameState] Unknown form: %s" % form_name)
		return false
	current_form = form_name
	print("[GameState] Swapped to form: %s" % form_name)
	return true

## Get whether a form is unlocked.
func is_form_unlocked(form_name: String) -> bool:
	return form_name in unlocked_forms

## Reset checkpoint to the starting position.
func reset_checkpoint() -> void:
	current_checkpoint = Vector2.ZERO
	print("[GameState] Checkpoint reset to start.")

## Restore to checkpoint.
func respawn_at_checkpoint() -> Vector2:
	var pos := current_checkpoint
	print("[GameState] Respawning at checkpoint: %s" % str(pos))
	return pos
