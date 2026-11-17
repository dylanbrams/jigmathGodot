class_name PauseMenu
extends Control
## In-game pause overlay: Resume / Sound / Puzzle select / Main menu. Frees itself on resume.

signal resumed

var _settings_open := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 44)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := UiTheme.make_button("Resume")
	resume.pressed.connect(close)
	box.add_child(resume)
	var sound := UiTheme.make_button("Sound")
	sound.pressed.connect(_open_settings)
	box.add_child(sound)
	var select := UiTheme.make_button("Puzzle select")
	select.pressed.connect(Game.go_select)
	box.add_child(select)
	var home := UiTheme.make_button("Main menu")
	home.pressed.connect(Game.go_home)
	box.add_child(home)
	resume.grab_focus()

	dim.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	panel.scale = Vector2.ONE * 0.9
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "modulate:a", 1.0, 0.15)
	t.tween_property(panel, "modulate:a", 1.0, 0.15)
	t.tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_settings() -> void:
	_settings_open = true
	var panel := SettingsPanel.new()
	panel.closed.connect(func() -> void: _settings_open = false)
	add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _settings_open:
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	resumed.emit()
	queue_free()
