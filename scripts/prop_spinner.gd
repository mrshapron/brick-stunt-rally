class_name PropSpinner
extends AnimatableBody3D
## A rotating brick arm on a central post that sweeps the track and knocks the
## car around - a moving obstacle. Kinematic, so it pushes the car on contact.

var spin: float = 1.6


func configure(p: Dictionary) -> void:
	sync_to_physics = true
	spin = float(p.get("spin", 1.6))
	var color := _color(p.get("color", "#19e0c8"))
	var arm := _v3(p.get("arm", [12, 1.2, 1.6]))

	# Central post (static-looking part of the same body).
	_add_part(Vector3(1.4, 4.0, 1.4), Vector3(0, 2.0, 0), color.darkened(0.2), true)
	# The sweeping arm.
	_add_part(arm, Vector3(0, 3.4, 0), color, true)


func _physics_process(delta: float) -> void:
	rotation.y += spin * delta


func _add_part(size: Vector3, pos: Vector3, color: Color, collide: bool) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	add_child(mi)
	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		add_child(col)


func _v3(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _color(v: Variant) -> Color:
	if v is String:
		return Color(v)
	return Color(0.1, 0.88, 0.78)
