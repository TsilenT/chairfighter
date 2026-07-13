class_name ZoneBase
extends Node2D
## Base for all zone scenes. Zone scene contract (see the rebuild plan):
## SpawnPoints/ (Marker2D, must include "Default"), Geometry/ (Platforms),
## Route/ (validator waypoints), Doors/, Enemies/, optional Boss/, Props/.

@export var zone_display_name: String = ""
@export var camera_limits: Rect2 = Rect2(-200, -1200, 4000, 1800)
@export var theme_res: ZoneTheme


func _ready() -> void:
	add_to_group("zone")
	if theme_res == null:
		theme_res = ZoneTheme.new()
	_setup_background()


func apply_camera_limits(rig: CameraRig) -> void:
	rig.set_zone_limits(camera_limits)


func _setup_background() -> void:
	# Full-screen gradient behind everything, in canvas space.
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var grad := Gradient.new()
	grad.set_color(0, theme_res.bg_top)
	grad.set_color(1, theme_res.bg_bottom)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
