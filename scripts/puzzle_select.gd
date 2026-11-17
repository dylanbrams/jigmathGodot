extends Control
## Puzzle select: one tab per image section, a grid of thumbnails per tab.

const THUMB_SIZE := Vector2(262, 196)
const COLUMNS := 4

var _grid: GridContainer
var _tab_buttons := {} # section key -> Button
var _group := ButtonGroup.new()


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackground.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	# Header: back button + title.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	root.add_child(header)
	var back := UiTheme.make_button("Back", Vector2(140, 56))
	back.pressed.connect(Game.go_home)
	header.add_child(back)
	var title := Label.new()
	title.text = "Choose a puzzle"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(title)

	# Section tabs.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	root.add_child(tabs)
	for s in Game.sections:
		var b := UiTheme.make_button("%s  (%s)" % [s.title, _progress_text(s)], Vector2(0, 52))
		b.toggle_mode = true
		b.button_group = _group
		b.pressed.connect(_show_section.bind(s.key))
		tabs.add_child(b)
		_tab_buttons[s.key] = b

	# Thumbnail grid.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 22)
	_grid.add_theme_constant_override("v_separation", 22)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_grid)

	if Game.sections.is_empty():
		return
	var start: String = Game.current_section if _tab_buttons.has(Game.current_section) else Game.sections[0].key
	_tab_buttons[start].button_pressed = true
	_show_section(start)


func _progress_text(section: Dictionary) -> String:
	var done := 0
	for path: String in section.images:
		if Settings.is_completed(path):
			done += 1
	return "%d/%d" % [done, section.images.size()]


func _show_section(key: String) -> void:
	Game.current_section = key
	for c in _grid.get_children():
		c.queue_free()
	var images: Array = Game.get_section(key).images
	for i in images.size():
		var thumb := _make_thumb(images[i])
		_grid.add_child(thumb)
		# staggered pop-in
		thumb.modulate.a = 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(thumb, "modulate:a", 1.0, 0.25).set_delay(i * 0.04)
		t.tween_property(thumb, "scale", Vector2.ONE, 0.3).from(Vector2.ONE * 0.85)\
			.set_delay(i * 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _make_thumb(path: String) -> Button:
	var b := UiTheme.make_button("", THUMB_SIZE)
	b.pressed.connect(func() -> void: Game.start_puzzle(Game.current_section, path))

	var pic := TextureRect.new()
	pic.texture = load(path)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.clip_contents = true
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 8
	pic.offset_top = 8
	pic.offset_right = -8
	pic.offset_bottom = -42
	b.add_child(pic)

	var name_label := Label.new()
	name_label.text = Game.pretty_name(path)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_top = -40
	name_label.offset_bottom = -4
	b.add_child(name_label)

	if Settings.is_completed(path):
		var star := Label.new()
		star.text = "Solved"
		star.add_theme_font_size_override("font_size", 18)
		star.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tag := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UiTheme.GOLD
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		tag.add_theme_stylebox_override("panel", sb)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.add_child(star)
		tag.position = Vector2(16, 16)
		b.add_child(tag)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Game.go_home()
