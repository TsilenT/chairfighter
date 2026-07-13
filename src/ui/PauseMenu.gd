extends Control
## Pause overlay. Game.gd owns the pause toggle; this is display-only.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
