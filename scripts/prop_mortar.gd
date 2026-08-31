class_name PropMortar
extends Node3D
## Off-screen artillery shelling the battlefield: every interval it picks a spot
## near the player, telegraphs it with a shrinking red ring + whistle of light,
## then the shell lands - a big blast that damages the player if they're inside.
## Teaches "keep moving!" and makes the war zone feel alive.

var interval: float = 4.0
var damage: float = 22.0
var radius: float = 6.0

var _timer: float = 3.0


func configure(p: Dictionary) -> void:
	interval = float(p.get("interval", 4.0))
	damage = float(p.get("damage", 22.0))
	radius = float(p.get("radius", 6.0))
	_timer = interval * 0.75


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = interval
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not (player is Node3D):
		return
	# Aim near (not exactly at) the player so driving away always works.
	var p := (player as Node3D).global_position
	var ang := randf() * TAU
	var dist := randf_range(2.0, 11.0)
	var target := Vector3(p.x + cos(ang) * dist, 0.0, p.z + sin(ang) * dist)
	_telegraph(target)


func _telegraph(target: Vector3) -> void:
	var host := get_parent()
	if host == null:
		return

	# Shrinking warning ring on the ground.
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.5
	tm.outer_radius = radius
	tm.rings = 6
	tm.ring_segments = 24
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.2, 0.1, 0.9)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.2, 0.1)
	m.emission_energy_multiplier = 2.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = m
	host.add_child(ring)
	ring.global_position = target + Vector3(0, 0.3, 0)

	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(0.25, 1.0, 0.25), 1.3)
	tw.tween_property(m, "emission_energy_multiplier", 5.0, 1.3)
	tw.finished.connect(func() -> void:
		ring.queue_free()
		_impact(target))


func _impact(target: Vector3) -> void:
	var host := get_parent()
	if host == null or not is_inside_tree():
		return
	Effects.explosion(host, target + Vector3(0, 0.8, 0), 1.5, Color(1.0, 0.45, 0.1))
	if host is Node3D:
		# Also pops barrels / hurts enemies caught in the shelling - chaos!
		Effects.blast(host, target + Vector3(0, 0.8, 0), radius, 18.0, 16.0)
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D and player.has_method("take_damage"):
		var d := (player as Node3D).global_position.distance_to(target)
		if d < radius:
			player.take_damage(damage * clampf(1.0 - d / radius, 0.35, 1.0))
