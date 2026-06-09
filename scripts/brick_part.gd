class_name BrickPart
extends RefCounted
## LEGO-style car parts on a fine stud/plate grid. One source of truth for the
## Lab builder, the preset cars and the driven vehicle.
##
## A part is a Dictionary:
##   { "t":"brick", "pos":[gx,gy,gz], "size":[w,d], "h":3, "color":"#hex", "rot":0 }
##   - t: brick | plate | tile | slope | wheel | rocket
##   - pos: gx,gz on the stud grid (X,Z); gy is the plate layer of the bottom
##   - size: footprint in studs (before rotation); h: height in plates
##   - rot: 0/90/180/270 yaw (footprint swaps for 90/270)

const STUD := 0.34          # world units per stud (horizontal)
const PLATE := 0.16         # world units per plate layer (vertical)
const BRICK_PLATES := 3     # a standard brick is 3 plates tall


static func default_h(t: String) -> int:
	match t:
		"plate", "tile":
			return 1
		_:
			return BRICK_PLATES


static func make(t: String, gx: int, gy: int, gz: int, w: int, d: int, color: String, h: int = -1, rot: int = 0) -> Dictionary:
	return {
		"t": t,
		"pos": [gx, gy, gz],
		"size": [w, d],
		"h": h if h > 0 else default_h(t),
		"color": color,
		"rot": rot,
	}


# --- geometry helpers ---

static func footprint(rec: Dictionary) -> Vector2i:
	var w: int = int(rec["size"][0])
	var d: int = int(rec["size"][1])
	var rot: int = int(rec.get("rot", 0))
	if rot == 90 or rot == 270:
		return Vector2i(d, w)
	return Vector2i(w, d)


static func part_h(rec: Dictionary) -> int:
	return int(rec.get("h", default_h(str(rec.get("t", "brick")))))


static func cells(rec: Dictionary) -> Array:
	var fp := footprint(rec)
	var gx: int = int(rec["pos"][0])
	var gy: int = int(rec["pos"][1])
	var gz: int = int(rec["pos"][2])
	var h := part_h(rec)
	var out: Array = []
	for ix in fp.x:
		for iz in fp.y:
			for iy in h:
				out.append(Vector3i(gx + ix, gy + iy, gz + iz))
	return out


static func wheel_radius(rec: Dictionary) -> float:
	# Visual radius of a wheel part (matches _wheel()), so callers can sit a car
	# correctly on its round wheels rather than on the wheel's box height.
	var diam := maxf(float(rec["size"][0]), float(rec["size"][1])) * STUD
	return maxf(diam * 0.62, 0.34)


static func center_world(rec: Dictionary) -> Vector3:
	var fp := footprint(rec)
	var gx: float = float(rec["pos"][0])
	var gy: float = float(rec["pos"][1])
	var gz: float = float(rec["pos"][2])
	var h := part_h(rec)
	return Vector3((gx + fp.x * 0.5) * STUD, (gy + h * 0.5) * PLATE, (gz + fp.y * 0.5) * STUD)


static func design_aabb(design: Array, skip_wheels: bool = false) -> AABB:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	var any := false
	for rec in design:
		if skip_wheels and str(rec.get("t", "brick")) == "wheel":
			continue
		var c := center_world(rec)
		var fp := footprint(rec)
		var half := Vector3(fp.x * STUD, part_h(rec) * PLATE, fp.y * STUD) * 0.5
		mn = mn.min(c - half)
		mx = mx.max(c + half)
		any = true
	if not any:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return AABB(mn, mx - mn)


# --- visual builder ---

static func build_part(rec: Dictionary) -> Node3D:
	var t := str(rec.get("t", "brick"))
	var color := Color(str(rec.get("color", "#cccccc")))
	var w: int = int(rec["size"][0])
	var d: int = int(rec["size"][1])
	var h := part_h(rec)
	var sx := w * STUD
	var sy := h * PLATE
	var sz := d * STUD

	var root := Node3D.new()
	match t:
		"wheel":
			root.add_child(_wheel(maxf(sx, sz)))
		"rocket":
			_rocket(root, color, maxf(sx, sz))
		"slope":
			_slope(root, sx, sy, sz, color)
		"tile":
			_box(root, Vector3(sx * 0.98, sy, sz * 0.98), color, 0.3, 0.1)
		_:
			_box(root, Vector3(sx * 0.97, sy, sz * 0.97), color, 0.5, 0.0)
			var studs := _studs(w, d, color, sy)
			if studs != null:
				root.add_child(studs)
	root.rotation.y = deg_to_rad(float(rec.get("rot", 0)))
	return root


# Returns the wheel's spinnable node so callers can rotate it (display cars).
static func build_wheel(diam: float) -> Node3D:
	return _wheel(diam)


static func _box(parent: Node, size: Vector3, color: Color, rough: float, metal: float) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	mi.material_override = m
	parent.add_child(mi)


static func _studs(w: int, d: int, color: Color, sy: float) -> MultiMeshInstance3D:
	if w <= 0 or d <= 0:
		return null
	var cyl := CylinderMesh.new()
	cyl.top_radius = STUD * 0.3
	cyl.bottom_radius = STUD * 0.3
	cyl.height = PLATE * 0.55
	cyl.radial_segments = Mobile.stud_segments()
	var m := StandardMaterial3D.new()
	m.albedo_color = color.lightened(0.07)
	m.roughness = 0.5
	cyl.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl
	mm.instance_count = w * d
	var top_y := sy * 0.5 + cyl.height * 0.5 - 0.005
	var idx := 0
	for ix in w:
		for iz in d:
			var x := (-(w - 1) * 0.5 + ix) * STUD
			var z := (-(d - 1) * 0.5 + iz) * STUD
			mm.set_instance_transform(idx, Transform3D(Basis(), Vector3(x, top_y, z)))
			idx += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


static func _slope(parent: Node, sx: float, sy: float, sz: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(sx, sy, sz)
	prism.left_to_right = 1.0
	mi.mesh = prism
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.35
	mi.material_override = m
	parent.add_child(mi)


static func _rocket(parent: Node, color: Color, length: float) -> void:
	var tube := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(maxf(length, 0.5), 0.26, 0.26)
	tube.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.16, 0.2)
	m.metallic = 0.5
	m.roughness = 0.4
	tube.material_override = m
	parent.add_child(tube)
	var tip := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.2, 0.3, 0.3)
	tip.mesh = tb
	tip.position = Vector3(maxf(length, 0.5) * 0.5, 0, 0)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.9, 0.2, 0.15)
	tm.emission_enabled = true
	tm.emission = Color(0.9, 0.1, 0.1)
	tm.emission_energy_multiplier = 0.4
	tip.material_override = tm
	parent.add_child(tip)


static func _wheel(diam: float) -> Node3D:
	var radius := maxf(diam * 0.62, 0.34)
	var width := radius * 0.85
	var spin := Node3D.new()

	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.06, 0.06, 0.08)
	tire_mat.roughness = 0.95
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.8, 0.82, 0.88)
	rim_mat.metallic = 0.8
	rim_mat.roughness = 0.3

	var tire := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = radius
	tc.bottom_radius = radius
	tc.height = width
	tc.radial_segments = 18
	tc.material = tire_mat
	tire.mesh = tc
	tire.rotation_degrees = Vector3(90, 0, 0)
	spin.add_child(tire)

	var hub := MeshInstance3D.new()
	var hc := CylinderMesh.new()
	hc.top_radius = radius * 0.5
	hc.bottom_radius = radius * 0.5
	hc.height = width + 0.04
	hc.radial_segments = 14
	hc.material = rim_mat
	hub.mesh = hc
	hub.rotation_degrees = Vector3(90, 0, 0)
	spin.add_child(hub)

	for i in 5:
		var ang := TAU * float(i) / 5.0
		for zside in [width * 0.5, -width * 0.5]:
			var spoke := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(radius * 0.9, 0.07, 0.05)
			spoke.mesh = sb
			spoke.material_override = rim_mat
			spoke.position = Vector3(cos(ang) * radius * 0.42, sin(ang) * radius * 0.42, zside)
			spoke.rotation = Vector3(0, 0, ang)
			spin.add_child(spoke)

	for i in 12:
		var ang := TAU * float(i) / 12.0
		var tread := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.12, 0.13, width * 0.96)
		tread.mesh = tb
		tread.material_override = tire_mat
		tread.position = Vector3(cos(ang) * (radius - 0.02), sin(ang) * (radius - 0.02), 0)
		tread.rotation = Vector3(0, 0, ang)
		spin.add_child(tread)

	return spin
