## DummyEnemy.gd — A training dummy that takes damage and can be defeated.
##
## Visual: Red placeholder with "DUMMY" label.
## When defeated: turns gray, fades out, and queue_free().
##
## Take damage via the Health component by calling take_damage(amount, knockback).

extends CharacterBody2D

class_name DummyEnemy

signal defeated

@export var max_health: float = 5.0

@onready var _health: Node = $Health
@onready var _hurtbox: Area2D = $Hurtbox
@onready var _visual: ColorRect = $Visual
@onready var _label: Label = $Visual/Label

var is_alive: bool = true
var _hit_flash_timer: float = 0.0
var _defeat_timer: float = 0.0
var _fade_out: bool = false


func _ready() -> void:
	_health.health_changed.connect(_on_hp_changed)
	_health.died.connect(_on_died)
	_health.max_health = max_health
	_health.current_hp = max_health
	_health.health_changed.emit(_health.current_hp, _health.max_health)
	_hurtbox.hitbox_entered.connect(_on_hitbox_entered)
	is_alive = true


func _physics_process(delta: float) -> void:
	if _hit_flash_timer > 0:
		_hit_flash_timer -= delta
		if _hit_flash_timer <= 0.0:
			_visual.color = Color(0.85, 0.15, 0.15, 1)

	if _fade_out:
		_defeat_timer -= delta
		if _visual:
			var new_alpha = clamp(_defeat_timer / 0.5, 0.0, 1.0)
			_visual.color = Color(0.5, 0.5, 0.5, new_alpha)
		if _defeat_timer <= 0.0 and is_alive:
			is_alive = false
			defeated.emit()
			queue_free()


func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	_label.text = "HP: %d/%d" % [
		max(0, int(current_hp)),
		int(max_hp)
	]


func _on_died() -> void:
	"""Called when Health component fires died signal."""
	_start_defeat()


func _on_hitbox_entered(hitbox_area) -> void:
	if not is_alive:
		return
	if not (hitbox_area is Hitbox):
		return
	# Flash white briefly
	_visual.color = Color(1.0, 1.0, 1.0, 1)
	_hit_flash_timer = 0.1

	# Damage
	var damage_amount = hitbox_area.damage
	var kb = -hitbox_area.hit_direction.normalized()
	print("[DummyEnemy] Took %d damage!" % damage_amount)
	take_damage(damage_amount, kb)


func take_damage(amount: float, kb: Vector2 = Vector2.ZERO) -> void:
	_health.take_damage(amount, kb)


func _start_defeat() -> void:
	_fade_out = true
	_defeat_timer = 0.5
