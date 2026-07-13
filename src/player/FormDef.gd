class_name FormDef
extends Resource
## One resource per chair form (src/forms/<id>.tres). Movement is authored
## as design metrics (jump height in px, time to apex); velocities and
## gravity are DERIVED so levels and physics can never drift apart.

@export var id: StringName
@export var display_name: String = ""
@export var run_speed: float = 340.0
@export var accel: float = 2600.0
@export var decel: float = 3000.0
@export var air_control: float = 0.65
@export var jump_height: float = 150.0
@export var time_to_apex: float = 0.38
@export var fall_gravity_mult: float = 1.6
@export var attack_damage: float = 2.0
@export var attack_range: float = 52.0
@export var attack_cooldown: float = 0.3
@export var collider_height: float = 56.0
@export var body_color: Color = Color(0.55, 0.36, 0.2)
@export var sprite_path: String = ""
@export_multiline var unlock_blurb: String = ""


func rise_gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)


func fall_gravity() -> float:
	return rise_gravity() * fall_gravity_mult


func jump_velocity() -> float:
	return -rise_gravity() * time_to_apex
