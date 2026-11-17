class_name MenuBackground
extends Control
## Navy gradient with faint math symbols drifting upward. Used behind every menu screen.

const SYMBOLS: Array[String] = ["+", "-", "x", "/", "=", "7", "12", "3", "9", "24", "5", "8"]
const COUNT := 30

var _items: Array[Dictionary] = []
var _font: Font = preload("res://assets/fonts/Roboto-Regular.ttf")
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	for i in COUNT:
		_items.append(_make_item(true))


func _make_item(anywhere: bool) -> Dictionary:
	var view := get_viewport_rect().size
	return {
		"pos": Vector2(_rng.randf_range(0, view.x), _rng.randf_range(0, view.y) if anywhere else view.y + 60.0),
		"speed": _rng.randf_range(10.0, 34.0),
		"size": _rng.randi_range(36, 110),
		"rot": _rng.randf_range(-0.5, 0.5),
		"spin": _rng.randf_range(-0.15, 0.15),
		"text": SYMBOLS[_rng.randi_range(0, SYMBOLS.size() - 1)],
		"alpha": _rng.randf_range(0.04, 0.11),
	}


func _process(delta: float) -> void:
	for i in _items.size():
		var it := _items[i]
		it.pos.y -= it.speed * delta
		it.rot += it.spin * delta
		if it.pos.y < -120.0:
			_items[i] = _make_item(false)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var top := Color(0.14, 0.17, 0.28)
	var bottom := Color(0.06, 0.07, 0.12)
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
	for it in _items:
		draw_set_transform(it.pos, it.rot)
		draw_string(_font, Vector2.ZERO, it.text, HORIZONTAL_ALIGNMENT_CENTER, -1, it.size, Color(1, 1, 1, it.alpha))
	draw_set_transform(Vector2.ZERO)
