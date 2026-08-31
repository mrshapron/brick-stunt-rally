extends DriveScene
## Aero World hub: you fly an aircraft between floating islands and pass through
## a glowing ring-gate to start that flight level. A golden RETURN gate flies you
## back to the main hub. Locked gates can't be entered until you clear the prior.

const RETURN := -1

var _craft: Aircraft
var _fly_cam: FlyCamera
var _pause_menu: PauseMenu
var _gates: Array = []  # [{pos, idx, unlocked, mat}]
var _gate_radius: float = 5.0
var _t: float = 0.0
var _enter_cd: float = 1.2


func _ready() -> void:
	add_light_and_env(Color("#3a6fc0"), Color("#cfe2f5"))
	add_fade()
	_add_islands()

	_craft = Aircraft.new()
	add_child(_craft)
	_craft.configure("plane", Color("#2f7fd0"), Color("#f0f0f0"))
	_craft.reset_to(Vector3(0, 24, 40), 0.0)

	_fly_cam = FlyCamera.new()
	_fly_cam.target = _craft
	add_child(_fly_cam)

	# Level ring-gates laid out in a gentle arc in front of the start.
	var n := GameState.sky_level_count()
	for i in n:
		var ang := lerpf(-0.9, 0.9, float(i) / float(maxi(n - 1, 1)))
		var radius := 70.0
		var px := sin(ang) * radius
		var pz := -28.0 - cos(ang) * radius
		var py := 22.0 + float(i) * 2.0
		var data := GameState.get_sky_level(i)
		var unlocked := GameState.sky_is_unlocked(i)
		var complete := GameState.sky_is_complete(i)
		var color := Color("#3a8a3a")
		if complete:
			color = Color("#33d65a")
		elif unlocked:
			color = Color("#ffd24a") if str(data.get("kind")) == "plane" else Color("#ff8a3a")
		var kind_tag := "PLANE" if str(data.get("kind")) == "plane" else "HELI"
		var sub := "LOCKED"
		if complete:
			sub = "%.1fs" % GameState.sky_best(i)
		elif unlocked:
			sub = kind_tag
		_add_gate(Vector3(px, py, pz), i, unlocked, color, "%d  %s" % [i + 1, str(data.get("name", "Flight"))], sub)

	# Return-to-hub gate, behind and above the spawn.
	_add_gate(Vector3(0, 30, 70), RETURN, true, Color("#ffd24a"), "RETURN", "to hub")

	_pause_menu = PauseMenu.new()
	_pause_menu.allow_restart = false
	_pause_menu.allow_map = false
	add_child(_pause_menu)

	add_overlay("AERO WORLD", "Fly through a ring to start a level   .   gold ring = back to hub   .   hold Space to boost")
	add_touch_controls("fly")


func _add_islands() -> void:
	# A central airport island + scattered floating islands and clouds, plus a
	# couple of parked aircraft for flavour.
	_floating_island(Vector3(0, 8, 40), 30.0, 6.0, Color("#6fae4f"))
	var tower := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(4, 14, 4)
	tower.mesh = tb
	tower.position = Vector3(10, 18, 46)
	tower.material_override = _flat(Color("#c0c4cc"))
	add_child(tower)
	var cabin := MeshInstance3D.new()
	var cbb := BoxMesh.new()
	cbb.size = Vector3(6, 3, 6)
	cabin.mesh = cbb
	cabin.position = Vector3(10, 26, 46)
	cabin.material_override = _flat(Color("#3a5a86"))
	add_child(cabin)

	# Parked decor aircraft (idle, rotors spinning).
	var heli := Aircraft.new()
	add_child(heli)
	heli.configure("heli", Color("#e0a740"), Color("#222222"))
	heli.controlled = false
	heli.reset_to(Vector3(-8, 14.6, 44), PI)
	var plane := Aircraft.new()
	add_child(plane)
	plane.configure("plane", Color("#c43a2a"), Color("#eaeaea"))
	plane.controlled = false
	plane.reset_to(Vector3(2, 14.6, 36), PI)

	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	for i in 12:
		var p := Vector3(rng.randf_range(-150, 150), rng.randf_range(2, 40), rng.randf_range(-160, 90))
		if p.distance_to(Vector3(0, 8, 40)) < 50.0:
			continue
		_floating_island(p, rng.randf_range(6.0, 16.0), rng.randf_range(3.0, 6.0), Color("#6fae4f").lightened(rng.randf_range(-0.1, 0.1)))
	for i in 24:
		_cloud(Vector3(rng.randf_range(-200, 200), rng.randf_range(6, 55), rng.randf_range(-200, 110)), rng)


func _floating_island(pos: Vector3, size: float, thick: float, color: Color) -> void:
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, thick, size)
	body.mesh = bm
	body.position = pos
	body.material_override = _flat(color.darkened(0.15))
	add_child(body)
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(size + 0.8, 1.2, size + 0.8)
	cap.mesh = cm
	cap.position = pos + Vector3(0, thick * 0.5, 0)
	cap.material_override = _flat(color)
	add_child(cap)


func _add_gate(pos: Vector3, idx: int, unlocked: bool, color: Color, title: String, sub: String) -> void:
	var node := Node3D.new()
	node.position = pos
	add_child(node)

	var torus := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = _gate_radius
	tm.outer_radius = _gate_radius + 1.1
	tm.rings = 8
	tm.ring_segments = 24
	torus.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.2
	m.roughness = 0.3
	torus.material_override = m
	node.add_child(torus)

	var label := Label3D.new()
	label.text = title
	label.font_size = 90
	label.pixel_size = 0.02
	label.position = Vector3(0, _gate_radius + 2.4, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 18
	label.modulate = color.lightened(0.3)
	node.add_child(label)
	var subl := Label3D.new()
	subl.text = sub
	subl.font_size = 56
	subl.pixel_size = 0.02
	subl.position = Vector3(0, _gate_radius + 1.0, 0)
	subl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	subl.outline_size = 14
	node.add_child(subl)

	_gates.append({"pos": pos, "idx": idx, "unlocked": unlocked, "mat": m})


func _process(delta: float) -> void:
	if _transitioning:
		return
	_t += delta
	if _enter_cd > 0.0:
		_enter_cd -= delta

	if Input.is_action_just_pressed("menu"):
		transition_to("res://scenes/hub.tscn")
		return

	if not is_instance_valid(_craft):
		return
	# Keep the craft from diving into the islands or flying off forever.
	if _craft.global_position.y < 6.0:
		_craft.reset_to(Vector3(0, 24, 40), 0.0)

	var cp := _craft.global_position
	var nearest_locked := -1
	var nearest_d := 1e9
	for g in _gates:
		var gp: Vector3 = g["pos"]
		var d := cp.distance_to(gp)
		var e := 2.2
		if d < 60.0:
			e = 3.0 + sin(_t * 5.0) * 1.2
		g["mat"].emission_energy_multiplier = e
		if d < _gate_radius + 1.5 and _enter_cd <= 0.0:
			if g["unlocked"]:
				_enter(int(g["idx"]))
				return
			elif d < nearest_d:
				nearest_d = d
				nearest_locked = int(g["idx"])
	if nearest_locked >= 0:
		set_prompt("Level %d is locked - clear the level before it first" % (nearest_locked + 1))
	else:
		set_prompt("")


func _enter(idx: int) -> void:
	Sfx.play_checkpoint()
	if idx == RETURN:
		transition_to("res://scenes/hub.tscn")
		return
	GameState.sky_current = idx
	Effects.explosion(self, _craft.global_position, 1.0, Color(0.6, 0.85, 1.0))
	transition_to("res://scenes/sky_level.tscn")
