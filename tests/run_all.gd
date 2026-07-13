extends SceneTree
## Headless test entry point:
##   godot --headless --path . -s res://tests/run_all.gd
## Discovers tests/unit/test_*.gd, each exposing:
##   func run(tree: SceneTree) -> Array   # of failure strings (may await)
## Exits 0 on all green, 1 otherwise.


func _initialize() -> void:
	var runner := Node.new()
	runner.name = "TestRunner"
	runner.set_script(load("res://tests/TestRunnerNode.gd"))
	root.add_child(runner)
