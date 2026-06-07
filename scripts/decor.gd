class_name Decor
extends RefCounted
## A kit of decorative lego props (no collision): lamp posts, flowers, arches,
## signs and brick statues. Each returns a Node3D positioned at its own origin.


static func lamp_post(color: Color = Color(1.0, 0.86, 0.45)) -> Node3D:
	var r := Node3D.new()
	_box(r, Vector3(0.3, 4.0, 0.3), Vector3(0, 2.0, 0), Color(0.2, 0.2, 0.24))
	_box(r, Vector3(0.95, 0.6, 0.95), Vector3(0, 4.2, 0), Color(0.14, 0.14, 0.18))
	_box(r, Vector3(0.72, 0.5, 0.72), Vector3(0, 4.0, 0), color, 3.0)
	return r


static func flower(petal: Color = Color(1.0, 0.35, 0.45)) -> Node3D:
	var r := Node3D.new()
	_box(r, Vector3(0.16, 1.2, 0.16), Vector3(0, 0.6, 0), Color(0.3, 0.6, 0.25))
	_box(r, Vector3(0.4, 0.4, 0.4), Vector3(0, 1.35, 0), Color(1.0, 0.85, 0.2))
	for a in 4:
		var ang := a * PI * 0.5
		_box(r, Vector3(0.34, 0.2, 0.34), Vector3(cos(ang) * 0.42, 1.35, sin(ang) * 0.42), petal)
	return r


static func arch(color: Color = Color(0.85, 0.3, 0.25)) -> Node3D:
	var r := Node3D.new()
	_box(r, Vector3(0.7, 5.0, 0.9), Vector3(-2.4, 2.5, 0), color)
	_box(r, Vector3(0.7, 5.0, 0.9), Vector3(2.4, 2.5, 0), color)
	_box(r, Vector3(6.1, 1.0, 0.9), Vector3(0, 5.3, 0), color.lightened(0.12))
	var studs := BrickFactory._make_studs(Vector3(6.1, 1.0, 0.9), color.lightened(0.12))
	if studs != null:
		studs.position = Vector3(0, 5.3, 0)
		r.add_child(studs)
	return r


static func sign_post(color: Color = Color(0.2, 0.5, 0.9)) -> Node3D:
	var r := Node3D.new()
	_box(r, Vector3(0.2, 2.6, 0.2), Vector3(0, 1.3, 0), Color(0.25, 0.2, 0.15))
	_box(r, Vector3(2.4, 1.3, 0.2), Vector3(0, 2.7, 0), color)
	_box(r, Vector3(2.0, 0.28, 0.26), Vector3(0, 2.95, 0), Color(1, 1, 1))
	_box(r, Vector3(2.0, 0.28, 0.26), Vector3(0, 2.45, 0), Color(1, 1, 1))
	return r


static func statue(colors: Array) -> Node3D:
	var r := Node3D.new()
	for k in 4:
		var w := 1.7 - k * 0.25
		_box(r, Vector3(w, 1.0, w), Vector3(0, 0.5 + k * 1.0, 0), Color(str(colors[k % colors.size()])))
	return r


static func building(w: float, d: float, h: float, color: Color, win: Color) -> Node3D:
	# A collidable lego tower block with a window grid and a roof cap.
	var body := StaticBody3D.new()
	_box(body, Vector3(w, h, d), Vector3(0, h * 0.5, 0), color)
	_box(body, Vector3(w * 1.06, 0.7, d * 1.06), Vector3(0, h + 0.2, 0), color.darkened(0.3))
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(w, h, d)
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	body.add_child(cs)

	var yy := 2.2
	while yy < h - 1.6:
		var xx := -w * 0.5 + 1.4
		while xx < w * 0.5 - 0.8:
			_box(body, Vector3(0.7, 0.9, 0.12), Vector3(xx, yy, d * 0.5 + 0.06), win, 1.6)
			_box(body, Vector3(0.7, 0.9, 0.12), Vector3(xx, yy, -d * 0.5 - 0.06), win, 1.6)
			xx += 2.4
		var zz := -d * 0.5 + 1.4
		while zz < d * 0.5 - 0.8:
			_box(body, Vector3(0.12, 0.9, 0.7), Vector3(w * 0.5 + 0.06, yy, zz), win, 1.6)
			_box(body, Vector3(0.12, 0.9, 0.7), Vector3(-w * 0.5 - 0.06, yy, zz), win, 1.6)
			zz += 2.4
		yy += 3.4
	return body


static func speed_bump(length: float, color: Color = Color(0.9, 0.78, 0.25)) -> Node3D:
	# A low collidable strip the car bumps over (runs along Z).
	var body := StaticBody3D.new()
	_box(body, Vector3(1.6, 0.4, length), Vector3(0, 0.2, 0), color)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6, 0.4, length)
	cs.shape = sh
	cs.position = Vector3(0, 0.2, 0)
	body.add_child(cs)
	var z := -length * 0.5 + 1.0
	while z < length * 0.5 - 0.5:
		_box(body, Vector3(1.7, 0.06, 0.8), Vector3(0, 0.41, z), Color(0.1, 0.1, 0.12))
		z += 1.8
	return body


static func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, emissive: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	mi.material_override = m
	parent.add_child(mi)
