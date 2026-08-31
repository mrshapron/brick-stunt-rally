extends DriveScene
## A flight level in the Aero World: fly the aircraft through a course of glowing
## rings in order, then through the golden finish ring, against the clock. Built
## procedurally from the level's data (kind + ring count + spread).

var _craft: Aircraft
var _fly_cam: FlyCamera
var _pause_menu: PauseMenu

var _rings: Array[Node3D] = []
var _ring_pos: Array[Vector3] = []
var _ring_mats: Array[StandardMaterial3D] = []
var _ring_radius: float = 4.6
var _next: int = 0
var _start_pos: Vector3 = Vector3(0, 18, 0)
var _last_safe: Vector3 = Vector3(0, 18, 0)

var _elapsed: float = 0.0
var _running: bool = false
var _finished: bool = false
var _t: float = 0.0

var _timer_label: Label
var _ring_label: Label
var _msg_panel: Control
var _msg_title: Label
var _msg_sub: Label
var _accent: Color = Color("#19e0c8")


func _ready() -> void:
	var data := GameState.get_sky_level(GameState.sky_current)
	var kind := str(data.get("kind", "plane"))
	_accent = Color("#ff8a3a") if kind == "heli" else Color("#19e0c8")

	add_light_and_env(Color("#3a6fc0"), Color("#cfe2f5"))
	add_fade()
	_add_sky_decor()
	_build_course(data)

	_craft = Aircraft.new()
	add_child(_craft)
	var base := Color("#e23a6d") if kind == "heli" else Color("#2f7fd0")
	_craft.configure(kind, base, Color("#f0f0f0"))
	_craft.reset_to(_start_pos, 0.0)

	_fly_cam = FlyCamera.new()
	_fly_cam.target = _craft
	add_child(_fly_cam)

	_build_hud(str(data.get("name", "Flight")))
	_setup_pause_menu()
	add_touch_controls("fly", true)

	GameState.sky_current = GameState.sky_current
	_running = true


func _setup_pause_menu() -> void:
	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)
	_pause_menu.restart_requested.connect(func() -> void: transition_to("res://scenes/sky_level.tscn"))
	_pause_menu.map_requested.connect(func() -> void: transition_to("res://scenes/sky_hub.tscn"))


func _build_course(data: Dictionary) -> void:
	var count := int(data.get("rings", 6))
	var spread := float(data.get("spread", 30.0))
	var climb := float(data.get("climb", 6.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + GameState.sky_current * 17

	var pos := Vector3(0, 18, 0)
	var dir := Vector3(0, 0, -1)
	_start_pos = pos - dir * 14.0
	_last_safe = _start_pos

	for i in count:
		pos += dir * spread
		var turn := rng.randf_range(-0.45, 0.45)
		dir = dir.rotated(Vector3.UP, turn).normalized()
		pos.y += rng.randf_range(-climb * 0.35, climb)
		pos.y = clampf(pos.y, 12.0, 60.0)
		_add_ring(pos, dir, _accent, false)

	# Golden finish ring a little further on.
	pos += dir * spread
	pos.y = clampf(pos.y, 12.0, 60.0)
	_add_ring(pos, dir, Color("#ffd24a"), true)


func _add_ring(pos: Vector3, dir: Vector3, color: Color, finish: bool) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	if dir.length() > 0.01:
		node.look_at(pos + dir, Vector3.UP)

	var torus := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = _ring_radius
	tm.outer_radius = _ring_radius + (1.2 if finish else 0.8)
	tm.rings = 8
	tm.ring_segments = 22
	torus.mesh = tm
	torus.rotation_degrees = Vector3(90, 0, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	m.roughness = 0.3
	torus.material_override = m
	node.add_child(torus)

	# Floating sparkle pillar so rings are easy to spot from afar.
	var beam := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.12
	bc.bottom_radius = 0.12
	bc.height = 60.0
	beam.mesh = bc
	beam.position = Vector3(0, -28.0, 0)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(color, 0.25)
	bm.emission_enabled = true
	bm.emission = color
	bm.emission_energy_multiplier = 1.0
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = bm
	node.add_child(beam)

	_rings.append(node)
	_ring_pos.append(pos)
	_ring_mats.append(m)


func _add_sky_decor() -> void:
	# Floating brick islands + clouds for a sense of place and speed.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + GameState.sky_current
	for i in 14:
		var p := Vector3(rng.randf_range(-160, 160), rng.randf_range(0, 50), rng.randf_range(-260, 60))
		var s := rng.randf_range(6.0, 16.0)
		var isl := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(s, rng.randf_range(3, 7), s)
		isl.mesh = bm
		isl.position = p
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color("#6fae4f").lightened(rng.randf_range(-0.1, 0.1))
		isl.material_override = mm
		add_child(isl)
		var cap := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(s + 0.6, 1.0, s + 0.6)
		cap.mesh = cb
		cap.position = p + Vector3(0, bm.size.y * 0.5, 0)
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color("#8fd060")
		cap.material_override = cm
		add_child(cap)
	for i in 22:
		var cp := Vector3(rng.randf_range(-200, 200), rng.randf_range(8, 58), rng.randf_range(-300, 80))
		_cloud(cp, rng)


func _build_hud(level_name: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _hud_label(level_name, 30)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 14.0
	title.offset_bottom = 52.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	_timer_label = _hud_label("0.0s", 34)
	_timer_label.anchor_left = 0.0
	_timer_label.anchor_right = 1.0
	_timer_label.offset_top = 50.0
	_timer_label.offset_bottom = 92.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_timer_label)

	_ring_label = _hud_label("", 26)
	_ring_label.position = Vector2(20, 16)
	_ring_label.add_theme_color_override("font_color", _accent)
	root.add_child(_ring_label)

	# Centered win/lose message panel.
	_msg_panel = Control.new()
	_msg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_panel.visible = false
	root.add_child(_msg_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_msg_panel.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	_msg_title = _hud_label("", 64)
	_msg_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_msg_title)
	_msg_sub = _hud_label("", 26)
	_msg_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_msg_sub)

	_update_ring_label()


func _hud_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _update_ring_label() -> void:
	if _ring_label:
		_ring_label.text = "Rings  %d / %d" % [_next, _rings.size()]


func _process(delta: float) -> void:
	_t += delta
	# Pulse the next target ring so the player always knows where to go.
	for i in _ring_mats.size():
		var e := 2.0
		if i == _next:
			e = 3.5 + sin(_t * 6.0) * 1.5
		_ring_mats[i].emission_energy_multiplier = e

	if _finished:
		return
	if not _running:
		return

	_elapsed += delta
	if _timer_label:
		_timer_label.text = "%.1fs" % _elapsed

	if not is_instance_valid(_craft):
		return

	# Crashed into the ground/void: respawn at the last cleared ring.
	if _craft.global_position.y < 2.0:
		Sfx.play_smash()
		Effects.explosion(self, _craft.global_position + Vector3(0, 1, 0), 1.4, _accent)
		_craft.reset_to(_last_safe + Vector3(0, 6, 0), _craft._yaw)
		return

	# Reached the next ring?
	if _next < _ring_pos.size():
		if _craft.global_position.distance_to(_ring_pos[_next]) < _ring_radius + 1.2:
			_pass_ring()


func _pass_ring() -> void:
	_last_safe = _ring_pos[_next]
	Sfx.play_checkpoint()
	Effects.explosion(self, _ring_pos[_next], 0.7, _accent)
	_next += 1
	_update_ring_label()
	if _next >= _ring_pos.size():
		_win()


func _win() -> void:
	if _finished:
		return
	_finished = true
	_running = false
	Sfx.play_finish()
	var idx := GameState.sky_current
	var first_clear := not GameState.sky_is_complete(idx)
	var is_best := GameState.record_sky_time(idx, _elapsed)
	var earned := 60 + idx * 25 + (60 if first_clear else 0)
	GameState.add_money(earned)
	var sub := "Best!  " if is_best else ""
	sub += "+$%d" % earned
	sub += "\n" + ("Tap the screen to continue" if DisplayServer.is_touchscreen_available() else "Press Enter to continue")
	_show_message("Course Clear!  %.1fs" % _elapsed, sub, Color("#7CFC8A"))


func _show_message(title: String, sub: String, color: Color) -> void:
	if _msg_panel == null:
		return
	_msg_panel.visible = true
	_msg_title.text = title
	_msg_title.add_theme_color_override("font_color", color)
	_msg_sub.text = sub


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		if event.is_action_pressed("advance") or (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
			transition_to("res://scenes/sky_hub.tscn")
		return
	if event.is_action_pressed("menu"):
		transition_to("res://scenes/sky_hub.tscn")
