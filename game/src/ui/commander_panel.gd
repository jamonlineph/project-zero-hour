class_name CommanderPanel
extends Control
## Commander power tree (P2-09b): the faction's powers grouped by the rank
## that opens them, with Choose buttons while points are available.

var runner: SimRunner
var player_id: int = 1
var _list: VBoxContainer
var _title: Label
var _shown: Vector2i = Vector2i(-1, -1)   ## rank and powers shown; refresh when they change


func setup(sim_runner: SimRunner, local_player: int) -> void:
	name = "CommanderPanel"
	runner = sim_runner
	player_id = local_player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.06, 0.05, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 28)
	outer.add_child(_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var close := Button.new()
	close.name = "Close"
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 52)
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(queue_free)
	outer.add_child(close)
	refresh()


## A rank gained, or a choice landing a few ticks after the click, shows
## without reopening the panel.
func _process(_delta: float) -> void:
	var player: SimPlayer = runner.world.get_player(player_id)
	if Vector2i(player.rank, player.powers.size()) != _shown:
		refresh()


func refresh() -> void:
	for c: Node in _list.get_children():
		c.queue_free()
	var world: SimWorld = runner.world
	var player: SimPlayer = world.get_player(player_id)
	_shown = Vector2i(player.rank, player.powers.size())
	var points: int = CommanderPowers.points(player)
	_title.text = "Commander: rank %d, %d point%s to spend" % [player.rank, points, "" if points == 1 else "s"]
	var tier: int = -1
	for def: PowerDef in world.content.powers_for(player.faction):
		if def.tier != tier:
			tier = def.tier
			var h := Label.new()
			h.text = "Rank %d" % tier
			h.add_theme_font_size_override("font_size", 20)
			h.modulate = Color(0.75, 0.95, 0.8)
			_list.add_child(h)
		var row := HBoxContainer.new()
		_list.add_child(row)
		var text := Label.new()
		text.text = "%s: %s" % [def.name, def.description]
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var b := Button.new()
		b.name = "Choose_" + def.id
		b.custom_minimum_size = Vector2(150, 48)
		b.focus_mode = Control.FOCUS_NONE
		if player.powers.has(def.id):
			b.text = "Chosen"
			b.disabled = true
		elif player.rank < def.tier:
			b.text = "Rank %d" % def.tier
			b.disabled = true
		elif def.group != "" and CommanderPowers.in_group(world, player, def.group):
			b.text = "Ruled out"   # another doctrine was chosen (P3-12b)
			b.disabled = true
		else:
			b.text = "Choose"
			b.disabled = points <= 0
			var id: String = def.id
			b.pressed.connect(func() -> void:
				runner.submit(SimCommand.make_choose_power(id))
				refresh.call_deferred())
		row.add_child(b)
