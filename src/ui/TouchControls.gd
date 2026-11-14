extends CanvasLayer
## Landscape controls with independent thumb tracking and a contextual door button.

signal pause_requested
signal forms_requested

const MOVE_COLOR := Color("#3d3856")
const ACTION_COLOR := Color("#624052")
const POWER_COLOR := Color("#405073")
const RADIUS := 51.0
const SMALL := 37.0
const HEART_SAFE_TOP := 64.0

var _surface: Control
var _controls: Dictionary = {}
var _touches: Dictionary = {}
var _power_label := "Power"
var _can_enter := false


func _ready() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	_surface = Control.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	_surface.draw.connect(_draw_buttons)
	get_viewport().size_changed.connect(_layout)
	Events.form_changed.connect(_on_form_changed)
	_on_form_changed(GameState.current_form)
	set_enabled(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_touches()


func set_enabled(enabled: bool) -> void:
	if not enabled:
		_release_touches()
	_surface.visible = enabled
	set_process_input(enabled)
	set_physics_process(enabled)


func _release_touches() -> void:
	for finger in _touches.keys():
		_release(int(finger))


func _physics_process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var near_door := false
	if player != null and player.is_alive():
		for candidate in get_tree().get_nodes_in_group("doors"):
			var door := candidate as Door
			if door != null and door.can_interact(player):
				near_door = true
				break
	if near_door != _can_enter:
		_can_enter = near_door
		_surface.queue_redraw()


func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var left := 82.0
	var right := size.x - 82.0
	var floor := size.y - 77.0
	_controls = {
		&"move_left": [Vector2(left, floor), RADIUS, "", MOVE_COLOR],
		&"move_right": [Vector2(left + 115.0, floor), RADIUS, "", MOVE_COLOR],
		&"interact": [Vector2(left + 44.0, floor - 102.0), SMALL, "Enter", MOVE_COLOR],
		&"jump": [Vector2(right, floor), RADIUS, "Jump", ACTION_COLOR],
		&"attack": [Vector2(right - 115.0, floor), RADIUS, "Attack", ACTION_COLOR],
		&"special": [Vector2(right - 12.0, floor - 112.0), RADIUS, _power_label, POWER_COLOR],
		&"forms": [Vector2(right - 133.0, HEART_SAFE_TOP), SMALL, "Forms", POWER_COLOR],
		&"pause": [Vector2(right - 48.0, HEART_SAFE_TOP), SMALL, "Pause", MOVE_COLOR],
	}
	_surface.queue_redraw()


func _on_form_changed(id: StringName) -> void:
	const LABELS := {
		&"basic": "Power", &"armchair": "Hook", &"recliner": "Brace", &"office": "Dash",
		&"barstool": "Spin", &"folding": "Fold", &"highchair": "Tray",
		&"rocking": "Slam", &"stool": "Pogo",
	}
	_power_label = LABELS.get(id, "Power")
	_layout()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var finger: int = event.index
		if event.pressed and not event.canceled:
			var action := _at(event.position)
			if action == &"":
				return
			_press(finger, action)
		else:
			if not _touches.has(finger):
				return
			_release(finger)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touches.has(event.index):
		var current: StringName = _touches[event.index]
		if current in [&"move_left", &"move_right", &"move_idle"]:
			var action := _at(event.position)
			if action not in [&"move_left", &"move_right"]:
				action = &"move_idle"
			if action != current:
				_release(event.index)
				_press(event.index, action)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and OS.get_cmdline_user_args().has("--touch-preview") \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var action := _at(event.position)
			if action == &"":
				return
			_press(-1, action)
		elif _touches.has(-1):
			_release(-1)
		else:
			return
		get_viewport().set_input_as_handled()


func _at(pos: Vector2) -> StringName:
	for action: StringName in _controls:
		if not _available(action):
			continue
		var rect: Array = _controls[action]
		if pos.distance_squared_to(rect[0]) <= float(rect[1]) ** 2:
			return action
	return &""


func _available(action: StringName) -> bool:
	match action:
		&"interact":
			return _can_enter
		&"forms", &"special":
			return GameState.unlocked_forms.size() > 1
	return true


func _press(finger: int, action: StringName) -> void:
	_touches[finger] = action
	_surface.queue_redraw()
	match action:
		&"pause":
			pause_requested.emit()
		&"forms":
			forms_requested.emit()
		&"move_idle":
			pass
		_:
			Input.action_press(action)


func _release(finger: int) -> void:
	var action: StringName = _touches[finger]
	_touches.erase(finger)
	if action not in [&"pause", &"forms", &"move_idle"] and action not in _touches.values():
		Input.action_release(action)
	_surface.queue_redraw()


func _draw_buttons() -> void:
	var font := ThemeDB.fallback_font
	for action: StringName in _controls:
		if not _available(action):
			continue
		var layout: Array = _controls[action]
		var center: Vector2 = layout[0]
		var radius: float = layout[1]
		var title: String = layout[2]
		var dim: Color = layout[3]
		var pressed := action in _touches.values()
		_surface.draw_circle(center, radius, Color(dim.lightened(0.32) if pressed else dim, 0.82 if pressed else 0.56))
		_surface.draw_arc(center, radius - 1, 0.0, TAU, 36, Color(1.0, 0.93, 0.84, 0.62), 2, true)
		if title.is_empty():
			var direction := -1.0 if action == &"move_left" else 1.0
			_surface.draw_polyline(PackedVector2Array([
				center + Vector2(-8 * direction, -11), center + Vector2(7 * direction, 0),
				center + Vector2(-8 * direction, 11),
			]), Color("#fff3e1"), 4.0, true)
			continue
		var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		_surface.draw_string(font, center + Vector2(-width * 0.5, 8), title, HORIZONTAL_ALIGNMENT_LEFT,
				-1, 24, Color("#fff3e1"))
