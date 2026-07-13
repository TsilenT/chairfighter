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
	_setup_parallax()
	_setup_vignette()


func apply_camera_limits(rig: CameraRig) -> void:
	rig.set_zone_limits(camera_limits)


func _physics_process(_delta: float) -> void:
	# Kill floor: falling below the camera bounds is death (respawn at
	# checkpoint). Zones never need bottomless-pit special-casing.
	var p := get_tree().get_first_node_in_group("player")
	if p == null or not is_ancestor_of(p):
		return
	if (p as Node2D).global_position.y > camera_limits.end.y + 150.0 \
			and p.has_method("is_alive") and p.is_alive() and p.has_method("kill"):
		p.kill()


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


## Two silhouette "furniture skyline" layers, deterministic per zone name.
func _setup_parallax() -> void:
	var bg := ParallaxBackground.new()
	bg.layer = -9
	add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(zone_display_name)
	var floor_y := camera_limits.position.y + camera_limits.size.y * 0.62
	for config in [[0.22, theme_res.parallax_far, 1.35], [0.45, theme_res.parallax_near, 1.0]]:
		var layer := ParallaxLayer.new()
		layer.motion_scale = Vector2(config[0], clampf(config[0] + 0.35, 0.0, 1.0))
		bg.add_child(layer)
		var strip := Node2D.new()
		strip.set_script(load("res://src/fx/SilhouetteStrip.gd"))
		strip.setup(rng, camera_limits, floor_y, config[1], config[2])
		layer.add_child(strip)


## Soft radial vignette above gameplay, below the game UI layers.
func _setup_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	float v = smoothstep(0.38, 0.95, length(d * vec2(1.15, 1.0)));
	COLOR = vec4(0.02, 0.01, 0.02, v * 0.34);
}
"""
	mat.shader = shader
	rect.material = mat
	layer.add_child(rect)
