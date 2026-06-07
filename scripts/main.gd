extends DriveScene
## Gameplay: builds the current (generated) level, drives the loop (timer,
## flips, checkpoints, hazards, finish), and returns to the world map when done.

var builder: LevelBuilder
var hud: HUD

var elapsed: float = 0.0
var running: bool = false
var finished: bool = false
var flips: int = 0
var spawn_point: Vector3 = Vector3(0, 4, 0)
var last_checkpoint: Vector3 = Vector3(0, 4, 0)
var combat: bool = false
var enemies_alive: int = 0
var race: bool = false
var _bots: Array = []
var _finish_x: float = 0.0
var _has_reward: bool = false


func _ready() -> void:
	var data := GameState.get_current_level_data()
	add_light_and_env(Color(data.get("sky_top", "#4d86db")), Color(data.get("sky_horizon", "#c7d6ea")))
	add_fade()

	builder = LevelBuilder.new()
	add_child(builder)
	builder.finish_reached.connect(_on_finish)
	builder.checkpoint_reached.connect(_on_checkpoint)
	builder.hazard_hit.connect(_on_hazard)

	spawn_point = builder.build(data)
	last_checkpoint = spawn_point

	spawn_car(spawn_point)
	vehicle.flipped.connect(_on_flip)
	vehicle.damaged.connect(_on_player_damaged)
	vehicle.died.connect(_on_player_died)
	add_camera()
	_setup_hud(data.get("name", "Level"))

	combat = data.get("combat", false)
	if combat:
		_spawn_enemies(data.get("enemies", []))

	race = data.get("race", false)
	if race:
		_setup_race(data)

	Sfx.start_engine()
	running = true


func _setup_race(data: Dictionary) -> void:
	_finish_x = float(data.get("finish_x", 100.0))
	var lanes: Array = data.get("bots", [])
	for i in lanes.size():
		var bd: Dictionary = lanes[i]
		var bot := Bot.new()
		add_child(bot)
		# Staggered starting grid so they don't pile up.
		bot.configure(float(bd.get("speed", 16.0)), _finish_x, int(bd.get("car", 0)), float(bd.get("lane_z", 0.0)), bool(bd.get("shoots", false)), -float(i % 3) * 4.0)
		_bots.append(bot)
	if hud:
		hud.set_race(1, _bots.size() + 1)


func _player_place() -> int:
	var ahead := 0
	for b in _bots:
		if is_instance_valid(b) and b.position.x > vehicle.global_position.x:
			ahead += 1
	return ahead + 1


func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n


func _spawn_enemies(list: Array) -> void:
	for e in list:
		var enemy := Enemy.new()
		enemy.configure(e)
		add_child(enemy)
		enemy.global_position = _v3(e.get("pos", [0, 1.5, 0]))
		enemy.died.connect(_on_enemy_died)
		enemies_alive += 1
	hud.set_combat(enemies_alive)


func _v3(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _setup_hud(level_name: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUD.new()
	layer.add_child(hud)
	hud.set_level_name(level_name)


func _physics_process(delta: float) -> void:
	if running and not finished:
		elapsed += delta
	if is_instance_valid(vehicle) and vehicle.global_position.y < -30.0:
		_respawn()


func _process(_delta: float) -> void:
	if is_instance_valid(vehicle):
		if hud:
			hud.update_hud(elapsed, vehicle.get_speed_kmh(), flips)
			if race and not finished:
				hud.set_race(_player_place(), _bots.size() + 1)
		if not finished:
			Sfx.set_engine_speed(vehicle.get_speed_kmh() / (vehicle.max_speed * 3.6))

	if Input.is_action_just_pressed("menu"):
		_to_world_map()
	elif Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	elif finished and Input.is_action_just_pressed("advance"):
		if _has_reward:
			_has_reward = false
			Sfx.stop_engine()
			transition_to("res://scenes/car_reward.tscn")
		else:
			_to_world_map()


func _to_world_map() -> void:
	Sfx.stop_engine()
	transition_to("res://scenes/world_map.tscn")


func _respawn() -> void:
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	vehicle.rotation = Vector3.ZERO
	vehicle.global_position = last_checkpoint + Vector3(0, 1.5, 0)


func _on_flip() -> void:
	if finished:
		return
	flips += 1
	Sfx.play_flip()
	if hud:
		hud.flash_flip()
	if is_instance_valid(vehicle):
		vehicle.add_boost()


func _on_checkpoint(pos: Vector3) -> void:
	if pos.distance_to(last_checkpoint) > 0.5:
		Sfx.play_checkpoint()
	last_checkpoint = pos


func _on_hazard() -> void:
	if finished:
		return
	Sfx.play_smash()
	_respawn()


func _on_finish() -> void:
	if race:
		_finish_race()
	else:
		_win()


func _finish_race() -> void:
	if finished:
		return
	var place := _player_place()
	if place == 1:
		_win()
	else:
		finished = true
		running = false
		Sfx.stop_engine()
		if hud:
			hud.show_message("You came %s" % _ordinal(place), "You need 1st place to win!\nPress R to retry   .   M for world map")


func _win() -> void:
	if finished:
		return
	finished = true
	running = false
	Sfx.stop_engine()
	Sfx.play_finish()
	var first_clear := not GameState.is_level_complete(GameState.current_world, GameState.current_level)
	var earned := GameState.money_reward(first_clear)
	GameState.add_money(earned)
	var is_best := GameState.record_time(elapsed)
	var reward := GameState.try_award_world_car()
	_has_reward = reward != ""
	if hud:
		hud.show_complete(elapsed, GameState.get_current_best(), is_best, reward, earned)


func _on_enemy_died() -> void:
	enemies_alive = maxi(0, enemies_alive - 1)
	if hud:
		hud.set_enemies(enemies_alive)
	if enemies_alive == 0 and combat and not finished:
		_win()


func _on_player_damaged(ratio: float) -> void:
	if hud:
		hud.set_health(ratio)


func _on_player_died() -> void:
	if finished:
		return
	finished = true
	running = false
	Sfx.stop_engine()
	Effects.explosion(self, vehicle.global_position + Vector3(0, 1, 0), 2.2)
	vehicle.visible = false
	if hud:
		hud.show_message("DESTROYED", "Press R to retry   .   M for world map")
