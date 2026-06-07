class_name Minifig
extends RefCounted
## Builds a generic blocky "minifigure" character from primitives (legally
## distinct proportions). Faces +Z. Returns a Node3D ~1.6 units tall at scale 1.


static func build(s: float = 1.0, shirt: String = "#2f6fb0", legs: String = "#23324d", skin: String = "#f4c542", hair: String = "#7a3b1f") -> Node3D:
	var root := Node3D.new()

	# Hips + legs
	_box(root, Vector3(0.62, 0.16, 0.36) * s, Vector3(0, 0.62, 0) * s, legs)
	_box(root, Vector3(0.27, 0.55, 0.34) * s, Vector3(-0.16, 0.3, 0) * s, legs)
	_box(root, Vector3(0.27, 0.55, 0.34) * s, Vector3(0.16, 0.3, 0) * s, _darken(legs))

	# Torso
	_box(root, Vector3(0.64, 0.5, 0.4) * s, Vector3(0, 0.98, 0) * s, shirt)

	# Arms + hands
	_box(root, Vector3(0.16, 0.46, 0.2) * s, Vector3(-0.42, 1.0, 0.02) * s, _darken(shirt))
	_box(root, Vector3(0.16, 0.46, 0.2) * s, Vector3(0.42, 1.0, 0.02) * s, _darken(shirt))
	_box(root, Vector3(0.16, 0.16, 0.16) * s, Vector3(-0.42, 0.78, 0.16) * s, skin)
	_box(root, Vector3(0.16, 0.16, 0.16) * s, Vector3(0.42, 0.78, 0.16) * s, skin)

	# Head + face + hair
	_cyl(root, 0.22 * s, 0.34 * s, Vector3(0, 1.42, 0) * s, skin)
	_box(root, Vector3(0.05, 0.06, 0.02) * s, Vector3(-0.08, 1.46, 0.205) * s, "#1a1a1a")
	_box(root, Vector3(0.05, 0.06, 0.02) * s, Vector3(0.08, 1.46, 0.205) * s, "#1a1a1a")
	_box(root, Vector3(0.47, 0.16, 0.47) * s, Vector3(0, 1.64, 0) * s, hair)

	return root


static func _darken(hex: String) -> String:
	return Color(hex).darkened(0.12).to_html(false)


static func _box(parent: Node, size: Vector3, pos: Vector3, hex: String) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(hex)
	parent.add_child(mi)


static func _cyl(parent: Node, r: float, h: float, pos: Vector3, hex: String) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	mi.mesh = c
	mi.position = pos
	mi.material_override = _mat(hex)
	parent.add_child(mi)


static func _mat(hex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 0.55
	return m
