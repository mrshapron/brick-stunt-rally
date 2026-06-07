class_name BrickFactory
extends RefCounted
## Builds "studded brick" nodes procedurally: a colored box body plus a grid of
## small cylinder studs on top (rendered with a MultiMesh for cheapness). No
## external assets, and deliberately generic proportions (legally distinct from
## any branded interlocking-brick toy).

const STUD_SPACING: float = 1.0
const STUD_RADIUS: float = 0.3
const STUD_HEIGHT: float = 0.22


static func make_wedge(size: Vector3, color: Color, flip: bool = false) -> Node3D:
	# A clean ramp: a triangular prism that sits flush on the ground. Rises toward
	# +X by default, or descends toward +X when flip is true.
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = size
	prism.left_to_right = 0.0 if flip else 1.0
	mi.mesh = prism
	mi.material_override = _body_material(color)
	body.add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = prism.create_convex_shape()
	body.add_child(col)
	return body


static func make_brick(size: Vector3, color: Color, kind: String, with_studs: bool = true) -> Node3D:
	var body: Node3D
	if kind == "destructible":
		var rb := RigidBody3D.new()
		rb.mass = maxf(0.5, size.x * size.y * size.z * 0.15)
		rb.add_to_group("destructible")
		body = rb
	else:
		body = StaticBody3D.new()

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = _body_material(color)
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)

	if with_studs:
		var studs := _make_studs(size, color)
		if studs != null:
			body.add_child(studs)

	return body


static func _body_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mat.metallic = 0.0
	return mat


static func _make_studs(size: Vector3, color: Color) -> MultiMeshInstance3D:
	var nx := int(floor(size.x / STUD_SPACING))
	var nz := int(floor(size.z / STUD_SPACING))
	if nx <= 0 or nz <= 0:
		return null

	var cyl := CylinderMesh.new()
	cyl.top_radius = STUD_RADIUS
	cyl.bottom_radius = STUD_RADIUS
	cyl.height = STUD_HEIGHT
	cyl.radial_segments = Mobile.stud_segments()
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color.lightened(0.08)
	smat.roughness = 0.5
	cyl.material = smat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl
	mm.instance_count = nx * nz

	var top_y := size.y * 0.5 + STUD_HEIGHT * 0.5
	var idx := 0
	for ix in nx:
		for iz in nz:
			var x := -((nx - 1) * STUD_SPACING) * 0.5 + ix * STUD_SPACING
			var z := -((nz - 1) * STUD_SPACING) * 0.5 + iz * STUD_SPACING
			mm.set_instance_transform(idx, Transform3D(Basis(), Vector3(x, top_y, z)))
			idx += 1

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	# Studs are tiny bumps; skipping them in the shadow pass saves drawing
	# thousands of cylinders into the shadow map for no visible difference.
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
