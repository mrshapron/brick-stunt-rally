class_name Effects
extends RefCounted
## Spawns a one-shot explosion: a burst of emissive particles, a quick light
## flash, and a boom sound. Auto-frees when finished.


static func explosion(host: Node, pos: Vector3, scale: float = 1.0, color: Color = Color(1.0, 0.6, 0.15)) -> void:
	if host == null or not host.is_inside_tree():
		return

	# Fireball: bright fast chunks (fewer particles on mobile).
	var ps := Mobile.particle_scale()
	var fire := _burst(host, pos, int(34 * scale * ps), 0.55, color, 6.0 * scale, 16.0 * scale, Vector3(0, -10, 0), 0.5 * scale, 1.6 * scale, 3.0)
	fire.spread = 180.0
	# Hot yellow core.
	var core := _burst(host, pos, int(16 * scale * ps), 0.4, Color(1.0, 0.95, 0.5), 8.0 * scale, 20.0 * scale, Vector3(0, -6, 0), 0.4 * scale, 1.0 * scale, 4.0)
	core.spread = 180.0
	# Rising smoke.
	var smoke := _burst(host, pos + Vector3(0, 0.5, 0), int(18 * scale * ps), 1.2, Color(0.2, 0.19, 0.18, 0.55), 1.5 * scale, 4.0 * scale, Vector3(0, 1.5, 0), 1.0 * scale, 2.4 * scale, 0.0)
	smoke.spread = 50.0
	smoke.direction = Vector3(0, 1, 0)

	# Expanding shockwave ring on the ground.
	var ring := MeshInstance3D.new()
	host.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.3, 0)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 1.0
	ring.mesh = torus
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.75, 0.35, 0.85)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.6, 0.2)
	rmat.emission_energy_multiplier = 3.0
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.scale = Vector3.ONE * 0.4
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * scale * 5.0, 0.35)
	tw.tween_property(rmat, "albedo_color:a", 0.0, 0.35)
	tw.finished.connect(ring.queue_free)

	# Bright flash light (skipped on mobile to respect light limits).
	if Mobile.explosion_light():
		var light := OmniLight3D.new()
		host.add_child(light)
		light.global_position = pos
		light.omni_range = 18.0 * scale
		light.light_energy = 9.0
		light.light_color = color
		host.get_tree().create_timer(0.2).timeout.connect(light.queue_free)

	Sfx.play_explosion()


static func _burst(host: Node, pos: Vector3, amount: int, life: float, color: Color, vmin: float, vmax: float, grav: Vector3, smin: float, smax: float, emission: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	host.add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.color = color
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = mat
	p.mesh = bm
	p.finished.connect(p.queue_free)
	return p


static func damage_number(host: Node, pos: Vector3, amount: float) -> void:
	if host == null or not host.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = str(int(round(amount)))
	l.font_size = 130
	l.pixel_size = 0.018
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1.0, 0.9, 0.3)
	l.outline_size = 18
	l.position = pos + Vector3(randf_range(-0.5, 0.5), 1.0, 0)
	host.add_child(l)
	var tw := host.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 3.2, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.finished.connect(l.queue_free)


static func blast(host: Node3D, pos: Vector3, radius: float, damage: float, force: float) -> void:
	# Radial explosion: damages enemies and physically flings nearby rigid bodies
	# (destructible bricks) away, with falloff. Leaves the player's own car alone.
	if host == null or not host.is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = host.get_world_3d().direct_space_state
	if space == null:
		return
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis(), pos)
	params.collide_with_bodies = true
	var hits: Array[Dictionary] = space.intersect_shape(params, 48)
	var seen: Dictionary = {}
	for h in hits:
		var col := h.get("collider") as Node3D
		if col == null:
			continue
		var id := col.get_instance_id()
		if seen.has(id):
			continue
		seen[id] = true
		if col.is_in_group("player"):
			continue
		var d := col.global_position.distance_to(pos)
		var falloff := clampf(1.0 - d / radius, 0.15, 1.0)
		if (col.is_in_group("enemy") or col.is_in_group("racer")) and col.has_method("take_damage"):
			col.take_damage(damage * falloff)
		if col is RigidBody3D:
			var dir := col.global_position - pos
			dir.y = 0.0
			if dir.length() < 0.1:
				dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			(col as RigidBody3D).apply_central_impulse(dir.normalized() * force * falloff + Vector3(0, force * 0.5 * falloff, 0))
