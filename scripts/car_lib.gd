class_name CarLib
extends RefCounted
## Preset cars and the display builder. Designs are lists of LEGO part records
## (see brick_part.gd). Used by the garage, AI opponents, and reward screen.


const TIRE := "#161616"


static func catalog() -> Array:
	# A varied garage: each car uses a distinct body archetype so the silhouettes
	# read clearly (low sports cars, tall jeeps, trucks, buggies, etc.).
	return [
		{"name": "Crimson GT", "design": _sports(14, 6, "#d23b2e", "#33333a", "#f2c94c", 1)},
		{"name": "Azure Spyder", "design": _supercar(15, 7, "#2f7fd0", "#13233a", "#eaf2ff", 1)},
		{"name": "Trail Boss 4x4", "design": _suv(12, 8, "#4f8a3f", "#28331f", "#d8d8d0", 1)},
		{"name": "Dune Raider", "design": _buggy(12, 7, "#e0a740", "#2a2a2a", "#ff7a1a", 1)},
		{"name": "Neon Phantom", "design": _supercar(15, 7, "#19e0c8", "#0c2f2c", "#ff2bd0", 1)},
		{"name": "War Rig", "design": _monster(13, 8, "#8a6b4a", "#43331f", "#caa040", 3)},
		{"name": "Granite Crawler", "design": _suv(12, 8, "#6f7d6a", "#333b33", "#1a1a1a", 1)},
		{"name": "Viper Muscle", "design": _muscle(14, 7, "#e23a6d", "#241319", "#f0f0f0", 1)},
		{"name": "Savanna Hauler", "design": _truck(13, 7, "#c2b25a", "#5b4630", "#2e2316", 1)},
	]


static func design(index: int) -> Array:
	var cat := catalog()
	return cat[clampi(index, 0, cat.size() - 1)]["design"]


static func car_name(index: int) -> String:
	var cat := catalog()
	return cat[clampi(index, 0, cat.size() - 1)]["name"]


static func _add_wheels(d: Array, L: int, W: int, ws: int, front_gx: int, rear_gx: int) -> void:
	for wx in [front_gx, rear_gx]:
		d.append(BrickPart.make("wheel", wx, 0, 0, ws, ws, TIRE))
		d.append(BrickPart.make("wheel", wx, 0, W - ws, ws, ws, TIRE))


static func _sports(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# Low, long roadster: raked nose, tiny cockpit, smooth deck, rear wing.
	var d: Array = []
	_add_wheels(d, L, W, 2, 1, L - 3)
	d.append(BrickPart.make("brick", 0, 1, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 4, 0, L, W, accent))
	d.append(BrickPart.make("slope", 0, 5, 0, 3, W, base, 2, 0))
	var hood_end: int = maxi(L - 7, 4)
	d.append(BrickPart.make("tile", 3, 5, 0, maxi(hood_end - 3, 1), W, base))
	var cab_x: int = hood_end
	var cab_len: int = 3
	d.append(BrickPart.make("slope", cab_x - 1, 5, 1, 1, W - 2, cab, 2, 0))
	d.append(BrickPart.make("brick", cab_x, 5, 1, cab_len, W - 2, cab, 2))
	d.append(BrickPart.make("tile", cab_x, 7, 1, cab_len, W - 2, cab))
	d.append(BrickPart.make("slope", cab_x + cab_len, 5, 1, 1, W - 2, cab, 2, 180))
	var deck_x: int = cab_x + cab_len + 1
	d.append(BrickPart.make("tile", deck_x, 5, 0, maxi(L - deck_x, 1), W, base))
	d.append(BrickPart.make("brick", L - 2, 5, 0, 1, 1, "#1c1c1c", 2))
	d.append(BrickPart.make("brick", L - 2, 5, W - 1, 1, 1, "#1c1c1c", 2))
	d.append(BrickPart.make("tile", L - 2, 7, 0, 1, W, accent))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", deck_x + r, 6, midz, 2, 1, "#cccccc"))
	return d


static func _supercar(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# Ultra-low, wide hypercar: long sharp nose, side intakes, big high wing.
	var d: Array = []
	_add_wheels(d, L, W, 2, 1, L - 3)
	d.append(BrickPart.make("brick", 0, 1, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 4, 0, L, W, accent))
	d.append(BrickPart.make("slope", 0, 5, 0, 4, W, base, 2, 0))
	d.append(BrickPart.make("plate", 4, 4, 0, maxi(L - 8, 1), 1, accent))
	d.append(BrickPart.make("plate", 4, 4, W - 1, maxi(L - 8, 1), 1, accent))
	var cab_x: int = int(L * 0.45)
	d.append(BrickPart.make("slope", cab_x - 1, 5, 1, 1, W - 2, cab, 2, 0))
	d.append(BrickPart.make("brick", cab_x, 5, 1, 3, W - 2, cab, 2))
	d.append(BrickPart.make("slope", cab_x + 3, 5, 1, 1, W - 2, cab, 2, 180))
	d.append(BrickPart.make("tile", cab_x, 7, 1, 3, W - 2, cab))
	var deck_x: int = cab_x + 4
	d.append(BrickPart.make("tile", deck_x, 5, 0, maxi(L - deck_x, 1), W, base))
	d.append(BrickPart.make("brick", L - 2, 5, 1, 1, 1, "#181818", 3))
	d.append(BrickPart.make("brick", L - 2, 5, W - 2, 1, 1, "#181818", 3))
	d.append(BrickPart.make("tile", L - 2, 8, 0, 2, W, accent))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", deck_x + r, 6, midz, 2, 1, "#dddddd"))
	return d


static func _suv(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# Tall, boxy 4x4 on big wheels: upright cabin, roof rack, bull bar.
	var d: Array = []
	var ws := 3
	_add_wheels(d, L, W, ws, 1, L - 1 - ws)
	d.append(BrickPart.make("brick", 0, 1, 0, L, W, base))
	d.append(BrickPart.make("brick", 0, 4, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 7, 0, L, W, accent))
	d.append(BrickPart.make("tile", 0, 4, 0, 1, W, "#2a2a2a"))
	var cab_len: int = maxi(L - 5, 3)
	d.append(BrickPart.make("slope", 1, 8, 1, 1, W - 2, cab, 3, 0))
	d.append(BrickPart.make("brick", 2, 8, 1, cab_len, W - 2, cab, 3))
	d.append(BrickPart.make("tile", 2, 11, 1, cab_len, W - 2, cab))
	d.append(BrickPart.make("plate", 2, 12, 1, cab_len, 1, "#222222"))
	d.append(BrickPart.make("plate", 2, 12, W - 2, cab_len, 1, "#222222"))
	for cb in range(2, 2 + cab_len, 2):
		d.append(BrickPart.make("plate", cb, 12, 1, 1, W - 2, "#222222"))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", 3 + r * 3, 13, midz, 2, 1, "#cccccc"))
	return d


static func _truck(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# Pickup: tall cab up front, open flatbed with low walls behind, big wheels.
	var d: Array = []
	var ws := 3
	_add_wheels(d, L, W, ws, 1, L - 1 - ws)
	d.append(BrickPart.make("brick", 0, 1, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 4, 0, L, W, accent))
	var cab_len: int = int(L * 0.4)
	d.append(BrickPart.make("slope", 0, 5, 0, 1, W, base, 3, 0))
	d.append(BrickPart.make("brick", 1, 5, 1, cab_len, W - 2, cab, 3))
	d.append(BrickPart.make("slope", 1 + cab_len, 5, 1, 1, W - 2, cab, 3, 180))
	d.append(BrickPart.make("tile", 1, 8, 1, cab_len, W - 2, cab))
	var bed_x: int = 1 + cab_len + 1
	var bed_len: int = maxi(L - bed_x, 2)
	d.append(BrickPart.make("tile", bed_x, 5, 0, bed_len, W, base))
	d.append(BrickPart.make("brick", bed_x, 5, 0, bed_len, 1, base, 2))
	d.append(BrickPart.make("brick", bed_x, 5, W - 1, bed_len, 1, base, 2))
	d.append(BrickPart.make("brick", L - 1, 5, 0, 1, W, base, 2))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", bed_x + r, 7, midz, 2, 1, "#cccccc"))
	return d


static func _buggy(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# Open off-road buggy: narrow chassis, exposed roll cage, light bar.
	var d: Array = []
	var ws := 3
	_add_wheels(d, L, W, ws, 1, L - 1 - ws)
	d.append(BrickPart.make("brick", 1, 1, 1, L - 2, W - 2, base))
	d.append(BrickPart.make("plate", 1, 4, 1, L - 2, W - 2, accent))
	d.append(BrickPart.make("brick", int(L * 0.4), 5, 2, 2, maxi(W - 4, 1), cab, 2))
	var x0: int = 2
	var x1: int = L - 3
	var z0: int = 1
	var z1: int = W - 2
	for px in [x0, x1]:
		for pz in [z0, z1]:
			d.append(BrickPart.make("brick", px, 5, pz, 1, 1, "#2a2a2a", 4))
	d.append(BrickPart.make("plate", x0, 9, z0, x1 - x0 + 1, 1, "#2a2a2a"))
	d.append(BrickPart.make("plate", x0, 9, z1, x1 - x0 + 1, 1, "#2a2a2a"))
	d.append(BrickPart.make("plate", x0, 9, z0, 1, z1 - z0 + 1, "#2a2a2a"))
	d.append(BrickPart.make("plate", x1, 9, z0, 1, z1 - z0 + 1, "#2a2a2a"))
	d.append(BrickPart.make("tile", 0, 4, 1, 1, W - 2, accent))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", x1 - 1 + r, 5, midz, 2, 1, "#dddddd"))
	return d


static func _muscle(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# Muscle car: long hood with a scoop, fastback roofline, dual exhaust tips.
	var d: Array = []
	_add_wheels(d, L, W, 2, 1, L - 3)
	d.append(BrickPart.make("brick", 0, 1, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 4, 0, L, W, accent))
	var hood_len: int = int(L * 0.4)
	d.append(BrickPart.make("tile", 0, 5, 0, hood_len, W, base))
	d.append(BrickPart.make("brick", int(hood_len * 0.45), 5, int(W / 2) - 1, 2, 2, "#1c1c1c", 2))
	var cab_x: int = hood_len
	var cab_len: int = maxi(int(L * 0.32), 2)
	d.append(BrickPart.make("slope", cab_x - 1, 5, 1, 1, W - 2, cab, 3, 0))
	d.append(BrickPart.make("brick", cab_x, 5, 1, cab_len, W - 2, cab, 3))
	d.append(BrickPart.make("tile", cab_x, 8, 1, cab_len, W - 2, cab))
	d.append(BrickPart.make("slope", cab_x + cab_len, 5, 1, 3, W - 2, base, 3, 180))
	d.append(BrickPart.make("tile", L - 2, 5, 0, 2, W, base))
	d.append(BrickPart.make("brick", L - 1, 1, 1, 1, 1, "#444444", 1))
	d.append(BrickPart.make("brick", L - 1, 1, W - 2, 1, 1, "#444444", 1))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", cab_x + r, 9, midz, 2, 1, "#cccccc"))
	return d


static func _monster(L: int, W: int, base: String, cab: String, accent: String, rockets: int) -> Array:
	# War rig: huge wheels, raised armored body, front armor slope, roof guns.
	var d: Array = []
	var ws := 4
	_add_wheels(d, L, W, ws, 0, L - ws)
	d.append(BrickPart.make("brick", 0, 2, 0, L, W, base))
	d.append(BrickPart.make("brick", 0, 5, 0, L, W, base))
	d.append(BrickPart.make("plate", 0, 8, 0, L, W, accent))
	d.append(BrickPart.make("slope", 0, 8, 0, 2, W, base, 3, 0))
	var cab_len: int = maxi(L - 6, 3)
	d.append(BrickPart.make("slope", 1, 9, 1, 1, W - 2, cab, 3, 0))
	d.append(BrickPart.make("brick", 2, 9, 1, cab_len, W - 2, cab, 3))
	d.append(BrickPart.make("tile", 2, 12, 1, cab_len, W - 2, cab))
	var midz: int = int(W / 2) - 1
	for r in rockets:
		d.append(BrickPart.make("rocket", 3 + r * 3, 13, midz, 2, 1, "#caa040"))
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
		var bottom := node.position.y - BrickPart.part_h(rec) * BrickPart.PLATE * 0.5
		if str(rec.get("t", "brick")) == "wheel":
			bottom = node.position.y - BrickPart.wheel_radius(rec)
			if node.get_child_count() > 0:
				wheels.append(node.get_child(0))
		min_bottom = minf(min_bottom, bottom)

	if min_bottom < 0.9e9:
		for child in root.get_children():
			child.position.y -= min_bottom
	root.set_meta("wheels", wheels)
	return root
