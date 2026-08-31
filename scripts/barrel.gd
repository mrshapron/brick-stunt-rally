class_name Barrel
extends StaticBody3D
## Explosive barrel: shoot it (or drive into it) and it goes up in a big blast
## that damages nearby enemies and sets off other barrels in a chain reaction.
## In the "enemy" group so rocket blasts hit it, but it does NOT count toward
## the mission's enemy total.

const RADIUS := 7.0
const DAMAGE := 45.0
const PLAYER_DAMAGE := 14.0
const FORCE := 26.0

var _exploded: bool = false


func _ready() -> void:
	add_to_group("enemy")

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("#c23327")
	body_mat.roughness = 0.45
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color("#f2c94c")
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color("#f2c94c")
	stripe_mat.emission_energy_multiplier = 0.5

	var drum := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.75
	cyl.bottom_radius = 0.75
	cyl.height = 1.7
	cyl.radial_segments = 10
	drum.mesh = cyl
	drum.position = Vector3(0, 0.85, 0)
	drum.material_override = body_mat
	add_child(drum)

	var stripe := MeshInstance3D.new()
	var scyl := CylinderMesh.new()
	scyl.top_radius = 0.78
	scyl.bottom_radius = 0.78
	scyl.height = 0.3
	scyl.radial_segments = 10
	stripe.mesh = scyl
	stripe.position = Vector3(0, 0.85, 0)
	stripe.material_override = stripe_mat
	add_child(stripe)

	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.78
	shape.height = 1.7
	cs.shape = shape
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)

	# Touch trigger: ramming the barrel with the car sets it off too.
	var trigger := Area3D.new()
	var tcs := CollisionShape3D.new()
	var tshape := CylinderShape3D.new()
	tshape.radius = 1.3
	tshape.height = 2.0
	tcs.shape = tshape
	tcs.position = Vector3(0, 1.0, 0)
	trigger.add_child(tcs)
	trigger.body_entered.connect(_on_touched)
	add_child(trigger)


func _on_touched(body: Node) -> void:
	if body.is_in_group("player"):
		explode()


func take_damage(_d: float) -> void:
	explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var host := get_parent()
	var pos := global_position + Vector3(0, 1.0, 0)
	Effects.explosion(host, pos, 1.6, Color(1.0, 0.55, 0.12))
	# Chain to enemies + other barrels (blast skips the player on its own)...
	if host is Node3D:
		Effects.blast(host, pos, RADIUS, DAMAGE, FORCE)
	# ...but standing right next to an exploding barrel should still sting.
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D and player.has_method("take_damage"):
		var d := (player as Node3D).global_position.distance_to(pos)
		if d < RADIUS * 0.7:
			player.take_damage(PLAYER_DAMAGE * clampf(1.0 - d / RADIUS, 0.3, 1.0))
	queue_free()
