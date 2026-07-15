class_name Hitbox
extends Area2D
## Damage dealer. Layer 4 (hitbox), masks layer 5 (hurtbox). Two modes:
##  - burst: call activate(duration); hits each target at most once per burst.
##  - continuous: monitoring stays on (contact damage); re-hits a lingering
##    target every rehit_interval.
## Faction prevents friendly fire ("player" vs "enemy").
## All timing runs on physics time so Engine.time_scale cannot skew it.

@export var damage: float = 1.0
@export var knockback_strength: float = 260.0
@export var faction: StringName = &"enemy"
@export var continuous := false
@export var rehit_interval := 0.8

var _clock := 0.0
var _burst_left := 0.0
var _hit_expiry: Dictionary = {}   # hurtbox instance_id -> clock time when re-hit allowed


func _ready() -> void:
	collision_layer = 8
	collision_mask = 16
	monitorable = false
	monitoring = continuous
	area_entered.connect(_on_area_entered)


func activate(duration: float) -> void:
	_hit_expiry.clear()
	_burst_left = duration
	monitoring = true
	for area in get_overlapping_areas():
		_on_area_entered(area)


func deactivate() -> void:
	_burst_left = 0.0
	# Deactivation can be triggered by a damage callback while physics is
	# flushing Area2D overlaps (for example, an enemy hits a spinning Bar
	# Stool). Defer the monitor mutation so that response is always legal.
	set_deferred("monitoring", continuous)
	_hit_expiry.clear()


func _physics_process(delta: float) -> void:
	_clock += delta
	if _burst_left > 0.0:
		_burst_left -= delta
		if _burst_left <= 0.0 and not continuous:
			monitoring = false
	if continuous and monitoring:
		for area in get_overlapping_areas():
			_on_area_entered(area)


func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or hurtbox.faction == faction:
		return
	var id := hurtbox.get_instance_id()
	if _hit_expiry.has(id) and _clock < float(_hit_expiry[id]):
		return
	# Burst mode: one hit per activation. Continuous: re-hit on an interval.
	_hit_expiry[id] = _clock + rehit_interval if continuous else INF
	hurtbox.receive_hit(self)


func knockback_for(target: Node2D) -> Vector2:
	var dir := Vector2.RIGHT
	if target.global_position.x < global_position.x:
		dir = Vector2.LEFT
	# Standard arc: mostly horizontal with an upward pop.
	return (dir * 0.85 + Vector2.UP * 0.55).normalized() * knockback_strength
