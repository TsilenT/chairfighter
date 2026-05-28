## Hitbox.gd — Melee hitbox generator.
##
## Used by the attacker (Player melee) to detect hits on enemies.
## Active for a brief window then self-deactivates. Uses Area2D to
## detect overlaps with Hurtbox nodes on layer 8.
##
## Activation is explicit — call hitbox.activate() when the melee
## swing animation occurs.

extends Area2D

## Damage this hitbox deals.
@export var damage: float = 2.0

## Direction of the hit (for knockback on victim).
@export var hit_direction: Vector2 = Vector2.RIGHT

## Duration (seconds) this hitbox stays active.
@export var active_duration: float = 0.15

## Cooldown (seconds) before this hitbox can be activated again.
@export var cooldown_duration: float = 0.25

## Layer constants: 3 = hitboxes, 4 = hurtboxes, 5 = enemies
const LAYER_HITBOX := 3
const LAYER_HURTBOX := 4
const LAYER_ENEMY   := 5


var _active: bool = false
var _active_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _bodies_hit: Dictionary = {}  # Track which hurtboxes already took damage this activation


func _ready() -> void:
	set_collision_layer_bit(LAYER_HITBOX, true)
	set_collision_mask_bit(LAYER_HURTBOX, true)
	_active = false
	_active_timer = 0.0
	_cooldown_timer = 0.0


func activate() -> void:
	"""Activate this hitbox for the active duration. Must not already be active with a cooldown."""
	if _active or _cooldown_timer > 0:
		return
	_active = true
	_active_timer = active_duration
	_cooldown_timer = cooldown_duration
	_bodies_hit.clear()
	modulate = Color.WHITE


func _process(delta: float) -> void:
	if _active:
		_active_timer -= delta
		if _active_timer <= 0:
			_deactivate()
	if _cooldown_timer > 0:
		_cooldown_timer -= delta


func _deactivate() -> void:
	"""Hide and reset this hitbox."""
	_active = false
	_bodies_hit.clear()
	set_visible(false)


func _on_body_entered(body: Node2D) -> void:
	if not _active:
		return
	if body in _bodies_hit:
		return  # Already hit this hurtbox this activation

	var hurtbox: Hurtbox = _find_hurtbox(body)
	if hurtbox == null:
		return

	# Find Health on the same node or children
	var health: Health = _find_health(body)
	if health == null:
		return

	# Apply damage
	var actual_damage = health.take_damage(damage, hit_direction)
	if actual_damage > 0:
		_bodies_hit[body] = true
		_deactivate()


func _find_health(node: Node2D) -> Health:
	"""Recursively search node and children for a Health component."""
	if node is Health:
		return node
	for child in node.get_children():
		if _find_health(child):
			return _find_health(child)
	return null


func _find_hurtbox(node: Node2D) -> Hurtbox:
	"""Recursively search node and children for a Hurtbox (or Hurtbox ancestor)."""
	if node is Hurtbox:
		return node
	for child in node.get_children():
		if _find_hurtbox(child):
			return _find_hurtbox(child)
	return null
