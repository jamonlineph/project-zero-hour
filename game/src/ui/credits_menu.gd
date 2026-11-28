class_name CreditsMenu
extends Control
## Credits and legal notices (P4-06): who made the game and its assets, and
## under which licenses (game/data/credits.json, generated from the asset
## manifest by tools/gen_credits.py), plus the Godot Engine's own license
## and third-party notices, which its MIT license asks us to ship.

const CREDITS_PATH: String = "res://data/credits.json"

var _text: RichTextLabel
var _licenses: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.08, 0.07, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Credits"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("normal_font_size", 18)
	_text.add_theme_font_size_override("bold_font_size", 20)
	_text.add_theme_font_override("bold_font", UiTheme.bold_font())
	_text.add_theme_color_override("default_color", UiTheme.TEXT)
	box.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_licenses = _button(row, "Engine licenses", show_engine_licenses)
	_licenses.name = "EngineLicenses"
	_button(row, "Back", queue_free).name = "Back"
	show_credits()


func show_credits() -> void:
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CREDITS_PATH)) if FileAccess.file_exists(CREDITS_PATH) else null
	if not c is Dictionary:
		_text.text = "Credits file missing."
		return
	var d: Dictionary = c
	var t: String = "[b]%s[/b]\nMade by %s.\n%s\n\n" % [d.get("game", ""), d.get("made_by", ""), d.get("note", "")]
	t += "[b]Licenses[/b]\nCode: %s\nArt, sound, maps and data: %s\n\n" % [d.get("code_license", ""), d.get("asset_license", "")]
	t += "[b]Assets[/b]\n"
	for a: Variant in d.get("assets", []):
		var e: Dictionary = a
		t += "%s: %s (%s). License: %s\n" % [e.get("author", ""), e.get("what", ""), e.get("source", ""), e.get("license", "")]
	t += "\n[b]Made with[/b]\n"
	for tool: Variant in d.get("tools", []):
		t += "%s\n" % str(tool)
	_text.text = t
	_licenses.text = "Engine licenses"


## The engine's license and every third-party component it includes.
func show_engine_licenses() -> void:
	if _licenses.text == "Credits":
		show_credits()
		return
	var t: String = "[b]Godot Engine[/b]\n%s\n\n[b]Third-party components in the engine[/b]\n" % Engine.get_license_text()
	for info: Dictionary in Engine.get_copyright_info():
		t += "\n[b]%s[/b]\n" % info.get("name", "")
		for part: Dictionary in info.get("parts", []):
			for line: String in part.get("copyright", []):
				t += "© %s\n" % line
			t += "License: %s\n" % part.get("license", "")
	_text.text = t
	_text.scroll_to_line(0)
	_licenses.text = "Credits"


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
