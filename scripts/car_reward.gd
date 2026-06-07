extends DriveScene
## Congratulations / car reveal screen shown after completing a world. The new
## car sits on a turntable you can orbit (Arrows/WASD) to admire from any angle.

var _cam: Camera3D
var _car_node: Node3D
var _yaw: float = 0.7
var _pitch: float = 0.5
var _dist: float = 9.0
var _done: bool = false


func _ready() -> void:
	add_light_and_env(Color(0.16, 0.2, 0.34), Color(0.62, 0.72, 0.92))
	add_fade()

	var ped := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.4
	cyl.height = 1.2
	ped.mesh = cyl
	ped.position = Vector3(0, 0.6, 0)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.2, 0.22, 0.3)
	ped.material_override = pm
	add_child(ped)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.0
	torus.outer_radius = 3.4
	ring.mesh = torus
	ring.position = Vector3(0, 1.25, 0)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(1.0, 0.85, 0.3)
	rm.emission_enabled = true
	rm.emission = Color(1.0, 0.85, 0.3)
	rm.emission_energy_multiplier = 2.0
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rm
	add_child(ring)

	_car_node = CarLib.build_display(GameState.last_reward_design)
	_car_node.position = Vector3(0, 1.2, 0)
	add_child(_car_node)

	for c in ["#d2473b", "#3b86d2", "#e6b32e"]:
		_confetti(Color(c))

	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	_update_cam()

	_build_ui()


func _process(delta: float) -> void:
	if _done:
		return
	var rot := 1.6 * delta
	if Input.is_action_pressed("move_left"):
		_yaw -= rot
	if Input.is_action_pressed("move_right"):
		_yaw += rot
	if Input.is_action_pressed("move_up"):
		_pitch = clampf(_pitch + rot, 0.12, 1.3)
	if Input.is_action_pressed("move_down"):
		_pitch = clampf(_pitch - rot, 0.12, 1.3)
	if is_instance_valid(_car_node):
		_car_node.rotation.y += 0.5 * delta
	_update_cam()

	if Input.is_action_just_pressed("advance") or Input.is_action_just_pressed("menu"):
		_done = true
		transition_to("res://scenes/world_map.tscn")


func _update_cam() -> void:
	var center := Vector3(0, 2.0, 0)
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_cam.global_position = center + dir * _dist
	_cam.look_at(center, Vector3.UP)


func _confetti(color: Color) -> void:
	var p := CPUParticles3D.new()
	p.position = Vector3(0, 12, 0)
	p.amount = 26
	p.lifetime = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(8, 0.5, 8)
	p.direction = Vector3(0, -1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -3.0, 0)
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.45
	p.color = color
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.3, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.2
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = m
	p.mesh = bm
	add_child(p)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := _label(root, "CONGRATULATIONS!", 52)
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 26.0
	title.offset_bottom = 90.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate = Color(1.0, 0.85, 0.3)

	var sub := _label(root, "You won the %s!" % GameState.last_reward_name, 30)
	sub.anchor_left = 0.0
	sub.anchor_right = 1.0
	sub.offset_top = 92.0
	sub.offset_bottom = 132.0
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hint := _label(root, "Arrows / WASD to look around   .   Enter to continue", 20)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top = -46.0
	hint.offset_bottom = -16.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.85)


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	parent.add_child(l)
	return l
