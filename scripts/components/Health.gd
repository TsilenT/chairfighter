## Health.gd — Generic hit-point health component.
##
## Attach to any node that can take damage (player, enemy, boss).
## Tracks current health, max health, dead state, and emits signals
## so other systems react to damage/death events.
##
## Layer/Mask convention (Godot 4 bit flags):
##  - Layer  1 (1) = collision world / static bodies
##  - Layer  3 (4) = hitboxes (melee attacks)
##  - Layer  4 (8) = hurtboxes (take damage targets)
##  - Layer  5 (16) = enemies
##  - Layer  6 (32) = grapple points
##  - Layer  7 (64) = ability gates

extends Node2D

class_name Health

## Max HP for this entity.
@export var max_health: float = 10.0

## Emitted when health changes value (current_hp, max_hp).
signal health_changed(current: float, max_hp: float)

## Emitted when health reaches zero.
signal died

## Max HP (read-only after init unless explicitly changed).
var max_hp: float = 0.0

## Current health value (read-only — use take_damage / heal instead).
var current_hp: float = 0.0

## Invincibility frame duration in seconds after taking damage.
@export var invincible_duration: float = 0.5

## Current invincibility timer countdown.
var _invincible_timer: float = 0.0

## Whether this entity can currently take damage.
var invincible: bool = false


func _ready() -> void:
	max_hp = max_health
	current_hp = max_health
	invincible = false
	_invincible_timer = 0.0
	health_changed.emit(current_hp, max_hp)


func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO) -> float:
	"""Apply damage. Returns the actual damage dealt (0.0 if dead or invincible)."""
	if current_hp <= 0:
		return 0.0

	if invincible:
		return 0.0

	# Start invincibility frames
	_invincible_timer = invincible_duration
	invincible = true

	current_hp = max(0.0, current_hp - amount)
	health_changed.emit(current_hp, max_hp)

	if current_hp <= 0.0:
		died.emit()
		return amount

	return amount


func _process(delta: float) -> void:
	if invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			invincible = false


func heal(amount: float) -> void:
	"""Restore HP, capped at max_hp."""
	if current_hp <= 0:
		return
	current_hp = min(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


func reset() -> void:
	"""Reset health to full and clear dead state."""
	current_hp = max_hp
	max_hp = max_health
	invincible = false
	_invincible_timer = 0.0
	health_changed.emit(current_hp, max_hp)
