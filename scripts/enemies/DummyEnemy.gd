## DummyEnemy.gd — Placeholder training dummy enemy.
##
## A non-moving StaticBody2D with a Health component and visible
## defeat animation. Used for combat testing during development.

extends StaticBody2D

const DAMAGE_LAYER := 5
const HP_LAYER := 4


func _ready() -> void:
	pass
