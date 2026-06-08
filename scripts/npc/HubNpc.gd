## HubNpc.gd — Central flavor NPC in TestLevel.
##
## The speech bubble is always visible. The text changes depending
## on whether the Armchair form has been unlocked via GameState.

extends CharacterBody2D

@onready var bubble_text := $SpeechBubble/BubbleText as Label
@onready var name_label := $SpeechBubble/NameLabel as Label

var _is_armchair_unlocked := false
var _flavor_line_index := 0
var _base_y := 0.0

var _next_step_hint := "Press Interact to talk to the NPC."

# Pre-written flavor lines keyed on the armchair-unlock state.
# First line is always the tutorial hint; rest cycle as flavor.

var _flavor_before := [
	"Take a breath. This game starts slow — just move, jump, and attack.",
	"Find the Baron, take him down, then you'll unlock the Armchair form.",
	_next_step_hint,
	"The grapple path goes up past Platform 3 — don't forget to look up."
]

var _flavor_after := [
	"Oh! You've unlocked the Armchair! Now you can really move.",
	_next_step_hint,
	"Grapple up to that high platform — there's a gate only the Armchair can pass.",
	"Your reach just got an upgrade. Use it wisely."
]

func _ready() -> void:
	_base_y = position.y
	_is_armchair_unlocked = GameState.is_form_unlocked("Armchair")
	_update_text()
	# Monitor GameState for Armchair unlock.
	GameState.form_unlocked.connect(_on_form_unlocked)

func _process(_delta: float) -> void:
	# Subtle up-and-down idle animation.
	position.y = _base_y + sin(Time.get_ticks_msec() / 600.0) * 2.0

func _update_text() -> void:
	if _is_armchair_unlocked:
		name_label.text = "Unknown"
		bubble_text.text = _flavor_after[_flavor_line_index % _flavor_after.size()]
	else:
		name_label.text = "???"
		bubble_text.text = _flavor_before[_flavor_line_index % _flavor_before.size()]


func _on_form_unlocked(form_name: String) -> void:
	if form_name == "Armchair":
		_is_armchair_unlocked = true
		_update_text()
