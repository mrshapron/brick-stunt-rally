extends Area3D
## A small decorative prop that shatters when the player drives into it instead
## of blocking the car. Its box mesh pieces fly off as short-lived shards.

## How much the car is jolted (HP) when it smashes through this prop. Small, and
## it regenerates over time, so it's just a light "ouch" for plowing through.
var damage: float = 6.0
var _broken: bool = false


func _ready() -> void:
	add_to_group("breakable")
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _broken or not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_shatter()


func _shatter() -> void:
	_broken = true
	var host := get_tree().current_scene
	if host != null:
		for c in get_children():
			if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
				_spawn_shard(host, c as MeshInstance3D)
	Sfx.play_smash()
	queue_free()


func _spawn_shard(host: Node, mi: MeshInstance3D) -> void:
	var bm := mi.mesh as BoxMesh
	var rb := RigidBody3D.new()
	rb.mass = 0.2
	rb.gravity_scale = 1.2

	var vis := MeshInstance3D.new()
	var newmesh := BoxMesh.new()
	newmesh.size = bm.size
	vis.mesh = newmesh
	vis.material_override = mi.material_override
	rb.add_child(vis)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = bm.size
	cs.shape = shape
	rb.add_child(cs)

	host.add_child(rb)
	rb.global_position = mi.global_position
	rb.apply_central_impulse(Vector3(randf_range(-1.2, 1.2), randf_range(1.6, 3.2), randf_range(-1.2, 1.2)))
	rb.angular_velocity = Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7))
	get_tree().create_timer(1.4).timeout.connect(rb.queue_free)
