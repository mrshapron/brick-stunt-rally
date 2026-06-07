class_name Character
extends CharacterBody3D
## On-foot minifigure controller. Walks on the ground plane with the same
## directional input as the car, faces movement, with gravity so it stays
## grounded and falls off ledges.

@export var speed: float = 8.0
@export var gravity: float = 20.0
@export var jump_force: float = 10.0
@export var turn_speed: float = 14.0

var controlled: bool = true
var _model: Node3D
var _walk_t: float = 0.0
var _legs: Array = []
var _arms: Array = []


func _ready() -> void:
	add_to_group("player")
	_model = Minifig.build(1.0)
	add_child(_model)
	_legs = _model.get_meta("legs", [])
	_arms = _model.get_meta("arms", [])

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.3
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		if controlled and Input.is_action_just_pressed("fire"):
			velocity.y = jump_force
	else:
		velocity.y -= gravity * delta

	var ix := 0.0
	var iz := 0.0
	if controlled:
		ix = Input.get_axis("move_left", "move_right")
		iz = Input.get_axis("move_up", "move_down")
	var dir := Vector3(ix, 0, iz)
	if dir.length() > 1.0:
		dir = dir.normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	var moving := dir.length() > 0.05 and is_on_floor()
	if dir.length() > 0.05:
		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * delta, 0.0, 1.0))
	_animate_walk(moving, delta)


func _animate_walk(moving: bool, delta: float) -> void:
	if moving:
		_walk_t += delta * 9.0
		var s := sin(_walk_t)
		if _model:
			_model.position.y = absf(s) * 0.07
		if _legs.size() == 2:
			_legs[0].rotation.x = s * 0.7
			_legs[1].rotation.x = -s * 0.7
		if _arms.size() == 2:
			_arms[0].rotation.x = -s * 0.5
			_arms[1].rotation.x = s * 0.5
	else:
		var w := clampf(delta * 9.0, 0.0, 1.0)
		if _model:
			_model.position.y = lerpf(_model.position.y, 0.0, w)
		for limb in _legs + _arms:
			limb.rotation.x = lerp_angle(limb.rotation.x, 0.0, w)
