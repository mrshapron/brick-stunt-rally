class_name ChaseCamera
extends Camera3D
## Side-biased chase camera for the 2.5D plane. Stays at a fixed Z, follows the
## car's X tightly and Y smoothly, and looks slightly ahead so the player can
## read upcoming ramps.

@export var target: Node3D
@export var offset: Vector3 = Vector3(2.0, 4.5, 22.0)
@export var look_ahead: Vector3 = Vector3(4.0, 1.0, 0.0)
@export var follow_speed: float = 6.0
@export var min_height: float = 3.5


func _ready() -> void:
	fov = 55.0
	current = true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var tp := target.global_position
	var desired := Vector3(tp.x + offset.x, maxf(tp.y + offset.y, min_height), tp.z + offset.z)
	var weight := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, weight)
	look_at(Vector3(tp.x + look_ahead.x, tp.y + look_ahead.y, tp.z), Vector3.UP)
