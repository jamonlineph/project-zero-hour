class_name CommandGrid
extends GridContainer
## The 3x4 command/build grid (P1-25). Each slot has a grid hotkey:
##   Q W E R
##   A S D F
##   Z X C V
## Entries are dictionaries: {"label", "icon" (Texture2D or null), "enabled",
## "action" (Callable), optional "alt_action" (Callable, right-click / long
## press, for example cancel), optional "tooltip"}.

## Emitted after a slot's action ran (the game plays a click).
signal activated(slot: int)

const SLOT_KEYS: Array[Key] = [KEY_Q, KEY_W, KEY_E, KEY_R, KEY_A, KEY_S, KEY_D, KEY_F, KEY_Z, KEY_X, KEY_C, KEY_V]
const SLOT_LABELS: Array[String] = ["Q", "W", "E", "R", "A", "S", "D", "F", "Z", "X", "C", "V"]
const BUTTON_SIZE := Vector2(88, 80)   ## big enough for an icon and two lines (P2-17)
const ICON_SIZE: int = 40

var _buttons: Array[Button] = []
var _hotkeys: Array[Label] = []
var _entries: Array[Dictionary] = []


func _ready() -> void:
	columns = 4
	for i: int in 12:
		var b := Button.new()
		b.custom_minimum_size = BUTTON_SIZE
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", ICON_SIZE)
		b.add_theme_font_size_override("font_size", 13)   # readable on phones (P2-17)
		b.add_theme_constant_override("line_spacing", -2)
		# The hotkey sits in the top-left corner, so the label keeps two lines.
		var key := Label.new()
		key.text = SLOT_LABELS[i]
		key.position = Vector2(5, 2)
		key.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color", UiTheme.ACCENT)
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(key)
		_hotkeys.append(key)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pressed.bind(i))
		b.gui_input.connect(_on_gui_input.bind(i))
		add_child(b)
		_buttons.append(b)
	set_entries([])


func set_entries(entries: Array[Dictionary]) -> void:
	_entries = entries
	for i: int in 12:
		var b: Button = _buttons[i]
		if i >= entries.size():
			b.text = ""
			b.icon = null
			b.disabled = true
			b.tooltip_text = ""
			b.modulate = Color(1, 1, 1, 0.25)
			_hotkeys[i].visible = false
			continue
		var e: Dictionary = entries[i]
		b.text = str(e.get("label", ""))
		_hotkeys[i].visible = true
		b.icon = e.get("icon", null)
		b.disabled = not bool(e.get("enabled", true))
		b.tooltip_text = Loc.t("%s  (hotkey %s)") % [str(e.get("tooltip", e.get("label", ""))), SLOT_LABELS[i]]
		b.modulate = Color.WHITE


func entry_count() -> int:
	return _entries.size()


## Runs a slot's action, as if its button were pressed. Returns true if done.
func activate(slot: int, alternate: bool = false) -> bool:
	if slot < 0 or slot >= _entries.size():
		return false
	var e: Dictionary = _entries[slot]
	if not bool(e.get("enabled", true)) and not alternate:
		return false
	var key: String = "alt_action" if alternate else "action"
	var action: Variant = e.get(key, null)
	if action is Callable and (action as Callable).is_valid():
		(action as Callable).call()
		activated.emit(slot)
		return true
	return false


## Handles a grid hotkey. Returns true if the key belonged to a filled slot.
func handle_key(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var k := event as InputEventKey
	if not k.pressed or k.echo or k.ctrl_pressed or k.alt_pressed:
		return false
	var slot: int = SLOT_KEYS.find(k.physical_keycode)
	if slot < 0 or slot >= _entries.size():
		return false
	activate(slot, k.shift_pressed)
	return true


func _on_pressed(slot: int) -> void:
	activate(slot)


func _on_gui_input(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		activate(slot, true)
