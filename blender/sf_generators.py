"""Procedural placeholder generators: one function per archetype.

These build clean, readable grey-box models from simple shapes so the game
has something to show before final art exists. Final art replaces them
(docs/04-art-pipeline.md). Every generator gets (spec, palette) and builds
objects in the current scene. Models face -Y (the front), with z = 0 as ground.
"""

from sf_common import TEAM_MATERIAL, box, cylinder, empty, get_material, sphere


def _materials(spec, palette):
    faction = palette["factions"][spec["faction"]]
    return {
        "body": get_material(f"{spec['faction']}_body", faction["body"], roughness=0.8),
        "accent": get_material(f"{spec['faction']}_accent", [c * 0.8 for c in faction["body"]], roughness=0.8),
        "dark": get_material("dark", (0.07, 0.07, 0.07), roughness=0.9),
        "metal": get_material("metal", (0.25, 0.26, 0.27), roughness=0.5, metallic=0.6),
        "team": get_material(TEAM_MATERIAL, palette["team_color_preview"], roughness=0.6),
        "glass": get_material("glass", (0.12, 0.18, 0.22), roughness=0.2),
    }


def tracked(spec, palette):
    """Tracked vehicle: tank, howitzer or tracked troop carrier."""
    m = _materials(spec, palette)
    length, width, height = spec["length"], spec["width"], spec["height"]
    track_w = width * 0.22
    track_h = height * 0.45
    hull_h = height * 0.45
    hull = box("hull", (width * 0.78, length * 0.94, hull_h), (0, 0, track_h * 0.8 + hull_h / 2), m["body"])
    for side, sx in (("l", -1), ("r", 1)):
        box(f"track_{side}", (track_w, length, track_h), (sx * (width - track_w) / 2, 0, track_h / 2), m["dark"], hull)
    hull_top = track_h * 0.8 + hull_h
    if not spec.get("turret", True):
        return
    t_w, t_l, t_h = width * 0.6, length * 0.4, height * 0.32
    t_y = length * 0.06
    turret = box("turret", (t_w, t_l, t_h), (0, t_y, hull_top + t_h / 2), m["accent"], hull)
    for side, sx in (("l", -1), ("r", 1)):
        box(f"team_panel_{side}", (0.05, t_l * 0.6, t_h * 0.55), (sx * (t_w / 2 + 0.03), t_y, hull_top + t_h / 2), m["team"], turret)
    barrel_len = spec.get("barrel_length", length * 0.55)
    barrel_r = spec.get("barrel_radius", 0.09)
    barrel_y = t_y - t_l / 2 - barrel_len / 2
    barrel = cylinder("barrel", barrel_r, barrel_len, (0, barrel_y, hull_top + t_h * 0.55), m["metal"], axis="Y", parent=turret)
    empty("muzzle_0", (0, barrel_y - barrel_len / 2, hull_top + t_h * 0.55), parent=barrel)
    if spec.get("aps"):
        # Active protection launchers on the turret corners.
        for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
            box(f"aps_{i}", (0.25, 0.25, 0.18), (sx * t_w * 0.45, t_y + sy * t_l * 0.4, hull_top + t_h + 0.09), m["metal"], turret)
    if spec.get("cage"):
        # Anti-drone cage: a frame of thin bars above the turret.
        cage_z = hull_top + t_h + 0.55
        for i, sx in enumerate((-1, 1)):
            box(f"cage_rail_{i}", (0.05, t_l * 1.3, 0.05), (sx * t_w * 0.6, t_y, cage_z), m["metal"], turret)
        for i, sy in enumerate((-1, 0, 1)):
            box(f"cage_bar_{i}", (t_w * 1.2, 0.05, 0.05), (0, t_y + sy * t_l * 0.6, cage_z), m["metal"], turret)
        for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
            box(f"cage_post_{i}", (0.05, 0.05, 0.55), (sx * t_w * 0.6, t_y + sy * t_l * 0.6, cage_z - 0.27), m["metal"], turret)


def wheeled(spec, palette):
    """Wheeled vehicle: trucks, light vehicles, launchers."""
    m = _materials(spec, palette)
    length, width, height = spec["length"], spec["width"], spec["height"]
    axles = spec.get("axles", 2)
    wheel_r = height * 0.22
    body_z = wheel_r * 1.2
    body = box("body", (width * 0.92, length * 0.68, height * 0.45), (0, length * 0.14, body_z + height * 0.22), m["body"])
    cab_l = length * 0.28
    cab = box("cab", (width * 0.92, cab_l, height * 0.62), (0, -length / 2 + cab_l / 2, body_z + height * 0.31), m["body"], body)
    box("windshield", (width * 0.8, 0.05, height * 0.22), (0, -length / 2 - 0.02, body_z + height * 0.45), m["glass"], cab)
    for side, sx in (("l", -1), ("r", 1)):
        box(f"team_door_{side}", (0.04, cab_l * 0.6, height * 0.25), (sx * (width * 0.46 + 0.02), -length / 2 + cab_l / 2, body_z + height * 0.25), m["team"], cab)
    for a in range(axles):
        y = -length * 0.32 + a * (length * 0.68 / max(axles - 1, 1))
        for side, sx in (("l", -1), ("r", 1)):
            cylinder(f"wheel_{side}{a}", wheel_r, width * 0.16, (sx * width * 0.42, y, wheel_r), m["dark"], axis="X", parent=body)
    cargo = spec.get("cargo")
    if cargo == "crates":
        for i in range(3):
            box(f"crate_{i}", (width * 0.7, length * 0.18, height * 0.3), (0, length * (0.0 + i * 0.2), body_z + height * 0.6), m["metal"], body)
    elif cargo == "launcher":
        launcher = box("launcher", (width * 0.8, length * 0.55, height * 0.35), (0, length * 0.15, body_z + height * 0.75), m["metal"], body)
        launcher.rotation_euler = (0.35, 0, 0)


def infantry(spec, palette):
    """A small squad of low-poly soldiers, scaled up for readability."""
    m = _materials(spec, palette)
    figures = spec.get("figures", 4)
    s = spec.get("scale", 1.3)
    spacing = 0.9 * s
    cols = 2
    for i in range(figures):
        ox = ((i % cols) - (cols - 1) / 2) * spacing
        oy = ((i // cols) - ((figures - 1) // cols) / 2) * spacing
        legs = box(f"soldier_{i}", (0.32 * s, 0.22 * s, 0.85 * s), (ox, oy, 0.425 * s), m["dark"])
        box(f"torso_{i}", (0.42 * s, 0.26 * s, 0.6 * s), (ox, oy, 1.15 * s), m["body"], legs)
        box(f"vest_{i}", (0.44 * s, 0.2 * s, 0.32 * s), (ox, oy + 0.06 * s, 1.18 * s), m["team"], legs)
        sphere(f"head_{i}", 0.13 * s, (ox, oy, 1.6 * s), m["body"], parent=legs)
        sphere(f"helmet_{i}", 0.15 * s, (ox, oy, 1.66 * s), m["body"], scale=(1.0, 1.0, 0.65), parent=legs)
        box(f"rifle_{i}", (0.06 * s, 0.75 * s, 0.08 * s), (ox + 0.22 * s, oy - 0.25 * s, 1.15 * s), m["metal"], legs)


def drone(spec, palette):
    """Quadcopter (recon or attack drone). Hover height is handled in Godot."""
    m = _materials(spec, palette)
    size = spec.get("size", 1.2)
    body = box("body", (size * 0.35, size * 0.5, size * 0.15), (0, 0, size * 0.1), m["body"])
    box("team_plate", (size * 0.25, size * 0.3, 0.02), (0, 0, size * 0.18), m["team"], body)
    for i, (sx, sy) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        box(f"arm_{i}", (size * 0.08, size * 0.08, size * 0.04), (sx * size * 0.3, sy * size * 0.3, size * 0.12), m["dark"], body)
        cylinder(f"rotor_{i}", size * 0.2, 0.02, (sx * size * 0.42, sy * size * 0.42, size * 0.16), m["metal"], parent=body)
    box("camera_pod", (size * 0.1, size * 0.1, size * 0.1), (0, -size * 0.22, size * 0.02), m["glass"], body)


def building(spec, palette):
    """Generic structure: base slab, main block, team-color band, details."""
    m = _materials(spec, palette)
    w, d, h = spec["width"], spec["depth"], spec["height"]
    base = box("base", (w, d, 0.3), (0, 0, 0.15), m["metal"])
    main = box("main", (w * 0.8, d * 0.7, h), (0, d * 0.05, 0.3 + h / 2), m["body"], base)
    box("team_band", (w * 0.82, d * 0.72, h * 0.12), (0, d * 0.05, 0.3 + h * 0.7), m["team"], main)
    box("door", (w * 0.25, 0.1, h * 0.45), (0, -d * 0.3 - 0.05, 0.3 + h * 0.225), m["dark"], main)
    details = spec.get("details", [])
    if "mast" in details:
        cylinder("mast", 0.12, h * 0.9, (w * 0.25, d * 0.2, 0.3 + h + h * 0.45), m["metal"], parent=main)
        sphere("dish", 0.6, (w * 0.25, d * 0.2, 0.3 + h * 1.9), m["metal"], scale=(1.0, 0.35, 1.0), parent=main)
    if "vents" in details:
        for i in range(3):
            box(f"vent_{i}", (w * 0.12, d * 0.12, 0.4), (-w * 0.25 + i * w * 0.15, d * 0.15, 0.3 + h + 0.2), m["dark"], main)


ARCHETYPES = {
    "tracked": tracked,
    "wheeled": wheeled,
    "infantry": infantry,
    "drone": drone,
    "building": building,
}
