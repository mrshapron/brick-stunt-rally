class_name Missile
extends Area3D
## Player rocket: a rocket-shaped projectile with a fiery exhaust trail and a
## glow that flies straight, damages enemies on contact, and explodes on any hit
## (ignores the player who fired it).

## Gentle homing: within HOME_RANGE the rocket curves toward the nearest enemy
## (a light "magnet", not a perfect lock) so near-misses still connect.
const HOME_RANGE: float = 18.0
const HOME_STRENGTH: float = 2.6

var velocity: Vector3 = Vector3.ZERO
var damage: float = 34.0
var _life: float = 3.0


func setup(dir: Vector3, dmg: float) -> void:
	damage = dmg
	velocity = dir.normalized() * 48.0


func _ready() -> void:
	# Point the rocket's +X (nose) along the full 3D travel direction, so it
	# tilts up/down with the turret aim instead of staying flat.
	_orient()

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.5
	cs.shape = sp
	add_child(cs)

	_build_rocket()
	body_entered.connect(_on_body_entered)


func _build_rocket() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.85, 0.86, 0.9)
	metal.metallic = 0.5
	metal.roughness = 0.4

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 0.9
	cyl.radial_segments = 10
	body.mesh = cyl
	body.rotation_degrees = Vector3(0, 0, 90)
	body.material_override = metal
	add_child(body)

	var nose := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.45
	cone.radial_segments = 10
	nose.mesh = cone
	nose.rotation_degrees = Vector3(0, 0, -90)
	nose.position = Vector3(0.65, 0, 0)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.9, 0.18, 0.15)
	nose_mat.emission_enabled = true
	nose_mat.emission = Color(0.9, 0.1, 0.1)
	nose_mat.emission_energy_multiplier = 0.4
	nose.material_override = nose_mat
	add_child(nose)

	for ang in [0.0, 90.0]:
		var fin := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.35, 0.5, 0.06)
		fin.mesh = fb
		fin.position = Vector3(-0.4, 0, 0)
		fin.rotation_degrees = Vector3(ang, 0, 0)
		fin.material_override = metal
		add_child(fin)

	# Fiery exhaust trail (stays in world so it streaks behind the rocket).
	var fire := CPUParticles3D.new()
	fire.position = Vector3(-0.55, 0, 0)
	fire.local_coords = false
	fire.amount = 26
	fire.lifetime = 0.28
	fire.direction = Vector3(-1, 0, 0)
	fire.spread = 14.0
	fire.initial_velocity_min = 6.0
	fire.initial_velocity_max = 12.0
	fire.gravity = Vector3.ZERO
	fire.scale_amount_min = 0.25
	fire.scale_amount_max = 0.7
	fire.color = Color(1.0, 0.65, 0.15)
	var fm := BoxMesh.new()
	fm.size = Vector3(0.4, 0.4, 0.4)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(1.0, 0.6, 0.1)
	fmat.emission_enabled = true
	fmat.emission = Color(1.0, 0.55, 0.1)
	fmat.emission_energy_multiplier = 2.5
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.material = fmat
	fire.mesh = fm
	add_child(fire)

	if Mobile.explosion_light():
		var glow := OmniLight3D.new()
		glow.position = Vector3(-0.4, 0, 0)
		glow.omni_range = 5.0
		glow.light_energy = 2.5
		glow.light_color = Color(1.0, 0.6, 0.2)
		add_child(glow)


func _physics_process(delta: float) -> void:
	var target := _nearest_enemy()
	if target != null:
		var want := (target.global_position - global_position)
		want.y *= 0.6
		if want.length() > 0.5:
			var cur := velocity.normalized()
			var wdir := want.normalized()
			# Only magnetise toward enemies roughly ahead (no U-turns).
			if cur.dot(wdir) > -0.15:
				var blended := (cur + (wdir - cur) * clampf(HOME_STRENGTH * delta, 0.0, 1.0)).normalized()
				velocity = blended * velocity.length()
				_orient()
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := HOME_RANGE * HOME_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not is_instance_valid(e):
			continue
		var d := global_position.distance_squared_to((e as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _orient() -> void:
	if velocity.length() <= 0.01:
		return
	var x := velocity.normalized()
	var ref := Vector3.UP
	if absf(x.dot(ref)) > 0.999:
		ref = Vector3.RIGHT
	var z := x.cross(ref).normalized()
	var y := z.cross(x).normalized()
	global_transform.basis = Basis(x, y, z)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		return
	Effects.explosion(get_parent(), global_position, 1.8)
	Effects.blast(get_parent(), global_position, 6.0, damage, 16.0)
	queue_free()
