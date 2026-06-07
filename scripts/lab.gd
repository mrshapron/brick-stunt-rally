extends Node3D
## Laboratory: a voxel brick car builder. Left click places a brick (in the
## selected color) on the highlighted cell, right click removes a brick. Orbit
## the view with the arrow keys / WASD. Save your design and Drive it - the car
## you build is used everywhere in the game.

const COLORS := ["#d2473b", "#e6b32e", "#7ab648", "#3b86d2", "#b06bff", "#ff7b29", "#ffffff", "#2b2f36"]
const BMIN := Vector3i(-2, 0, -3)
const BMAX := Vector3i(9, 7, 6)

var _camera: Camera3D
var _build_root: Node3D
var _ghost: MeshInstance3D
var _blocks: Dictionary = {}
var _selected: int = 0

var _yaw: float = 0.7
var _pitch: float = 0.6
var _dist: float = 16.0
var _center := Vector3(2.5, 1.0, 1.0)

var _ghost_cell: Vector3i
var _ghost_valid: bool = false
var _hover_cell: Vector3i
var _has_hover: bool = false

var _preview: ColorRect
var _feedback: Label
var _part: String = "block"
var _part_label: Label
var _original: Array = []


func _ready() -> void:
	_setup_world()
	_build_root = Node3D.new()
	add_child(_build_root)

	# Baseplate (build foundation).
	var base := BrickFactory.make_brick(Vector3(13, 1, 11), Color("#5a6070"), "static", true)
	base.position = Vector3(3.5, -1.0, 1.5)
	base.add_to_group("labbase")
	add_child(base)

	_ghost = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3.ONE * 0.96
	_ghost.mesh = gm
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(1, 1, 1, 0.4)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.emission_enabled = true
	gmat.emission = Color(1, 1, 1)
	gmat.emission_energy_multiplier = 0.3
	_ghost.mesh.material = gmat
	_ghost.visible = false
	add_child(_ghost)

	_original = GameState.get_car_design().duplicate(true)
	_rebuild_from(_original)

	_camera = Camera3D.new()
	_camera.fov = 55.0
	add_child(_camera)
	_camera.current = true
	_update_camera()

	_build_ui()


func _setup_world() -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -40, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.16, 0.18, 0.26)
	sky_mat.sky_horizon_color = Color(0.4, 0.44, 0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _process(delta: float) -> void:
	var rot := 1.6 * delta
	if Input.is_action_pressed("move_left"):
		_yaw -= rot
	if Input.is_action_pressed("move_right"):
		_yaw += rot
	if Input.is_action_pressed("move_up"):
		_pitch = clampf(_pitch + rot, 0.15, 1.4)
	if Input.is_action_pressed("move_down"):
		_pitch = clampf(_pitch - rot, 0.15, 1.4)
	_update_camera()
	_update_targets()

	if Input.is_action_just_pressed("menu"):
		get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _update_camera() -> void:
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_camera.global_position = _center + dir * _dist
	_camera.look_at(_center, Vector3.UP)


func _update_targets() -> void:
	_ghost_valid = false
	_has_hover = false
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var to := from + _camera.project_ray_normal(mouse) * 200.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		_ghost.visible = false
		return

	var n: Vector3 = hit.normal
	var p: Vector3 = hit.position + n * 0.5
	var pcell := Vector3i(roundi(p.x), roundi(p.y), roundi(p.z))
	if _in_bounds(pcell) and not _blocks.has(pcell):
		_ghost_cell = pcell
		_ghost.position = Vector3(pcell)
		_ghost.visible = true
		_ghost_valid = true
	else:
		_ghost.visible = false

	var col: Object = hit.collider
	if col and col is Node and col.is_in_group("labblock"):
		_has_hover = true
		_hover_cell = col.get_meta("cell")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and _ghost_valid:
			_place(_ghost_cell, Color(COLORS[_selected]), _part)
			Sfx.play_hit()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and _has_hover:
			_remove(_hover_cell)
			Sfx.play_hit()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_TAB:
				_cycle_part()
				return
			var idx: int = ke.keycode - KEY_1
			if idx >= 0 and idx < COLORS.size():
				_select(idx)


func _place(cell: Vector3i, color: Color, kind: String) -> void:
	if _blocks.has(cell) or not _in_bounds(cell):
		return
	var body := StaticBody3D.new()
	body.position = Vector3(cell)
	body.add_to_group("labblock")
	body.set_meta("cell", cell)
	body.set_meta("color", color.to_html(false))
	body.set_meta("kind", kind)

	body.add_child(_part_visual(kind, color))

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE
	cs.shape = bs
	body.add_child(cs)

	_build_root.add_child(body)
	_blocks[cell] = body


func _part_visual(kind: String, color: Color) -> Node3D:
	if kind == "wheel":
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.46
		c.bottom_radius = 0.46
		c.height = 0.42
		c.radial_segments = 16
		mi.mesh = c
		mi.rotation_degrees = Vector3(90, 0, 0)
		mi.material_override = _mat(Color(0.1, 0.1, 0.12))
		return mi
	elif kind == "rocket":
		var root := Node3D.new()
		var tube := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 0.34, 0.34)
		tube.mesh = b
		tube.material_override = _mat(Color(0.72, 0.72, 0.78))
		root.add_child(tube)
		var tip := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.24, 0.36, 0.36)
		tip.mesh = tb
		tip.position = Vector3(0.5, 0, 0)
		tip.material_override = _mat(Color(0.9, 0.2, 0.15))
		root.add_child(tip)
		return root
	var mb := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.94
	mb.mesh = bm
	mb.material_override = _mat(color)
	return mb


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m


func _set_part(p: String) -> void:
	_part = p
	if _part_label:
		_part_label.text = "Placing: " + _part.to_upper()


func _cycle_part() -> void:
	var order := ["block", "wheel", "rocket"]
	_set_part(order[(order.find(_part) + 1) % order.size()])


func _rebuild_from(design: Array) -> void:
	for cell in _blocks.keys():
		_blocks[cell].queue_free()
	_blocks.clear()
	for v in design:
		var kind: String = str(v[4]) if v.size() > 4 else "block"
		_place(Vector3i(int(v[0]), int(v[1]), int(v[2])), Color(str(v[3])), kind)


func _on_reset() -> void:
	_rebuild_from(_original)
	if _feedback:
		_feedback.text = "Reset to start"


func _remove(cell: Vector3i) -> void:
	if _blocks.has(cell):
		_blocks[cell].queue_free()
		_blocks.erase(cell)


func _collect() -> Array:
	var arr: Array = []
	for cell in _blocks:
		var b: Node = _blocks[cell]
		arr.append([cell.x, cell.y, cell.z, b.get_meta("color"), b.get_meta("kind")])
	return arr


func _in_bounds(c: Vector3i) -> bool:
	return c.x >= BMIN.x and c.x <= BMAX.x and c.y >= BMIN.y and c.y <= BMAX.y and c.z >= BMIN.z and c.z <= BMAX.z


func _select(i: int) -> void:
	_selected = i
	if _preview:
		_preview.color = Color(COLORS[i])


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _label(root, "LABORATORY", 48)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 16.0
	title.offset_bottom = 58.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.7, 0.85, 1.0)

	var info := _label(root, "Left: place   .   Right: remove   .   Arrows/WASD: rotate   .   1-8: color   .   Tab: switch part (block/wheel/rocket)", 22)
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.anchor_right = 1.0
	info.offset_top = -38.0
	info.offset_bottom = -12.0
	info.offset_left = 16.0
	info.modulate = Color(1, 1, 1, 0.8)

	# Color palette swatches.
	var pal := HBoxContainer.new()
	pal.add_theme_constant_override("separation", 8)
	pal.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pal.position = Vector2(-COLORS.size() * 31, -96)
	layer.add_child(pal)
	for i in COLORS.size():
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(54, 54)
		sw.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COLORS[i])
		sb.set_corner_radius_all(6)
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		sw.pressed.connect(_select.bind(i))
		pal.add_child(sw)

	# Buttons (top-right).
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -250.0
	col.offset_top = 16.0
	layer.add_child(col)
	_part_label = Label.new()
	_part_label.text = "Placing: BLOCK"
	_part_label.add_theme_font_size_override("font_size", 24)
	_part_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_part_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_part_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_part_label)

	# Part templates to pick from.
	var parts_row := HBoxContainer.new()
	parts_row.add_theme_constant_override("separation", 6)
	for entry in [["Block", "block"], ["Wheel", "wheel"], ["Rocket", "rocket"]]:
		var pb := Button.new()
		pb.text = entry[0]
		pb.custom_minimum_size = Vector2(74, 48)
		pb.focus_mode = Control.FOCUS_NONE
		pb.add_theme_font_size_override("font_size", 18)
		pb.pressed.connect(_set_part.bind(entry[1]))
		parts_row.add_child(pb)
	col.add_child(parts_row)

	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(230, 34)
	_preview.color = Color(COLORS[_selected])
	col.add_child(_preview)
	_add_button(col, "Save", _on_save)
	_add_button(col, "Clear", _on_clear)
	_add_button(col, "Reset car", _on_reset)
	_add_button(col, "Drive it!", _on_drive)
	_add_button(col, "Back (M)", _on_back)
	_feedback = _label(col, "", 24)
	_feedback.modulate = Color(0.6, 1.0, 0.6)


func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(230, 56)
	b.add_theme_font_size_override("font_size", 28)
	b.pressed.connect(cb)
	parent.add_child(b)


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	parent.add_child(l)
	return l


func _on_save() -> void:
	var d := _collect()
	if d.is_empty():
		if _feedback:
			_feedback.text = "Add some bricks first!"
		return
	GameState.set_car_design(d)
	if _feedback:
		_feedback.text = "Saved!"


func _on_clear() -> void:
	for cell in _blocks.keys():
		_blocks[cell].queue_free()
	_blocks.clear()


func _on_drive() -> void:
	var d := _collect()
	if d.is_empty():
		if _feedback:
			_feedback.text = "Add some bricks first!"
		return
	GameState.set_car_design(d)
	get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/hub.tscn")
