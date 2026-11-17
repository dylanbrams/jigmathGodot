class_name PuzzlePiece
extends Node2D
## One jigsaw piece: a textured polygon (cell + tabs/blanks) with a math label.
## `position` is the CELL centre so scale/rotation tweens pivot naturally.

var texture: Texture2D
var size: Vector2          # cell size (the tabs stick out beyond this)
var text := ""
var cell := Vector2i.ZERO
var home := Vector2.ZERO   # centre position when correctly placed
var locked := false
var font: Font
var outline := PackedVector2Array()
var uvs := PackedVector2Array()

var flash := 0.0:
	set(v):
		flash = v
		queue_redraw()
var label_alpha := 1.0:
	set(v):
		label_alpha = v
		queue_redraw()
var outline_alpha := 1.0:
	set(v):
		outline_alpha = v
		queue_redraw()
## 0..1, how far the piece is "lifted" off the table (drives the drop shadow).
var lift := 0.0:
	set(v):
		lift = v
		queue_redraw()

var _plate := StyleBoxFlat.new()
var _tween: Tween


func _init() -> void:
	_plate.bg_color = Color(0.05, 0.07, 0.12, 0.78)
	_plate.set_corner_radius_all(10)


## signs = [top, right, bottom, left]; +1 tab, -1 blank, 0 flat. Needs `home`, `size` set.
## side_pos = [right, left]: where down the side edge the tab sits (0..1 from the top),
## kept off-centre so notches never collide with the label.
func build(signs: Array[int], side_pos: Array[float], board_rect: Rect2, uv_rect: Rect2) -> void:
	var hw := size.x * 0.5
	var hh := size.y * 0.5
	var tl := Vector2(-hw, -hh)
	var tr := Vector2(hw, -hh)
	var br := Vector2(hw, hh)
	var bl := Vector2(-hw, hh)
	outline = PackedVector2Array()
	outline.append_array(JigsawEdge.points(tl, tr, Vector2.UP, signs[0], size))
	outline.append_array(JigsawEdge.points(tr, br, Vector2.RIGHT, signs[1], size, side_pos[0]))
	outline.append_array(JigsawEdge.points(br, bl, Vector2.DOWN, signs[2], size))
	outline.append_array(JigsawEdge.points(bl, tl, Vector2.LEFT, signs[3], size, 1.0 - side_pos[1]))
	uvs = PackedVector2Array()
	for v in outline:
		uvs.append(uv_rect.position + (home + v - board_rect.position) / board_rect.size * uv_rect.size)
	queue_redraw()


func contains_point(global_point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(global_point), outline)


## Tween for position/scale; replaces any previous one so animations never fight.
func new_tween() -> Tween:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	return _tween


func pulse(strength := 0.55) -> void:
	flash = strength
	create_tween().tween_property(self, "flash", 0.0, 0.35)


func _draw() -> void:
	if outline.is_empty():
		return
	if lift > 0.0:
		var off := Vector2(7, 11) * lift
		var shadow := PackedVector2Array()
		for v in outline:
			shadow.append(v + off)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.30 * lift))
	draw_colored_polygon(outline, Color.WHITE, uvs, texture)
	if flash > 0.0:
		draw_colored_polygon(outline, Color(1, 1, 1, flash))
	if outline_alpha > 0.0:
		var closed := outline.duplicate()
		closed.append(outline[0])
		draw_polyline(closed, Color(0, 0, 0, 0.55 * outline_alpha), 2.0, true)
	if label_alpha > 0.0:
		_draw_label()


func _draw_label() -> void:
	var fs := clampi(int(size.y * 0.26), 18, 34)
	var max_w := size.x * 0.88
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if w > max_w:
		fs = maxi(10, int(fs * max_w / w))
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var plate := Rect2(Vector2(-ts.x * 0.5 - 12, -fs * 0.7), Vector2(ts.x + 24, fs * 1.4))
	var old_bg := _plate.bg_color
	_plate.bg_color = Color(old_bg.r, old_bg.g, old_bg.b, 0.78 * label_alpha)
	draw_style_box(_plate, plate)
	var baseline := (font.get_ascent(fs) - font.get_descent(fs)) * 0.5
	draw_string(font, Vector2(-ts.x * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, label_alpha))
