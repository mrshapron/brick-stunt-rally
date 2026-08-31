extends DriveScene
## World hub: drive up to a world portal and press Enter to enter it. You can
## drive freely past portals to reach the world you want.

const ENTER_TIME := 2.0
const LAB := -10
const PARK := -11
const AERO := -12
# Some worlds sit up on hills (height per world index; 0 = on the ground).
const HILLS := [0.0, 0.0, 5.0, 0.0, 9.0, 0.0, 4.0]
# A fun LEGO travel poster per world, shown on a billboard at its portal.
const POSTERS := [
	"res://textures/worlds/world_grassland.png",
	"res://textures/worlds/world_desert.png",
	"res://textures/worlds/world_neon.png",
	"res://textures/worlds/world_war.png",
	"res://textures/worlds/world_mountains.png",
	"res://textures/worlds/world_speedway.png",
	"res://textures/worlds/world_safari.png",
]

var _near := -1
var _near_gate: Node3D
var _dwell := 0.0
var _portals: Array[Area3D] = []
var _t := 0.0
var _pause_menu: PauseMenu


func _ready() -> void:
	add_light_and_env()
	add_fade()

	var half := 112.0
	add_ground(Vector3(half * 2.0, 3, half * 2.0), Color("#6b7080"), true)
	add_border(half - 2.0, half - 2.0, Color("#4f5460"))
	add_city(half, ["#c64b3a", "#3b86d2", "#e6b32e", "#5aa54a", "#b06bff", "#e08a2a", "#cfd2da"])
	add_scenery(half, Color("#4f7a3f"), Color(0.32, 0.62, 0.28), 22, true, false)
	add_park_decor(half, Color("#e6b32e"))
	for fpos in [Vector3(48, 0, -8), Vector3(-48, 0, -8)]:
		var f := Decor.fountain()
		f.position = fpos
		add_child(f)

	add_bridge(0, -12, 38, 4.5, Color("#b0683a"))

	# Two landmark brick builds flanking the entrance avenue, angled inward so
	# you see them face-on while driving toward the world portals.
	var nyc := Decor.nyc_skyline()
	nyc.position = Vector3(-40, 0, 18)
	nyc.rotation.y = PI * 0.32
	add_child(nyc)

	var bear := Decor.pink_bear()
	bear.position = Vector3(40, 0, 18)
	bear.rotation.y = -PI * 0.32
	bear.scale = Vector3(1.6, 1.6, 1.6)
	add_child(bear)

	# World portals in a back row, each on a decorated pad.
	var n := GameState.get_world_count()
	for i in n:
		var w := GameState.get_world(i)
		var done := GameState.levels_completed(i)
		var color := Color(w.get("accent", "#e6b32e"))
		var sub := "%d/%d done" % [done, GameState.LEVELS_PER_WORLD]
		var px := -float(n - 1) * 30.0 * 0.5 + i * 30.0
		var hh: float = HILLS[i] if i < HILLS.size() else 0.0
		var top := 0.0
		if hh > 0.0:
			top = add_hill(px, -62.0, hh, color.darkened(0.12))
		var pos := Vector3(px, top + 3.5, -62)
		add_pad(Vector3(pos.x, top + 0.15, pos.z), Vector3(13, 0.3, 13), color.darkened(0.15))
		var gate := _make_portal_door(pos, color, str(w.get("name", "World")), sub)
		gate.body_entered.connect(_on_near.bind(gate, i))
		gate.body_exited.connect(_on_far.bind(gate, i))
		if i < POSTERS.size():
			_add_world_poster(px, top + 12.0, -66.0, POSTERS[i], color)

	# Laboratory + Parking portals in a front row.
	var lab_color := Color("#7bd0ff")
	var lab_pos := Vector3(-20, 3.5, -28)
	add_pad(Vector3(lab_pos.x, 0.15, lab_pos.z), Vector3(13, 0.3, 13), lab_color.darkened(0.2))
	var lab_gate := _make_portal_door(lab_pos, lab_color, "Laboratory", "build a car")
	lab_gate.body_entered.connect(_on_near.bind(lab_gate, LAB))
	lab_gate.body_exited.connect(_on_far.bind(lab_gate, LAB))

	var park_color := Color("#c0c4cc")
	var park_pos := Vector3(20, 3.5, -28)
	add_pad(Vector3(park_pos.x, 0.15, park_pos.z), Vector3(13, 0.3, 13), park_color.darkened(0.25))
	var park_gate := _make_portal_door(park_pos, park_color, "Parking", "%d cars" % GameState.get_cars().size())
	park_gate.body_entered.connect(_on_near.bind(park_gate, PARK))
	park_gate.body_exited.connect(_on_far.bind(park_gate, PARK))

	# Ambient engines for life.
	for spot in [Vector3(-40, 0, -10), Vector3(40, 0, -10), Vector3(0, 0, 40)]:
		var e := PropEngine.new()
		e.position = spot
		e.configure({"color": "#8a8f9e", "scale": 1.4, "spin": 3.5})
		add_child(e)

	_build_sky_gateway()

	spawn_car(Vector3(0, 3, 8))
	add_camera()
	add_overlay("WORLD HUB", "Drive into a world portal and hold for 2s to enter (or press Enter)   .   Esc = menu")
	add_touch_controls("navp")

	# Pause menu (Esc / on-screen II): no level to restart or world map here.
	_pause_menu = PauseMenu.new()
	_pause_menu.allow_restart = false
	_pause_menu.allow_map = false
	add_child(_pause_menu)


func _add_world_poster(px: float, py: float, pz: float, tex_path: String, accent: Color) -> void:
	# A framed LEGO travel poster on posts, facing the player as they approach.
	var holder := Node3D.new()
	holder.position = Vector3(px, py, pz)
	add_child(holder)

	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(8.0, 5.4, 0.4)
	frame.mesh = fb
	var fm := StandardMaterial3D.new()
	fm.albedo_color = accent.darkened(0.2)
	fm.metallic = 0.2
	frame.material_override = fm
	holder.add_child(frame)

	var tex: Texture2D = load(tex_path)
	if tex != null:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(7.4, 4.8)
		q.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1)
		q.material_override = m
		q.position = Vector3(0, 0, 0.22)
		holder.add_child(q)

	# Two posts down to the ground.
	var length := maxf(py - 2.7, 1.0)
	for sx in [-3.4, 3.4]:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.4, length, 0.4)
		post.mesh = pb
		post.position = Vector3(sx, -(2.7 + length * 0.5), 0)
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.22, 0.24, 0.3)
		post.material_override = pm
		holder.add_child(post)


func _make_portal_door(pos: Vector3, color: Color, world_name: String, sub: String) -> Area3D:
	# A glowing "magic door": a brick archway with a spinning portal swirl and
	# floating sparkles. No ugly transparent box. The Area3D itself is the
	# entry trigger (you drive through the doorway to enter the world).
	var area := Area3D.new()
	area.position = pos
	area.add_to_group("portal")

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 7.0, 3.6)
	col.shape = shape
	area.add_child(col)

	# Archway frame: two pillars + a top beam, in a darker tone of the world.
	var frame_col := color.darkened(0.4)
	for sx in [-2.7, 2.7]:
		area.add_child(_door_box(Vector3(1.0, 7.0, 1.0), Vector3(sx, 0.0, 0.0), frame_col))
	area.add_child(_door_box(Vector3(6.4, 1.1, 1.0), Vector3(0.0, 3.45, 0.0), color.lightened(0.1)))
	# A keystone glow gem on top of the arch.
	var gem := _door_box(Vector3(1.2, 1.2, 1.2), Vector3(0.0, 4.3, 0.0), color.lightened(0.35))
	gem.material_override = _glow_mat(color.lightened(0.4), 2.0)
	gem.rotation_degrees = Vector3(0, 45, 45)
	area.add_child(gem)

	# Glowing portal ring (vertical torus) framing the swirl.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.0
	tm.outer_radius = 2.45
	tm.rings = 6
	tm.ring_segments = 18
	ring.mesh = tm
	ring.position = Vector3(0.0, 0.2, 0.0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.material_override = _glow_mat(color.lightened(0.2), 2.0)
	area.add_child(ring)

	# Spinning swirl surface (hex disc), emissive + slightly see-through.
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 2.0
	dm.bottom_radius = 2.0
	dm.height = 0.14
	dm.radial_segments = 6
	disc.mesh = dm
	disc.position = Vector3(0.0, 0.2, -0.05)
	disc.rotation_degrees = Vector3(90, 0, 0)
	var dmat := _glow_mat(color.lightened(0.4), 2.2)
	dmat.albedo_color = Color(color.lightened(0.35).r, color.lightened(0.35).g, color.lightened(0.35).b, 0.72)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = dmat
	area.add_child(disc)

	# Floating sparkles drifting up out of the portal.
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 1.6
	p.position = Vector3(0.0, 0.2, 0.1)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 50.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.32
	var pm := QuadMesh.new()
	pm.size = Vector2(0.3, 0.3)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = color.lightened(0.5)
	pmat.emission_enabled = true
	pmat.emission = color.lightened(0.5)
	pmat.emission_energy_multiplier = 2.5
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.material = pmat
	p.mesh = pm
	area.add_child(p)

	# Compact name banner above the door (clears the poster above it).
	var label := Label3D.new()
	label.text = world_name
	label.font_size = 110
	label.pixel_size = 0.013
	label.position = Vector3(0.0, 4.9, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 22
	label.no_depth_test = true
	area.add_child(label)
	if sub != "":
		var subl := Label3D.new()
		subl.text = sub
		subl.font_size = 64
		subl.pixel_size = 0.013
		subl.position = Vector3(0.0, -2.4, 1.4)
		subl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		subl.modulate = Color(1, 1, 1, 0.92)
		subl.no_depth_test = true
		area.add_child(subl)

	area.set_meta("disc", disc)
	area.set_meta("ring", ring)
	area.set_meta("color", color)
	add_child(area)
	_portals.append(area)
	return area


func _door_box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	mi.material_override = m
	return mi


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


func _animate_portals(delta: float) -> void:
	for area in _portals:
		if not is_instance_valid(area):
			continue
		var charging: bool = area == _near_gate
		var disc: MeshInstance3D = area.get_meta("disc")
		var ring: MeshInstance3D = area.get_meta("ring")
		if is_instance_valid(disc):
			disc.rotate_object_local(Vector3.UP, (4.2 if charging else 1.4) * delta)
			var dmat: StandardMaterial3D = disc.material_override
			if dmat:
				dmat.emission_energy_multiplier = (3.4 if charging else 1.8) + sin(_t * 4.0) * 0.5
		if is_instance_valid(ring):
			var rmat: StandardMaterial3D = ring.material_override
			if rmat:
				rmat.emission_energy_multiplier = (4.2 if charging else 2.0) + sin(_t * 3.0) * 0.4


func _build_sky_gateway() -> void:
	# Cross a bridge to the base of a very tall tower, then drive up a spiral ramp
	# that wraps around the tower to a helipad "parking" on top, where the Aero
	# World portal waits.
	var col := Color("#9bd0ff")
	var deck_y := 4.5
	var deck_w := 12.0
	var ramp_run := 20.0
	var cx := 200.0
	var cz := -15.0          # bridge runs out along +X at this Z (= tower -Z side)
	var deck_start := 60.0
	var spiral_r := 15.0
	var tower_cx := cx
	var tower_cz := 0.0      # tower centre; spiral start sits at (cx, deck_y, -spiral_r)

	# Ramp up from the hub ground to deck height (offset in Z to line up with the
	# spiral's entry, whose starting direction points +X).
	var ramp := BrickFactory.make_wedge(Vector3(ramp_run, deck_y, deck_w), col.darkened(0.1))
	ramp.position = Vector3(deck_start - ramp_run * 0.5, deck_y * 0.5 - 0.05, cz)
	add_child(ramp)

	# Main deck out to the tower base (crosses over the border wall).
	var deck_len := tower_cx - deck_start
	var deck := BrickFactory.make_brick(Vector3(deck_len, 1.0, deck_w), col, "static", true)
	deck.position = Vector3(deck_start + deck_len * 0.5, deck_y - 0.5, cz)
	add_child(deck)
	for sz in [deck_w * 0.5 - 0.4, -(deck_w * 0.5 - 0.4)]:
		var rail := BrickFactory.make_brick(Vector3(deck_len, 1.2, 0.5), col.lightened(0.12), "static", true)
		rail.position = Vector3(deck_start + deck_len * 0.5, deck_y + 0.6, cz + sz)
		add_child(rail)

	# Clouds drifting in the gap below the deck.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1313
	for i in 12:
		_cloud(Vector3(rng.randf_range(deck_start, tower_cx + 20.0), rng.randf_range(-4.0, 2.0), rng.randf_range(cz - 16, cz + 30)), rng)

	# The tall tower core + a wide footing.
	var turns := 3
	var rise := 38.0
	var pad_y := deck_y + rise
	var tower := MeshInstance3D.new()
	var tcyl := CylinderMesh.new()
	tcyl.top_radius = 6.0
	tcyl.bottom_radius = 8.0
	tcyl.height = pad_y + 2.0
	tcyl.radial_segments = 10
	tower.mesh = tcyl
	tower.position = Vector3(tower_cx, (pad_y + 2.0) * 0.5, tower_cz)
	tower.material_override = _flat(Color("#7c8794"))
	add_child(tower)
	# Diagonal support struts (offshore-rig look).
	for k in 6:
		var sa := TAU * float(k) / 6.0
		var strut := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.8, pad_y * 1.1, 0.8)
		strut.mesh = sb
		strut.position = Vector3(tower_cx + cos(sa) * 8.5, pad_y * 0.45, tower_cz + sin(sa) * 8.5)
		strut.rotation = Vector3(deg_to_rad(8) * sin(sa), 0, deg_to_rad(8) * -cos(sa))
		strut.material_override = _flat(Color("#5f6a76"))
		add_child(strut)

	# Spiral ramp wrapping the tower from the deck up to the helipad.
	var seg_per := 18
	var total_seg := turns * seg_per
	var theta0 := 3.0 * PI / 2.0
	var road_w := 10.0
	var arc_len := turns * TAU * spiral_r
	var slope := rise / arc_len
	for i in total_seg:
		var f := float(i) / float(total_seg)
		var theta := theta0 + f * turns * TAU
		var h := deck_y + f * rise
		var p := Vector3(tower_cx + cos(theta) * spiral_r, h, tower_cz + sin(theta) * spiral_r)
		var tangent := Vector3(-sin(theta), 0.0, cos(theta))
		var fwd := (tangent + Vector3.UP * slope).normalized()
		var tint := col.darkened(0.05) if i % 2 == 0 else col.darkened(0.18)
		_spiral_segment(p, fwd, spiral_r * (TAU / seg_per) * 1.3, road_w, tint)

	# Helipad parking on top + the Aero World portal at its centre.
	_build_helipad(Vector3(tower_cx, pad_y, tower_cz), 16.0)
	var aero := _make_portal_door(Vector3(tower_cx, pad_y + 3.5, tower_cz), col, "Aero World", "helicopters & planes")
	aero.body_entered.connect(_on_near.bind(aero, AERO))
	aero.body_exited.connect(_on_far.bind(aero, AERO))


func _spiral_segment(p: Vector3, fwd: Vector3, length: float, width: float, color: Color) -> void:
	# One drivable ramp segment of the spiral: a tilted road slab with a low wall
	# on each edge, all in a single static body.
	var body := StaticBody3D.new()
	var zaxis := fwd.cross(Vector3.UP).normalized()
	var yaxis := zaxis.cross(fwd).normalized()
	body.transform = Transform3D(Basis(fwd.normalized(), yaxis, zaxis), p)
	add_child(body)

	_static_box(body, Vector3(length, 1.0, width), Vector3.ZERO, color)
	for sgn in [1.0, -1.0]:
		_static_box(body, Vector3(length, 1.4, 0.5), Vector3(0, 0.9, sgn * (width * 0.5 - 0.25)), color.lightened(0.15))


func _static_box(body: StaticBody3D, size: Vector3, local_pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = local_pos
	mi.material_override = _flat(color)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = local_pos
	body.add_child(cs)


func _build_helipad(center: Vector3, radius: float) -> void:
	# Octagonal helipad: dark deck, yellow perimeter ring + lights, a green "H",
	# a windsock and a couple of parked helicopters.
	var pad := StaticBody3D.new()
	pad.position = center + Vector3(0, -0.75, 0)
	add_child(pad)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 1.5
	cyl.radial_segments = 8
	mi.mesh = cyl
	mi.material_override = _flat(Color("#2b3038"))
	pad.add_child(mi)
	var cs := CollisionShape3D.new()
	var cshape := CylinderShape3D.new()
	cshape.radius = radius
	cshape.height = 1.5
	cs.shape = cshape
	pad.add_child(cs)

	var top := center.y + 0.16

	# Yellow perimeter ring.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 4.0
	tm.outer_radius = radius - 3.4
	tm.rings = 8
	tm.ring_segments = 32
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	ring.position = Vector3(center.x, top, center.z)
	ring.material_override = _emit(Color("#ffd24a"), 1.6)
	add_child(ring)

	# Perimeter lights around the octagon edge.
	for k in 16:
		var a := TAU * float(k) / 16.0
		var light := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.5, 0.5, 0.5)
		light.mesh = lb
		light.position = Vector3(center.x + cos(a) * (radius - 1.2), top, center.z + sin(a) * (radius - 1.2))
		light.material_override = _emit(Color("#5ad36a") if k % 2 == 0 else Color("#ffe14d"), 2.0)
		add_child(light)

	# Green "H" marking.
	for dx in [-2.4, 2.4]:
		var bar := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(1.1, 0.2, 6.0)
		bar.mesh = bb
		bar.position = Vector3(center.x + dx, top, center.z)
		bar.material_override = _emit(Color("#39d65a"), 1.2)
		add_child(bar)
	var cross := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(4.0, 0.2, 1.2)
	cross.mesh = cb
	cross.position = Vector3(center.x, top, center.z)
	cross.material_override = _emit(Color("#39d65a"), 1.2)
	add_child(cross)

	# Windsock at the pad edge.
	var pole := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.top_radius = 0.12
	pcyl.bottom_radius = 0.12
	pcyl.height = 5.0
	pole.mesh = pcyl
	pole.position = Vector3(center.x - radius + 1.5, center.y + 2.5, center.z - radius + 1.5)
	pole.material_override = _flat(Color("#cfd2da"))
	add_child(pole)
	for s in 3:
		var sock := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(1.1 - s * 0.28, 0.9 - s * 0.18, 0.9 - s * 0.18)
		sock.mesh = sb
		sock.position = Vector3(center.x - radius + 2.6 + s * 0.9, center.y + 4.6, center.z - radius + 1.5)
		sock.material_override = _flat(Color("#ff7a1a") if s % 2 == 0 else Color("#ffffff"))
		add_child(sock)

	# Parked helicopters (decor, rotors idling).
	var spots := [Vector3(center.x + 9.0, center.y + 1.4, center.z + 8.0), Vector3(center.x - 9.0, center.y + 1.4, center.z + 8.0)]
	var hcolors := [Color("#e0a740"), Color("#3b86d2")]
	for idx in spots.size():
		var heli := Aircraft.new()
		add_child(heli)
		heli.configure("heli", hcolors[idx], Color("#222222"))
		heli.controlled = false
		heli.remove_from_group("player")
		heli.reset_to(spots[idx], PI)


func _emit(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


func _on_near(body: Node, gate: Node3D, world_index: int) -> void:
	if not body.is_in_group("player"):
		return
	_near = world_index
	_near_gate = gate
	_dwell = 0.0


func _on_far(body: Node, gate: Node3D, world_index: int) -> void:
	if body.is_in_group("player") and _near == world_index:
		_near = -1
		_near_gate = null
		_dwell = 0.0
		set_prompt("")


func _process(delta: float) -> void:
	_t += delta
	_animate_portals(delta)
	if _transitioning or _near == -1:
		return
	_dwell += delta
	var ratio := clampf(_dwell / ENTER_TIME, 0.0, 1.0)
	var wname := "World"
	if _near == LAB:
		wname = "Laboratory"
	elif _near == PARK:
		wname = "Parking"
	elif _near == AERO:
		wname = "Aero World"
	else:
		wname = str(GameState.get_world(_near).get("name", "World"))
	set_prompt("Entering %s ...  %d%%" % [wname, int(ratio * 100.0)])
	if _dwell >= ENTER_TIME or Input.is_action_just_pressed("advance"):
		_enter(_near)


func _enter(world_index: int) -> void:
	Sfx.play_checkpoint()
	if _near_gate:
		# Portal surge: the swirl flares up and grows to swallow the car as the
		# screen fades, so it feels like being pulled into the new world.
		var color: Color = _near_gate.get_meta("color", Color(0.6, 0.85, 1.0))
		var disc: MeshInstance3D = _near_gate.get_meta("disc")
		if is_instance_valid(disc):
			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(disc, "scale", Vector3(3.4, 3.4, 3.4), 0.45)
			var dmat: StandardMaterial3D = disc.material_override
			if dmat:
				tw.tween_property(dmat, "emission_energy_multiplier", 9.0, 0.45)
		Effects.explosion(self, _near_gate.global_position + Vector3(0, 1.0, 0.5), 1.4, color.lightened(0.2))
	if world_index == LAB:
		transition_to("res://scenes/lab.tscn")
	elif world_index == PARK:
		transition_to("res://scenes/parking.tscn")
	elif world_index == AERO:
		transition_to("res://scenes/sky_hub.tscn")
	else:
		GameState.current_world = world_index
		transition_to("res://scenes/world_map.tscn")
