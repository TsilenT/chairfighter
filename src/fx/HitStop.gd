extends Node
## Freeze-frame juice. Dips Engine.time_scale briefly on request, always
## restoring to DemoDriver.time_scale_base so demo runs stay accelerated.

var _depth := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.hitstop_requested.connect(_on_hitstop)


func _on_hitstop(duration: float) -> void:
	_depth += 1
	Engine.time_scale = DemoDriver.time_scale_base * 0.05
	# Real-time timer: unaffected by the dip itself.
	await get_tree().create_timer(duration, true, false, true).timeout
	_depth -= 1
	if _depth <= 0:
		_depth = 0
		Engine.time_scale = DemoDriver.time_scale_base
