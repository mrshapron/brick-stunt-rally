extends DriveScene
## Parking lot: every car you own is parked here. Walk the minifig up to a car
## and press E to make it your active car (you'll drive it everywhere). Press M
## to return to the hub.

var _near := -1


func _ready() -> void:
	add_light_and_env(Color("#5aa0d8"), Color("#cfe0ee"))
	add_fade()

	var half := 72.0
	add_ground(Vector3(half * 2.0, 3, half * 2.0), Color("#6b7080"), true)
	add_border(half - 2.0, half - 2.0, Color("#4f5460"))
	add_scenery(half, Color("#4f7a3f"), Color(0.32, 0.62, 0.28), 20, true, false)

	var owned := GameState.get_cars()
	var spacing := 13.0
	var startx := -(owned.size() - 1) * spacing * 0.5
	for i in owned.size():
		var x := startx + i * spacing
		add_pad(Vector3(x, 0.15, -8), Vector3(9, 0.3, 10), Color(0.28, 0.28, 0.32))
		var disp := CarLib.build_display(owned[i])
		disp.position = Vector3(x, 0.7, -8)
		disp.rotation.y = -PI * 0.5
		add_child(disp)

		var label := Label3D.new()
		label.text = "Car %d%s" % [i + 1, "  *active*" if i == GameState.active_car else ""]
		label.font_size = 130
		label.pixel_size = 0.012
		label.position = Vector3(x, 4.6, -8)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 18
		add_child(label)

		var area := Area3D.new()
		area.position = Vector3(x, 2, -8)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(9, 5, 10)
		cs.shape = bs
		area.add_child(cs)
		area.add_to_group("parkcar")
		add_child(area)
		area.body_entered.connect(_on_near.bind(i))
		area.body_exited.connect(_on_far.bind(i))

	character = Character.new()
	add_child(character)
	character.global_position = Vector3(startx, 2, 8)
	camera = ChaseCamera.new()
	camera.target = character
	add_child(camera)

	add_overlay("PARKING", "Walk up to a car and press E to drive it   .   Space to jump   .   M = hub")


func _on_near(body: Node, i: int) -> void:
	if body.is_in_group("player"):
		_near = i
		set_prompt("Press E to take Car %d" % (i + 1))


func _on_far(body: Node, i: int) -> void:
	if body.is_in_group("player") and _near == i:
		_near = -1
		set_prompt("")


func _process(_delta: float) -> void:
	if _transitioning:
		return
	if Input.is_action_just_pressed("menu"):
		transition_to("res://scenes/hub.tscn")
		return
	if _near != -1 and Input.is_action_just_pressed("interact"):
		GameState.set_active_car(_near)
		Sfx.play_checkpoint()
		transition_to("res://scenes/hub.tscn")
