class_name Enemy
extends CharacterBody3D
## Enemy types:
##  - drone:  fast, low HP, rams the player (no gun)
##  - tank:   slow, high HP, chases and shoots
##  - turret: stationary, medium HP, shoots
##  - boss:   huge war machine - slow, tons of HP, aimed shots plus periodic
##            360-degree shell bursts you must weave between
## Each has a floating HP bar and explodes on death.

signal died

var type: String = "drone"
var hp: float = 22.0
var max_hp: float = 22.0
var speed: float = 12.0
var fire_rate: float = 0.0
var contact_damage: float = 16.0
var shot_damage: float = 10.0

var _player: Node3D
var _bar: HPBar
var _mat: StandardMaterial3D
var _cd: float = 0.0
var _burst_cd: float = 5.0
var _flash: float = 0.0
var _y: float = 1.5
var _dead: bool = false


func configure(p: Dictionary) -> void:
	type = p.get("type", "drone")
	add_to_group("enemy")
	var color := Color(1.0, 0.45, 0.2)
	var size := Vector3(1.8, 1.2, 1.8)
	match type:
		"tank":
			max_hp = 70.0
			speed = 4.5
			fire_rate = 2.0
			shot_damage = 14.0
			color = Color(0.36, 0.49, 0.23)
			size = Vector3(3.2, 1.8, 2.6)
		"turret":
			max_hp = 45.0
			speed = 0.0
			fire_rate = 1.2
			shot_damage = 11.0
			color = Color(0.54, 0.56, 0.62)
			size = Vector3(2.4, 2.2, 2.4)
		"boss":
			max_hp = 320.0
			speed = 3.0
			fire_rate = 1.6
			shot_damage = 13.0
			color = Color(0.3, 0.32, 0.26)
			size = Vector3(6.0, 3.2, 5.0)
		_:
			type = "drone"
			max_hp = 22.0
			speed = 12.0
			fire_rate = 0.0
			contact_damage = 16.0
			color = Color(1.0, 0.35, 0.22)
			size = Vector3(1.8, 1.2, 1.8)
	max_hp *= float(p.get("hp_mult", 1.0))
	hp = max_hp
	_build(size, color)

	_bar = HPBar.new()
	add_child(_bar)
	_bar.position = Vector3(0, size.y + 1.3, 0)


func _build(size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = Vector3(0, size.y * 0.5, 0)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.roughness = 0.5
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.2
	mi.material_override = _mat
	add_child(mi)

	var top := MeshInstance3D.new()
	var tb := BoxMesh.new()
	if type == "drone":
		tb.size = Vector3(size.x * 1.4, 0.16, 0.4)
	else:
		tb.size = Vector3(size.x * 0.9, 0.4, 0.4)
	top.mesh = tb
	top.position = Vector3(size.x * 0.4, size.y * 0.85, 0)
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.12, 0.12, 0.14)
	top.material_override = tm
	add_child(top)

	if type == "boss":
		# Menacing extras: armored top turret, twin barrels and a glowing core.
		var turret := MeshInstance3D.new()
		var trb := BoxMesh.new()
		trb.size = Vector3(2.6, 1.4, 2.2)
		turret.mesh = trb
		turret.position = Vector3(0, size.y + 0.7, 0)
		turret.material_override = _mat
		add_child(turret)
		for bz in [-0.5, 0.5]:
			var barrel_mi := MeshInstance3D.new()
			var bbm := BoxMesh.new()
			bbm.size = Vector3(3.0, 0.4, 0.4)
			barrel_mi.mesh = bbm
			barrel_mi.position = Vector3(2.4, size.y + 0.7, bz)
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.1, 0.1, 0.12)
			barrel_mi.material_override = bmat
			add_child(barrel_mi)
		var core := MeshInstance3D.new()
		var cbm := BoxMesh.new()
		cbm.size = Vector3(1.2, 1.2, 1.2)
		core.mesh = cbm
		core.position = Vector3(0, size.y * 0.5, 0)
		core.rotation_degrees = Vector3(45, 0, 45)
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(1.0, 0.25, 0.1)
		cmat.emission_enabled = true
		cmat.emission = Color(1.0, 0.25, 0.1)
		cmat.emission_energy_multiplier = 2.0
		core.material_override = cmat
		add_child(core)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	add_child(cs)


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")
	_y = global_position.y


func _physics_process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		_mat.emission_energy_multiplier = 3.0 if _flash > 0.0 else 0.2

	if not is_instance_valid(_player):
		return

	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.001 else Vector3.ZERO

	if type == "drone":
		if dist > 2.6:
			global_position += dir * speed * delta
		elif _player.has_method("take_damage"):
			_player.take_damage(contact_damage)
			die()
			return
	elif type == "tank":
		if dist > 12.0:
			global_position += dir * speed * delta
		_try_fire(delta, dir)
	elif type == "boss":
		if dist > 16.0:
			global_position += dir * speed * delta
		_try_fire(delta, dir)
		# Periodic 360-degree shell burst: a ring of shots to weave between.
		_burst_cd -= delta
		if _burst_cd <= 0.0:
			_burst_cd = 4.5
			for k in 10:
				var a := TAU * float(k) / 10.0
				_spawn_shot(Vector3(cos(a), 0, sin(a)), shot_damage * 0.8, 14.0)
			Sfx.play_explosion()
	else:
		_try_fire(delta, dir)

	global_position.y = _y
	if dir != Vector3.ZERO:
		rotation.y = atan2(dir.x, dir.z)
	if _bar:
		_bar.set_ratio(hp / max_hp)


func _try_fire(delta: float, dir: Vector3) -> void:
	if fire_rate <= 0.0:
		return
	_cd -= delta
	if _cd <= 0.0:
		_cd = fire_rate
		_spawn_shot(dir, shot_damage, 24.0)
		Sfx.play_shoot()


func _spawn_shot(dir: Vector3, dmg: float, speed_v: float) -> void:
	var s := EnemyShot.new()
	s.setup(dir, dmg, speed_v)
	s.position = global_position + Vector3(0, 1.6, 0) + dir * (3.2 if type == "boss" else 2.2)
	get_tree().current_scene.add_child(s)


func take_damage(d: float) -> void:
	if _dead:
		return
	hp -= d
	_flash = 0.08
	Sfx.play_hit()
	Effects.damage_number(get_parent(), global_position + Vector3(0, 2.0, 0), d)
	if hp <= 0.0:
		die()


func die() -> void:
	if _dead:
		return
	_dead = true
	var boom := 3.0 if type == "boss" else 1.4
	Effects.explosion(get_parent(), global_position + Vector3(0, 1, 0), boom, Color(1.0, 0.55, 0.12))
	died.emit()
	queue_free()
