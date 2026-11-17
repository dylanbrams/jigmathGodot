class_name SettingsPanel
extends Control
## Modal sound-options overlay. Add it as a child of any screen; it frees itself on close.

signal closed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Sound"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_add_slider(box, "Master volume", Settings.master_volume, "pick",
		func(v: float) -> void: Settings.master_volume = v)
	_add_slider(box, "Sound effects", Settings.sfx_volume, "snap",
		func(v: float) -> void: Settings.sfx_volume = v)

	var mute := CheckButton.new()
	mute.text = "Mute all sound"
	mute.button_pressed = Settings.muted
	mute.toggled.connect(func(on: bool) -> void:
		Settings.muted = on
		Settings.apply()
		Settings.save()
		Sfx.play("click"))
	box.add_child(mute)

	var done := UiTheme.make_button("Done", Vector2(240, 60))
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(close)
	box.add_child(done)
	done.grab_focus()

	# Pop in.
	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	panel.scale = Vector2.ONE * 0.9
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 1.0, 0.15)
	t.tween_property(panel, "modulate:a", 1.0, 0.15)
	t.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _add_slider(parent: Control, label_text: String, value: float, preview: String, setter: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.custom_minimum_size = Vector2(300, 34)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var pct := Label.new()
	pct.custom_minimum_size.x = 70
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.text = "%d%%" % roundi(value * 100.0)
	row.add_child(pct)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		Settings.apply()
		pct.text = "%d%%" % roundi(v * 100.0))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		Settings.save()
		Sfx.play(preview))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	Settings.save()
	closed.emit()
	queue_free()
