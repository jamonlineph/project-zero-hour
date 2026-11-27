class_name UiTheme
extends RefCounted
## The game's UI look (P2-17): dark olive panels with steel-olive frames and
## amber highlights, in the classic 2000s military RTS style
## (docs/04-art-pipeline.md), with the OFL font Inter. Built in code and set
## on the root window, so every menu and HUD control picks it up.
## Sizes are for the 1280x720 canvas, which phones scale down: body text is
## at least 16 px and buttons at least 44 px tall (touch targets).

const FONT_REGULAR: String = "res://assets/fonts/Inter-Regular.otf"
const FONT_SEMIBOLD: String = "res://assets/fonts/Inter-SemiBold.otf"
const FONT_BOLD: String = "res://assets/fonts/Inter-Bold.otf"

const PANEL := Color(0.10, 0.12, 0.09, 0.94)
const BUTTON := Color(0.17, 0.20, 0.15)
const BUTTON_HOVER := Color(0.22, 0.26, 0.18)
const BUTTON_PRESSED := Color(0.12, 0.14, 0.10)
const FRAME := Color(0.40, 0.43, 0.32)         ## steel-olive frame
const FRAME_DARK := Color(0.07, 0.08, 0.06)
const ACCENT := Color(0.96, 0.74, 0.26)        ## amber: hover, focus, titles
const TEXT := Color(0.92, 0.93, 0.86)
const TEXT_DIM := Color(0.55, 0.57, 0.50)
const BODY_SIZE: int = 18

static var _theme: Theme


## The shared theme (built once).
static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Sets the theme on the window, so every Control under it uses it.
static func apply(tree: SceneTree) -> void:
	tree.root.theme = get_theme()


## Controls directly under a CanvasLayer don't inherit the window's theme
## (Godot stops theme propagation at a CanvasLayer), so the layer's children
## get it set directly, now and whenever one is added.
static func apply_to_layer(layer: CanvasLayer) -> void:
	for child: Node in layer.get_children():
		if child is Control:
			(child as Control).theme = get_theme()
	layer.child_entered_tree.connect(func(child: Node) -> void:
		if child is Control and child.get_parent() == layer:
			(child as Control).theme = get_theme())


static func bold_font() -> Font:
	return load(FONT_BOLD) as Font


## A framed panel (used by the HUD for the minimap and selection boxes).
static func panel_box(fill: Color = PANEL) -> StyleBoxFlat:
	var s := _box(fill, FRAME, 2)
	s.set_content_margin_all(8)
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = load(FONT_REGULAR) as Font
	t.default_font_size = BODY_SIZE
	var semibold: Font = load(FONT_SEMIBOLD) as Font

	# Buttons: framed plates; amber border on hover and focus, darker when pressed.
	var normal := _box(BUTTON, FRAME, 2)
	var hover := _box(BUTTON_HOVER, ACCENT, 2)
	var pressed := _box(BUTTON_PRESSED, ACCENT.darkened(0.3), 2)
	pressed.shadow_size = 0
	var disabled := _box(BUTTON.darkened(0.35), FRAME_DARK, 2)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_border_width_all(2)
	focus.border_color = ACCENT
	for s: StyleBoxFlat in [normal, hover, pressed, disabled]:
		s.content_margin_left = 14
		s.content_margin_right = 14
		s.content_margin_top = 6
		s.content_margin_bottom = 6
	for type: String in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, ACCENT)
		t.set_color("font_pressed_color", type, ACCENT)
		t.set_color("font_hover_pressed_color", type, ACCENT)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_disabled_color", type, TEXT_DIM)
		t.set_color("icon_disabled_color", type, Color(1, 1, 1, 0.35))
		t.set_font("font", type, semibold)

	# Panels.
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "Panel", panel_box())
	var popup := panel_box()
	popup.set_content_margin_all(12)
	t.set_stylebox("panel", "PopupPanel", popup)

	# Text.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.75))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	# Sliders and bars (settings, power).
	var track := _box(Color(0.06, 0.07, 0.05), FRAME_DARK, 1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT.darkened(0.15)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_color("font_color", "ProgressBar", TEXT)

	# Scroll bars stay thin but easy to grab.
	var grabber := _box(FRAME, FRAME.lightened(0.2), 1)
	for type: String in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", type, track)
		t.set_stylebox("grabber", type, grabber)
		t.set_stylebox("grabber_highlight", type, _box(ACCENT.darkened(0.2), ACCENT, 1))
		t.set_stylebox("grabber_pressed", type, _box(ACCENT, ACCENT, 1))

	# Tooltips.
	t.set_stylebox("panel", "TooltipPanel", panel_box(Color(0.06, 0.07, 0.05, 0.96)))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)
	return t


## A flat box with a border and a small drop shadow, like a metal plate.
static func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.set_border_width_all(width)
	s.border_color = border
	s.set_corner_radius_all(2)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 2
	s.shadow_offset = Vector2(1, 2)
	return s
