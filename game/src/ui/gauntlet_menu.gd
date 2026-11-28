class_name GauntletMenu
extends Control
## The Gauntlet screen (P4-03): the seven commanders, which are beaten, and a
## button to fight the next one with the main menu's faction and credits.

var menu: Control   ## the main menu (content, faction, credits)
var _list: VBoxContainer


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
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "Gauntlet: seven commanders"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_button(row, "Start over", func() -> void: Gauntlet.reset(); refresh()).name = "Reset"
	_button(row, "Back", queue_free).name = "Back"
	refresh()


func refresh() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var done: int = Gauntlet.beaten()
	var all: Array = Gauntlet.commanders()
	for i: int in all.size():
		var c: Dictionary = all[i]
		var line := HBoxContainer.new()
		_list.add_child(line)
		var text := Label.new()
		var map: MapDef = (menu.get("content") as ContentDb).get_map(str(c["map"])) if menu != null else null
		text.text = "%d. %s: %s, %s, %s, on %s\n%s" % [i + 1, c["call_sign"], MatchConfig.FACTIONS.get(str(c["faction"]), c["faction"]),
			str(c["personality"]).capitalize(), str(c["difficulty"]).capitalize(), map.name if map != null else c["map"], c["intro"]]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.modulate = Color(1, 1, 1, 1) if i <= done else Color(1, 1, 1, 0.45)
		line.add_child(text)
		var b := Button.new()
		b.name = "Fight_%d" % i
		b.custom_minimum_size = Vector2(150, 48)
		b.focus_mode = Control.FOCUS_NONE
		if i < done:
			b.text = "Beaten"
			b.disabled = true
		elif i == done:
			b.text = "Fight"
			var step: int = i
			b.pressed.connect(func() -> void: fight(step))
		else:
			b.text = "Locked"
			b.disabled = true
		line.add_child(b)
	if done >= all.size():
		var won := Label.new()
		won.text = "All seven commanders beaten. Well done, commander."
		won.add_theme_color_override("font_color", UiTheme.ACCENT)
		_list.add_child(won)


func fight(step: int) -> void:
	var content: ContentDb = menu.get("content")
	var sc: Dictionary = Gauntlet.scenario(content, step, str(menu.get("faction")),
		content.skirmish_credits[int(menu.get("credits_index"))])
	menu.call("_start", sc)


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 50)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
