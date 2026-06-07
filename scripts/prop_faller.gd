class_name PropFaller
extends Node3D
## Periodically drops brick "boulders" from the sky around its position - a
## moving hazard the car has to dodge. Boulders are physics bodies that knock
## the car around, and they clean themselves up after a few seconds.

var interval: float = 1.6
var width: float = 14.0
var height: float = 22.0
var color: Color = Color(0.55, 0.55, 0.6)
var _t: float = 0.0


func configure(p: Dictionary) -> void:
	interval = float(p.get("interval", 1.6))
	width = float(p.get("width", 14.0))
	height = float(p.get("height", 22.0))
	if p.has("color"):
		color = Color(str(p["color"]))
	_t = randf() * interval


func _process(delta: float) -> void:
	_t += delta
	if _t >= interval:
		_t = 0.0
		_drop()


func _drop() -> void:
	var s := randf_range(1.3, 2.3)
	var b := RigidBody3D.new()
	b.mass = s * 2.0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(s, s, s)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color.lightened(randf_range(-0.1, 0.1))
	m.roughness = 0.8
	mi.material_override = m
	b.add_child(mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(s, s, s)
	cs.shape = bs
	b.add_child(cs)

	get_tree().current_scene.add_child(b)
	b.global_position = global_position + Vector3(
		randf_range(-width * 0.5, width * 0.5),
		height,
		randf_range(-10.0, 10.0))
	b.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))

	get_tree().create_timer(7.0).timeout.connect(b.queue_free)
