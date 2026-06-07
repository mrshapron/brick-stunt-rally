class_name Bot
extends AnimatableBody3D
## AI race opponent. Kinematic body (so it collides with and bumps the player),
## drives the track to the finish, spins its wheels, and on advanced races fires
## rockets at the player.

const LANE_STIFF: float = 7.0
const LANE_DAMP: float = 5.6

var speed: float = 16.0
var finished: bool = false
var _track: RaceTrack
var _s: float = 0.0
var _lane: float = 0.0
var _wobble: float = 0.0
var _wheels: Array = []
var _can_shoot: bool = false
var _cd: float = 0.0
var _player: Node3D
# Reactive jostling: lateral offset from the lane + its velocity, a temporary
# speed multiplier (dips on contact, recovers), and how aggressively this bot
# leans into rivals to disturb them.
var _z_off: float = 0.0
var _z_vel: float = 0.0
var _spd_mod: float = 1.0
var _aggr: float = 0.6


func configure(track: RaceTrack, spd: float, car_index: int, lane: float, can_shoot: bool, start_s: float = 0.0) -> void:
	# Must be false: when true the physics server owns the transform and our
	# direct position writes get discarded (all bots would snap back to origin).
	sync_to_physics = false
	_track = track
	speed = spd
	_lane = lane
	_s = start_s
	_wobble = randf() * TAU
	_can_shoot = can_shoot
	_cd = randf_range(1.5, 3.0)
	_aggr = randf_range(0.35, 1.0)
	add_to_group("racer")

	var disp := CarLib.build_display(CarLib.design(car_index))
	add_child(disp)
	_wheels = disp.get_meta("wheels", [])

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.0, 1.4, 2.2)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	_place()


func progress() -> float:
	return _s


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")


func _place() -> void:
	if _track == null:
		return
	var pos: Vector2 = _track.sample_pos(_s)
	var dir: Vector2 = _track.sample_dir(_s)
	var lateral: float = _lane + _z_off
	var w: Vector2 = pos + _track.perp(dir) * lateral
	position = Vector3(w.x, 0.0, w.y)
	rotation.y = atan2(-dir.y, dir.x)


func _physics_process(delta: float) -> void:
	if _track == null:
		return
	var v := 0.0 if finished else speed * _spd_mod
	_s += v * delta
	_spd_mod = move_toward(_spd_mod, 1.0, delta * 1.5)

	var dir: Vector2 = _track.sample_dir(_s)
	var perp: Vector2 = _track.perp(dir)
	var me := Vector2(global_position.x, global_position.z)

	# Lateral "jostle" model in track space (forward = along path, lat = perp):
	# a spring holds the lane, contact shoves sideways, and aggressive bots lean
	# into a rival just ahead-and-beside to disturb its line.
	var acc := -_z_off * LANE_STIFF - _z_vel * LANE_DAMP

	if is_instance_valid(_player):
		var rel := Vector2(_player.global_position.x, _player.global_position.z) - me
		var fwd := rel.dot(dir)
		var lat := rel.dot(perp)
		if absf(fwd) < 3.4 and absf(lat) < 3.0:
			acc += (-signf(lat) if absf(lat) > 0.05 else 1.0) * 26.0
			_spd_mod = minf(_spd_mod, 0.85)
			if _player.has_method("apply_central_impulse"):
				var pd := Vector3(rel.x, 0.0, rel.y)
				if pd.length() < 0.1:
					pd = Vector3(0, 0, 1)
				_player.apply_central_impulse(pd.normalized() * 5.5)

	for r in get_tree().get_nodes_in_group("racer"):
		if r == self or not (r is Node3D):
			continue
		var rel2 := Vector2((r as Node3D).global_position.x, (r as Node3D).global_position.z) - me
		var fwd2 := rel2.dot(dir)
		var lat2 := rel2.dot(perp)
		if absf(fwd2) > 4.2 or absf(lat2) > 4.5:
			continue
		if absf(lat2) < 1.9:
			# Bump sideways only - no speed penalty, so packs don't "accordion"
			# (bots kept slowing each other and falling back every few seconds).
			acc += (-signf(lat2) if absf(lat2) > 0.05 else 1.0) * 30.0
		elif fwd2 > 0.2 and fwd2 < 3.2:
			acc += signf(lat2) * 15.0 * _aggr

	_z_vel = clampf(_z_vel + acc * delta, -11.0, 11.0)
	_z_off += _z_vel * delta
	var bound := _track.width * 0.5 - 1.5
	var lane_lo := -bound - _lane
	var lane_hi := bound - _lane
	if _z_off < lane_lo:
		_z_off = lane_lo
		_z_vel = 0.0
	elif _z_off > lane_hi:
		_z_off = lane_hi
		_z_vel = 0.0

	var pos: Vector2 = _track.sample_pos(_s)
	var weave := sin(_s * 0.05 + _wobble) * 1.0
	var lateral: float = _lane + weave + _z_off
	var w: Vector2 = pos + perp * lateral
	position = Vector3(w.x, sin(_s * 0.6 + _wobble) * 0.04, w.y)
	rotation.y = atan2(-dir.y, dir.x)
	for wheel in _wheels:
		wheel.rotate_object_local(Vector3.UP, v * delta / 0.34)

	if _can_shoot and not finished and is_instance_valid(_player):
		_cd -= delta
		if _cd <= 0.0:
			_cd = 2.6
			var to := _player.global_position - global_position
			to.y = 0.0
			if to.length() > 1.0:
				_fire(to.normalized())

	if not finished and _s >= _track.length * float(_track.laps):
		finished = true


func _fire(dir: Vector3) -> void:
	var s := EnemyShot.new()
	s.setup(dir, 8.0, 26.0)
	s.position = global_position + Vector3(0, 1.1, 0) + dir * 2.2
	get_tree().current_scene.add_child(s)
	Sfx.play_shoot()
