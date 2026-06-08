class_name CarLib
extends RefCounted
## Preset cars and the display builder. Designs are lists of LEGO part records
## (see brick_part.gd). Used by the garage, AI opponents, and reward screen.


static func catalog() -> Array:
	return [
		{"name": "Red Roadster", "design": _car(12, 6, "#c43a2a", "#7f241b", "#1a1a1a", 1)},
		{"name": "Blue Bolt", "design": _car(13, 6, "#2f6fb0", "#1d4e85", "#e6e6e6", 1)},
		{"name": "Yellow Hauler", "design": _car(12, 7, "#e0a740", "#a8742a", "#1a1a1a", 1)},
		{"name": "Green Buggy", "design": _car(11, 6, "#5aa54a", "#356b2c", "#1a1a1a", 1)},
		{"name": "Neon Racer", "design": _car(13, 6, "#19e0c8", "#0f8f80", "#141414", 1)},
		{"name": "War Rig", "design": _car(12, 7, "#8a6b4a", "#5b4630", "#caa040", 2)},
		{"name": "Rock Crawler", "design": _car(11, 7, "#6f7d6a", "#4a5648", "#1a1a1a", 1)},
		{"name": "Speedster X", "design": _car(14, 6, "#e23a6d", "#9e2048", "#141414", 1)},
		{"name": "Safari Truck", "design": _car(12, 7, "#c2b25a", "#7a6a2a", "#5b4630", 1)},
	]


static func design(index: int) -> Array:
	var cat := catalog()
	return cat[clampi(index, 0, cat.size() - 1)]["design"]


static func car_name(index: int) -> String:
	var cat := catalog()
	return cat[clampi(index, 0, cat.size() - 1)]["name"]


static func _car(length: int, width: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# A sleek studded car: full-footprint lower body, an accent beltline, a
	# smooth tiled hood/trunk, an inset cabin with sloped windscreens and a tiled
	# roof, wheels at the corners, and roof rockets.
	var d: Array = []
	var L := length
	var W := width
	var cl: int = maxi(L - 6, 2)

	# Wheels (2x2) at the four corners.
	for wx in [1, L - 3]:
		d.append(BrickPart.make("wheel", wx, 0, 0, 2, 2, "#161616"))
		d.append(BrickPart.make("wheel", wx, 0, W - 2, 2, 2, "#161616"))

	# Lower body (3 plates) + accent beltline plate on top.
	d.append(BrickPart.make("brick", 0, 1, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 4, 0, L, W, accent))

	# Smooth hood + trunk.
	d.append(BrickPart.make("tile", 0, 5, 0, 2, W, base))
	d.append(BrickPart.make("tile", L - 2, 5, 0, 2, W, base))

	# Cabin (inset), sloped windscreens front and back, smooth roof.
	d.append(BrickPart.make("brick", 3, 5, 1, cl, W - 2, cab))
	d.append(BrickPart.make("slope", 2, 5, 1, 1, W - 2, cab, 3, 0))
	d.append(BrickPart.make("slope", L - 3, 5, 1, 1, W - 2, cab, 3, 180))
	d.append(BrickPart.make("tile", 3, 8, 1, cl, W - 2, cab))

	# Rocket(s) on the roof.
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", 4 + r * 3, 9, midz, 2, 1, "#cccccc"))
	return d


static func build_display(design_arr: Array) -> Node3D:
	# Visual-only model sitting on its wheels with its lowest point at y=0, so
	# callers can drop the root on the ground. Wheels exposed via meta("wheels").
	var root := Node3D.new()
	var wheels: Array = []
	var aabb := BrickPart.design_aabb(design_arr)
	var cx := aabb.position.x + aabb.size.x * 0.5
	var cz := aabb.position.z + aabb.size.z * 0.5
	var min_bottom := 1.0e9

	for rec in design_arr:
		var node := BrickPart.build_part(rec)
		var c := BrickPart.center_world(rec)
		node.position = Vector3(c.x - cx, c.y, c.z - cz)
		root.add_child(node)
		if str(rec.get("t", "brick")) == "wheel" and node.get_child_count() > 0:
			wheels.append(node.get_child(0))
		min_bottom = minf(min_bottom, node.position.y - BrickPart.part_h(rec) * BrickPart.PLATE * 0.5)

	if min_bottom < 0.9e9:
		for child in root.get_children():
			child.position.y -= min_bottom
	root.set_meta("wheels", wheels)
	return root
