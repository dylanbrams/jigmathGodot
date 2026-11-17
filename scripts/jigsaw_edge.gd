class_name JigsawEdge
extends RefCounted
## Builds one jigsaw edge as a polyline. The tab profile is symmetric, so two
## neighbouring pieces walking the shared edge in opposite directions (with opposite
## signs) produce exactly matching tab and blank.

const SUBDIVISIONS := 6
## Global size of tabs/blanks relative to the profile below.
const TAB_SCALE := 0.85
## Profile in units of the piece's shorter side: x measured from edge centre, y = height
## above the edge. Ghost points at both ends give natural spline tangents.
const PROFILE: Array[Vector2] = [
	Vector2(-0.30, 0.0), # ghost
	Vector2(-0.17, 0.0), Vector2(-0.08, 0.02), Vector2(-0.06, 0.07), Vector2(-0.11, 0.12),
	Vector2(-0.17, 0.17), Vector2(-0.17, 0.23), Vector2(-0.10, 0.28), Vector2(0.0, 0.30),
	Vector2(0.10, 0.28), Vector2(0.17, 0.23), Vector2(0.17, 0.17), Vector2(0.11, 0.12),
	Vector2(0.06, 0.07), Vector2(0.08, 0.02), Vector2(0.17, 0.0),
	Vector2(0.30, 0.0), # ghost
]

static var _curve: PackedVector2Array


## Points from `a` (inclusive) towards `b` (exclusive). `outward` is the unit normal
## pointing away from the piece; sign +1 = tab, -1 = blank, 0 = flat border.
static func points(a: Vector2, b: Vector2, outward: Vector2, sign: int, piece_size: Vector2, along_frac := 0.5) -> PackedVector2Array:
	var out := PackedVector2Array([a])
	if sign == 0:
		return out
	var along := b - a
	var dir := along.normalized()
	var mid := along.length() * along_frac # where along a->b the tab is centred
	var s := minf(piece_size.x, piece_size.y) * TAB_SCALE
	for pt in _get_curve():
		out.append(a + dir * (mid + pt.x * s) + outward * (pt.y * s * sign))
	return out


static func _get_curve() -> PackedVector2Array:
	if _curve.is_empty():
		for i in range(1, PROFILE.size() - 2):
			var p0 := PROFILE[i - 1]
			var p1 := PROFILE[i]
			var p2 := PROFILE[i + 1]
			var p3 := PROFILE[i + 2]
			for k in SUBDIVISIONS:
				var t := float(k) / SUBDIVISIONS
				_curve.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t
					+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t
					+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
		_curve.append(PROFILE[PROFILE.size() - 2])
	return _curve
