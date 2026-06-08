extends CanvasLayer
## On-screen touch controls for the iOS build. Built in code, shown only on a
## touchscreen (removed entirely on desktop so keyboard play is untouched).
## set_mode() swaps the button set between gameplay (car/foot) and navigation.

const VJoystick := preload("res://scripts/virtual_joystick.gd")
const TButton := preload("res://scripts/touch_button.gd")

var _move: Control
var _aim: Control
var _fire: Control
var _interact: Control
var _pause: Control
var _enter: Control
var _back: Control
var _mode: String = "car"


func _ready() -> void:
	# Desktop / no touchscreen: don't exist at all.
	if not DisplayServer.is_touchscreen_available():
		queue_free()
		return
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_move = VJoystick.new()
	_move.setup("move_left", "move_right", "move_up", "move_down")
	_move.anchor_left = 0.0
	_move.anchor_right = 0.5
	_move.anchor_top = 0.12
	_move.anchor_bottom = 1.0
	root.add_child(_move)

	_aim = VJoystick.new()
	_aim.setup("aim_left", "aim_right", "aim_up", "aim_down")
	_aim.floating = false
	_aim.radius = 82.0
	_aim.knob_radius = 42.0
	_corner(_aim, -454.0, -244.0, -244.0, -34.0)
	root.add_child(_aim)

	_fire = _make_button(root, "fire", "FIRE", Color(0.95, 0.4, 0.3))
	_fire.hold = true
	_corner(_fire, -204.0, -204.0, -36.0, -36.0)

	_interact = _make_button(root, "interact", "E", Color(0.45, 0.8, 1.0))
	_corner(_interact, -188.0, -350.0, -52.0, -214.0)

	_enter = _make_button(root, "advance", "ENTER", Color(0.45, 0.9, 0.5))
	_corner(_enter, -204.0, -204.0, -36.0, -36.0)

	_pause = _make_button(root, "pause", "II", Color(0.85, 0.85, 0.9))
	_pause.anchor_left = 1.0
	_pause.anchor_right = 1.0
	_pause.offset_left = -116.0
	_pause.offset_right = -36.0
	_pause.offset_top = 30.0
	_pause.offset_bottom = 110.0

	_back = _make_button(root, "menu", "BACK", Color(0.85, 0.85, 0.9))
	_back.anchor_left = 1.0
	_back.anchor_right = 1.0
	_back.offset_left = -150.0
	_back.offset_right = -36.0
	_back.offset_top = 30.0
	_back.offset_bottom = 110.0

	set_mode(_mode)


func _make_button(root: Node, action: String, label: String, tint: Color) -> Control:
	var b: Control = TButton.new()
	b.action = action
	b.label = label
	b.tint = tint
	root.add_child(b)
	return b


func _corner(c: Control, l: float, t: float, r: float, b: float) -> void:
	# Anchor to the bottom-right corner using negative offsets.
	c.anchor_left = 1.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func set_mode(mode: String) -> void:
	_mode = mode
	if _move == null:
		return
	var car := mode == "car"
	var foot := mode == "foot"
	var nav := mode == "nav"
	_set_vis(_aim, car)
	_set_vis(_fire, car or foot)
	_set_vis(_interact, true)
	_set_vis(_pause, car or foot)
	_set_vis(_enter, nav)
	_set_vis(_back, nav)
	if _fire:
		_fire.label = "FIRE" if car else "JUMP"
		_fire.queue_redraw()


func _set_vis(c: Control, v: bool) -> void:
	if c == null:
		return
	if not v and c.visible and c.has_method("_release"):
		c._release()
	c.visible = v
