class_name Bot
extends Node3D
## A simple AI racer: drives straight down the track toward the finish at a set
## speed (with a little wobble), then stops when it crosses the line.

var speed: float = 16.0
var finished: bool = false
var _finish_x: float = 100.0
var _wobble: float = 0.0
var _lane_z: float = 0.0


func configure(spd: float, finish_x: float, car_index: int, lane_z: float) -> void:
	speed = spd
	_finish_x = finish_x
	_lane_z = lane_z
	_wobble = randf() * TAU
	position = Vector3(0, 0.7, lane_z)
	var disp := CarLib.build_display(CarLib.design(car_index))
	disp.position = Vector3(0, 0.7, 0)
	add_child(disp)


func _physics_process(delta: float) -> void:
	if finished:
		return
	position.x += speed * delta
	position.z = _lane_z + sin(position.x * 0.05 + _wobble) * 1.2
	if position.x >= _finish_x:
		finished = true
