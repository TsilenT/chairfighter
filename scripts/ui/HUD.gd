## HUD.gd — Simple HUD that shows the current chair form.
##
## Reads the active form from GameState and updates a label and color box.

extends CanvasLayer


@onready var form_label := $FormLabel as Label
@onready var form_color_box := $FormColorBox as ColorRect


func _ready() -> void:
	var form_def : ChairForm = GameState.get_current_form_def()
	if form_def:
		_update_display(form_def.form_name, form_def.body_color, form_def.label_text)
	
	GameState.form_unlocked.connect(_on_form_unlocked)


func _process(_delta: float) -> void:
	## Update display each frame so it stays in sync with GameState.
	var form_def : ChairForm = GameState.get_current_form_def()
	if form_def and form_label:
		if form_label.text != form_def.label_text:
			_update_display(form_def.form_name, form_def.body_color, form_def.label_text)


func _update_display(name: String, color: Color, label: String) -> void:
	if form_label:
		form_label.text = label
	if form_color_box:
		form_color_box.color = color * 0.8


func _on_form_unlocked(form_name: String) -> void:
	var form_def : ChairForm = GameState.get_current_form_def()
	if form_def:
		_update_display(form_def.form_name, form_def.body_color, form_def.label_text)
	else:
		if form_label:
			form_label.text = "%s unlocked!" % form_name
