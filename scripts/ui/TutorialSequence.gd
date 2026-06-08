## TutorialSequence.gd — Opening guided sequence controller.
##
## Presents one short prompt at a time, watches existing Input Map actions
## (move_left, move_right, jump, attack, interact), hides each prompt the
## instant its action is completed, then clears the whole overlay when the
## sequence finishes.
##
## Usage: Attach as a CanvasLayer in a level (e.g. TestLevel). Set `active` true
## to start; or leave it false in the editor and wire `start_sequence()`
## from a scene signal.

extends CanvasLayer


## Export config
@export var active: bool = true
@export var prompt_delay: float = 0.5
@export var prompt_timeout: float = 30.0
@export var prompt_font_size: int = 28


## Internal state
var _steps: Array = []
var _current_step: int = -1
var _step_done: bool = false
var _done_actions: Array = []
var _sequence_finished: bool = false
var _step_delay_left: float = 0.0  # delay between steps

var _overlay: ColorRect
var _banner_bg: ColorRect
var _banner: VBoxContainer
var _prompt_label: Label
var _progression_label: Label
var _step_timers: Array = []  # one Timer per step


## Called when the node enters the scene tree.
func _ready() -> void:
	_build_overlay()
	_set_up_steps()
	if active and not _sequence_finished:
		await get_tree().create_timer(0.5).timeout
		_start_prompt(0)


## Build the placeholder UI as plain ColorRect/Label nodes at runtime.
func _build_overlay() -> void:
	# Semi-transparent backdrop (full viewport).
	_overlay = ColorRect.new()
	_overlay.name = "TutorialOverlay"
	_overlay.color = Color(0.0, 0.0, 0.0, 0.3)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.size = Vector2(1280, 720)
	_overlay.position = Vector2(0, 0)
	_overlay.z_index = 100
	add_child(_overlay)

	# Dark purple banner background — top-center, safe margins.
	_banner_bg = ColorRect.new()
	_banner_bg.name = "BannerBG"
	_banner_bg.color = Color(0.05, 0.05, 0.08, 0.9)
	_banner_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_bg.size = Vector2(640, 100)
	_banner_bg.position = Vector2((1280 - 640) / 2.0, 16.0)
	_overlay.add_child(_banner_bg)

	# Container inside banner.
	_banner = VBoxContainer.new()
	_banner.name = "TutorialBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.size = Vector2(610, 90)
	_banner.position = Vector2(15, 5)
	_overlay.add_child(_banner)

	# Progression hint label (shown above main prompt).
	_progression_label = Label.new()
	_progression_label.name = "ProgressionLabel"
	_progression_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_progression_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_progression_label.size = Vector2(580, 24)
	_progression_label.add_theme_font_size_override("font_size", 16)
	_progression_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	_progression_label.visible = false
	_banner.add_child(_progression_label)

	# Main prompt label.
	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_prompt_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_prompt_label.size = Vector2(580, 50)
	_prompt_label.add_theme_font_size_override("font_size", 28)
	_prompt_label.add_theme_color_override("font_color", Color.WHITE)
	_banner.add_child(_prompt_label)


## Define the guided sequence steps.
func _set_up_steps() -> void:
	_steps = [
		{
			"description": "HOLD move_left or move_right to walk. Walk to the next ledge.",
			"actions": ["move_left", "move_right"],
			"next_prompt": "Next: jump over to the next ledge using the Jump action.",
		},
		{
			"description": "Press the Jump action to leap forward. Press Jump to jump!",
			"actions": ["jump"],
			"next_prompt": "Next: strike forward with the Attack action.",
		},
		{
			"description": "Press the Attack action to strike forward. Press Attack to attack!",
			"actions": ["attack"],
			"next_prompt": "Next: talk to the NPC ahead using the Interact action.",
		},
		{
			"description": "Walk close to the NPC, then press the Interact action to talk.",
			"actions": ["interact"],
			"completion": "near_npc_interact",
			"next_prompt": "After this tutorial, defeat ReclinerBaron, switch to Armchair form, then grapple across to Platform 3.",
		},
		{
			"description": "After defeating ReclinerBaron, switch to Armchair form, hold Special near the yellow markers to grapple.",
			"actions": ["special"],
			"completion": "armchair_grapple",
		},
	]

	# Create one Timer per step for per-prompt timeouts.
	_step_timers.clear()
	for i in _steps.size():
		var t := Timer.new()
		t.name = "StepTimer_" + str(i)
		t.wait_time = _steps[i].get("timeout", prompt_timeout)
		t.one_shot = true
		t.autostart = false
		t.timeout.connect(_on_prompt_timed_out.bind(i))
		add_child(t)
		_step_timers.append(t)


## Show prompt at the given index and start watching for input.
func _start_prompt(index: int) -> void:
	if _sequence_finished or index < 0 or index >= _steps.size():
		if index >= _steps.size():
			_on_sequence_end()
		return

	# Stop previous timer (if any).
	if _current_step >= 0 and _current_step < _step_timers.size():
		var prev: Timer = _step_timers[_current_step]
		if prev and not prev.is_stopped():
			prev.stop()

	_current_step = index
	_step_done = false

	var step: Dictionary = _steps[index]
	var desc: Variant = step.get("description", "")
	if desc:
		_prompt_label.text = desc
	else:
		_prompt_label.text = ""

	var nxt: Variant = step.get("next_prompt", "")
	if nxt and nxt != "":
		_progression_label.text = nxt
		_progression_label.visible = true
	else:
		_progression_label.visible = false

	# Start the timeout timer for this step.
	if _current_step < _step_timers.size() and _step_timers[_current_step]:
		var to: float = step.get("timeout", prompt_timeout)
		_step_timers[_current_step].wait_time = to
		_step_timers[_current_step].start()


## Called when a per-step prompt timer fires.
func _on_prompt_timed_out(index: int) -> void:
	if index == _current_step and not _step_done and not _sequence_finished:
		_step_done = true
		_on_step_complete()


## Called every frame to check for player input.
func _process(_delta: float) -> void:
	# Don't accept input during inter-step delay.
	if _step_delay_left > 0.0:
		_step_delay_left -= _delta
		return
	if _current_step < 0 or _sequence_finished:
		return

	var step: Dictionary = _steps[_current_step]
	if _is_step_completed(step):
		_step_done = true
		for action in step.get("actions", []):
			if action not in _done_actions:
				_done_actions.append(action)
		_on_step_complete()
		return


## Return true only when the current prompt's requested action really happened.
func _is_step_completed(step: Dictionary) -> bool:
	var completion: String = step.get("completion", "input")
	match completion:
		"near_npc_interact":
			return Input.is_action_just_pressed("interact") and _is_player_near_node("HubNpc", 160.0)
		"armchair_grapple":
			var player: Node = _get_player()
			return Input.is_action_pressed("special") and player != null and player.has_method("is_grappling") and player.is_grappling()
		_:
			var actions: Array = step.get("actions", [])
			for action in actions:
				if action in _done_actions:
					continue
				if action == "move_left" or action == "move_right":
					if Input.is_action_pressed(action):
						return true
				elif Input.is_action_just_pressed(action):
					return true
	return false


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func _is_player_near_node(node_name: String, radius: float) -> bool:
	var player: Node = _get_player()
	var target: Node = get_tree().root.find_child(node_name, true, false)
	if player == null or target == null or not (player is Node2D) or not (target is Node2D):
		return false
	return (player as Node2D).global_position.distance_to((target as Node2D).global_position) <= radius


## Called when the player completes an input or the timer expires.
func _on_step_complete() -> void:
	_prompt_label.text = ""
	_progression_label.visible = false
	if _current_step >= 0 and _current_step < _step_timers.size():
		var t: Timer = _step_timers[_current_step]
		if t and not t.is_stopped():
			t.stop()
	if _current_step < 0 or _sequence_finished:
		return
	# If the current step has no input actions (pure progression cue), skip it instantly
	var step: Dictionary = _steps[_current_step]
	var actions: Array = step.get("actions", [])
	if actions.is_empty():
		if _current_step + 1 < _steps.size():
			_start_prompt(_current_step + 1)
		else:
			_on_sequence_end()
		return
	_step_delay_left = prompt_delay
	if _current_step + 1 < _steps.size():
		var next_step: int = _current_step + 1
		if prompt_delay > 0.0:
			await get_tree().create_timer(prompt_delay).timeout
		if _sequence_finished or not is_inside_tree():
			return
		_start_prompt(next_step)
	else:
		_on_sequence_end()


## Called when the entire sequence has completed.
func _on_sequence_end() -> void:
	_sequence_finished = true
	for t in _step_timers:
		if t and not t.is_stopped():
			t.stop()
	await get_tree().create_timer(0.3).timeout
	if _overlay and is_inside_tree():
		_overlay.queue_free()
		_overlay = null
	if is_inside_tree():
		queue_free()


## Start the sequence from a given step index (public).
func start_sequence(from_step: int = 0) -> void:
	_reset_state()
	if from_step < 0:
		from_step = 0
	if from_step >= _steps.size():
		_on_sequence_end()
		return
	_start_prompt(from_step)


## Skip the current prompt (advances to next).
func skip_prompt() -> void:
	if _step_done or _sequence_finished:
		return
	_step_done = true
	_on_step_complete()


## Skip the entire sequence immediately.
func skip_sequence() -> void:
	if _sequence_finished:
		return
	for t in _step_timers:
		if t and not t.is_stopped():
			t.stop()
	if _overlay and is_inside_tree():
		_overlay.queue_free()
		_overlay = null
	if is_inside_tree():
		queue_free()


## True when the whole sequence is done.
func is_sequence_finished() -> bool:
	return _sequence_finished


## Reset state for replay.
func _reset_state() -> void:
	_current_step = -1
	_step_done = false
	_sequence_finished = false
	_step_delay_left = 0.0
	_done_actions.clear()
	if _overlay == null:
		_build_overlay()
	_set_up_steps()
