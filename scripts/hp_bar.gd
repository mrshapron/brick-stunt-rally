class_name HPBar
extends Node3D
## A floating health bar (red background + green fill) that always faces the
## camera. Call set_ratio(0..1) to update.

var width: float = 2.4
var _fill: MeshInstance3D


func _ready() -> void:
	add_child(_make_bar(Vector3(width + 0.14, 0.36, 0.05), Color(0.08, 0.0, 0.0)))
	_fill = _make_bar(Vector3(width, 0.28, 0.08), Color(0.2, 1.0, 0.25))
	add_child(_fill)


func set_ratio(r: float) -> void:
	r = clampf(r, 0.0, 1.0)
	_fill.scale.x = maxf(r, 0.001)
	_fill.position.x = -width * 0.5 * (1.0 - r)
	var c := Color(1.0, 0.15, 0.1).lerp(Color(0.2, 1.0, 0.25), r)
	var mat: StandardMaterial3D = _fill.material_override
	mat.albedo_color = c
	mat.emission = c


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_transform.basis = cam.global_transform.basis


func _make_bar(size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.7
	mi.material_override = m
	return mi
