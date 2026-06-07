extends DriveScene
## World map: drive up to a level gate and press Enter to play it. Locked gates
## can't be entered. Press M to return to the hub.

const ENTER_TIME := 2.0

var _near := -1
var _near_gate: Node3D
var _near_locked := false
var _dwell := 0.0


func _ready() -> void:
	var w := GameState.current_world
	var theme := GameState.get_world(w)
	add_light_and_env(Color(theme.get("sky_top", "#4d86db")), Color(theme.get("sky_horizon", "#c7d6ea")))
	add_fade()

	var hx := 90.0
	var hz := 78.0
	add_ground(Vector3(hx * 2.0, 3, hz * 2.0), Color(theme.get("ground", "#6fae4f")), true)
	add_border(hx - 2.0, hz - 2.0, Color(theme.get("accent", "#e6b32e")).darkened(0.35))
	add_skyline(hx, hz, theme.get("bricks", ["#d2473b", "#3b86d2"]), 12, w * 99 + 7)
	add_scenery(
		maxf(hx, hz),
		Color(theme.get("mountain", "#4f7a3f")),
		Color(theme.get("foliage", "#3a8a2e")),
		int(theme.get("trees", 18)),
		bool(theme.get("snow", true)),
		bool(theme.get("dunes", false)))
	add_park_decor(maxf(hx, hz), Color(theme.get("accent", "#e6b32e")))
	if bool(theme.get("safari", false)):
		var arng := RandomNumberGenerator.new()
		arng.seed = 33
		var kinds := ["giraffe", "elephant", "tiger"]
		for i in 9:
			var an := Animals.build(kinds[i % kinds.size()])
			an.position = Vector3(arng.randf_range(-hx * 0.75, hx * 0.75), 0, arng.randf_range(22.0, hz * 0.8))
			an.rotation.y = arng.randf() * TAU
			add_child(an)

	# 10 gates laid out as two rows of five, each on a decorated pad.
	for l in range(1, GameState.LEVELS_PER_WORLD + 1):
		var col := (l - 1) % 5
		var row := (l - 1) / 5
		var gx := float(col) * 28.0 - 56.0
		var gz := float(row) * 32.0 - 12.0
		var unlocked := GameState.is_level_unlocked(w, l)
		var complete := GameState.is_level_complete(w, l)
		var color := Color(0.45, 0.45, 0.5)
		var sub := "locked"
		if complete:
			color = Color(0.3, 1.0, 0.4)
			sub = "%.2fs" % GameState.get_level_best(w, l)
		elif unlocked:
			color = Color(0.95, 0.8, 0.25)
			sub = "play"
		add_pad(Vector3(gx, 0.15, gz), Vector3(11, 0.3, 11), color.darkened(0.2))
		var gate := make_gate(Vector3(gx, 3.0, gz), Vector3(5, 6, 5), color, str(l), sub, "levelgate")
		gate.body_entered.connect(_on_near.bind(gate, l, unlocked))
		gate.body_exited.connect(_on_far.bind(gate, l))

	# Ambient engines themed to the world.
	for spot in [Vector3(-70, 0, 44), Vector3(70, 0, 44), Vector3(0, 0, -44)]:
		var e := PropEngine.new()
		e.position = spot
		e.configure({"color": theme.get("accent", "#e6b32e"), "scale": 1.4, "spin": 3.5})
		add_child(e)

	spawn_car(Vector3(-56, 3, 44))
	add_camera()
	add_overlay("%s" % theme.get("name", "World"), "Drive into a level gate and hold for 2s to play (or press Enter)   .   M = hub")
	add_touch_controls("nav")


func _on_near(body: Node, gate: Node3D, level: int, unlocked: bool) -> void:
	if not body.is_in_group("player"):
		return
	_near = level
	_near_gate = gate
	_near_locked = not unlocked
	_dwell = 0.0


func _on_far(body: Node, gate: Node3D, level: int) -> void:
	if body.is_in_group("player") and _near == level:
		reset_gate(gate)
		_near = -1
		_near_gate = null
		_dwell = 0.0
		set_prompt("")


func _process(delta: float) -> void:
	if _transitioning:
		return
	if Input.is_action_just_pressed("menu"):
		transition_to("res://scenes/hub.tscn")
		return
	if _near == -1:
		return
	if _near_locked:
		set_prompt("Level %d is locked - beat Level %d first" % [_near, _near - 1])
		return
	_dwell += delta
	var ratio := clampf(_dwell / ENTER_TIME, 0.0, 1.0)
	charge_gate(_near_gate, ratio)
	set_prompt("Entering Level %d ...  %d%%" % [_near, int(ratio * 100.0)])
	if _dwell >= ENTER_TIME or Input.is_action_just_pressed("advance"):
		_enter(_near)


func _enter(level: int) -> void:
	GameState.current_level = level
	Sfx.play_checkpoint()
	if _near_gate:
		Effects.explosion(self, _near_gate.global_position, 1.2, Color(0.6, 0.85, 1.0))
	transition_to("res://scenes/main.tscn")
