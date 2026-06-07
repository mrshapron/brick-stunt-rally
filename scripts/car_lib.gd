class_name CarLib
extends RefCounted
## A library of preset car designs (voxel lists) and a visual display builder
## used by the Parking lot. Designs use the same [x,y,z,"#hex",kind] format as
## the Laboratory (kinds: block / wheel / rocket).

const SCALE := 0.55


static func catalog() -> Array:
	return [
		{"name": "Red Roadster", "design": _car(6, 3, "#c43a2a", "#7f241b", 1)},
		{"name": "Blue Bolt", "design": _car(7, 3, "#2f6fb0", "#1d4e85", 1)},
		{"name": "Yellow Hauler", "design": _car(6, 4, "#e0a740", "#a8742a", 1)},
		{"name": "Green Buggy", "design": _car(5, 3, "#5aa54a", "#356b2c", 1)},
		{"name": "Neon Racer", "design": _car(7, 3, "#19e0c8", "#0f8f80", 1)},
		{"name": "War Rig", "design": _car(6, 4, "#8a6b4a", "#5b4630", 2)},
		{"name": "Rock Crawler", "design": _car(6, 5, "#6f7d6a", "#4a5648", 1)},
		{"name": "Speedster X", "design": _car(8, 3, "#e23a6d", "#9e2048", 1)},
	]


static func design(index: int) -> Array:
	var cat := catalog()
	return cat[clampi(index, 0, cat.size() - 1)]["design"]


static func car_name(index: int) -> String:
	var cat := catalog()
	return cat[clampi(index, 0, cat.size() - 1)]["name"]


static func _car(lx: int, lz: int, base: String, cab: String, rockets: int) -> Array:
	var d: Array = []
	for x in lx:
		for z in lz:
			var corner: bool = (x == 0 or x == lx - 1) and (z == 0 or z == lz - 1)
			if corner:
				d.append([x, 0, z, "#161616", "wheel"])
			else:
				d.append([x, 0, z, base, "block"])
	for x in range(1, lx - 1):
		for z in lz:
			d.append([x, 1, z, cab, "block"])
	var mid := int(lz / 2)
	for r in rockets:
		d.append([2 + r * 2, 2, mid, "#cccccc", "rocket"])
	return d


static func build_display(design_arr: Array) -> Node3D:
	# Visual-only model (no physics) for the parking lot.
	var root := Node3D.new()
	var mnx := 99.0
	var mnz := 99.0
	var mxx := -99.0
	var mxz := -99.0
	for v in design_arr:
		mnx = minf(mnx, float(v[0]))
		mxx = maxf(mxx, float(v[0]))
		mnz = minf(mnz, float(v[2]))
		mxz = maxf(mxz, float(v[2]))
	if mnx > mxx:
		mnx = 0.0
		mxx = 0.0
		mnz = 0.0
		mxz = 0.0
	var cx := (mnx + mxx) * 0.5
	var cz := (mnz + mxz) * 0.5

	for v in design_arr:
		var kind: String = str(v[4]) if v.size() > 4 else "block"
		var color := Color(str(v[3])) if v.size() > 3 else Color(0.8, 0.3, 0.25)
		var local := Vector3((float(v[0]) - cx) * SCALE, float(v[1]) * SCALE, (float(v[2]) - cz) * SCALE)
		if kind == "wheel":
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.26
			cyl.bottom_radius = 0.26
			cyl.height = 0.24
			cyl.radial_segments = 16
			w.mesh = cyl
			w.rotation_degrees = Vector3(90, 0, 0)
			w.position = local
			w.material_override = _mat(Color(0.08, 0.08, 0.1))
			root.add_child(w)
		elif kind == "rocket":
			var t := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.5, 0.2, 0.2)
			t.mesh = b
			t.position = local
			t.material_override = _mat(Color(0.7, 0.7, 0.75))
			root.add_child(t)
		else:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * SCALE * 0.92
			mi.mesh = bm
			mi.position = local
			mi.material_override = _mat(color)
			root.add_child(mi)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	return m
