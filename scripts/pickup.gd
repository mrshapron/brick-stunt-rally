class_name Pickup
extends Area3D
## Floating collectible crate: drive through it to grab it.
##   kind = "health"  ->  +35 HP (green cross)
##   kind = "money"   ->  +$25  (gold coin)

var kind: String = "health"

var _spin: Node3D
var _t: float = 0.0
var _base_y: float = 0.0


func configure(k: String) -> void:
	kind = k


func _ready() -> void:
	_base_y = position.y

	var color := Color("#39d65a") if kind == "health" else Color("#ffd24a")
	_spin = Node3D.new()
	add_child(_spin)

	var crate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 1.3, 1.3)
	crate.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color, 0.85)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crate.material_override = m
	_spin.add_child(crate)

	var icon_mat := StandardMaterial3D.new()
	icon_mat.albedo_color = Color(1, 1, 1)
	icon_mat.emission_enabled = true
	icon_mat.emission = Color(1, 1, 1)
	icon_mat.emission_energy_multiplier = 1.2
	if kind == "health":
		for s in [Vector3(0.9, 0.3, 0.2), Vector3(0.3, 0.9, 0.2)]:
			var bar := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = s
			bar.mesh = bb
			bar.position = Vector3(0, 0, 0.68)
			bar.material_override = icon_mat
			_spin.add_child(bar)
	else:
		var coin := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.4
		cyl.bottom_radius = 0.4
		cyl.height = 0.14
		coin.mesh = cyl
		coin.rotation_degrees = Vector3(90, 0, 0)
		coin.position = Vector3(0, 0, 0.68)
		coin.material_override = icon_mat
		_spin.add_child(coin)

	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.6
	cs.shape = shape
	add_child(cs)

	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	if _spin:
		_spin.rotation.y += delta * 2.2
	position.y = _base_y + sin(_t * 2.4) * 0.3


func _on_body(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if kind == "health":
		if body.has_method("heal"):
			body.heal(35.0)
	else:
		GameState.add_money(25)
	Sfx.play_checkpoint()
	Effects.explosion(get_parent(), global_position, 0.5, Color("#39d65a") if kind == "health" else Color("#ffd24a"))
	queue_free()
