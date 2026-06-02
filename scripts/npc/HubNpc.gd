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

# Pre-written flavor lines keyed on the armchair-unlock state.

var _flavor_before := [
	"Excuse me, little chair. You look like someone who's been through the wringer.",
	"The Baron's tough, but you'll figure it out. Eventually.",
	"I've seen a hundred chairs try this place. Most don't make it past the second platform.",
	"You want to get up there? Grapple's the way. Don't forget that."
]

var _flavor_after := [
	"Oh! You've unlocked the Armchair! Now you're really getting somewhere.",
	"That grapple thing of yours is quite the contraption, isn't it?",
	"The Baron won't stand a chance now. You've got reach AND attitude.",
	"If you hadn't seen the Armchair, you'd never find that route. Quite clever, really."
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
