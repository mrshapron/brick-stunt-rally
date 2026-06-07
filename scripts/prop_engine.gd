class_name PropEngine
extends Node3D
## Decorative brick engine: a base block with a spinning gear/flywheel and a
## couple of bobbing pistons. Purely visual (no collision) - it just adds life.

var spin_speed: float = 4.0
var _gear: Node3D
var _pistons: Array[MeshInstance3D] = []


func configure(p: Dictionary) -> void:
	var color := _color(p.get("color", "#8a8f9e"))
	var s: float = float(p.get("scale", 1.0))
	spin_speed = float(p.get("spin", 4.0))

	_add_box(Vector3(3, 1.5, 2) * s, Vector3(0, 0.75, 0) * s, color)
	_add_box(Vector3(2.2, 0.8, 1.6) * s, Vector3(0.2, 1.7, 0) * s, color.darkened(0.1))

	# Spinning gear/flywheel on the front face (axle along Z, faces the camera).
	_gear = Node3D.new()
	_gear.position = Vector3(1.4, 1.0, 0) * s
	add_child(_gear)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9 * s
	cyl.bottom_radius = 0.9 * s
	cyl.height = 0.35 * s
	cyl.radial_segments = 8
	disc.mesh = cyl
	disc.rotation_degrees = Vector3(90, 0, 0)
	disc.material_override = _mat(color.lightened(0.15))
	_gear.add_child(disc)
	# A bright bolt off-center so the spin is clearly visible.
	var bolt := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.35, 0.35, 0.5) * s
	bolt.mesh = bm
	bolt.position = Vector3(0.55 * s, 0, 0)
	bolt.material_override = _mat(Color(0.95, 0.85, 0.2))
	_gear.add_child(bolt)

	for i in 2:
		var p_mesh := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.5, 1.2, 0.5) * s
		p_mesh.mesh = pm
		p_mesh.position = Vector3((-0.6 + i * 0.6) * s, 1.9 * s, 0)
		p_mesh.material_override = _mat(Color(0.85, 0.85, 0.9))
		add_child(p_mesh)
		_pistons.append(p_mesh)


func _process(delta: float) -> void:
	if _gear:
		_gear.rotation.z += spin_speed * delta
	var t := Time.get_ticks_msec() / 1000.0
	for i in _pistons.size():
		_pistons[i].position.y = 1.9 + sin(t * spin_speed + i * PI) * 0.28


func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.55
	return m


func _color(v: Variant) -> Color:
	if v is String:
		return Color(v)
	return Color(0.54, 0.56, 0.62)
