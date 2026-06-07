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
	if theme.get("climb", false):
		return _generate_climb(world, level, theme)
	if theme.get("race", false):
		return _generate_race(world, level, theme)

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

	# Safari world: brick animals lining the road.
	if theme.get("safari", false):
		var kinds := ["giraffe", "elephant", "tiger"]
		var ax := 8.0
		var ai := 0
		while ax < x:
			var az := (DEPTH * 0.5 + 5.0) * (1.0 if (ai % 2 == 0) else -1.0)
			props.append({
				"type": "animal",
				"animal": kinds[ai % kinds.size()],
				"pos": [ax, 0, az],
				"rot": 90.0 if az > 0.0 else -90.0,
			})
			ax += 24.0
			ai += 1

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


static func _generate_race(world: int, level: int, theme: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6200 + level * 97

	var ld := float(level) / 10.0
	var ground: String = theme.get("ground", "#454a55")
	var accent: String = theme.get("accent", "#e8e84d")
	var brick_cols: Array = theme.get("bricks", ["#d2473b", "#3b86d2", "#e6b32e"])

	# Advanced levels race a closed circuit you lap 3 times (an "Olympic"-style
	# loop); earlier levels are a point-to-point sprint with gentle S-turns.
	var circuit := level >= 7
	var width := 30.0
	var points := PackedVector2Array()
	var laps := 1

	if circuit:
		laps = 3
		var rx := 95.0
		var rz := 56.0 + ld * 8.0
		var segs := 60
		for i in segs:
			var a := TAU * float(i) / float(segs)
			# Ellipse that starts at (0,0) heading +X, plus a gentle chicane.
			var x := rx * sin(a)
			var z := rz * (1.0 - cos(a)) + sin(a * 3.0) * 5.0
			points.append(Vector2(x, z))
	else:
		var track_len := 200.0 + level * 16.0
		var segs := 26
		var amp := lerpf(4.0, 18.0, ld)
		for i in segs + 1:
			var x := track_len * float(i) / float(segs)
			var z := sin(float(i) * 0.6) * amp + sin(float(i) * 0.27) * amp * 0.5
			points.append(Vector2(x, z))

	var track := RaceTrack.new()
	track.setup(points, circuit, laps, width)

	var bricks: Array = []
	# A big base ground so going off-track lands on grass, not into the void.
	var mnx := 1e9
	var mxx := -1e9
	var mnz := 1e9
	var mxz := -1e9
	for p in points:
		mnx = minf(mnx, p.x)
		mxx = maxf(mxx, p.x)
		mnz = minf(mnz, p.y)
		mxz = maxf(mxz, p.y)
	var pad := 70.0
	bricks.append({
		"size": [(mxx - mnx) + pad * 2.0, 3, (mxz - mnz) + pad * 2.0],
		"pos": [(mnx + mxx) * 0.5, -1.85, (mnz + mxz) * 0.5],
		"color": Color(ground).darkened(0.18).to_html(), "kind": "static",
	})

	_bake_road(track, bricks, ground, accent)

	# Obstacle blocks to weave around (kept off the racing line, away from start).
	var obstacles := 3 + int(level / 2)
	for i in obstacles:
		var s := rng.randf_range(track.length * 0.12, track.length * 0.92)
		var pos: Vector2 = track.sample_pos(s)
		var dir: Vector2 = track.sample_dir(s)
		var off := rng.randf_range(-width * 0.28, width * 0.28)
		var pp: Vector2 = pos + track.perp(dir) * off
		bricks.append({"size": [2, 2, 2], "pos": [pp.x, 1.0, pp.y], "color": brick_cols[rng.randi() % brick_cols.size()], "kind": "destructible"})

	# Opponent bots: staggered behind the start line (unique lane + row).
	var bots: Array = []
	var num := 3 + int(level / 3)
	var base := lerpf(13.0, 22.0, ld)
	var max_lane := width * 0.5 - 3.0
	for i in num:
		var side := 1.0 if i % 2 == 0 else -1.0
		var rank := int(i / 2)
		var lane: float = clampf(side * (3.0 + float(rank) * 3.0), -max_lane, max_lane)
		bots.append({
			"speed": base + rng.randf_range(-1.0, 1.5) + i * 0.2,
			"lane": lane,
			"start_s": -6.0 - float(i) * 5.0,
			"car": i % 8,
			"shoots": level >= 6,
		})

	var sp: Vector2 = track.sample_pos(0.0)
	var kind_name := "Circuit" if circuit else "Race"
	return {
		"name": "%s  -  %s %d" % [theme.get("name", "Speedway"), kind_name, level],
		"spawn": [sp.x + 2.0, 4, sp.y],
		"bricks": bricks,
		"loops": [],
		"props": [],
		"checkpoints": [],
		"race": true,
		"bots": bots,
		"track": track,
		"laps": laps,
		"sky_top": theme.get("sky_top", "#3a5a86"),
		"sky_horizon": theme.get("sky_horizon", "#bcd0e0"),
	}


static func _bake_road(track: RaceTrack, bricks: Array, ground: String, accent: String) -> void:
	# Lay the road as short segments following the centreline (rotated about Y),
	# with a dashed centre line and guard rails down both sides.
	var n := track.pts.size()
	var seg_count := n if track.closed else n - 1
	for i in seg_count:
		var a: Vector2 = track.pts[i]
		var b: Vector2 = track.pts[(i + 1) % n]
		var mid: Vector2 = (a + b) * 0.5
		var d: Vector2 = b - a
		var seg_len := d.length()
		if seg_len < 0.01:
			continue
		var yaw := rad_to_deg(atan2(-d.y, d.x))
		var perp: Vector2 = Vector2(-d.y, d.x).normalized()
		bricks.append({"size": [seg_len * 1.1, 3, track.width], "pos": [mid.x, -1.5, mid.y], "color": ground, "kind": "static", "yaw": yaw, "studs": false})
		if i % 2 == 0:
			bricks.append({"size": [seg_len * 0.45, 0.2, 0.6], "pos": [mid.x, 0.16, mid.y], "color": "#e6c020", "kind": "static", "yaw": yaw, "studs": false})
		for sgn in [1.0, -1.0]:
			var rp: Vector2 = mid + perp * (track.width * 0.5) * sgn
			bricks.append({"size": [seg_len * 1.12, 2.0, 1.2], "pos": [rp.x, 1.0, rp.y], "color": accent, "kind": "static", "yaw": yaw, "studs": false})


static func _generate_climb(world: int, level: int, theme: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5100 + level * 137

	var ld := float(level) / 10.0
	var ground: String = theme.get("ground", "#8a9aa5")
	var accent: String = theme.get("accent", "#c0d0d8")
	var brick_cols: Array = theme.get("bricks", ["#9aa0b5", "#6b7d6b", "#caa040"])

	var bricks: Array = []
	var props: Array = []
	var checkpoints: Array = []

	# Gentle slopes early, steeper later - but always climbable for the car.
	var angle := lerpf(19.0, 25.0, ld)
	var tan_a := tan(deg_to_rad(angle))
	var x := -8.0
	var base := 0.0

	var start_len := 22.0
	bricks.append(_plateau(x + start_len * 0.5, start_len, base, ground))
	x += start_len

	# The mountain climbs continuously: each ramp lifts to a higher plateau.
	var steps := 4 + int(round(ld * 5.0))
	for i in steps:
		var h := lerpf(3.5, 7.0, ld) * rng.randf_range(0.9, 1.15)
		var up_len := h / tan_a
		bricks.append(_wedge(x + up_len * 0.5, base, up_len, h, accent, false))
		x += up_len
		base += h

		var plen := rng.randf_range(10.0, 15.0)
		bricks.append(_plateau(x + plen * 0.5, plen, base, ground))
		var pmid := x + plen * 0.5

		if rng.randf() < 0.55:
			bricks.append_array(_stack_at(pmid, rng.randf_range(-7.0, 7.0), base, 2 + int(ld * 3.0), brick_cols, rng))
		# Boulders tumbling down from higher up the mountain.
		if level >= 2 and rng.randf() < 0.7:
			props.append({
				"type": "faller",
				"pos": [pmid, base + 1.0, 0],
				"interval": lerpf(2.2, 1.0, ld),
				"width": plen * 0.85,
				"height": 22.0,
				"color": "#6f7d6a",
			})
		checkpoints.append({"pos": [x + plen - 4.0, base + 2.5, 0], "size": [2, 6, DEPTH]})
		x += plen

	# Summit with the finish gate at the very top.
	var fin_len := 20.0
	bricks.append(_plateau(x + fin_len * 0.5, fin_len, base, ground))

	return {
		"name": "%s  -  Level %d" % [theme.get("name", "Mountains"), level],
		"spawn": [2, 4, 0],
		"bricks": bricks,
		"loops": [],
		"props": props,
		"checkpoints": checkpoints,
		"finish": {"pos": [x + fin_len * 0.6, base + 3.0, 0], "size": [2.5, 8, DEPTH]},
		"sky_top": theme.get("sky_top", "#5a86c0"),
		"sky_horizon": theme.get("sky_horizon", "#dfeaf2"),
	}


static func _plateau(cx: float, length: float, top_y: float, color: String) -> Dictionary:
	return {"size": [length, 3, DEPTH], "pos": [cx, top_y - 1.5, 0], "color": color, "kind": "static", "road": true}


static func _wedge(cx: float, base_y: float, length: float, height: float, color: String, flip: bool) -> Dictionary:
	return {"kind": "wedge", "size": [length, height, DEPTH], "pos": [cx, base_y + height * 0.5 - 0.05, 0], "color": color, "flip": flip}


static func _stack_at(cx: float, cz: float, base_y: float, height: int, colors: Array, rng: RandomNumberGenerator) -> Array:
	var arr: Array = []
	for k in height:
		arr.append({
			"size": [1.8, 1.6, 2.4],
			"pos": [cx, base_y + 0.82 + k * 1.64, cz],
			"color": colors[rng.randi() % colors.size()],
			"kind": "destructible",
		})
	return arr


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
	return {"size": [length, 3, DEPTH], "pos": [cx, -1.5, 0], "color": color, "kind": "static", "road": true}


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
