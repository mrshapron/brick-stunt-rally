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
## Health regen: after this many seconds without taking a hit, the car slowly
## heals back up at regen_rate HP per second.
@export var regen_delay: float = 4.0
@export var regen_rate: float = 7.0
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
## Rocket turret aiming (arrow keys): yaw turn rate and barrel elevation rate.
@export var turret_turn_speed: float = 2.6
@export var turret_pitch_speed: float = 1.6

var _wheels: Array[RayCast3D] = []
var _wheel_meshes: Array[Node3D] = []
var _wheel_spins: Array[Node3D] = []
var _grounded: bool = false
var _boost_timer: float = 0.0
var _dust: CPUParticles3D
var _chassis: Node3D
var _prev_vel: Vector3 = Vector3.ZERO
var health: float = 100.0
var _fire_timer: float = 0.0
var _since_hit: float = 999.0
var _dead: bool = false
var _body_color: Color = Color("#c43a2a")
var _last_break_ms: int = 0
var controlled: bool = true
var _driver: Node3D
var _launchers: Array[Vector3] = []
var _turret: Node3D
var _barrels: Node3D
var _turret_yaw: float = 0.0
var _turret_pitch: float = 0.12
var _top_y: float = 0.6


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
	# Build the body from the player's Laboratory design (LEGO part records).
	# Visuals come from BrickPart; collision is a single body box (fast + stable)
	# and the wheels are raycast suspension at the design's wheel parts.
	var design := GameState.get_car_design()
	var aabb := BrickPart.design_aabb(design)
	if aabb.size.length() < 0.01:
		aabb = AABB(Vector3.ZERO, Vector3.ONE)
	var center := aabb.position + aabb.size * 0.5
	_top_y = aabb.size.y * 0.5

	$CollisionShape3D.queue_free()

	var wheel_cells: Array[Vector3] = []
	for rec in design:
		var t := str(rec.get("t", "brick"))
		var local := BrickPart.center_world(rec) - center
		if t == "wheel":
			wheel_cells.append(local)
			continue
		if t == "brick" or t == "plate" or t == "tile":
			_body_color = Color(str(rec.get("color", "#c43a2a")))
		var node := BrickPart.build_part(rec)
		node.position = local
		_chassis.add_child(node)
		if t == "rocket":
			_launchers.append(local)

	# One simplified body collider from the non-wheel bounds.
	var body := BrickPart.design_aabb(design, true)
	if body.size.length() < 0.01:
		body = aabb
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = body.size * 0.96
	cs.shape = bs
	cs.position = (body.position + body.size * 0.5) - center
	add_child(cs)

	_driver = Minifig.build(0.7)
	_driver.position = Vector3(0, aabb.size.y * 0.5 - 0.7, -0.1)
	_chassis.add_child(_driver)

	# Wheels: use placed wheel parts if any, else auto 4 corners.
	if wheel_cells.is_empty():
		var hx := maxf(aabb.size.x * 0.5 - 0.3, 0.5)
		var hz := maxf(aabb.size.z * 0.5 - 0.2, 0.4)
		var by := -aabb.size.y * 0.5 + 0.1
		for wx in [hx, -hx]:
			for wz in [hz, -hz]:
				wheel_cells.append(Vector3(wx, by, wz))
	for wpos in wheel_cells:
		var ray := RayCast3D.new()
		ray.position = wpos
		ray.target_position = Vector3(0, -(suspension_rest + wheel_radius), 0)
		$Wheels.add_child(ray)

	if _launchers.is_empty():
		_launchers.append(Vector3(aabb.size.x * 0.5, aabb.size.y * 0.3, 0))


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


func _make_wheel_mesh(ray: RayCast3D) -> Node3D:
	# A realistic-looking wheel: dark rubber tire, a metallic hub with spokes,
	# and tread blocks around the rim so the rotation is clearly visible when
	# the car moves. The "spin" node is rotated about the axle each frame.
	var root := Node3D.new()
	ray.add_child(root)
	var spin := Node3D.new()
	root.add_child(spin)

	var width := 0.42
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.06, 0.06, 0.08)
	tire_mat.roughness = 0.95
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.78, 0.8, 0.86)
	rim_mat.metallic = 0.8
	rim_mat.roughness = 0.3

	# Tire (axle along Z = lateral).
	var tire := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = wheel_radius
	tc.bottom_radius = wheel_radius
	tc.height = width
	tc.radial_segments = 20
	tc.material = tire_mat
	tire.mesh = tc
	tire.rotation_degrees = Vector3(90, 0, 0)
	spin.add_child(tire)

	# Metallic hub poking out both faces.
	var hub := MeshInstance3D.new()
	var hcyl := CylinderMesh.new()
	hcyl.top_radius = wheel_radius * 0.5
	hcyl.bottom_radius = wheel_radius * 0.5
	hcyl.height = width + 0.05
	hcyl.radial_segments = 16
	hcyl.material = rim_mat
	hub.mesh = hcyl
	hub.rotation_degrees = Vector3(90, 0, 0)
	spin.add_child(hub)

	# Spokes on both outer faces.
	for i in 5:
		var ang := TAU * float(i) / 5.0
		for zside in [width * 0.5, -width * 0.5]:
			var spoke := MeshInstance3D.new()
			var sb := BoxMesh.new()
			sb.size = Vector3(wheel_radius * 0.92, 0.09, 0.05)
			spoke.mesh = sb
			spoke.material_override = rim_mat
			spoke.position = Vector3(cos(ang) * wheel_radius * 0.42, sin(ang) * wheel_radius * 0.42, zside)
			spoke.rotation = Vector3(0, 0, ang)
			spin.add_child(spoke)

	# Tread blocks around the circumference (makes rolling obvious).
	for i in 14:
		var ang := TAU * float(i) / 14.0
		var tread := MeshInstance3D.new()
		var tb := BoxMesh.new()
		tb.size = Vector3(0.14, 0.16, width * 0.96)
		tread.mesh = tb
		tread.material_override = tire_mat
		tread.position = Vector3(cos(ang) * (wheel_radius - 0.02), sin(ang) * (wheel_radius - 0.02), 0)
		tread.rotation = Vector3(0, 0, ang)
		spin.add_child(tread)

	_wheel_spins.append(spin)
	return root


func _setup_dust() -> void:
	_dust = CPUParticles3D.new()
	_dust.amount = int(24 * Mobile.particle_scale())
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

	_aim_turret(delta)

	# Regenerate health while not being hit (recover between firefights).
	_since_hit += delta
	if not _dead and _since_hit > regen_delay and health < max_health:
		health = minf(max_health, health + regen_rate * delta)
		damaged.emit(health / max_health)

	_fire_timer -= delta
	if controlled and not _dead and Input.is_action_pressed("fire") and _fire_timer <= 0.0:
		_fire_timer = fire_cooldown
		_shoot()

	_update_lean(delta)


func _build_launchers() -> void:
	# Rotatable rocket turret on the roof. The arrow keys yaw "_turret" and
	# elevate "_barrels"; missiles fly along the barrels' aim, independent of
	# which way the car is driving.
	_turret = Node3D.new()
	_turret.position = Vector3(0.0, _top_y + 0.18, 0.0)
	_chassis.add_child(_turret)

	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.7, 0.34, 0.9)
	base.mesh = base_mesh
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.22, 0.23, 0.28)
	base_mat.metallic = 0.4
	base.material_override = base_mat
	_turret.add_child(base)

	_barrels = Node3D.new()
	_barrels.position = Vector3(0.0, 0.12, 0.0)
	_turret.add_child(_barrels)

	for sz in [-0.28, 0.28]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 0.3, 0.3)
		mi.mesh = bm
		mi.position = Vector3(0.5, 0.0, sz)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.16, 0.16, 0.19)
		m.metallic = 0.5
		mi.material_override = m
		_barrels.add_child(mi)


func _aim_turret(delta: float) -> void:
	if controlled and not _dead:
		var ay := Input.get_axis("aim_right", "aim_left")
		var ap := Input.get_axis("aim_down", "aim_up")
		_turret_yaw += ay * turret_turn_speed * delta
		_turret_pitch = clampf(_turret_pitch + ap * turret_pitch_speed * delta, -0.1, 1.0)
	if _turret:
		_turret.rotation.y = _turret_yaw
	if _barrels:
		_barrels.rotation.z = _turret_pitch


func _shoot() -> void:
	if not _barrels:
		return
	var dir := _barrels.global_transform.basis.x
	for sz in [-0.28, 0.28]:
		var muzzle := _barrels.to_global(Vector3(1.15, 0.0, sz))
		var m := Missile.new()
		m.setup(dir, missile_damage)
		m.position = muzzle
		get_tree().current_scene.add_child(m)
	Sfx.play_shoot()


func take_damage(d: float) -> void:
	if _dead:
		return
	_since_hit = 0.0
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
	# Roll about the lateral axle (local Z) so the tread/spokes visibly turn.
	var amount := speed * delta / wheel_radius
	for s in _wheel_spins:
		s.rotate_z(-amount)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("destructible") and linear_velocity.length() > 6.0:
		Sfx.play_smash()
		# A crash costs a little health (it regenerates afterward).
		take_damage(5.0)
		if body is RigidBody3D:
			var dir := Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized()
			var impulse := dir * 6.0 + Vector3(0, 4.0, 0)
			body.call_deferred("apply_central_impulse", impulse)

	# A hard crash into anything solid shakes a few bricks loose (cosmetic) and
	# costs a little health that regenerates. Rate-limited so it doesn't spam.
	var hspeed := Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
	var solid := body is StaticBody3D or body is RigidBody3D
	if solid and hspeed > 9.0 and Time.get_ticks_msec() - _last_break_ms > 400:
		_last_break_ms = Time.get_ticks_msec()
		var d2 := Vector3(linear_velocity.x, 0.0, linear_velocity.z).normalized()
		Effects.brick_burst(get_parent(), global_position + d2 * 1.3 + Vector3(0, 0.4, 0), _body_color, 5, -d2 * 2.5)
		Sfx.play_smash()
		if not _dead:
			take_damage(4.0)

	if body.is_in_group("racer") and body is Node3D and linear_velocity.length() > 5.0:
		# Crash into a rival racer.
		var p: Vector3 = (global_position + (body as Node3D).global_position) * 0.5 + Vector3(0, 0.6, 0)
		Effects.explosion(get_parent(), p, 0.7, Color(1.0, 0.8, 0.3))


func _point_velocity(p: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(p - global_position)


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func add_boost() -> void:
	_boost_timer = 0.6
