extends DriveScene
## World hub: drive up to a world portal and press Enter to enter it. You can
## drive freely past portals to reach the world you want.

const ENTER_TIME := 2.0
const LAB := -10
const PARK := -11
# Some worlds sit up on hills (height per world index; 0 = on the ground).
const HILLS := [0.0, 0.0, 5.0, 0.0, 9.0, 0.0, 4.0]

var _near := -1
var _near_gate: Node3D
var _dwell := 0.0


func _ready() -> void:
	add_light_and_env()
	add_fade()

	var half := 112.0
	add_ground(Vector3(half * 2.0, 3, half * 2.0), Color("#6b7080"), true)
	add_border(half - 2.0, half - 2.0, Color("#4f5460"))
	add_city(half, ["#c64b3a", "#3b86d2", "#e6b32e", "#5aa54a", "#b06bff", "#e08a2a", "#cfd2da"])
	add_scenery(half, Color("#4f7a3f"), Color(0.32, 0.62, 0.28), 22, true, false)
	add_park_decor(half, Color("#e6b32e"))
	for fpos in [Vector3(48, 0, -8), Vector3(-48, 0, -8)]:
		var f := Decor.fountain()
		f.position = fpos
		add_child(f)

	# World portals in a back row, each on a decorated pad.
	var n := GameState.get_world_count()
	for i in n:
		var w := GameState.get_world(i)
		var done := GameState.levels_completed(i)
		var color := Color(w.get("accent", "#e6b32e"))
		var sub := "%d/%d done" % [done, GameState.LEVELS_PER_WORLD]
		var px := -float(n - 1) * 30.0 * 0.5 + i * 30.0
		var hh: float = HILLS[i] if i < HILLS.size() else 0.0
		var top := 0.0
		if hh > 0.0:
			top = add_hill(px, -62.0, hh, color.darkened(0.12))
		var pos := Vector3(px, top + 3.5, -62)
		add_pad(Vector3(pos.x, top + 0.15, pos.z), Vector3(13, 0.3, 13), color.darkened(0.15))
		var gate := make_gate(pos, Vector3(6, 7, 6), color,
			str(w.get("name", "World")), sub, "portal")
		gate.body_entered.connect(_on_near.bind(gate, i))
		gate.body_exited.connect(_on_far.bind(gate, i))

	# Laboratory + Parking portals in a front row.
	var lab_color := Color("#7bd0ff")
	var lab_pos := Vector3(-20, 3.5, -28)
	add_pad(Vector3(lab_pos.x, 0.15, lab_pos.z), Vector3(13, 0.3, 13), lab_color.darkened(0.2))
	var lab_gate := make_gate(lab_pos, Vector3(6, 7, 6), lab_color, "Laboratory", "build a car", "portal")
	lab_gate.body_entered.connect(_on_near.bind(lab_gate, LAB))
	lab_gate.body_exited.connect(_on_far.bind(lab_gate, LAB))

	var park_color := Color("#c0c4cc")
	var park_pos := Vector3(20, 3.5, -28)
	add_pad(Vector3(park_pos.x, 0.15, park_pos.z), Vector3(13, 0.3, 13), park_color.darkened(0.25))
	var park_gate := make_gate(park_pos, Vector3(6, 7, 6), park_color, "Parking", "%d cars" % GameState.get_cars().size(), "portal")
	park_gate.body_entered.connect(_on_near.bind(park_gate, PARK))
	park_gate.body_exited.connect(_on_far.bind(park_gate, PARK))

	# Ambient engines for life.
	for spot in [Vector3(-40, 0, -10), Vector3(40, 0, -10), Vector3(0, 0, 40)]:
		var e := PropEngine.new()
		e.position = spot
		e.configure({"color": "#8a8f9e", "scale": 1.4, "spin": 3.5})
		add_child(e)

	spawn_car(Vector3(0, 3, 8))
	add_camera()
	add_overlay("WORLD HUB", "Drive into a world portal and hold for 2s to enter (or press Enter)")


func _on_near(body: Node, gate: Node3D, world_index: int) -> void:
	if not body.is_in_group("player"):
		return
	_near = world_index
	_near_gate = gate
	_dwell = 0.0


func _on_far(body: Node, gate: Node3D, world_index: int) -> void:
	if body.is_in_group("player") and _near == world_index:
		reset_gate(gate)
		_near = -1
		_near_gate = null
		_dwell = 0.0
		set_prompt("")


func _process(delta: float) -> void:
	if _transitioning or _near == -1:
		return
	_dwell += delta
	var ratio := clampf(_dwell / ENTER_TIME, 0.0, 1.0)
	charge_gate(_near_gate, ratio)
	var wname := "World"
	if _near == LAB:
		wname = "Laboratory"
	elif _near == PARK:
		wname = "Parking"
	else:
		wname = str(GameState.get_world(_near).get("name", "World"))
	set_prompt("Entering %s ...  %d%%" % [wname, int(ratio * 100.0)])
	if _dwell >= ENTER_TIME or Input.is_action_just_pressed("advance"):
		_enter(_near)


func _enter(world_index: int) -> void:
	Sfx.play_checkpoint()
	if _near_gate:
		Effects.explosion(self, _near_gate.global_position, 1.2, Color(0.6, 0.85, 1.0))
	if world_index == LAB:
		transition_to("res://scenes/lab.tscn")
	elif world_index == PARK:
		transition_to("res://scenes/parking.tscn")
	else:
		GameState.current_world = world_index
		transition_to("res://scenes/world_map.tscn")
