## ChairForm.gd — Abstract base class for all chair forms.
##
## Each form must extend this class and override the exported properties
## to control movement, color, and label displayed by the HUD.
##
## Subclasses should also override build_visuals() if they want a distinct
## placeholder appearance, and _on_grapple() / _on_attack() / _on_special()
## if they have unique mechanics.

class_name ChairForm
extends RefCounted

## Name of this form (used for switching and display).
@export var form_name: String = "ChairForm"

## Whether this form is unlocked.
@export var is_unlocked: bool = false

## Movement properties (delegated by Player per active form).
@export var max_speed: float = 280.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2000.0
@export var air_control: float = 0.5
@export var jump_velocity: float = -520.0
@export var gravity_scale: float = 3.5

## Collision shape size override (Vector2.ZERO = no change).
@export var collision_shape: Vector2 = Vector2.ZERO

## Visual properties for placeholder rendering.
@export var body_color: Color = Color(0.6, 0.5, 0.3, 1.0)
@export var label_color: Color = Color.WHITE
@export var label_text: String = "Basic Chair"

## Called when the player enters the tree to attach the form.
func on_enter_player(player_node: CharacterBody2D) -> void:
	pass

## Called when the player leaves the tree.
func on_exit_player(player_node: CharacterBody2D) -> void:
	pass

## Called to update the player's visual placeholder.
## Subclasses override to change body_color, label_text, etc.
func on_visual_update(root_node: Node2D) -> void:
	pass

## Called when the player's attack (Melee) is performed.
func on_attack() -> void:
	pass

## Called when the player's special is performed.
## Override in subclasses to handle form-specific mechanics.
func on_special() -> void:
	pass

## Called when the form is activated (switched to).
func on_activate(_previous_form: ChairForm) -> void:
	pass

## Called when the form is deactivated (switched away from).
func on_deactivate(_next_form: ChairForm) -> void:
	pass
