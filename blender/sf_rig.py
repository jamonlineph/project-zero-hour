"""Infantry rig and animations (P2-16).

Every infantry model gets one armature, "squad_rig", with the same bones for
each soldier i (the shared rig):

    s{i}_hips        root of the soldier (moves for bobbing, prone, deaths)
      s{i}_spine     torso and vest
        s{i}_head    head and helmet
        s{i}_arm_l   left arm
        s{i}_arm_r   right arm and the weapon
      s{i}_leg_l, s{i}_leg_r

Body parts are separate low-poly meshes parented to their bone (rigid
binding), so artists can later replace them with a skinned mesh on the same
bones. The animations are actions on the armature, one per name in ANIMATIONS,
stored as NLA tracks so the glTF exporter writes each as its own animation:

    idle, walk, run, aim, fire, prone       loop
    death_1, death_2, enter_building        play once and hold the last pose

Poses are written as sampled smooth functions, so loops join seamlessly.
Soldiers walk out of step (a phase offset each) so a squad looks natural.
"""

import math

import bpy
from mathutils import Matrix, Vector

FPS = 30
# name: (seconds, loops)
ANIMATIONS = {
    "idle": (2.0, True),
    "walk": (1.0, True),
    "run": (0.6, True),
    "aim": (1.0, True),
    "fire": (0.4, True),
    "prone": (1.0, True),
    "death_1": (1.2, False),
    "death_2": (1.2, False),
    "enter_building": (1.0, False),
}
BONES = ("hips", "spine", "head", "arm_l", "arm_r", "leg_l", "leg_r")


def bone_name(i, part):
    return "s%d_%s" % (i, part)


def build_rig(figure_origins, s):
    """Creates the armature with bones for soldiers standing at
    figure_origins [(x, y), ...] (meters), scaled by s. Returns it."""
    data = bpy.data.armatures.new("squad_rig")
    arm = bpy.data.objects.new("squad_rig", data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for i, (ox, oy) in enumerate(figure_origins):
        def bone(part, head, tail, parent=None):
            b = data.edit_bones.new(bone_name(i, part))
            b.head = Vector((ox + head[0] * s, oy + head[1] * s, head[2] * s))
            b.tail = Vector((ox + tail[0] * s, oy + tail[1] * s, tail[2] * s))
            b.roll = 0.0
            b.use_connect = False
            if parent is not None:
                b.parent = parent
            return b
        hips = bone("hips", (0, 0, 0.85), (0, 0, 1.0))
        spine = bone("spine", (0, 0, 1.0), (0, 0, 1.45), hips)
        bone("head", (0, 0, 1.45), (0, 0, 1.75), spine)
        bone("arm_l", (-0.25, 0, 1.38), (-0.15, -0.32, 1.12), spine)
        bone("arm_r", (0.25, 0, 1.38), (0.2, -0.32, 1.12), spine)
        bone("leg_l", (-0.09, 0, 0.85), (-0.09, 0, 0.05), hips)
        bone("leg_r", (0.09, 0, 0.85), (0.09, 0, 0.05), hips)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def attach(obj, arm, bone):
    """Parents a mesh to a bone, keeping where it is in the world."""
    obj.parent = arm
    obj.parent_type = "BONE"
    obj.parent_bone = bone
    b = arm.data.bones[bone]
    parent_matrix = arm.matrix_world @ b.matrix_local @ Matrix.Translation((0.0, b.length, 0.0))
    obj.matrix_parent_inverse = parent_matrix.inverted()


# --- Poses ------------------------------------------------------------------
# Each pose function returns {part: (rot_x, rot_y, rot_z, lift)} in degrees and
# meters (lift moves the hips along their bone, which points up). t runs 0..1
# over the animation; phase is the soldier's walk offset (0..1).

def _wave(t, phase=0.0):
    return math.sin(2.0 * math.pi * (t + phase))


def pose_idle(t, phase):
    return {"spine": (1.5 * _wave(t, phase), 0, 0, 0), "head": (0, 0, 6 * _wave(t, phase + 0.25), 0)}


def _stride(t, phase, legs, arms, lean, bob):
    w = _wave(t, phase)
    return {
        "hips": (0, 0, 0, bob * abs(w)),
        "spine": (lean, 0, 0, 0),
        "leg_l": (legs * w, 0, 0, 0),
        "leg_r": (-legs * w, 0, 0, 0),
        "arm_l": (-arms * w, 0, 0, 0),
        "arm_r": (arms * 0.3 * w, 0, 0, 0),
    }


def pose_walk(t, phase):
    return _stride(t, phase, 26, 12, 3, 0.03)


def pose_run(t, phase):
    return _stride(t, phase, 42, 22, 12, 0.06)


def _aim():
    return {"spine": (4, 0, 0, 0), "arm_l": (-55, 0, 0, 0), "arm_r": (-55, 0, 0, 0), "head": (6, 0, 0, 0),
            "leg_l": (8, 0, 0, 0), "leg_r": (-6, 0, 0, 0)}


def pose_aim(t, phase):
    p = _aim()
    p["spine"] = (4 + 0.8 * _wave(t, phase), 0, 0, 0)
    return p


def pose_fire(t, phase):
    p = _aim()
    kick = math.exp(-t * 10.0) * 7.0   # recoil right after the shot, then settle
    p["spine"] = (4 - kick, 0, 0, 0)
    p["arm_l"] = (-55 - kick, 0, 0, 0)
    p["arm_r"] = (-55 - kick, 0, 0, 0)
    return p


def pose_prone(t, phase):
    return {"hips": (85, 0, 0, -0.62), "head": (-60, 0, 0, 0), "arm_l": (-95, 0, 0, 0), "arm_r": (-95, 0, 0, 0),
            "spine": (0.8 * _wave(t, phase), 0, 0, 0)}


def _ease(t):
    return t * t * (3.0 - 2.0 * t)


def pose_death_1(t, phase):
    """Falls backward."""
    k = _ease(min(1.0, t / 0.7))
    return {"hips": (-88 * k, 0, 0, -0.65 * k), "spine": (-10 * k, 0, 0, 0), "head": (-15 * k, 0, 0, 0),
            "arm_l": (40 * k, 0, -30 * k, 0), "arm_r": (40 * k, 0, 30 * k, 0), "leg_l": (12 * k, 0, 0, 0)}


def pose_death_2(t, phase):
    """Slumps forward onto its face, rolled a little to one side."""
    k = _ease(min(1.0, t / 0.8))
    return {"hips": (86 * k, 0, 22 * k, -0.66 * k), "spine": (8 * k, 0, 0, 0), "head": (-20 * k, 0, 35 * k, 0),
            "leg_l": (-12 * k, 0, 0, 0), "leg_r": (6 * k, 0, 0, 0),
            "arm_l": (-40 * k, 0, 35 * k, 0), "arm_r": (-70 * k, 0, -20 * k, 0)}


def pose_enter_building(t, phase):
    """Ducks and walks forward into a doorway."""
    p = _stride(t * 2.0, phase, 26, 10, 25 * min(1.0, t * 3), 0.0)
    p["hips"] = (0, 0, 0, -0.2 * min(1.0, t * 3))
    return p


POSES = {
    "idle": pose_idle, "walk": pose_walk, "run": pose_run, "aim": pose_aim, "fire": pose_fire,
    "prone": pose_prone, "death_1": pose_death_1, "death_2": pose_death_2,
    "enter_building": pose_enter_building,
}


def add_animations(arm, figures):
    """Creates every animation in ANIMATIONS on the armature."""
    bpy.context.scene.render.fps = FPS
    arm.animation_data_create()
    for name, (seconds, loops) in ANIMATIONS.items():
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data.action = action
        frames = max(2, int(round(seconds * FPS)))
        samples = 12 if loops else 10
        for k in range(samples + 1):
            t = k / samples
            frame = 1 + round(t * frames)
            for i in range(figures):
                phase = (i * 0.37) % 1.0
                pose = POSES[name](t, phase)
                for part in BONES:
                    pb = arm.pose.bones[bone_name(i, part)]
                    pb.rotation_mode = "XYZ"
                    rx, ry, rz, lift = pose.get(part, (0, 0, 0, 0))
                    pb.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(rz))
                    pb.location = (0.0, lift, 0.0)
                    pb.keyframe_insert("rotation_euler", frame=frame)
                    pb.keyframe_insert("location", frame=frame)
        track = arm.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, action)
        arm.animation_data.action = None
    # Rest pose for icons and the export's default.
    for pb in arm.pose.bones:
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
