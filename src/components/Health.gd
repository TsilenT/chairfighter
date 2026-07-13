class_name Health
extends Node
## Reusable health pool shared by player, enemies, and bosses. Damage flows
## exclusively Hitbox → Hurtbox → Health; owners react through signals and
## apply knockback themselves (they own their physics).
##
## Invulnerability counts down in physics time (not wall clock) so behavior
## is identical under Engine.time_scale changes (demo runs, hitstop).

signal changed(current: float, maximum: float)
signal damaged(amount: float, knockback: Vector2)
signal died

@export var max_health: float = 5.0
@export var invuln_time: float = 0.6

var current: float
var _invuln_left := 0.0


func _ready() -> void:
	current = max_health


func _physics_process(delta: float) -> void:
	if _invuln_left > 0.0:
		_invuln_left = maxf(0.0, _invuln_left - delta)


func is_alive() -> bool:
	return current > 0.0


func is_invulnerable() -> bool:
	return _invuln_left > 0.0


## Returns true if the hit landed (not invulnerable / already dead).
func damage(amount: float, knockback: Vector2 = Vector2.ZERO) -> bool:
	if not is_alive() or is_invulnerable():
		return false
	current = maxf(0.0, current - amount)
	_invuln_left = invuln_time
	changed.emit(current, max_health)
	damaged.emit(amount, knockback)
	if current <= 0.0:
		died.emit()
	return true


## Unconditional death (kill floors); ignores invulnerability.
func kill() -> void:
	if not is_alive():
		return
	current = 0.0
	changed.emit(current, max_health)
	died.emit()


func heal(amount: float) -> void:
	if not is_alive():
		return
	current = minf(max_health, current + amount)
	changed.emit(current, max_health)


func reset_full() -> void:
	current = max_health
	_invuln_left = 0.0
	changed.emit(current, max_health)
