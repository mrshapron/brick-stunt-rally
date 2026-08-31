extends DriveScene
## Gameplay: builds the current (generated) level, drives the loop (timer,
## flips, checkpoints, hazards, finish), and returns to the world map when done.

var builder: LevelBuilder
var hud: HUD
var pause_menu: PauseMenu

var elapsed: float = 0.0
var running: bool = false
var finished: bool = false
var flips: int = 0
var spawn_point: Vector3 = Vector3(0, 4, 0)
var last_checkpoint: Vector3 = Vector3(0, 4, 0)
var combat: bool = false
var enemies_alive: int = 0
var _waves: Array = []
var _wave_idx: int = 0
var race: bool = false
var _bots: Array = []
var _track: RaceTrack
var _laps: int = 1
var _player_laps: int = 0
var _last_s: float = 0.0
var _player_prog: float = 0.0
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
	_setup_pause_menu()
	add_touch_controls("car", true)

	combat = data.get("combat", false)
	if combat:
		_start_combat(data)

	race = data.get("race", false)
	if race:
		_setup_race(data)

	Sfx.play_level_start()
	Sfx.start_engine()
	running = true


func _setup_race(data: Dictionary) -> void:
	_track = data.get("track")
	_laps = int(data.get("laps", 1))
	var lanes: Array = data.get("bots", [])
	for i in lanes.size():
		var bd: Dictionary = lanes[i]
		var bot := Bot.new()
		add_child(bot)
		bot.configure(_track, float(bd.get("speed", 16.0)), int(bd.get("car", 0)), float(bd.get("lane", 0.0)), bool(bd.get("shoots", false)), float(bd.get("start_s", -6.0 - float(i) * 5.0)))
		_bots.append(bot)
	if _track and is_instance_valid(vehicle):
		_last_s = _track.nearest_s(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	if hud:
		hud.set_race(1, _bots.size() + 1, 1, _laps)


func _update_race_progress() -> void:
	if _track == null or not is_instance_valid(vehicle):
		return
	var s := _track.nearest_s(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	if _track.closed:
		var ds := s - _last_s
		if ds < -_track.length * 0.5:
			_player_laps += 1
		elif ds > _track.length * 0.5:
			_player_laps = maxi(0, _player_laps - 1)
	_last_s = s
	_player_prog = float(_player_laps) * _track.length + s


func _race_done() -> bool:
	if _track == null:
		return false
	if _track.closed:
		return _player_laps >= _laps
	return _player_prog >= _track.length - 4.0


func _player_place() -> int:
	var ahead := 0
	for b in _bots:
		if is_instance_valid(b) and b.progress() > _player_prog:
			ahead += 1
	return ahead + 1


func _ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
		_: return "%dth" % n


func _start_combat(data: Dictionary) -> void:
	# Battlefield extras first, then the first enemy wave.
	for b in data.get("barrels", []):
		var barrel := Barrel.new()
		add_child(barrel)
		barrel.global_position = _v3(b)
	for p in data.get("pickups", []):
		var pickup := Pickup.new()
		pickup.configure(str(p.get("kind", "health")))
		add_child(pickup)
		pickup.global_position = _v3(p.get("pos", [0, 1.4, 0]))

	_waves = data.get("waves", [])
	if _waves.is_empty():
		_waves = [data.get("enemies", [])]
	_wave_idx = 0
	_spawn_enemies(_waves[0])
	if _waves.size() > 1 and hud:
		hud.flash_center("WAVE 1 / %d" % _waves.size())


func _spawn_enemies(list: Array) -> void:
	for e in list:
		var enemy := Enemy.new()
		enemy.configure(e)
		add_child(enemy)
		enemy.global_position = _v3(e.get("pos", [0, 1.5, 0]))
		enemy.died.connect(_on_enemy_died)
		enemies_alive += 1
	hud.set_combat(enemies_alive)


func _next_wave() -> void:
	_wave_idx += 1
	if _wave_idx >= _waves.size():
		return
	var wave: Array = _waves[_wave_idx]
	Sfx.play_checkpoint()
	if hud:
		var tag := "WAVE %d / %d" % [_wave_idx + 1, _waves.size()]
		for e in wave:
			if str(e.get("type", "")) == "boss":
				tag = "!!  BOSS INCOMING  !!"
				break
		hud.flash_center(tag)
	# Dramatic drop-in: a puff of smoke where each enemy lands.
	for e in wave:
		Effects.explosion(self, _v3(e.get("pos", [0, 1.5, 0])), 0.7, Color(0.7, 0.5, 0.3))
	_spawn_enemies(wave)


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


func _setup_pause_menu() -> void:
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.restart_requested.connect(_on_restart)
	pause_menu.map_requested.connect(_to_world_map)


func _on_restart() -> void:
	Sfx.stop_engine()
	get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if running and not finished:
		elapsed += delta
	if is_instance_valid(vehicle) and vehicle.global_position.y < -30.0:
		_respawn()


func _process(_delta: float) -> void:
	if is_instance_valid(vehicle):
		if race and not finished:
			_update_race_progress()
			if hud:
				var lap := clampi(_player_laps + 1, 1, _laps)
				hud.set_race(_player_place(), _bots.size() + 1, lap, _laps)
			if _race_done():
				_finish_race()
		if hud:
			hud.update_hud(elapsed, vehicle.get_speed_kmh(), flips)
		if not finished:
			Sfx.set_engine_speed(vehicle.get_speed_kmh() / (vehicle.max_speed * 3.6))

	if Input.is_action_just_pressed("restart"):
		_on_restart()
	elif finished and Input.is_action_just_pressed("advance"):
		_continue_after_finish()


func _unhandled_input(event: InputEvent) -> void:
	# On touch (no keyboard), tapping the screen after a level ends continues
	# back to the world map / reward, matching the "Tap to continue" prompt.
	if finished and event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_continue_after_finish()
		return
	super(event)


func _continue_after_finish() -> void:
	if not finished:
		return
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
			var race_hint := "You need 1st place to win!\n" + ("Tap the screen to continue" if DisplayServer.is_touchscreen_available() else "Press R to retry   .   M for world map")
			hud.show_message("You came %s" % _ordinal(place), race_hint)


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
		if _wave_idx < _waves.size() - 1:
			# Brief breather, then the next wave storms in.
			get_tree().create_timer(1.6).timeout.connect(_next_wave)
		else:
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
	vehicle.set_controlled(false)
	vehicle.linear_velocity = Vector3.ZERO
	vehicle.angular_velocity = Vector3.ZERO
	if hud:
		var dead_hint := "Tap the screen to continue" if DisplayServer.is_touchscreen_available() else "Press R to retry   .   M for world map"
		hud.show_message("DESTROYED", dead_hint)
