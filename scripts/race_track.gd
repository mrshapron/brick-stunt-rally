class_name RaceTrack
extends RefCounted
## A race centreline defined by a polyline of (x, z) points. Works for an open
## sprint (with gentle turns) or a closed circuit you lap several times. Cars
## follow it by distance-along-track (s); helpers sample position/heading and
## project a world point back onto the line (for lap + placement tracking).

var pts: PackedVector2Array = PackedVector2Array()
var closed: bool = false
var laps: int = 1
var width: float = 30.0
var length: float = 0.0
var _cum: PackedFloat32Array = PackedFloat32Array()


func setup(points: PackedVector2Array, is_closed: bool, lap_count: int, w: float) -> void:
	pts = points
	closed = is_closed
	laps = maxi(1, lap_count)
	width = w
	_rebuild()


func _rebuild() -> void:
	var n := pts.size()
	_cum = PackedFloat32Array()
	_cum.resize(n)
	if n == 0:
		length = 0.0
		return
	_cum[0] = 0.0
	var d := 0.0
	for i in range(1, n):
		d += pts[i].distance_to(pts[i - 1])
		_cum[i] = d
	if closed and n > 1:
		d += pts[n - 1].distance_to(pts[0])
	length = maxf(d, 0.0001)


func _seg_end(i: int) -> float:
	return _cum[i + 1] if i + 1 < pts.size() else length


func sample_pos(s: float) -> Vector2:
	return _sample(s)[0]


func sample_dir(s: float) -> Vector2:
	return _sample(s)[1]


func perp(dir: Vector2) -> Vector2:
	return Vector2(-dir.y, dir.x)


func _sample(s: float) -> Array:
	var n := pts.size()
	if n < 2:
		return [pts[0] if n == 1 else Vector2.ZERO, Vector2.RIGHT]
	if closed:
		s = fposmod(s, length)
	else:
		s = clampf(s, 0.0, length)
	var seg_count := n if closed else n - 1
	for i in range(seg_count):
		var s1 := _seg_end(i)
		if s <= s1 or i == seg_count - 1:
			var a := pts[i]
			var b := pts[(i + 1) % n]
			var s0 := _cum[i]
			var t := clampf((s - s0) / maxf(s1 - s0, 0.0001), 0.0, 1.0)
			var dir := b - a
			if dir.length() < 0.0001:
				dir = Vector2.RIGHT
			return [a.lerp(b, t), dir.normalized()]
	return [pts[n - 1], Vector2.RIGHT]


func nearest_s(p: Vector2) -> float:
	var n := pts.size()
	if n < 2:
		return 0.0
	var seg_count := n if closed else n - 1
	var best_s := 0.0
	var best_d := INF
	for i in range(seg_count):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var ab := b - a
		var l2 := ab.length_squared()
		var t := 0.0
		if l2 > 0.0001:
			t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
		var proj := a + ab * t
		var d := proj.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best_s = lerpf(_cum[i], _seg_end(i), t)
	return best_s
