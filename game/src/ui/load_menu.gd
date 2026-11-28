class_name LoadMenu
extends Control
## Lists saved games, newest first (P3-22). Picking one emits `chosen` with
## the save's data; Back closes the list.

signal chosen(data: Dictionary)

var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.08, 0.07, 1.0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	center.add_child(box)
	var title := Label.new()
	title.text = "Load game"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 420)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(560, 50)
	back.pressed.connect(queue_free)
	box.add_child(back)
	refresh()


func refresh() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var saves: Array[Dictionary] = SaveGame.list()
	if saves.is_empty():
		var none := Label.new()
		none.text = "No saved games yet. Save from the pause menu during a match."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size.x = 540
		_list.add_child(none)
		return
	for s: Dictionary in saves:
		var b := Button.new()
		var minutes: int = int(s["game_seconds"]) / 60
		b.text = Loc.t("%s   ·   %s   ·   %d:%02d into the match") % [str(s["saved_at"]).replace("T", " "),
			str(s["map"]).capitalize(), minutes, int(s["game_seconds"]) % 60]
		b.custom_minimum_size = Vector2(540, 50)
		b.pressed.connect(func() -> void: chosen.emit(SaveGame.read(str(s["path"]))))
		_list.add_child(b)
