class_name UnitStatus
extends Node3D
## Health bar and veterancy pips floating above a unit or building (P1-22).
## Camera-facing quads; the bar shows only when the entity is damaged or
## selected, the pips whenever it has a veterancy rank. Reads sim state only.

const BAR_HEIGHT: float = 0.3
const PIP_SIZE: float = 0.32
const PIP_GAP: float = 0.42

static var _bg_material: StandardMaterial3D
static var _fill_materials: Array[StandardMaterial3D] = []
static var _pip_material: StandardMaterial3D

var bar_width: float = 2.0
var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mesh: QuadMesh
var _pips: Array[MeshInstance3D] = []
var _last_hp: int = -1
var _last_max: int = -1
var _last_rank: int = -1
var _selected: bool = false


func setup(width_m: float, height_m: float) -> void:
	name = "Status"
	bar_width = width_m
	position.y = height_m
	_ensure_materials()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(bar_width + 0.12, BAR_HEIGHT + 0.12)
	_bg = _quad("Bar", bg_mesh, _bg_material)
	_fill_mesh = QuadMesh.new()
	_fill = _quad("Fill", _fill_mesh, _fill_materials[0])
	_bg.visible = false
	_fill.visible = false


## Call every frame; only rebuilds the bar when something changed.
func refresh(hp: int, max_hp: int, vet_rank: int, selected: bool) -> void:
	if hp == _last_hp and max_hp == _last_max and vet_rank == _last_rank and selected == _selected:
		return
	_last_hp = hp
	_last_max = max_hp
	_last_rank = vet_rank
	_selected = selected
	var ratio: float = clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var show_bar: bool = selected or hp < max_hp
	_bg.visible = show_bar
	_fill.visible = show_bar
	if show_bar:
		var w: float = bar_width * ratio
		_fill_mesh.size = Vector2(maxf(w, 0.01), BAR_HEIGHT)
		# Keep the bar anchored at its left end as it shrinks.
		_fill_mesh.center_offset = Vector3(-(bar_width - w) * 0.5, 0.0, 0.0)
		var color_index: int = 0 if ratio > 0.6 else (1 if ratio > 0.3 else 2)
		_fill.material_override = _fill_materials[color_index]
	_set_pips(vet_rank)


func bar_visible() -> bool:
	return _bg.visible


func health_ratio() -> float:
	return _fill_mesh.size.x / bar_width if _fill.visible else 1.0


func pip_count() -> int:
	var n: int = 0
	for p: MeshInstance3D in _pips:
		if p.visible:
			n += 1
	return n


func _set_pips(rank: int) -> void:
	while _pips.size() < rank:
		var mesh := QuadMesh.new()
		mesh.size = Vector2(PIP_SIZE, PIP_SIZE)
		mesh.center_offset = Vector3(-bar_width * 0.5 + PIP_SIZE * 0.5 + _pips.size() * PIP_GAP, BAR_HEIGHT + 0.3, 0.0)
		_pips.append(_quad("Pip%d" % _pips.size(), mesh, _pip_material))
	for i: int in _pips.size():
		_pips[i].visible = i < rank


func _quad(node_name: String, mesh: QuadMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static func _ensure_materials() -> void:
	if _bg_material != null:
		return
	_bg_material = _billboard(Color(0.05, 0.05, 0.05, 0.85), 0)
	for c: Color in [Color(0.3, 0.95, 0.35), Color(0.95, 0.8, 0.2), Color(0.95, 0.25, 0.2)]:
		_fill_materials.append(_billboard(c, 1))
	_pip_material = _billboard(Color(1.0, 0.82, 0.25), 1)


static func _billboard(color: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = priority
	m.albedo_color = color
	return m
