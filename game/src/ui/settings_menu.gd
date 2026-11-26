class_name SettingsMenu
extends Control
## Settings screen (P1-35), opened from the main menu and the pause menu.
## Every change applies at once and is saved to user://settings.cfg.

signal closed

const ACTION_NAMES: Dictionary = {
	"cam_left": "Camera left", "cam_right": "Camera right",
	"cam_forward": "Camera forward", "cam_back": "Camera back",
	"cam_rotate_left": "Rotate camera left", "cam_rotate_right": "Rotate camera right",
	"cam_zoom_in": "Zoom in", "cam_zoom_out": "Zoom out",
	"cmd_stop": "Stop", "cmd_attack_move": "Attack-move", "cmd_hold": "Hold position", "cmd_guard": "Guard",
	"toggle_help": "Show or hide help",
}

var settings: GameSettings
var _rows: VBoxContainer
var _waiting_action: String = ""
var _buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	settings = GameSettings.current()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.08, 0.07, 0.96)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 36)
	outer.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_rows)
	_build_rows()
	var back := _button(outer, "Back", close)
	back.name = "Back"


func close() -> void:
	settings.save()
	closed.emit()
	queue_free()


func _build_rows() -> void:
	for c: Node in _rows.get_children():
		c.queue_free()
	_buttons.clear()
	_header("Display")
	_cycle("Render scale", "%d%%" % roundi(settings.render_scale * 100.0), func() -> void:
		settings.render_scale = _next(GameSettings.RENDER_SCALES, settings.render_scale))
	_cycle("Frame rate limit", "Unlimited" if settings.fps_cap == 0 else "%d fps" % settings.fps_cap, func() -> void:
		var i: int = GameSettings.FPS_CHOICES.find(settings.fps_cap)
		settings.fps_cap = GameSettings.FPS_CHOICES[(i + 1) % GameSettings.FPS_CHOICES.size()])
	_cycle("Shadows", "On" if settings.shadows else "Off", func() -> void: settings.shadows = not settings.shadows)
	_cycle("Battery saver (30 fps, lower resolution, no shadows)", "On" if settings.battery_saver else "Off",
		func() -> void: settings.battery_saver = not settings.battery_saver).name = "BatterySaver"
	_cycle("Interface size", "%d%%" % roundi(settings.ui_scale * 100.0), func() -> void:
		settings.ui_scale = _next(GameSettings.UI_SCALES, settings.ui_scale))
	_header("Controls")
	_cycle("Pan at the screen edge (mouse)", "On" if settings.edge_pan else "Off",
		func() -> void: settings.edge_pan = not settings.edge_pan)
	for action: String in InputActions.BINDINGS:
		var b := _cycle(ACTION_NAMES.get(action, action), OS.get_keycode_string(settings.key_for(action) as Key),
			func() -> void: _wait_for_key(action))
		_buttons[action] = b
	_cycle("Reset all keys", "Reset", func() -> void: settings.reset_bindings())
	_header("Sound")
	for bus: String in GameSettings.BUSES:
		_slider(bus, bus)


## A row: label on the left, a button on the right that runs `action`, then
## applies, saves and redraws.
func _cycle(label: String, value: String, action: Callable) -> Button:
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var b := _button(row, value, func() -> void:
		action.call()
		_changed())
	b.custom_minimum_size = Vector2(200, 48)
	return b


func _slider(label: String, bus: String) -> void:
	var row := HBoxContainer.new()
	_rows.add_child(row)
	var l := Label.new()
	l.text = "%s volume" % label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 18)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = settings.volumes.get(bus, 1.0)
	s.custom_minimum_size = Vector2(200, 48)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void:
		settings.volumes[bus] = v
		settings.apply(get_tree()))
	row.add_child(s)


func _header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.modulate = Color(0.75, 0.95, 0.8)
	_rows.add_child(l)


func _changed() -> void:
	if _waiting_action != "":
		return
	settings.apply(get_tree())
	settings.save()
	_build_rows.call_deferred()


func _wait_for_key(action: String) -> void:
	_waiting_action = action
	_buttons[action].text = "Press a key..."


func _input(event: InputEvent) -> void:
	if _waiting_action == "" or not (event is InputEventKey) or not event.pressed:
		return
	var key := event as InputEventKey
	get_viewport().set_input_as_handled()
	var action: String = _waiting_action
	_waiting_action = ""
	if key.physical_keycode != KEY_ESCAPE:
		settings.rebind(action, key.physical_keycode)
	_changed()


static func _next(choices: Array[float], value: float) -> float:
	for c: float in choices:
		if c > value + 0.001:
			return c
	return choices[0]


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 18)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b
