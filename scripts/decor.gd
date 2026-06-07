class_name Decor
extends RefCounted
## A kit of decorative lego props: lamp posts, flowers, arches, signs and brick
## statues. Most are solid (collide with the car); small fragile things like
## flowers shatter when driven through. Each returns a Node3D at its own origin.

const BREAK_PROP := preload("res://scripts/break_prop.gd")


static func lamp_post(color: Color = Color(1.0, 0.86, 0.45)) -> Node3D:
	# Breakable: knock it over and it bursts apart (gives the car a small jolt).
	var r: Area3D = BREAK_PROP.new()
	_box(r, Vector3(0.3, 4.0, 0.3), Vector3(0, 2.0, 0), Color(0.2, 0.2, 0.24))
	_box(r, Vector3(0.95, 0.6, 0.95), Vector3(0, 4.2, 0), Color(0.14, 0.14, 0.18))
	_box(r, Vector3(0.72, 0.5, 0.72), Vector3(0, 4.0, 0), color, 3.0)
	_break_box(r, Vector3(1.0, 4.7, 1.0), Vector3(0, 2.35, 0))
	return r


static func flower(petal: Color = Color(1.0, 0.35, 0.45)) -> Node3D:
	# Fragile: the car plows through and the flower bursts into shards instead of
	# stopping the car (see break_prop.gd).
	var r: Area3D = BREAK_PROP.new()
	_box(r, Vector3(0.16, 1.2, 0.16), Vector3(0, 0.6, 0), Color(0.3, 0.6, 0.25))
	_box(r, Vector3(0.4, 0.4, 0.4), Vector3(0, 1.35, 0), Color(1.0, 0.85, 0.2))
	for a in 4:
		var ang := a * PI * 0.5
		_box(r, Vector3(0.34, 0.2, 0.34), Vector3(cos(ang) * 0.42, 1.35, sin(ang) * 0.42), petal)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.7, 1.1)
	cs.shape = shape
	cs.position = Vector3(0, 0.85, 0)
	r.add_child(cs)
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
	solidify(r)
	return r


static func sign_post(color: Color = Color(0.2, 0.5, 0.9)) -> Node3D:
	var r := Node3D.new()
	_box(r, Vector3(0.2, 2.6, 0.2), Vector3(0, 1.3, 0), Color(0.25, 0.2, 0.15))
	_box(r, Vector3(2.4, 1.3, 0.2), Vector3(0, 2.7, 0), color)
	_box(r, Vector3(2.0, 0.28, 0.26), Vector3(0, 2.95, 0), Color(1, 1, 1))
	_box(r, Vector3(2.0, 0.28, 0.26), Vector3(0, 2.45, 0), Color(1, 1, 1))
	solidify(r)
	return r


static func statue(colors: Array) -> Node3D:
	# Breakable stacked-brick statue: drive into it and the blocks tumble apart.
	var r: Area3D = BREAK_PROP.new()
	for k in 4:
		var w := 1.7 - k * 0.25
		_box(r, Vector3(w, 1.0, w), Vector3(0, 0.5 + k * 1.0, 0), Color(str(colors[k % colors.size()])))
	_break_box(r, Vector3(1.9, 4.2, 1.9), Vector3(0, 2.1, 0))
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


static func fountain() -> Node3D:
	var r := Node3D.new()
	var s := 6.0
	var stone := Color("#bcbcc4")
	var water := Color("#3ba0e0")
	_box(r, Vector3(s, 0.8, 0.4), Vector3(0, 0.4, s * 0.5), stone)
	_box(r, Vector3(s, 0.8, 0.4), Vector3(0, 0.4, -s * 0.5), stone)
	_box(r, Vector3(0.4, 0.8, s), Vector3(s * 0.5, 0.4, 0), stone)
	_box(r, Vector3(0.4, 0.8, s), Vector3(-s * 0.5, 0.4, 0), stone)
	_box(r, Vector3(s - 0.4, 0.5, s - 0.4), Vector3(0, 0.5, 0), water, 0.3)
	_box(r, Vector3(0.8, 2.0, 0.8), Vector3(0, 1.5, 0), stone)
	_box(r, Vector3(2.2, 0.4, 2.2), Vector3(0, 2.6, 0), stone)
	_box(r, Vector3(1.2, 0.4, 1.2), Vector3(0, 2.95, 0), water, 0.3)
	solidify(r)
	return r


static func nyc_skyline() -> Node3D:
	# A "postcard" brick build (like the souvenir sets): a slate backboard with
	# the Brooklyn Bridge, twin towers, the Empire State Building, a cloud, a
	# flag, the Statue of Liberty, and a NEW YORK sign. Faces +Z. No collision.
	var r := Node3D.new()
	var slate := Color("#2b2f3d")
	var tan := Color("#d8b079")
	var blue := Color("#2f6bb0")
	var gray := Color("#9aa0ad")
	var green := Color("#5fa783")
	var white := Color("#f2f4f7")

	# Backboard + a few sky panels for that mosaic look. The board is thick and
	# the buildings stand FORWARD of it (higher +Z) so the whole thing reads as
	# a real 3D diorama instead of a flat picture.
	_box(r, Vector3(17.0, 9.4, 0.8), Vector3(0, 4.7, -0.4), slate)
	_box(r, Vector3(4.2, 4.0, 0.2), Vector3(-3.0, 6.4, 0.05), Color("#3a567d"))
	_box(r, Vector3(3.2, 3.0, 0.2), Vector3(4.6, 6.6, 0.05), Color("#5b4a3a"))
	_box(r, Vector3(3.0, 2.4, 0.2), Vector3(1.4, 7.6, 0.05), Color("#46506a"))

	# Base diorama platform (gives the build a real footprint with depth).
	_box(r, Vector3(17.0, 0.8, 3.6), Vector3(0, 0.4, 1.4), Color("#3d6b48"))
	_box(r, Vector3(17.0, 0.5, 1.3), Vector3(0, 0.95, 2.6), Color("#2f9bd6"))
	for gx in [-6.5, -2.0, 3.0, 6.8]:
		_box(r, Vector3(1.1, 0.5, 0.6), Vector3(gx, 1.05, 2.1), Color("#46b04a"))

	# --- Brooklyn Bridge (left): two double-arch towers + a deck with depth ---
	var bz := 1.1
	var bdepth := 1.5
	for tx in [-7.2, -4.4]:
		# Two legs per tower with a gap = the classic twin-arch silhouette.
		for lx in [tx - 0.5, tx + 0.5]:
			_box(r, Vector3(0.55, 5.6, bdepth), Vector3(lx, 3.4, bz), tan)
		_box(r, Vector3(1.9, 0.55, bdepth + 0.1), Vector3(tx, 6.1, bz), tan.darkened(0.12))
		_box(r, Vector3(1.9, 0.45, bdepth + 0.1), Vector3(tx, 4.0, bz), tan.darkened(0.05))
	# Roadway deck (runs along X, has real Z depth).
	_box(r, Vector3(5.2, 0.5, bdepth + 0.2), Vector3(-5.8, 2.7, bz), gray)
	_box(r, Vector3(5.2, 0.18, bdepth + 0.3), Vector3(-5.8, 3.0, bz), gray.lightened(0.1))
	# Suspension cables on BOTH side faces so the bridge has depth.
	for zc in [bz - (bdepth * 0.5) - 0.05, bz + (bdepth * 0.5) + 0.05]:
		for sgn in [-1.0, 1.0]:
			_rbox(r, Vector3(0.1, 3.4, 0.1), Vector3(-5.8 + sgn * 1.35, 4.5, zc), Vector3(0, 0, 46.0 * sgn), Color("#cfd3da"))
			_rbox(r, Vector3(0.08, 2.2, 0.08), Vector3(-5.8 + sgn * 2.1, 4.0, zc), Vector3(0, 0, 60.0 * sgn), Color("#cfd3da"))

	# --- Twin towers (centre-right, blue glass, deep) ---
	for tw: Vector3 in [Vector3(2.1, 3.3, 1.0), Vector3(3.4, 3.7, 1.0)]:
		var th: float = tw.y * 2.0
		_box(r, Vector3(1.0, th, 1.2), Vector3(tw.x, tw.y, tw.z), blue)
		_box(r, Vector3(1.06, 0.3, 1.26), Vector3(tw.x, th, tw.z), blue.lightened(0.1))
		var wy := 1.4
		while wy < th - 0.6:
			_box(r, Vector3(1.04, 0.12, 1.24), Vector3(tw.x, wy, tw.z), blue.darkened(0.35))
			wy += 0.7

	# --- Empire State Building (right, stepped tan tower, deep) ---
	_box(r, Vector3(2.4, 4.2, 1.5), Vector3(6.0, 2.1, 1.0), tan)
	_box(r, Vector3(1.8, 2.6, 1.2), Vector3(6.0, 5.0, 1.0), tan.lightened(0.04))
	_box(r, Vector3(1.1, 1.8, 0.9), Vector3(6.0, 6.9, 1.0), tan.lightened(0.08))
	_box(r, Vector3(0.18, 1.7, 0.18), Vector3(6.0, 8.4, 1.0), gray)
	for ey in [2.0, 3.4, 4.8]:
		_box(r, Vector3(2.0, 0.14, 1.54), Vector3(6.0, ey, 1.0), tan.darkened(0.3))

	# --- Cloud (top) ---
	for cb in [Vector3(-1.2, 8.0, 0.4), Vector3(-0.2, 8.3, 0.4), Vector3(0.8, 8.0, 0.4)]:
		_box(r, Vector3(1.5, 1.1, 0.7), cb, white)

	# --- US flag (top-left): proper stars & stripes ---
	_box(r, Vector3(0.14, 2.6, 0.14), Vector3(-7.7, 7.5, 0.7), gray)
	for s in 7:
		var stripe := Color("#c0392b") if s % 2 == 0 else white
		_box(r, Vector3(1.5, 0.13, 0.12), Vector3(-6.85, 8.85 - float(s) * 0.16, 0.78), stripe)
	_box(r, Vector3(0.62, 0.5, 0.13), Vector3(-7.2, 8.72, 0.82), Color("#274690"))
	for star in [Vector2(-7.38, 8.82), Vector2(-7.05, 8.82), Vector2(-7.38, 8.6), Vector2(-7.05, 8.6)]:
		_box(r, Vector3(0.1, 0.1, 0.06), Vector3(star.x, star.y, 0.9), white)

	# --- Statue of Liberty (centre front, most forward) ---
	var sx := -0.6
	var sz := 1.9
	_box(r, Vector3(1.8, 1.3, 1.4), Vector3(sx, 0.95, sz), tan)
	_box(r, Vector3(1.3, 0.9, 1.0), Vector3(sx, 2.0, sz), tan.lightened(0.06))
	_box(r, Vector3(0.95, 2.3, 0.8), Vector3(sx, 3.6, sz), green)
	_box(r, Vector3(0.75, 0.6, 0.7), Vector3(sx, 4.9, sz), green.lightened(0.05))
	_box(r, Vector3(0.5, 0.55, 0.55), Vector3(sx, 5.4, sz), green)
	for c in 5:
		var ca := -1.0 + float(c) * 0.5
		_rbox(r, Vector3(0.12, 0.42, 0.12), Vector3(sx + ca * 0.45, 5.85, sz), Vector3(0, 0, -ca * 45.0), green.lightened(0.08))
	# Raised arm + torch.
	_rbox(r, Vector3(0.2, 1.3, 0.2), Vector3(sx + 0.55, 5.4, sz + 0.05), Vector3(0, 0, -32.0), green)
	_box(r, Vector3(0.22, 0.5, 0.22), Vector3(sx + 1.05, 6.2, sz + 0.05), gray)
	_box(r, Vector3(0.34, 0.42, 0.34), Vector3(sx + 1.1, 6.6, sz + 0.05), Color("#ff8a1e"), 2.2)

	# --- AMERICA banner (top, red/white/blue with raised text) ---
	_box(r, Vector3(7.6, 1.1, 0.5), Vector3(2.4, 9.1, 0.7), Color("#274690"))
	_box(r, Vector3(7.6, 0.16, 0.52), Vector3(2.4, 9.62, 0.72), Color("#c0392b"))
	_box(r, Vector3(7.6, 0.16, 0.52), Vector3(2.4, 8.58, 0.72), Color("#c0392b"))
	var america := Label3D.new()
	america.text = "AMERICA"
	america.font_size = 110
	america.outline_size = 22
	america.outline_modulate = Color(0.06, 0.06, 0.12)
	america.pixel_size = 0.006
	america.position = Vector3(2.4, 9.12, 1.0)
	america.double_sided = true
	r.add_child(america)

	# --- NEW YORK sign (raised plaque with depth) ---
	_box(r, Vector3(5.2, 1.3, 0.5), Vector3(0, 1.0, 2.5), Color("#ef8a1c"))
	_box(r, Vector3(5.2, 0.26, 0.54), Vector3(0, 0.4, 2.52), Color("#2f9bd6"))
	var sign := Label3D.new()
	sign.text = "NEW YORK"
	sign.font_size = 130
	sign.outline_size = 26
	sign.outline_modulate = Color(0.1, 0.08, 0.05)
	sign.modulate = Color(1, 1, 1)
	sign.pixel_size = 0.006
	sign.position = Vector3(0, 1.05, 2.78)
	sign.double_sided = true
	r.add_child(sign)
	solidify(r)
	return r


static func pink_bear() -> Node3D:
	# "Lotso"-style brick teddy: round pink body, cream belly/muzzle, dark-pink
	# inner ears + heart nose, grumpy brows, and a wooden mallet on a little
	# stool that he rests a paw on. Faces +Z, stands on its own origin.
	var r := Node3D.new()
	var pink := Color("#ec2f8e")
	var pink_d := Color("#bf1c6a")
	var cream := Color("#eccf9f")
	var nose_c := Color("#aa1858")
	var mouth_c := Color("#6e1030")
	var white := Color("#f7f7fa")
	var brown := Color("#5b3318")
	var wood := Color("#b07a3c")
	var wood_d := Color("#8f6228")

	# Legs + cream paw pads.
	for lx in [-0.98, 0.98]:
		_box(r, Vector3(1.55, 2.1, 1.7), Vector3(lx, 1.05, 0), pink)
		_box(r, Vector3(1.05, 0.5, 0.8), Vector3(lx, 0.4, 0.8), cream)

	# Rounded body (stacked tiers) + big cream tummy patch.
	_box(r, Vector3(3.3, 1.6, 2.5), Vector3(0, 2.5, 0), pink)
	_box(r, Vector3(3.5, 1.7, 2.6), Vector3(0, 3.7, 0), pink)
	_box(r, Vector3(2.9, 1.0, 2.3), Vector3(0, 4.7, 0), pink)
	_box(r, Vector3(2.3, 2.6, 0.5), Vector3(0, 3.3, 1.25), cream)
	_box(r, Vector3(1.4, 0.9, 0.45), Vector3(0, 4.5, 1.3), cream)

	# Left arm hanging; cream paw.
	_rbox(r, Vector3(1.0, 2.1, 1.05), Vector3(-2.25, 3.7, 0.2), Vector3(0, 0, 13.0), pink)
	_box(r, Vector3(0.95, 0.85, 1.0), Vector3(-2.55, 2.6, 0.5), cream)

	# Right arm reaching down/forward to rest on the mallet; cream paw.
	_rbox(r, Vector3(1.0, 2.3, 1.05), Vector3(2.35, 3.5, 0.7), Vector3(0, 0, -26.0), pink)
	_box(r, Vector3(1.05, 0.7, 1.15), Vector3(3.0, 2.85, 1.5), cream)

	# Head.
	_box(r, Vector3(3.7, 3.1, 2.9), Vector3(0, 6.0, 0), pink)
	_box(r, Vector3(3.2, 0.8, 2.6), Vector3(0, 7.6, 0), pink)
	# Ears: pink outer with dark-pink inner.
	for ex in [-1.6, 1.6]:
		_box(r, Vector3(1.15, 1.2, 0.95), Vector3(ex, 7.5, 0), pink)
		_box(r, Vector3(0.6, 0.65, 0.45), Vector3(ex, 7.5, 0.5), pink_d)
	# Big cream muzzle.
	_box(r, Vector3(2.5, 1.8, 1.1), Vector3(0, 5.35, 1.4), cream)
	# Heart-shaped dark-pink nose (two top bumps + point).
	for nx in [-0.26, 0.26]:
		_box(r, Vector3(0.5, 0.45, 0.55), Vector3(nx, 6.0, 2.0), nose_c)
	_box(r, Vector3(0.55, 0.5, 0.55), Vector3(0, 5.65, 2.0), nose_c)
	_box(r, Vector3(0.22, 0.4, 0.3), Vector3(0, 5.35, 2.05), nose_c.darkened(0.15))
	# Smiling open mouth (dark interior + cream lower lip).
	_box(r, Vector3(1.5, 0.5, 0.3), Vector3(0, 4.95, 2.0), mouth_c)
	_box(r, Vector3(1.7, 0.2, 0.35), Vector3(0, 4.65, 2.0), cream.darkened(0.05))
	# Eyes (white + brown iris + pupil + glint) and grumpy inward brows.
	for ey in [-0.8, 0.8]:
		_box(r, Vector3(0.66, 0.78, 0.25), Vector3(ey, 6.55, 1.55), white)
		_box(r, Vector3(0.36, 0.4, 0.2), Vector3(ey, 6.5, 1.68), brown)
		_box(r, Vector3(0.16, 0.18, 0.16), Vector3(ey, 6.52, 1.78), Color(0.05, 0.05, 0.05))
		_box(r, Vector3(0.08, 0.1, 0.08), Vector3(ey - 0.1, 6.62, 1.84), white)
		_rbox(r, Vector3(0.9, 0.26, 0.24), Vector3(ey, 7.18, 1.55), Vector3(0, 0, signf(ey) * 26.0), pink_d)

	# --- Wooden mallet on a little stool (his "hand helper") ---
	# Stool top + four legs.
	_box(r, Vector3(2.4, 0.4, 2.0), Vector3(3.0, 2.2, 1.5), wood)
	for ox in [-0.85, 0.85]:
		for oz in [-0.7, 0.7]:
			_box(r, Vector3(0.32, 2.0, 0.32), Vector3(3.0 + ox, 1.0, 1.5 + oz), wood_d)
	# Mallet: cylindrical head lying on the stool + handle angled up to the paw.
	_rbox(r, Vector3(1.9, 0.85, 0.85), Vector3(3.0, 2.85, 1.5), Vector3(0, 0, 0), wood)
	for bx in [-0.7, 0.7]:
		_box(r, Vector3(0.22, 0.95, 0.95), Vector3(3.0 + bx, 2.85, 1.5), wood_d)
	_rbox(r, Vector3(0.36, 2.6, 0.36), Vector3(2.55, 3.9, 1.45), Vector3(0, 0, 18.0), wood)

	solidify(r)
	return r


static func solidify(root: Node3D) -> void:
	# Give a decorative build collision: walk its mesh descendants and add a
	# matching collision shape (box/cylinder/prism) onto one StaticBody so the
	# car can't drive through it. Text labels and particles are skipped.
	var body := StaticBody3D.new()
	var shapes: Array = []
	_gather_shapes(root, Transform3D.IDENTITY, shapes)
	for entry in shapes:
		var cs := CollisionShape3D.new()
		cs.shape = entry[0]
		cs.transform = entry[1]
		body.add_child(cs)
	root.add_child(body)


static func _gather_shapes(node: Node, accum: Transform3D, out: Array) -> void:
	for child in node.get_children():
		if not (child is Node3D):
			continue
		var t: Transform3D = accum * (child as Node3D).transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var sh := _shape_for_mesh((child as MeshInstance3D).mesh)
			if sh != null:
				out.append([sh, t])
		_gather_shapes(child, t, out)


static func _shape_for_mesh(mesh: Mesh) -> Shape3D:
	if mesh is BoxMesh:
		var b := BoxShape3D.new()
		b.size = (mesh as BoxMesh).size
		return b
	if mesh is CylinderMesh:
		var cm := mesh as CylinderMesh
		var c := CylinderShape3D.new()
		c.radius = maxf(cm.top_radius, cm.bottom_radius)
		c.height = cm.height
		return c
	if mesh is PrismMesh:
		return mesh.create_convex_shape()
	return null


static func _rbox(parent: Node, size: Vector3, pos: Vector3, rot_deg: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	mi.material_override = m
	parent.add_child(mi)


static func _break_box(parent: Node, size: Vector3, pos: Vector3) -> void:
	# A trigger volume on a BreakProp so the car's overlap triggers the shatter.
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	parent.add_child(cs)


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
