## Health.gd — Generic health component for any entity.
##
## Exports max_health at init time. Call take_damage(amount, knockback_direction)
## to reduce HP; emits health_changed(current, max_hp) and died() when depleted.
##
## knockback_force is set to knockback_direction * 300 during take_damage
## — other scripts may apply it in their physics step.
##
## Layers (Bit flags — Godot 4):
##   Bit 0 (1) = static world
##   Bit 1 (2) = player
##   Bit 3 (8) = hurtboxes (damage receivers)
##   Bit 4 (16) = hitboxes (melee attack areas)

extends Node

class_name Health

signal health_changed(current_hp: float, max_hp: float)
signal died

@export var max_health: float = 10.0
var current_hp: float = 0.0
var knockback_force: Vector2 = Vector2.ZERO


func _ready() -> void:
	current_hp = max_health
	health_changed.emit(current_hp, max_health)


func take_damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> bool:
	"""Apply damage. Returns true if the entity died."""
	if amount < 0:
		amount = 0
	current_hp = max(current_hp - amount, 0.0)
	knockback_force = knockback.normalized() * 300.0
	health_changed.emit(current_hp, max_health)
	if current_hp <= 0.0:
		died.emit()
		return true
	return false


func heal(amount: float) -> void:
	"""Restore HP to max, clamped to max."""
	amount = max(amount, 0.0)
	current_hp = min(current_hp + amount, max_health)
	health_changed.emit(current_hp, max_health)


func is_alive() -> bool:
	return current_hp > 0.0


# Bit indices
const BIT_HURTBOX  := 3  # bit 3 = layer 4
const BIT_HITBOX   := 4  # bit 4 = layer 5
const BIT_STATIC   := 0
