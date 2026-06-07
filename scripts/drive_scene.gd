class_name DriveScene
extends Node3D
## Shared setup for any scene where you drive the car around: lighting +
## themed environment, the vehicle, the chase camera, and a simple overlay
## (title + hint + mute button). Used by the hub, world map and gameplay.

const VehicleScene := preload("res://scenes/vehicle.tscn")

var vehicle: Vehicle
var camera: ChaseCamera
var character: Character
var on_foot: bool = false
var _prompt_label: Label
var _fade: ColorRect
var _transitioning: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if on_foot:
			_enter_car()
		else:
			_exit_car()


func _exit_car() -> void:
	if not is_instance_valid(vehicle) or on_foot:
		return
	on_foot = true
	vehicle.set_controlled(false)
	vehicle.set_driver_visible(false)
	character = Character.new()
	add_child(character)
	character.global_position = vehicle.global_position + vehicle.global_transform.basis.z * 2.4 + Vector3(0, 0.6, 0)
	if camera:
		camera.target = character
	set_prompt("Walk up to the car and press E to get in   .   Space to jump")
	Sfx.play_checkpoint()


func _enter_car() -> void:
	if not is_instance_valid(vehicle) or not is_instance_valid(character):
		return
	if character.global_position.distance_to(vehicle.global_position) > 6.0:
		set_prompt("Too far from the car - get closer, then press E")
		return
	on_foot = false
	vehicle.set_controlled(true)
	vehicle.set_driver_visible(true)
	if camera:
		camera.target = vehicle
	character.queue_free()
	character = null
	set_prompt("")
	Sfx.play_checkpoint()


func add_light_and_env(sky_top: Color = Color(0.28, 0.5, 0.86), sky_horizon: Color = Color(0.78, 0.85, 0.92)) -> void:
	# Warm sun angled into the sky so the sky's sun disk is visible.
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38, -55, 0)
	light.light_color = Color(1.0, 0.96, 0.86)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	sky_mat.ground_horizon_color = sky_horizon.darkened(0.1)
	sky_mat.ground_bottom_color = sky_top.darkened(0.4)
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.07
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.ssao_enabled = true
	# Subtle distance haze so far mountains read with depth (sky stays vivid).
	env.fog_enabled = true
	env.fog_light_color = sky_horizon
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.45

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func add_scenery(half: float, mountain: Color = Color(0.34, 0.46, 0.32), leaf: Color = Color(0.3, 0.6, 0.26), tree_count: int = 20, snow: bool = true, dunes: bool = false) -> void:
	# Purely decorative backdrop (no collision): mountains/dunes, trees, clouds.
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var segs := 9 if dunes else 5

	for i in 8:
		var ang := TAU * float(i) / 8.0 + rng.randf() * 0.35
		var r := half * rng.randf_range(1.6, 2.3)
		var h := rng.randf_range(22.0, 36.0) if dunes else rng.randf_range(30.0, 60.0)
		var rad := rng.randf_range(34.0, 52.0) if dunes else rng.randf_range(20.0, 34.0)
		var pos := Vector3(cos(ang) * r, h * 0.5 - 5.0, sin(ang) * r)
		_cone(pos, rad, h, segs, mountain.lightened(rng.randf_range(-0.05, 0.08)))
		if snow:
			_cone(pos + Vector3(0, h * 0.42, 0), rad * 0.34, h * 0.22, segs, Color(0.95, 0.96, 1.0))

	for i in tree_count:
		var ta := rng.randf() * TAU
		var tr := half * rng.randf_range(1.05, 1.45)
		_tree(Vector3(cos(ta) * tr, 0, sin(ta) * tr), leaf, rng)

	for i in 12:
		_cloud(Vector3(rng.randf_range(-half, half), rng.randf_range(40.0, 62.0), rng.randf_range(-half, half)), rng)


func add_park_decor(half: float, accent: Color) -> void:
	# Lego park dressing (no collision): lamp posts, flowers, arches, signs, statue.
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	for i in 10:
		var ang := TAU * float(i) / 10.0
		var l := Decor.lamp_post()
		l.position = Vector3(cos(ang) * half * 0.86, 0, sin(ang) * half * 0.86)
		add_child(l)
	for i in 18:
		var fl := Decor.flower(Color.from_hsv(rng.randf(), 0.7, 1.0))
		fl.position = Vector3(rng.randf_range(-half * 0.8, half * 0.8), 0, rng.randf_range(8.0, half * 0.8))
		add_child(fl)
	var a := Decor.arch(accent)
	a.position = Vector3(0, 0, half * 0.62)
	add_child(a)
	var s := Decor.sign_post(accent)
	s.position = Vector3(-half * 0.55, 0, half * 0.35)
	add_child(s)
	var st := Decor.statue(["#d2473b", "#3b86d2", "#e6b32e", "#5aa54a"])
	st.position = Vector3(half * 0.55, 0, half * 0.35)
	add_child(st)


func _cone(pos: Vector3, radius: float, height: float, segs: int, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segs
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _flat(color)
	add_child(mi)


func _tree(pos: Vector3, leaf: Color, rng: RandomNumberGenerator) -> void:
	var trunk := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.9, 3.0, 0.9)
	trunk.mesh = tb
	trunk.position = pos + Vector3(0, 1.5, 0)
	trunk.material_override = _flat(Color(0.45, 0.3, 0.18))
	add_child(trunk)
	var n := rng.randi_range(2, 3)
	for k in n:
		var leaf_mi := MeshInstance3D.new()
		var lb := BoxMesh.new()
		var w := 3.2 - k * 0.7
		lb.size = Vector3(w, 1.6, w)
		leaf_mi.mesh = lb
		leaf_mi.position = pos + Vector3(0, 3.2 + k * 1.3, 0)
		leaf_mi.material_override = _flat(leaf.lightened(k * 0.06))
		add_child(leaf_mi)


func _cloud(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(3, 5)
	for k in n:
		var puff := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(3.0, 6.0)
		bm.size = Vector3(s, s * 0.6, s)
		puff.mesh = bm
		puff.position = pos + Vector3(rng.randf_range(-5, 5), rng.randf_range(-1, 1), rng.randf_range(-4, 4))
		puff.material_override = _flat(Color(1, 1, 1))
		add_child(puff)


func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m


func spawn_car(at: Vector3) -> void:
	vehicle = VehicleScene.instantiate()
	add_child(vehicle)
	vehicle.global_position = at


func add_camera() -> void:
	camera = ChaseCamera.new()
	camera.target = vehicle
	add_child(camera)


func add_overlay(title: String, hint: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title_label := _overlay_label(title, 34)
	title_label.anchor_left = 0.0
	title_label.anchor_right = 1.0
	title_label.offset_top = 18.0
	title_label.offset_bottom = 64.0
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_label)

	var hint_label := _overlay_label(hint, 18)
	hint_label.anchor_left = 0.0
	hint_label.anchor_right = 1.0
	hint_label.anchor_top = 1.0
	hint_label.anchor_bottom = 1.0
	hint_label.offset_top = -46.0
	hint_label.offset_bottom = -16.0
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate = Color(1, 1, 1, 0.8)
	root.add_child(hint_label)

	_prompt_label = _overlay_label("", 30)
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 0.62
	_prompt_label.anchor_bottom = 0.62
	_prompt_label.offset_bottom = 44.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.modulate = Color(1.0, 0.95, 0.5)
	_prompt_label.visible = false
	root.add_child(_prompt_label)

	var mute := Button.new()
	mute.anchor_left = 1.0
	mute.anchor_right = 1.0
	mute.offset_left = -150.0
	mute.offset_top = 16.0
	mute.offset_right = -16.0
	mute.offset_bottom = 54.0
	mute.focus_mode = Control.FOCUS_NONE
	mute.add_theme_font_size_override("font_size", 18)
	mute.text = "Sound: Off" if Sfx.is_muted() else "Sound: On"
	mute.pressed.connect(func() -> void:
		Sfx.toggle_mute()
		mute.text = "Sound: Off" if Sfx.is_muted() else "Sound: On")
	root.add_child(mute)


func set_prompt(text: String) -> void:
	if _prompt_label == null:
		return
	_prompt_label.text = text
	_prompt_label.visible = text != ""


func _overlay_label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


func add_fade() -> void:
	# Full-screen white overlay that fades out on arrival ("entering the world").
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(1, 1, 1, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.55)


func transition_to(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	set_prompt("")
	if camera:
		var ct := create_tween()
		ct.tween_property(camera, "fov", 32.0, 0.45)
	if _fade:
		var tw := create_tween()
		tw.tween_property(_fade, "color:a", 1.0, 0.45)
		tw.finished.connect(func() -> void: get_tree().change_scene_to_file(path))
	else:
		get_tree().change_scene_to_file(path)


func charge_gate(gate: Node3D, ratio: float) -> void:
	var mi := _gate_mesh(gate)
	if mi == null:
		return
	var s := 1.0 + 0.3 * ratio
	mi.scale = Vector3(s, s, s)
	var mat: StandardMaterial3D = mi.material_override
	if mat:
		mat.emission_energy_multiplier = lerpf(1.6, 7.0, ratio)


func reset_gate(gate: Node3D) -> void:
	var mi := _gate_mesh(gate)
	if mi == null:
		return
	mi.scale = Vector3.ONE
	var mat: StandardMaterial3D = mi.material_override
	if mat:
		mat.emission_energy_multiplier = 1.6


func _gate_mesh(gate: Node3D) -> MeshInstance3D:
	if gate == null:
		return null
	for c in gate.get_children():
		if c is MeshInstance3D:
			return c
	return null


func add_ground(size: Vector3, color: Color, studs: bool = true) -> void:
	var g := BrickFactory.make_brick(size, color, "static", studs)
	g.position = Vector3(0, -size.y * 0.5, 0)
	add_child(g)


func add_pad(pos: Vector3, size: Vector3, color: Color) -> void:
	var pad := BrickFactory.make_brick(size, color, "static", true)
	pad.position = pos
	add_child(pad)


func add_border(half_x: float, half_z: float, color: Color) -> void:
	var h := 3.0
	var t := 2.5
	var blocks := [
		[Vector3(half_x * 2.0 + t * 2.0, h, t), Vector3(0, h * 0.5, -half_z)],
		[Vector3(half_x * 2.0 + t * 2.0, h, t), Vector3(0, h * 0.5, half_z)],
		[Vector3(t, h, half_z * 2.0 + t * 2.0), Vector3(-half_x, h * 0.5, 0)],
		[Vector3(t, h, half_z * 2.0 + t * 2.0), Vector3(half_x, h * 0.5, 0)],
	]
	for b in blocks:
		var w := BrickFactory.make_brick(b[0], color, "static", true)
		w.position = b[1]
		add_child(w)


func add_skyline(half_x: float, half_z: float, colors: Array, count: int, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in count:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.72, 0.92)
		var px := cos(ang) * half_x * rad
		var pz := sin(ang) * half_z * rad
		var hgt := rng.randf_range(5.0, 14.0)
		var wd := rng.randf_range(3.0, 6.0)
		var c: Color = colors[rng.randi() % colors.size()]
		var b := BrickFactory.make_brick(Vector3(wd, hgt, wd), c, "static", true)
		b.position = Vector3(px, hgt * 0.5, pz)
		add_child(b)


func make_gate(pos: Vector3, size: Vector3, color: Color, label_text: String, sub_text: String, group: String) -> Area3D:
	var area := Area3D.new()
	area.position = pos
	area.add_to_group(group)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.32)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	mi.material_override = mat
	area.add_child(mi)

	var label := Label3D.new()
	label.text = label_text
	label.font_size = 200
	label.pixel_size = 0.012
	label.position = Vector3(0, size.y * 0.5 + 1.6, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 24
	area.add_child(label)

	if sub_text != "":
		var sub := Label3D.new()
		sub.text = sub_text
		sub.font_size = 90
		sub.pixel_size = 0.012
		sub.position = Vector3(0, size.y * 0.5 + 0.7, 0)
		sub.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sub.modulate = Color(1, 1, 1, 0.85)
		area.add_child(sub)

	add_child(area)
	return area
