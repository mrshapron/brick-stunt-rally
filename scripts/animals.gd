class_name Animals
extends RefCounted
## Brick-built safari animals (decor, no collision). Each build() returns a
## Node3D facing +X. Made from simple boxes with characteristic details
## (giraffe spots, tiger stripes, elephant trunk/tusks).

const TAN := "#d9a441"
const TAN_DARK := "#8a5a2a"
const GREY := "#9a9aa0"
const GREY_DARK := "#7a7a82"
const ORANGE := "#e08a2a"
const WHITE := "#ede3d0"
const DARK := "#1a1a1a"


static func build(kind: String) -> Node3D:
	match kind:
		"elephant":
			return _elephant()
		"tiger":
			return _tiger()
		_:
			return _giraffe()


static func _giraffe() -> Node3D:
	var r := Node3D.new()
	# Legs
	for lx in [1.1, -1.1]:
		for lz in [0.6, -0.6]:
			_box(r, Vector3(0.5, 4.2, 0.5), Vector3(lx, 2.1, lz), TAN)
	# Body
	_box(r, Vector3(3.2, 1.8, 1.7), Vector3(0, 5.0, 0), TAN)
	# Neck (rising toward +X)
	var nx := 1.3
	var ny := 6.0
	for i in 4:
		_box(r, Vector3(1.0, 1.2, 0.9), Vector3(nx, ny, 0), TAN)
		nx += 0.45
		ny += 1.0
	# Head
	_box(r, Vector3(1.5, 0.9, 0.85), Vector3(nx + 0.4, ny - 0.2, 0), TAN)
	_box(r, Vector3(0.5, 0.5, 0.4), Vector3(nx + 1.1, ny - 0.3, 0), TAN_DARK)
	# Ossicones
	for oz in [0.25, -0.25]:
		_box(r, Vector3(0.16, 0.6, 0.16), Vector3(nx + 0.1, ny + 0.6, oz), TAN_DARK)
	# Spots
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 12:
		var sx := rng.randf_range(-1.4, 1.4)
		var sy := rng.randf_range(4.4, 5.7)
		var sz := 0.86 if rng.randf() < 0.5 else -0.86
		_box(r, Vector3(0.5, 0.5, 0.06), Vector3(sx, sy, sz), TAN_DARK)
	return r


static func _elephant() -> Node3D:
	var r := Node3D.new()
	for lx in [1.7, -1.7]:
		for lz in [0.9, -0.9]:
			_box(r, Vector3(1.0, 2.2, 1.0), Vector3(lx, 1.1, lz), GREY)
	# Body
	_box(r, Vector3(5.0, 3.0, 2.6), Vector3(0, 3.3, 0), GREY)
	# Head
	_box(r, Vector3(2.0, 2.2, 1.9), Vector3(3.0, 3.4, 0), GREY)
	# Ears
	for ez in [1.1, -1.1]:
		_box(r, Vector3(0.3, 2.0, 1.6), Vector3(2.7, 3.7, ez), GREY_DARK)
	# Trunk (curving down)
	var tx := 4.0
	var ty := 3.0
	for i in 5:
		_box(r, Vector3(0.7 - i * 0.06, 0.7, 0.7 - i * 0.06), Vector3(tx, ty, 0), GREY)
		tx += 0.25
		ty -= 0.6
	# Tusks
	for sz in [0.5, -0.5]:
		_box(r, Vector3(1.0, 0.2, 0.2), Vector3(4.1, 2.6, sz), WHITE)
	# Eyes
	for ez2 in [0.7, -0.7]:
		_box(r, Vector3(0.18, 0.18, 0.1), Vector3(3.95, 4.0, ez2), DARK)
	return r


static func _tiger() -> Node3D:
	var r := Node3D.new()
	for lx in [1.1, -1.1]:
		for lz in [0.5, -0.5]:
			_box(r, Vector3(0.6, 1.3, 0.6), Vector3(lx, 0.65, lz), ORANGE)
	# Body
	_box(r, Vector3(3.3, 1.4, 1.4), Vector3(0, 1.5, 0), ORANGE)
	# Belly
	_box(r, Vector3(3.0, 0.5, 1.2), Vector3(0, 0.95, 0), WHITE)
	# Head
	_box(r, Vector3(1.4, 1.3, 1.3), Vector3(2.1, 1.8, 0), ORANGE)
	_box(r, Vector3(0.5, 0.6, 0.9), Vector3(2.9, 1.6, 0), WHITE)
	for ez in [0.4, -0.4]:
		_box(r, Vector3(0.4, 0.4, 0.3), Vector3(2.0, 2.6, ez), ORANGE)
		_box(r, Vector3(0.16, 0.16, 0.1), Vector3(2.85, 2.0, ez), DARK)
	# Tail (curving up behind)
	var ttx := -1.8
	var tty := 1.6
	for i in 4:
		_box(r, Vector3(0.4, 0.4, 0.4), Vector3(ttx, tty, 0), ORANGE)
		ttx -= 0.35
		tty += 0.35
	# Stripes
	for i in 5:
		var sx := -1.2 + i * 0.6
		_box(r, Vector3(0.18, 1.5, 1.45), Vector3(sx, 1.6, 0), DARK)
	return r


static func _box(parent: Node, size: Vector3, pos: Vector3, hex: String) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.7
	mi.material_override = m
	parent.add_child(mi)
