extends Control
## A round on-screen action button for touch. Dispatches an InputEventAction so
## both polling (Input.is_action_pressed) and event handlers (_unhandled_input)
## react - that matters because e.g. "interact" and "pause" are read as events.
## Tracks its own touch index for multitouch.

var action: String = ""
var label: String = ""
var tint: Color = Color(0.95, 0.85, 0.3)

var _index: int = -1
var _down: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _index == -1 and visible and _hit(t.position):
				_index = t.index
				_set_down(true)
				get_viewport().set_input_as_handled()
		elif t.index == _index:
			_index = -1
			_set_down(false)


func _hit(p: Vector2) -> bool:
	var c := global_position + size * 0.5
	return p.distance_to(c) <= size.x * 0.5


func _set_down(down: bool) -> void:
	if down == _down:
		return
	_down = down
	if action != "":
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		ev.strength = 1.0 if down else 0.0
		Input.parse_input_event(ev)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := size.x * 0.5
	var fill := tint
	fill.a = 0.5 if _down else 0.28
	draw_circle(c, r, fill)
	draw_arc(c, r - 1.5, 0.0, TAU, 40, Color(1, 1, 1, 0.75), 3.0, true)
	if label != "":
		var font := ThemeDB.fallback_font
		var fs := int(clampf(r * 0.5, 16.0, 34.0))
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, c + Vector2(-tw.x * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
