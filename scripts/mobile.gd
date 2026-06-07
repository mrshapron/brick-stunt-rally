class_name Mobile
extends RefCounted
## Small helpers for the iOS/mobile build. Everything is gated so the desktop
## build is completely unaffected (is_mobile() is false on desktop).

static func is_mobile() -> bool:
	return OS.has_feature("mobile")


static func has_touch() -> bool:
	return DisplayServer.is_touchscreen_available()


# --- Graphics quality knobs (mobile gets the lighter values) ---

static func shadow_distance() -> float:
	return 45.0 if is_mobile() else 70.0


static func glow_enabled() -> bool:
	return not is_mobile()


static func stud_segments() -> int:
	return 6 if is_mobile() else 8


static func particle_scale() -> float:
	return 0.6 if is_mobile() else 1.0


static func explosion_light() -> bool:
	# Mobile (Forward Mobile) has tight per-object light limits, so skip the
	# extra dynamic point lights from explosions/missiles there.
	return not is_mobile()
