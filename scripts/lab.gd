extends Node3D
## Laboratory: a LEGO-style car builder on a fine stud/plate grid. Pick a part
## type (brick/plate/tile/slope/wheel/rocket), a size and a color, then click to
## stack it. Drag to orbit, pinch to zoom; on desktop left-click places, right
## click (or Remove mode) deletes. Save and Drive your creation.

const COLORS := ["#d2473b", "#e6b32e", "#7ab648", "#3b86d2", "#b06bff", "#ff7b29", "#ffffff", "#2b2f36", "#19e0c8", "#e23a6d", "#8a6b4a", "#c6d2da"]
const TYPES := ["brick", "plate", "tile", "slope", "wheel", "rocket"]
const SIZES := [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 4)]
const COSTS := {"brick": 5, "plate": 3, "tile": 4, "slope": 6, "wheel": 25, "rocket": 45}
const GX := 26
const GY := 30
const GZ := 16

var _camera: Camera3D
var _build_root: Node3D
var _ghost: MeshInstance3D

var _parts: Dictionary = {}      # id -> StaticBody3D
var _occupied: Dictionary = {}   # Vector3i -> id
var _next_id: int = 0

var _ptype: String = "brick"
var _psize: Vector2i = Vector2i(2, 2)
var _prot: int = 0
var _selected: int = 0

var _yaw: float = 0.7
var _pitch: float = 0.6
var _dist: float = 8.5
var _center := Vector3(2.2, 0.7, 1.0)

var _ghost_cell: Vector3i
var _ghost_valid: bool = false
var _hover_id: int = -1
var _has_hover: bool = false

var _preview: ColorRect
var _feedback: Label
var _sel_label: Label
var _money_label: Label
var _original: Array = []

const DRAG_THRESH: float = 12.0
var _remove_mode: bool = false
var _remove_button: Button
var _touches: Dictionary = {}
var _touch_start: Vector2 = Vector2.ZERO
var _moved: bool = false
var _pinch_dist: float = 0.0


func _ready() -> void:
	_setup_world()
	_build_root = Node3D.new()
	add_child(_build_root)
	_make_baseplate()

	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.4, 1.0, 0.5, 0.4)
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.emission_enabled = true
	gmat.emission = Color(0.4, 1.0, 0.5)
	gmat.emission_energy_multiplier = 0.25
	_ghost.material_override = gmat
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


func _make_baseplate() -> void:
	var base_rec := BrickPart.make("plate", 0, -1, 0, GX, GZ, "#5a6070")
	var base := StaticBody3D.new()
	base.add_to_group("labbase")
	base.position = BrickPart.center_world(base_rec)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(GX * BrickPart.STUD, BrickPart.PLATE, GZ * BrickPart.STUD)
	cs.shape = bs
	base.add_child(cs)
	base.add_child(BrickPart.build_part(base_rec))
	add_child(base)


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
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("aim_left"):
		_yaw -= rot
	if Input.is_action_pressed("move_right") or Input.is_action_pressed("aim_right"):
		_yaw += rot
	if Input.is_action_pressed("move_up") or Input.is_action_pressed("aim_up"):
		_pitch = clampf(_pitch + rot, 0.15, 1.4)
	if Input.is_action_pressed("move_down") or Input.is_action_pressed("aim_down"):
		_pitch = clampf(_pitch - rot, 0.15, 1.4)
	_update_camera()
	_update_targets()

	if Input.is_action_just_pressed("menu"):
		get_tree().change_scene_to_file("res://scenes/hub.tscn")


func _update_camera() -> void:
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_camera.global_position = _center + dir * _dist
	_camera.look_at(_center, Vector3.UP)


func _world_to_cell(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / BrickPart.STUD), floori(p.y / BrickPart.PLATE), floori(p.z / BrickPart.STUD))


func _candidate_rec(cell: Vector3i) -> Dictionary:
	return BrickPart.make(_ptype, cell.x, cell.y, cell.z, _psize.x, _psize.y, COLORS[_selected], -1, _prot)


func _in_bounds(rec: Dictionary) -> bool:
	for c in BrickPart.cells(rec):
		if c.x < 0 or c.x >= GX or c.y < 0 or c.y >= GY or c.z < 0 or c.z >= GZ:
			return false
	return true


func _overlaps(rec: Dictionary) -> bool:
	for c in BrickPart.cells(rec):
		if _occupied.has(c):
			return true
	return false


func _update_targets(screen_pos: Vector2 = Vector2(-1, -1)) -> void:
	_ghost_valid = false
	_has_hover = false
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var mouse := screen_pos if screen_pos.x >= 0.0 else get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse)
	var to := from + _camera.project_ray_normal(mouse) * 200.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		_ghost.visible = false
		return

	var n: Vector3 = hit.normal
	var cell := _world_to_cell((hit.position as Vector3) + n * 0.04)
	_ghost_cell = cell
	var rec := _candidate_rec(cell)
	_ghost_valid = _in_bounds(rec) and not _overlaps(rec)
	_show_ghost(rec, _ghost_valid)

	var col: Object = hit.collider
	if col and col is Node and (col as Node).is_in_group("labpart"):
		_has_hover = true
		_hover_id = int((col as Node).get_meta("id"))


func _show_ghost(rec: Dictionary, valid: bool) -> void:
	var fp := BrickPart.footprint(rec)
	var h := BrickPart.part_h(rec)
	var bm: BoxMesh = _ghost.mesh
	bm.size = Vector3(fp.x * BrickPart.STUD, h * BrickPart.PLATE, fp.y * BrickPart.STUD) * 0.98
	_ghost.position = BrickPart.center_world(rec)
	var mat: StandardMaterial3D = _ghost.material_override
	if valid:
		mat.albedo_color = Color(0.4, 1.0, 0.5, 0.4)
		mat.emission = Color(0.4, 1.0, 0.5)
	else:
		mat.albedo_color = Color(1.0, 0.35, 0.35, 0.35)
		mat.emission = Color(1.0, 0.35, 0.35)
	_ghost.visible = true


func _two_finger_dist() -> float:
	var pts := _touches.values()
	if pts.size() < 2:
		return 0.0
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_touch_start = t.position
				_moved = false
			elif _touches.size() == 2:
				_pinch_dist = _two_finger_dist()
		else:
			_touches.erase(t.index)
			if _touches.is_empty() and not _moved:
				_update_targets(t.position)
				if _remove_mode and _has_hover:
					_do_remove()
				elif _ghost_valid:
					_do_place()
		return
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var nd := _two_finger_dist()
			if _pinch_dist > 0.0:
				_dist = clampf(_dist * (_pinch_dist / maxf(nd, 1.0)), 4.0, 18.0)
				_update_camera()
			_pinch_dist = nd
			_moved = true
		else:
			if (d.position - _touch_start).length() > DRAG_THRESH:
				_moved = true
			_yaw -= d.relative.x * 0.01
			_pitch = clampf(_pitch + d.relative.y * 0.01, 0.15, 1.4)
			_update_camera()
		return
	elif event is InputEventMouseButton and not DisplayServer.is_touchscreen_available():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist = clampf(_dist - 0.6, 4.0, 18.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist = clampf(_dist + 0.6, 4.0, 18.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _ghost_valid:
			_do_place()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT and _has_hover:
			_do_remove()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_TAB:
				_cycle_type()
			elif ke.keycode == KEY_R:
				_rotate_part()
			else:
				var idx: int = ke.keycode - KEY_1
				if idx >= 0 and idx < COLORS.size():
					_select(idx)


func _part_cost(t: String) -> int:
	return int(COSTS.get(t, 5))


func _do_place() -> void:
	var cost := _part_cost(_ptype)
	if not GameState.spend(cost):
		if _feedback:
			_feedback.text = "Need $%d!" % cost
		return
	_place_part(_candidate_rec(_ghost_cell), true)
	_update_money()
	Sfx.play_hit()


func _do_remove() -> void:
	_remove_part(_hover_id)
	_update_money()
	Sfx.play_hit()


func _place_part(rec: Dictionary, paid: bool = false) -> void:
	var id := _next_id
	_next_id += 1
	var body := StaticBody3D.new()
	body.add_to_group("labpart")
	body.position = BrickPart.center_world(rec)
	body.set_meta("id", id)
	body.set_meta("paid", paid)
	body.set_meta("cost", _part_cost(str(rec.get("t", "brick"))))
	body.set_meta("rec", rec)

	var fp := BrickPart.footprint(rec)
	var h := BrickPart.part_h(rec)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(fp.x * BrickPart.STUD, h * BrickPart.PLATE, fp.y * BrickPart.STUD) * 0.98
	cs.shape = bs
	body.add_child(cs)
	body.add_child(BrickPart.build_part(rec))

	_build_root.add_child(body)
	_parts[id] = body
	for c in BrickPart.cells(rec):
		_occupied[c] = id


func _remove_part(id: int) -> void:
	if not _parts.has(id):
		return
	var body: Node = _parts[id]
	var rec: Dictionary = body.get_meta("rec")
	if body.get_meta("paid", false):
		GameState.add_money(int(body.get_meta("cost", 0)))
	for c in BrickPart.cells(rec):
		_occupied.erase(c)
	body.queue_free()
	_parts.erase(id)


func _clear_blocks() -> void:
	for id in _parts.keys():
		var b: Node = _parts[id]
		if b.get_meta("paid", false):
			GameState.add_money(int(b.get_meta("cost", 0)))
		b.queue_free()
	_parts.clear()
	_occupied.clear()


func _rebuild_from(design: Array) -> void:
	_clear_blocks()
	for rec in design:
		if rec is Dictionary:
			_place_part((rec as Dictionary).duplicate(true), false)
	_update_money()


func _collect() -> Array:
	var arr: Array = []
	for id in _parts:
		arr.append((_parts[id] as Node).get_meta("rec"))
	return arr


# --- selection ---

func _select(i: int) -> void:
	_selected = i
	if _preview:
		_preview.color = Color(COLORS[i])


func _set_type(t: String) -> void:
	_ptype = t
	_update_sel_label()


func _cycle_type() -> void:
	_set_type(TYPES[(TYPES.find(_ptype) + 1) % TYPES.size()])


func _set_size(s: Vector2i) -> void:
	_psize = s
	_update_sel_label()


func _rotate_part() -> void:
	_prot = (_prot + 90) % 360
	_update_sel_label()


func _toggle_remove() -> void:
	_remove_mode = not _remove_mode
	_remove_button.text = "Remove: On" if _remove_mode else "Remove: Off"


func _update_sel_label() -> void:
	if _sel_label:
		_sel_label.text = "%s  %dx%d  rot %d  ($%d)" % [_ptype.to_upper(), _psize.x, _psize.y, _prot, _part_cost(_ptype)]


func _update_money() -> void:
	if _money_label:
		_money_label.text = "Money:  $%d" % GameState.money


# --- UI ---

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _label(root, "LABORATORY", 44)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 12.0
	title.offset_bottom = 52.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(0.7, 0.85, 1.0)

	var info_text := "Click: place   .   Right-click: remove   .   Drag/WASD: orbit   .   R: rotate   .   Tab: part   .   1-9: color"
	if DisplayServer.is_touchscreen_available():
		info_text = "Tap: place   .   Drag: orbit   .   Pinch: zoom   .   pick part / size / color below"
	var info := _label(root, info_text, 20)
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.anchor_right = 1.0
	info.offset_top = -34.0
	info.offset_bottom = -10.0
	info.offset_left = 16.0
	info.modulate = Color(1, 1, 1, 0.8)

	# Color palette (bottom center).
	var pal := HBoxContainer.new()
	pal.add_theme_constant_override("separation", 6)
	pal.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pal.position = Vector2(-COLORS.size() * 27, -92)
	layer.add_child(pal)
	for i in COLORS.size():
		var sw := Button.new()
		sw.custom_minimum_size = Vector2(46, 46)
		sw.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(COLORS[i])
		sb.set_corner_radius_all(6)
		sw.add_theme_stylebox_override("normal", sb)
		sw.add_theme_stylebox_override("hover", sb)
		sw.add_theme_stylebox_override("pressed", sb)
		sw.pressed.connect(_select.bind(i))
		pal.add_child(sw)

	# Right column.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.offset_left = -260.0
	col.offset_top = 12.0
	layer.add_child(col)

	_money_label = Label.new()
	_money_label.text = "Money:  $%d" % GameState.money
	_money_label.add_theme_font_size_override("font_size", 24)
	_money_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	_money_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_money_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_money_label)

	_sel_label = Label.new()
	_sel_label.add_theme_font_size_override("font_size", 20)
	_sel_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_sel_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_sel_label.add_theme_constant_override("outline_size", 4)
	col.add_child(_sel_label)
	_update_sel_label()

	# Part-type buttons (two rows).
	var trow1 := HBoxContainer.new()
	trow1.add_theme_constant_override("separation", 5)
	var trow2 := HBoxContainer.new()
	trow2.add_theme_constant_override("separation", 5)
	for i in TYPES.size():
		var tb := Button.new()
		tb.text = TYPES[i].capitalize()
		tb.custom_minimum_size = Vector2(82, 44)
		tb.focus_mode = Control.FOCUS_NONE
		tb.add_theme_font_size_override("font_size", 17)
		tb.pressed.connect(_set_type.bind(TYPES[i]))
		(trow1 if i < 3 else trow2).add_child(tb)
	col.add_child(trow1)
	col.add_child(trow2)

	# Size buttons + rotate.
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 5)
	for s in SIZES:
		var sbn := Button.new()
		sbn.text = "%dx%d" % [s.x, s.y]
		sbn.custom_minimum_size = Vector2(56, 44)
		sbn.focus_mode = Control.FOCUS_NONE
		sbn.add_theme_font_size_override("font_size", 17)
		sbn.pressed.connect(_set_size.bind(s))
		srow.add_child(sbn)
	var rotb := Button.new()
	rotb.text = "Rotate"
	rotb.custom_minimum_size = Vector2(80, 44)
	rotb.focus_mode = Control.FOCUS_NONE
	rotb.add_theme_font_size_override("font_size", 17)
	rotb.pressed.connect(_rotate_part)
	srow.add_child(rotb)
	col.add_child(srow)

	_remove_button = Button.new()
	_remove_button.text = "Remove: Off"
	_remove_button.custom_minimum_size = Vector2(0, 44)
	_remove_button.focus_mode = Control.FOCUS_NONE
	_remove_button.add_theme_font_size_override("font_size", 19)
	_remove_button.pressed.connect(_toggle_remove)
	col.add_child(_remove_button)

	_preview = ColorRect.new()
	_preview.custom_minimum_size = Vector2(240, 26)
	_preview.color = Color(COLORS[_selected])
	col.add_child(_preview)

	_add_button(col, "Save", _on_save)
	_add_button(col, "Clear", _on_clear)
	_add_button(col, "Reset car", _on_reset)
	_add_button(col, "Drive it!", _on_drive)
	_add_button(col, "Back (M)", _on_back)
	_feedback = _label(col, "", 22)
	_feedback.modulate = Color(0.6, 1.0, 0.6)


func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 50)
	b.add_theme_font_size_override("font_size", 26)
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
	_clear_blocks()
	_update_money()


func _on_reset() -> void:
	_rebuild_from(_original)
	if _feedback:
		_feedback.text = "Reset to start"


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
