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


func _ready() -> void:
	_setup_input()
	_load()
	_load_garage()


func _ensure_cars() -> void:
	if cars.is_empty():
		cars = [CarLib.design(0), CarLib.design(1)]


func _upgrade_design(d: Array) -> Array:
	# Old designs had no wheel/rocket parts. Give them wheels at the bottom
	# corners and a rocket on top so they show up and work.
	var has_wheel := false
	var has_rocket := false
	var mny := 99
	for v in d:
		var k: String = str(v[4]) if v.size() > 4 else "block"
		if k == "wheel":
			has_wheel = true
		if k == "rocket":
			has_rocket = true
		mny = mini(mny, int(v[1]))
	if has_wheel:
		return d

	var mnx := 99
	var mxx := -99
	var mnz := 99
	var mxz := -99
	var maxy := -99
	for v in d:
		maxy = maxi(maxy, int(v[1]))
		if int(v[1]) == mny:
			mnx = mini(mnx, int(v[0]))
			mxx = maxi(mxx, int(v[0]))
			mnz = mini(mnz, int(v[2]))
			mxz = maxi(mxz, int(v[2]))
	var corners := {
		Vector2i(mnx, mnz): true, Vector2i(mxx, mnz): true,
		Vector2i(mnx, mxz): true, Vector2i(mxx, mxz): true,
	}
	var out: Array = []
	for v in d:
		var k2: String = str(v[4]) if v.size() > 4 else "block"
		var c2: String = str(v[3]) if v.size() > 3 else "#cccccc"
		if int(v[1]) == mny and corners.has(Vector2i(int(v[0]), int(v[2]))):
			out.append([int(v[0]), int(v[1]), int(v[2]), "#161616", "wheel"])
		else:
			out.append([int(v[0]), int(v[1]), int(v[2]), c2, k2])
	if not has_rocket:
		out.append([int((mnx + mxx) / 2.0), maxy + 1, int((mnz + mxz) / 2.0), "#cfcfcf", "rocket"])
	return out


func get_cars() -> Array:
	_ensure_cars()
	return cars


func get_car_design() -> Array:
	_ensure_cars()
	return cars[clampi(active_car, 0, cars.size() - 1)]


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
	_save_garage()
	return CarLib.car_name(2 + w)


func _save_garage() -> void:
	var f := FileAccess.open(GARAGE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"cars": cars, "active": active_car, "rewards": car_rewards}))
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
	elif parsed is Array:
		# Legacy single-design save.
		cars = [parsed]
		active_car = 0
	# Upgrade any wheel-less old designs.
	var upgraded := false
	for i in cars.size():
		var u := _upgrade_design(cars[i])
		if u.size() != cars[i].size():
			upgraded = true
		cars[i] = u
	if upgraded:
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
	_add_action("move_right", [KEY_RIGHT, KEY_D])
	_add_action("move_left", [KEY_LEFT, KEY_A])
	_add_action("move_up", [KEY_UP, KEY_W])
	_add_action("move_down", [KEY_DOWN, KEY_S])
	_add_action("fire", [KEY_SPACE, KEY_F])
	_add_action("interact", [KEY_E, KEY_C])
	_add_action("restart", [KEY_R])
	_add_action("menu", [KEY_ESCAPE, KEY_M])
	_add_action("advance", [KEY_N, KEY_ENTER])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
