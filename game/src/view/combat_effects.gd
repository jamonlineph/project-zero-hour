class_name CombatEffects
extends Node3D
## Pooled combat effects (P1-28): muzzle flashes, tracers, explosions, smoke
## and death blasts. Every effect type has a fixed pool that is reused round
## robin, so a big fight never allocates nodes. View only: driven by sim
## events through GameView.play_events().
##
## Budget: about 50 explosions per second on a mid-range phone (the pools
## below cover that with room to spare). The battery-saver setting halves
## particle amounts.

enum Kind { MUZZLE, EXPLOSION, SMOKE, DEATH }

const POOL_SIZES: Dictionary = {Kind.MUZZLE: 32, Kind.EXPLOSION: 48, Kind.SMOKE: 24, Kind.DEATH: 16}
const TRACER_POOL: int = 32
const TRACER_SECONDS: float = 0.09
const TRACER_COLOR := Color(1.0, 0.85, 0.45)
const LASER_COLOR := Color(0.35, 0.9, 1.0)   ## counter-drone lasers and microwave

var _pools: Dictionary[int, Array] = {}
var _next: Dictionary[int, int] = {}
var _tracers: Array[MeshInstance3D] = []
var _next_tracer: int = 0
var played: int = 0          ## effects started (for tests and the perf harness)


func _ready() -> void:
	name = "CombatEffects"
	var saver: bool = GameSettings.current().battery_saver
	for kind: int in POOL_SIZES:
		var pool: Array[GPUParticles3D] = []
		for i: int in POOL_SIZES[kind]:
			var p: GPUParticles3D = _make(kind, saver)
			add_child(p)
			pool.append(p)
		_pools[kind] = pool
		_next[kind] = 0
	for i: int in TRACER_POOL:
		var t := _make_tracer()
		add_child(t)
		_tracers.append(t)


func pool_size(kind: Kind) -> int:
	return (_pools.get(kind, []) as Array).size()


## Starts one effect at a world position. `size` scales it (1 = default).
func play(kind: Kind, at: Vector3, size: float = 1.0) -> void:
	var pool: Array = _pools[kind]
	var i: int = _next[kind]
	_next[kind] = (i + 1) % pool.size()
	var p: GPUParticles3D = pool[i]
	p.position = at
	p.scale = Vector3.ONE * size
	p.restart()
	played += 1


## A short bright streak from a muzzle to the target.
func tracer(from: Vector3, to: Vector3, color: Color = TRACER_COLOR) -> void:
	var length: float = from.distance_to(to)
	if length < 0.5:
		return
	var t: MeshInstance3D = _tracers[_next_tracer]
	_next_tracer = (_next_tracer + 1) % _tracers.size()
	t.position = (from + to) * 0.5
	t.look_at_from_position(t.position, to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	t.scale = Vector3(1.0, 1.0, length)
	t.visible = true
	var mat := t.material_override as StandardMaterial3D
	mat.albedo_color = Color(color, 1.0)
	var tween := t.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, TRACER_SECONDS)
	tween.tween_callback(func() -> void: t.visible = false)
	played += 1


func _make(kind: int, saver: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.gravity = Vector3(0, -2.0, 0)
	var quad := QuadMesh.new()
	var draw := StandardMaterial3D.new()
	draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	draw.vertex_color_use_as_albedo = true
	draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ramp := Gradient.new()
	match kind:
		Kind.MUZZLE:
			p.amount = 4
			p.lifetime = 0.08
			m.spread = 25.0
			m.initial_velocity_min = 2.0
			m.initial_velocity_max = 4.0
			m.scale_min = 0.6
			m.scale_max = 1.0
			quad.size = Vector2(0.6, 0.6)
			draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			ramp.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.5, 0.1, 0.0)])
		Kind.EXPLOSION:
			p.amount = 12
			p.lifetime = 0.5
			m.spread = 80.0
			m.initial_velocity_min = 3.0
			m.initial_velocity_max = 7.0
			m.scale_min = 0.8
			m.scale_max = 1.6
			quad.size = Vector2(1.2, 1.2)
			draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.4, 1.0), Color(0.9, 0.3, 0.05, 0.8), Color(0.2, 0.2, 0.2, 0.0)])
		Kind.SMOKE:
			p.amount = 10
			p.lifetime = 2.5
			p.explosiveness = 0.6
			m.spread = 30.0
			m.gravity = Vector3(0.3, 0.8, 0)
			m.initial_velocity_min = 0.5
			m.initial_velocity_max = 1.5
			m.scale_min = 1.5
			m.scale_max = 3.0
			quad.size = Vector2(1.5, 1.5)
			ramp.colors = PackedColorArray([Color(0.25, 0.24, 0.22, 0.7), Color(0.4, 0.4, 0.4, 0.0)])
		Kind.DEATH:
			p.amount = 24
			p.lifetime = 0.9
			m.spread = 90.0
			m.initial_velocity_min = 4.0
			m.initial_velocity_max = 10.0
			m.scale_min = 1.0
			m.scale_max = 2.4
			quad.size = Vector2(1.6, 1.6)
			draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 1.0), Color(1.0, 0.4, 0.05, 0.9), Color(0.15, 0.15, 0.15, 0.0)])
	if saver:
		p.amount = maxi(2, p.amount / 2)
	var tex := GradientTexture1D.new()
	tex.gradient = ramp
	m.color_ramp = tex
	p.process_material = m
	quad.material = draw
	p.draw_pass_1 = quad
	# Effects can fly a little way from their origin; keep them from culling.
	p.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 24, 24))
	return p


func _make_tracer() -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.85, 0.45, 0.0)
	var t := MeshInstance3D.new()
	t.mesh = mesh
	t.material_override = mat
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.visible = false
	return t
