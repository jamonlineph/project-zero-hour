class_name InfantryAnimator
extends Node
## Plays the shared infantry animations (P2-16, made by blender/sf_rig.py)
## from sim state, through an AnimationTree: a blend tree with one Transition
## node that has an input per animation and cross-fades between them.
## View only: reads SimEntity, never writes it.

const STATES: Array[String] = ["idle", "walk", "run", "aim", "fire", "prone", "death_1", "death_2", "enter_building"]
const LOOPING: Array[String] = ["idle", "walk", "run", "aim", "fire", "prone"]
const XFADE_S: float = 0.15
const FIRE_HOLD_S: float = 0.45   ## how long "fire" shows after a shot

var state: String = ""
var _tree: AnimationTree
var _fired_left: float = 0.0


## An animator for an infantry model, or null if the model has no rig or is
## missing one of the animations (placeholders made before P2-16).
static func attach_to(model: Node3D) -> InfantryAnimator:
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return null
	for s: String in STATES:
		if not player.has_animation(s):
			return null
	var a := InfantryAnimator.new()
	a.name = "InfantryAnimator"
	model.add_child(a)
	a._build(player)
	return a


## The animation for a soldier's sim state. `fired` = shot in the last moment.
static func state_for(e: SimEntity, fired: bool) -> String:
	if e.dead:
		return "death_1" if e.id % 2 == 0 else "death_2"
	var moving: bool = e.mover != null and (e.mover.has_target or e.mover.needs_path)
	if e.order == SimEntity.Order.HOLD and not moving:
		return "prone"
	if moving:
		return "walk" if e.order == SimEntity.Order.ATTACK_MOVE else "run"
	if fired:
		return "fire"
	for w: SimWeapon in e.weapons:
		if w.target_id != 0:
			return "aim"
	return "idle"


func _build(player: AnimationPlayer) -> void:
	for s: String in LOOPING:
		player.get_animation(s).loop_mode = Animation.LOOP_LINEAR
	var blend := AnimationNodeBlendTree.new()
	var transition := AnimationNodeTransition.new()
	transition.xfade_time = XFADE_S
	transition.input_count = STATES.size()
	for i: int in STATES.size():
		transition.set_input_name(i, STATES[i])
		var clip := AnimationNodeAnimation.new()
		clip.animation = StringName(STATES[i])
		blend.add_node(StringName(STATES[i]), clip)
	blend.add_node(&"state", transition)
	for i: int in STATES.size():
		blend.connect_node(&"state", i, StringName(STATES[i]))
	blend.connect_node(&"output", 0, &"state")
	_tree = AnimationTree.new()
	_tree.name = "AnimationTree"
	add_child(_tree)
	_tree.anim_player = _tree.get_path_to(player)
	_tree.tree_root = blend
	_tree.active = true
	play("idle")


## Switches to an animation (cross-fades; does nothing if already playing).
func play(s: String) -> void:
	if s == state or not STATES.has(s):
		return
	state = s
	_tree.set("parameters/state/transition_request", s)


## Call when the soldier fires (from the "fired" sim event).
func fired() -> void:
	_fired_left = FIRE_HOLD_S


func update(e: SimEntity, delta: float) -> void:
	_fired_left = maxf(0.0, _fired_left - delta)
	play(state_for(e, _fired_left > 0.0))
