extends Node2D
## JigMath prototype: assemble the picture by working out where each math fragment
## belongs. Rows read left-to-right as equations. Drag pieces; correct ones snap in.

const COLS := 5
const ROWS := 4
const BOARD_AREA := Rect2(40, 100, 640, 540)
const TRAY_AREA := Rect2(730, 70, 500, 600)
const SNAP_FRACTION := 0.45 # of the smaller cell dimension
const COMBO_WINDOW_MS := 2500
const GOLD := Color(1.0, 0.85, 0.4)
const CONFETTI: Array[Color] = [Color("ff5d73"), Color("ffd166"), Color("06d6a0"), Color("4cc9f0"), Color("b388ff")]

var rng := RandomNumberGenerator.new()
var font: Font = preload("res://assets/fonts/Roboto-Regular.ttf")
var sfx := Sfx.new()
var image_paths: Array[String] = []
var image_index := -1

var board_rect := Rect2()
var cell_size := Vector2.ZERO
var texture: Texture2D
var grid_pieces: Array[PuzzlePiece] = [] # reading order, never reordered
var pieces: Array[PuzzlePiece] = []      # z-order (last = topmost)
var locked_count := 0
var held: PuzzlePiece = null
var grab_offset := Vector2.ZERO
var solved := false
var near_home := false
var tilt_target := 0.0
var combo := 0
var last_snap_ms := 0
var shake_tween: Tween

var frame_glow := 0.0:
	set(v):
		frame_glow = v
		if board_layer:
			board_layer.queue_redraw()

var board_layer: Node2D
var piece_layer: Node2D
var progress_label: Label
var message_label: Label
var hint_label: Label


func _ready() -> void:
	rng.randomize()
	add_child(sfx)
	_collect_images()
	_build_ui()
	new_puzzle()


func _process(delta: float) -> void:
	if held:
		tilt_target = lerpf(tilt_target, 0.0, minf(1.0, 10.0 * delta))
		held.rotation = lerp_angle(held.rotation, tilt_target, minf(1.0, 20.0 * delta))


func _collect_images() -> void:
	for f in DirAccess.get_files_at("res://assets/images"):
		f = f.trim_suffix(".import") # exported builds list only the .import files
		var path := "res://assets/images/" + f
		if f.get_extension().to_lower() in ["jpg", "jpeg", "png"] and not image_paths.has(path):
			image_paths.append(path)
	image_paths.shuffle()


func _build_ui() -> void:
	RenderingServer.set_default_clear_color(Color(0.10, 0.12, 0.18))
	board_layer = Node2D.new()
	board_layer.draw.connect(_draw_board)
	add_child(board_layer)
	piece_layer = Node2D.new()
	add_child(piece_layer)
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := _make_label(ui, "JigMath", 36, Vector2(40, 24))
	title.add_theme_color_override("font_color", GOLD)
	progress_label = _make_label(ui, "", 22, Vector2(40, 655))
	_make_label(ui, "N: new puzzle    R: reshuffle", 18, Vector2(900, 684)).modulate.a = 0.6

	message_label = _make_label(ui, "Solved!", 84, Vector2(BOARD_AREA.position.x, 300))
	message_label.size = Vector2(BOARD_AREA.size.x, 110)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.pivot_offset = message_label.size * 0.5
	message_label.add_theme_color_override("font_color", GOLD)
	message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	message_label.add_theme_constant_override("outline_size", 16)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = _make_label(ui, "Press N for the next puzzle", 24, Vector2(BOARD_AREA.position.x, 420))
	hint_label.size = Vector2(BOARD_AREA.size.x, 40)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_label.add_theme_constant_override("outline_size", 8)
	message_label.visible = false
	hint_label.visible = false


func _make_label(parent: Node, text: String, font_size: int, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


# ---------------------------------------------------------------- puzzle setup

func new_puzzle() -> void:
	image_index = (image_index + 1) % image_paths.size()
	texture = load(image_paths[image_index])
	_fit_board()
	_spawn_pieces()
	board_layer.queue_redraw()


func _fit_board() -> void:
	var tex_size := texture.get_size()
	var scale_f := minf(BOARD_AREA.size.x / tex_size.x, BOARD_AREA.size.y / tex_size.y)
	var s := tex_size * scale_f
	board_rect = Rect2(BOARD_AREA.position + (BOARD_AREA.size - s) * 0.5, s)
	cell_size = s / Vector2(COLS, ROWS)


func _spawn_pieces() -> void:
	for p in pieces:
		p.queue_free()
	pieces.clear()
	grid_pieces.clear()
	locked_count = 0
	held = null
	solved = false
	combo = 0
	frame_glow = 0.0
	message_label.visible = false
	hint_label.visible = false

	# One random sign per interior edge; neighbours see it with opposite sign.
	var right_signs: Array = [] # [row][col] edge between (col,row) and (col+1,row)
	var below_signs: Array = [] # [row][col] edge between (col,row) and (col,row+1)
	for r in ROWS:
		right_signs.append(_random_signs(COLS))
		below_signs.append(_random_signs(COLS))

	var tokens := MathGenerator.generate(COLS, ROWS, rng)
	var src_cell := texture.get_size() / Vector2(COLS, ROWS)
	for row in ROWS:
		for col in COLS:
			var p := PuzzlePiece.new()
			p.texture = texture
			p.font = font
			p.size = cell_size
			p.cell = Vector2i(col, row)
			p.text = tokens[row * COLS + col]
			p.home = board_rect.position + (Vector2(col, row) + Vector2(0.5, 0.5)) * cell_size
			var signs: Array[int] = [
				0 if row == 0 else -below_signs[row - 1][col],
				0 if col == COLS - 1 else right_signs[row][col],
				0 if row == ROWS - 1 else below_signs[row][col],
				0 if col == 0 else -right_signs[row][col - 1],
			]
			p.build(signs, board_rect)
			piece_layer.add_child(p)
			pieces.append(p)
			grid_pieces.append(p)
	_scatter()
	_update_progress()


func _random_signs(count: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(1 if rng.randf() < 0.5 else -1)
	return out


func _scatter() -> void:
	var slots: Array[Vector2] = []
	var cols := maxi(1, int(TRAY_AREA.size.x / (cell_size.x * 1.15)))
	var rows := ceili(float(pieces.size()) / cols)
	var step := Vector2(TRAY_AREA.size.x / cols, TRAY_AREA.size.y / rows)
	for i in pieces.size():
		var slot := Vector2(i % cols, i / cols)
		var jitter := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 14.0
		slots.append(TRAY_AREA.position + (slot + Vector2(0.5, 0.5)) * step + jitter)
	slots.shuffle()
	for i in pieces.size():
		var p := pieces[i]
		p.z_index = 1
		p.position = slots[i]
		# pop-in
		p.scale = Vector2.ZERO
		p.new_tween().tween_property(p, "scale", Vector2.ONE, 0.35)\
			.set_delay(i * 0.02).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func reshuffle() -> void:
	if solved:
		return
	var loose := pieces.filter(func(p: PuzzlePiece) -> bool: return not p.locked)
	var targets: Array[Vector2] = []
	for p: PuzzlePiece in loose:
		targets.append(p.position)
	targets.shuffle()
	for i in loose.size():
		var p: PuzzlePiece = loose[i]
		p.new_tween().tween_property(p, "position", targets[i], 0.35)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sfx.play("tick", 0.8)


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_puzzle"):
		new_puzzle()
	elif event.is_action_pressed("reshuffle"):
		reshuffle()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pick_up(get_global_mouse_position())
		else:
			_drop()
	elif event is InputEventMouseMotion and held:
		held.position = get_global_mouse_position() + grab_offset
		tilt_target = clampf(tilt_target + event.relative.x * 0.004, -0.3, 0.3)
		_update_near()


func _snap_distance() -> float:
	return minf(cell_size.x, cell_size.y) * SNAP_FRACTION


func _pick_up(mouse: Vector2) -> void:
	if solved:
		return
	for i in range(pieces.size() - 1, -1, -1): # last = topmost
		var p := pieces[i]
		if not p.locked and p.contains_point(mouse):
			held = p
			grab_offset = p.position - mouse
			p.z_index = 10
			piece_layer.move_child(p, -1)
			pieces.erase(p)
			pieces.append(p)
			p.new_tween().tween_property(p, "scale", Vector2.ONE * 1.08, 0.1)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			create_tween().tween_property(p, "lift", 1.0, 0.1)
			sfx.play("pick", rng.randf_range(0.95, 1.1))
			_update_near()
			return


## Magnet hint: when the held piece is within snap range, light up its home slot.
func _update_near() -> void:
	var n := held != null and held.position.distance_to(held.home) <= _snap_distance()
	if n == near_home:
		return
	near_home = n
	board_layer.queue_redraw()
	if n:
		sfx.play("tick")
		held.new_tween().tween_property(held, "scale", Vector2.ONE * 1.14, 0.08)
	elif held:
		held.new_tween().tween_property(held, "scale", Vector2.ONE * 1.08, 0.08)


func _drop() -> void:
	if held == null:
		return
	var p := held
	held = null
	var was_near := near_home
	near_home = false
	board_layer.queue_redraw()
	tilt_target = 0.0
	create_tween().tween_property(p, "rotation", 0.0, 0.15)
	create_tween().tween_property(p, "lift", 0.0, 0.12)
	if was_near:
		_lock(p)
		return
	p.z_index = 1
	var rest := p.position
	var t := p.new_tween()
	t.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if board_rect.grow(cell_size.x * 0.15).has_point(rest):
		# Dropped on the board but in the wrong place: a little "nope" wiggle.
		sfx.play("wrong")
		t.set_parallel(false)
		for d in [10.0, -8.0, 5.0, 0.0]:
			t.tween_property(p, "position:x", rest.x + d, 0.045)


func _lock(p: PuzzlePiece) -> void:
	p.locked = true
	p.z_index = 0
	locked_count += 1

	var now := Time.get_ticks_msec()
	combo = combo + 1 if now - last_snap_ms <= COMBO_WINDOW_MS else 0
	last_snap_ms = now
	sfx.play("snap", sfx.combo_pitch(combo))

	var t := p.new_tween()
	t.tween_property(p, "position", p.home, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "scale", Vector2.ONE * 1.16, 0.05)
	t.tween_property(p, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	p.pulse(0.75)
	create_tween().tween_property(p, "label_alpha", 0.55, 0.4)
	_burst(p.home, 16, [GOLD, Color.WHITE], 260.0)
	_shake(2.5 + minf(combo, 4) * 0.5, 0.12)
	_update_progress()
	_bump(progress_label)

	if locked_count == grid_pieces.size():
		_on_solved()
	else:
		_check_row(p.cell.y)


func _check_row(row: int) -> void:
	for col in COLS:
		if not grid_pieces[row * COLS + col].locked:
			return
	sfx.play("row")
	for col in COLS:
		var p := grid_pieces[row * COLS + col]
		var t := create_tween()
		t.tween_interval(0.12 + col * 0.07)
		t.tween_callback(func() -> void:
			p.pulse(0.6)
			_burst(p.home, 6, [Color.WHITE, GOLD], 140.0, 0.5, 4.0))


func _update_progress() -> void:
	progress_label.text = "Placed %d / %d" % [locked_count, grid_pieces.size()]


func _bump(label: Control) -> void:
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE * 1.25
	create_tween().tween_property(label, "scale", Vector2.ONE, 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- win

func _on_solved() -> void:
	solved = true
	sfx.play("win")
	_shake(7.0, 0.35)

	# Wave of celebration across the pieces in reading order, labels and seams fade out.
	for i in grid_pieces.size():
		var p := grid_pieces[i]
		var wave := create_tween()
		wave.tween_interval(0.2 + i * 0.035)
		wave.tween_callback(func() -> void:
			p.pulse(0.5)
			var bounce := p.new_tween()
			bounce.tween_property(p, "scale", Vector2.ONE * 1.12, 0.07)
			bounce.tween_property(p, "scale", Vector2.ONE, 0.4)\
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
		create_tween().tween_property(p, "label_alpha", 0.0, 0.5).set_delay(0.5 + i * 0.02)
		create_tween().tween_property(p, "outline_alpha", 0.0, 0.8).set_delay(1.1)

	var glow := create_tween()
	glow.tween_property(self, "frame_glow", 1.0, 0.3)
	glow.tween_property(self, "frame_glow", 0.35, 1.0)

	# Confetti cannons.
	for i in 3:
		var shot := create_tween()
		shot.tween_interval(0.1 + i * 0.3)
		var x := lerpf(BOARD_AREA.position.x, BOARD_AREA.end.x, 0.15 + i * 0.35)
		shot.tween_callback(_confetti.bind(Vector2(x, 700.0)))

	# Title pops in with an elastic overshoot.
	message_label.visible = true
	message_label.scale = Vector2.ZERO
	var pop := create_tween()
	pop.tween_interval(0.6)
	pop.tween_property(message_label, "scale", Vector2.ONE, 0.7)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hint_label.visible = true
	hint_label.modulate.a = 0.0
	create_tween().tween_property(hint_label, "modulate:a", 1.0, 0.5).set_delay(1.8)


func _confetti(from: Vector2) -> void:
	_burst(from, 70, CONFETTI, 900.0, 2.4, 7.0, Vector2.UP, 28.0)


# ---------------------------------------------------------------- fx helpers

func _burst(pos: Vector2, amount: int, colors: Array[Color], speed: float,
		life := 0.6, particle_size := 5.0, dir := Vector2.UP, spread := 180.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 20
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 700)
	p.damping_min = 30.0
	p.damping_max = 90.0
	p.angular_velocity_min = -540.0
	p.angular_velocity_max = 540.0
	p.scale_amount_min = particle_size * 0.6
	p.scale_amount_max = particle_size
	var initial := Gradient.new()
	initial.set_color(0, colors[0])
	initial.set_color(1, colors[colors.size() - 1])
	for i in range(1, colors.size() - 1):
		initial.add_point(float(i) / (colors.size() - 1), colors[i])
	p.color_initial_ramp = initial
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _shake(strength: float, duration: float) -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	shake_tween = create_tween()
	shake_tween.tween_method(func(k: float) -> void:
		position = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * strength * (1.0 - k),
		0.0, 1.0, duration)
	shake_tween.tween_callback(func() -> void: position = Vector2.ZERO)


# ---------------------------------------------------------------- drawing

func _draw_board() -> void:
	var frame := Color(0.16, 0.19, 0.28).lerp(GOLD, frame_glow)
	board_layer.draw_rect(board_rect.grow(8), frame)
	board_layer.draw_rect(board_rect, Color(0.07, 0.08, 0.12))
	board_layer.draw_texture_rect(texture, board_rect, false, Color(1, 1, 1, 0.12))
	for c in range(COLS + 1):
		var x := board_rect.position.x + c * cell_size.x
		board_layer.draw_line(Vector2(x, board_rect.position.y), Vector2(x, board_rect.end.y), Color(1, 1, 1, 0.12))
	for r in range(ROWS + 1):
		var y := board_rect.position.y + r * cell_size.y
		board_layer.draw_line(Vector2(board_rect.position.x, y), Vector2(board_rect.end.x, y), Color(1, 1, 1, 0.12))
	board_layer.draw_rect(TRAY_AREA.grow(10), Color(1, 1, 1, 0.04))
	if held and near_home:
		var ring := _offset(held.outline, held.home)
		board_layer.draw_colored_polygon(ring, Color(GOLD, 0.25))
		ring.append(ring[0])
		board_layer.draw_polyline(ring, GOLD, 3.0, true)


func _offset(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in poly:
		out.append(v + by)
	return out
