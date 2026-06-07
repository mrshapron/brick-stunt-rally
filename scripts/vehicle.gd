class_name Vehicle
extends RigidBody3D
## Arcade car that drives freely across the ground plane (X = screen left/right,
## Z = screen depth) while staying upright. Input is screen-relative (matches the
## fixed camera angle): the car accelerates toward the pressed direction and
## turns to face it. Raycast wheels give suspension so ramps still launch it.

signal flipped
signal damaged(ratio: float)
signal died

@export var max_health: float = 100.0
@export var fire_cooldown: float = 0.32
@export var missile_damage: float = 34.0
@export var engine_accel: float = 30.0
@export var max_speed: float = 24.0
@export var turn_speed: float = 9.0
## Tire lateral grip: fraction of sideways velocity the tires cancel each
## physics step (0 = ice / free slide, 1 = perfect static grip / no slide).
@export_range(0.0, 1.0) var tire_grip: float = 0.85
@export var suspension_rest: float = 0.55
@export var suspension_stiffness: float = 45.0
@export var suspension_damping: float = 5.5
@export var wheel_radius: float = 0.4
@export var rolling_resistance: float = 1.5
## How much the body visually pitches/rolls under acceleration (springy feel).
@export var lean_amount: float = 0.011

var _wheels: Array[RayCast3D] = []
var _wheel_meshes: Array[MeshInstance3D] = []
var _grounded: bool = false
var _boost_timer: float = 0.0
var _dust: CPUParticles3D
var _chassis: Node3D
var _prev_vel: Vector3 = Vector3.ZERO
var health: float = 100.0
var _fire_timer: float = 0.0
var _dead: bool = false
var controlled: bool = true
var _driver: Node3D
var _launchers: Array[Vector3] = []


func _ready() -> void:
	_chassis = $Chassis
	health = max_health
	mass = 4.0
	_build_from_design()
	_build_launchers()
	# Pitch/roll are free so the chassis tilts to follow the ground (real
	# suspension feel); yaw is driven directly for arcade steering.
	axis_lock_angular_x = false
	axis_lock_angular_z = false
	angular_damp = 1.5
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 6
	add_to_group("player")
	body_entered.connect(_on_body_entered)
	for c in $Wheels.get_children():
		if c is RayCast3D:
			c.enabled = true
			_wheels.append(c)
			_wheel_meshes.append(_make_wheel_mesh(c))
	_setup_dust()


func _build_from_design() -> void:
	# Build the body from the player's Laboratory design. Each voxel has a kind:
	# "block" (body), "wheel" (a driving wheel) or "rocket" (a missile launcher).
	var design := GameState.get_car_design()
	var scale := 0.55

	var mn := Vector3(99, 99, 99)
	var mx := Vector3(-99, -99, -99)
	for v in design:
		var c := Vector3(float(v[0]), float(v[1]), float(v[2]))
		mn = Vector3(minf(mn.x, c.x), minf(mn.y, c.y), minf(mn.z, c.z))
		mx = Vector3(maxf(mx.x, c.x), maxf(mx.y, c.y), maxf(mx.z, c.z))
	if mn.x > mx.x:
		mn = Vector3.ZERO
		mx = Vector3.ZERO
	var center := (mn + mx) * 0.5
	var dim := (mx - mn + Vector3.ONE) * scale

	# Remove the placeholder collider; we build one collider per solid brick so
	# the car's collision matches exactly what was built.
	$CollisionShape3D.queue_free()

	var wheel_cells: Array[Vector3] = []
	var collider_count := 0
	for v in design:
		var cell := Vector3(float(v[0]), float(v[1]), float(v[2]))
		var local := (cell - center) * scale
		var kind: String = str(v[4]) if v.size() > 4 else "block"
		var col := Color(str(v[3])) if v.size() > 3 else Color(0.8, 0.3, 0.25)
		if kind == "wheel":
			wheel_cells.append(local)
		elif kind == "rocket":
			_launchers.append(local)
			_add_launcher_mesh(local)
			_add_collider(local, scale)
			collider_count += 1
		else:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3.ONE * scale * 0.92
			mi.mesh = bm
			mi.position = local
			var m := StandardMaterial3D.new()
			m.albedo_color = col
			m.roughness = 0.5
			mi.material_override = m
			_chassis.add_child(mi)
			_add_collider(local, scale)
			collider_count += 1

	if collider_count == 0:
		_add_collider(Vector3.ZERO, scale)

	_driver = Minifig.build(0.7)
	_driver.position = Vector3(0, dim.y * 0.5 - 0.7, -0.1)
	_chassis.add_child(_driver)

	# Wheels: use placed wheel parts if any, else auto 4 corners.
	if wheel_cells.is_empty():
		var hx := maxf(dim.x * 0.5 - 0.3, 0.5)
		var hz := maxf(dim.z * 0.5 - 0.2, 0.4)
		var by := -dim.y * 0.5 + 0.1
		for wx in [hx, -hx]:
			for wz in [hz, -hz]:
				wheel_cells.append(Vector3(wx, by, wz))
	for wpos in wheel_cells:
		var ray := RayCast3D.new()
		ray.position = wpos
		ray.target_position = Vector3(0, -(suspension_rest + wheel_radius), 0)
		$Wheels.add_child(ray)

	if _launchers.is_empty():
		_launchers.append(Vector3(dim.x * 0.5, dim.y * 0.3, 0))


func _add_collider(local: Vector3, scale: float) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * scale * 0.98
	cs.shape = bs
	cs.position = local
	add_child(cs)


func _add_launcher_mesh(local: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.3, 0.3)
	mi.mesh = bm
	mi.position = local
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.16, 0.2)
	m.metallic = 0.5
	mi.material_override = m
	_chassis.add_child(mi)


func _make_wheel_mesh(ray: RayCast3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = wheel_radius
	cyl.bottom_radius = wheel_radius
	cyl.height = 0.45
	cyl.radial_segments = 18
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.07, 0.07, 0.09)
	m.roughness = 0.9
	cyl.material = m
	mi.mesh = cyl
	mi.rotation_degrees = Vector3(90, 0, 0)
	ray.add_child(mi)
	return mi


func _setup_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = 24
	_dust.lifetime = 0.7
	_dust.position = Vector3(-1.4, -0.45, 0)
	_dust.emitting = false
	_dust.direction = Vector3(-1, 0.5, 0)
	_dust.spread = 30.0
	_dust.initial_velocity_min = 2.0
	_dust.initial_velocity_max = 5.0
	_dust.gravity = Vector3(0, -3.0, 0)
	_dust.scale_amount_min = 0.4
	_dust.scale_amount_max = 1.1
	_dust.color = Color(0.82, 0.77, 0.62)

	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.85, 0.8, 0.66, 0.6)
	dmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = dmat
	_dust.mesh = quad
	add_child(_dust)


func _physics_process(delta: float) -> void:
	var ix := 0.0
	var iz := 0.0
	if controlled:
		ix = Input.get_axis("move_left", "move_right")
		iz = Input.get_axis("move_up", "move_down")
	var move := Vector3(ix, 0.0, iz)
	if move.length() > 1.0:
		move = move.normalized()

	_grounded = false
	# Suspension pushes along the car's own up axis so the four corner wheels
	# settle the body parallel to the surface it's resting on.
	var up := global_transform.basis.y
	for i in _wheels.size():
		var ray := _wheels[i]
		ray.force_raycast_update()
		var mesh := _wheel_meshes[i]
		if ray.is_colliding():
			_grounded = true
			var hit := ray.get_collision_point()
			var origin := ray.global_position
			var max_len := suspension_rest + wheel_radius
			var dist := origin.distance_to(hit)
			var compression := clampf(1.0 - dist / max_len, 0.0, 1.0)
			var point_vel := _point_velocity(origin)
			var damp := -up.dot(point_vel) * suspension_damping
			var spring := compression * suspension_stiffness
			apply_force(up * (spring + damp) * mass, origin - global_position)
			var target_y := clampf(wheel_radius - dist, -max_len, wheel_radius)
			mesh.position.y = lerpf(mesh.position.y, target_y, clampf(delta * 18.0, 0.0, 1.0))
		else:
			mesh.position.y = lerpf(mesh.position.y, -suspension_rest, clampf(delta * 10.0, 0.0, 1.0))

	# Tire lateral friction: cancel sideways (horizontal) velocity so the car
	# grips and tracks its heading instead of sliding. Only with wheels down.
	if _grounded:
		var side := global_transform.basis.z
		side.y = 0.0
		if side.length() > 0.01:
			side = side.normalized()
			var lateral := side.dot(linear_velocity)
			linear_velocity -= side * (lateral * tire_grip)

	var hvel := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	# Current heading from the forward axis (robust while the body is tilted).
	var fwd := global_transform.basis.x
	var cur_yaw := atan2(-fwd.z, fwd.x)

	if _grounded:
		if move.length() > 0.05:
			if hvel.length() < max_speed:
				apply_central_force(move * engine_accel * mass)
			var target_yaw := atan2(-move.z, move.x)
			var diff := wrapf(target_yaw - cur_yaw, -PI, PI)
			angular_velocity.y = diff * turn_speed
		else:
			angular_velocity.y = 0.0
			apply_central_force(-hvel * rolling_resistance * mass)
	else:
		# Airborne: gently right the car so it lands wheels-down.
		var corr := up.cross(Vector3.UP)
		apply_torque(corr * 8.0 * mass)

	_spin_wheels(hvel.length(), delta)

	if _boost_timer > 0.0:
		_boost_timer -= delta
		apply_central_force(global_transform.basis.x * engine_accel * mass * 0.9)

	if _dust:
		_dust.emitting = _grounded and hvel.length() > 4.0

	_fire_timer -= delta
	if controlled and not _dead and Input.is_action_pressed("fire") and _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		_shoot()

	_update_lean(delta)


func _build_launchers() -> void:
	for sz in [-0.55, 0.55]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.32, 0.32)
		mi.mesh = bm
		mi.position = Vector3(0.4, 1.0, sz)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.16, 0.16, 0.19)
		m.metallic = 0.4
		mi.material_override = m
		_chassis.add_child(mi)


func _shoot() -> void:
	var dir := global_transform.basis.x
	for local in _launchers:
		var muzzle := to_global(local) + dir * 0.8
		var m := Missile.new()
		m.setup(dir, missile_damage)
		m.position = muzzle
		get_tree().current_scene.add_child(m)
	Sfx.play_shoot()


func take_damage(d: float) -> void:
	if _dead:
		return
	health = maxf(0.0, health - d)
	damaged.emit(health / max_health)
	Sfx.play_hit()
	if health <= 0.0:
		_dead = true
		died.emit()


func get_health_ratio() -> float:
	return health / max_health


func set_controlled(value: bool) -> void:
	controlled = value


func set_driver_visible(value: bool) -> void:
	if _driver:
		_driver.visible = value


func _update_lean(delta: float) -> void:
	# Visual-only chassis lean from acceleration: dive/squat under accel-brake,
	# roll into turns. Makes the suspension feel springy without destabilizing
	# the physics body (which stays upright).
	var accel := (linear_velocity - _prev_vel) / delta
	_prev_vel = linear_velocity
	var fwd := global_transform.basis.x
	var side := global_transform.basis.z
	var long_a := fwd.dot(accel)
	var lat_a := side.dot(accel)
	var target_pitch := clampf(-long_a * lean_amount, -0.16, 0.16)
	var target_roll := clampf(lat_a * lean_amount, -0.16, 0.16)
	var w := clampf(delta * 9.0, 0.0, 1.0)
	_chassis.rotation.z = lerpf(_chassis.rotation.z, target_pitch, w)
	_chassis.rotation.x = lerpf(_chassis.rotation.x, target_roll, w)


func _spin_wheels(speed: float, delta: float) -> void:
	var spin := speed * delta / wheel_radius
	for mesh in _wheel_meshes:
		mesh.rotate_object_local(Vector3.UP, spin)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("destructible") and linear_velocity.length() > 6.0:
		Sfx.play_smash()
		if body is RigidBody3D:
			var dir := Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized()
			var impulse := dir * 6.0 + Vector3(0, 4.0, 0)
			body.call_deferred("apply_central_impulse", impulse)


func _point_velocity(p: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(p - global_position)


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func add_boost() -> void:
	_boost_timer = 0.6
