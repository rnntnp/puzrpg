extends RefCounted

const SHAKE_MINIMUM_DAMAGE := 40


static func duration(damage: int) -> float:
	var strength := clampf((float(damage) - 40.0) / 160.0, 0.0, 1.0)
	return lerpf(0.24, 0.65, strength)


static func displacement(progress: float) -> float:
	# Quick recoil, followed by one slower return to rest.
	if progress < 0.22:
		var outward := clampf(progress / 0.22, 0.0, 1.0)
		return 1.0 - (1.0 - outward) * (1.0 - outward)
	var returning := clampf((progress - 0.22) / 0.78, 0.0, 1.0)
	return (1.0 - returning) * (1.0 - returning)
