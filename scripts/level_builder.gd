class_name LevelBuilder
extends Node3D
## Reads a level Dictionary (parsed from JSON) and instantiates the world:
## bricks, loops, checkpoints and the finish gate. Keeping levels as data makes
## them trivial to generate and tweak (by hand or by an AI).

signal finish_reached
signal checkpoint_reached(pos: Vector3)
signal hazard_hit


func build(data: Dictionary) -> Vector3:
	for c in get_children():
		c.queue_free()

	for b in data.get("bricks", []):
		var kind: String = b.get("kind", "static")
		if kind == "hazard":
			_build_area(_v3(b.get("pos", [0, 0, 0])), _v3(b.get("size", [4, 1, 8])),
				"hazard", Color(1.0, 0.23, 0.19))
		elif kind == "wedge":
			var w := BrickFactory.make_wedge(_v3(b.get("size", [8, 3, 8])), _to_color(b.get("color", "#e6b32e")), bool(b.get("flip", false)))
			w.position = _v3(b.get("pos", [0, 0, 0]))
			add_child(w)
		else:
			_build_brick(b)
	for l in data.get("loops", []):
		_build_loop(l)
	for p in data.get("props", []):
		var prop := Props.build(p)
		if prop != null:
			add_child(prop)
	for cp in data.get("checkpoints", []):
		_build_area(_v3(cp.get("pos", [0, 2, 0])), _v3(cp.get("size", [2, 5, 9])),
			"checkpoint", Color(0.2, 0.6, 1.0))
	if data.has("finish"):
		var f: Dictionary = data["finish"]
		_build_area(_v3(f.get("pos", [0, 3, 0])), _v3(f.get("size", [2.5, 8, 9])),
			"finish", Color(0.3, 1.0, 0.4))

	return _v3(data.get("spawn", [0, 4, 0]))


func _build_brick(b: Dictionary) -> void:
	var size := _v3(b.get("size", [4, 1, 4]))
	var color := _to_color(b.get("color", "#c9ccd6"))
	var kind: String = b.get("kind", "static")
	var studs: bool = b.get("studs", true)
	var brick := BrickFactory.make_brick(size, color, kind, studs)
	brick.position = _v3(b.get("pos", [0, 0, 0]))
	if b.has("rot"):
		brick.rotation.z = deg_to_rad(float(b["rot"]))
	if b.get("road", false):
		_add_road_markings(brick, size)
	add_child(brick)


func _add_road_markings(brick: Node3D, size: Vector3) -> void:
	# Flat painted tiles laid on top of the studs: a dashed yellow centre line and
	# white lane edges. Lego-flavoured "road" look (visual only).
	var top := size.y * 0.5 + 0.26
	var half_len := size.x * 0.5

	var x := -half_len + 1.2
	while x < half_len - 0.6:
		_add_marking(brick, Vector3(x, top, 0), Vector3(1.5, 0.12, 0.5), Color(0.95, 0.82, 0.2))
		x += 3.2

	var edge := size.z * 0.5 - 1.2
	for sz in [edge, -edge]:
		_add_marking(brick, Vector3(0, top, sz), Vector3(size.x * 0.98, 0.12, 0.35), Color(0.92, 0.92, 0.94))


func _add_marking(brick: Node3D, pos: Vector3, msize: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = msize
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	mi.material_override = m
	brick.add_child(mi)


func _build_loop(loop: Dictionary) -> void:
	var center := _v3(loop.get("pos", [0, 8, 0]))
	var radius := float(loop.get("radius", 7.0))
	var segments := int(loop.get("segments", 40))
	var depth := float(loop.get("depth", 9.0))
	var color := _to_color(loop.get("color", "#9aa0b5"))
	var start_deg := float(loop.get("arc_start", -80.0))
	var end_deg := float(loop.get("arc_end", 280.0))
	var span := deg_to_rad(end_deg - start_deg)
	# Just enough overlap to hide seams without plates visibly stacking.
	var seg_len := absf(span) * radius / segments * 1.04

	for i in range(segments + 1):
		var t := float(i) / segments
		var ang := deg_to_rad(lerpf(start_deg, end_deg, t))
		var brick := BrickFactory.make_brick(Vector3(seg_len, 0.6, depth), color, "static", false)
		brick.position = center + Vector3(cos(ang), sin(ang), 0.0) * radius
		brick.rotation.z = ang + PI * 0.5
		add_child(brick)


func _build_area(pos: Vector3, size: Vector3, group: String, color: Color) -> void:
	var area := Area3D.new()
	area.position = pos
	area.add_to_group(group)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	area.add_child(col)

	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.3)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	area.add_child(mi)

	area.body_entered.connect(_on_area_entered.bind(group, area))
	add_child(area)


func _on_area_entered(body: Node, group: String, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if group == "finish":
		finish_reached.emit()
	elif group == "checkpoint":
		checkpoint_reached.emit(area.global_position)
	elif group == "hazard":
		hazard_hit.emit()


func _v3(a: Variant) -> Vector3:
	if a is Vector3:
		return a
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


func _to_color(v: Variant) -> Color:
	if v is String:
		return Color(v)
	if v is Array and v.size() >= 3:
		var alpha := float(v[3]) if v.size() > 3 else 1.0
		return Color(float(v[0]), float(v[1]), float(v[2]), alpha)
	return Color(0.8, 0.8, 0.84)
