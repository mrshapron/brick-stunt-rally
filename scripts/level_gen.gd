class_name LevelGen
extends RefCounted
## Deterministic, difficulty-scaled level generator. Given (world, level) it
## produces a level Dictionary consumed by LevelBuilder. Difficulty rises with
## both the level (1-10) and the world index, controlling course length, gaps,
## ramp steepness, destructible obstacles, hazards and loops.
##
## Courses run along +X toward the finish on a WIDE track (Z depth), so the car
## can weave left/right. Gaps and hazards span the full width (you must jump
## them); destructible obstacles are scattered across the width to dodge/smash.
## Falls and hazards respawn at the last checkpoint, so levels stay completable.

const DEPTH: float = 26.0


static func generate(world: int, level: int, theme: Dictionary) -> Dictionary:
	if theme.get("combat", false):
		return _generate_combat(world, level, theme)

	var rng := RandomNumberGenerator.new()
	rng.seed = (world + 1) * 9973 + level * 131

	var gd: float = clampf((float(world) * 10.0 + float(level)) / 32.0, 0.0, 1.0)

	var ground: String = theme.get("ground", "#7a9e5a")
	var accent: String = theme.get("accent", "#e6b32e")
	var brick_cols: Array = theme.get("bricks", ["#d2473b", "#3b86d2", "#e6b32e"])

	var bricks: Array = []
	var loops: Array = []
	var checkpoints: Array = []
	var props: Array = []

	var edge := DEPTH * 0.5 - 2.0

	var x := -8.0
	var start_len := 22.0
	bricks.append(_ground(x + start_len * 0.5, start_len, ground))
	# A couple of ambient engines flanking the start.
	props.append(_engine(6.0, edge, accent))
	props.append(_engine(6.0, -edge, brick_cols[0]))
	x += start_len

	var segments := 5 + level + world
	var since_cp := 0
	var allow_gaps := level >= 3
	var allow_loops := (float(world) * 10.0 + float(level)) >= 6.0

	for i in segments:
		if allow_gaps and rng.randf() < 0.25 + gd * 0.35:
			var rlen := rng.randf_range(8.0, 11.0)
			var ang := lerpf(16.0, 24.0, gd)
			bricks.append(_ramp(x - rlen * 0.55, ang, rlen, accent))
			x += clampf(3.0 + gd * 4.0 + rng.randf() * 1.5, 3.0, 7.5)

		var seg_len := rng.randf_range(18.0, 26.0)
		bricks.append(_ground(x + seg_len * 0.5, seg_len, ground))
		var seg_mid := x + seg_len * 0.5

		var feat := rng.randf()
		if feat < 0.45:
			# A few destructible clusters scattered across the width.
			var clusters := 1 + int(round(gd * 2.0))
			for _c in clusters:
				var cz := rng.randf_range(-DEPTH * 0.5 + 3.0, DEPTH * 0.5 - 3.0)
				var cx := seg_mid + rng.randf_range(-4.0, 4.0)
				var h_cnt := 2 + int(round(gd * 3.0))
				bricks.append_array(_stack(cx, cz, h_cnt, brick_cols, rng))
		elif feat < 0.75:
			var jlen := rng.randf_range(7.0, 10.0)
			bricks.append(_ramp(seg_mid - jlen * 0.5, lerpf(14.0, 22.0, gd), jlen, accent))
		else:
			var hw := clampf(3.0 + gd * 3.5, 3.0, 7.0)
			bricks.append(_ramp(seg_mid - hw * 0.5 - 4.5, lerpf(15.0, 22.0, gd), 8.0, accent))
			bricks.append(_hazard(seg_mid, hw))

		if allow_loops and rng.randf() < (gd - 0.3) * 0.6:
			# Loops sit off to one side so there's always a clear lane to drive
			# past them on the wide track (and you can still drive through for fun).
			var lz := DEPTH * 0.3 * (1.0 if rng.randf() < 0.5 else -1.0)
			loops.append({
				"pos": [seg_mid, 7.5, lz],
				"radius": 6.0,
				"segments": 40,
				"depth": 8.0,
				"color": "#9aa0b5",
				"arc_start": -85.0,
				"arc_end": 275.0,
			})

		# Lively brick contraptions.
		if rng.randf() < 0.5:
			var ez := edge if rng.randf() < 0.5 else -edge
			props.append(_engine(seg_mid, ez, brick_cols[rng.randi() % brick_cols.size()]))
		if gd > 0.4 and rng.randf() < 0.25:
			var pz := rng.randf_range(-edge + 2.0, edge - 2.0)
			props.append({
				"type": "platform",
				"pos": [seg_mid, 1.5, pz],
				"size": [6, 1, 6],
				"color": accent,
				"travel": [0, 3.0 + gd * 4.0, 0],
				"period": 2.6,
			})
		if gd > 0.5 and rng.randf() < 0.22:
			props.append({
				"type": "spinner",
				"pos": [seg_mid, 0.0, 0],
				"spin": 1.2 + gd,
				"arm": [10.0 + gd * 6.0, 1.2, 1.6],
				"color": accent,
			})

		x += seg_len
		since_cp += 1
		if since_cp >= 2:
			checkpoints.append({"pos": [x - 5.0, 2.5, 0], "size": [2, 6, DEPTH]})
			since_cp = 0

	var fin_len := 24.0
	bricks.append(_ground(x + fin_len * 0.5, fin_len, ground))

	return {
		"name": "%s  -  Level %d" % [theme.get("name", "World"), level],
		"spawn": [2, 4, 0],
		"bricks": bricks,
		"loops": loops,
		"props": props,
		"checkpoints": checkpoints,
		"finish": {"pos": [x + fin_len * 0.6, 3, 0], "size": [2.5, 8, DEPTH]},
		"sky_top": theme.get("sky_top", "#4d86db"),
		"sky_horizon": theme.get("sky_horizon", "#c7d6ea"),
	}


static func _generate_combat(world: int, level: int, theme: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + level * 131

	var ground: String = theme.get("ground", "#5a5648")
	var accent: String = theme.get("accent", "#ff7b29")
	var brick_cols: Array = theme.get("bricks", ["#8a3b2a", "#6b6450", "#caa040"])
	var half := 60.0

	var bricks: Array = []
	bricks.append({"size": [half * 2.0, 3, half * 2.0], "pos": [0, -1.5, 0], "color": ground, "kind": "static"})

	# Cover blocks scattered around the arena (not near the player's spawn).
	var cover := 6 + level
	for i in cover:
		var cx := rng.randf_range(-half + 8.0, half - 8.0)
		var cz := rng.randf_range(-half + 8.0, half - 25.0)
		var ch := rng.randf_range(2.0, 4.0)
		bricks.append({
			"size": [rng.randf_range(3.0, 6.0), ch, rng.randf_range(3.0, 6.0)],
			"pos": [cx, ch * 0.5 - 0.05, cz],
			"color": brick_cols[rng.randi() % brick_cols.size()],
			"kind": "static",
		})

	# Enemies: count and toughness rise with the level; tougher types appear later.
	var enemies: Array = []
	var count := 3 + level
	var hp_mult := 1.0 + float(level) * 0.12
	for i in count:
		var roll := rng.randf()
		var etype := "drone"
		if level >= 4 and roll < 0.35:
			etype = "tank"
		elif roll < 0.65:
			etype = "turret"
		var ex := rng.randf_range(-half + 10.0, half - 10.0)
		var ez := rng.randf_range(-half + 10.0, half - 35.0)
		enemies.append({"type": etype, "pos": [ex, 1.5, ez], "hp_mult": hp_mult})

	var props: Array = [
		_engine(-half + 6.0, -half + 6.0, accent),
		_engine(half - 6.0, -half + 6.0, brick_cols[0]),
	]

	return {
		"name": "%s  -  Mission %d" % [theme.get("name", "War"), level],
		"spawn": [0, 4, half - 12.0],
		"bricks": bricks,
		"loops": [],
		"props": props,
		"checkpoints": [],
		"enemies": enemies,
		"combat": true,
		"sky_top": theme.get("sky_top", "#7a3a24"),
		"sky_horizon": theme.get("sky_horizon", "#caa089"),
	}


static func _engine(cx: float, cz: float, color: String) -> Dictionary:
	return {"type": "engine", "pos": [cx, 0.0, cz], "color": color, "spin": 3.0 + randf() * 3.0}


static func _ground(cx: float, length: float, color: String) -> Dictionary:
	return {"size": [length, 3, DEPTH], "pos": [cx, -1.5, 0], "color": color, "kind": "static"}


static func _ramp(cx: float, ang_deg: float, length: float, color: String) -> Dictionary:
	# Flush triangular ramp (rises toward +X), sunk slightly so its base doesn't
	# z-fight the ground.
	var height: float = length * tan(deg_to_rad(ang_deg))
	return {"kind": "wedge", "size": [length, height, DEPTH], "pos": [cx, height * 0.5 - 0.05, 0], "color": color}


static func _hazard(cx: float, width: float) -> Dictionary:
	return {"size": [width, 1.2, DEPTH], "pos": [cx, 0.4, 0], "color": "#ff3b30", "kind": "hazard"}


static func _stack(cx: float, cz: float, height: int, colors: Array, rng: RandomNumberGenerator) -> Array:
	var arr: Array = []
	for k in height:
		arr.append({
			"size": [1.8, 1.6, 2.4],
			"pos": [cx, 0.82 + k * 1.64, cz],
			"color": colors[rng.randi() % colors.size()],
			"kind": "destructible",
		})
	return arr
