"""Shared helpers for Project Zero Hour's Blender asset scripts.

Conventions (see docs/04-art-pipeline.md):
- 1 Blender unit = 1 meter. Ground is z = 0, the origin is the footprint center.
- Models face -Y in Blender, which becomes +Z (Vector3.MODEL_FRONT) in Godot.
- Parts the game recolors per player use a material named "team_color".
- Attachment points are empties named muzzle_0, muzzle_1, fx_exhaust, ...
"""

import csv
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Vector

TEAM_MATERIAL = "team_color"
MANIFEST_HEADER = ["path", "author", "source", "license", "generated_by", "notes"]


# --- Scene -----------------------------------------------------------------

def reset_scene():
    """Start from an empty scene (also resets render settings)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c):
    """Palette colors are written as screen (sRGB) values, the way artists
    pick them; Blender and glTF materials want linear values."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def get_material(name, color, roughness=0.75, metallic=0.0):
    """Create (or reuse) a simple Principled BSDF material. `color` is sRGB."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    if hasattr(mat, "use_nodes") and not mat.use_nodes:
        mat.use_nodes = True
    rgba = (srgb_to_linear(color[0]), srgb_to_linear(color[1]), srgb_to_linear(color[2]), 1.0)
    mat.diffuse_color = rgba
    bsdf = mat.node_tree.nodes.get("Principled BSDF") if mat.node_tree else None
    if bsdf is not None:
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    return mat


def _object_from_bmesh(name, bm, material, parent=None):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def box(name, size, location, material, parent=None):
    """Axis-aligned box. size = (x, y, z) in meters; location = its center."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    return _object_from_bmesh(name, bm, material, parent)


def cylinder(name, radius, depth, location, material, axis="Z", segments=12, parent=None):
    """Cylinder centered on `location`, running along `axis` (X, Y or Z)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segments,
                          radius1=radius, radius2=radius, depth=depth)
    if axis == "X":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
    elif axis == "Y":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    return _object_from_bmesh(name, bm, material, parent)


def sphere(name, radius, location, material, scale=(1.0, 1.0, 1.0), parent=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=radius)
    bmesh.ops.scale(bm, vec=Vector(scale), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(location), verts=bm.verts)
    return _object_from_bmesh(name, bm, material, parent)


def empty(name, location, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.2
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    if parent is not None:
        obj.parent = parent
    return obj


def set_origin(obj, world_point):
    """Move an object's origin (its pivot in Godot) to world_point without
    moving its mesh or its children. Turrets and barrels need this so the
    game can rotate them about the right point."""
    bpy.context.view_layer.update()
    mw = obj.matrix_world.copy()
    local = mw.inverted() @ Vector(world_point)
    shift = Matrix.Translation(local)
    if obj.data is not None:
        obj.data.transform(Matrix.Translation(-local))
    obj.matrix_world = mw @ shift
    # Object.children can be a stale cache in background mode, so scan instead.
    for child in [o for o in bpy.data.objects if o.parent == obj]:
        child.matrix_parent_inverse = Matrix.Translation(-local) @ child.matrix_parent_inverse
    return obj


def asset_objects():
    """Every object in the scene except cameras and lights."""
    return [o for o in bpy.context.scene.objects if o.type not in {"CAMERA", "LIGHT"}]


def triangle_count(objects):
    total = 0
    for obj in objects:
        if obj.type == "MESH":
            for poly in obj.data.polygons:
                total += len(poly.vertices) - 2
    return total


# --- Export ----------------------------------------------------------------

def export_glb(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type not in {"CAMERA", "LIGHT"})
    rigged = any(o.type == "ARMATURE" for o in bpy.context.scene.objects)
    extra = {}
    if rigged:
        # Each NLA track becomes one glTF animation (sf_rig, P2-16).
        extra = {"export_animations": True, "export_animation_mode": "NLA_TRACKS",
                 "export_force_sampling": True}
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=not rigged,   # applying modifiers drops the armature binding
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        **extra,
    )


# --- Rendering (icons and sprite sheets) ------------------------------------

def _bounds(objects):
    points = []
    for obj in objects:
        if obj.type == "MESH":
            points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        return Vector((0, 0, 0)), 1.0
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    center = (lo + hi) * 0.5
    radius = max((hi - lo).length * 0.5, 0.1)
    return center, radius


def setup_render(size, engine="CYCLES", samples=32):
    scene = bpy.context.scene
    scene.render.engine = engine
    if engine == "CYCLES":
        scene.cycles.device = "CPU"
        scene.cycles.samples = samples
        scene.cycles.use_denoising = True
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("IconWorld")
    scene.world = world
    if hasattr(world, "use_nodes") and not world.use_nodes:
        world.use_nodes = True
    background = world.node_tree.nodes.get("Background") if world.node_tree else None
    if background is not None:
        background.inputs["Color"].default_value = (0.35, 0.37, 0.40, 1.0)
        background.inputs["Strength"].default_value = 0.9


def add_lights():
    sun_data = bpy.data.lights.new("KeyLight", type="SUN")
    sun_data.energy = 3.5
    sun = bpy.data.objects.new("KeyLight", sun_data)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(-40))  # top-left key light
    bpy.context.scene.collection.objects.link(sun)


def place_camera(azimuth_deg, elevation_deg, padding=1.15):
    """Orthographic camera looking at the asset from the given angles.
    azimuth 0 looks at the model's front (the -Y side)."""
    objects = asset_objects()
    center, radius = _bounds(objects)
    cam = bpy.context.scene.camera
    if cam is None:
        cam_data = bpy.data.cameras.new("IconCamera")
        cam_data.type = "ORTHO"
        cam = bpy.data.objects.new("IconCamera", cam_data)
        bpy.context.scene.collection.objects.link(cam)
        bpy.context.scene.camera = cam
    cam.data.ortho_scale = radius * 2.0 * padding
    az = math.radians(azimuth_deg)
    el = math.radians(elevation_deg)
    direction = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = center + direction * (radius * 6.0)
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    cam.data.clip_end = radius * 20.0
    return cam


def render_to(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def stitch_horizontal(frame_paths, out_path):
    """Combine equally sized PNG frames left-to-right into one sprite sheet."""
    import numpy as np  # bundled with Blender

    frames = []
    for p in frame_paths:
        img = bpy.data.images.load(p)
        w, h = img.size
        px = np.empty(w * h * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        frames.append(px.reshape(h, w, 4))
        bpy.data.images.remove(img)
    sheet = np.concatenate(frames, axis=1)
    h, w = sheet.shape[0], sheet.shape[1]
    out = bpy.data.images.new("sheet", width=w, height=h, alpha=True)
    out.pixels.foreach_set(sheet.ravel())
    out.filepath_raw = out_path
    out.file_format = "PNG"
    out.save()
    bpy.data.images.remove(out)


# --- Provenance manifest ---------------------------------------------------

def update_manifest(manifest_path, rows):
    """Insert or replace manifest rows (dicts keyed by MANIFEST_HEADER), by path."""
    existing = {}
    if os.path.exists(manifest_path):
        with open(manifest_path, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                existing[row["path"]] = row
    for row in rows:
        existing[row["path"]] = row
    with open(manifest_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=MANIFEST_HEADER, lineterminator="\n")
        writer.writeheader()
        for path in sorted(existing):
            writer.writerow({k: existing[path].get(k, "") for k in MANIFEST_HEADER})
