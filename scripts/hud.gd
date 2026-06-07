class_name HUD
extends Control
## Code-built heads-up display: live stats top-left, a flip flash, a controls
## hint, and a level-complete panel. Built in code so it stays easy to tweak.

var _level_name: String = "Level"
var _level_label: Label
var _time_label: Label
var _speed_label: Label
var _flip_label: Label
var _flip_flash: Label
var _flash_timer: float = 0.0

var _complete: PanelContainer
var _complete_title: Label
var _complete_body: Label
var _mute_button: Button
var _hp_fill: ColorRect
var _enemies_label: Label
const HP_W: float = 220.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var stats := VBoxContainer.new()
	stats.position = Vector2(20, 16)
	stats.add_theme_constant_override("separation", 4)
	add_child(stats)

	_level_label = _make_label(stats, _level_name, 26)
	_time_label = _make_label(stats, "Time  0.00", 22)
	_speed_label = _make_label(stats, "Speed  0 km/h", 22)

	var hp_row := Control.new()
	hp_row.custom_minimum_size = Vector2(HP_W, 24)
	stats.add_child(hp_row)
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.55)
	hp_bg.position = Vector2(0, 2)
	hp_bg.size = Vector2(HP_W, 20)
	hp_row.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.2, 1.0, 0.3)
	_hp_fill.position = Vector2(2, 4)
	_hp_fill.size = Vector2(HP_W - 4, 16)
	hp_row.add_child(_hp_fill)
	var hp_text := _make_label(hp_row, "HP", 14)
	hp_text.position = Vector2(6, 2)

	_enemies_label = _make_label(stats, "", 22)
	_enemies_label.visible = false
	_flip_label = _make_label(stats, "Flips  0", 22)

	var hint := _make_label(self, "WASD/Arrows drive   .   Space/F fire   .   E get out / in car   .   R restart   .   M world map", 18)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(20, -40)
	hint.modulate = Color(1, 1, 1, 0.75)

	_flip_flash = _make_label(self, "FLIP!", 64)
	_flip_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flip_flash.position = Vector2(0, 120)
	_flip_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flip_flash.modulate = Color(1.0, 0.85, 0.2)
	_flip_flash.visible = false

	_mute_button = Button.new()
	_mute_button.anchor_left = 1.0
	_mute_button.anchor_right = 1.0
	_mute_button.offset_left = -150.0
	_mute_button.offset_top = 16.0
	_mute_button.offset_right = -16.0
	_mute_button.offset_bottom = 54.0
	_mute_button.focus_mode = Control.FOCUS_NONE
	_mute_button.add_theme_font_size_override("font_size", 18)
	_mute_button.text = _mute_text()
	_mute_button.pressed.connect(_on_mute_pressed)
	add_child(_mute_button)

	_build_complete_panel()


func _mute_text() -> String:
	return "Sound: Off" if Sfx.is_muted() else "Sound: On"


func _on_mute_pressed() -> void:
	Sfx.toggle_mute()
	_mute_button.text = _mute_text()


func _make_label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


func _build_complete_panel() -> void:
	_complete = PanelContainer.new()
	_complete.set_anchors_preset(Control.PRESET_CENTER)
	_complete.visible = false
	add_child(_complete)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_complete.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vb)

	_complete_title = _make_label(vb, "LEVEL COMPLETE", 40)
	_complete_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_complete_body = _make_label(vb, "", 24)
	_complete_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func set_level_name(n: String) -> void:
	_level_name = n
	if _level_label:
		_level_label.text = n


func update_hud(elapsed: float, speed_kmh: float, flips: int) -> void:
	_time_label.text = "Time  %0.2f" % elapsed
	_speed_label.text = "Speed  %d km/h" % int(round(speed_kmh))
	_flip_label.text = "Flips  %d" % flips
	if _flash_timer > 0.0:
		_flash_timer -= get_process_delta_time()
		_flip_flash.modulate.a = clampf(_flash_timer / 0.8, 0.0, 1.0)
		if _flash_timer <= 0.0:
			_flip_flash.visible = false


func set_health(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	_hp_fill.size.x = (HP_W - 4) * ratio
	_hp_fill.color = Color(1.0, 0.2, 0.15).lerp(Color(0.2, 1.0, 0.3), ratio)


func set_combat(count: int) -> void:
	_enemies_label.visible = true
	set_enemies(count)


func set_enemies(count: int) -> void:
	_enemies_label.text = "Enemies left: %d" % count


func show_message(title: String, body: String) -> void:
	_complete.visible = true
	_complete_title.text = title
	_complete_body.text = body


func flash_flip() -> void:
	_flip_flash.visible = true
	_flip_flash.modulate.a = 1.0
	_flash_timer = 0.8


func show_complete(time: float, best: float, is_best: bool, reward: String = "") -> void:
	_complete.visible = true
	var best_txt := "%0.2f" % best if best >= 0.0 else "--"
	var lines := "Your time: %0.2f s\nBest: %s s" % [time, best_txt]
	if is_best:
		lines += "\nNew best!"
	if reward != "":
		lines += "\n\nWORLD COMPLETE!  You won the %s!\nFind it in the Parking lot." % reward
	lines += "\n\nPress Enter/N to continue   .   R to retry"
	_complete_body.text = lines
