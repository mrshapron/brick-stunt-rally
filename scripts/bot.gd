class_name Bot
extends RigidBody3D
## AI race opponent: a real physics car. An AI steering controller drives it
## along the track with forces, so it collides and gets shoved around by the
## player and other cars just like a real vehicle. Has HP + a health bar and can
## be destroyed with rockets.

const ACCEL: float = 12.0
const TURN: float = 6.0
const LOOKAHEAD: float = 2.5

var speed: float = 16.0
var finished: bool = false
var max_health: float = 60.0
var health: float = 60.0

var _track: RaceTrack
var _s: float = 0.0
var _lane: float = 0.0
var _wobble: float = 0.0
var _wheels: Array = []
var _can_shoot: bool = false
var _cd: float = 0.0
var _player: Node3D
var _hpbar: HPBar
var _dead: bool = false


func configure(track: RaceTrack, spd: float, car_index: int, lane: float, can_shoot: bool, start_s: float = 0.0) -> void:
	_track = track
	speed = spd
	_lane = lane
	_s = start_s
	_wobble = randf() * TAU
	_can_shoot = can_shoot
	_cd = randf_range(1.5, 3.0)
	add_to_group("racer")

	mass = 3.0
	gravity_scale = 1.0
	# Stay upright but slide/get pushed freely on the ground plane.
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	angular_damp = 6.0
	linear_damp = 0.6
	can_sleep = false

	var disp := CarLib.build_display(CarLib.design(car_index))
	add_child(disp)
	_wheels = disp.get_meta("wheels", [])

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.0, 1.4, 2.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)

	_hpbar = HPBar.new()
	_hpbar.width = 1.9
	add_child(_hpbar)
	_hpbar.position = Vector3(0, 2.1, 0)
	_hpbar.set_ratio(1.0)

	# Drop in at the start position, facing down the track.
	var sp: Vector2 = _track.sample_pos(_s)
	var d0: Vector2 = _track.sample_dir(_s)
	var w: Vector2 = sp + _track.perp(d0) * _lane
	global_position = Vector3(w.x, 0.6, w.y)
	rotation = Vector3(0, atan2(-d0.y, d0.x), 0)


func progress() -> float:
	return _s


func take_damage(d: float) -> void:
	if _dead:
		return
	health = maxf(0.0, health - d)
	if _hpbar:
		_hpbar.set_ratio(health / max_health)
	Sfx.play_hit()
	if health <= 0.0:
		_die()


func _die() -> void:
	if _dead:
		return
	_dead = true
	finished = true
	Effects.explosion(get_parent(), global_position + Vector3(0, 0.6, 0), 1.5)
	queue_free()


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _track == null or _dead:
		return
	if not finished:
		_s += speed * delta

	var hv := Vector3(linear_velocity.x, 0.0, linear_velocity.z)

	if not finished:
		# Seek a point a little ahead on the track at our lane offset, steering
		# toward it with force so collisions can shove us off and we recover.
		var aim_s := _s + LOOKAHEAD
		var tp: Vector2 = _track.sample_pos(aim_s)
		var perp: Vector2 = _track.perp(_track.sample_dir(aim_s))
		var lane := _lane + sin(_s * 0.05 + _wobble) * 0.5
		var target: Vector2 = tp + perp * lane
		var to := Vector3(target.x - global_position.x, 0.0, target.y - global_position.z)
		var desired := to.normalized() * speed if to.length() > 0.2 else Vector3.ZERO
		apply_central_force((desired - hv) * ACCEL * mass)

		var head := hv if hv.length() > 1.5 else to
		if head.length() > 0.1:
			var ty := atan2(-head.z, head.x)
			var dy := wrapf(ty - rotation.y, -PI, PI)
			angular_velocity = Vector3(0, dy * TURN, 0)
	else:
		apply_central_force(-hv * 2.0 * mass)

	var spd := hv.length()
	for wheel in _wheels:
		wheel.rotate_z(-spd * delta / 0.34)

	if _can_shoot and not finished and is_instance_valid(_player):
		_cd -= delta
		if _cd <= 0.0:
			_cd = 2.6
			var aim := _player.global_position - global_position
			aim.y = 0.0
			if aim.length() > 1.0:
				_fire(aim.normalized())

	if not finished and _s >= _track.length * float(_track.laps):
		finished = true


func _fire(dir: Vector3) -> void:
	var s := EnemyShot.new()
	s.setup(dir, 8.0, 26.0)
	s.position = global_position + Vector3(0, 1.1, 0) + dir * 2.2
	get_tree().current_scene.add_child(s)
	Sfx.play_shoot()
