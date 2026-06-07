extends Control
## A draggable analog thumbstick. Touching anywhere inside its rect drops the
## stick base there (floating) and the knob follows your thumb, feeding four
## InputMap actions with proportional strength so steering is analog. Supports
## multitouch (tracks its own touch index) and draws itself crisply at any DPI.

var action_left: String = ""
var action_right: String = ""
var action_up: String = ""
var action_down: String = ""
var radius: float = 95.0
var knob_radius: float = 48.0
var dead_zone: float = 0.16
var floating: bool = true
var ring_color: Color = Color(1, 1, 1, 0.14)
var knob_color: Color = Color(1, 1, 1, 0.32)

var _index: int = -1
var _center: Vector2 = Vector2.ZERO
var _pos: Vector2 = Vector2.ZERO
var _active: bool = false


func setup(al: String, ar: String, au: String, ad: String) -> void:
	action_left = al
	action_right = ar
	action_up = au
	action_down = ad


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _index == -1 and visible and get_global_rect().has_point(t.position):
				_index = t.index
				_active = true
				_center = t.position if floating else global_position + size * 0.5
				_pos = t.position
				_apply()
				queue_redraw()
				get_viewport().set_input_as_handled()
		elif t.index == _index:
			_release()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _index:
			_pos = d.position
			_apply()
			queue_redraw()


func _release() -> void:
	_index = -1
	_active = false
	for a in [action_left, action_right, action_up, action_down]:
		if a != "":
			Input.action_release(a)
	queue_redraw()


func _vector() -> Vector2:
	var v := (_pos - _center) / radius
	if v.length() > 1.0:
		v = v.normalized()
	if v.length() < dead_zone:
		return Vector2.ZERO
	return v


func _apply() -> void:
	var v := _vector()
	_press(action_right, maxf(0.0, v.x))
	_press(action_left, maxf(0.0, -v.x))
	_press(action_down, maxf(0.0, v.y))
	_press(action_up, maxf(0.0, -v.y))


func _press(a: String, s: float) -> void:
	if a == "":
		return
	if s > 0.001:
		Input.action_press(a, clampf(s, 0.0, 1.0))
	else:
		Input.action_release(a)


func _draw() -> void:
	var c := (_center - global_position) if _active else (size * 0.5)
	if not _active and floating:
		return
	draw_circle(c, radius, ring_color)
	draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.4), 3.0, true)
	var knob := c
	if _active:
		var off := _pos - _center
		if off.length() > radius:
			off = off.normalized() * radius
		knob += off
	draw_circle(knob, knob_radius, knob_color)
	draw_arc(knob, knob_radius, 0.0, TAU, 32, Color(1, 1, 1, 0.7), 3.0, true)
