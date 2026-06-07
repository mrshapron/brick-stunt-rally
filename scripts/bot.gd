class_name Bot
extends AnimatableBody3D
## AI race opponent. Kinematic body (so it collides with and bumps the player),
## drives the track to the finish, spins its wheels, and on advanced races fires
## rockets at the player.

var speed: float = 16.0
var finished: bool = false
var _finish_x: float = 100.0
var _wobble: float = 0.0
var _lane_z: float = 0.0
var _wheels: Array = []
var _can_shoot: bool = false
var _cd: float = 0.0
var _player: Node3D


func configure(spd: float, finish_x: float, car_index: int, lane_z: float, can_shoot: bool) -> void:
	sync_to_physics = true
	speed = spd
	_finish_x = finish_x
	_lane_z = lane_z
	_wobble = randf() * TAU
	_can_shoot = can_shoot
	_cd = randf_range(1.5, 3.0)
	add_to_group("racer")
	position = Vector3(0, 0.0, lane_z)

	var disp := CarLib.build_display(CarLib.design(car_index))
	add_child(disp)
	_wheels = disp.get_meta("wheels", [])

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 1.4, 2.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	var v := 0.0 if finished else speed
	position.x += v * delta
	position.z = _lane_z + sin(position.x * 0.05 + _wobble) * 1.2
	position.y = sin(position.x * 0.6 + _wobble) * 0.04
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, v * delta / 0.34)

	# Keep cars from overlapping: if the player is on top of us, shove it out
	# sideways (a racing jostle) so they never merge.
	if is_instance_valid(_player):
		var d := _player.global_position - global_position
		if absf(d.x) < 3.0 and absf(d.z) < 2.6 and _player.has_method("apply_central_impulse"):
			var pushz := 1.0 if d.z >= 0.0 else -1.0
			_player.apply_central_impulse(Vector3(0.0, 0.0, pushz) * 5.0)

	if _can_shoot and not finished and is_instance_valid(_player):
		_cd -= delta
		if _cd <= 0.0:
			_cd = 2.6
			var to := _player.global_position - global_position
			to.y = 0.0
			if to.length() > 1.0:
				_fire(to.normalized())

	if not finished and position.x >= _finish_x:
		finished = true


func _fire(dir: Vector3) -> void:
	var s := EnemyShot.new()
	s.setup(dir, 8.0, 26.0)
	s.position = global_position + Vector3(0, 1.1, 0) + dir * 2.2
	get_tree().current_scene.add_child(s)
	Sfx.play_shoot()
