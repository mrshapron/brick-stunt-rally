class_name FlyCamera
extends Camera3D
## Third-person chase camera for the Aircraft: sits behind and above the craft
## along its heading and looks slightly ahead, smoothing position so banking
## turns feel cinematic.

@export var target: Node3D
@export var distance: float = 12.0
@export var height: float = 4.0
@export var look_ahead: float = 6.0
@export var follow_speed: float = 4.0


func _ready() -> void:
	fov = 64.0
	current = true
	if is_instance_valid(target):
		global_position = target.global_position + Vector3(0, height, distance)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	# Forward is the craft's -Z; keep the camera level (ignore roll) so the
	# horizon stays stable during banked turns.
	var fwd := -target.global_transform.basis.z
	fwd.y *= 0.6
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var desired := target.global_position - fwd * distance + Vector3(0, height, 0)
	var w := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, w)
	look_at(target.global_position + fwd * look_ahead, Vector3.UP)
