class_name PropPlatform
extends AnimatableBody3D
## A studded brick platform that slides back and forth between two points and
## carries the car (kinematic body). Great for crossing gaps or rising up.

var travel: Vector3 = Vector3(0, 4, 0)
var period: float = 3.0
var _base: Vector3
var _t: float = 0.0


func configure(p: Dictionary) -> void:
	sync_to_physics = true
	var size := _v3(p.get("size", [6, 1, 6]))
	var color := _color(p.get("color", "#e0a740"))
	travel = _v3(p.get("travel", [0, 4, 0]))
	period = float(p.get("period", 3.0))
	_t = float(p.get("phase", 0.0))

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mi.material_override = mat
	add_child(mi)

	var studs := BrickFactory._make_studs(size, color)
	if studs != null:
		add_child(studs)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)


func _ready() -> void:
	_base = position


func _physics_process(delta: float) -> void:
	_t += delta
	var f := sin(_t / period * TAU) * 0.5 + 0.5
	global_position = _base + travel * f


func _v3(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _color(v: Variant) -> Color:
	if v is String:
		return Color(v)
	return Color(0.88, 0.65, 0.25)
