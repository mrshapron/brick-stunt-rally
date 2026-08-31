class_name Aircraft
extends Node3D
## Arcade flyer used in the Aero World. One controller for two kinds:
##   - "plane": fast, wide turns, must keep a minimum cruise speed
##   - "heli":  slower, very agile, can almost hover
## Controls (keyboard or the left touch joystick): steer with the stick
##   - up/down  -> pitch (climb / dive)
##   - left/right -> turn (with a visual bank)
## Hold FIRE / Space to BOOST. Built from bricks, no external assets. The model
## faces -Z (Godot forward); rotor/propeller spin every frame.

var kind: String = "plane"
var controlled: bool = true
var speed: float = 0.0

# Tuned per kind in configure().
var cruise: float = 30.0
var min_speed: float = 12.0
var boost_mul: float = 1.6
var yaw_rate: float = 1.4
var max_pitch: float = 0.55
var max_bank: float = 0.6
var turn_assist: float = 1.0

var _yaw: float = 0.0
var _pitch: float = 0.0
var _bank: float = 0.0
var _vel: Vector3 = Vector3.ZERO
var _rotor: Node3D
var _prop: Node3D
var _spin: float = 0.0


func configure(k: String, base: Color = Color("#d23b2e"), accent: Color = Color("#eaeaea")) -> void:
	kind = k
	if kind == "heli":
		cruise = 17.0
		min_speed = 0.0
		boost_mul = 1.8
		yaw_rate = 1.9
		max_pitch = 0.7
		max_bank = 0.45
	else:
		cruise = 32.0
		min_speed = 14.0
		boost_mul = 1.6
		yaw_rate = 1.25
		max_pitch = 0.5
		max_bank = 0.7
	speed = cruise
	add_to_group("player")
	add_to_group("aircraft")
	_build(base, accent)


func reset_to(pos: Vector3, yaw: float) -> void:
	global_position = pos
	_yaw = yaw
	_pitch = 0.0
	_bank = 0.0
	speed = cruise
	_vel = Vector3.ZERO
	_apply_orientation()


func get_speed() -> float:
	return speed


func get_altitude() -> float:
	return global_position.y


func _ready() -> void:
	_apply_orientation()


func _physics_process(delta: float) -> void:
	_spin += delta
	if is_instance_valid(_rotor):
		_rotor.rotate_y(delta * 26.0)
	if is_instance_valid(_prop):
		_prop.rotate_z(delta * 40.0)

	if not controlled:
		return

	# Inverted axes: pull "down" to climb and "left" to bank right (classic
	# flight-stick feel), matching how the plane reads on screen.
	var yaw_in := Input.get_axis("move_right", "move_left")
	var pitch_in := Input.get_axis("move_up", "move_down")
	var boosting := Input.is_action_pressed("fire")

	_yaw += yaw_in * yaw_rate * delta
	var tp := pitch_in * max_pitch
	_pitch = lerpf(_pitch, tp, clampf(delta * 3.0, 0.0, 1.0))
	var tb := -yaw_in * max_bank
	_bank = lerpf(_bank, tb, clampf(delta * 4.0, 0.0, 1.0))

	var target_speed := cruise * (boost_mul if boosting else 1.0)
	speed = lerpf(speed, target_speed, clampf(delta * 1.5, 0.0, 1.0))

	var ch := cos(_pitch)
	var forward := Vector3(-sin(_yaw) * ch, sin(_pitch), -cos(_yaw) * ch)
	_vel = forward * speed
	global_position += _vel * delta

	_apply_orientation(forward)


func _apply_orientation(forward: Vector3 = Vector3.INF) -> void:
	if forward == Vector3.INF:
		var ch := cos(_pitch)
		forward = Vector3(-sin(_yaw) * ch, sin(_pitch), -cos(_yaw) * ch)
	if forward.length() < 0.001:
		return
	look_at(global_position + forward, Vector3.UP)
	rotate_object_local(Vector3(0, 0, 1), _bank)


# --- model building ---

func _build(base: Color, accent: Color) -> void:
	if kind == "heli":
		_build_heli(base, accent)
	else:
		_build_plane(base, accent)


func _build_plane(base: Color, accent: Color) -> void:
	# Fuselage (long, nose toward -Z).
	_box(self, Vector3(1.2, 1.1, 5.0), Vector3(0, 0, 0), base, 0.4)
	# Cockpit canopy.
	_box(self, Vector3(0.9, 0.7, 1.6), Vector3(0, 0.7, -0.6), Color(0.3, 0.5, 0.7), 0.2)
	# Nose cone.
	_box(self, Vector3(0.9, 0.9, 0.8), Vector3(0, 0, -2.7), accent.darkened(0.1), 0.3)
	# Main wings.
	_box(self, Vector3(8.6, 0.28, 1.7), Vector3(0, -0.1, 0.1), accent, 0.4)
	# Wing tips (accent stripes).
	_box(self, Vector3(0.7, 0.34, 1.7), Vector3(4.3, -0.1, 0.1), base.darkened(0.15), 0.4)
	_box(self, Vector3(0.7, 0.34, 1.7), Vector3(-4.3, -0.1, 0.1), base.darkened(0.15), 0.4)
	# Tailplane (horizontal stabiliser) + vertical fin at the back (+Z).
	_box(self, Vector3(3.4, 0.24, 1.1), Vector3(0, 0.1, 2.2), accent, 0.4)
	_box(self, Vector3(0.28, 1.4, 1.2), Vector3(0, 0.7, 2.3), base, 0.4)
	# Propeller at the nose, spins about Z.
	_prop = Node3D.new()
	_prop.position = Vector3(0, 0, -3.15)
	add_child(_prop)
	_box(_prop, Vector3(0.4, 0.4, 0.3), Vector3.ZERO, Color(0.1, 0.1, 0.12), 0.3)
	_box(_prop, Vector3(0.2, 4.0, 0.12), Vector3.ZERO, Color(0.08, 0.08, 0.1), 0.3)
	_box(_prop, Vector3(4.0, 0.2, 0.12), Vector3.ZERO, Color(0.08, 0.08, 0.1), 0.3)


func _build_heli(base: Color, accent: Color) -> void:
	# Rounded cabin (nose toward -Z) + glass front.
	_box(self, Vector3(1.8, 1.6, 3.2), Vector3(0, 0, -0.2), base, 0.4)
	_box(self, Vector3(1.5, 1.1, 1.2), Vector3(0, 0.15, -1.5), Color(0.3, 0.5, 0.7), 0.2)
	# Tail boom (extends back, +Z) + tail fin.
	_box(self, Vector3(0.5, 0.5, 3.4), Vector3(0, 0.4, 2.6), base.darkened(0.1), 0.5)
	_box(self, Vector3(0.22, 1.2, 0.9), Vector3(0, 0.9, 4.1), accent, 0.5)
	# Landing skids.
	for sx in [-0.8, 0.8]:
		_box(self, Vector3(0.16, 0.16, 2.6), Vector3(sx, -1.05, 0), Color(0.12, 0.12, 0.14), 0.5)
		_box(self, Vector3(0.16, 0.5, 0.16), Vector3(sx, -0.8, -0.8), Color(0.12, 0.12, 0.14), 0.5)
		_box(self, Vector3(0.16, 0.5, 0.16), Vector3(sx, -0.8, 0.8), Color(0.12, 0.12, 0.14), 0.5)
	# Main rotor on a mast, spins about Y.
	_box(self, Vector3(0.3, 0.5, 0.3), Vector3(0, 1.0, 0), Color(0.15, 0.15, 0.18), 0.4)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, 1.3, 0)
	add_child(_rotor)
	_box(_rotor, Vector3(0.4, 0.16, 0.4), Vector3.ZERO, Color(0.1, 0.1, 0.12), 0.4)
	_box(_rotor, Vector3(8.4, 0.1, 0.4), Vector3.ZERO, Color(0.07, 0.07, 0.09), 0.4)
	_box(_rotor, Vector3(0.4, 0.1, 8.4), Vector3.ZERO, Color(0.07, 0.07, 0.09), 0.4)
	# Small tail rotor (spins about Z) at the boom end.
	_prop = Node3D.new()
	_prop.position = Vector3(0.3, 0.9, 4.3)
	add_child(_prop)
	_box(_prop, Vector3(0.1, 2.0, 0.1), Vector3.ZERO, Color(0.08, 0.08, 0.1), 0.4)
	_box(_prop, Vector3(2.0, 0.1, 0.1), Vector3.ZERO, Color(0.08, 0.08, 0.1), 0.4)


func _box(parent: Node, size: Vector3, pos: Vector3, color: Color, rough: float) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	mi.material_override = m
	parent.add_child(mi)
