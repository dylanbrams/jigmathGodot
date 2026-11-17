extends Control
## Home screen: Play -> puzzle select, Sound options, Quit.


func _ready() -> void:
	theme = UiTheme.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(MenuBackground.new())

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "JigMath"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 132)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1))
	title.add_theme_constant_override("outline_size", 18)
	box.add_child(title)

	var tagline := Label.new()
	tagline.text = "Solve the sums. Build the picture."
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 28)
	tagline.modulate.a = 0.75
	box.add_child(tagline)

	box.add_child(_spacer(26))

	var buttons: Array[Button] = []
	var play := UiTheme.make_button("Play", Vector2(340, 72))
	play.pressed.connect(Game.go_select)
	buttons.append(play)
	var sound := UiTheme.make_button("Sound", Vector2(340, 72))
	sound.pressed.connect(func() -> void: add_child(SettingsPanel.new()))
	buttons.append(sound)
	if OS.get_name() != "Web":
		var quit := UiTheme.make_button("Quit", Vector2(340, 72))
		quit.pressed.connect(func() -> void: get_tree().quit())
		buttons.append(quit)
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
	play.grab_focus()

	_animate_in(title, tagline, buttons)


func _spacer(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size.y = h
	return s


func _animate_in(title: Label, tagline: Label, buttons: Array[Button]) -> void:
	# Title drops in with an elastic bounce, then the rest fades up in sequence.
	await get_tree().process_frame
	title.pivot_offset = title.size * 0.5
	title.scale = Vector2.ZERO
	create_tween().tween_property(title, "scale", Vector2.ONE, 0.9)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tagline.modulate.a = 0.0
	create_tween().tween_property(tagline, "modulate:a", 0.75, 0.5).set_delay(0.4)
	for i in buttons.size():
		var b := buttons[i]
		b.modulate.a = 0.0
		var t := create_tween().set_parallel(true)
		t.tween_property(b, "modulate:a", 1.0, 0.35).set_delay(0.5 + i * 0.1)
		t.tween_property(b, "position:y", b.position.y, 0.35).from(b.position.y + 30.0)\
			.set_delay(0.5 + i * 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
