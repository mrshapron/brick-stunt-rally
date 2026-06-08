extends Node
## Autoload. Owns the world/level structure (Candy-Crush style: a few worlds,
## each with 10 levels of rising difficulty), sequential unlock progression,
## best times, on-disk save/load, and the runtime input map.

const LEVELS_PER_WORLD: int = 10
const SAVE_PATH: String = "user://save.json"
const GARAGE_PATH: String = "user://garage.json"

# Each world has a theme (palette + sky) used by the level generator and scenes.
const WORLDS: Array = [
	{
		"name": "Grassland",
		"ground": "#6fae4f",
		"accent": "#e6b32e",
		"bricks": ["#d2473b", "#3b86d2", "#e6b32e"],
		"sky_top": "#4d86db",
		"sky_horizon": "#c7d6ea",
		"mountain": "#4f7a3f",
		"foliage": "#3a8a2e",
		"trees": 22,
		"snow": true,
		"dunes": false,
	},
	{
		"name": "Desert",
		"ground": "#d8a84e",
		"accent": "#b5532a",
		"bricks": ["#e6b32e", "#b5532a", "#7a4b9e"],
		"sky_top": "#e8a14d",
		"sky_horizon": "#f3d9a8",
		"mountain": "#cfa867",
		"foliage": "#7aa64a",
		"trees": 6,
		"snow": false,
		"dunes": true,
	},
	{
		"name": "Neon City",
		"ground": "#3a3f5c",
		"accent": "#19e0c8",
		"bricks": ["#ff3ea5", "#19e0c8", "#ffe14d"],
		"sky_top": "#140a2e",
		"sky_horizon": "#3a2a6a",
		"mountain": "#2a2f4a",
		"foliage": "#19e0c8",
		"trees": 10,
		"snow": false,
		"dunes": false,
	},
	{
		"name": "War Zone",
		"ground": "#5a5648",
		"accent": "#ff7b29",
		"bricks": ["#8a3b2a", "#6b6450", "#caa040"],
		"sky_top": "#7a3a24",
		"sky_horizon": "#caa089",
		"mountain": "#6b5a44",
		"foliage": "#6b6a3a",
		"trees": 8,
		"snow": false,
		"dunes": true,
		"combat": true,
	},
	{
		"name": "Mountains",
		"ground": "#8a9aa5",
		"accent": "#c6d2da",
		"bricks": ["#9aa0b5", "#6b7d6b", "#caa040"],
		"sky_top": "#5a86c0",
		"sky_horizon": "#dfeaf2",
		"mountain": "#6f7d6a",
		"foliage": "#3a8a2e",
		"trees": 16,
		"snow": true,
		"dunes": false,
		"climb": true,
	},
	{
		"name": "Speedway",
		"ground": "#454a55",
		"accent": "#e8e84d",
		"bricks": ["#d2473b", "#3b86d2", "#e6b32e"],
		"sky_top": "#3a5a86",
		"sky_horizon": "#bcd0e0",
		"mountain": "#5a6a7a",
		"foliage": "#3a8a2e",
		"trees": 14,
		"snow": false,
		"dunes": false,
		"race": true,
	},
	{
		"name": "Safari",
		"ground": "#c2b25a",
		"accent": "#8a6a2a",
		"bricks": ["#d9a441", "#e08a2a", "#7a9e4a"],
		"sky_top": "#6fa8d8",
		"sky_horizon": "#ecd9a0",
		"mountain": "#b09a55",
		"foliage": "#7a9e3a",
		"trees": 18,
		"snow": false,
		"dunes": false,
		"safari": true,
	},
]

var current_world: int = 0
var current_level: int = 1
# progress[w][l] = best_time (float). Presence of a key means "completed".
var progress: Dictionary = {}
# The player's owned cars (each a voxel design). Starts with 2.
var cars: Array = []
var active_car: int = 0
# car_rewards[str(world)] = true once that world's car has been granted.
var car_rewards: Dictionary = {}
# The most recently awarded car (for the congratulations / reveal screen).
var last_reward_name: String = ""
var last_reward_design: Array = []
# Currency: earned by finishing levels, spent building cars in the Laboratory.
var money: int = 250


func _ready() -> void:
	_setup_input()
	_load()
	_load_garage()
	# Cap the framerate: on a 120 Hz (ProMotion) display the renderer would
	# otherwise push twice the frames it needs, heating the machine. 60 fps is
	# plenty for this arcade game and roughly halves GPU/CPU load.
	Engine.max_fps = 60


func _ensure_cars() -> void:
	if cars.is_empty():
		cars = [CarLib.design(0), CarLib.design(1)]
	elif cars.size() < 2:
		# Always start with at least two cars.
		cars.append(CarLib.design(1))


func _is_new_design(d: Array) -> bool:
	return d.is_empty() or d[0] is Dictionary


func _migrate_design(d: Array) -> Array:
	# Convert an old voxel design (list of [x,y,z,"#hex",kind] cells) to the new
	# LEGO part format. Each old 1x1 cell becomes a 2x2-stud, 3-plate part so the
	# overall shape is preserved on the finer grid.
	if _is_new_design(d):
		return d
	var out: Array = []
	for v in d:
		if not (v is Array):
			continue
		var kind: String = str(v[4]) if v.size() > 4 else "block"
		var t := "brick"
		if kind == "wheel":
			t = "wheel"
		elif kind == "rocket":
			t = "rocket"
		var color: String = str(v[3]) if v.size() > 3 else "#cccccc"
		out.append(BrickPart.make(t, int(v[0]) * 2, int(v[1]) * 3, int(v[2]) * 2, 2, 2, color))
	return out


func get_cars() -> Array:
	_ensure_cars()
	return cars


func get_car_design() -> Array:
	_ensure_cars()
	var d: Array = cars[clampi(active_car, 0, cars.size() - 1)]
	if d == null or d.is_empty():
		# Never hand back an empty car (would build an invisible vehicle).
		return CarLib.design(0)
	return d


func set_car_design(design: Array) -> void:
	_ensure_cars()
	cars[clampi(active_car, 0, cars.size() - 1)] = design
	_save_garage()


func set_active_car(index: int) -> void:
	_ensure_cars()
	active_car = clampi(index, 0, cars.size() - 1)
	_save_garage()


func try_award_world_car() -> String:
	var w := current_world
	if car_rewards.has(str(w)):
		return ""
	for l in range(1, LEVELS_PER_WORLD + 1):
		if not is_level_complete(w, l):
			return ""
	car_rewards[str(w)] = true
	_ensure_cars()
	cars.append(CarLib.design(2 + w))
	last_reward_name = CarLib.car_name(2 + w)
	last_reward_design = CarLib.design(2 + w)
	_save_garage()
	return last_reward_name


func add_money(amount: int) -> void:
	money += amount
	_save_garage()


func spend(amount: int) -> bool:
	if money >= amount:
		money -= amount
		_save_garage()
		return true
	return false


func money_reward(first_clear: bool) -> int:
	# Scales with difficulty; big payout the first time, small for replays.
	var base := 30 + current_world * 15 + current_level * 8
	return base * 2 if first_clear else maxi(8, int(base / 4.0))


func _save_garage() -> void:
	var f := FileAccess.open(GARAGE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"cars": cars, "active": active_car, "rewards": car_rewards, "money": money}))
		f.close()


func _load_garage() -> void:
	if not FileAccess.file_exists(GARAGE_PATH):
		return
	var f := FileAccess.open(GARAGE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		cars = parsed.get("cars", [])
		active_car = int(parsed.get("active", 0))
		car_rewards = parsed.get("rewards", {})
		money = int(parsed.get("money", 250))
	elif parsed is Array:
		# Legacy single-design save.
		cars = [parsed]
		active_car = 0
	# Migrate any old voxel designs to the new LEGO part format.
	var changed := false
	for i in cars.size():
		if cars[i] is Array and not _is_new_design(cars[i]):
			cars[i] = _migrate_design(cars[i])
			changed = true
	if changed:
		_save_garage()


func get_world_count() -> int:
	return WORLDS.size()


func get_world(index: int) -> Dictionary:
	return WORLDS[index]


func get_current_level_data() -> Dictionary:
	return LevelGen.generate(current_world, current_level, WORLDS[current_world])


func is_world_unlocked(_w: int) -> bool:
	# All worlds are reachable from the hub; difficulty rises by world.
	return true


func is_level_unlocked(w: int, l: int) -> bool:
	if l <= 1:
		return true
	return is_level_complete(w, l - 1)


func is_level_complete(w: int, l: int) -> bool:
	return progress.has(str(w)) and progress[str(w)].has(str(l))


func get_level_best(w: int, l: int) -> float:
	if is_level_complete(w, l):
		return progress[str(w)][str(l)]
	return -1.0


func get_current_best() -> float:
	return get_level_best(current_world, current_level)


func levels_completed(w: int) -> int:
	if not progress.has(str(w)):
		return 0
	return progress[str(w)].size()


func record_time(t: float) -> bool:
	var wk := str(current_world)
	var lk := str(current_level)
	if not progress.has(wk):
		progress[wk] = {}
	var is_best := true
	if progress[wk].has(lk):
		if t < progress[wk][lk]:
			progress[wk][lk] = t
		else:
			is_best = false
	else:
		progress[wk][lk] = t
	_save()
	return is_best


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(progress))
		f.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		progress = parsed


func _setup_input() -> void:
	# WASD drives the wheels; the arrow keys aim the rocket turret.
	_add_action("move_right", [KEY_D])
	_add_action("move_left", [KEY_A])
	_add_action("move_up", [KEY_W])
	_add_action("move_down", [KEY_S])
	_add_action("aim_left", [KEY_LEFT])
	_add_action("aim_right", [KEY_RIGHT])
	_add_action("aim_up", [KEY_UP])
	_add_action("aim_down", [KEY_DOWN])
	_add_action("fire", [KEY_SPACE, KEY_F])
	_add_action("interact", [KEY_E, KEY_C])
	_add_action("restart", [KEY_R])
	# In menu/navigation scenes ESC and M both go "back". The gameplay scene
	# instead treats ESC as "pause" (see its own handling) and ignores "menu".
	_add_action("menu", [KEY_ESCAPE, KEY_M])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("advance", [KEY_N, KEY_ENTER])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
