class_name ChaseCamera
extends Camera3D
## Side-biased chase camera for the 2.5D plane. Stays at a fixed Z, follows the
## car's X tightly and Y smoothly, and looks slightly ahead so the player can
## read upcoming ramps.

@export var target: Node3D
@export var offset: Vector3 = Vector3(2.0, 4.5, 22.0)
@export var look_ahead: Vector3 = Vector3(4.0, 1.0, 0.0)
@export var follow_speed: float = 6.0
@export var min_height: float = 3.5

var _faded: Dictionary = {}


func _ready() -> void:
	fov = 55.0
	current = true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var tp := target.global_position
	var desired := Vector3(tp.x + offset.x, maxf(tp.y + offset.y, min_height), tp.z + offset.z)
	var weight := clampf(follow_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired, weight)
	look_at(Vector3(tp.x + look_ahead.x, tp.y + look_ahead.y, tp.z), Vector3.UP)
	_update_occlusion()


func _update_occlusion() -> void:
	# Fade anything sitting between the camera and the player so you can always
	# see the car. Restores objects once they're no longer in the way.
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var from := global_position
	var to := target.global_position + Vector3(0, 1.0, 0)
	var occluding: Dictionary = {}
	var exclude: Array = []
	for i in 5:
		var p := PhysicsRayQueryParameters3D.create(from, to)
		p.exclude = exclude
		p.collide_with_areas = false
		var hit := space.intersect_ray(p)
		if hit.is_empty():
			break
		var col := hit.get("collider") as Node
		if col == null:
			break
		exclude.append(hit.get("rid"))
		if col.is_in_group("player"):
			break
		var id := col.get_instance_id()
		occluding[id] = true
		if not _faded.has(id):
			_fade(col, id)
	for id in _faded.keys():
		if not occluding.has(id):
			_restore(id)


func _fade(node: Node, id: int) -> void:
	var raw: Array = []
	_collect_mats(node, raw)
	var entries: Array = []
	for m in raw:
		var sm := m as StandardMaterial3D
		entries.append({"m": sm, "a": sm.albedo_color.a, "tr": sm.transparency})
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var c := sm.albedo_color
		c.a = 0.28
		sm.albedo_color = c
	_faded[id] = entries


func _restore(id: int) -> void:
	for entry in _faded[id]:
		var sm: StandardMaterial3D = entry["m"]
		if is_instance_valid(sm):
			var c: Color = sm.albedo_color
			c.a = entry["a"]
			sm.albedo_color = c
			sm.transparency = entry["tr"]
	_faded.erase(id)


func _collect_mats(node: Node, out: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).material_override is StandardMaterial3D:
		out.append((node as MeshInstance3D).material_override)
	for c in node.get_children():
		_collect_mats(c, out)
