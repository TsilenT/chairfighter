extends Control

signal resume_requested
signal form_requested(id: StringName)

const Style := preload("res://src/ui/MenuStyle.gd")

@onready var _menu: VBoxContainer = $Center


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fill()


func _fill() -> void:
	var objective := Style.label(GameState.current_objective(), 18)
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(objective)

	var forms := GridContainer.new()
	var player := get_tree().get_first_node_in_group("player") as Player
	var can_swap := player != null and player.state == Player.State.MOVE and not player.is_folded()
	if not can_swap:
		var warning := Style.label("Finish the move or unfold before changing seats.", 16)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_menu.add_child(warning)
	forms.columns = 3
	forms.add_theme_constant_override("h_separation", 8)
	forms.add_theme_constant_override("v_separation", 8)
	_menu.add_child(forms)
	var selected: Button
	for id: StringName in GameState.FORM_ORDER:
		var form := load("res://src/forms/%s.tres" % id) as FormDef
		var option := Style.button(form.display_name if GameState.is_unlocked(id) else "Locked")
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.disabled = not can_swap or not GameState.is_unlocked(id)
		option.pressed.connect(form_requested.emit.bind(id))
		forms.add_child(option)
		if id == GameState.current_form:
			option.add_theme_stylebox_override("normal",
					Style.panel(Color("#49374e"), Color("#d29c65"), 2, 9))
			if can_swap:
				selected = option

	var help := Style.label(_controls(), 16)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(help)

	var shake := CheckButton.new()
	shake.text = "Camera shake"
	shake.button_pressed = GameState.camera_shake
	shake.toggled.connect(GameState.set_camera_shake)
	_menu.add_child(shake)

	var resume := Style.button("Resume")
	resume.pressed.connect(resume_requested.emit)
	_menu.add_child(resume)
	if selected != null:
		selected.grab_focus()
	else:
		resume.grab_focus()


func _controls() -> String:
	if GameState.touch_controls:
		return "Hold Jump for height. Power follows your chair. Use Enter at a doorway."
	return "Keyboard  A/D or arrows · Space · J/Z attack · K/X power · W/F enter\nGamepad  Stick · A jump · X attack · B power · Y enter · LB/RB swap\nForms  Tab or Select · Quick swap  Q/E"
