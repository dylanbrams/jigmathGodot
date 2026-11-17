class_name UiTheme
extends RefCounted
## Shared look for every menu screen, plus the hover/press "juice" for buttons.

const GOLD := Color(1.0, 0.85, 0.4)
const NAVY := Color(0.10, 0.12, 0.18)
const PANEL := Color(0.14, 0.17, 0.26)
const BUTTON := Color(0.21, 0.26, 0.40)
const BUTTON_HOVER := Color(0.29, 0.35, 0.54)

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(color: Color, radius := 14, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_border_width_all(border_w)
	b.border_color = border
	b.content_margin_left = 22
	b.content_margin_right = 22
	b.content_margin_top = 12
	b.content_margin_bottom = 12
	return b


static func _knob(color: Color) -> ImageTexture:
	var n := 34
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (n - 1) * 0.5
	for y in n:
		for x in n:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = load("res://assets/fonts/Roboto-Regular.ttf")
	t.default_font_size = 26

	t.set_stylebox("normal", "Button", _box(BUTTON))
	t.set_stylebox("hover", "Button", _box(BUTTON_HOVER))
	t.set_stylebox("pressed", "Button", _box(BUTTON.darkened(0.25)))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 14, GOLD, 3))
	t.set_stylebox("disabled", "Button", _box(BUTTON.darkened(0.3)))
	t.set_color("font_color", "Button", Color(0.95, 0.96, 1.0))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)

	t.set_stylebox("panel", "PanelContainer", _box(PANEL, 22, Color(1, 1, 1, 0.08), 2))

	var track := _box(Color(1, 1, 1, 0.14), 6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	t.set_stylebox("slider", "HSlider", track)
	var fill := _box(GOLD.darkened(0.15), 6)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _knob(GOLD))
	t.set_icon("grabber_highlight", "HSlider", _knob(Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _knob(Color(0.5, 0.5, 0.5)))

	t.set_color("font_color", "Label", Color(0.93, 0.95, 1.0))
	t.set_color("font_color", "CheckButton", Color(0.93, 0.95, 1.0))
	return t


## Adds hover swell, press squash and click/hover sounds to a button.
static func juice(b: BaseButton, hover_scale := 1.06) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void:
		_scale_to(b, hover_scale)
		Sfx.play("hover"))
	b.mouse_exited.connect(func() -> void: _scale_to(b, 1.0))
	b.button_down.connect(func() -> void: _scale_to(b, 0.95))
	b.button_up.connect(func() -> void: _scale_to(b, hover_scale if b.is_hovered() else 1.0))
	b.pressed.connect(func() -> void: Sfx.play("click"))


static func _scale_to(c: Control, s: float) -> void:
	if c.has_meta("juice_tween"):
		var old: Tween = c.get_meta("juice_tween")
		if old and old.is_valid():
			old.kill()
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * s, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta("juice_tween", tw)


static func make_button(text: String, min_size := Vector2(300, 64)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	juice(b)
	return b
