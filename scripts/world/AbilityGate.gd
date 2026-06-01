## AbilityGate.gd — A form-locked gate that blocks passage until the player
## transforms into the required chair form.
##
## Reusable, standalone scene. Drop into any level to require a specific
## form (e.g. "Armchair") before the player can progress.
## Basic Chair is always considered "locked out."

extends Area2D
class_name AbilityGate

## Name of the form that unlocks this gate.
## The player must be in this form to pass.
@export var required_form: String = "Armchair" :
	set(v):
		required_form = v
		_update_locked_text()
		_update_color()

## Display label shown above the gate (e.g. "Requires Armchair").
@export var gate_label: String = "Requires Armchair" :
	set(v):
		gate_label = v
		_update_locked_text()

## If true, the gate disappears after being unlocked (one-time use).
@export var consume_on_unlock: bool = false

## Emitted when the player successfully meets the requirement.
signal gate_unlocked(gate: AbilityGate)

## Emitted when the player tries to pass without the correct form.
signal gate_denied(gate: AbilityGate, player_form: String)

# Internal state
var _is_unlocked: bool = false
var _denied_timer: Timer = Timer.new()
var _lock_label: Label = Label.new()
var _vis_layer := Node2D.new()
var _col_layer := StaticBody2D.new()


func _ready() -> void:
	# --- Set up node structure ---
	_vis_layer.name = "Visuals"
	_col_layer.name = "Collision"
	add_child(_vis_layer)
	add_child(_col_layer)

	# --- Collision sensor (invisible circle at the gate opening) ---
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	var col_sens := CollisionShape2D.new()
	col_sens.name = "Sensor"
	col_sens.shape = circle
	col_sens.position = Vector2(0, -2)
	add_child(col_sens)

	# --- Bottom post (vertical rectangle) ---
	var vis_post := ColorRect.new()
	vis_post.size = Vector2(32, 80)
	vis_post.color = Color(1.0, 0.4, 0.4, 0.8)  # red = locked
	_vis_layer.add_child(vis_post)
	vis_post.position = Vector2(-16, 40)

	var post_shape := RectangleShape2D.new()
	post_shape.size = Vector2(32, 80)
	var post_col := CollisionShape2D.new()
	post_col.shape = post_shape
	post_col.position = Vector2(0, 40)
	_col_layer.add_child(post_col)

	# --- Top arch (horizontal rectangle) ---
	var vis_arch := ColorRect.new()
	vis_arch.size = Vector2(80, 12)
	vis_arch.color = Color(1.0, 0.4, 0.4, 0.8)
	_vis_layer.add_child(vis_arch)
	vis_arch.position = Vector2(-40, -40)

	var arch_shape := RectangleShape2D.new()
	arch_shape.size = Vector2(80, 12)
	var arch_col := CollisionShape2D.new()
	arch_col.shape = arch_shape
	arch_col.position = Vector2(0, -34)
	_col_layer.add_child(arch_col)

	# --- Floating label showing requirement ---
	_lock_label.text = "LOCKED: %s" % gate_label
	_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.add_theme_font_size_override("font_size", 12)
	_lock_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	add_child(_lock_label)
	_lock_label.position = Vector2(0, 56)

	# --- Body entered / exited for detecting player presence ---
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# --- Denied feedback timer (brief cooldown between denials) ---
	_denied_timer.wait_time = 0.5
	_denied_timer.one_shot = true
	_denied_timer.timeout.connect(_on_denied_timer_timeout)
	add_child(_denied_timer)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if _is_unlocked:
		return

	var player_form: String = _get_player_current_form(body)

	# --- Requirement check ---
	if required_form == player_form:
		_unlock()
	else:
		_denied(player_form)


func _get_player_current_form(body: Node2D) -> String:
	# Use the GameState autoload to read the current active form.
	# Resolve it by path so the gate scene still compiles in isolated load checks.
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		return str(game_state.get("current_form"))
	return "BasicChair"


func _unlock() -> void:
	_is_unlocked = true
	print("[AbilityGate] Gate unlocked! Required: %s" % required_form)
	gate_unlocked.emit(self)
	_update_locked_text()
	_update_color()
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	_col_layer.set_deferred("collision_layer", 0)
	_col_layer.set_deferred("collision_mask", 0)
	for child in _col_layer.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)

	if not consume_on_unlock:
		return

	# Animate out: brief rise then fade for one-time gates.
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position + Vector2(0, -10), 0.15)
	tween.tween_interval(0.2)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	await tween.finished
	queue_free()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return


func _denied(player_form: String) -> void:
	if _denied_timer.is_stopped():
		_denied_timer.start()
		gate_denied.emit(self, player_form)
		print("[AbilityGate] Denied: player is %s, need %s." % [player_form, required_form])


func _on_denied_timer_timeout() -> void:
	pass


# ---------- helpers ----------

func _update_locked_text() -> void:
	if _is_unlocked:
		_lock_label.text = "UNLOCKED!"
		_lock_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 1.0))
	else:
		_lock_label.text = "LOCKED: %s" % gate_label
		_lock_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))


func _update_color() -> void:
	for child in _vis_layer.get_children():
		if child is ColorRect:
			child.color = _get_gate_color()


func _get_gate_color() -> Color:
	return Color(0.4, 1.0, 0.4, 0.6) if _is_unlocked else Color(1.0, 0.4, 0.4, 0.8)
