class_name Props
extends RefCounted
## Builds an animated brick prop from a data dict: {"type", "pos", ...params}.


static func build(p: Dictionary) -> Node3D:
	var node: Node3D
	match p.get("type", ""):
		"engine":
			node = PropEngine.new()
		"platform":
			node = PropPlatform.new()
		"spinner":
			node = PropSpinner.new()
		"faller":
			node = PropFaller.new()
		_:
			return null
	node.position = _v3(p.get("pos", [0, 0, 0]))
	node.configure(p)
	return node


static func _v3(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
