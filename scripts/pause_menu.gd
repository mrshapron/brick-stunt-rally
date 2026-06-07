class_name PauseMenu
extends CanvasLayer
## Code-built pause overlay. Toggled with ESC ("pause"). Freezes the game tree
## while open (this layer keeps processing via PROCESS_MODE_ALWAYS) and offers
## Resume / Restart / World Map / Quit, plus the sound toggle.

signal restart_requested
signal map_requested

var _is_open: bool = false
var _root: Control
var _mute_button: Button


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.2, 0.97)
	sb.border_color = Color(1.0, 0.82, 0.3, 1.0)
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(40)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vb)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	_add_button(vb, "Resume", _on_resume)
	_add_button(vb, "Restart", _on_restart)
	_add_button(vb, "World Map", _on_map)
	_mute_button = _add_button(vb, _mute_text(), _on_mute)
	_add_button(vb, "Quit Game", _on_quit)


func _add_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 52)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _mute_text() -> String:
	return "Sound: Off" if Sfx.is_muted() else "Sound: On"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _is_open:
		close()
	else:
		open()


func open() -> void:
	_is_open = true
	visible = true
	_mute_button.text = _mute_text()
	get_tree().paused = true


func close() -> void:
	_is_open = false
	visible = false
	get_tree().paused = false


func _on_resume() -> void:
	close()


func _on_restart() -> void:
	get_tree().paused = false
	_is_open = false
	visible = false
	restart_requested.emit()


func _on_map() -> void:
	get_tree().paused = false
	_is_open = false
	visible = false
	map_requested.emit()


func _on_mute() -> void:
	Sfx.toggle_mute()
	_mute_button.text = _mute_text()


func _on_quit() -> void:
	get_tree().quit()
