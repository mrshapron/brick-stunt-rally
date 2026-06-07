class_name EnemyShot
extends Area3D
## Enemy projectile. Damages the player on contact, explodes on any solid hit,
## ignores other enemies.

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var _life: float = 4.0


func setup(dir: Vector3, dmg: float, speed: float = 24.0) -> void:
	damage = dmg
	velocity = dir.normalized() * speed


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.4
	cs.shape = sp
	add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.4, 0.4)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.25, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.2, 0.1)
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	add_child(mi)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy") or body.is_in_group("racer"):
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
	Effects.explosion(get_parent(), global_position, 0.6, Color(1.0, 0.3, 0.15))
	queue_free()
